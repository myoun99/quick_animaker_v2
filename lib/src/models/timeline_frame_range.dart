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

/// Snaps a raw dragged span to WHOLE exposure blocks (UI-R8 user rule: a
/// selection half-covering a block extends through it — blocks never
/// split). GHOST blocks snap exactly like real ones (UI-R20 #5 / P3b:
/// every cell is selectable — repeat instances and synced attach mirrors
/// included); what a selection can DO to a ghost stands down at each
/// op's own seam (move plans are ghost-free, delete skips ghost starts).
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

  // Expand both edges outward to their covering blocks — ghost or real.
  final startBlock = coveringDrawingBlockAt(layer.timeline, start);
  if (startBlock != null) {
    start = math.min(start, startBlock.startIndex);
  }
  final endBlock = coveringDrawingBlockAt(layer.timeline, endExclusive - 1);
  if (endBlock != null) {
    endExclusive = math.max(endExclusive, endBlock.endIndexExclusive);
  }

  return TimelineFrameRangeSelection(
    layerId: layer.id,
    startIndex: start,
    endIndexExclusive: endExclusive,
  );
}
