import 'timeline_cell_exposure_state.dart';

enum TimelineExposureRangeKind { none, drawing }

class TimelineExposureRange {
  const TimelineExposureRange({
    required this.kind,
    required this.startFrameIndex,
    required this.endFrameIndexExclusive,
    required this.selectedFrameIndex,
  });

  final TimelineExposureRangeKind kind;
  final int startFrameIndex;
  final int endFrameIndexExclusive;
  final int selectedFrameIndex;

  int get length => endFrameIndexExclusive - startFrameIndex;

  bool get containsSelectedFrame =>
      selectedFrameIndex >= startFrameIndex &&
      selectedFrameIndex < endFrameIndexExclusive;

  bool get isSingleFrame => length == 1;

  bool get isStartFrame =>
      kind != TimelineExposureRangeKind.none &&
      containsSelectedFrame &&
      selectedFrameIndex == startFrameIndex;

  bool get isEndFrame =>
      kind != TimelineExposureRangeKind.none &&
      containsSelectedFrame &&
      selectedFrameIndex == endFrameIndexExclusive - 1;

  bool get isMiddleFrame =>
      kind != TimelineExposureRangeKind.none &&
      containsSelectedFrame &&
      !isStartFrame &&
      !isEndFrame;

  bool get isBlock => kind != TimelineExposureRangeKind.none;
}

/// The covered block run containing [selectedFrameIndex], resolved from
/// cell states so non-model rows (the camera keyframe row) keep working.
/// Under explicit block lengths a covered run always ends at the block's
/// true end — a drawing start on either side bounds the run even when two
/// blocks are glued.
TimelineExposureRange resolveTimelineExposureRange({
  required int selectedFrameIndex,
  required int minFrameIndex,
  required int maxFrameIndexExclusive,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
}) {
  TimelineExposureRange none() => TimelineExposureRange(
    kind: TimelineExposureRangeKind.none,
    startFrameIndex: selectedFrameIndex,
    endFrameIndexExclusive: selectedFrameIndex,
    selectedFrameIndex: selectedFrameIndex,
  );

  if (minFrameIndex >= maxFrameIndexExclusive ||
      selectedFrameIndex < minFrameIndex ||
      selectedFrameIndex >= maxFrameIndexExclusive) {
    return none();
  }

  final selectedState = exposureStateAt(selectedFrameIndex);
  if (!selectedState.isCovered) {
    return none();
  }

  var startFrameIndex = selectedFrameIndex;
  while (startFrameIndex > minFrameIndex &&
      exposureStateAt(startFrameIndex) !=
          TimelineCellExposureState.drawingStart) {
    final previousState = exposureStateAt(startFrameIndex - 1);
    if (!previousState.isCovered) {
      break;
    }
    startFrameIndex -= 1;
  }

  var endFrameIndexExclusive = selectedFrameIndex + 1;
  while (endFrameIndexExclusive < maxFrameIndexExclusive) {
    final nextState = exposureStateAt(endFrameIndexExclusive);
    if (!nextState.isCovered ||
        nextState == TimelineCellExposureState.drawingStart) {
      break;
    }
    endFrameIndexExclusive += 1;
  }

  return TimelineExposureRange(
    kind: TimelineExposureRangeKind.drawing,
    startFrameIndex: startFrameIndex,
    endFrameIndexExclusive: endFrameIndexExclusive,
    selectedFrameIndex: selectedFrameIndex,
  );
}
