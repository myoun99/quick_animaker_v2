import 'dart:math' as math;

import 'timeline_grid_metrics.dart';
import 'timeline_virtualization_plan.dart';

/// Calculates a TimelinePanel/LayerTimelineGrid virtualization plan using the
/// same dimensions as the current grid UI.
///
/// This adapter is calculation-only: it does not build widgets and does not
/// depend on project domain models.
TimelineVirtualizationPlan calculateLayerTimelineGridVirtualizationPlan({
  required double horizontalScrollOffset,
  required double verticalScrollOffset,
  required double viewportWidth,
  required double viewportHeight,
  required int visibleFrameCount,
  required int layerCount,
  TimelineGridMetrics metrics = TimelineGridMetrics.defaults,
  int frameOverscanBefore = 2,
  int frameOverscanAfter = 2,
  int layerOverscanBefore = 2,
  int layerOverscanAfter = 2,
}) {
  final effectiveFrameCount = math.max(
    visibleFrameCount,
    metrics.minimumVisibleFrameCells,
  );

  return calculateTimelineVirtualizationPlan(
    horizontalScrollOffset: horizontalScrollOffset,
    verticalScrollOffset: verticalScrollOffset,
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    frameCellWidth: metrics.frameCellWidth,
    layerRowHeight: metrics.layerRowHeight,
    frameCount: effectiveFrameCount,
    layerCount: layerCount,
    frameOverscanBefore: frameOverscanBefore,
    frameOverscanAfter: frameOverscanAfter,
    layerOverscanBefore: layerOverscanBefore,
    layerOverscanAfter: layerOverscanAfter,
  );
}
