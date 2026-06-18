import 'dart:math' as math;

import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_range_resolver.dart';

class SelectedExposureDisplayRange {
  const SelectedExposureDisplayRange({
    required this.resolvedRange,
    required this.visibleStartFrameIndex,
    required this.visibleEndFrameIndexExclusive,
  });

  final TimelineExposureRange resolvedRange;
  final int visibleStartFrameIndex;
  final int visibleEndFrameIndexExclusive;

  bool get hasVisibleIntersection =>
      visibleStartFrameIndex < visibleEndFrameIndexExclusive;
}

SelectedExposureDisplayRange resolveSelectedExposureDisplayRange({
  required bool active,
  required int currentFrameIndex,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
}) {
  if (!active) {
    return const SelectedExposureDisplayRange(
      resolvedRange: TimelineExposureRange(
        kind: TimelineExposureRangeKind.none,
        startFrameIndex: 0,
        endFrameIndexExclusive: 0,
        selectedFrameIndex: 0,
      ),
      visibleStartFrameIndex: 0,
      visibleEndFrameIndexExclusive: 0,
    );
  }

  final resolvedRange = resolveTimelineExposureRange(
    selectedFrameIndex: currentFrameIndex,
    minFrameIndex: 0,
    maxFrameIndexExclusive: math.max(
      frameEndIndexExclusive,
      currentFrameIndex + 1,
    ),
    exposureStateAt: exposureStateAt,
  );

  if (!resolvedRange.isBlock) {
    return SelectedExposureDisplayRange(
      resolvedRange: resolvedRange,
      visibleStartFrameIndex: 0,
      visibleEndFrameIndexExclusive: 0,
    );
  }

  final visibleStartFrameIndex = math.max(
    resolvedRange.startFrameIndex,
    frameStartIndex,
  );
  final visibleEndFrameIndexExclusive = math.min(
    resolvedRange.endFrameIndexExclusive,
    frameEndIndexExclusive,
  );

  return SelectedExposureDisplayRange(
    resolvedRange: resolvedRange,
    visibleStartFrameIndex: visibleStartFrameIndex,
    visibleEndFrameIndexExclusive: visibleEndFrameIndexExclusive,
  );
}
