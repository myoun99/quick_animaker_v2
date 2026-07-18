import 'dart:math' as math;

import '../core/collection_equality.dart';
import 'layer.dart';
import 'layer_id.dart';
import 'timeline_coverage.dart';

/// One layer's selected frame RANGE (UI-R8, TVP-style): [startIndex,
/// endIndexExclusive) snapped to whole exposure blocks. View state — never
/// persisted.
class TimelineFrameRangeSelection {
  const TimelineFrameRangeSelection({
    required this.layerId,
    required this.startIndex,
    required this.endIndexExclusive,
    this.layerIds = const [],
  }) : assert(endIndexExclusive > startIndex, 'Range must cover frames.');

  /// The ANCHOR layer (where the drag started) — single-layer flows keep
  /// reading this.
  final LayerId layerId;
  final int startIndex;
  final int endIndexExclusive;

  /// The Excel-style layer SPAN (UI-R17 #8): display-ordered eligible
  /// layers from anchor to head. Empty = the anchor layer alone.
  final List<LayerId> layerIds;

  /// The layers this selection covers, anchor-only selections included.
  List<LayerId> get spanLayerIds => layerIds.isEmpty ? [layerId] : layerIds;

  bool coversLayer(LayerId id) =>
      layerIds.isEmpty ? id == layerId : layerIds.contains(id);

  int get lengthFrames => endIndexExclusive - startIndex;

  bool contains(int frameIndex) =>
      frameIndex >= startIndex && frameIndex < endIndexExclusive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineFrameRangeSelection &&
          other.layerId == layerId &&
          other.startIndex == startIndex &&
          other.endIndexExclusive == endIndexExclusive &&
          listEquals(other.layerIds, layerIds);

  @override
  int get hashCode => Object.hash(
    layerId,
    startIndex,
    endIndexExclusive,
    Object.hashAll(layerIds),
  );

  @override
  String toString() =>
      'TimelineFrameRangeSelection($layerId, [$startIndex, '
      '$endIndexExclusive), span: $spanLayerIds)';
}

/// ONE property lane's selected frame RANGE (UI-R23 #3 part 2): the
/// (layer, lane)-scoped selection domain — INDEPENDENT of the layer's
/// frame-range selection (frame selection ⊥ transform keys; the two are
/// mutually exclusive, starting one clears the other). Raw cells, no
/// block snapping (lane keys are points). View state — never persisted.
class TimelineLaneSelection {
  const TimelineLaneSelection({
    required this.layerId,
    required this.laneId,
    required this.startIndex,
    required this.endIndexExclusive,
  }) : assert(endIndexExclusive > startIndex, 'Range must cover frames.');

  final LayerId layerId;

  /// The lane id [transformPropertyLanes] emits ('position', 'scale', …).
  final String laneId;
  final int startIndex;
  final int endIndexExclusive;

  int get lengthFrames => endIndexExclusive - startIndex;

  bool contains(int frameIndex) =>
      frameIndex >= startIndex && frameIndex < endIndexExclusive;

  bool coversLane(LayerId layer, String lane) =>
      layer == layerId && lane == laneId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineLaneSelection &&
          other.layerId == layerId &&
          other.laneId == laneId &&
          other.startIndex == startIndex &&
          other.endIndexExclusive == endIndexExclusive;

  @override
  int get hashCode =>
      Object.hash(layerId, laneId, startIndex, endIndexExclusive);

  @override
  String toString() =>
      'TimelineLaneSelection($layerId/$laneId, [$startIndex, '
      '$endIndexExclusive))';
}

/// Snaps a raw dragged span to WHOLE exposure blocks (UI-R8 user rule: a
/// selection half-covering a block extends through it — blocks never
/// split). GHOST exposures are TEXT-ONLY now (UI-R23 #6: repeat/hold
/// instances and synced attach mirrors "aren't blocks, they only carry
/// text") — they never extend a selection, reading as empty cells for the
/// snap. A raw span may still land on ghost cells; the move plans stay
/// ghost-free so those cells just ride along.
TimelineFrameRangeSelection? snapFrameRangeToBlocks({
  required Layer layer,
  required int anchorIndex,
  required int headIndex,
}) {
  var start = math.max(0, math.min(anchorIndex, headIndex));
  var endExclusive = math.max(anchorIndex, headIndex) + 1;
  if (endExclusive <= start) {
    return null;
  }

  // Expand outward until stable: covering REAL blocks at the edges (ghost
  // exposures are text-only and never extend the span, UI-R23 #6), and
  // INSTRUCTION events anywhere in the range (UI-R22 #4 — covering one
  // cell of a CAM event selects its whole span, the block rule). Each pass
  // only grows the range, so the loop terminates.
  var changed = true;
  while (changed) {
    changed = false;
    final startBlock = coveringDrawingBlockAt(layer.timeline, start);
    if (startBlock != null &&
        !startBlock.entry.ghost &&
        startBlock.startIndex < start) {
      start = startBlock.startIndex;
      changed = true;
    }
    final endBlock = coveringDrawingBlockAt(layer.timeline, endExclusive - 1);
    if (endBlock != null &&
        !endBlock.entry.ghost &&
        endBlock.endIndexExclusive > endExclusive) {
      endExclusive = endBlock.endIndexExclusive;
      changed = true;
    }
    for (final entry in layer.instructions.entries) {
      final eventEnd = entry.key + entry.value.length;
      if (entry.key < endExclusive && eventEnd > start) {
        if (entry.key < start) {
          start = entry.key;
          changed = true;
        }
        if (eventEnd > endExclusive) {
          endExclusive = eventEnd;
          changed = true;
        }
      }
    }
  }

  return TimelineFrameRangeSelection(
    layerId: layer.id,
    startIndex: start,
    endIndexExclusive: endExclusive,
  );
}
