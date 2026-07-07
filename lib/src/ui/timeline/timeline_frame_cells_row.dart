import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_coverage.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cell.dart';
import 'timeline_frame_coordinate_policy.dart';
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
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.commaDrag,
    this.sectionStart = false,
  });

  /// Whether this row opens a new timesheet section (drawing/SE/camera);
  /// draws a heavier divider along the row's top edge without changing the
  /// row geometry.
  final bool sectionStart;

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
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// Comma-drag hooks; null hides the block edge grips.
  final TimelineCommaDragCallbacks? commaDrag;

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
    final commaDrag = this.commaDrag;

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
                width: metrics.frameCellWidth,
                height: metrics.layerRowHeight,
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
                emptyRunStart: timelineEmptyRunStartsAt(
                  current: exposureStateForLayer(layer, frameIndex),
                  previous: frameIndex == 0
                      ? null
                      : exposureStateForLayer(layer, frameIndex - 1),
                ),
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
        if (sectionStart)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: IgnorePointer(
              child: Container(
                key: ValueKey<String>(
                  'timeline-section-divider-row-${layer.id}',
                ),
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        if (commaDrag != null && layerKindHoldsDrawings(layer.kind))
          ...timelineRowBlockEdgeGrips(
            layer: layer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            commaDrag: commaDrag,
            axis: Axis.horizontal,
          ),
      ],
    );
  }
}

/// The edge grips for every drawing block intersecting the visible window,
/// shared by the horizontal row and the X-sheet column (Axis policy).
List<Widget> timelineRowBlockEdgeGrips({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required TimelineCommaDragCallbacks commaDrag,
  required Axis axis,
}) {
  final grips = <Widget>[];
  final blocks = drawingBlocks(layer.timeline);
  for (var ordinal = 0; ordinal < blocks.length; ordinal += 1) {
    final block = blocks[ordinal];
    if (block.endIndexExclusive <= frameStartIndex ||
        block.startIndex >= frameEndIndexExclusive) {
      continue;
    }

    final blockStartOffset = frameVisibleX(
      frameIndex: block.startIndex,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final blockEndOffset = frameVisibleX(
      frameIndex: block.endIndexExclusive,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );

    for (final edge in TimelineBlockEdge.values) {
      grips.add(
        TimelineBlockEdgeGrip(
          layerId: layer.id,
          blockStartIndex: block.startIndex,
          blockOrdinal: ordinal,
          edge: edge,
          blockStartOffset: blockStartOffset,
          blockEndOffset: blockEndOffset,
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          callbacks: commaDrag,
          axis: axis,
        ),
      );
    }
  }
  return grips;
}
