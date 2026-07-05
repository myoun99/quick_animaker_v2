import 'dart:async';

import 'package:flutter/material.dart';

import '../models/brush_preset.dart';
import '../models/brush_preset_id.dart';
import '../models/canvas_viewport.dart';
import '../services/brush_preset_file_service.dart';
import 'brush/brush_settings_panel.dart';
import 'brush/brush_tool_state.dart';
import 'brush/main_canvas_brush_host.dart';
import 'editor_session_manager.dart';
import 'panels/editor_panel_dock.dart';

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
class EditorCanvasArea extends StatefulWidget {
  const EditorCanvasArea({super.key, required this.session, this.presetFileService});

  final EditorSessionManager session;

  /// Injectable preset persistence; defaults to the app-data preset file.
  final BrushPresetFileService? presetFileService;

  @override
  State<EditorCanvasArea> createState() => _EditorCanvasAreaState();
}

class _EditorCanvasAreaState extends State<EditorCanvasArea> {
  CanvasViewport _canvasViewport = CanvasViewport();
  BrushToolState _brushToolState = BrushToolState.defaults;
  late final BrushPresetFileService _presetFileService =
      widget.presetFileService ?? BrushPresetFileService();
  List<BrushPreset> _brushPresets = const <BrushPreset>[];

  @override
  void initState() {
    super.initState();
    _presetFileService.loadOrDefaults().then((presets) {
      if (mounted) {
        setState(() => _brushPresets = presets);
      }
    });
  }

  void _applyPreset(BrushPreset preset) {
    setState(() {
      _brushToolState = BrushToolState.fromBrushSettings(preset.settings);
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
    });
    _persistPresets();
  }

  void _deletePreset(BrushPresetId id) {
    setState(() {
      _brushPresets = [
        for (final preset in _brushPresets)
          if (preset.id != id) preset,
      ];
    });
    _persistPresets();
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
    unawaited(
      _presetFileService.save(_brushPresets).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFBDBDBD)),
              ),
              child: RepaintBoundary(
                child: KeyedSubtree(
                  key: const ValueKey<String>(
                    'main-canvas-brush-host-container',
                  ),
                  child: MainCanvasBrushHost(
                    selection: session.activeBrushEditorSelection,
                    canvasSize: session.activeCut.canvasSize,
                    historyManager: session.historyManager,
                    viewport: _canvasViewport,
                    onViewportChanged: (viewport) {
                      setState(() => _canvasViewport = viewport);
                    },
                    selectionLabels: session.canvasSelectionLabels,
                    brushToolState: _brushToolState,
                  ),
                ),
              ),
            ),
          ),
        ),
        EditorPanelDock(
          children: [
            BrushSettingsPanel(
              state: _brushToolState,
              onChanged: (state) {
                setState(() => _brushToolState = state);
              },
              presets: _brushPresets,
              onPresetApplied: _applyPreset,
              onPresetSaveRequested: _saveCurrentAsPreset,
              onPresetDeleted: _deletePreset,
            ),
          ],
        ),
      ],
    );
  }
}
