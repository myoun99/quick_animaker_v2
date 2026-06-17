import 'timeline_cell_exposure_state.dart';

enum TimelineExposureRangeKind { none, drawing, blank }

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

TimelineExposureRange resolveTimelineExposureRange({
  required int selectedFrameIndex,
  required int minFrameIndex,
  required int maxFrameIndexExclusive,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
}) {
  if (minFrameIndex >= maxFrameIndexExclusive ||
      selectedFrameIndex < minFrameIndex ||
      selectedFrameIndex >= maxFrameIndexExclusive) {
    return TimelineExposureRange(
      kind: TimelineExposureRangeKind.none,
      startFrameIndex: selectedFrameIndex,
      endFrameIndexExclusive: selectedFrameIndex,
      selectedFrameIndex: selectedFrameIndex,
    );
  }

  final selectedState = exposureStateAt(selectedFrameIndex);
  return switch (selectedState) {
    TimelineCellExposureState.empty => TimelineExposureRange(
      kind: TimelineExposureRangeKind.none,
      startFrameIndex: selectedFrameIndex,
      endFrameIndexExclusive: selectedFrameIndex,
      selectedFrameIndex: selectedFrameIndex,
    ),
    TimelineCellExposureState.drawingStart ||
    TimelineCellExposureState.heldExposure => _resolveConnectedRange(
      kind: TimelineExposureRangeKind.drawing,
      selectedFrameIndex: selectedFrameIndex,
      minFrameIndex: minFrameIndex,
      maxFrameIndexExclusive: maxFrameIndexExclusive,
      exposureStateAt: exposureStateAt,
      canContinueBackward: (state) =>
          state == TimelineCellExposureState.heldExposure,
      canContinueForward: (state) =>
          state == TimelineCellExposureState.heldExposure,
      isBlockStart: (state) => state == TimelineCellExposureState.drawingStart,
    ),
    TimelineCellExposureState.blankStart ||
    TimelineCellExposureState.blankHeld => _resolveConnectedRange(
      kind: TimelineExposureRangeKind.blank,
      selectedFrameIndex: selectedFrameIndex,
      minFrameIndex: minFrameIndex,
      maxFrameIndexExclusive: maxFrameIndexExclusive,
      exposureStateAt: exposureStateAt,
      canContinueBackward: (state) =>
          state == TimelineCellExposureState.blankHeld,
      canContinueForward: (state) =>
          state == TimelineCellExposureState.blankHeld,
      isBlockStart: (state) => state == TimelineCellExposureState.blankStart,
    ),
  };
}

TimelineExposureRange _resolveConnectedRange({
  required TimelineExposureRangeKind kind,
  required int selectedFrameIndex,
  required int minFrameIndex,
  required int maxFrameIndexExclusive,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
  required bool Function(TimelineCellExposureState state) canContinueBackward,
  required bool Function(TimelineCellExposureState state) canContinueForward,
  required bool Function(TimelineCellExposureState state) isBlockStart,
}) {
  var startFrameIndex = selectedFrameIndex;
  while (startFrameIndex > minFrameIndex) {
    final previousFrameIndex = startFrameIndex - 1;
    final previousState = exposureStateAt(previousFrameIndex);
    if (isBlockStart(previousState)) {
      startFrameIndex = previousFrameIndex;
      break;
    }
    if (!canContinueBackward(previousState)) {
      break;
    }
    startFrameIndex = previousFrameIndex;
  }

  var endFrameIndexExclusive = selectedFrameIndex + 1;
  while (endFrameIndexExclusive < maxFrameIndexExclusive) {
    final nextState = exposureStateAt(endFrameIndexExclusive);
    if (!canContinueForward(nextState)) {
      break;
    }
    endFrameIndexExclusive += 1;
  }

  return TimelineExposureRange(
    kind: kind,
    startFrameIndex: startFrameIndex,
    endFrameIndexExclusive: endFrameIndexExclusive,
    selectedFrameIndex: selectedFrameIndex,
  );
}
