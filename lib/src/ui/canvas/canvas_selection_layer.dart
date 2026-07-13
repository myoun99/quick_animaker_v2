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
    this.onShapeCommitted,
    this.selectionCommands,
    this.onDragActiveChanged,
    this.onLiftRequested,
    this.onLiftDabsRewritten,
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

  /// A committed region change — marquee release, click-away, Ctrl+D —
  /// as (before, after); the host wraps it into the selection-shape
  /// history command (R11-⑧: selecting is undoable). Null applies changes
  /// directly with no history (focused tests).
  final void Function(
    CanvasSelectionShape? before,
    CanvasSelectionShape? after,
  )?
  onShapeCommitted;

  final CanvasSelectionCommands? selectionCommands;

  /// Raised while a selection drag is in progress (the panel holds
  /// viewport gestures exactly like during a stroke).
  final ValueChanged<bool>? onDragActiveChanged;

  /// R14-④/R15-④ bitmap lift: called ONCE per selection shape when the
  /// Move tool first drags (or nudges) it. The host commits the shape's
  /// ERASE (origin pixels vanish immediately) and returns that command's
  /// id plus the lifted STAMP dab, which the layer floats during the drag
  /// and lands into the command at release — so the original is never
  /// visible while moving and a cancelled/zero drag restores it exactly.
  /// Null return = the shape covers no pixels: the move is a no-op.
  /// Without this callback the layer keeps the legacy whole-stroke move
  /// (focused tests).
  final ({BrushPaintCommandId commandId, BrushDab stampDab})? Function(
    CanvasSelectionShape shape,
  )?
  onLiftRequested;

  /// Raw dab rewrite on the lift command (no history entry) — the drag
  /// lifecycle uses it to suppress/restore the stamp while floating.
  final void Function(BrushPaintCommandId commandId, List<BrushDab> dabs)?
  onLiftDabsRewritten;

  @override
  State<CanvasSelectionLayer> createState() => _CanvasSelectionLayerState();
}

/// The layer's interaction mode: the marquee tools DRAW regions, the MOVE
/// tool drags the selected content (R11-⑧: selection and move are
/// separate tools — a marquee drag never moves strokes anymore).
enum CanvasSelectionTool { rect, lasso, move }

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

  /// True from a USER selection (marquee commit, shape channel apply)
  /// until its first Move interaction lifts the pixels; move/transform
  /// commits keep it false so a lifted stamp never re-lifts itself.
  bool _shapeNeedsLift = false;

  /// The lift command owning this selection's pixels (R15-④), the stamp
  /// dab currently FLOATING (removed from the command while dragging so
  /// the base never shows it — no double image), and the command's dabs
  /// as they stood before the gesture (the history command's `before`,
  /// and the cancel restore target).
  BrushPaintCommandId? _liftCommandId;
  BrushDab? _pendingLiftStamp;
  List<BrushDab>? _liftBeforeDabs;

  BrushPaintCommand? _liftCommand() {
    final id = _liftCommandId;
    if (id == null) {
      return null;
    }
    for (final command in widget.visibleCommands()) {
      if (command.id == id) {
        return command;
      }
    }
    return null;
  }

  void _clearLiftState() {
    _liftCommandId = null;
    _pendingLiftStamp = null;
    _liftBeforeDabs = null;
  }

  /// The committed region as it stood when a marquee drag started — the
  /// undo record's BEFORE (a cancelled drag restores it).
  CanvasSelectionShape? _shapeBeforeMarquee;

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
      // Build-phase safety (R15-⑤): this runs inside didUpdateWidget —
      // the drag-end notify reaches ancestor setState and must defer.
      _resetAll(deferDragNotify: true);
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
      applyShape: applyCommittedShape,
    );
  }

  void _resetAll({bool deferDragNotify = false}) {
    final wasDragging = _dragMode != _DragMode.none;
    setState(() {
      // Cancel FIRST: a floating lift stamp must land back into its
      // command before the lift bookkeeping clears.
      _cancelDrag(notify: wasDragging && !deferDragNotify);
      _shape = null;
      _selectedIds = const {};
      _clearLiftState();
      _clearTransform();
    });
    if (deferDragNotify && wasDragging) {
      final notify = widget.onDragActiveChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notify?.call(false);
      });
    }
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
    final before = _shape;
    _resetAll();
    // Deselecting a real region is undoable, symmetric with selecting.
    if (before != null) {
      final commit = widget.onShapeCommitted;
      if (commit != null) {
        commit(before, null);
      }
    }
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
    if (shape == null) {
      return;
    }
    if (widget.onLiftRequested != null) {
      if (!_ensureLifted(shape)) {
        return;
      }
    } else if (_selectedIds.isEmpty) {
      return;
    }
    _commitMove(dx: dx, dy: dy);
  }

  /// R14-④/R15-④: lifts the shape's pixels once per user selection — the
  /// host commits the ERASE (origin vanishes) and hands back the stamp,
  /// which floats until release. False = nothing under the shape to move.
  bool _ensureLifted(CanvasSelectionShape shape) {
    if (!_shapeNeedsLift) {
      if (_liftCommandId != null) {
        return _liftCommand() != null;
      }
      return _selectedIds.isNotEmpty;
    }
    final lift = widget.onLiftRequested!(shape);
    _shapeNeedsLift = false;
    if (lift == null) {
      _clearLiftState();
      setState(() => _selectedIds = const {});
      return false;
    }
    _liftCommandId = lift.commandId;
    _pendingLiftStamp = lift.stampDab;
    // Undo of the upcoming move must show the pixels back at the ORIGIN
    // (visually the pre-lift picture), so the history `before` is the
    // erase command WITH the stamp at its lift position.
    final command = _liftCommand();
    _liftBeforeDabs = [...?command?.sourceDabs, lift.stampDab];
    setState(() => _selectedIds = {lift.commandId});
    return true;
  }

  /// A move gesture on an ALREADY-landed lift: pull the stamp out of the
  /// command (raw rewrite, no history) so the base stops drawing it — the
  /// float alone shows the moving pixels, never a double image.
  void _suppressLiftStampForDrag() {
    if (_liftCommandId == null || _pendingLiftStamp != null) {
      return;
    }
    final command = _liftCommand();
    if (command == null) {
      _clearLiftState();
      return;
    }
    BrushDab? stamp;
    for (final dab in command.sourceDabs) {
      if (dab.stamp != null && !dab.erase) {
        stamp = dab;
      }
    }
    if (stamp == null || widget.onLiftDabsRewritten == null) {
      return;
    }
    _liftBeforeDabs = command.sourceDabs;
    _pendingLiftStamp = stamp;
    widget.onLiftDabsRewritten!(command.id, [
      for (final dab in command.sourceDabs)
        if (dab.erase || dab.stamp == null) dab,
    ]);
  }

  /// Cancel / zero-move release: the floating stamp lands back exactly
  /// where the gesture found it (raw rewrite, no history entry).
  void _restoreSuppressedLiftStamp() {
    final id = _liftCommandId;
    final before = _liftBeforeDabs;
    if (id == null || _pendingLiftStamp == null || before == null) {
      return;
    }
    widget.onLiftDabsRewritten?.call(id, before);
    _pendingLiftStamp = null;
    _liftBeforeDabs = null;
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
    final shape = _shape;
    if (widget.tool == CanvasSelectionTool.move) {
      // The MOVE tool only drags the selected content; outside the
      // region (or without one) it does nothing (R11-⑧).
      if (shape == null || !shape.containsPoint(canvasPoint)) {
        return;
      }
      // R14-④: with a lift host the shape's PIXELS decide (a marquee over
      // the middle of a stroke moves those pixels even though no whole
      // command joined); legacy hosts still need selected commands.
      if (widget.onLiftRequested != null) {
        if (!_ensureLifted(shape)) {
          return;
        }
        // Later gestures: the landed stamp leaves the base for the float.
        _suppressLiftStampForDrag();
      } else if (_selectedIds.isEmpty) {
        return;
      }
      _activePointer = event.pointer;
      setState(() {
        _dragMode = _DragMode.move;
        _moveScreenDelta = Offset.zero;
        _floatSurface = _buildFloatSurface();
      });
    } else {
      // The marquee tools ALWAYS draw a new region — even starting inside
      // the current one (moving lives on the Move tool). The old region
      // hides during the drag; the RELEASE records the change as one
      // undoable step (a cancelled drag restores it).
      _activePointer = event.pointer;
      setState(() {
        _dragMode = _DragMode.marquee;
        _shapeBeforeMarquee = _shape;
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
    // A cancelled (or zero-move) lift gesture lands the floating stamp
    // back exactly where the gesture found it.
    if (_dragMode == _DragMode.move) {
      _restoreSuppressedLiftStamp();
    }
    // A CANCELLED marquee restores the region it hid at drag start (a
    // finished one consumed the stash in _finishMarquee).
    if (_dragMode == _DragMode.marquee && _shapeBeforeMarquee != null) {
      _shape = _shapeBeforeMarquee;
      _shapeNeedsLift = true;
      _selectedIds = selectCommandIdsInShape(
        commands: widget.visibleCommands(),
        shape: _shapeBeforeMarquee!,
      );
    }
    _shapeBeforeMarquee = null;
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
    final before = _shapeBeforeMarquee;
    _shapeBeforeMarquee = null;
    // A click (degenerate region) deselects — Photoshop's click-away.
    final after = _marqueeShape();
    if (before == null && after == null) {
      return;
    }
    // The change routes through ONE undoable step (R11-⑧: selecting is
    // an undoable action); without a history host it applies directly.
    final commit = widget.onShapeCommitted;
    if (commit != null) {
      commit(before, after);
    } else {
      applyCommittedShape(after);
    }
  }

  /// Adopts a committed region — called by the selection-shape history
  /// command on execute/undo/redo (and directly without a history host).
  /// The joined command set re-derives from the shape.
  void applyCommittedShape(CanvasSelectionShape? shape) {
    if (!mounted) {
      return;
    }
    setState(() {
      _shape = shape;
      _shapeNeedsLift = shape != null;
      _clearLiftState();
      _selectedIds = shape == null
          ? const {}
          : selectCommandIdsInShape(
              commands: widget.visibleCommands(),
              shape: shape,
            );
      if (shape == null) {
        _clearTransform();
      }
    });
    _syncAnts();
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
    // R15-④ lift move: the ERASE stays at the origin forever; only the
    // stamp translates. A floating (suppressed) stamp lands directly at
    // the destination in the same rewrite.
    final liftId = _liftCommandId;
    if (liftId != null && _selectedIds.contains(liftId)) {
      final command = _liftCommand();
      if (command == null) {
        _clearLiftState();
        return;
      }
      final pending = _pendingLiftStamp;
      final beforeDabs = _liftBeforeDabs ?? command.sourceDabs;
      final List<BrushDab> afterDabs;
      if (pending != null) {
        afterDabs = [
          ...command.sourceDabs,
          pending.copyWith(
            center: CanvasPoint(
              x: pending.center.x + dx,
              y: pending.center.y + dy,
            ),
          ),
        ];
      } else {
        afterDabs = [
          for (final dab in command.sourceDabs)
            dab.stamp != null && !dab.erase
                ? dab.copyWith(
                    center: CanvasPoint(
                      x: dab.center.x + dx,
                      y: dab.center.y + dy,
                    ),
                  )
                : dab,
        ];
      }
      _pendingLiftStamp = null;
      _liftBeforeDabs = null;
      widget.onTransformCommitted((
        before: {liftId: beforeDabs},
        after: {liftId: afterDabs},
      ));
      setState(() => _shape = shape.translated(dx: dx, dy: dy));
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
    // A floating lift stamp IS the moving content (R15-④): the base no
    // longer draws it, the float draws exactly it.
    final pending = _pendingLiftStamp;
    if (pending != null) {
      return materializeBrushDabSequenceOnBitmapSurface(
        surface: surface,
        sequence: BrushDabSequence([pending]),
      ).surface;
    }
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
