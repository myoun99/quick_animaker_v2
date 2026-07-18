import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../models/canvas_viewport.dart';
import '../input/app_input_settings.dart';
import '../../models/viewport_point.dart';

/// Viewport pan/zoom input for the canvas panel, independent of what the
/// viewport currently shows (interactive canvas, blank paper, playback).
/// Living at the panel level is what keeps navigation working on timeline
/// positions without an editable frame.
///
/// - Middle-mouse drag pans.
/// - Scroll wheel zooms around the cursor — no modifier key by design.
/// - Trackpad pinch/pan gestures zoom around the focal point and pan
///   (mouse-less desktops; the same events arrive from some touchpads).
/// - Two touch fingers pinch-zoom around the focal point and pan
///   (tablet/touch-screen navigation). One finger stays reserved for
///   drawing — the interactive canvas cancels its stroke when the second
///   finger lands, so a quick pinch never leaves marks.
///
/// While a brush stroke is in progress ([strokeActive]) new pans and wheel
/// zooms are ignored so a stray wheel tick cannot re-anchor the stroke
/// mid-draw. Two-finger touch navigation deliberately bypasses that gate:
/// the second finger IS the cancel-and-navigate signal.
class CanvasViewportGestureLayer extends StatefulWidget {
  const CanvasViewportGestureLayer({
    super.key,
    required this.viewport,
    required this.onViewportChanged,
    this.strokeActive = false,
    this.rotationEnabled = true,
    this.onInvokeAction,
    this.onBrushSizeDragStart,
    this.onBrushSizeDragUpdate,
    this.onBrushSizeDragEnd,
    required this.child,
  });

  final CanvasViewport viewport;
  final ValueChanged<CanvasViewport> onViewportChanged;

  /// PEN-7b: the FLIP slot dispatches registry actions (drawing/frame
  /// steps, layer up/down) through the shell's one action funnel — the
  /// same ids the arrow keys fire.
  final void Function(String actionId)? onInvokeAction;

  /// PEN-7b: the BRUSH-SIZE slot (vertical drag; [snap] while the
  /// modifier finger is down). The host owns the actual size math — the
  /// layer only reports the cumulative upward delta.
  final VoidCallback? onBrushSizeDragStart;
  final void Function(double upwardDelta, {required bool snap})?
  onBrushSizeDragUpdate;
  final VoidCallback? onBrushSizeDragEnd;

  /// True while the user is drawing; blocks new viewport gestures.
  final bool strokeActive;

  /// False disables the two-finger/trackpad ROTATION gestures (P8) while
  /// pan/zoom keep working — for hosts whose content cannot rotate (the
  /// timesheet).
  final bool rotationEnabled;

  final Widget child;

  @override
  State<CanvasViewportGestureLayer> createState() =>
      _CanvasViewportGestureLayerState();
}

class _CanvasViewportGestureLayerState
    extends State<CanvasViewportGestureLayer> {
  /// Two-finger/trackpad rotation engages only past this angle (P8): a
  /// plain pinch-zoom must not wobble the canvas.
  static const double rotationDeadzoneDegrees = 5;

  /// A resulting view angle inside this window snaps back to 0° — easy
  /// return to straight.
  static const double rotationZeroSnapDegrees = 5;

  int? _panPointer;
  Offset? _panStartLocalPosition;
  CanvasViewport? _panStartViewport;
  CanvasViewport? _panZoomStartViewport;

  /// Non-null once the trackpad rotation crossed the deadzone: the fixed
  /// compensation (±deadzone, the crossing side) subtracted from the raw
  /// delta so the engagement is seamless AND stays continuous when the
  /// gesture later swings back through zero.
  double? _panZoomRotationCompensation;

  /// Live touch contacts (pointer id → local position). The first two form
  /// the two-finger navigation gesture.
  final Map<int, Offset> _touchPositions = <int, Offset>{};
  List<int>? _touchNavPointers;
  Offset? _touchNavStartFocal;
  double? _touchNavStartDistance;
  double? _touchNavStartAngle;
  double? _touchNavRotationCompensation;
  CanvasViewport? _touchNavStartViewport;

  static double _wrapDegrees(double degrees) {
    var wrapped = degrees;
    while (wrapped > 180) {
      wrapped -= 360;
    }
    while (wrapped < -180) {
      wrapped += 360;
    }
    return wrapped;
  }

  /// Snaps a candidate view angle to 0° when it lands near straight.
  static double _snappedRotation(double degrees) {
    final normalized = _wrapDegrees(degrees);
    if (normalized.abs() <= rotationZeroSnapDegrees) {
      return degrees - normalized;
    }
    return degrees;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey<String>('canvas-viewport-gesture-layer'),
      // Translucent: receive events over the whole viewport (the blank
      // canvas paints without hit-testable render objects) while the
      // interactive canvas below keeps receiving its drawing input.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      onPointerSignal: _handlePointerSignal,
      onPointerPanZoomStart: _handlePanZoomStart,
      onPointerPanZoomUpdate: _handlePanZoomUpdate,
      onPointerPanZoomEnd: _handlePanZoomEnd,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      _touchPositions[event.pointer] = event.localPosition;
      if (AppInput.effectiveCanvasTouchMode == CanvasTouchMode.draw) {
        _syncTouchNavigation();
      } else {
        _controlTouchDown(event);
      }
      return;
    }

    if (!_startsMappedPan(event.buttons) ||
        _panPointer != null ||
        widget.strokeActive) {
      return;
    }
    _panPointer = event.pointer;
    _panStartLocalPosition = event.localPosition;
    _panStartViewport = widget.viewport;
  }

  /// Whether this button chord starts a viewport PAN (PEN-7a): any
  /// pressed secondary bit whose CANVAS mapping says pan — the wheel/
  /// middle bit (default mapping) or the right bit when assigned. The
  /// pen tip's contact bit rides along on stylus presses, so the check
  /// is per-bit, not equality.
  bool _startsMappedPan(int buttons) {
    final settings = AppInput.settings.value;
    if ((buttons & kTertiaryButton) != 0 &&
        settings.canvasWheelClick.action == CanvasPointerAction.pan) {
      return true;
    }
    if ((buttons & kSecondaryButton) != 0 &&
        settings.canvasRightClick.action == CanvasPointerAction.pan) {
      return true;
    }
    return false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_touchPositions.containsKey(event.pointer)) {
      _touchPositions[event.pointer] = event.localPosition;
      if (AppInput.effectiveCanvasTouchMode == CanvasTouchMode.draw) {
        _updateTouchNavigation();
      } else {
        _controlTouchMove(event);
      }
      return;
    }

    if (event.pointer != _panPointer) {
      return;
    }
    final startPosition = _panStartLocalPosition;
    final startViewport = _panStartViewport;
    if (startPosition == null || startViewport == null) {
      return;
    }
    final delta = event.localPosition - startPosition;
    _emit(startViewport.translated(dx: delta.dx, dy: delta.dy));
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_touchPositions.remove(event.pointer) != null) {
      if (AppInput.effectiveCanvasTouchMode == CanvasTouchMode.draw) {
        _syncTouchNavigation();
      } else {
        _controlTouchLift(event.pointer);
      }
      return;
    }
    if (event.pointer == _panPointer) {
      _clearPan();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_touchPositions.remove(event.pointer) != null) {
      if (AppInput.effectiveCanvasTouchMode == CanvasTouchMode.draw) {
        _syncTouchNavigation();
      } else {
        _controlTouchLift(event.pointer);
      }
      return;
    }
    if (event.pointer == _panPointer) {
      _clearPan();
    }
  }

  // --- PEN-7b: the CONTROL-mode touch engine ------------------------------
  //
  // Slot model: the fingers that land together (~120ms) form the BASE
  // group; its size picks the user-assigned drag action (flip/navigate/
  // brush size). Once the group LOCKS (any finger crosses the slop) later
  // fingers become the +1 MODIFIER (never a re-classification — the
  // Callipeg-confusion fix); the modifier constrains the action (snap/
  // lock/fine-step). Any BASE finger lifting ends the gesture; a modifier
  // lifting just releases the constraint. Speed never decides anything.

  static const Duration groupWindow = Duration(milliseconds: 120);
  static const double _touchSlop = 18;

  /// One flip step per this many pixels along the locked axis.
  static const double flipStepExtent = 48;

  final List<int> _groupPointers = <int>[];
  final Map<int, Offset> _groupDownPositions = <int, Offset>{};
  DateTime? _groupStartedAt;
  bool _groupLocked = false;
  CanvasTouchDragAction _groupAction = CanvasTouchDragAction.none;
  final Set<int> _modifierPointers = <int>{};

  // Flip state: axis locks to the dominant direction at group lock.
  bool? _flipAxisHorizontal;
  int _flipEmittedSteps = 0;

  // Navigate state (group-form anchors — reset when the modifier
  // engages/releases so constraints never jump the view).
  Offset? _navStartFocal;
  double? _navStartDistance;
  double? _navStartAngle;
  double? _navRotationCompensation;
  CanvasViewport? _navStartViewport;
  bool _navModifierActive = false;
  double? _navModifierLockRotation;

  // Brush-size state.
  bool _brushSizeActive = false;

  void _controlTouchDown(PointerDownEvent event) {
    final now = DateTime.now();
    if (_groupPointers.isEmpty) {
      _groupStartedAt = now;
      _groupPointers.add(event.pointer);
      _groupDownPositions[event.pointer] = event.localPosition;
      return;
    }
    final startedAt = _groupStartedAt;
    final withinWindow =
        startedAt != null && now.difference(startedAt) <= groupWindow;
    if (!_groupLocked && withinWindow && _groupPointers.length < 3) {
      _groupPointers.add(event.pointer);
      _groupDownPositions[event.pointer] = event.localPosition;
      return;
    }
    // Late finger = the modifier (lock-then-modify; never re-classify).
    if (_groupLocked && AppInput.settings.value.extraFingerModifier) {
      _modifierPointers.add(event.pointer);
      _engageModifier();
    }
  }

  void _controlTouchMove(PointerMoveEvent event) {
    if (!_groupPointers.contains(event.pointer)) {
      return;
    }
    if (!_groupLocked) {
      final down = _groupDownPositions[event.pointer];
      if (down == null || (event.localPosition - down).distance < _touchSlop) {
        return;
      }
      _lockGroup(firstMovedDelta: event.localPosition - down);
    }
    _dispatchGroupUpdate();
  }

  void _lockGroup({required Offset firstMovedDelta}) {
    _groupLocked = true;
    _groupAction = AppInput.touchDragActionFor(_groupPointers.length);
    switch (_groupAction) {
      case CanvasTouchDragAction.flip:
        _flipAxisHorizontal =
            firstMovedDelta.dx.abs() >= firstMovedDelta.dy.abs();
        _flipEmittedSteps = 0;
      case CanvasTouchDragAction.navigate:
        _anchorNavigate();
      case CanvasTouchDragAction.brushSize:
        _brushSizeActive = true;
        widget.onBrushSizeDragStart?.call();
      case CanvasTouchDragAction.none:
        break;
    }
  }

  void _dispatchGroupUpdate() {
    switch (_groupAction) {
      case CanvasTouchDragAction.flip:
        _updateFlip();
      case CanvasTouchDragAction.navigate:
        _updateNavigate();
      case CanvasTouchDragAction.brushSize:
        _updateBrushSize();
      case CanvasTouchDragAction.none:
        break;
    }
  }

  Offset _groupCentroid(Map<int, Offset> positions) {
    var sum = Offset.zero;
    for (final pointer in _groupPointers) {
      sum += positions[pointer] ?? Offset.zero;
    }
    return sum / _groupPointers.length.toDouble();
  }

  void _updateFlip() {
    final horizontal = _flipAxisHorizontal;
    if (horizontal == null) {
      return;
    }
    final downCentroid = _groupCentroid(_groupDownPositions);
    final nowCentroid = _groupCentroid(_touchPositions);
    final along = horizontal
        ? nowCentroid.dx - downCentroid.dx
        : nowCentroid.dy - downCentroid.dy;
    final steps = (along / flipStepExtent).truncate();
    while (_flipEmittedSteps != steps) {
      final forward = steps > _flipEmittedSteps;
      _flipEmittedSteps += forward ? 1 : -1;
      final fine =
          _modifierPointers.isNotEmpty &&
          AppInput.settings.value.extraFingerModifier;
      final actionId = horizontal
          ? (forward
                // Drag right = next, drag left = previous; the modifier
                // steps ONE FRAME (the Ctrl+arrow mapping) instead of one
                // drawing.
                ? (fine ? 'frame-next' : 'drawing-next')
                : (fine ? 'frame-previous' : 'drawing-previous'))
          // Drag up = layer up (the arrow-key arbitration path).
          : (forward ? 'selection-nudge-down' : 'selection-nudge-up');
      widget.onInvokeAction?.call(actionId);
    }
  }

  void _anchorNavigate() {
    final positions = {
      for (final pointer in _groupPointers)
        pointer: _touchPositions[pointer] ?? Offset.zero,
    };
    _navStartFocal = _groupCentroid(positions);
    if (_groupPointers.length >= 2) {
      final first = positions[_groupPointers[0]]!;
      final second = positions[_groupPointers[1]]!;
      _navStartDistance = (second - first).distance;
      _navStartAngle = _touchAngleDegrees(first, second);
    } else {
      _navStartDistance = null;
      _navStartAngle = null;
    }
    _navRotationCompensation = null;
    _navStartViewport = widget.viewport;
  }

  void _engageModifier() {
    if (_groupAction == CanvasTouchDragAction.navigate) {
      // Re-anchor so the constraint takes over from HERE, not from the
      // gesture start — the view never jumps when the finger lands.
      _navModifierActive = true;
      _navModifierLockRotation = widget.viewport.rotationDegrees;
      _anchorNavigate();
    }
  }

  void _releaseModifier() {
    if (_groupAction == CanvasTouchDragAction.navigate) {
      _navModifierActive = false;
      _navModifierLockRotation = null;
      _anchorNavigate();
    }
  }

  void _updateNavigate() {
    final startFocal = _navStartFocal;
    final startViewport = _navStartViewport;
    if (startFocal == null || startViewport == null) {
      return;
    }
    final settings = AppInput.settings.value;
    final modifier = _navModifierActive && settings.extraFingerModifier;
    final focal = _groupCentroid(_touchPositions);
    final focalAnchor = ViewportPoint(x: startFocal.dx, y: startFocal.dy);
    var next = startViewport;

    final startDistance = _navStartDistance;
    if (_groupPointers.length >= 2 && startDistance != null) {
      final first = _touchPositions[_groupPointers[0]];
      final second = _touchPositions[_groupPointers[1]];
      if (first != null && second != null) {
        final distance = (second - first).distance;
        if (startDistance > 0 && distance > 0) {
          var nextZoom = startViewport.zoom * (distance / startDistance);
          if (modifier) {
            // Constrain: zoom snaps to the user's percent list.
            nextZoom =
                AppInput.snapToList(nextZoom * 100, settings.zoomSnapPercents) /
                100;
          }
          next = next.zoomedAround(nextZoom: nextZoom, anchor: focalAnchor);
        }
        final rotationOn =
            widget.rotationEnabled && settings.navigationRotationEnabled;
        final startAngle = rotationOn ? _navStartAngle : null;
        if (startAngle != null) {
          final rawDelta = _wrapDegrees(
            _touchAngleDegrees(first, second) - startAngle,
          );
          if (_navRotationCompensation == null &&
              rawDelta.abs() >= rotationDeadzoneDegrees) {
            _navRotationCompensation = rawDelta.sign * rotationDeadzoneDegrees;
          }
          final compensation = _navRotationCompensation;
          if (compensation != null) {
            var nextRotation =
                startViewport.rotationDegrees + rawDelta - compensation;
            if (modifier) {
              final lockAngle = _navModifierLockRotation;
              if (settings.navigationModifierRotationLock &&
                  lockAngle != null) {
                // Constrain: rotation LOCKED at the modifier-engage angle
                // (pure pan + snapped zoom).
                nextRotation = lockAngle;
              } else {
                // Constrain: rotation snaps to the degree grid.
                final snap = settings.rotationSnapDegrees;
                if (snap > 0) {
                  nextRotation = (nextRotation / snap).round() * snap;
                }
              }
            } else {
              nextRotation = _snappedRotation(nextRotation);
            }
            next = next.rotatedAround(
              nextRotationDegrees: nextRotation,
              anchor: focalAnchor,
            );
          }
        }
      }
    }
    _emit(
      next.translated(
        dx: focal.dx - startFocal.dx,
        dy: focal.dy - startFocal.dy,
      ),
    );
  }

  void _updateBrushSize() {
    final downCentroid = _groupCentroid(_groupDownPositions);
    final nowCentroid = _groupCentroid(_touchPositions);
    // Vertical only (가로축은 의도적으로 비움): up = bigger.
    widget.onBrushSizeDragUpdate?.call(
      downCentroid.dy - nowCentroid.dy,
      snap:
          _modifierPointers.isNotEmpty &&
          AppInput.settings.value.extraFingerModifier,
    );
  }

  void _controlTouchLift(int pointer) {
    if (_modifierPointers.remove(pointer)) {
      _releaseModifier();
      return;
    }
    if (!_groupPointers.contains(pointer)) {
      return;
    }
    // Any BASE finger lifting ends the gesture whole.
    if (_brushSizeActive) {
      widget.onBrushSizeDragEnd?.call();
    }
    _resetControlEngine();
  }

  void _resetControlEngine() {
    _groupPointers.clear();
    _groupDownPositions.clear();
    _groupStartedAt = null;
    _groupLocked = false;
    _groupAction = CanvasTouchDragAction.none;
    _modifierPointers.clear();
    _flipAxisHorizontal = null;
    _flipEmittedSteps = 0;
    _navStartFocal = null;
    _navStartDistance = null;
    _navStartAngle = null;
    _navRotationCompensation = null;
    _navStartViewport = null;
    _navModifierActive = false;
    _navModifierLockRotation = null;
    _brushSizeActive = false;
  }

  /// (Re)arms or disarms the two-finger gesture as touch contacts come and
  /// go. Any contact-count change re-anchors the gesture at the current
  /// positions so a lifted/added finger never jumps the viewport.
  void _syncTouchNavigation() {
    if (_touchPositions.length < 2) {
      _touchNavPointers = null;
      _touchNavStartFocal = null;
      _touchNavStartDistance = null;
      _touchNavStartAngle = null;
      _touchNavRotationCompensation = null;
      _touchNavStartViewport = null;
      return;
    }

    final pointers = _touchPositions.keys.take(2).toList(growable: false);
    final first = _touchPositions[pointers[0]]!;
    final second = _touchPositions[pointers[1]]!;
    _touchNavPointers = pointers;
    _touchNavStartFocal = Offset(
      (first.dx + second.dx) / 2,
      (first.dy + second.dy) / 2,
    );
    _touchNavStartDistance = (second - first).distance;
    _touchNavStartAngle = _touchAngleDegrees(first, second);
    _touchNavRotationCompensation = null;
    _touchNavStartViewport = widget.viewport;
  }

  static double _touchAngleDegrees(Offset first, Offset second) {
    final vector = second - first;
    return math.atan2(vector.dy, vector.dx) * 180 / math.pi;
  }

  void _updateTouchNavigation() {
    // A non-touch stroke (stylus/mouse) stays active through stray touch
    // contacts — hold navigation and keep re-anchoring so the viewport
    // neither warps the stroke nor jumps when the stroke ends. (A TOUCH
    // stroke is cancelled by the second finger, clearing this flag.)
    if (widget.strokeActive) {
      _syncTouchNavigation();
      return;
    }

    final pointers = _touchNavPointers;
    final startFocal = _touchNavStartFocal;
    final startDistance = _touchNavStartDistance;
    final startViewport = _touchNavStartViewport;
    if (pointers == null ||
        startFocal == null ||
        startDistance == null ||
        startViewport == null) {
      return;
    }
    final first = _touchPositions[pointers[0]];
    final second = _touchPositions[pointers[1]];
    if (first == null || second == null) {
      return;
    }

    final focal = Offset(
      (first.dx + second.dx) / 2,
      (first.dy + second.dy) / 2,
    );
    final distance = (second - first).distance;
    final focalAnchor = ViewportPoint(x: startFocal.dx, y: startFocal.dy);
    // Scale around the START focal, then follow the fingers: the canvas
    // point that was under the initial focal stays under the current one.
    var next = startViewport;
    if (startDistance > 0 && distance > 0) {
      next = next.zoomedAround(
        nextZoom: startViewport.zoom * (distance / startDistance),
        anchor: focalAnchor,
      );
    }
    // Two-finger rotation (P8): the angle between the fingers turns the
    // view around the same focal — past the deadzone, so a plain pinch
    // stays level.
    final startAngle = widget.rotationEnabled ? _touchNavStartAngle : null;
    if (startAngle != null) {
      final rawDelta = _wrapDegrees(
        _touchAngleDegrees(first, second) - startAngle,
      );
      if (_touchNavRotationCompensation == null &&
          rawDelta.abs() >= rotationDeadzoneDegrees) {
        _touchNavRotationCompensation = rawDelta.sign * rotationDeadzoneDegrees;
      }
      final compensation = _touchNavRotationCompensation;
      if (compensation != null) {
        next = next.rotatedAround(
          nextRotationDegrees: _snappedRotation(
            startViewport.rotationDegrees + rawDelta - compensation,
          ),
          anchor: focalAnchor,
        );
      }
    }
    _emit(
      next.translated(
        dx: focal.dx - startFocal.dx,
        dy: focal.dy - startFocal.dy,
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        widget.strokeActive) {
      return;
    }
    final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
    _emit(
      widget.viewport.zoomedAround(
        nextZoom: widget.viewport.zoom * factor,
        anchor: ViewportPoint(
          x: event.localPosition.dx,
          y: event.localPosition.dy,
        ),
      ),
    );
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    if (widget.strokeActive) {
      return;
    }
    _panZoomStartViewport = widget.viewport;
    _panZoomRotationCompensation = null;
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final base = _panZoomStartViewport;
    if (base == null) {
      return;
    }
    final anchor = ViewportPoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
    );
    // Pan, scale and rotation are all cumulative since the gesture start,
    // so each update recomputes from the start viewport instead of
    // accumulating.
    var next = base;
    if (event.scale != 1.0) {
      next = base.zoomedAround(
        nextZoom: base.zoom * event.scale,
        anchor: anchor,
      );
    }
    // Trackpad rotation gesture (P8) — same deadzone/snap as two fingers.
    final rawDelta = widget.rotationEnabled
        ? event.rotation * 180 / math.pi
        : 0.0;
    if (_panZoomRotationCompensation == null &&
        rawDelta.abs() >= rotationDeadzoneDegrees) {
      _panZoomRotationCompensation = rawDelta.sign * rotationDeadzoneDegrees;
    }
    final compensation = _panZoomRotationCompensation;
    if (compensation != null) {
      next = next.rotatedAround(
        nextRotationDegrees: _snappedRotation(
          base.rotationDegrees + rawDelta - compensation,
        ),
        anchor: anchor,
      );
    }
    _emit(next.translated(dx: event.pan.dx, dy: event.pan.dy));
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    _panZoomStartViewport = null;
    _panZoomRotationCompensation = null;
  }

  void _clearPan() {
    _panPointer = null;
    _panStartLocalPosition = null;
    _panStartViewport = null;
  }

  void _emit(CanvasViewport viewport) {
    widget.onViewportChanged(viewport.clamped());
  }
}
