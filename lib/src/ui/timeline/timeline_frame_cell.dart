import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
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
    this.emptyRunStart = false,
    this.frameName,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.axis = Axis.horizontal,
    this.width,
    this.height,
    this.cellKeyPrefix = 'timeline-cell',
    this.selectedSemanticsKey = const ValueKey<String>(
      'timeline-selected-cell',
    ),
  });

  final Layer layer;
  final int frameIndex;
  final bool active;
  final bool selected;
  final bool outsidePlaybackRange;
  final TimelineCellExposureState exposureState;
  final bool selectedExposureRangeSegment;
  final TimelineExposureBlockVisualSegment exposureBlockSegment;

  /// Whether this cell opens an empty run — the timesheet X marks only the
  /// FIRST cell of each empty stretch, like paper sheets.
  final bool emptyRunStart;
  final String? frameName;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// The frame axis direction: horizontal in the layer timeline, vertical
  /// in the X-sheet. Controls which edges of an exposure block round.
  final Axis axis;

  /// Cell dimensions; default to the horizontal timeline metrics.
  final double? width;
  final double? height;

  /// Key namespace ('timeline-cell' / 'xsheet-cell') so both grids share
  /// this widget while keeping their stable test keys.
  final String cellKeyPrefix;

  /// Semantics key marking the selected cell in this grid's namespace.
  final ValueKey<String> selectedSemanticsKey;

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
    final isEmptyX = exposureState == TimelineCellExposureState.uncovered;

    return InkWell(
      key: ValueKey<String>('$cellKeyPrefix-${layer.id}-$frameIndex'),
      onTap: () {
        onSelectLayer(layer.id);
        onSelectFrame(frameIndex);
      },
      child: Container(
        width: width ?? _metrics.frameCellWidth,
        height: height ?? _metrics.layerRowHeight,
        alignment: Alignment.center,
        decoration: _timelineCellDecoration(
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
          exposureBlockSegment: exposureBlockSegment,
          axis: axis,
        ),
        child: Center(
          child: Semantics(
            key: selected ? selectedSemanticsKey : null,
            child: Text(
              _markerForCell(
                layer: layer,
                exposureState: exposureState,
                emptyRunStart: emptyRunStart,
                frameName: frameName,
                outsidePlaybackRange: outsidePlaybackRange,
              ),
              semanticsLabel: _semanticsLabelForCell(
                exposureState: exposureState,
                frameName: frameName,
              ),
              style: TextStyle(
                color: timelineCellUsesDrawingInk(exposureState)
                    ? (outsidePlaybackRange
                          ? timelineDrawingInkColor.withValues(alpha: 0.55)
                          : timelineDrawingInkColor)
                    : isEmptyX
                    // The "X" only marks emptiness; keep it quiet.
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                    : outsidePlaybackRange
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                    : selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight:
                    !isEmptyX &&
                        exposureState != TimelineCellExposureState.held
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
  required Axis axis,
}) {
  return BoxDecoration(
    color: backgroundColor,
    border: Border.all(color: borderColor, width: borderWidth),
    borderRadius: _timelineCellBorderRadius(exposureBlockSegment, axis),
  );
}

BorderRadius? _timelineCellBorderRadius(
  TimelineExposureBlockVisualSegment exposureBlockSegment,
  Axis axis,
) {
  if (!exposureBlockSegment.isBlock) {
    return null;
  }

  const blockRadius = Radius.circular(6);
  final startRadius = exposureBlockSegment.continuesFromPrevious
      ? Radius.zero
      : blockRadius;
  final endRadius = exposureBlockSegment.continuesToNext
      ? Radius.zero
      : blockRadius;
  return switch (axis) {
    Axis.horizontal => BorderRadius.horizontal(
      left: startRadius,
      right: endRadius,
    ),
    Axis.vertical => BorderRadius.vertical(top: startRadius, bottom: endRadius),
  };
}

String _markerForCell({
  required Layer layer,
  required TimelineCellExposureState exposureState,
  required bool emptyRunStart,
  String? frameName,
  required bool outsidePlaybackRange,
}) {
  return switch (exposureState) {
    // The timesheet "X": the FIRST cell of each empty run inside the
    // playback range (paper-sheet style). Camera rows mirror keyframes,
    // not cel exposure — no X there.
    TimelineCellExposureState.uncovered =>
      layer.kind == LayerKind.camera || outsidePlaybackRange || !emptyRunStart
          ? ''
          : 'X',
    TimelineCellExposureState.drawingStart =>
      frameName == null || frameName.isEmpty ? '○' : frameName,
    TimelineCellExposureState.held => '',
    TimelineCellExposureState.markHeld ||
    TimelineCellExposureState.markUncovered => '●',
  };
}

String? _semanticsLabelForCell({
  required TimelineCellExposureState exposureState,
  String? frameName,
}) {
  return switch (exposureState) {
    TimelineCellExposureState.uncovered => null,
    TimelineCellExposureState.drawingStart =>
      frameName == null || frameName.isEmpty
          ? 'drawing start'
          : 'drawing start $frameName',
    TimelineCellExposureState.held => 'held exposure',
    TimelineCellExposureState.markHeld ||
    TimelineCellExposureState.markUncovered => 'inbetween mark',
  };
}
