import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
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
    this.onTryIncreaseExposure,
    this.onTryDecreaseExposure,
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
  final bool Function(Layer layer, int frameIndex)? hasMarkForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// Comma-drag step attempts for the active layer's selected exposure
  /// block; when either is null the drag handle is not offered.
  final TimelineExposureCommaStepAttempt? onTryIncreaseExposure;
  final TimelineExposureCommaStepAttempt? onTryDecreaseExposure;

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
    final onTryIncreaseExposure = this.onTryIncreaseExposure;
    final onTryDecreaseExposure = this.onTryDecreaseExposure;
    // Comma-drag dispatches by LayerKind inside the shared row widget: the
    // camera row's cells mirror keyframes, not exposure runs, so it gets no
    // handle.
    final showCommaDragHandle =
        onTryIncreaseExposure != null &&
        onTryDecreaseExposure != null &&
        layer.kind != LayerKind.camera &&
        timelineCommaDragHandleVisible(
          displayRange: selectedExposureDisplayRange,
          exposureStateAt: (frameIndex) =>
              exposureStateForLayer(layer, frameIndex),
        );
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
        if (showCommaDragHandle)
          TimelineExposureCommaDragHandle(
            layerId: layer.id,
            displayRange: selectedExposureDisplayRange,
            frameStartIndex: frameStartIndex,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            onTryIncreaseExposure: onTryIncreaseExposure,
            onTryDecreaseExposure: onTryDecreaseExposure,
          ),
      ],
    );
  }
}
