import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_paint_command.dart';
import '../../models/canvas_size.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/cache_invalidation_executor.dart';
import '../canvas/brush_edit_canvas_input_settings.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import 'brush_canvas_defaults.dart';

/// Reusable Brush canvas panel for the production main-canvas brush route.
///
/// This widget is route-agnostic and behaves as an embedded canvas panel for
/// the main editor canvas area. Temporary debug controls are intentionally not
/// part of this panel.
class BrushCanvasPanel extends StatefulWidget {
  const BrushCanvasPanel({
    super.key,
    required this.coordinator,
    required this.availableFrameKeys,
    required this.cacheInvalidationSink,
    this.canvasSize = BrushCanvasDefaults.canvasSize,
    this.initialInputSettings = const BrushEditCanvasInputSettings(size: 10),
  });

  final BrushFrameEditingCoordinator coordinator;
  final List<BrushFrameKey> availableFrameKeys;
  final CacheInvalidationSink cacheInvalidationSink;
  final CanvasSize canvasSize;
  final BrushEditCanvasInputSettings initialInputSettings;

  @override
  State<BrushCanvasPanel> createState() => _BrushCanvasPanelState();
}

class _BrushCanvasPanelState extends State<BrushCanvasPanel> {
  late final _inputSettings = widget.initialInputSettings;

  @override
  Widget build(BuildContext context) {
    final activeKey = widget.coordinator.activeFrameKey;
    final session = widget.coordinator.activeSessionState;
    final displayPreviewSurface = widget.coordinator.frameStore
        .validPreviewSurfaceOrNull(activeKey);
    final visibleCommands = displayPreviewSurface == null
        ? widget.coordinator.frameStore
            .getOrCreateFrame(activeKey)
            .visibleActivePaintCommands
        : const <BrushPaintCommand>[];
    final committedSourceDabStrokes = visibleCommands
        .map((command) => command.sourceDabs)
        .where((dabs) => dabs.isNotEmpty)
        .toList(growable: false);
    final committedSourceDabs = committedSourceDabStrokes
        .expand((dabs) => dabs)
        .toList(growable: false);

    return Padding(
      key: const ValueKey<String>('brush-canvas-panel'),
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: SizedBox(
          width: widget.canvasSize.width.toDouble(),
          height: widget.canvasSize.height.toDouble(),
          child: InteractiveBrushEditCanvasView(
            key: ValueKey<String>('brush-canvas-${activeKey.frameId.value}'),
            sessionState: session,
            layerId: activeKey.layerId,
            frameId: activeKey.frameId,
            inputSettings: _inputSettings,
            committedSourceDabs: committedSourceDabs,
            committedSourceDabStrokes: committedSourceDabStrokes,
            displayPreviewSurface: displayPreviewSurface,
            onSourceStrokeCommitted: _handleSourceStrokeCommitted,
          ),
        ),
      ),
    );
  }

  void _handleSourceStrokeCommitted(List<BrushDab> sourceDabs) {
    setState(() {
      widget.coordinator.commitSourceStroke(sourceDabs: sourceDabs);
    });
  }
}
