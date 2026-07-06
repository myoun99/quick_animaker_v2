import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/selected_exposure_display_range_policy.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_comma_drag_policy.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_range_resolver.dart';

void main() {
  group('TimelineExposureCommaDragSession', () {
    test('rejects non-positive frame cell extents', () {
      expect(
        () => TimelineExposureCommaDragSession(frameCellExtent: 0),
        throwsAssertionError,
      );
    });

    test('does not step before the drag crosses a cell midpoint', () {
      final session = TimelineExposureCommaDragSession(frameCellExtent: 48);
      var increases = 0;
      var decreases = 0;

      session.update(
        delta: 20,
        tryIncrease: () {
          increases += 1;
          return true;
        },
        tryDecrease: () {
          decreases += 1;
          return true;
        },
      );

      expect(increases, 0);
      expect(decreases, 0);
      expect(session.appliedSteps, 0);
    });

    test('emits one increase per crossed cell, accumulating across updates', () {
      final session = TimelineExposureCommaDragSession(frameCellExtent: 48);
      var increases = 0;

      session.update(
        delta: 30,
        tryIncrease: () {
          increases += 1;
          return true;
        },
        tryDecrease: () => fail('decrease not expected'),
      );
      expect(increases, 1);

      session.update(
        delta: 96,
        tryIncrease: () {
          increases += 1;
          return true;
        },
        tryDecrease: () => fail('decrease not expected'),
      );

      expect(increases, 3);
      expect(session.appliedSteps, 3);
    });

    test('reversing the drag emits decreases back to the resting point', () {
      final session = TimelineExposureCommaDragSession(frameCellExtent: 10);
      var increases = 0;
      var decreases = 0;
      bool countIncrease() {
        increases += 1;
        return true;
      }

      bool countDecrease() {
        decreases += 1;
        return true;
      }

      session.update(
        delta: 25,
        tryIncrease: countIncrease,
        tryDecrease: countDecrease,
      );
      expect(increases, 3);

      session.update(
        delta: -25,
        tryIncrease: countIncrease,
        tryDecrease: countDecrease,
      );

      expect(decreases, 3);
      expect(session.appliedSteps, 0);
    });

    test('a rejected step is not counted as applied', () {
      final session = TimelineExposureCommaDragSession(frameCellExtent: 10);
      var decreaseAttempts = 0;
      var increases = 0;

      // Drag three cells toward shorter, but only the first shorten lands
      // (e.g. the exposure is already at its minimum afterwards).
      session.update(
        delta: -30,
        tryIncrease: () => fail('increase not expected'),
        tryDecrease: () {
          decreaseAttempts += 1;
          return decreaseAttempts == 1;
        },
      );
      expect(decreaseAttempts, 2);
      expect(session.appliedSteps, -1);

      // Dragging back to the origin must replay from the APPLIED state:
      // exactly one increase undoes the single applied decrease.
      session.update(
        delta: 30,
        tryIncrease: () {
          increases += 1;
          return true;
        },
        tryDecrease: () => fail('decrease not expected'),
      );

      expect(increases, 1);
      expect(session.appliedSteps, 0);
    });
  });

  group('timelineCommaDragHandleVisible', () {
    SelectedExposureDisplayRange displayRange({
      required TimelineExposureRangeKind kind,
      int startFrameIndex = 0,
      int endFrameIndexExclusive = 2,
    }) {
      return SelectedExposureDisplayRange(
        resolvedRange: TimelineExposureRange(
          kind: kind,
          startFrameIndex: startFrameIndex,
          endFrameIndexExclusive: endFrameIndexExclusive,
          selectedFrameIndex: startFrameIndex,
        ),
        visibleStartFrameIndex: startFrameIndex,
        visibleEndFrameIndexExclusive: endFrameIndexExclusive,
      );
    }

    test('hidden when no exposure block is selected', () {
      expect(
        timelineCommaDragHandleVisible(
          displayRange: displayRange(kind: TimelineExposureRangeKind.none),
          exposureStateAt: (_) => TimelineCellExposureState.empty,
        ),
        isFalse,
      );
    });

    test('hidden for blank exposure blocks', () {
      expect(
        timelineCommaDragHandleVisible(
          displayRange: displayRange(kind: TimelineExposureRangeKind.blank),
          exposureStateAt: (_) => TimelineCellExposureState.empty,
        ),
        isFalse,
      );
    });

    test('visible for a drawing block whose end is a true block end', () {
      expect(
        timelineCommaDragHandleVisible(
          displayRange: displayRange(kind: TimelineExposureRangeKind.drawing),
          exposureStateAt: (frameIndex) => frameIndex == 2
              ? TimelineCellExposureState.empty
              : TimelineCellExposureState.drawingStart,
        ),
        isTrue,
      );
      expect(
        timelineCommaDragHandleVisible(
          displayRange: displayRange(kind: TimelineExposureRangeKind.drawing),
          exposureStateAt: (frameIndex) => frameIndex == 2
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.heldExposure,
        ),
        isTrue,
      );
    });

    test('hidden when the block is truncated by the resolved window', () {
      // The cell just past the resolved end still holds the same exposure,
      // so the block's real end lies beyond the virtualization window.
      expect(
        timelineCommaDragHandleVisible(
          displayRange: displayRange(kind: TimelineExposureRangeKind.drawing),
          exposureStateAt: (frameIndex) => frameIndex == 0
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.heldExposure,
        ),
        isFalse,
      );
    });
  });
}
