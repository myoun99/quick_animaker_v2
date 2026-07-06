import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_frame_cells_row.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';

class TimelineFrameRowsScrollBody extends StatelessWidget {
  const TimelineFrameRowsScrollBody({
    super.key,
    required this.layers,
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
    this.hasMarkForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final List<Layer> layers;
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
  final bool Function(Layer layer, int frameIndex)? hasMarkForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('timeline-frame-rows-scroll-body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < layers.length; index += 1)
            TimelineFrameCellsRow(
              layer: layers[index],
              active: layers[index].id == activeLayerId,
              sectionStart: timelineSectionStartsAt(layers, index),
              currentFrameIndex: currentFrameIndex,
              playbackFrameCount: playbackFrameCount,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerWidth,
              trailingFrameSpacerWidth: trailingFrameSpacerWidth,
              metrics: metrics,
              exposureStateForLayer: exposureStateForLayer,
              hasMarkForLayer: hasMarkForLayer,
              frameNameForLayer: frameNameForLayer,
              onSelectLayer: onSelectLayer,
              onSelectFrame: onSelectFrame,
            ),
          if (layers.isEmpty)
            SizedBox(
              width: totalFrameContentWidth,
              height: metrics.layerRowHeight,
            ),
        ],
      ),
    );
  }
}
