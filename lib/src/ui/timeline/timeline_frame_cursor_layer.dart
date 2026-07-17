import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_frame_range.dart';
import '../../models/timeline_repeat.dart';
import 'property_lane_model.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_drag_preview.dart';
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
    this.dragPreview,
    this.frameRangeSelection,
    this.viewportOffset,
    this.viewportMainExtent = 0,
    this.selectedSemanticsKey = const ValueKey<String>(
      'timeline-selected-cell',
    ),
  });

  final ValueListenable<int> frameCursor;

  /// The session's frame-range selection (UI-R8): rendered as an accent
  /// span over the selected layer's row — this layer repaints, the rows
  /// never rebuild for it (value-only channel, cursor-layer pattern).
  final ValueListenable<TimelineFrameRangeSelection?>? frameRangeSelection;

  /// The session's edit-drag preview channel: while a comma drag targets
  /// the active layer, the selection visuals (the selected-exposure
  /// outline) follow the PREVIEW layer so they ride the drag live.
  final ValueListenable<TimelineDragPreview?>? dragPreview;

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

  /// UI-R15: the live frame-axis scroll offset. When provided with a
  /// positive [viewportMainExtent], visibility gating and the outline's
  /// display clamp use the offset-derived window instead of the (now
  /// full) build bounds — the widget builds once in content space and
  /// this layer follows the viewport by itself.
  final ValueListenable<double>? viewportOffset;
  final double viewportMainExtent;

  /// Semantics key marking the selected cell in this grid's namespace.
  final ValueKey<String> selectedSemanticsKey;

  ({int startIndex, int endIndexExclusive}) _visibleWindow() {
    final offset = viewportOffset;
    final cell = metrics.frameCellWidth;
    if (offset == null || viewportMainExtent <= 0 || cell <= 0) {
      return (
        startIndex: frameStartIndex,
        endIndexExclusive: frameEndIndexExclusive,
      );
    }
    final localOffset = offset.value - leadingFrameSpacerWidth;
    final first = frameStartIndex + (localOffset / cell).floor();
    final last =
        frameStartIndex + ((localOffset + viewportMainExtent) / cell).ceil();
    return (
      startIndex: math.max(frameStartIndex, first - 2),
      endIndexExclusive: math.min(frameEndIndexExclusive, last + 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return ListenableBuilder(
      listenable: Listenable.merge([
        frameCursor,
        ?dragPreview,
        ?frameRangeSelection,
        ?viewportOffset,
      ]),
      builder: (context, _) {
        final frame = frameCursor.value;
        // UI-R15: under full bounds + a live offset, visibility GATES and
        // the outline's display clamp use the offset-derived window (the
        // old bucket-window semantics), while positioning stays in the
        // widget's own coordinate space. This thin builder re-runs per
        // scroll — a handful of Positioned, repaint-scale cost.
        final window = _visibleWindow();
        final cursorVisible =
            frame >= window.startIndex && frame < window.endIndexExclusive;
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

        // The frame-range selection (UI-R8): an accent span over the
        // selected layer's row — selection reads from color alone.
        final range = frameRangeSelection?.value;
        if (range != null &&
            range.endIndexExclusive > window.startIndex &&
            range.startIndex < window.endIndexExclusive) {
          int? rangeRowIndex;
          for (var index = 0; index < rows.length; index += 1) {
            if (!rows[index].isLane && rows[index].layer.id == range.layerId) {
              rangeRowIndex = index;
              break;
            }
          }
          if (rangeRowIndex != null) {
            final spanStart = frameVisibleX(
              frameIndex: range.startIndex,
              frameStartIndex: frameStartIndex,
              frameCellWidth: metrics.frameCellWidth,
              leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            );
            final spanEnd = frameVisibleX(
              frameIndex: range.endIndexExclusive,
              frameStartIndex: frameStartIndex,
              frameCellWidth: metrics.frameCellWidth,
              leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            );
            final rowOffset = rangeRowIndex * metrics.layerRowHeight;
            final band = Semantics(
              key: const ValueKey<String>('timeline-frame-range-selection'),
              label: 'selected frame range',
              container: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: timelineSelectedFrameBorderColor.withValues(
                    alpha: 0.18,
                  ),
                  border: Border.all(
                    color: timelineSelectedFrameBorderColor,
                    width: 2,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
              ),
            );
            children.add(
              horizontal
                  ? Positioned(
                      left: spanStart,
                      top: rowOffset,
                      width: spanEnd - spanStart,
                      height: metrics.layerRowHeight,
                      child: band,
                    )
                  : Positioned(
                      top: spanStart,
                      left: rowOffset,
                      height: spanEnd - spanStart,
                      width: metrics.layerRowHeight,
                      child: band,
                    ),
            );
          }
        }

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
          final layer =
              timelineDragPreviewLayerFor(dragPreview?.value, activeLayer.id) ??
              activeLayer;
          // Display rows are uniformly tall (timelineDisplayRowExtent).
          final rowOffset = activeRowIndex * metrics.layerRowHeight;
          // Ghost cells read as EMPTY here (UI-R11 #5): the selection
          // block outline never wraps derived exposures — they show text
          // only, no block UI of any kind.
          TimelineCellExposureState stateAt(int frameIndex) =>
              timelineIndexIsGhost(layer, frameIndex)
              ? TimelineCellExposureState.uncovered
              : layer.kind == LayerKind.instruction
              ? instructionCellExposureState(layer, frameIndex)
              : exposureStateForLayer(layer, frameIndex);
          final displayRange = resolveSelectedExposureDisplayRange(
            active: true,
            currentFrameIndex: frame,
            frameStartIndex: window.startIndex,
            frameEndIndexExclusive: window.endIndexExclusive,
            exposureStateAt: stateAt,
          );
          final cellOffset = frameVisibleX(
            frameIndex: frame,
            frameStartIndex: frameStartIndex,
            frameCellWidth: metrics.frameCellWidth,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
          );

          // On a drawing block the BLOCK outline is the selection visual —
          // the single-cell ring would double it up (UI-R10 #8), so the
          // ring keeps its semantics node (probes/tests anchor on it) but
          // paints nothing there; empty cells keep the visible ring.
          final onBlock = displayRange.resolvedRange.isBlock;
          final ring = Semantics(
            key: selectedSemanticsKey,
            label: 'selected cell',
            container: true,
            child: onBlock
                ? const SizedBox.expand()
                : DecoratedBox(
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
