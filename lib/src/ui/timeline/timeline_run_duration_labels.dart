import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/timeline_repeat.dart' show gluedRunAt;
import 'timeline_cell_style.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_range_policy.dart' show timelineSecondsLabel;

/// R26 #7: every frame block prints its own length at the block's END
/// cell, bottom-right — the storyboard cut block's TIME-label idiom
/// brought down to frame blocks, and the same shared display toggle:
/// frames (`48f`) or seconds+frames (`2+00`).
///
/// An overlay of positioned widgets rather than more painter work on
/// purpose: the cells painter bakes tiles (with a native rasterizer
/// behind it), and a label that changes with the frames/seconds toggle
/// would have to join every bake key on both paths. Riding ABOVE the
/// tiles — like the run-edge handles these are modeled on — keeps the
/// toggle a plain rebuild.
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
  final seenRunStarts = <int>{};

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
    final run = gluedRunAt(layer, key);
    if (run == null || !seenRunStarts.add(run.startIndex)) {
      continue;
    }
    if (run.endIndexExclusive <= frameStartIndex ||
        run.startIndex >= frameEndIndexExclusive) {
      continue;
    }
    final lengthFrames = run.endIndexExclusive - run.startIndex;
    final text = showSeconds
        ? timelineSecondsLabel(lengthFrames, countingBase)
        : '${lengthFrames}f';
    final start = edgeX(run.startIndex);
    final extent = edgeX(run.endIndexExclusive) - start;

    // Anchored to the run's end, allowed to reach back over the whole
    // block (clipped at the block, never spilling into the neighbor);
    // the fitted font keeps it readable-not-vanished at deep zoom-out
    // (the #38 rule).
    final label = IgnorePointer(
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: timelineFittedGlyphFontSize(9, frameCellExtent),
                color: timelineDrawingInkColor.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
    labels.add(
      axis == Axis.horizontal
          ? Positioned(
              key: ValueKey<String>(
                '$keyPrefix-run-duration-${layer.id}-${run.startIndex}',
              ),
              left: start,
              top: 0,
              width: extent,
              height: crossAxisExtent,
              child: label,
            )
          : Positioned(
              key: ValueKey<String>(
                '$keyPrefix-run-duration-${layer.id}-${run.startIndex}',
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
