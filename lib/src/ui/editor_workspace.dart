import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../models/brush_preset.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../services/brush_preset_file_service.dart';
import 'brush/brush_preset_library.dart';
import 'brush/brush_preset_panel.dart';
import 'brush/brush_settings_panel.dart';
import 'brush/brush_tool_state.dart';
import 'brush/tools_panel.dart';
import 'camera/camera_panel.dart';
import 'editor_canvas_area.dart';
import 'editor_session_manager.dart';
import 'export/ae_keyframe_data.dart';
import 'export/export_frame_renderer.dart';
import 'export/export_plan.dart';
import 'panels/editor_panel_dock.dart';
import 'panels/editor_panel_layout.dart';
import 'panels/editor_panel_tabs.dart';
import 'storyboard_cut_thumbnail_store.dart';
import 'storyboard_playhead_mapping.dart';
import 'storyboard_tab_host.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart' show TimelinePanel;
import 'timeline_tab_host.dart';

/// The editor workspace: the left panel dock, the canvas and the bottom
/// panel region — every dockable panel lives in one of the two tab groups
/// of an [EditorPanelLayoutModel], so tabs can move between docks.
///
/// This widget is the COMMON OWNER of all dockable-panel view state (brush
/// tool, preset library, camera view, timeline view state): a panel keeps
/// working wherever its tab is docked. Hot values (slider drags, zooms) are
/// ValueNotifiers consumed per-tab, so dragging a brush slider never
/// rebuilds the timeline and vice versa; this widget itself only rebuilds
/// on layout changes.
class EditorWorkspace extends StatefulWidget {
  const EditorWorkspace({
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

  static const double bottomPanelHeight = 350;

  static const String leftGroupId = 'left';
  static const String bottomGroupId = 'bottom';

  static const String toolsTabId = 'tools';
  static const String brushesTabId = 'brushes';
  static const String brushSettingsTabId = 'brush-settings';
  static const String cameraTabId = 'camera';
  static const String timelineTabId = 'timeline';
  static const String storyboardTabId = 'storyboard';

  @override
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<EditorWorkspace> {
  final EditorPanelLayoutModel _layout = EditorPanelLayoutModel(
    groups: {
      EditorWorkspace.leftGroupId: [
        EditorWorkspace.toolsTabId,
        EditorWorkspace.brushesTabId,
        EditorWorkspace.brushSettingsTabId,
        EditorWorkspace.cameraTabId,
      ],
      EditorWorkspace.bottomGroupId: [
        EditorWorkspace.timelineTabId,
        EditorWorkspace.storyboardTabId,
      ],
    },
    activeTabs: {
      EditorWorkspace.leftGroupId: EditorWorkspace.brushesTabId,
      EditorWorkspace.bottomGroupId: EditorWorkspace.timelineTabId,
    },
  );

  final ValueNotifier<BrushToolState> _brushTool = ValueNotifier(
    BrushToolState.defaults,
  );
  late final BrushPresetLibrary _presetLibrary;

  /// Camera view mode: overlay shown with the outside dimmed.
  final ValueNotifier<bool> _cameraViewEnabled = ValueNotifier(false);
  final ValueNotifier<double> _cameraDimOpacity = ValueNotifier(0.5);

  final ValueNotifier<TimelineOrientation> _timelineOrientation = ValueNotifier(
    TimelineOrientation.horizontal,
  );

  // One shared zoom slider drives whichever view is shown; the values are
  // kept per view so each keeps a sensible default scale.
  final ValueNotifier<double> _timelinePixelsPerFrame = ValueNotifier(
    TimelinePanel.defaultPixelsPerFrame,
  );
  final ValueNotifier<double> _storyboardPixelsPerFrame = ValueNotifier(8);

  /// Shared frames↔seconds display toggle (conte-sheet 초+コマ notation).
  final ValueNotifier<bool> _showSecondsDisplay = ValueNotifier(false);

  late final StoryboardCutThumbnailStore _storyboardThumbnails;

  @override
  void initState() {
    super.initState();
    _presetLibrary = BrushPresetLibrary(
      fileService: widget.presetFileService,
      filePicker: widget.brushFilePicker,
    );
    unawaited(_presetLibrary.load());
    _storyboardThumbnails = StoryboardCutThumbnailStore(
      render: _renderStoryboardThumbnail,
      invalidationHub: widget.session.cacheInvalidationHub,
    );
  }

  @override
  void dispose() {
    _storyboardThumbnails.dispose();
    _presetLibrary.dispose();
    _brushTool.dispose();
    _cameraViewEnabled.dispose();
    _cameraDimOpacity.dispose();
    _timelineOrientation.dispose();
    _timelinePixelsPerFrame.dispose();
    _storyboardPixelsPerFrame.dispose();
    _showSecondsDisplay.dispose();
    _layout.dispose();
    super.dispose();
  }

  /// Thumbnails render the cut's first frame THROUGH THE CAMERA (what the
  /// shot actually frames — conte-sheet style), scaled to a small output;
  /// always current (a fresh renderer replays surfaces straight from the
  /// brush store).
  Future<ui.Image?> _renderStoryboardThumbnail(Cut cut) {
    const thumbnailWidth = 128;
    final cameraSize = widget.session.cameraFrameSize;
    final height = math.max(
      1,
      (thumbnailWidth * cameraSize.height / cameraSize.width).round(),
    );
    return ExportFrameRenderer(session: widget.session).renderComposite(
      ExportFrameTask(cut: cut, frameIndex: 0),
      ExportSizeMode.camera,
      outputSize: CanvasSize(width: thumbnailWidth, height: height),
    );
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
    _brushTool.value = BrushToolState.fromBrushSettings(preset.settings);
    _presetLibrary.markActive(preset.id);
  }

  Future<void> _importBrushFile() async {
    final message = await _presetLibrary.importFromFile();
    if (message == null || !mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Whether the storyboard tab is the active tab of any group (visible on
  /// screen).
  bool get _isStoryboardVisible => _layout.groupIds.any(
    (groupId) =>
        _layout.activeTabIn(groupId) == EditorWorkspace.storyboardTabId,
  );

  /// Runs a layout mutation and clamps the playhead when the storyboard
  /// just came on screen (over-end playheads on non-last cuts must land
  /// back on the counter frame — timeline parity).
  void _mutatingLayout(VoidCallback mutate) {
    final wasVisible = _isStoryboardVisible;
    mutate();
    if (!wasVisible && _isStoryboardVisible) {
      clampPlayheadForStoryboard(widget.session);
    }
  }

  void _selectTab(String groupId, String tabId) {
    _mutatingLayout(() => _layout.selectTab(groupId, tabId));
  }

  EditorPanelTab _tabFor(String tabId) {
    switch (tabId) {
      case EditorWorkspace.toolsTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Tools',
          icon: Icons.handyman_outlined,
          builder: (context) => ValueListenableBuilder<BrushToolState>(
            valueListenable: _brushTool,
            builder: (context, toolState, _) => ToolsPanel(
              tool: toolState.tool,
              onToolChanged: (tool) {
                _brushTool.value = _brushTool.value.copyWith(tool: tool);
              },
            ),
          ),
        );
      case EditorWorkspace.brushesTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Brushes',
          icon: Icons.brush_outlined,
          builder: (context) => ListenableBuilder(
            listenable: _presetLibrary,
            builder: (context, _) => BrushPresetPanel(
              presets: _presetLibrary.presets,
              selectedPresetId: _presetLibrary.activePresetId,
              onPresetApplied: _applyPreset,
              onPresetSaveRequested: () {
                _presetLibrary.saveCurrent(_brushTool.value.toBrushSettings());
              },
              onPresetDeleted: _presetLibrary.delete,
              onPresetRenamed: _presetLibrary.rename,
              onPresetsReordered: _presetLibrary.reorder,
              onPresetImportRequested: () {
                unawaited(_importBrushFile());
              },
            ),
          ),
        );
      case EditorWorkspace.brushSettingsTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Brush Settings',
          icon: Icons.tune,
          builder: (context) => ValueListenableBuilder<BrushToolState>(
            valueListenable: _brushTool,
            builder: (context, toolState, _) => BrushSettingsPanel(
              state: toolState,
              onChanged: (state) => _brushTool.value = state,
            ),
          ),
        );
      case EditorWorkspace.cameraTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Camera',
          icon: Icons.videocam_outlined,
          builder: (context) => ListenableBuilder(
            listenable: Listenable.merge([
              _cameraViewEnabled,
              _cameraDimOpacity,
            ]),
            builder: (context, _) => CameraPanel(
              cameraViewEnabled: _cameraViewEnabled.value,
              onCameraViewChanged: (enabled) {
                _cameraViewEnabled.value = enabled;
              },
              dimOpacity: _cameraDimOpacity.value,
              onDimOpacityChanged: (opacity) {
                _cameraDimOpacity.value = opacity;
              },
              isCameraLayerActive: widget.session.isCameraLayerActive,
              pose: widget.session.cameraPoseAtCurrentFrame,
              hasKeyframeAtCurrentFrame:
                  widget.session.hasCameraKeyframeAtCurrentFrame,
              onPoseCommitted: widget.session.setCameraKeyframeAtCurrentFrame,
              onRemoveKeyframe:
                  widget.session.removeCameraKeyframeAtCurrentFrame,
              onCopyAeKeyframes: _copyCameraAeKeyframes,
            ),
          ),
        );
      case EditorWorkspace.timelineTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Timeline',
          icon: Icons.view_timeline_outlined,
          // The legacy mode-toggle keys stay on the tab buttons so every
          // existing flow (and test helper) keeps working.
          buttonKey: const ValueKey<String>('timeline-mode-timeline-button'),
          builder: (context) => ListenableBuilder(
            listenable: Listenable.merge([
              _timelineOrientation,
              _timelinePixelsPerFrame,
              _showSecondsDisplay,
            ]),
            builder: (context, _) => TimelineTabHost(
              session: widget.session,
              orientation: _timelineOrientation.value,
              onOrientationChanged: (orientation) {
                _timelineOrientation.value = orientation;
              },
              pixelsPerFrame: _timelinePixelsPerFrame.value,
              onPixelsPerFrameChanged: (value) {
                _timelinePixelsPerFrame.value = value;
              },
              showSeconds: _showSecondsDisplay.value,
              onShowSecondsChanged: (show) {
                _showSecondsDisplay.value = show;
              },
            ),
          ),
        );
      case EditorWorkspace.storyboardTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Storyboard',
          icon: Icons.movie_outlined,
          buttonKey: const ValueKey<String>('timeline-mode-storyboard-button'),
          builder: (context) => ListenableBuilder(
            listenable: Listenable.merge([
              _storyboardPixelsPerFrame,
              _showSecondsDisplay,
              _storyboardThumbnails,
            ]),
            builder: (context, _) => StoryboardTabHost(
              session: widget.session,
              pixelsPerFrame: _storyboardPixelsPerFrame.value,
              onPixelsPerFrameChanged: (value) {
                _storyboardPixelsPerFrame.value = value;
              },
              showSeconds: _showSecondsDisplay.value,
              onShowSecondsChanged: (show) {
                _showSecondsDisplay.value = show;
              },
              thumbnailFor: _storyboardThumbnails.thumbnailFor,
            ),
          ),
        );
      default:
        throw ArgumentError.value(tabId, 'tabId', 'Unknown panel tab');
    }
  }

  Widget _buildTabGroup(String groupId, {bool compact = false}) {
    return EditorPanelTabs(
      compact: compact,
      tabs: [for (final id in _layout.tabsIn(groupId)) _tabFor(id)],
      activeTabId: _layout.activeTabIn(groupId)!,
      onTabSelected: (tabId) => _selectTab(groupId, tabId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _layout,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // CSP-like layout: the tool/brush/camera palettes dock on
                  // the left of the canvas as tabs.
                  EditorPanelDock.filled(
                    side: EditorPanelDockSide.left,
                    child: _buildTabGroup(
                      EditorWorkspace.leftGroupId,
                      compact: true,
                    ),
                  ),
                  Expanded(
                    child: EditorCanvasArea(
                      session: widget.session,
                      brushToolState: _brushTool,
                      cameraViewEnabled: _cameraViewEnabled,
                      cameraDimOpacity: _cameraDimOpacity,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: EditorWorkspace.bottomPanelHeight,
              child: _buildTabGroup(EditorWorkspace.bottomGroupId),
            ),
          ],
        );
      },
    );
  }
}
