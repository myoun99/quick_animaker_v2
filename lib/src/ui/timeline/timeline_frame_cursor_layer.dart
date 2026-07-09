import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import 'property_lane_model.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_instruction_row_visual.dart';
import 'timeline_playhead.dart';
import 'timeline_selected_exposure_outline.dart';

/// Everything of a timeline grid that moves with the frame cursor — the
/// playhead tint, the active layer's selected-cell ring (carrying the
/// grid's selected-cell semantics) and the selected exposure outline — in
/// ONE widget subscribed to the cursor.
///
/// This is the heart of the playback-performance architecture: a playback
/// tick or an editing seek repaints THIS layer only. Rows and cells never
/// depend on the cursor, so the grid's hundreds of cell widgets stay
/// untouched frame to frame (the storyboard's cheap-playhead pattern,
/// generalized). One widget serves both orientations (Axis policy).
class TimelineCursorLayer extends StatelessWidget {
  const TimelineCursorLayer({
    super.key,
    required this.frameCursor,
    required this.rows,
    required this.activeLayerId,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.metrics,
    required this.exposureStateForLayer,
    required this.crossAxisExtent,
    this.axis = Axis.horizontal,
    this.selectedSemanticsKey = const ValueKey<String>(
      'timeline-selected-cell',
    ),
  });

  final ValueListenable<int> frameCursor;

  /// The grid's display rows (layer rows + expanded lanes), for the active
  /// layer's cross-axis position.
  final List<TimelineDisplayRow> rows;
  final LayerId? activeLayerId;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;

  /// Total layer-axis extent of the rows (the playhead's length).
  final double crossAxisExtent;

  /// The frame axis direction; every visual transposes, none forks.
  final Axis axis;

  /// Semantics key marking the selected cell in this grid's namespace.
  final ValueKey<String> selectedSemanticsKey;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return ValueListenableBuilder<int>(
      valueListenable: frameCursor,
      builder: (context, frame, _) {
        final cursorVisible =
            frame >= frameStartIndex && frame < frameEndIndexExclusive;
        final children = <Widget>[
          // Mounted only while the cursor is inside the built window (the
          // widget's own out-of-range shrink is not enough — tests and
          // semantics treat presence of the playhead key as visibility).
          if (cursorVisible)
            TimelinePlayhead(
              currentFrameIndex: frame,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerWidth,
              metrics: metrics,
              layerCount: rows.length,
              crossAxisExtent: crossAxisExtent,
              axis: axis,
            ),
        ];

        // The selection visuals follow the ACTIVE layer's row. The exposure
        // outline stays even while the cursor itself is scrolled out of the
        // window (its block may still intersect); only the cell ring needs
        // the cursor on screen.
        int? activeRowIndex;
        Layer? activeLayer;
        for (var index = 0; index < rows.length; index += 1) {
          if (!rows[index].isLane && rows[index].layer.id == activeLayerId) {
            activeRowIndex = index;
            activeLayer = rows[index].layer;
            break;
          }
        }
        if (activeLayer != null && activeRowIndex != null) {
          final layer = activeLayer;
          // Display rows are uniformly tall (timelineDisplayRowExtent).
          final rowOffset = activeRowIndex * metrics.layerRowHeight;
          TimelineCellExposureState stateAt(int frameIndex) =>
              layer.kind == LayerKind.instruction
              ? instructionCellExposureState(layer, frameIndex)
              : exposureStateForLayer(layer, frameIndex);
          final displayRange = resolveSelectedExposureDisplayRange(
            active: true,
            currentFrameIndex: frame,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            exposureStateAt: stateAt,
          );
          final cellOffset = frameVisibleX(
            frameIndex: frame,
            frameStartIndex: frameStartIndex,
            frameCellWidth: metrics.frameCellWidth,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
          );

          final ring = Semantics(
            key: selectedSemanticsKey,
            label: 'selected cell',
            container: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: timelineSelectedFrameBorderColor,
                  width: 3,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
          );

          final rowStack = Stack(
            clipBehavior: Clip.none,
            children: [
              TimelineSelectedExposureOutline(
                axis: axis,
                layerId: layer.id,
                displayRange: displayRange,
                frameStartIndex: frameStartIndex,
                leadingFrameSpacerWidth: leadingFrameSpacerWidth,
                frameCellWidth: metrics.frameCellWidth,
                rowHeight: metrics.layerRowHeight,
                borderColor: timelineSelectedFrameBorderColor,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              if (cursorVisible)
                horizontal
                    ? Positioned(
                        left: cellOffset,
                        top: 0,
                        width: metrics.frameCellWidth,
                        height: metrics.layerRowHeight,
                        child: ring,
                      )
                    : Positioned(
                        top: cellOffset,
                        left: 0,
                        height: metrics.frameCellWidth,
                        width: metrics.layerRowHeight,
                        child: ring,
                      ),
            ],
          );

          children.add(
            horizontal
                ? Positioned(
                    left: 0,
                    right: 0,
                    top: rowOffset,
                    height: metrics.layerRowHeight,
                    child: rowStack,
                  )
                : Positioned(
                    top: 0,
                    bottom: 0,
                    left: rowOffset,
                    width: metrics.layerRowHeight,
                    child: rowStack,
                  ),
          );
        }

        // Pointer-transparent (cells keep every gesture); semantics stay.
        return IgnorePointer(
          child: horizontal
              ? SizedBox(
                  height: crossAxisExtent,
                  child: Stack(clipBehavior: Clip.none, children: children),
                )
              : SizedBox(
                  width: crossAxisExtent,
                  child: Stack(clipBehavior: Clip.none, children: children),
                ),
        );
      },
    );
  }
}
