import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_point.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../services/brush_dab_interpolator.dart';
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
    this.committedSourceDabStrokes = const <List<BrushDab>>[],
    this.dabInterpolator = const BrushDabInterpolator(),
    this.showTransparentBackground = true,
  });

  final BrushEditSessionState sessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final ValueChanged<List<BrushDab>> onSourceStrokeCommitted;
  final List<BrushDab> committedSourceDabs;
  final List<List<BrushDab>> committedSourceDabStrokes;
  final bool showTransparentBackground;
  final BrushDabInterpolator dabInterpolator;

  @override
  State<InteractiveBrushEditCanvasView> createState() =>
      _InteractiveBrushEditCanvasViewState();
}

class _InteractiveBrushEditCanvasViewState
    extends State<InteractiveBrushEditCanvasView> {
  int? _activePointer;
  var _nextSequence = 0;
  final List<BrushDab> _collectedDabs = <BrushDab>[];
  final List<BrushDab> _liveOverlayDabs = <BrushDab>[];
  Path? _liveStrokePath;
  BrushDab? _liveStrokePathDab;
  var _liveStrokePathVersion = 0;

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
        committedSourceDabStrokes: widget.committedSourceDabStrokes,
        activeStrokeOverlay: List<BrushDab>.unmodifiable(_liveOverlayDabs),
        activeStrokePath: _liveStrokePath,
        activeStrokePathDab: _liveStrokePathDab,
        activeStrokePathVersion: _liveStrokePathVersion,
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
      final initialDabs = widget.dabInterpolator.interpolate(
        previous: null,
        nextRaw: _dabFromPosition(
          event.localPosition,
          sequence: _nextSequence,
        ),
        firstSequence: _nextSequence,
      );
      _collectedDabs
        ..clear()
        ..addAll(initialDabs);
      _liveOverlayDabs
        ..clear()
        ..addAll(initialDabs);
      _resetLiveStrokePath(initialDabs);
      _nextSequence = _collectedDabs.length;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer ||
        !_isInsideSurface(event.localPosition)) {
      return;
    }

    final previousDab = _collectedDabs.isEmpty ? null : _collectedDabs.last;
    final nextDabs = widget.dabInterpolator.interpolate(
      previous: previousDab,
      nextRaw: _dabFromPosition(event.localPosition, sequence: _nextSequence),
      firstSequence: _nextSequence,
    );
    if (nextDabs.isEmpty) {
      return;
    }

    setState(() {
      _collectedDabs.addAll(nextDabs);
      _liveOverlayDabs
        ..clear()
        ..addAll(_liveOverlayForLatestDab(nextDabs));
      _extendLiveStrokePath(previousDab, nextDabs);
      _nextSequence += nextDabs.length;
    });
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

  List<BrushDab> _liveOverlayForLatestDab(List<BrushDab> nextDabs) {
    if (nextDabs.isEmpty) {
      return const <BrushDab>[];
    }

    return <BrushDab>[nextDabs.last];
  }

  void _resetLiveStrokePath(List<BrushDab> dabs) {
    _liveStrokePath = null;
    _liveStrokePathDab = null;
    if (dabs.isEmpty) {
      _liveStrokePathVersion += 1;
      return;
    }

    final firstDab = dabs.first;
    final path = Path()..moveTo(firstDab.center.x, firstDab.center.y);
    for (final dab in dabs.skip(1)) {
      path.lineTo(dab.center.x, dab.center.y);
    }
    _liveStrokePath = path;
    _liveStrokePathDab = firstDab;
    _liveStrokePathVersion += 1;
  }

  void _extendLiveStrokePath(BrushDab? previousDab, List<BrushDab> nextDabs) {
    if (nextDabs.isEmpty) {
      return;
    }

    final path = _liveStrokePath ?? Path();
    if (_liveStrokePath == null) {
      final startDab = previousDab ?? nextDabs.first;
      path.moveTo(startDab.center.x, startDab.center.y);
    }
    for (final dab in nextDabs) {
      path.lineTo(dab.center.x, dab.center.y);
    }
    _liveStrokePath = path;
    _liveStrokePathDab = _liveStrokePathDab ?? previousDab ?? nextDabs.first;
    _liveStrokePathVersion += 1;
  }

  BrushDab _dabFromPosition(Offset localPosition, {required int sequence}) {
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
      sequence: sequence,
    );
  }

  void _clearStroke() {
    setState(() {
      _activePointer = null;
      _nextSequence = 0;
      _collectedDabs.clear();
      _liveOverlayDabs.clear();
      _liveStrokePath = null;
      _liveStrokePathDab = null;
      _liveStrokePathVersion += 1;
    });
  }
}
