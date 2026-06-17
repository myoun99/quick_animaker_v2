import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_range_resolver.dart';

void main() {
  group('resolveTimelineExposureRange', () {
    test('empty selected frame returns none without inventing a range', () {
      final range = _resolve(
        selectedFrameIndex: 2,
        states: {2: TimelineCellExposureState.empty},
      );

      expect(range.kind, TimelineExposureRangeKind.none);
      expect(range.startFrameIndex, 2);
      expect(range.endFrameIndexExclusive, 2);
      expect(range.length, 0);
      expect(range.containsSelectedFrame, isFalse);
      expect(range.isBlock, isFalse);
    });

    test('drawingStart alone resolves single-frame drawing range', () {
      final range = _resolve(
        selectedFrameIndex: 3,
        states: {3: TimelineCellExposureState.drawingStart},
      );

      expect(range.kind, TimelineExposureRangeKind.drawing);
      expect(range.startFrameIndex, 3);
      expect(range.endFrameIndexExclusive, 4);
      expect(range.length, 1);
      expect(range.isSingleFrame, isTrue);
      expect(range.isStartFrame, isTrue);
      expect(range.isEndFrame, isTrue);
      expect(range.isMiddleFrame, isFalse);
    });

    test(
      'drawingStart with heldExposure cells resolves full drawing range',
      () {
        final range = _resolve(
          selectedFrameIndex: 0,
          states: {
            0: TimelineCellExposureState.drawingStart,
            1: TimelineCellExposureState.heldExposure,
            2: TimelineCellExposureState.heldExposure,
          },
        );

        expect(range.kind, TimelineExposureRangeKind.drawing);
        expect(range.startFrameIndex, 0);
        expect(range.endFrameIndexExclusive, 3);
        expect(range.isStartFrame, isTrue);
      },
    );

    test('heldExposure selection resolves back to drawing block start', () {
      final range = _resolve(
        selectedFrameIndex: 2,
        states: {
          0: TimelineCellExposureState.drawingStart,
          1: TimelineCellExposureState.heldExposure,
          2: TimelineCellExposureState.heldExposure,
          3: TimelineCellExposureState.heldExposure,
        },
      );

      expect(range.kind, TimelineExposureRangeKind.drawing);
      expect(range.startFrameIndex, 0);
      expect(range.endFrameIndexExclusive, 4);
      expect(range.isMiddleFrame, isTrue);
    });

    test('drawing range does not connect through blank or empty cells', () {
      final range = _resolve(
        selectedFrameIndex: 2,
        states: {
          0: TimelineCellExposureState.blankStart,
          1: TimelineCellExposureState.blankHeld,
          2: TimelineCellExposureState.heldExposure,
          3: TimelineCellExposureState.blankHeld,
          4: TimelineCellExposureState.heldExposure,
        },
      );

      expect(range.kind, TimelineExposureRangeKind.drawing);
      expect(range.startFrameIndex, 2);
      expect(range.endFrameIndexExclusive, 3);
      expect(range.isSingleFrame, isTrue);
    });

    test('blankStart alone resolves single-frame blank range', () {
      final range = _resolve(
        selectedFrameIndex: 5,
        states: {5: TimelineCellExposureState.blankStart},
      );

      expect(range.kind, TimelineExposureRangeKind.blank);
      expect(range.startFrameIndex, 5);
      expect(range.endFrameIndexExclusive, 6);
      expect(range.isSingleFrame, isTrue);
      expect(range.isStartFrame, isTrue);
      expect(range.isEndFrame, isTrue);
    });

    test('blankStart with blankHeld cells resolves full blank range', () {
      final range = _resolve(
        selectedFrameIndex: 4,
        states: {
          4: TimelineCellExposureState.blankStart,
          5: TimelineCellExposureState.blankHeld,
          6: TimelineCellExposureState.blankHeld,
        },
      );

      expect(range.kind, TimelineExposureRangeKind.blank);
      expect(range.startFrameIndex, 4);
      expect(range.endFrameIndexExclusive, 7);
      expect(range.isStartFrame, isTrue);
    });

    test('blankHeld selection resolves back to blank block start', () {
      final range = _resolve(
        selectedFrameIndex: 7,
        states: {
          5: TimelineCellExposureState.blankStart,
          6: TimelineCellExposureState.blankHeld,
          7: TimelineCellExposureState.blankHeld,
          8: TimelineCellExposureState.blankHeld,
        },
      );

      expect(range.kind, TimelineExposureRangeKind.blank);
      expect(range.startFrameIndex, 5);
      expect(range.endFrameIndexExclusive, 9);
      expect(range.isMiddleFrame, isTrue);
    });

    test('blank range does not connect through drawing or empty cells', () {
      final range = _resolve(
        selectedFrameIndex: 3,
        states: {
          1: TimelineCellExposureState.drawingStart,
          2: TimelineCellExposureState.heldExposure,
          3: TimelineCellExposureState.blankHeld,
          4: TimelineCellExposureState.heldExposure,
          5: TimelineCellExposureState.blankHeld,
        },
      );

      expect(range.kind, TimelineExposureRangeKind.blank);
      expect(range.startFrameIndex, 3);
      expect(range.endFrameIndexExclusive, 4);
      expect(range.isSingleFrame, isTrue);
    });

    test('respects lower bound for a partially visible drawing range', () {
      final queried = <int>[];
      final range = _resolve(
        selectedFrameIndex: 2,
        minFrameIndex: 2,
        maxFrameIndexExclusive: 5,
        states: {
          1: TimelineCellExposureState.drawingStart,
          2: TimelineCellExposureState.heldExposure,
          3: TimelineCellExposureState.heldExposure,
          4: TimelineCellExposureState.heldExposure,
        },
        onQuery: queried.add,
      );

      expect(range.kind, TimelineExposureRangeKind.drawing);
      expect(range.startFrameIndex, 2);
      expect(range.endFrameIndexExclusive, 5);
      expect(queried, isNot(contains(1)));
    });

    test('respects upper bound for a partially visible blank range', () {
      final queried = <int>[];
      final range = _resolve(
        selectedFrameIndex: 8,
        minFrameIndex: 6,
        maxFrameIndexExclusive: 9,
        states: {
          6: TimelineCellExposureState.blankStart,
          7: TimelineCellExposureState.blankHeld,
          8: TimelineCellExposureState.blankHeld,
          9: TimelineCellExposureState.blankHeld,
        },
        onQuery: queried.add,
      );

      expect(range.kind, TimelineExposureRangeKind.blank);
      expect(range.startFrameIndex, 6);
      expect(range.endFrameIndexExclusive, 9);
      expect(queried, isNot(contains(9)));
    });

    test(
      'outside-bounds selection returns safe none and performs no reads',
      () {
        var queryCount = 0;
        final range = resolveTimelineExposureRange(
          selectedFrameIndex: 12,
          minFrameIndex: 0,
          maxFrameIndexExclusive: 10,
          exposureStateAt: (_) {
            queryCount += 1;
            return TimelineCellExposureState.drawingStart;
          },
        );

        expect(range.kind, TimelineExposureRangeKind.none);
        expect(range.startFrameIndex, 12);
        expect(range.endFrameIndexExclusive, 12);
        expect(queryCount, 0);
      },
    );

    test('empty bounds selection returns safe none and performs no reads', () {
      var queryCount = 0;
      final range = resolveTimelineExposureRange(
        selectedFrameIndex: 0,
        minFrameIndex: 0,
        maxFrameIndexExclusive: 0,
        exposureStateAt: (_) {
          queryCount += 1;
          return TimelineCellExposureState.drawingStart;
        },
      );

      expect(range.kind, TimelineExposureRangeKind.none);
      expect(range.startFrameIndex, 0);
      expect(range.endFrameIndexExclusive, 0);
      expect(queryCount, 0);
    });
  });
}

TimelineExposureRange _resolve({
  required int selectedFrameIndex,
  required Map<int, TimelineCellExposureState> states,
  int minFrameIndex = 0,
  int maxFrameIndexExclusive = 10,
  void Function(int frameIndex)? onQuery,
}) {
  return resolveTimelineExposureRange(
    selectedFrameIndex: selectedFrameIndex,
    minFrameIndex: minFrameIndex,
    maxFrameIndexExclusive: maxFrameIndexExclusive,
    exposureStateAt: (frameIndex) {
      if (frameIndex < minFrameIndex || frameIndex >= maxFrameIndexExclusive) {
        throw StateError('Read outside bounds: $frameIndex');
      }
      onQuery?.call(frameIndex);
      return states[frameIndex] ?? TimelineCellExposureState.empty;
    },
  );
}
