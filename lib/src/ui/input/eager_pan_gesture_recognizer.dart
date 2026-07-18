import 'package:flutter/gestures.dart';

/// A [PanGestureRecognizer] that accepts at the DIRECTIONAL hit slop
/// (~18px, [computeHitSlop]) instead of the pan slop (~36px,
/// [computePanSlop]) — UI-R22F #2.
///
/// Why: the timeline's edit pans (range select/move, block moves, run
/// [+] adds, lane value scrubs) sit INSIDE scroll viewports whose
/// directional drag recognizers accept at the hit slop. A plain pan
/// needed twice the distance, so slow small drags lost the arena to the
/// scroll while fast large drags crossed both thresholds in one event
/// and won as the deeper recognizer — the "random"-feeling split. With
/// the SAME slop, the edit pan's total distance reaches the threshold no
/// later than any axis component can, and the deeper recognizer handles
/// the event first: the edit gesture now wins deterministically on its
/// hit area for every device it supports.
class EagerPanGestureRecognizer extends PanGestureRecognizer {
  EagerPanGestureRecognizer({super.debugOwner, super.supportedDevices});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings);
}
