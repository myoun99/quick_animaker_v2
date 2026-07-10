import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_dab_sequence.dart';
import '../../models/brush_paint_command.dart';
import '../../models/brush_paint_command_id.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import 'dart:math' as math;

import '../../services/bitmap_surface_brush_commit.dart';
import '../../services/canvas_selection.dart';
import '../brush/canvas_selection_commands.dart';
import 'bitmap_surface_painter.dart';
import 'viewport_canvas_transform.dart';

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

enum _DragMode { none, marquee, move, transform }

/// Which part of the Ctrl+T box a drag grabbed.
enum _TransformHandle {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  topEdge,
  rightEdge,
  bottomEdge,
  leftEdge,
  rotate,
  inside,
}

/// The grabbed handle's BASE-LOCAL coordinates (relative to the base box
/// center = the affine pivot); null for rotate/inside.
CanvasPoint? _handleLocal(_TransformHandle handle, double w, double h) {
  switch (handle) {
    case _TransformHandle.topLeft:
      return CanvasPoint(x: -w / 2, y: -h / 2);
    case _TransformHandle.topRight:
      return CanvasPoint(x: w / 2, y: -h / 2);
    case _TransformHandle.bottomRight:
      return CanvasPoint(x: w / 2, y: h / 2);
    case _TransformHandle.bottomLeft:
      return CanvasPoint(x: -w / 2, y: h / 2);
    case _TransformHandle.topEdge:
      return CanvasPoint(x: 0, y: -h / 2);
    case _TransformHandle.rightEdge:
      return CanvasPoint(x: w / 2, y: 0);
    case _TransformHandle.bottomEdge:
      return CanvasPoint(x: 0, y: h / 2);
    case _TransformHandle.leftEdge:
      return CanvasPoint(x: -w / 2, y: 0);
    case _TransformHandle.rotate:
    case _TransformHandle.inside:
      return null;
  }
}

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

  // Ctrl+T free-transform session (P9b): the composite affine, the base
  // box it manipulates (the shape's AABB at session start; its center is
  // the affine pivot) and the per-drag solving context.
  SelectionAffine? _transform;
  double _baseBoxWidth = 0;
  double _baseBoxHeight = 0;
  _TransformHandle? _transformDragHandle;
  SelectionAffine? _transformDragStart;
  CanvasPoint? _transformDragStartPointer;
  double _transformLastAngle = 0;

  /// Screen-space hit slack around a handle (≥ touch-friendly).
  static const double _handleHitRadius = 16;

  /// How far the rotate knob sticks out of the top edge, screen pixels.
  static const double _rotateLeverLength = 28;

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
      transformActive: () => _transform != null,
      beginTransform: _beginTransform,
      commitTransform: _commitTransform,
      cancelTransform: _cancelTransform,
    );
  }

  void _resetAll() {
    setState(() {
      _shape = null;
      _selectedIds = const {};
      _clearTransform();
      _cancelDrag(notify: _dragMode != _DragMode.none);
    });
    _syncAnts();
  }

  void _clearTransform() {
    _transform = null;
    _baseBoxWidth = 0;
    _baseBoxHeight = 0;
    _transformDragHandle = null;
    _transformDragStart = null;
    _transformDragStartPointer = null;
    _floatSurface = null;
  }

  /// Ctrl+T: opens the free-transform box on the live selection.
  void _beginTransform() {
    final shape = _shape;
    if (shape == null || _selectedIds.isEmpty || _transform != null) {
      return;
    }
    var minX = shape.points.first.x, maxX = shape.points.first.x;
    var minY = shape.points.first.y, maxY = shape.points.first.y;
    for (final point in shape.points.skip(1)) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }
    setState(() {
      _baseBoxWidth = math.max(maxX - minX, 1);
      _baseBoxHeight = math.max(maxY - minY, 1);
      _transform = SelectionAffine(
        pivot: CanvasPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
      );
      _floatSurface = _buildFloatSurface();
    });
    _syncAnts();
  }

  /// Enter: the open transform as ONE undo entry; identity commits
  /// nothing but still closes the box.
  void _commitTransform() {
    final affine = _transform;
    final shape = _shape;
    if (affine == null || shape == null) {
      return;
    }
    if (!affine.isIdentity) {
      final before = <BrushPaintCommandId, List<BrushDab>>{};
      final after = <BrushPaintCommandId, List<BrushDab>>{};
      for (final command in widget.visibleCommands()) {
        if (!_selectedIds.contains(command.id)) {
          continue;
        }
        before[command.id] = command.sourceDabs;
        after[command.id] = transformDabs(command.sourceDabs, affine);
      }
      if (after.isNotEmpty) {
        widget.onTransformCommitted((before: before, after: after));
        _shape = transformShape(shape, affine);
      }
    }
    setState(_clearTransform);
    _syncAnts();
  }

  /// Escape: discards the open transform.
  void _cancelTransform() {
    if (_transform == null) {
      return;
    }
    setState(_clearTransform);
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
  /// With an open Ctrl+T session the nudge rides the session's
  /// translation instead (committed with the transform).
  void _nudge(double dx, double dy) {
    final transform = _transform;
    if (transform != null) {
      setState(() {
        _transform = transform.copyWith(
          tx: transform.tx + dx,
          ty: transform.ty + dy,
        );
      });
      return;
    }
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
    final transform = _transform;
    if (transform != null) {
      // Ctrl+T is modal: only the box's handles/inside react; clicks
      // elsewhere are inert until Enter/Escape closes the session.
      final handle = _hitTestTransformHandle(event.localPosition, transform);
      if (handle == null) {
        return;
      }
      _activePointer = event.pointer;
      setState(() {
        _dragMode = _DragMode.transform;
        _transformDragHandle = handle;
        _transformDragStart = transform;
        _transformDragStartPointer = canvasPoint;
        if (handle == _TransformHandle.rotate) {
          _transformLastAngle = _pointerAngleAbout(canvasPoint, transform);
        }
      });
      widget.onDragActiveChanged?.call(true);
      return;
    }
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
      case _DragMode.transform:
        _updateTransformDrag(_toCanvas(event.localPosition));
    }
  }

  void _updateTransformDrag(CanvasPoint pointer) {
    final handle = _transformDragHandle;
    final start = _transformDragStart;
    final startPointer = _transformDragStartPointer;
    if (handle == null || start == null || startPointer == null) {
      return;
    }
    switch (handle) {
      case _TransformHandle.inside:
        setState(() {
          _transform = start.copyWith(
            tx: start.tx + pointer.x - startPointer.x,
            ty: start.ty + pointer.y - startPointer.y,
          );
        });
      case _TransformHandle.rotate:
        // Wrapped-delta accumulation (the camera lever rule): continuous
        // across the ±180° seam. Canvas-space angles, so the P8 view
        // rotation/flip never skews the feel.
        final current = _transform ?? start;
        final angle = _pointerAngleAbout(pointer, current);
        var delta = angle - _transformLastAngle;
        while (delta > 180) {
          delta -= 360;
        }
        while (delta < -180) {
          delta += 360;
        }
        _transformLastAngle = angle;
        setState(() {
          _transform = current.copyWith(
            rotationDegrees: current.rotationDegrees + delta,
          );
        });
      default:
        setState(() => _transform = _solveScaleDrag(start, handle, pointer));
    }
  }

  /// Solves the scale drag: the grabbed handle lands under the pointer
  /// while the anchor — the OPPOSITE handle, or the center with Alt —
  /// stays fixed (its motion folds into the translation). Shift locks the
  /// aspect on corner handles.
  SelectionAffine _solveScaleDrag(
    SelectionAffine start,
    _TransformHandle handle,
    CanvasPoint pointer,
  ) {
    final grabbed = _handleLocal(handle, _baseBoxWidth, _baseBoxHeight)!;
    final centerPivot = HardwareKeyboard.instance.isAltPressed;
    final anchorLocal = centerPivot
        ? CanvasPoint(x: 0, y: 0)
        : CanvasPoint(x: -grabbed.x, y: -grabbed.y);
    final anchorCanvas = start.apply(
      CanvasPoint(
        x: start.pivot.x + anchorLocal.x,
        y: start.pivot.y + anchorLocal.y,
      ),
    );
    final radians = start.rotationDegrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    // v = R(−θ)·(pointer − anchor): the pointer in the box's local frame.
    final dx = pointer.x - anchorCanvas.x;
    final dy = pointer.y - anchorCanvas.y;
    final vx = dx * cos + dy * sin;
    final vy = -dx * sin + dy * cos;

    var sx = start.sx;
    var sy = start.sy;
    if (grabbed.x != anchorLocal.x) {
      sx = vx / (grabbed.x - anchorLocal.x);
    }
    if (grabbed.y != anchorLocal.y) {
      sy = vy / (grabbed.y - anchorLocal.y);
    }
    if (HardwareKeyboard.instance.isShiftPressed &&
        grabbed.x != anchorLocal.x &&
        grabbed.y != anchorLocal.y) {
      final magnitude = math.max(sx.abs(), sy.abs());
      sx = sx.isNegative ? -magnitude : magnitude;
      sy = sy.isNegative ? -magnitude : magnitude;
    }
    sx = _clampScale(sx);
    sy = _clampScale(sy);

    // Anchor compensation: R·(S_old∘o − S_new∘o) folds into t.
    final dLocalX = start.sx * anchorLocal.x - sx * anchorLocal.x;
    final dLocalY = start.sy * anchorLocal.y - sy * anchorLocal.y;
    return start.copyWith(
      sx: sx,
      sy: sy,
      tx: start.tx + dLocalX * cos - dLocalY * sin,
      ty: start.ty + dLocalX * sin + dLocalY * cos,
    );
  }

  static double _clampScale(double scale) {
    if (scale.isNaN || !scale.isFinite) {
      return 0.01;
    }
    if (scale.abs() < 0.01) {
      return scale.isNegative ? -0.01 : 0.01;
    }
    return scale;
  }

  /// The pointer's canvas-space angle about the transformed box center.
  double _pointerAngleAbout(CanvasPoint pointer, SelectionAffine affine) {
    final center = affine.apply(affine.pivot);
    return math.atan2(pointer.y - center.y, pointer.x - center.x) *
        180 /
        math.pi;
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
      case _DragMode.transform:
        // The session stays open across drags; Enter/Escape close it.
        break;
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

  /// Clears drag bookkeeping (NOT the committed selection, and NOT an
  /// open Ctrl+T session — its float persists between handle drags).
  void _cancelDrag({required bool notify}) {
    final wasDragging = _dragMode != _DragMode.none;
    _dragMode = _DragMode.none;
    _activePointer = null;
    _marqueeStart = null;
    _marqueeCurrent = null;
    _lassoPoints = const [];
    _moveScreenDelta = Offset.zero;
    _transformDragHandle = null;
    _transformDragStart = null;
    _transformDragStartPointer = null;
    if (_transform == null) {
      _floatSurface = null;
    }
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

  /// A base-local point mapped through [affine] into viewport space.
  Offset _mapLocalToViewport(SelectionAffine affine, CanvasPoint local) {
    final canvasPoint = affine.apply(
      CanvasPoint(x: affine.pivot.x + local.x, y: affine.pivot.y + local.y),
    );
    final mapped = widget.viewport.canvasToViewport(canvasPoint);
    return Offset(mapped.x, mapped.y);
  }

  static const List<_TransformHandle> _scaleHandles = [
    _TransformHandle.topLeft,
    _TransformHandle.topRight,
    _TransformHandle.bottomRight,
    _TransformHandle.bottomLeft,
    _TransformHandle.topEdge,
    _TransformHandle.rightEdge,
    _TransformHandle.bottomEdge,
    _TransformHandle.leftEdge,
  ];

  Offset _rotateKnobOffset(SelectionAffine affine) {
    final topMid = _mapLocalToViewport(
      affine,
      CanvasPoint(x: 0, y: -_baseBoxHeight / 2),
    );
    final centerMapped = widget.viewport.canvasToViewport(
      affine.apply(affine.pivot),
    );
    final direction = topMid - Offset(centerMapped.x, centerMapped.y);
    final distance = direction.distance;
    final unit = distance == 0 ? const Offset(0, -1) : direction / distance;
    return topMid + unit * _rotateLeverLength;
  }

  /// The transformed box as a canvas-space polygon (inside = translate).
  CanvasSelectionShape _transformedBoxShape(SelectionAffine affine) {
    return CanvasSelectionShape([
      for (final corner in [
        CanvasPoint(x: -_baseBoxWidth / 2, y: -_baseBoxHeight / 2),
        CanvasPoint(x: _baseBoxWidth / 2, y: -_baseBoxHeight / 2),
        CanvasPoint(x: _baseBoxWidth / 2, y: _baseBoxHeight / 2),
        CanvasPoint(x: -_baseBoxWidth / 2, y: _baseBoxHeight / 2),
      ])
        affine.apply(
          CanvasPoint(
            x: affine.pivot.x + corner.x,
            y: affine.pivot.y + corner.y,
          ),
        ),
    ]);
  }

  _TransformHandle? _hitTestTransformHandle(
    Offset local,
    SelectionAffine affine,
  ) {
    if ((local - _rotateKnobOffset(affine)).distance <= _handleHitRadius) {
      return _TransformHandle.rotate;
    }
    for (final handle in _scaleHandles) {
      final position = _mapLocalToViewport(
        affine,
        _handleLocal(handle, _baseBoxWidth, _baseBoxHeight)!,
      );
      if ((local - position).distance <= _handleHitRadius) {
        return handle;
      }
    }
    if (_transformedBoxShape(affine).containsPoint(_toCanvas(local))) {
      return _TransformHandle.inside;
    }
    return null;
  }

  /// The Ctrl+T preview matrix: the canvas-space affine wrapped into
  /// screen space through the SAME viewport transform painters use.
  Matrix4 _affineScreenMatrix(SelectionAffine affine) {
    final radians = affine.rotationDegrees * math.pi / 180;
    final canvasMatrix =
        Matrix4.translationValues(
            affine.pivot.x + affine.tx,
            affine.pivot.y + affine.ty,
            0,
          )
          ..multiply(Matrix4.rotationZ(radians))
          ..multiply(Matrix4.diagonal3Values(affine.sx, affine.sy, 1))
          ..multiply(
            Matrix4.translationValues(-affine.pivot.x, -affine.pivot.y, 0),
          );
    return viewportTransformMatrix(widget.viewport)
      ..multiply(canvasMatrix)
      ..multiply(viewportInverseTransformMatrix(widget.viewport));
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
    final transform = _transform;
    final shape = _shape;
    // With an open Ctrl+T session the ants show the TRANSFORMED region
    // and the box chrome renders around the transformed base box.
    final displayShape = transform != null && shape != null
        ? transformShape(shape, transform)
        : shape;
    final chrome = transform == null
        ? null
        : (
            box: [
              for (final point in _transformedBoxShape(transform).points)
                _mapCanvasToViewportOffset(point),
            ],
            handles: [
              for (final handle in _scaleHandles)
                _mapLocalToViewport(
                  transform,
                  _handleLocal(handle, _baseBoxWidth, _baseBoxHeight)!,
                ),
            ],
            knob: _rotateKnobOffset(transform),
          );
    return Listener(
      key: const ValueKey<String>('canvas-selection-layer'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Stack(
        children: [
          if (floatSurface != null &&
              (_dragMode == _DragMode.move || transform != null))
            Positioned.fill(
              child: IgnorePointer(
                child: Transform(
                  transform: transform != null
                      ? _affineScreenMatrix(transform)
                      : Matrix4.translationValues(
                          _moveScreenDelta.dx,
                          _moveScreenDelta.dy,
                          0,
                        ),
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
                  committedShape: displayShape,
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
                  transformChrome: chrome,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _mapCanvasToViewportOffset(CanvasPoint point) {
    final mapped = widget.viewport.canvasToViewport(point);
    return Offset(mapped.x, mapped.y);
  }
}

/// The Ctrl+T box chrome in viewport space: the transformed box outline,
/// the 8 scale handles and the rotate knob.
typedef _TransformChrome = ({
  List<Offset> box,
  List<Offset> handles,
  Offset knob,
});

/// Marching ants: dashed outlines whose dash phase rides the animation.
class _SelectionAntsPainter extends CustomPainter {
  _SelectionAntsPainter({
    required Animation<double> repaint,
    required this.viewport,
    required this.committedShape,
    required this.screenOffset,
    required this.marqueeShape,
    required this.lassoTrail,
    this.transformChrome,
  }) : _phase = repaint,
       super(repaint: repaint);

  final Animation<double> _phase;
  final CanvasViewport viewport;
  final CanvasSelectionShape? committedShape;
  final Offset screenOffset;
  final CanvasSelectionShape? marqueeShape;
  final List<CanvasPoint> lassoTrail;
  final _TransformChrome? transformChrome;

  static const Color _chromeColor = Color(0xFF40C4FF);

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

    final chrome = transformChrome;
    if (chrome != null) {
      _paintTransformChrome(canvas, chrome);
    }
  }

  void _paintTransformChrome(Canvas canvas, _TransformChrome chrome) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _chromeColor;
    final fill = Paint()..color = _chromeColor;

    canvas.drawPath(Path()..addPolygon(chrome.box, true), stroke);
    for (final handle in chrome.handles) {
      canvas.drawRect(
        Rect.fromCenter(center: handle, width: 9, height: 9),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromCenter(center: handle, width: 9, height: 9),
        stroke,
      );
    }
    // The rotate lever: line from the top edge midpoint to the knob.
    final topMid = Offset(
      (chrome.box[0].dx + chrome.box[1].dx) / 2,
      (chrome.box[0].dy + chrome.box[1].dy) / 2,
    );
    canvas.drawLine(topMid, chrome.knob, stroke);
    canvas.drawCircle(chrome.knob, 5, fill);
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
      oldDelegate.lassoTrail != lassoTrail ||
      oldDelegate.transformChrome != transformChrome;
}
