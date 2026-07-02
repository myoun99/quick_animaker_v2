import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_point.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'brush_edit_canvas_view.dart';

class InteractiveBrushEditCanvasView extends StatefulWidget {
  const InteractiveBrushEditCanvasView({
    super.key,
    required this.sessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.onSourceStrokeCommitted,
    this.committedSourceDabs = const <BrushDab>[],
    this.showTransparentBackground = true,
  });

  final BrushEditSessionState sessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final ValueChanged<List<BrushDab>> onSourceStrokeCommitted;
  final List<BrushDab> committedSourceDabs;
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
        committedSourceDabs: widget.committedSourceDabs,
        activeStrokeOverlay: List<BrushDab>.unmodifiable(_collectedDabs),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null || !_isInsideSurface(event.localPosition)) {
      return;
    }

    _activePointer = event.pointer;
    _nextSequence = 0;
    setState(() {
      _collectedDabs
        ..clear()
        ..add(_dabFromPosition(event.localPosition));
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer ||
        !_isInsideSurface(event.localPosition)) {
      return;
    }

    setState(() => _collectedDabs.add(_dabFromPosition(event.localPosition)));
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    if (_collectedDabs.isNotEmpty) {
      widget.onSourceStrokeCommitted(
        List<BrushDab>.unmodifiable(_collectedDabs),
      );
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
    setState(() {
      _activePointer = null;
      _nextSequence = 0;
      _collectedDabs.clear();
    });
  }
}
