import 'dart:collection';

import 'frame.dart';
import 'frame_id.dart';
import 'layer.dart';
import 'layer_id.dart';
import 'timeline_coverage.dart';
import 'timeline_exposure.dart';

/// The resolved result of a multi-row range move (UI-R23 #9): the affected
/// drawing layers with their blocks relocated, plus the cross-row cel
/// re-key pairs the brush store must follow.
class MultiRowRangeMovePlan {
  const MultiRowRangeMovePlan({required this.layersAfter, required this.rekeys});

  /// Every affected layer's ghost-free timeline after the shift (the caller
  /// re-derives run behaviors). Keyed by layer id; unchanged layers are
  /// omitted.
  final Map<LayerId, Layer> layersAfter;

  /// (from, to, frameId) triples: a cel that changed owning layer, so its
  /// brush frame must re-key from the source row to the target row.
  final List<({LayerId from, LayerId to, FrameId frameId})> rekeys;
}

/// Plans a MULTI-ROW range move (UI-R23 #9): the selected blocks on a
/// contiguous run of drawing rows shift RIGIDLY by [rowDelta] rows and
/// [frameDelta] frames — every source row's selected blocks leave and the
/// row [rowDelta] away receives them at the shifted frames, cels and
/// breakdown dots riding along. "If a block is movable, it moves no matter
/// how many rows you select."
///
/// [orderedLayers] is the display-ordered lattice of move-eligible drawing
/// rows (all one section, so no cross-section landing is possible);
/// [sourceLayerIds] is the selection's span (a contiguous subset).
///
/// Null when the rigid shift cannot land — any illegal landing voids the
/// WHOLE move (multi-row rejects rather than pushing, unlike a single-row
/// slide): a source row maps off the lattice, a landing dips below frame 0,
/// a moved cel is linked from outside the moved set, the range is not
/// block-snapped on some row, or an incoming block would overlap a block
/// that STAYS on the target row.
MultiRowRangeMovePlan? planMultiRowRangeMove({
  required List<Layer> orderedLayers,
  required List<LayerId> sourceLayerIds,
  required int rangeStartIndex,
  required int rangeEndIndexExclusive,
  required int frameDelta,
  required int rowDelta,
}) {
  if (rowDelta == 0 || rangeEndIndexExclusive <= rangeStartIndex) {
    return null;
  }

  final indexById = <LayerId, int>{
    for (var i = 0; i < orderedLayers.length; i += 1) orderedLayers[i].id: i,
  };

  SplayTreeMap<int, TimelineExposure> ghostFree(Layer layer) {
    final base = SplayTreeMap<int, TimelineExposure>();
    layer.timeline.forEach((index, entry) {
      if (!(entry.isDrawing && entry.ghost)) {
        base[index] = entry;
      }
    });
    return base;
  }

  // Gather each source row's selected blocks + travelling cels, validating
  // the block-snap and the link-safety of every cel that would travel.
  final selectedByLayer = <LayerId, List<TimelineDrawingBlock>>{};
  final framesByLayer = <LayerId, List<Frame>>{};
  final frameIdsByLayer = <LayerId, Set<FrameId>>{};
  final sourceIndexes = <int>{};
  for (final sourceId in sourceLayerIds) {
    final sourceIndex = indexById[sourceId];
    if (sourceIndex == null) {
      return null;
    }
    final targetIndex = sourceIndex + rowDelta;
    if (targetIndex < 0 || targetIndex >= orderedLayers.length) {
      return null;
    }
    sourceIndexes.add(sourceIndex);
    final source = orderedLayers[sourceIndex];
    final base = ghostFree(source);
    final selected = <TimelineDrawingBlock>[];
    for (final block in drawingBlocks(base)) {
      final inRange =
          block.startIndex >= rangeStartIndex &&
          block.endIndexExclusive <= rangeEndIndexExclusive;
      final overlaps =
          block.startIndex < rangeEndIndexExclusive &&
          block.endIndexExclusive > rangeStartIndex;
      if (inRange) {
        selected.add(block);
      } else if (overlaps) {
        return null; // The range was not block-snapped on this row.
      }
    }
    final frameIds = <FrameId>{for (final block in selected) block.frameId};
    // A cel referenced from OUTSIDE the moved set stays put (link intact) —
    // the whole move is rejected rather than splitting the link.
    for (final entry in base.entries) {
      if (selected.any((block) => block.startIndex == entry.key)) {
        continue;
      }
      if (entry.value.isDrawing && frameIds.contains(entry.value.frameId)) {
        return null;
      }
    }
    final frames = <Frame>[];
    for (final frameId in frameIds) {
      Frame? found;
      for (final frame in source.frames) {
        if (frame.id == frameId) {
          found = frame;
          break;
        }
      }
      if (found == null) {
        return null;
      }
      frames.add(found);
    }
    selectedByLayer[sourceId] = selected;
    framesByLayer[sourceId] = frames;
    frameIdsByLayer[sourceId] = frameIds;
  }

  if (selectedByLayer.values.every((blocks) => blocks.isEmpty)) {
    return null; // Nothing but empty cells across every row.
  }

  final affectedIndexes = <int>{};
  for (final sourceIndex in sourceIndexes) {
    affectedIndexes.add(sourceIndex);
    affectedIndexes.add(sourceIndex + rowDelta);
  }

  final layersAfter = <LayerId, Layer>{};
  final rekeys = <({LayerId from, LayerId to, FrameId frameId})>[];

  for (final layerIndex in affectedIndexes) {
    final layer = orderedLayers[layerIndex];
    final isSource = sourceIndexes.contains(layerIndex);
    final incomingSourceIndex = layerIndex - rowDelta;
    final isTarget = sourceIndexes.contains(incomingSourceIndex);

    final timeline = ghostFree(layer);
    var frames = [...layer.frames];

    // This row is a SOURCE: its own selected blocks (and cels) leave.
    if (isSource) {
      for (final block in selectedByLayer[layer.id]!) {
        timeline.remove(block.startIndex);
      }
      final removedIds = frameIdsByLayer[layer.id]!;
      frames = [
        for (final frame in frames)
          if (!removedIds.contains(frame.id)) frame,
      ];
    }

    // This row is a TARGET: the mapped source's selected blocks arrive.
    if (isTarget) {
      final sourceLayer = orderedLayers[incomingSourceIndex];
      for (final block in selectedByLayer[sourceLayer.id]!) {
        final landing = block.startIndex + frameDelta;
        if (landing < 0) {
          return null;
        }
        final landingEnd = landing + block.length;
        for (final other in drawingBlocks(timeline)) {
          if (landing < other.endIndexExclusive &&
              other.startIndex < landingEnd) {
            return null; // Overlaps a block that stays — multi-row voids.
          }
        }
        timeline[landing] = block.entry;
      }
      frames = [...frames, ...framesByLayer[sourceLayer.id]!];
      for (final frameId in frameIdsByLayer[sourceLayer.id]!) {
        rekeys.add((from: sourceLayer.id, to: layer.id, frameId: frameId));
      }
    }

    layersAfter[layer.id] = layer.copyWith(timeline: timeline, frames: frames);
  }

  return MultiRowRangeMovePlan(layersAfter: layersAfter, rekeys: rekeys);
}
