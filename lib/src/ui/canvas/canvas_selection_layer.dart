import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_dab_sequence.dart';
import '../../models/brush_paint_command.dart';
import '../../models/brush_paint_command_id.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../services/bitmap_surface_brush_commit.dart';
import '../../services/canvas_selection.dart';
import '../brush/canvas_selection_commands.dart';
import 'bitmap_surface_painter.dart';

/// One committed selection move: the affected commands' dabs before and
/// after (the app-level undo payload).
typedef CanvasSelectionTransform = ({
  Map<BrushPaintCommandId, List<BrushDab>> before,
  Map<BrushPaintCommandId, List<BrushDab>> after,
});

/// The P9 selection interaction layer, mounted over the canvas while a
/// selection tool is active (Photoshop/CSP language):
///
/// - Dragging on empty ground draws a NEW region — rectangle marquee or
///   freehand lasso — shown as marching ants; commands join by the
///   dab-center majority rule.
/// - Dragging INSIDE the region moves the selection: the selected strokes
///   float live (rendered from their own dabs) and the release commits
///   ONE undoable in-place rewrite.
/// - A click (degenerate drag) deselects; Ctrl+D and arrow nudges arrive
///   through [selectionCommands].
///
/// All region geometry lives in CANVAS coordinates, so the ants stay
/// glued to the artwork through pan/zoom/rotation.
class CanvasSelectionLayer extends StatefulWidget {
  const CanvasSelectionLayer({
    super.key,
    required this.tool,
    required this.viewport,
    required this.canvasSize,
    required this.frameToken,
    required this.visibleCommands,
    required this.onTransformCommitted,
    this.selectionCommands,
    this.onDragActiveChanged,
  });

  /// Which selection tool draws new regions (selectRect or lasso).
  final CanvasSelectionTool tool;

  final CanvasViewport viewport;
  final CanvasSize canvasSize;

  /// Changes when the edited frame changes — the selection resets (a
  /// region has no meaning on another frame's strokes).
  final Object frameToken;

  /// The frame's visible commands, read fresh at selection/commit time.
  final List<BrushPaintCommand> Function() visibleCommands;

  /// The finished move as before/after dab maps; the host wraps it into
  /// the app-level history command.
  final void Function(CanvasSelectionTransform transform) onTransformCommitted;

  final CanvasSelectionCommands? selectionCommands;

  /// Raised while a selection drag is in progress (the panel holds
  /// viewport gestures exactly like during a stroke).
  final ValueChanged<bool>? onDragActiveChanged;

  @override
  State<CanvasSelectionLayer> createState() => _CanvasSelectionLayerState();
}

enum CanvasSelectionTool { rect, lasso }

enum _DragMode { none, marquee, move }

class _CanvasSelectionLayerState extends State<CanvasSelectionLayer>
    with SingleTickerProviderStateMixin {
  CanvasSelectionShape? _shape;
  Set<BrushPaintCommandId> _selectedIds = const {};

  _DragMode _dragMode = _DragMode.none;
  int? _activePointer;

  // Marquee-in-progress (canvas space).
  CanvasPoint? _marqueeStart;
  CanvasPoint? _marqueeCurrent;
  List<CanvasPoint> _lassoPoints = const [];

  // Move-in-progress: screen-space delta + the floating copy of the
  // selected strokes (built once at drag start).
  Offset _moveScreenDelta = Offset.zero;
  BitmapSurface? _floatSurface;

  late final AnimationController _ants = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  bool get _hasSelection => _shape != null;

  @override
  void initState() {
    super.initState();
    _bindCommands();
  }

  @override
  void didUpdateWidget(covariant CanvasSelectionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.selectionCommands, widget.selectionCommands)) {
      oldWidget.selectionCommands?.unbind();
      _bindCommands();
    }
    if (oldWidget.frameToken != widget.frameToken) {
      _resetAll();
    }
  }

  @override
  void dispose() {
    widget.selectionCommands?.unbind();
    if (_dragMode != _DragMode.none) {
      widget.onDragActiveChanged?.call(false);
    }
    _ants.dispose();
    super.dispose();
  }

  void _bindCommands() {
    widget.selectionCommands?.bind(
      hasSelection: () => _hasSelection,
      nudge: _nudge,
      deselect: _deselect,
    );
  }

  void _resetAll() {
    setState(() {
      _shape = null;
      _selectedIds = const {};
      _cancelDrag(notify: _dragMode != _DragMode.none);
    });
    _syncAnts();
  }

  void _syncAnts() {
    final animate = _hasSelection || _dragMode == _DragMode.marquee;
    if (animate && !_ants.isAnimating) {
      _ants.repeat();
    } else if (!animate && _ants.isAnimating) {
      _ants.stop();
    }
  }

  void _deselect() {
    if (!_hasSelection && _dragMode == _DragMode.none) {
      return;
    }
    _resetAll();
  }

  /// Arrow nudge: one canvas pixel per call, one undo entry per call.
  void _nudge(double dx, double dy) {
    final shape = _shape;
    if (shape == null || _selectedIds.isEmpty) {
      return;
    }
    _commitMove(dx: dx, dy: dy);
  }

  CanvasPoint _toCanvas(Offset local) =>
      widget.viewport.viewportToCanvas(ViewportPoint(x: local.dx, y: local.dy));

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      // A second TOUCH is the navigate signal (same rule as strokes):
      // cancel the selection drag and let the gesture layer take over.
      if (event.kind == PointerDeviceKind.touch &&
          _dragMode != _DragMode.none) {
        setState(() => _cancelDrag(notify: true));
        _syncAnts();
      }
      return;
    }
    if (event.buttons != kPrimaryButton &&
        event.kind != PointerDeviceKind.touch) {
      return;
    }
    final canvasPoint = _toCanvas(event.localPosition);
    _activePointer = event.pointer;
    final shape = _shape;
    if (shape != null &&
        _selectedIds.isNotEmpty &&
        shape.containsPoint(canvasPoint)) {
      setState(() {
        _dragMode = _DragMode.move;
        _moveScreenDelta = Offset.zero;
        _floatSurface = _buildFloatSurface();
      });
    } else {
      setState(() {
        _dragMode = _DragMode.marquee;
        _shape = null;
        _selectedIds = const {};
        _marqueeStart = canvasPoint;
        _marqueeCurrent = canvasPoint;
        _lassoPoints = [canvasPoint];
      });
    }
    widget.onDragActiveChanged?.call(true);
    _syncAnts();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    switch (_dragMode) {
      case _DragMode.none:
        return;
      case _DragMode.marquee:
        setState(() {
          final canvasPoint = _toCanvas(event.localPosition);
          _marqueeCurrent = canvasPoint;
          if (widget.tool == CanvasSelectionTool.lasso) {
            _lassoPoints = [..._lassoPoints, canvasPoint];
          }
        });
      case _DragMode.move:
        setState(() => _moveScreenDelta += event.delta);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    switch (_dragMode) {
      case _DragMode.none:
        break;
      case _DragMode.marquee:
        _finishMarquee();
      case _DragMode.move:
        _finishMove();
    }
    setState(() => _cancelDrag(notify: true));
    _syncAnts();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    setState(() => _cancelDrag(notify: true));
    _syncAnts();
  }

  /// Clears drag bookkeeping (NOT the committed selection).
  void _cancelDrag({required bool notify}) {
    final wasDragging = _dragMode != _DragMode.none;
    _dragMode = _DragMode.none;
    _activePointer = null;
    _marqueeStart = null;
    _marqueeCurrent = null;
    _lassoPoints = const [];
    _moveScreenDelta = Offset.zero;
    _floatSurface = null;
    if (notify && wasDragging) {
      widget.onDragActiveChanged?.call(false);
    }
  }

  void _finishMarquee() {
    final shape = _marqueeShape();
    if (shape == null) {
      // A click (degenerate region) deselects — Photoshop's click-away.
      _shape = null;
      _selectedIds = const {};
      return;
    }
    _shape = shape;
    _selectedIds = selectCommandIdsInShape(
      commands: widget.visibleCommands(),
      shape: shape,
    );
  }

  /// The in-progress or final marquee polygon; null while degenerate.
  CanvasSelectionShape? _marqueeShape() {
    if (widget.tool == CanvasSelectionTool.lasso) {
      if (_lassoPoints.length < 3) {
        return null;
      }
      return CanvasSelectionShape(_lassoPoints);
    }
    final start = _marqueeStart;
    final current = _marqueeCurrent;
    if (start == null || current == null) {
      return null;
    }
    if ((current.x - start.x).abs() < 2 && (current.y - start.y).abs() < 2) {
      return null;
    }
    return CanvasSelectionShape.rect(
      left: start.x,
      top: start.y,
      right: current.x,
      bottom: current.y,
    );
  }

  void _finishMove() {
    if (_moveScreenDelta == Offset.zero) {
      return;
    }
    final canvasDelta = widget.viewport.viewportDeltaToCanvasDelta(
      dx: _moveScreenDelta.dx,
      dy: _moveScreenDelta.dy,
    );
    _commitMove(dx: canvasDelta.x, dy: canvasDelta.y);
  }

  void _commitMove({required double dx, required double dy}) {
    final shape = _shape;
    if (shape == null || (dx == 0 && dy == 0)) {
      return;
    }
    final before = <BrushPaintCommandId, List<BrushDab>>{};
    final after = <BrushPaintCommandId, List<BrushDab>>{};
    for (final command in widget.visibleCommands()) {
      if (!_selectedIds.contains(command.id)) {
        continue;
      }
      before[command.id] = command.sourceDabs;
      after[command.id] = translateDabs(command.sourceDabs, dx: dx, dy: dy);
    }
    if (after.isEmpty) {
      return;
    }
    widget.onTransformCommitted((before: before, after: after));
    setState(() => _shape = shape.translated(dx: dx, dy: dy));
  }

  /// The selected strokes rendered alone (the live float shown while
  /// moving) — command replay order, so overlaps look exactly like the
  /// committed picture.
  BitmapSurface _buildFloatSurface() {
    var surface = BitmapSurface(canvasSize: widget.canvasSize);
    for (final command in widget.visibleCommands()) {
      if (!_selectedIds.contains(command.id) || command.sourceDabs.isEmpty) {
        continue;
      }
      surface = materializeBrushDabSequenceOnBitmapSurface(
        surface: surface,
        sequence: BrushDabSequence(command.sourceDabs),
      ).surface;
    }
    return surface;
  }

  @override
  Widget build(BuildContext context) {
    final floatSurface = _floatSurface;
    return Listener(
      key: const ValueKey<String>('canvas-selection-layer'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Stack(
        children: [
          if (floatSurface != null && _dragMode == _DragMode.move)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: _moveScreenDelta,
                  child: CustomPaint(
                    painter: BitmapSurfacePainter(
                      surface: floatSurface,
                      viewport: widget.viewport,
                      showTransparentBackground: false,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SelectionAntsPainter(
                  repaint: _ants,
                  viewport: widget.viewport,
                  committedShape: _shape,
                  screenOffset: _dragMode == _DragMode.move
                      ? _moveScreenDelta
                      : Offset.zero,
                  marqueeShape: _dragMode == _DragMode.marquee
                      ? _marqueeShape()
                      : null,
                  lassoTrail:
                      _dragMode == _DragMode.marquee &&
                          widget.tool == CanvasSelectionTool.lasso
                      ? _lassoPoints
                      : const [],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marching ants: dashed outlines whose dash phase rides the animation.
class _SelectionAntsPainter extends CustomPainter {
  _SelectionAntsPainter({
    required Animation<double> repaint,
    required this.viewport,
    required this.committedShape,
    required this.screenOffset,
    required this.marqueeShape,
    required this.lassoTrail,
  }) : _phase = repaint,
       super(repaint: repaint);

  final Animation<double> _phase;
  final CanvasViewport viewport;
  final CanvasSelectionShape? committedShape;
  final Offset screenOffset;
  final CanvasSelectionShape? marqueeShape;
  final List<CanvasPoint> lassoTrail;

  static const double _dashOn = 5;
  static const double _dashOff = 4;

  Offset _map(CanvasPoint point) {
    final mapped = viewport.canvasToViewport(point);
    return Offset(mapped.x, mapped.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final phase = _phase.value * (_dashOn + _dashOff);

    void paintShape(CanvasSelectionShape shape, Offset offset) {
      final path = Path();
      final points = shape.points;
      path.moveTo(
        _map(points.first).dx + offset.dx,
        _map(points.first).dy + offset.dy,
      );
      for (final point in points.skip(1)) {
        final mapped = _map(point);
        path.lineTo(mapped.dx + offset.dx, mapped.dy + offset.dy);
      }
      path.close();
      _paintAnts(canvas, path, phase);
    }

    final committed = committedShape;
    if (committed != null) {
      paintShape(committed, screenOffset);
    }
    final marquee = marqueeShape;
    if (marquee != null) {
      paintShape(marquee, Offset.zero);
    } else if (lassoTrail.length >= 2) {
      // Lasso still too short to close: show the raw trail.
      final path = Path()
        ..moveTo(_map(lassoTrail.first).dx, _map(lassoTrail.first).dy);
      for (final point in lassoTrail.skip(1)) {
        final mapped = _map(point);
        path.lineTo(mapped.dx, mapped.dy);
      }
      _paintAnts(canvas, path, phase);
    }
  }

  /// White under-stroke + phase-offset black dashes = ants readable on any
  /// artwork.
  void _paintAnts(Canvas canvas, Path path, double phase) {
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white;
    final black = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black;
    canvas.drawPath(path, white);
    canvas.drawPath(_dashPath(path, phase), black);
  }

  Path _dashPath(Path source, double phase) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = -phase % (_dashOn + _dashOff);
      while (distance < metric.length) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + _dashOn).clamp(0.0, metric.length);
        if (end > start) {
          dashed.addPath(metric.extractPath(start, end), Offset.zero);
        }
        distance += _dashOn + _dashOff;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant _SelectionAntsPainter oldDelegate) =>
      oldDelegate.viewport != viewport ||
      oldDelegate.committedShape != committedShape ||
      oldDelegate.screenOffset != screenOffset ||
      oldDelegate.marqueeShape != marqueeShape ||
      oldDelegate.lassoTrail != lassoTrail;
}
