import 'dart:collection';

import 'frame_id.dart';
import 'layer.dart';
import 'timeline_exposure.dart';

/// TVP-style REPEAT region (UI-R8): a persistent, LIVE spec on the layer.
///
/// The region does not store ghost entries — it stores WHAT to repeat
/// ([anchorFrameId] + [sourceSpanFrames]) and HOW MUCH ([frameCount]);
/// [rederiveRepeatRegions] wipes and re-synthesizes the ghost entries after
/// every timeline edit, so moving/resizing/re-ordering the source run
/// re-arranges the repeat automatically (user requirement: live sync).
///
/// The anchor is the source span's FIRST block's frameId — an identity, not
/// an index — so the span keeps tracking its run through moves. A vanished
/// anchor drops the region (self-healing).
class TimelineRepeatRegion {
  const TimelineRepeatRegion({
    required this.id,
    required this.anchorFrameId,
    required this.sourceSpanFrames,
    required this.frameCount,
  }) : assert(sourceSpanFrames >= 1, 'Repeat source span must cover frames.'),
       assert(frameCount >= 1, 'Repeat region must cover at least a frame.');

  final String id;

  /// The frameId of the source span's first drawing block (identity anchor;
  /// resolved to its lowest non-ghost timeline index on rederive).
  final FrameId anchorFrameId;

  /// The source span's length in frames, measured from the anchor block's
  /// start at creation. The span's exposure PATTERN (entries, holds, gaps)
  /// is what cycles into the ghosts.
  final int sourceSpanFrames;

  /// How many frames of ghosts the region synthesizes after the span.
  final int frameCount;

  TimelineRepeatRegion copyWith({int? sourceSpanFrames, int? frameCount}) =>
      TimelineRepeatRegion(
        id: id,
        anchorFrameId: anchorFrameId,
        sourceSpanFrames: sourceSpanFrames ?? this.sourceSpanFrames,
        frameCount: frameCount ?? this.frameCount,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'anchor': anchorFrameId.toJson(),
    'sourceSpanFrames': sourceSpanFrames,
    'frameCount': frameCount,
  };

  factory TimelineRepeatRegion.fromJson(Map<String, dynamic> json) =>
      TimelineRepeatRegion(
        id: json['id'] as String,
        anchorFrameId: FrameId.fromJson(json['anchor'] as Map<String, dynamic>),
        sourceSpanFrames: json['sourceSpanFrames'] as int,
        frameCount: json['frameCount'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineRepeatRegion &&
          other.id == id &&
          other.anchorFrameId == anchorFrameId &&
          other.sourceSpanFrames == sourceSpanFrames &&
          other.frameCount == frameCount;

  @override
  int get hashCode =>
      Object.hash(id, anchorFrameId, sourceSpanFrames, frameCount);

  @override
  String toString() =>
      'TimelineRepeatRegion(id: $id, anchor: $anchorFrameId, '
      'span: $sourceSpanFrames, count: $frameCount)';
}

/// Re-derives every repeat region's ghost entries from the CURRENT base
/// timeline — THE live-sync engine (UI-R8). Pure: returns [layer] itself
/// when nothing changes (identity matters for the grid's memo gates).
///
/// Pass order:
/// 1. Strip every ghost entry (they are derived state, never authored).
/// 2. Regions apply in source-position order (earlier span wins overlaps).
///    Each region resolves its anchor (lowest-index non-ghost entry with
///    the anchor frameId; missing anchor drops the region), reads the
///    span's exposure pattern (drawing entries + their holds + gaps; marks
///    don't repeat), and synthesizes the pattern cyclically GLUED after
///    the span for [TimelineRepeatRegion.frameCount] frames.
/// 3. Ghosts clamp before the next occupied index (a base entry or an
///    earlier region's ghost) — derived frames never displace authored
///    ones.
Layer rederiveRepeatRegions(Layer layer) {
  final hasGhosts = layer.timeline.values.any((entry) => entry.ghost);
  if (layer.repeatRegions.isEmpty && !hasGhosts) {
    return layer;
  }

  final base = SplayTreeMap<int, TimelineExposure>();
  layer.timeline.forEach((index, entry) {
    if (!entry.ghost) {
      base[index] = entry;
    }
  });

  // Resolve every region's anchor position first so application order is
  // the SPAN order on the timeline (earlier span wins), not list order.
  final resolved = <({TimelineRepeatRegion region, int anchorStart})>[];
  for (final region in layer.repeatRegions) {
    if (region.frameCount < 1) {
      continue;
    }
    int? anchorStart;
    for (final entry in base.entries) {
      if (entry.value.isDrawing &&
          entry.value.frameId == region.anchorFrameId) {
        anchorStart = entry.key;
        break;
      }
    }
    if (anchorStart == null) {
      continue; // Anchor vanished — the region drops (self-healing).
    }
    resolved.add((region: region, anchorStart: anchorStart));
  }
  resolved.sort((a, b) => a.anchorStart.compareTo(b.anchorStart));

  final result = SplayTreeMap<int, TimelineExposure>.of(base);
  final keptRegions = <TimelineRepeatRegion>[];
  for (final item in resolved) {
    final region = item.region;
    final spanStart = item.anchorStart;
    final spanEnd = spanStart + region.sourceSpanFrames;

    // The span's pattern: base drawing entries starting within the span,
    // as (offset from span start, frameId, length clamped to the span,
    // the block's inbetween-dot offsets).
    final pattern =
        <({int offset, FrameId frameId, int length, List<int> dots})>[];
    for (final entry in base.entries) {
      if (entry.key < spanStart || entry.key >= spanEnd) {
        continue;
      }
      final exposure = entry.value;
      if (!exposure.isDrawing) {
        continue;
      }
      final offset = entry.key - spanStart;
      final length = exposure.length!.clamp(1, spanEnd - entry.key);
      pattern.add((
        offset: offset,
        frameId: exposure.frameId!,
        length: length,
        dots: exposure.breakdownOffsets,
      ));
    }
    if (pattern.isEmpty) {
      continue; // Nothing to repeat (span holds no drawings) — drop.
    }

    // Ghosts attach at the first FREE frame at/after the span end: a base
    // hold extended past the span pushes them out instead of overlapping.
    var ghostStart = spanEnd;
    final coveringKey = result.containsKey(spanEnd)
        ? null
        : result.lastKeyBefore(spanEnd);
    if (coveringKey != null) {
      final covering = result[coveringKey]!;
      if (covering.isDrawing && coveringKey + covering.length! > spanEnd) {
        ghostStart = coveringKey + covering.length!;
      }
    }

    // The ghost budget: [ghostStart, ghostStart + frameCount), clamped
    // before the next occupied index (a base entry or an earlier region's
    // ghost) — derived frames never displace authored ones.
    final ghostEnd = ghostStart + region.frameCount;
    var limit = ghostEnd;
    for (final index in result.keys) {
      if (index >= ghostStart) {
        limit = index < limit ? index : limit;
        break;
      }
    }
    if (limit <= ghostStart) {
      keptRegions.add(region); // Fully occluded right now; spec survives.
      continue;
    }

    for (
      var cycleStart = ghostStart;
      cycleStart < limit;
      cycleStart += region.sourceSpanFrames
    ) {
      for (final part in pattern) {
        final start = cycleStart + part.offset;
        if (start >= limit) {
          break;
        }
        final length = part.length.clamp(1, limit - start);
        var ghost = TimelineExposure.drawing(
          part.frameId,
          length: length,
          ghost: true,
          repeatRegionId: region.id,
        );
        if (part.dots.isNotEmpty) {
          // Ghost copies carry the source block's dots; copyWith clamps
          // them to the (possibly shorter) ghost length.
          ghost = ghost.copyWith(breakdownOffsets: part.dots);
        }
        result[start] = ghost;
      }
    }
    keptRegions.add(region);
  }

  final regionsUnchanged =
      keptRegions.length == layer.repeatRegions.length &&
      () {
        for (var i = 0; i < keptRegions.length; i += 1) {
          if (keptRegions[i] != layer.repeatRegions[i]) {
            return false;
          }
        }
        return true;
      }();
  final timelineUnchanged =
      result.length == layer.timeline.length &&
      () {
        for (final entry in result.entries) {
          if (layer.timeline[entry.key] != entry.value) {
            return false;
          }
        }
        return true;
      }();
  if (regionsUnchanged && timelineUnchanged) {
    return layer;
  }
  return layer.copyWith(timeline: result, repeatRegions: keptRegions);
}

/// The contiguous GLUED run of non-ghost drawing blocks containing the
/// block at [blockStartIndex] (UI-R8: the repeat/add handles' unit —
/// "연결된 블록들"): expands in both directions while neighbours touch
/// (next.start == prev.endExclusive). Null when no non-ghost block starts
/// there.
({int startIndex, int endIndexExclusive, FrameId anchorFrameId})? gluedRunAt(
  Layer layer,
  int blockStartIndex,
) {
  final entry = layer.timeline[blockStartIndex];
  if (entry == null || !entry.isDrawing || entry.ghost) {
    return null;
  }
  final blocks = [
    for (final key in layer.timeline.keys)
      if (layer.timeline[key]!.isDrawing && !layer.timeline[key]!.ghost)
        (start: key, endExclusive: key + layer.timeline[key]!.length!),
  ];
  var index = blocks.indexWhere((block) => block.start == blockStartIndex);
  if (index < 0) {
    return null;
  }
  var first = index;
  while (first > 0 && blocks[first - 1].endExclusive == blocks[first].start) {
    first -= 1;
  }
  var last = index;
  while (last < blocks.length - 1 &&
      blocks[last].endExclusive == blocks[last + 1].start) {
    last += 1;
  }
  return (
    startIndex: blocks[first].start,
    endIndexExclusive: blocks[last].endExclusive,
    anchorFrameId: layer.timeline[blocks[first].start]!.frameId!,
  );
}

/// Whether [index] on [layer] falls inside a GHOST exposure (a derived
/// repeat instance) — the timeline cells dim these and the editing
/// affordances (grips, move, run-end handles) stand down on them.
bool timelineIndexIsGhost(Layer layer, int index) {
  final entry = layer.timeline[index];
  if (entry != null) {
    return entry.isDrawing && entry.ghost;
  }
  // Inside a hold: the covering block is the last entry before the index.
  final coveringKey = layer.timeline.lastKeyBefore(index);
  if (coveringKey == null) {
    return false;
  }
  final covering = layer.timeline[coveringKey]!;
  return covering.isDrawing &&
      covering.ghost &&
      index < coveringKey + covering.length!;
}
