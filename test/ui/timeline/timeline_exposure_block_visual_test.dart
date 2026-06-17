import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_block_visual.dart';

void main() {
  group('calculateTimelineExposureBlockVisualSegment', () {
    test('empty cells never become exposure blocks', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.drawingStart,
        current: TimelineCellExposureState.empty,
        next: TimelineCellExposureState.heldExposure,
      );

      expect(segment.kind, TimelineExposureBlockKind.none);
      expect(segment.isBlock, isFalse);
      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isFalse);
    });

    test('drawingStart connects to following held drawing cells only', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.heldExposure,
        current: TimelineCellExposureState.drawingStart,
        next: TimelineCellExposureState.heldExposure,
      );

      expect(segment.kind, TimelineExposureBlockKind.drawing);
      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isTrue);
    });

    test('heldExposure connects to adjacent drawing exposure states', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.drawingStart,
        current: TimelineCellExposureState.heldExposure,
        next: TimelineCellExposureState.heldExposure,
      );

      expect(segment.kind, TimelineExposureBlockKind.drawing);
      expect(segment.continuesFromPrevious, isTrue);
      expect(segment.continuesToNext, isTrue);
    });

    test('blankStart connects to following blank held cells only', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.blankHeld,
        current: TimelineCellExposureState.blankStart,
        next: TimelineCellExposureState.blankHeld,
      );

      expect(segment.kind, TimelineExposureBlockKind.blank);
      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isTrue);
    });

    test('blankHeld connects to adjacent blank exposure states', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.blankStart,
        current: TimelineCellExposureState.blankHeld,
        next: TimelineCellExposureState.blankHeld,
      );

      expect(segment.kind, TimelineExposureBlockKind.blank);
      expect(segment.continuesFromPrevious, isTrue);
      expect(segment.continuesToNext, isTrue);
    });

    test('different exposure kinds do not connect visually', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.blankStart,
        current: TimelineCellExposureState.heldExposure,
        next: TimelineCellExposureState.blankHeld,
      );

      expect(segment.kind, TimelineExposureBlockKind.drawing);
      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isFalse);
    });

    test('heldExposure followed by drawingStart does not connect forward', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.drawingStart,
        current: TimelineCellExposureState.heldExposure,
        next: TimelineCellExposureState.drawingStart,
      );

      expect(segment.kind, TimelineExposureBlockKind.drawing);
      expect(segment.continuesFromPrevious, isTrue);
      expect(segment.continuesToNext, isFalse);
    });

    test('drawingStart preceded by heldExposure does not connect backward', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.heldExposure,
        current: TimelineCellExposureState.drawingStart,
        next: TimelineCellExposureState.empty,
      );

      expect(segment.kind, TimelineExposureBlockKind.drawing);
      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isFalse);
    });

    test('blankHeld followed by blankStart does not connect forward', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.blankStart,
        current: TimelineCellExposureState.blankHeld,
        next: TimelineCellExposureState.blankStart,
      );

      expect(segment.kind, TimelineExposureBlockKind.blank);
      expect(segment.continuesFromPrevious, isTrue);
      expect(segment.continuesToNext, isFalse);
    });

    test('blankStart preceded by blankHeld does not connect backward', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.blankHeld,
        current: TimelineCellExposureState.blankStart,
        next: TimelineCellExposureState.empty,
      );

      expect(segment.kind, TimelineExposureBlockKind.blank);
      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isFalse);
    });

    test('single drawingStart has both sides rounded', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.empty,
        current: TimelineCellExposureState.drawingStart,
        next: TimelineCellExposureState.empty,
      );

      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isFalse);
    });

    test('single blankStart has both sides rounded', () {
      final segment = calculateTimelineExposureBlockVisualSegment(
        previous: TimelineCellExposureState.empty,
        current: TimelineCellExposureState.blankStart,
        next: TimelineCellExposureState.empty,
      );

      expect(segment.continuesFromPrevious, isFalse);
      expect(segment.continuesToNext, isFalse);
    });
  });
}
