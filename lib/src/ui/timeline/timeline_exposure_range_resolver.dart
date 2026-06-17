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
    TimelineCellExposureState.drawingStart => _resolveConnectedRange(
      kind: TimelineExposureRangeKind.drawing,
      selectedFrameIndex: selectedFrameIndex,
      minFrameIndex: minFrameIndex,
      maxFrameIndexExclusive: maxFrameIndexExclusive,
      exposureStateAt: exposureStateAt,
      searchBackward: false,
      continuationState: TimelineCellExposureState.heldExposure,
      blockStartState: TimelineCellExposureState.drawingStart,
    ),
    TimelineCellExposureState.heldExposure => _resolveConnectedRange(
      kind: TimelineExposureRangeKind.drawing,
      selectedFrameIndex: selectedFrameIndex,
      minFrameIndex: minFrameIndex,
      maxFrameIndexExclusive: maxFrameIndexExclusive,
      exposureStateAt: exposureStateAt,
      searchBackward: true,
      continuationState: TimelineCellExposureState.heldExposure,
      blockStartState: TimelineCellExposureState.drawingStart,
    ),
    TimelineCellExposureState.blankStart => _resolveConnectedRange(
      kind: TimelineExposureRangeKind.blank,
      selectedFrameIndex: selectedFrameIndex,
      minFrameIndex: minFrameIndex,
      maxFrameIndexExclusive: maxFrameIndexExclusive,
      exposureStateAt: exposureStateAt,
      searchBackward: false,
      continuationState: TimelineCellExposureState.blankHeld,
      blockStartState: TimelineCellExposureState.blankStart,
    ),
    TimelineCellExposureState.blankHeld => _resolveConnectedRange(
      kind: TimelineExposureRangeKind.blank,
      selectedFrameIndex: selectedFrameIndex,
      minFrameIndex: minFrameIndex,
      maxFrameIndexExclusive: maxFrameIndexExclusive,
      exposureStateAt: exposureStateAt,
      searchBackward: true,
      continuationState: TimelineCellExposureState.blankHeld,
      blockStartState: TimelineCellExposureState.blankStart,
    ),
  };
}

TimelineExposureRange _resolveConnectedRange({
  required TimelineExposureRangeKind kind,
  required int selectedFrameIndex,
  required int minFrameIndex,
  required int maxFrameIndexExclusive,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
  required bool searchBackward,
  required TimelineCellExposureState continuationState,
  required TimelineCellExposureState blockStartState,
}) {
  var startFrameIndex = selectedFrameIndex;
  if (searchBackward) {
    while (startFrameIndex > minFrameIndex) {
      final previousFrameIndex = startFrameIndex - 1;
      final previousState = exposureStateAt(previousFrameIndex);
      if (previousState == blockStartState) {
        startFrameIndex = previousFrameIndex;
        break;
      }
      if (previousState != continuationState) {
        break;
      }
      startFrameIndex = previousFrameIndex;
    }
  }

  var endFrameIndexExclusive = selectedFrameIndex + 1;
  while (endFrameIndexExclusive < maxFrameIndexExclusive) {
    final nextState = exposureStateAt(endFrameIndexExclusive);
    if (nextState != continuationState) {
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
