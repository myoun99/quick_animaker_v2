import 'package:flutter/material.dart';

import '../models/canvas_viewport.dart';
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
///
/// Model-derived inputs are read from [session]; the host rebuilds this widget
/// when the session notifies.
class EditorCanvasArea extends StatefulWidget {
  const EditorCanvasArea({super.key, required this.session});

  final EditorSessionManager session;

  @override
  State<EditorCanvasArea> createState() => _EditorCanvasAreaState();
}

class _EditorCanvasAreaState extends State<EditorCanvasArea> {
  CanvasViewport _canvasViewport = CanvasViewport();
  BrushToolState _brushToolState = BrushToolState.defaults;

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
            ),
          ],
        ),
      ],
    );
  }
}
