import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_dab_sequence.dart';
import '../../models/brush_edit_session_cache_operation_result.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_point.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../services/brush_edit_session_cache_operations.dart';
import '../../services/cache_invalidation_executor.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'brush_edit_canvas_view.dart';

class InteractiveBrushEditCanvasView extends StatefulWidget {
  const InteractiveBrushEditCanvasView({
    super.key,
    required this.sessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.cacheInvalidationSink,
    required this.onOperationResult,
    this.showTransparentBackground = true,
  });

  final BrushEditSessionState sessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CacheInvalidationSink cacheInvalidationSink;
  final ValueChanged<BrushEditSessionCacheOperationResult> onOperationResult;
  final bool showTransparentBackground;

  @override
  State<InteractiveBrushEditCanvasView> createState() =>
      _InteractiveBrushEditCanvasViewState();
}

class _InteractiveBrushEditCanvasViewState
    extends State<InteractiveBrushEditCanvasView> {
  int? _activePointer;
  var _nextSequence = 0;
  final List<BrushDab> _collectedDabs = <BrushDab>[];

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey<String>(
        'interactive-brush-edit-canvas-view-listener',
      ),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: BrushEditCanvasView(
        sessionState: widget.sessionState,
        showTransparentBackground: widget.showTransparentBackground,
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null || !_isInsideSurface(event.localPosition)) {
      return;
    }

    _activePointer = event.pointer;
    _nextSequence = 0;
    _collectedDabs
      ..clear()
      ..add(_dabFromPosition(event.localPosition));
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer ||
        !_isInsideSurface(event.localPosition)) {
      return;
    }

    _collectedDabs.add(_dabFromPosition(event.localPosition));
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    if (_collectedDabs.isNotEmpty) {
      final result =
          commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
            sessionState: widget.sessionState,
            sequence: BrushDabSequence(_collectedDabs),
            layerId: widget.layerId,
            frameId: widget.frameId,
            cacheInvalidationSink: widget.cacheInvalidationSink,
          );
      widget.onOperationResult(result);
    }

    _clearStroke();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    _clearStroke();
  }

  bool _isInsideSurface(Offset localPosition) {
    final canvasSize =
        widget.sessionState.canvasState.currentSurface.canvasSize;
    return localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx < canvasSize.width &&
        localPosition.dy < canvasSize.height;
  }

  BrushDab _dabFromPosition(Offset localPosition) {
    final settings = widget.inputSettings;
    return BrushDab(
      center: CanvasPoint(x: localPosition.dx, y: localPosition.dy),
      color: settings.color,
      size: settings.size,
      opacity: settings.opacity,
      flow: settings.flow,
      hardness: settings.hardness,
      tipShape: settings.tipShape,
      pressure: 1.0,
      sequence: _nextSequence++,
    );
  }

  void _clearStroke() {
    _activePointer = null;
    _nextSequence = 0;
    _collectedDabs.clear();
  }
}
