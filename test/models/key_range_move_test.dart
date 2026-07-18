import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/camera_instruction.dart';
import 'package:quick_animaker_v2/src/models/camera_pose.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/key_range_move.dart';

/// P3b-2 (#2 second half): camera keys and instruction spans shift with a
/// range selection — rigid, all-or-nothing.
void main() {
  final pose = CameraPose(center: CanvasPoint(x: 0, y: 0));

  group('shiftCameraKeysInRange', () {
    final keys = {2: pose, 4: pose, 9: pose};

    test('shifts exactly the keys in range; the rest stay', () {
      final shifted = shiftCameraKeysInRange(
        keyframes: keys,
        rangeStartIndex: 2,
        rangeEndIndexExclusive: 5,
        frameDelta: 3,
      );
      expect(shifted!.keys.toSet(), {5, 7, 9});
    });

    test('a landing on an UNSHIFTED key voids the plan', () {
      expect(
        shiftCameraKeysInRange(
          keyframes: keys,
          rangeStartIndex: 2,
          rangeEndIndexExclusive: 3,
          frameDelta: 2,
        ),
        isNull,
        reason: '2+2 lands on the unmoved 4',
      );
    });

    test('negative landings, empty ranges and zero deltas void', () {
      expect(
        shiftCameraKeysInRange(
          keyframes: keys,
          rangeStartIndex: 2,
          rangeEndIndexExclusive: 5,
          frameDelta: -3,
        ),
        isNull,
        reason: '2-3 dips below 0',
      );
      expect(
        shiftCameraKeysInRange(
          keyframes: keys,
          rangeStartIndex: 6,
          rangeEndIndexExclusive: 8,
          frameDelta: 2,
        ),
        isNull,
        reason: 'no keys in range',
      );
      expect(
        shiftCameraKeysInRange(
          keyframes: keys,
          rangeStartIndex: 2,
          rangeEndIndexExclusive: 5,
          frameDelta: 0,
        ),
        isNull,
      );
    });

    test('keys within the moved set may swap places freely', () {
      final shifted = shiftCameraKeysInRange(
        keyframes: {2: pose, 3: pose},
        rangeStartIndex: 2,
        rangeEndIndexExclusive: 4,
        frameDelta: 1,
      );
      expect(shifted!.keys.toSet(), {3, 4}, reason: '3 vacates before 2 lands');
    });
  });

  group('shiftInstructionEventsInRange', () {
    const pan = InstructionEvent(instructionId: 'pan', length: 3);
    const zoom = InstructionEvent(instructionId: 'zoom', length: 2);

    test('shifts events STARTING in range; overlap with an unmoved event '
        'voids', () {
      final events = {1: pan, 8: zoom};
      final shifted = shiftInstructionEventsInRange(
        events: events,
        rangeStartIndex: 0,
        rangeEndIndexExclusive: 4,
        frameDelta: 3,
      );
      expect(shifted!.keys.toSet(), {4, 8});
      expect(shifted[4], same(pan));

      expect(
        shiftInstructionEventsInRange(
          events: events,
          rangeStartIndex: 0,
          rangeEndIndexExclusive: 4,
          frameDelta: 6,
        ),
        isNull,
        reason: 'pan at [7,10) would overlap zoom at [8,10)',
      );
    });

    test('negative landings void', () {
      expect(
        shiftInstructionEventsInRange(
          events: const {1: pan},
          rangeStartIndex: 0,
          rangeEndIndexExclusive: 4,
          frameDelta: -2,
        ),
        isNull,
      );
    });
  });
}
