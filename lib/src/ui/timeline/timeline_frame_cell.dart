import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_grid_metrics.dart';

class TimelineFrameCell extends StatelessWidget {
  const TimelineFrameCell({
    super.key,
    required this.layer,
    required this.frameIndex,
    required this.active,
    required this.selected,
    required this.outsidePlaybackRange,
    required this.exposureState,
    required this.selectedExposureRangeSegment,
    required this.exposureBlockSegment,
    required this.hasMark,
    this.frameName,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final int frameIndex;
  final bool active;
  final bool selected;
  final bool outsidePlaybackRange;
  final TimelineCellExposureState exposureState;
  final bool selectedExposureRangeSegment;
  final TimelineExposureBlockVisualSegment exposureBlockSegment;
  final bool hasMark;
  final String? frameName;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  static const TimelineGridMetrics _metrics = TimelineGridMetrics.defaults;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final styleColors = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: exposureState,
      active: active,
      selected: selected,
    );
    final normalStyleColors = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: exposureState,
      active: active,
      selected: false,
    );
    final baseBackgroundColor = outsidePlaybackRange
        ? Color.alphaBlend(
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
            styleColors.background,
          )
        : styleColors.background;
    final backgroundColor = baseBackgroundColor;
    final cellBorderColor = selected && selectedExposureRangeSegment
        ? normalStyleColors.border
        : styleColors.border;
    final borderColor = outsidePlaybackRange
        ? Color.alphaBlend(
            colorScheme.outlineVariant.withValues(alpha: 0.55),
            cellBorderColor,
          )
        : cellBorderColor;
    final borderWidth = selected && !selectedExposureRangeSegment ? 3.0 : 1.0;

    return InkWell(
      key: ValueKey<String>('timeline-cell-${layer.id}-$frameIndex'),
      onTap: () {
        onSelectLayer(layer.id);
        onSelectFrame(frameIndex);
      },
      child: Container(
        width: _metrics.frameCellWidth,
        height: _metrics.layerRowHeight,
        alignment: Alignment.center,
        decoration: _timelineCellDecoration(
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
          exposureBlockSegment: exposureBlockSegment,
        ),
        child: Center(
          child: Semantics(
            key: selected
                ? const ValueKey<String>('timeline-selected-cell')
                : null,
            child: Text(
              _markerForCell(
                exposureState: exposureState,
                hasMark: hasMark,
                frameName: frameName,
              ),
              semanticsLabel: _semanticsLabelForCell(
                exposureState: exposureState,
                hasMark: hasMark,
                frameName: frameName,
              ),
              style: TextStyle(
                color: outsidePlaybackRange
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                    : selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight:
                    hasMark || exposureState != TimelineCellExposureState.empty
                    ? FontWeight.bold
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _timelineCellDecoration({
  required Color backgroundColor,
  required Color borderColor,
  required double borderWidth,
  required TimelineExposureBlockVisualSegment exposureBlockSegment,
}) {
  return BoxDecoration(
    color: backgroundColor,
    border: Border.all(color: borderColor, width: borderWidth),
    borderRadius: _timelineCellBorderRadius(exposureBlockSegment),
  );
}

BorderRadius? _timelineCellBorderRadius(
  TimelineExposureBlockVisualSegment exposureBlockSegment,
) {
  if (!exposureBlockSegment.isBlock) {
    return null;
  }

  const blockRadius = Radius.circular(6);
  return BorderRadius.horizontal(
    left: exposureBlockSegment.continuesFromPrevious
        ? Radius.zero
        : blockRadius,
    right: exposureBlockSegment.continuesToNext ? Radius.zero : blockRadius,
  );
}

String _markerForCell({
  required TimelineCellExposureState exposureState,
  required bool hasMark,
  String? frameName,
}) {
  if (hasMark) {
    return '●';
  }

  return switch (exposureState) {
    TimelineCellExposureState.empty => '',
    TimelineCellExposureState.drawingStart =>
      frameName == null || frameName.isEmpty ? '○' : frameName,
    TimelineCellExposureState.heldExposure => '',
    TimelineCellExposureState.blankStart => 'X',
    TimelineCellExposureState.blankHeld => '',
  };
}

String? _semanticsLabelForCell({
  required TimelineCellExposureState exposureState,
  required bool hasMark,
  String? frameName,
}) {
  if (hasMark) {
    return 'inbetween mark';
  }

  return switch (exposureState) {
    TimelineCellExposureState.empty => null,
    TimelineCellExposureState.drawingStart =>
      frameName == null || frameName.isEmpty
          ? 'drawing start'
          : 'drawing start $frameName',
    TimelineCellExposureState.heldExposure => 'held exposure',
    TimelineCellExposureState.blankStart => 'blank exposure start',
    TimelineCellExposureState.blankHeld => 'blank held exposure',
  };
}
