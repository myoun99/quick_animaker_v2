import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'property_lane_model.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cells_row.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_lane_rows.dart';
import 'timeline_section_policy.dart';

class TimelineFrameRowsScrollBody extends StatelessWidget {
  const TimelineFrameRowsScrollBody({
    super.key,
    required this.layers,
    required this.rows,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.totalFrameContentWidth,
    required this.metrics,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.commaDrag,
  });

  /// Display layers (section-divider positions key off layer indexes).
  final List<Layer> layers;

  /// Display rows: layer rows interleaved with expanded property lanes.
  final List<TimelineDisplayRow> rows;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final double totalFrameContentWidth;
  final TimelineGridMetrics metrics;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final TimelineCommaDragCallbacks? commaDrag;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('timeline-frame-rows-scroll-body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            row.isLane
                ? TimelineLaneFrameRow(
                    layer: row.layer,
                    lane: row.lane!,
                    frameStartIndex: frameStartIndex,
                    frameEndIndexExclusive: frameEndIndexExclusive,
                    leadingFrameSpacerWidth: leadingFrameSpacerWidth,
                    trailingFrameSpacerWidth: trailingFrameSpacerWidth,
                    metrics: metrics,
                  )
                : TimelineFrameCellsRow(
                    layer: row.layer,
                    active: row.layer.id == activeLayerId,
                    sectionStart: timelineSectionStartsAt(
                      layers,
                      row.layerIndex,
                    ),
                    currentFrameIndex: currentFrameIndex,
                    playbackFrameCount: playbackFrameCount,
                    frameStartIndex: frameStartIndex,
                    frameEndIndexExclusive: frameEndIndexExclusive,
                    leadingFrameSpacerWidth: leadingFrameSpacerWidth,
                    trailingFrameSpacerWidth: trailingFrameSpacerWidth,
                    metrics: metrics,
                    exposureStateForLayer: exposureStateForLayer,
                    frameNameForLayer: frameNameForLayer,
                    onSelectLayer: onSelectLayer,
                    onSelectFrame: onSelectFrame,
                    commaDrag: commaDrag,
                  ),
          if (rows.isEmpty)
            SizedBox(
              width: totalFrameContentWidth,
              height: metrics.layerRowHeight,
            ),
        ],
      ),
    );
  }
}
