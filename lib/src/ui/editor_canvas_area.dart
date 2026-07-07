import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../models/brush_preset.dart';
import '../models/brush_preset_id.dart';
import '../models/canvas_viewport.dart';
import '../services/abr/abr_decoder.dart';
import '../services/brush_preset_file_service.dart';
import '../services/sut/sut_decoder.dart';
import 'brush/brush_preset_panel.dart';
import 'brush/brush_settings_panel.dart';
import 'brush/brush_tool_state.dart';
import 'brush/main_canvas_brush_host.dart';
import 'brush/tools_panel.dart';
import 'camera/camera_frame_overlay.dart';
import 'camera/camera_panel.dart';
import 'canvas/canvas_layer_stack_view.dart';
import 'editor_session_manager.dart';
import 'export/ae_keyframe_data.dart';
import 'panels/editor_panel_dock.dart';
import 'playback/canvas_playback_view.dart';

/// The central drawing area: the brush canvas plus the brush-settings dock.
///
/// Owns the two pieces of transient view state that change on hot paths — the
/// [CanvasViewport] (pan/zoom) and the [BrushToolState] (brush sliders). Keeping
/// them local means dragging a brush slider or panning the canvas rebuilds only
/// this subtree instead of the whole editor Scaffold (cut bar, timeline, etc.).
/// Also owns the brush preset library, loaded from and persisted to the
/// app-level preset file.
///
/// Model-derived inputs are read from [session]; the host rebuilds this widget
/// when the session notifies.
/// A picked brush file: display name plus raw bytes.
typedef BrushFilePick = ({String name, Uint8List bytes});

/// Opens a brush file picker; `null` when the user cancels.
typedef BrushFilePicker = Future<BrushFilePick?> Function();

/// Production picker: the platform open-file dialog filtered to the
/// supported brush formats.
Future<BrushFilePick?> _openBrushFileDialog() async {
  const typeGroup = XTypeGroup(
    label: 'Brushes (Photoshop, Clip Studio)',
    extensions: ['abr', 'sut', 'sutg'],
  );
  final file = await openFile(acceptedTypeGroups: const [typeGroup]);
  if (file == null) {
    return null;
  }
  final bytes = await File(file.path).readAsBytes();
  return (name: file.name, bytes: bytes);
}

class EditorCanvasArea extends StatefulWidget {
  const EditorCanvasArea({
    super.key,
    required this.session,
    this.presetFileService,
    this.brushFilePicker,
  });

  final EditorSessionManager session;

  /// Injectable preset persistence; defaults to the app-data preset file.
  final BrushPresetFileService? presetFileService;

  /// Injectable brush-file picker; defaults to the platform file dialog.
  final BrushFilePicker? brushFilePicker;

  @override
  State<EditorCanvasArea> createState() => _EditorCanvasAreaState();
}

class _EditorCanvasAreaState extends State<EditorCanvasArea> {
  CanvasViewport _canvasViewport = CanvasViewport();
  BrushToolState _brushToolState = BrushToolState.defaults;

  /// Camera view mode: overlay shown with the outside dimmed.
  bool _cameraViewEnabled = false;
  double _cameraDimOpacity = 0.5;
  late final BrushPresetFileService _presetFileService =
      widget.presetFileService ?? BrushPresetFileService();
  List<BrushPreset> _brushPresets = const <BrushPreset>[];

  /// The last-applied (or last-saved) preset, highlighted in the list.
  /// Tweaking settings keeps the highlight; deleting the preset clears it.
  BrushPresetId? _activePresetId;

  @override
  void initState() {
    super.initState();
    _presetFileService.loadOrDefaults().then((presets) {
      if (mounted) {
        setState(() => _brushPresets = presets);
      }
    });
  }

  /// Copies the active cut's camera work to the clipboard as AE keyframe
  /// data (baked per frame; paste onto the canvas-sequence layer in a
  /// camera-frame-sized comp).
  void _copyCameraAeKeyframes() {
    final session = widget.session;
    final cut = session.activeCut;
    final cameraSize = session.cameraFrameSize;
    final text = buildAeTransformKeyframeData(
      framesPerSecond: session.projectFps,
      sourceWidth: cameraSize.width,
      sourceHeight: cameraSize.height,
      samples: bakeCameraAeSamples(
        camera: cut.camera,
        canvasSize: cut.canvasSize,
        frameCount: session.activeCutPlaybackFrameCount,
      ),
    );
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera keyframes copied for After Effects.'),
      ),
    );
  }

  void _applyPreset(BrushPreset preset) {
    setState(() {
      _brushToolState = BrushToolState.fromBrushSettings(preset.settings);
      _activePresetId = preset.id;
    });
  }

  void _saveCurrentAsPreset() {
    final preset = BrushPreset(
      id: BrushPresetId('user-${DateTime.now().millisecondsSinceEpoch}'),
      name: _nextPresetName(),
      settings: _brushToolState.toBrushSettings(),
    );
    setState(() {
      _brushPresets = [..._brushPresets, preset];
      _activePresetId = preset.id;
    });
    _persistPresets();
  }

  void _renamePreset(BrushPresetId id, String name) {
    setState(() {
      _brushPresets = [
        for (final preset in _brushPresets)
          preset.id == id ? preset.copyWith(name: name) : preset,
      ];
    });
    _persistPresets();
  }

  void _reorderPresets(List<BrushPreset> presets) {
    setState(() {
      _brushPresets = List.of(presets);
    });
    _persistPresets();
  }

  void _deletePreset(BrushPresetId id) {
    setState(() {
      _brushPresets = [
        for (final preset in _brushPresets)
          if (preset.id != id) preset,
      ];
      if (_activePresetId == id) {
        _activePresetId = null;
      }
    });
    _persistPresets();
  }

  Future<void> _importBrushFile() async {
    final picker = widget.brushFilePicker ?? _openBrushFileDialog;
    final BrushFilePick? pick;
    try {
      pick = await picker();
    } catch (error) {
      _showImportMessage('Could not open the file: $error');
      return;
    }
    if (pick == null || !mounted) {
      return;
    }

    final lowerName = pick.name.toLowerCase();
    final baseName = pick.name.contains('.')
        ? pick.name.substring(0, pick.name.lastIndexOf('.'))
        : pick.name;
    final List<BrushPreset> imported;
    final List<String> warnings;
    try {
      if (lowerName.endsWith('.sut') || lowerName.endsWith('.sutg')) {
        final result = await _decodeSutBytes(pick.bytes, sourceName: baseName);
        imported = result.presets;
        warnings = result.warnings;
      } else {
        final result = decodeAbrBrushFile(pick.bytes, sourceName: baseName);
        imported = result.presets;
        warnings = result.warnings;
      }
    } on AbrDecodeException catch (error) {
      _showImportMessage(error.message);
      return;
    } on SutDecodeException catch (error) {
      _showImportMessage(error.message);
      return;
    } on Exception {
      _showImportMessage('This file could not be read as a brush file.');
      return;
    }
    if (!mounted) {
      return;
    }
    // Imported brushes group under their source file, mirroring Clip
    // Studio's sub-tool groups (re-importing keeps them together).
    final grouped = [
      for (final preset in imported) preset.copyWith(group: baseName),
    ];
    setState(() {
      // Re-importing replaces presets with the same id (same brush/tip).
      final importedIds = {for (final preset in grouped) preset.id};
      _brushPresets = [
        for (final preset in _brushPresets)
          if (!importedIds.contains(preset.id)) preset,
        ...grouped,
      ];
    });
    _persistPresets();
    final summary = imported.length == 1
        ? 'Imported 1 brush from "${pick.name}".'
        : 'Imported ${imported.length} brushes from "${pick.name}".';
    _showImportMessage(
      warnings.isEmpty
          ? summary
          : '$summary (${warnings.length} entries with warnings)',
    );
  }

  /// The SQLite reader needs a file path; work on a scratch copy so the
  /// user's original brush file is never opened for writing or locked.
  Future<SutImportResult> _decodeSutBytes(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    final directory = await Directory.systemTemp.createTemp('sut_import');
    try {
      final file = File('${directory.path}/import.sut');
      await file.writeAsBytes(bytes, flush: true);
      return await decodeSutBrushFile(
        filePath: file.path,
        sourceName: sourceName,
      );
    } finally {
      unawaited(
        directory.delete(recursive: true).catchError((Object _) => directory),
      );
    }
  }

  void _showImportMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _nextPresetName() {
    final names = {for (final preset in _brushPresets) preset.name};
    var index = _brushPresets.length + 1;
    while (names.contains('Preset $index')) {
      index += 1;
    }
    return 'Preset $index';
  }

  void _persistPresets() {
    // Fire-and-forget: preset persistence must never block or crash the
    // editor; a failed write just leaves the in-memory library unsaved.
    unawaited(_presetFileService.save(_brushPresets).catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isCameraLayerActive = session.isCameraLayerActive;
    final showCameraOverlay = _cameraViewEnabled || isCameraLayerActive;
    return Row(
      children: [
        // CSP-like layout: the brush library + tool properties dock sits on
        // the left of the canvas.
        EditorPanelDock(
          side: EditorPanelDockSide.left,
          children: [
            ToolsPanel(
              tool: _brushToolState.tool,
              onToolChanged: (tool) {
                setState(
                  () => _brushToolState = _brushToolState.copyWith(tool: tool),
                );
              },
            ),
            BrushPresetPanel(
              presets: _brushPresets,
              selectedPresetId: _activePresetId,
              onPresetApplied: _applyPreset,
              onPresetSaveRequested: _saveCurrentAsPreset,
              onPresetDeleted: _deletePreset,
              onPresetRenamed: _renamePreset,
              onPresetsReordered: _reorderPresets,
              onPresetImportRequested: () {
                unawaited(_importBrushFile());
              },
            ),
            BrushSettingsPanel(
              state: _brushToolState,
              onChanged: (state) {
                setState(() => _brushToolState = state);
              },
            ),
            CameraPanel(
              cameraViewEnabled: _cameraViewEnabled,
              onCameraViewChanged: (enabled) {
                setState(() => _cameraViewEnabled = enabled);
              },
              dimOpacity: _cameraDimOpacity,
              onDimOpacityChanged: (opacity) {
                setState(() => _cameraDimOpacity = opacity);
              },
              isCameraLayerActive: isCameraLayerActive,
              pose: session.cameraPoseAtCurrentFrame,
              hasKeyframeAtCurrentFrame:
                  session.hasCameraKeyframeAtCurrentFrame,
              onPoseCommitted: session.setCameraKeyframeAtCurrentFrame,
              onRemoveKeyframe: session.removeCameraKeyframeAtCurrentFrame,
              onCopyAeKeyframes: _copyCameraAeKeyframes,
            ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    // Playback swaps only the viewport CONTENT (via the panel's
                    // contentOverride), so the panel shell — zoom buttons,
                    // panbars — keeps working while playing. Listen to
                    // enter/leave ONLY: subscribing this subtree to every
                    // playback tick rebuilt the whole panel at fps and
                    // caused real frame drops.
                    child: ValueListenableBuilder<bool>(
                      valueListenable: session.playback.isActiveListenable,
                      builder: (context, _, _) {
                        return _buildInteractiveCanvas(
                          session,
                          isCameraLayerActive: isCameraLayerActive,
                          showCameraOverlay: showCameraOverlay,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveCanvas(
    EditorSessionManager session, {
    required bool isCameraLayerActive,
    required bool showCameraOverlay,
  }) {
    final isPlaybackActive = session.playback.isActive;
    final layerStack = session.editingCanvasStack;
    final showAboveLayers = !isPlaybackActive && layerStack.above.isNotEmpty;
    // Camera mode retargets the Fit button at the camera frame's bounds —
    // fitting the cut canvas there framed the wrong rectangle.
    final fitFocusRect = isCameraLayerActive
        ? cameraFrameBoundsInCanvas(
            pose: session.cameraPoseAtCurrentFrame,
            cameraFrameSize: session.cameraFrameSize,
          )
        : null;
    return RepaintBoundary(
      child: KeyedSubtree(
        key: const ValueKey<String>('main-canvas-brush-host-container'),
        child: MainCanvasBrushHost(
          // Camera mode still needs artwork on screen: fall
          // back to the first drawn layer at the playhead.
          selection: isCameraLayerActive
              ? session.cameraBackdropSelection
              : session.activeBrushEditorSelection,
          canvasSize: session.activeCut.canvasSize,
          frameStore: session.brushFrameStore,
          cacheInvalidationSink: session.cacheInvalidationHub,
          historyManager: session.historyManager,
          viewport: _canvasViewport,
          onViewportChanged: (viewport) {
            setState(() => _canvasViewport = viewport);
          },
          selectionLabels: session.canvasSelectionLabels,
          brushToolState: _brushToolState,
          fitFocusRect: fitFocusRect,
          // Layers below/above the active one composite around the
          // interactive view from the layer image cache — this is what makes
          // the other layers (and their visibility/opacity) visible while
          // editing. During playback the composite covers everything.
          viewportUnderlayBuilder: isPlaybackActive
              ? null
              : (context, viewport) => CanvasLayerStackView(
                  layers: layerStack.below,
                  imageCache: session.layerFrameImageCache,
                  canvasSize: session.activeCut.canvasSize,
                  viewport: viewport,
                  paintPaper: true,
                ),
          interactiveContentOpacity: layerStack.activeLayerOpacity,
          // The playback view renders the camera framing itself; the editing
          // overlay would show a stale playhead pose on top of it.
          viewportOverlayBuilder:
              (showCameraOverlay || showAboveLayers) && !isPlaybackActive
              ? (context, viewport) => Stack(
                  children: [
                    if (showAboveLayers)
                      Positioned.fill(
                        child: CanvasLayerStackView(
                          layers: layerStack.above,
                          imageCache: session.layerFrameImageCache,
                          canvasSize: session.activeCut.canvasSize,
                          viewport: viewport,
                        ),
                      ),
                    if (showCameraOverlay)
                      Positioned.fill(
                        child: CameraFrameOverlay(
                          pose: session.cameraPoseAtCurrentFrame,
                          cameraFrameSize: session.cameraFrameSize,
                          viewport: viewport,
                          // Dim belongs to camera-view mode; plain
                          // manipulation keeps the artwork undimmed.
                          dimOpacity: _cameraViewEnabled
                              ? _cameraDimOpacity
                              : 0,
                          interactive: isCameraLayerActive,
                          onPoseCommitted:
                              session.setCameraKeyframeAtCurrentFrame,
                        ),
                      ),
                  ],
                )
              : null,
          contentOverride: isPlaybackActive
              ? (context, viewport) => CanvasPlaybackView(
                  controller: session.playback,
                  compositeCache: session.cutFrameCompositeCache,
                  qualityOf: () => session.playbackQuality,
                  prerenderProgress: session.prerenderScheduler.progress,
                  cameraViewEnabled: _cameraViewEnabled,
                  cameraFrameSize: session.cameraFrameSize,
                  cameraPoseOf: session.cameraPoseForCut,
                  viewport: viewport,
                )
              : null,
        ),
      ),
    );
  }
}
