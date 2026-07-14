import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_dab_sequence.dart';
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

/// The P9 selection interaction layer, mounted over the canvas while a
/// selection tool is active (Photoshop/CSP language):
///
/// - Dragging on empty ground draws a NEW region — rectangle marquee or
///   freehand lasso — shown as marching ants.
/// - Dragging INSIDE the region moves the selection's PIXELS (R19 pixel
///   model): the shape's raster lifts once (erase lands raw, the stamp
///   floats), every drag/nudge/Ctrl+T only moves the float, and the
///   CONFIRM adopts the whole session as ONE history entry.
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
    this.onShapeCommitted,
    this.selectionCommands,
    this.onDragActiveChanged,
    this.onLiftRequested,
    this.onLiftLanded,
    this.onLiftConfirmed,
    this.onLiftReverted,
    this.onMoveSessionPendingChanged,
    this.alwaysShowTransformBox = false,
  });

  /// R17-U (이동+Ctrl+T 통합, 핸들 상시): with the MOVE tool a selection
  /// shows its transform box immediately — grabbing a scale/rotate handle
  /// opens the session on the spot (the lift happens at that first
  /// interaction, never on mere display). Ctrl+T still works everywhere.
  final bool alwaysShowTransformBox;

  /// Which selection tool draws new regions (selectRect or lasso).
  final CanvasSelectionTool tool;

  final CanvasViewport viewport;
  final CanvasSize canvasSize;

  /// Changes when the edited frame changes — the selection resets (a
  /// region has no meaning on another frame's pixels).
  final Object frameToken;

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
  /// id plus the lifted STAMP dab, which the layer floats until the
  /// session confirms — so the original is never visible while moving and
  /// a reverted/zero-move session restores it exactly. Null return = the
  /// shape covers no pixels: the move is a no-op. R19 pixel model: every
  /// session lifts fresh from the CURRENT raster (a confirmed move's next
  /// move re-lifts the landed pixels — byte-identical by construction).
  final ({int liftToken, BrushDab stampDab})? Function(
    CanvasSelectionShape shape,
  )?
  onLiftRequested;

  /// Raw landing of the floating stamp at its pending position (no
  /// history entry) — the abandon fallback so a reset can never lose the
  /// float's pixels.
  final void Function(int liftToken, BrushDab stampDab)? onLiftLanded;

  /// CONFIRM of a move session (R16-①): the host lands [stampDab] and
  /// adopts the whole session (raw lift + landed stamp) as ONE history
  /// entry (BrushLiftMoveHistoryCommand).
  final void Function(int liftToken, BrushDab stampDab)? onLiftConfirmed;

  /// REVERT (R17-①): the host restores the pre-lift picture byte-exactly;
  /// nothing lands in history.
  final void Function(int liftToken)? onLiftReverted;

  /// True while a move session awaits its confirm — the host holds the
  /// session's edit-interaction lock (seeks refused, warmer down) without
  /// locking viewport navigation.
  final ValueChanged<bool>? onMoveSessionPendingChanged;

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

  /// True whenever the shape's pixels are NOT already floating: from a
  /// USER selection (marquee commit, shape channel apply) until a Move
  /// interaction lifts them, and again after every confirm (R19 pixel
  /// model — the next move re-lifts the landed raster, byte-identical).
  bool _shapeNeedsLift = false;

  /// The lift command owning this selection's pixels (R15-④), the stamp
  /// dab currently FLOATING (removed from the command so the base never
  /// shows it — no double image), and the command's dabs as they stood
  /// before the session opened (the transform `before` for re-opened
  /// sessions).
  ///
  /// R16-① (TVP-style): the stamp stays floating through EVERY drag and
  /// nudge — nothing lands and nothing is undoable until the user
  /// CONFIRMS (button, Enter, tool switch, deselect, undo/redo hook),
  /// which adopts the whole session as ONE history entry.
  int? _liftToken;
  BrushDab? _pendingLiftStamp;

  /// True once the session actually MOVED — the ants turn red until the
  /// confirm (green = confirmed / untouched).
  bool _moveSessionDirty = false;

  /// The shape as the session found it — the revert restores it.
  CanvasSelectionShape? _moveSessionStartShape;

  bool get _movePending => _pendingLiftStamp != null;

  /// REVERT (R17-①): the pixels — and the ants — return exactly to where
  /// the session found them; nothing lands in history.
  void _revertMoveSession() {
    final id = _liftToken;
    final pending = _pendingLiftStamp;
    if (id == null || pending == null) {
      return;
    }
    widget.onLiftReverted?.call(id);
    final startShape = _moveSessionStartShape;
    if (mounted) {
      setState(() {
        if (startShape != null) {
          _shape = startShape;
        }
        _shapeNeedsLift = true;
        _pendingLiftStamp = null;
        _liftToken = null;
        _moveSessionDirty = false;
        _moveSessionStartShape = null;
        if (_transform == null) {
          _floatSurface = null;
        }
      });
    }
    widget.onMoveSessionPendingChanged?.call(false);
    _syncAnts();
  }

  void _clearLiftState() {
    final wasPending = _movePending;
    _liftToken = null;
    _pendingLiftStamp = null;
    _moveSessionDirty = false;
    if (wasPending) {
      widget.onMoveSessionPendingChanged?.call(false);
    }
  }

  /// CONFIRM (R16-①): lands the floating stamp and adopts the whole
  /// session as ONE history entry. Safe to call from any event context;
  /// never called inside a build phase (the tool-switch and dispose
  /// triggers defer post-frame). Afterwards the shape needs a fresh lift
  /// (R19 pixel model: the landed raster IS the content to move next).
  void _confirmMoveSession() {
    final id = _liftToken;
    final pending = _pendingLiftStamp;
    if (id == null || pending == null) {
      return;
    }
    final confirm = widget.onLiftConfirmed;
    if (confirm != null) {
      confirm(id, pending);
    } else {
      // Headless hosts (focused tests): land without history.
      widget.onLiftLanded?.call(id, pending);
    }
    if (mounted) {
      setState(() {
        _pendingLiftStamp = null;
        _liftToken = null;
        _moveSessionDirty = false;
        _moveSessionStartShape = null;
        _shapeNeedsLift = true;
        if (_transform == null) {
          _floatSurface = null;
        }
      });
    } else {
      _pendingLiftStamp = null;
      _liftToken = null;
      _moveSessionDirty = false;
      _moveSessionStartShape = null;
      _shapeNeedsLift = true;
    }
    widget.onMoveSessionPendingChanged?.call(false);
    _syncAnts();
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
    // R17-①: a context change over a pending move ASKS (CSP grammar) —
    // 확정 lands the session as one undo entry, 되돌리기 puts the pixels
    // back exactly. Deferred post-frame: dialogs and history commands
    // must never run inside the build phase.
    if (oldWidget.tool != widget.tool && _movePending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _movePending) {
          _promptPendingMove();
        }
      });
    }
  }

  /// The R17-① "확정시키겠습니까?" prompt. Modal: the session stays
  /// pending until a choice lands (dismissing = confirm, the safe
  /// default — pixels keep their moved position and stay undoable).
  Future<void> _promptPendingMove() async {
    if (!mounted || !_movePending) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('selection-move-confirm-dialog'),
        title: const Text('이동 확정'),
        content: const Text('선택 영역 이동을 확정하시겠습니까?'),
        actions: [
          TextButton(
            key: const ValueKey<String>('selection-move-revert-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('되돌리기'),
          ),
          FilledButton(
            key: const ValueKey<String>('selection-move-apply-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확정'),
          ),
        ],
      ),
    );
    if (!mounted || !_movePending) {
      return;
    }
    if (confirmed == false) {
      _revertMoveSession();
    } else {
      _confirmMoveSession();
    }
  }

  @override
  void dispose() {
    widget.selectionCommands?.unbind();
    if (_dragMode != _DragMode.none) {
      widget.onDragActiveChanged?.call(false);
    }
    // R16-①: unmounting with a pending move (tool switched to a
    // non-selection tool) CONFIRMS it. The history execute defers
    // post-frame (dispose can run inside a build); the interaction hold
    // releases NOW so a leak can never lock seeks.
    final pendingStamp = _pendingLiftStamp;
    final liftId = _liftToken;
    if (pendingStamp != null && liftId != null) {
      widget.onMoveSessionPendingChanged?.call(false);
      final onConfirmed = widget.onLiftConfirmed;
      final onLanded = widget.onLiftLanded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (onConfirmed != null) {
          onConfirmed(liftId, pendingStamp);
        } else {
          onLanded?.call(liftId, pendingStamp);
        }
      });
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
      // Enter: an open Ctrl+T commits; otherwise a pending move confirms
      // (R16-①'s keyboard confirm).
      commitTransform: () {
        if (_transform != null) {
          _commitTransform();
        } else {
          _confirmMoveSession();
        }
      },
      cancelTransform: _cancelTransform,
      applyShape: applyCommittedShape,
      movePending: () => _movePending,
      confirmPendingMove: _confirmMoveSession,
      revertPendingMove: _revertMoveSession,
      transformValues: () {
        final transform = _transform;
        // A quad session has no affine channels (R20-D2) — the numeric
        // fields blank out rather than lie.
        if (transform == null || _warpCorners != null) {
          return null;
        }
        return (
          tx: transform.tx,
          ty: transform.ty,
          rotationDegrees: transform.rotationDegrees,
          scale: transform.sx,
        );
      },
      setTransformValues: _setTransformValues,
    );
  }

  /// Numeric transform input (R17-U tool settings): opens the session if
  /// none is up (Ctrl+T semantics — lift + box), then sets the affine
  /// outright. Enter/Escape keep their commit/revert meanings.
  void _setTransformValues({
    required double tx,
    required double ty,
    required double rotationDegrees,
    required double scale,
  }) {
    if (_warpCorners != null) {
      return; // Quad mode: the corners are the only channels (R20-D2).
    }
    if (_transform == null) {
      _beginTransform();
    }
    final transform = _transform;
    if (transform == null) {
      return;
    }
    setState(() {
      _transform = transform.copyWith(
        tx: tx,
        ty: ty,
        rotationDegrees: rotationDegrees,
        sx: scale,
        sy: scale,
      );
    });
    _syncAnts();
  }

  void _resetAll({bool deferDragNotify = false}) {
    final wasDragging = _dragMode != _DragMode.none;
    setState(() {
      // A pending float must not lose its pixels: land it at its pending
      // position (raw, no history) before the bookkeeping clears. Pending
      // resets are rare by construction — the session holds the seek lock.
      _landPendingLiftStamp();
      _cancelDrag(notify: wasDragging && !deferDragNotify);
      _shape = null;
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

  // --- Perspective quad session (R20-D2, PS Ctrl+corner) --------------
  //
  // Non-null = the open box is in QUAD mode: the four corners move
  // freely, the float previews through the forward homography, Enter
  // resamples through [transformStampDabQuad]. Entered by Ctrl-grabbing
  // a corner handle; Escape/commit semantics are the affine session's.
  List<CanvasPoint>? _warpCorners;
  int? _warpDragCorner; // null while dragging inside = translate all four.
  List<CanvasPoint>? _warpDragStartCorners;

  /// The pending stamp's canvas rect corners (TL/TR/BR/BL) — the quad's
  /// BASE. Initializing corners as affine(base) makes an untouched quad
  /// exactly identity for [transformStampDabQuad].
  List<CanvasPoint>? _stampRectCorners() {
    final pending = _pendingLiftStamp;
    final stamp = pending?.stamp;
    if (pending == null || stamp == null) {
      return null;
    }
    final left = pending.center.x - stamp.width / 2;
    final top = pending.center.y - stamp.height / 2;
    return [
      CanvasPoint(x: left, y: top),
      CanvasPoint(x: left + stamp.width, y: top),
      CanvasPoint(x: left + stamp.width, y: top + stamp.height),
      CanvasPoint(x: left, y: top + stamp.height),
    ];
  }

  static const List<_TransformHandle> _cornerHandles = [
    _TransformHandle.topLeft,
    _TransformHandle.topRight,
    _TransformHandle.bottomRight,
    _TransformHandle.bottomLeft,
  ];

  int? _hitTestWarpCorner(Offset local) {
    final corners = _warpCorners;
    if (corners == null) {
      return null;
    }
    for (var i = 0; i < 4; i += 1) {
      final mapped = widget.viewport.canvasToViewport(corners[i]);
      if ((local - Offset(mapped.x, mapped.y)).distance <= _handleHitRadius) {
        return i;
      }
    }
    return null;
  }

  void _clearTransform() {
    _transform = null;
    _transformOpenedLift = false;
    _baseBoxWidth = 0;
    _baseBoxHeight = 0;
    _transformDragHandle = null;
    _transformDragStart = null;
    _transformDragStartPointer = null;
    _warpCorners = null;
    _warpDragCorner = null;
    _warpDragStartCorners = null;
    // A pending session's float must keep rendering — its pixels are NOT
    // in the base surface (they left with the lift's erase).
    _floatSurface = _movePending ? _buildFloatSurface() : null;
  }

  /// True when THIS Ctrl+T session opened the lift (Escape then reverts
  /// the whole session — pixels return byte-exactly, as if Ctrl+T never
  /// happened). False when Ctrl+T rode an already-pending move (Escape
  /// only closes the box; the pending float stays).
  bool _transformOpenedLift = false;

  /// Ctrl+T: opens the free-transform box on the live selection (R19
  /// pixel model: the session lifts the shape's raster and the box
  /// manipulates the FLOAT; Enter resamples the stamp and confirms).
  void _beginTransform() {
    final shape = _shape;
    if (shape == null || _transform != null) {
      return;
    }
    if (widget.onLiftRequested == null) {
      return;
    }
    final hadPendingLift = _pendingLiftStamp != null;
    if (!_ensureLifted(shape)) {
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
      _transformOpenedLift = !hadPendingLift;
      _baseBoxWidth = math.max(maxX - minX, 1);
      _baseBoxHeight = math.max(maxY - minY, 1);
      _transform = SelectionAffine(
        pivot: CanvasPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
      );
      _floatSurface = _buildFloatSurface();
    });
    _syncAnts();
  }

  /// Enter: resamples the floating stamp through the affine (pure
  /// translations stay byte-exact) and CONFIRMS the session as ONE undo
  /// entry; identity closes the box with the session still pending.
  void _commitTransform() {
    final affine = _transform;
    final shape = _shape;
    final pending = _pendingLiftStamp;
    if (affine == null || shape == null) {
      return;
    }
    // R20-D2: an open quad resamples through the homography instead.
    final warpCorners = _warpCorners;
    if (warpCorners != null && pending != null) {
      final warped = transformStampDabQuad(pending, warpCorners);
      if (identical(warped, pending)) {
        // Untouched (or degenerate) quad: close the box, session pends on.
        setState(_clearTransform);
        _syncAnts();
        return;
      }
      final base = _stampRectCorners();
      final h = base == null ? null : solveHomography(base, warpCorners);
      setState(() {
        _pendingLiftStamp = warped;
        _shape = h == null
            ? CanvasSelectionShape(warpCorners)
            : CanvasSelectionShape([
                for (final point in shape.points) _applyHomography(h, point),
              ]);
        _moveSessionDirty = true;
        _clearTransform();
      });
      _confirmMoveSession();
      return;
    }
    if (!affine.isIdentity && pending != null) {
      setState(() {
        _pendingLiftStamp = transformStampDab(pending, affine);
        _shape = transformShape(shape, affine);
        _moveSessionDirty = true;
        _clearTransform();
      });
      _confirmMoveSession();
      return;
    }
    setState(_clearTransform);
    _syncAnts();
  }

  /// Escape: discards the open transform. A lift the Ctrl+T itself
  /// opened (and that never moved otherwise) reverts whole — the picture
  /// returns byte-exactly.
  void _cancelTransform() {
    if (_transform == null) {
      return;
    }
    if (_transformOpenedLift && !_moveSessionDirty && _movePending) {
      setState(_clearTransform);
      _revertMoveSession();
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
    // Every mutation path funnels through here — the settings panel's
    // numeric fields track the session via this (deferred) ping.
    widget.selectionCommands?.notifySessionChanged();
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
    if (shape == null || widget.onLiftRequested == null) {
      return;
    }
    if (!_ensureLifted(shape)) {
      return;
    }
    _commitMove(dx: dx, dy: dy);
  }

  /// R14-④/R15-④: lifts the shape's pixels once per selection-or-confirm
  /// — the host commits the ERASE (origin vanishes) and hands back the
  /// stamp, which floats until the session confirms. False = nothing
  /// under the shape to move.
  bool _ensureLifted(CanvasSelectionShape shape) {
    if (!_shapeNeedsLift) {
      return _pendingLiftStamp != null;
    }
    final lift = widget.onLiftRequested!(shape);
    _shapeNeedsLift = false;
    if (lift == null) {
      _clearLiftState();
      return false;
    }
    _liftToken = lift.liftToken;
    _pendingLiftStamp = lift.stampDab;
    _moveSessionDirty = false;
    _moveSessionStartShape = shape;
    widget.onMoveSessionPendingChanged?.call(true);
    return true;
  }

  /// Abandon fallback: land the floating stamp at its CURRENT pending
  /// position (raw, no history) so the pixels are never lost. Ordinary
  /// session ends go through the confirm.
  void _landPendingLiftStamp() {
    final id = _liftToken;
    final pending = _pendingLiftStamp;
    if (id == null || pending == null) {
      return;
    }
    widget.onLiftLanded?.call(id, pending);
    _pendingLiftStamp = null;
    _liftToken = null;
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
    var transform = _transform;
    // R17-U 핸들 상시: with the always-on box (Move tool), grabbing a
    // scale/rotate HANDLE promotes the implicit box into a real session
    // on the spot — the lift happens here, at the first interaction.
    if (transform == null &&
        widget.alwaysShowTransformBox &&
        widget.tool == CanvasSelectionTool.move &&
        _shape != null &&
        widget.onLiftRequested != null) {
      final implicitShape = _shape!;
      final box = _shapeBounds(implicitShape);
      _baseBoxWidth = box.width;
      _baseBoxHeight = box.height;
      final implicit = SelectionAffine(pivot: box.center);
      final handle = _hitTestTransformHandle(event.localPosition, implicit);
      if (handle != null && handle != _TransformHandle.inside) {
        final hadPendingLift = _pendingLiftStamp != null;
        if (!_ensureLifted(implicitShape)) {
          _baseBoxWidth = 0;
          _baseBoxHeight = 0;
          return;
        }
        setState(() {
          _transformOpenedLift = !hadPendingLift;
          _transform = implicit;
          _floatSurface = _buildFloatSurface();
        });
        transform = implicit;
      } else {
        // Inside/miss: fall through to the ordinary move-drag flow.
        _baseBoxWidth = 0;
        _baseBoxHeight = 0;
      }
    }
    if (transform != null) {
      // The open box is modal: only the box's handles/inside react;
      // clicks elsewhere are inert until Enter/Escape closes the session.
      final openTransform = transform;
      // R20-D2: an open QUAD session hit-tests its corners + inside only
      // (rotate/edge handles have no meaning on a free quad).
      final warpCorners = _warpCorners;
      if (warpCorners != null) {
        final cornerIndex = _hitTestWarpCorner(event.localPosition);
        if (cornerIndex == null &&
            !CanvasSelectionShape(warpCorners).containsPoint(canvasPoint)) {
          return;
        }
        _activePointer = event.pointer;
        setState(() {
          _dragMode = _DragMode.transform;
          _warpDragCorner = cornerIndex;
          _warpDragStartCorners = List.of(warpCorners);
          _transformDragStartPointer = canvasPoint;
        });
        widget.onDragActiveChanged?.call(true);
        return;
      }
      final handle = _hitTestTransformHandle(
        event.localPosition,
        openTransform,
      );
      if (handle == null) {
        return;
      }
      // R20-D2: Ctrl+corner switches the box into the perspective quad
      // (the PS gesture) — corners initialize at the affine positions of
      // the pending stamp's rect, so an untouched quad stays identity.
      if (_cornerHandles.contains(handle) &&
          HardwareKeyboard.instance.isControlPressed) {
        final base = _stampRectCorners();
        if (base != null) {
          final corners = [
            for (final corner in base) openTransform.apply(corner),
          ];
          _activePointer = event.pointer;
          setState(() {
            _warpCorners = corners;
            _dragMode = _DragMode.transform;
            _warpDragCorner = _cornerHandles.indexOf(handle);
            _warpDragStartCorners = List.of(corners);
            _transformDragStartPointer = canvasPoint;
          });
          widget.onDragActiveChanged?.call(true);
          return;
        }
      }
      _activePointer = event.pointer;
      setState(() {
        _dragMode = _DragMode.transform;
        _transformDragHandle = handle;
        _transformDragStart = openTransform;
        _transformDragStartPointer = canvasPoint;
        if (handle == _TransformHandle.rotate) {
          _transformLastAngle = _pointerAngleAbout(canvasPoint, openTransform);
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
      // R14-④/R19 pixel model: the shape's PIXELS are the content — the
      // first gesture on a selection (or on a confirmed landing) lifts
      // them fresh from the current raster.
      if (widget.onLiftRequested == null || !_ensureLifted(shape)) {
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
      // undoable step (a cancelled drag restores it). A pending move
      // session confirms first (R16-①: never revert, always confirm).
      _confirmMoveSession();
      _activePointer = event.pointer;
      setState(() {
        _dragMode = _DragMode.marquee;
        _shapeBeforeMarquee = _shape;
        _shape = null;
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
    // R20-D2 quad drag: one corner follows the pointer, or (inside) all
    // four translate together.
    final warpStart = _warpDragStartCorners;
    if (_warpCorners != null && warpStart != null) {
      final startPointer = _transformDragStartPointer;
      if (startPointer == null) {
        return;
      }
      final dx = pointer.x - startPointer.x;
      final dy = pointer.y - startPointer.y;
      final corner = _warpDragCorner;
      setState(() {
        _warpCorners = [
          for (var i = 0; i < 4; i += 1)
            corner == null || corner == i
                ? CanvasPoint(x: warpStart[i].x + dx, y: warpStart[i].y + dy)
                : warpStart[i],
        ];
      });
      _syncAnts();
      return;
    }
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
    // R16-①: the move SESSION survives the gesture — the float keeps
    // rendering at its pending position until the user confirms.
    // A CANCELLED marquee restores the region it hid at drag start (a
    // finished one consumed the stash in _finishMarquee).
    if (_dragMode == _DragMode.marquee && _shapeBeforeMarquee != null) {
      _shape = _shapeBeforeMarquee;
      _shapeNeedsLift = true;
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
    if (_transform == null && !_movePending) {
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
  void applyCommittedShape(CanvasSelectionShape? shape) {
    if (!mounted) {
      return;
    }
    // A committed region change over a pending move confirms it first
    // (deselect, Ctrl+D, a new shape from undo/redo — R16-①).
    _confirmMoveSession();
    setState(() {
      _shape = shape;
      _shapeNeedsLift = shape != null;
      _clearLiftState();
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
    final pending = _pendingLiftStamp;
    if (shape == null || pending == null || (dx == 0 && dy == 0)) {
      return;
    }
    // R16-① TVP move session: a drag/nudge only moves the FLOAT — nothing
    // lands and nothing is undoable until the confirm. The ants go red.
    setState(() {
      _pendingLiftStamp = pending.copyWith(
        center: CanvasPoint(x: pending.center.x + dx, y: pending.center.y + dy),
      );
      _moveSessionDirty = true;
      _floatSurface = _buildFloatSurface();
      _shape = shape.translated(dx: dx, dy: dy);
    });
    _syncAnts();
  }

  static CanvasPoint _applyHomography(Float64List h, CanvasPoint point) {
    final w = h[6] * point.x + h[7] * point.y + h[8];
    if (w.abs() < 1e-12) {
      return point;
    }
    return CanvasPoint(
      x: (h[0] * point.x + h[1] * point.y + h[2]) / w,
      y: (h[3] * point.x + h[4] * point.y + h[5]) / w,
    );
  }

  /// The quad preview matrix (R20-D2): the forward homography from the
  /// pending stamp's rect onto the warp corners, wrapped into screen
  /// space through the SAME viewport transform as the affine preview.
  Matrix4? _quadScreenMatrix(List<CanvasPoint> corners) {
    final base = _stampRectCorners();
    if (base == null) {
      return null;
    }
    final h = solveHomography(base, corners);
    if (h == null) {
      return null;
    }
    // Row-major 3×3 homography embedded into a column-major 4×4 acting
    // on (x, y, z, 1) with the perspective terms on the w row.
    final canvasMatrix = Matrix4(
      h[0],
      h[3],
      0,
      h[6], //
      h[1],
      h[4],
      0,
      h[7], //
      0,
      0,
      1,
      0, //
      h[2],
      h[5],
      0,
      h[8],
    );
    return viewportTransformMatrix(widget.viewport)
      ..multiply(canvasMatrix)
      ..multiply(viewportInverseTransformMatrix(widget.viewport));
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

  Offset _rotateKnobOffset(SelectionAffine affine) =>
      _rotateKnobOffsetFor(affine, _baseBoxHeight);

  Offset _rotateKnobOffsetFor(SelectionAffine affine, double boxHeight) {
    final topMid = _mapLocalToViewport(
      affine,
      CanvasPoint(x: 0, y: -boxHeight / 2),
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
  CanvasSelectionShape _transformedBoxShape(SelectionAffine affine) =>
      _boxShapeFor(affine, _baseBoxWidth, _baseBoxHeight);

  CanvasSelectionShape _boxShapeFor(
    SelectionAffine affine,
    double width,
    double height,
  ) {
    return CanvasSelectionShape([
      for (final corner in [
        CanvasPoint(x: -width / 2, y: -height / 2),
        CanvasPoint(x: width / 2, y: -height / 2),
        CanvasPoint(x: width / 2, y: height / 2),
        CanvasPoint(x: -width / 2, y: height / 2),
      ])
        affine.apply(
          CanvasPoint(
            x: affine.pivot.x + corner.x,
            y: affine.pivot.y + corner.y,
          ),
        ),
    ]);
  }

  /// The shape's axis-aligned bounds (box geometry for the transform
  /// chrome — R17-U always-on handles use it without opening a session).
  ({double width, double height, CanvasPoint center}) _shapeBounds(
    CanvasSelectionShape shape,
  ) {
    var minX = shape.points.first.x, maxX = shape.points.first.x;
    var minY = shape.points.first.y, maxY = shape.points.first.y;
    for (final point in shape.points.skip(1)) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }
    return (
      width: math.max(maxX - minX, 1),
      height: math.max(maxY - minY, 1),
      center: CanvasPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
    );
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

  /// The floating lift stamp rendered alone (the live float shown while
  /// moving) — the base no longer draws it, the float draws exactly it
  /// (R15-④), so there is never a double image.
  BitmapSurface _buildFloatSurface() {
    final surface = BitmapSurface(canvasSize: widget.canvasSize);
    final pending = _pendingLiftStamp;
    if (pending == null) {
      return surface;
    }
    return materializeBrushDabSequenceOnBitmapSurface(
      surface: surface,
      sequence: BrushDabSequence([pending]),
    ).surface;
  }

  @override
  Widget build(BuildContext context) {
    final floatSurface = _floatSurface;
    final transform = _transform;
    final shape = _shape;
    final warpCorners = _warpCorners;
    // With an open Ctrl+T session the ants show the TRANSFORMED region
    // and the box chrome renders around the transformed base box. An
    // open QUAD (R20-D2) maps the region through the homography instead.
    var displayShape = transform != null && shape != null
        ? transformShape(shape, transform)
        : shape;
    if (warpCorners != null && shape != null) {
      final base = _stampRectCorners();
      final h = base == null ? null : solveHomography(base, warpCorners);
      displayShape = h == null
          ? CanvasSelectionShape(warpCorners)
          : CanvasSelectionShape([
              for (final point in shape.points) _applyHomography(h, point),
            ]);
    }
    // R17-U 핸들 상시: with the Move tool a selection shows its box
    // chrome even before any session opens (identity affine around the
    // shape bounds; grabbing a handle opens the session at that moment).
    var chromeAffine = transform;
    var chromeWidth = _baseBoxWidth;
    var chromeHeight = _baseBoxHeight;
    if (chromeAffine == null &&
        widget.alwaysShowTransformBox &&
        widget.tool == CanvasSelectionTool.move &&
        shape != null &&
        _dragMode == _DragMode.none) {
      final bounds = _shapeBounds(shape);
      chromeAffine = SelectionAffine(pivot: bounds.center);
      chromeWidth = bounds.width;
      chromeHeight = bounds.height;
    }
    // Quad chrome (R20-D2): the free quadrilateral with its four corner
    // handles only — edges and the rotate knob have no quad meaning.
    final chrome = warpCorners != null
        ? (
            box: [
              for (final point in warpCorners)
                _mapCanvasToViewportOffset(point),
            ],
            handles: [
              for (final point in warpCorners)
                _mapCanvasToViewportOffset(point),
            ],
            knob: null as Offset?,
          )
        : chromeAffine == null
        ? null
        : (
            box: [
              for (final point in _boxShapeFor(
                chromeAffine,
                chromeWidth,
                chromeHeight,
              ).points)
                _mapCanvasToViewportOffset(point),
            ],
            handles: [
              for (final handle in _scaleHandles)
                _mapLocalToViewport(
                  chromeAffine,
                  _handleLocal(handle, chromeWidth, chromeHeight)!,
                ),
            ],
            knob: _rotateKnobOffsetFor(chromeAffine, chromeHeight) as Offset?,
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
              (_dragMode == _DragMode.move ||
                  transform != null ||
                  _movePending))
            Positioned.fill(
              child: IgnorePointer(
                child: Transform(
                  transform: warpCorners != null
                      ? (_quadScreenMatrix(warpCorners) ?? Matrix4.identity())
                      : transform != null
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
                  movePendingDirty: _movePending && _moveSessionDirty,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // R16-①: the CONFIRM button — floats at the selection's top
          // right while a move session is pending.
          if (_movePending && displayShape != null)
            Positioned(
              left: _confirmButtonOffset(displayShape).dx,
              top: _confirmButtonOffset(displayShape).dy,
              child: Material(
                key: const ValueKey<String>('selection-move-confirm'),
                color: _moveSessionDirty
                    ? const Color(0xFFFF4444)
                    : const Color(0xFF2ECC71),
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _confirmMoveSession,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.check, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Confirm button anchor: just outside the selection bbox's top-right,
  /// following the live drag offset.
  Offset _confirmButtonOffset(CanvasSelectionShape shape) {
    var maxX = shape.points.first.x;
    var minY = shape.points.first.y;
    for (final point in shape.points.skip(1)) {
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
    }
    final mapped = _mapCanvasToViewportOffset(CanvasPoint(x: maxX, y: minY));
    final dragOffset = _dragMode == _DragMode.move
        ? _moveScreenDelta
        : Offset.zero;
    return mapped + dragOffset + const Offset(8, -34);
  }

  Offset _mapCanvasToViewportOffset(CanvasPoint point) {
    final mapped = widget.viewport.canvasToViewport(point);
    return Offset(mapped.x, mapped.y);
  }
}

/// The Ctrl+T box chrome in viewport space: the transformed box outline,
/// the scale handles and the rotate knob (null in QUAD mode — a free
/// quadrilateral has no rotation lever).
typedef _TransformChrome = ({
  List<Offset> box,
  List<Offset> handles,
  Offset? knob,
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
    this.movePendingDirty = false,
  }) : _phase = repaint,
       super(repaint: repaint);

  final Animation<double> _phase;
  final CanvasViewport viewport;
  final CanvasSelectionShape? committedShape;
  final Offset screenOffset;
  final CanvasSelectionShape? marqueeShape;
  final List<CanvasPoint> lassoTrail;
  final _TransformChrome? transformChrome;

  /// R16-① TVP grammar: RED silhouette while the move session holds
  /// unconfirmed changes, GREEN when confirmed/untouched.
  final bool movePendingDirty;

  static const Color _chromeColor = Color(0xFF40C4FF);
  static const Color _confirmedAntsColor = Color(0xFF2ECC71);
  static const Color _pendingAntsColor = Color(0xFFFF4444);

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
    // Quad mode carries no knob (R20-D2).
    final knob = chrome.knob;
    if (knob != null) {
      final topMid = Offset(
        (chrome.box[0].dx + chrome.box[1].dx) / 2,
        (chrome.box[0].dy + chrome.box[1].dy) / 2,
      );
      canvas.drawLine(topMid, knob, stroke);
      canvas.drawCircle(knob, 5, fill);
    }
  }

  /// White under-stroke + phase-offset colored dashes: GREEN for a
  /// confirmed/untouched selection, RED while a move session holds
  /// unconfirmed changes (R16-①, TVP grammar) — readable on any artwork.
  void _paintAnts(Canvas canvas, Path path, double phase) {
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white;
    final dashes = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = movePendingDirty ? _pendingAntsColor : _confirmedAntsColor;
    canvas.drawPath(path, white);
    canvas.drawPath(_dashPath(path, phase), dashes);
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
      oldDelegate.transformChrome != transformChrome ||
      oldDelegate.movePendingDirty != movePendingDirty;
}
