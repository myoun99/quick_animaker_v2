import 'package:flutter/material.dart';

import '../../models/layer.dart';
import 'timeline_cell_style.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_range_policy.dart' show timelineDurationLabel;

/// R26 #7 / R27 #3: every frame block prints ITS OWN length — one label
/// per block, not the glued run's total (R26 #7 shipped the run total;
/// R27 #3 corrected it: "블록 하나 하나마다 해당 블록의 길이"). The same
/// shared display toggle picks frames (`48`) or seconds+frames (`2+00`),
/// and no `f` suffix on either path ([timelineDurationLabel]).
///
/// Anchor (R27 #3): the BOTTOM-CENTER of the block's LAST cell. The
/// positioned box still spans the whole block so a number wider than one
/// cell can spill back over its own block (never into the neighbour) —
/// only the alignment point rides the last cell.
///
/// An overlay of positioned widgets rather than more painter work on
/// purpose: the cells painter bakes tiles (with a native rasterizer
/// behind it), and a label that changes with the frames/seconds toggle
/// would have to join every bake key on both paths. Riding ABOVE the
/// tiles — like the run-edge handles these are modeled on — keeps the
/// toggle a plain rebuild.
///
/// Ghost blocks stay unlabeled: their timing is derived, the same rule
/// the run-edge clusters follow.
List<Widget> timelineRowRunDurationLabels({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required bool showSeconds,
  required int countingBase,
  required Axis axis,
  String keyPrefix = 'timeline',
}) {
  final labels = <Widget>[];

  double edgeX(int frameIndex) => frameVisibleX(
    frameIndex: frameIndex,
    frameStartIndex: frameStartIndex,
    frameCellWidth: frameCellExtent,
    leadingFrameSpacerWidth: leadingFrameSpacerWidth,
  );

  for (final key in layer.timeline.keys) {
    final entry = layer.timeline[key]!;
    if (!entry.isDrawing || entry.ghost) {
      continue;
    }
    final lengthFrames = entry.length ?? 1;
    final startIndex = key;
    final endIndexExclusive = key + lengthFrames;
    if (endIndexExclusive <= frameStartIndex ||
        startIndex >= frameEndIndexExclusive) {
      continue;
    }
    final text = timelineDurationLabel(
      lengthFrames,
      showSeconds: showSeconds,
      countingBase: countingBase,
    );
    final start = edgeX(startIndex);
    final extent = edgeX(endIndexExclusive) - start;

    // The centre of the block's LAST cell, block-local.
    final lastCellCentre = extent - frameCellExtent / 2;

    final glyph = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: TextStyle(
        fontSize: timelineFittedGlyphFontSize(9, frameCellExtent),
        fontWeight: FontWeight.w700,
        color: timelineDrawingInkColor.withValues(alpha: 0.72),
      ),
    );

    // A text box WIDER than the block, centred on the last cell, then
    // clipped at the block: the glyph centre lands exactly on the cell
    // centre at any width, and a number too wide for one cell spills
    // back over its own block instead of into the neighbour's.
    final label = IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: [
            axis == Axis.horizontal
                ? Positioned(
                    left: lastCellCentre - extent,
                    width: 2 * extent,
                    bottom: 1,
                    child: glyph,
                  )
                : Positioned(
                    left: 0,
                    right: 0,
                    bottom: 1,
                    child: glyph,
                  ),
          ],
        ),
      ),
    );
    labels.add(
      axis == Axis.horizontal
          ? Positioned(
              key: ValueKey<String>(
                '$keyPrefix-run-duration-${layer.id}-$startIndex',
              ),
              left: start,
              top: 0,
              width: extent,
              height: crossAxisExtent,
              child: label,
            )
          : Positioned(
              key: ValueKey<String>(
                '$keyPrefix-run-duration-${layer.id}-$startIndex',
              ),
              top: start,
              left: 0,
              height: extent,
              width: crossAxisExtent,
              child: label,
            ),
    );
  }
  return labels;
}
