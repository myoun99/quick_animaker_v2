import 'package:flutter/gestures.dart';

import '../debug/input_inspector.dart' show InputInspector;

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

  // PEN-11 field probes (no-ops while the Input Inspector is hidden):
  // the arena verdict with the accumulated distance at that moment. An
  // 'ep rej' BELOW the hit slop means a competitor accepted before this
  // recognizer even reached its threshold — the on-device measurement
  // the desktop tests can't take.
  String _probeSuffix(PointerDeviceKind kind) {
    final threshold = computeHitSlop(kind, gestureSettings);
    return 'd=${globalDistanceMoved.abs().toStringAsFixed(1)}'
        ' thr=${threshold.toStringAsFixed(1)}'
        ' ts=${gestureSettings?.touchSlop?.toStringAsFixed(1)}';
  }

  @override
  void acceptGesture(int pointer) {
    InputInspector.note('ep acc ${_probeSuffix(PointerDeviceKind.stylus)}');
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    InputInspector.note('ep rej ${_probeSuffix(PointerDeviceKind.stylus)}');
    super.rejectGesture(pointer);
  }
}
