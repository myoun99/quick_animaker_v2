import 'timeline_cell_exposure_state.dart';

enum TimelineExposureBlockKind { none, drawing, blank }

class TimelineExposureBlockVisualSegment {
  const TimelineExposureBlockVisualSegment({
    required this.kind,
    required this.continuesFromPrevious,
    required this.continuesToNext,
  });

  final TimelineExposureBlockKind kind;
  final bool continuesFromPrevious;
  final bool continuesToNext;

  bool get isBlock => kind != TimelineExposureBlockKind.none;
}

TimelineExposureBlockVisualSegment calculateTimelineExposureBlockVisualSegment({
  required TimelineCellExposureState? previous,
  required TimelineCellExposureState current,
  required TimelineCellExposureState? next,
}) {
  final kind = _kindForState(current);
  if (kind == TimelineExposureBlockKind.none) {
    return const TimelineExposureBlockVisualSegment(
      kind: TimelineExposureBlockKind.none,
      continuesFromPrevious: false,
      continuesToNext: false,
    );
  }

  return TimelineExposureBlockVisualSegment(
    kind: kind,
    continuesFromPrevious: switch (current) {
      TimelineCellExposureState.heldExposure => _isDrawingContinuation(previous),
      TimelineCellExposureState.blankHeld => _isBlankContinuation(previous),
      TimelineCellExposureState.drawingStart ||
      TimelineCellExposureState.blankStart ||
      TimelineCellExposureState.empty => false,
    },
    continuesToNext: switch (current) {
      TimelineCellExposureState.drawingStart ||
      TimelineCellExposureState.heldExposure => _isDrawingContinuation(next),
      TimelineCellExposureState.blankStart ||
      TimelineCellExposureState.blankHeld => _isBlankContinuation(next),
      TimelineCellExposureState.empty => false,
    },
  );
}

TimelineExposureBlockKind _kindForState(TimelineCellExposureState state) {
  return switch (state) {
    TimelineCellExposureState.empty => TimelineExposureBlockKind.none,
    TimelineCellExposureState.drawingStart ||
    TimelineCellExposureState.heldExposure => TimelineExposureBlockKind.drawing,
    TimelineCellExposureState.blankStart ||
    TimelineCellExposureState.blankHeld => TimelineExposureBlockKind.blank,
  };
}

bool _isDrawingContinuation(TimelineCellExposureState? state) {
  return state == TimelineCellExposureState.drawingStart ||
      state == TimelineCellExposureState.heldExposure;
}

bool _isBlankContinuation(TimelineCellExposureState? state) {
  return state == TimelineCellExposureState.blankStart ||
      state == TimelineCellExposureState.blankHeld;
}
