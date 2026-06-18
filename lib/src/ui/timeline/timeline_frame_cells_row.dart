import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_frame_cell.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_selected_exposure_outline.dart';

class TimelineFrameCellsRow extends StatelessWidget {
  const TimelineFrameCellsRow({
    super.key,
    required this.layer,
    required this.active,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    required this.exposureStateForLayer,
    this.hasMarkForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final bool active;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final bool Function(Layer layer, int frameIndex)? hasMarkForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final selectedExposureDisplayRange = resolveSelectedExposureDisplayRange(
      active: active,
      currentFrameIndex: currentFrameIndex,
      frameStartIndex: frameStartIndex,
      frameEndIndexExclusive: frameEndIndexExclusive,
      exposureStateAt: (frameIndex) => exposureStateForLayer(layer, frameIndex),
    );
    final selectedExposureRange = selectedExposureDisplayRange.resolvedRange;
    return Stack(
      key: ValueKey<String>('timeline-frame-row-area-${layer.id}'),
      children: [
        Row(
          children: [
            SizedBox(
              key: ValueKey<String>(
                'timeline-frame-row-leading-spacer-${layer.id}',
              ),
              width: leadingFrameSpacerWidth,
              height: metrics.layerRowHeight,
            ),
            for (
              var frameIndex = frameStartIndex;
              frameIndex < frameEndIndexExclusive;
              frameIndex += 1
            )
              TimelineFrameCell(
                layer: layer,
                frameIndex: frameIndex,
                active: active,
                selected: active && frameIndex == currentFrameIndex,
                outsidePlaybackRange: frameIndex >= playbackFrameCount,
                exposureState: exposureStateForLayer(layer, frameIndex),
                selectedExposureRangeSegment:
                    frameIndex >= selectedExposureRange.startFrameIndex &&
                    frameIndex < selectedExposureRange.endFrameIndexExclusive,
                exposureBlockSegment:
                    calculateTimelineExposureBlockVisualSegment(
                      previous: frameIndex == 0
                          ? null
                          : exposureStateForLayer(layer, frameIndex - 1),
                      current: exposureStateForLayer(layer, frameIndex),
                      next: exposureStateForLayer(layer, frameIndex + 1),
                    ),
                hasMark: hasMarkForLayer?.call(layer, frameIndex) ?? false,
                frameName: frameNameForLayer?.call(layer, frameIndex),
                onSelectLayer: onSelectLayer,
                onSelectFrame: onSelectFrame,
              ),
            SizedBox(
              key: ValueKey<String>(
                'timeline-frame-row-trailing-spacer-${layer.id}',
              ),
              width: trailingFrameSpacerWidth,
              height: metrics.layerRowHeight,
            ),
          ],
        ),
        TimelineSelectedExposureOutline(
          layerId: layer.id,
          displayRange: selectedExposureDisplayRange,
          frameStartIndex: frameStartIndex,
          leadingFrameSpacerWidth: leadingFrameSpacerWidth,
          frameCellWidth: metrics.frameCellWidth,
          rowHeight: metrics.layerRowHeight,
          borderColor: timelineSelectedFrameBorderColor,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
      ],
    );
  }
}
