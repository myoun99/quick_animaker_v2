import 'dart:collection';
import 'dart:math' as math;

import 'frame.dart';
import 'frame_id.dart';
import 'layer.dart';
import 'timeline_coverage.dart';
import 'timeline_exposure.dart';

/// The resolved result of a whole-block move drag (R10-④b): the affected
/// layers with the block relocated. Same-layer slides carry only
/// [sourceAfter]; cross-layer moves also carry the target pair and the
/// frame ids whose brush drawings must re-key to the target layer.
class DrawingBlockMovePlan {
  const DrawingBlockMovePlan({
    required this.sourceAfter,
    this.targetBefore,
    this.targetAfter,
    this.movedFrameIds = const [],
    required this.destinationStartIndex,
  }) : assert(
         (targetBefore == null) == (targetAfter == null),
         'Cross-layer plans carry both target snapshots.',
       );

  final Layer sourceAfter;

  /// Null when the move stays on the source layer.
  final Layer? targetBefore;
  final Layer? targetAfter;

  /// Frame ids that changed owning layer (empty for same-layer slides).
  final List<FrameId> movedFrameIds;

  final int destinationStartIndex;

  bool get isCrossLayer => targetBefore != null;
}

/// Plans moving the drawing block starting at [blockStartIndex] on [source]
/// by [frameDelta] frames onto [target] ([target] == [source] for a plain
/// slide). Returns null when the move is impossible or a no-op:
///
/// - blocks in the way get PUSHED in the direction of travel (R12-②):
///   rightward (and pure cross-layer drops) push the blocks ahead to later
///   frames, cascading; leftward pushes the blocks ahead toward frame 0,
///   consuming the gaps between them, and the move CLAMPS when the chain
///   hits the wall (cut-move precedent) — the block rests at the nearest
///   spot the chain allows;
/// - a landing (moved or pushed) whose start would overwrite a mark entry
///   sharing that exact index is rejected (marks may sit INSIDE holds,
///   never under a block start);
/// - cross-layer moves take the block's cel along, so a cel that other
///   timeline entries still reference (linked cels) stays put — the move
///   is rejected rather than splitting the link.
DrawingBlockMovePlan? planDrawingBlockMove({
  required Layer source,
  required Layer target,
  required int blockStartIndex,
  required int frameDelta,
}) {
  final entry = source.timeline[blockStartIndex];
  if (entry == null || !entry.isDrawing) {
    return null;
  }
  final sameLayer = source.id == target.id;
  if (sameLayer && frameDelta == 0) {
    return null;
  }
  final length = entry.length!;

  // Cross-layer: the cel travels with the block. Linked cels (the same
  // frame exposed by another entry) stay: rejecting keeps the link intact.
  Frame? movedFrame;
  if (!sameLayer) {
    final frameId = entry.frameId!;
    for (final candidate in source.timeline.entries) {
      if (candidate.key != blockStartIndex &&
          candidate.value.isDrawing &&
          candidate.value.frameId == frameId) {
        return null;
      }
    }
    for (final frame in source.frames) {
      if (frame.id == frameId) {
        movedFrame = frame;
        break;
      }
    }
    if (movedFrame == null) {
      return null;
    }
  }

  // Every other drawing block on the target timeline (the moved block's own
  // entry is ignored when sliding within the source layer).
  final others = [
    for (final block in drawingBlocks(target.timeline))
      if (!(sameLayer && block.startIndex == blockStartIndex)) block,
  ];

  final resolved = _resolvePushedLanding(
    others: others,
    requestedStart: blockStartIndex + frameDelta,
    movedLength: length,
    pushRight: frameDelta >= 0,
    // Leftward moves clamp against the frame-0 wall; the moved block never
    // ends up RIGHT of where it started on its own layer (a leftward drag
    // must not teleport it forward).
    leftwardCap: sameLayer ? blockStartIndex : math.max(0, blockStartIndex),
    // Same-layer slides BULLDOZE (R12-B): the moved block may never pass
    // a neighbour — everything in its path gets shoved along, order
    // preserved. Cross-layer landings keep the plain overlap rules.
    sameLayerStart: sameLayer ? blockStartIndex : null,
  );
  if (resolved == null) {
    return null;
  }
  final (:destStart, :pushes) = resolved;
  if (sameLayer && destStart == blockStartIndex && pushes.isEmpty) {
    return null;
  }

  // Mark protection: no landing (moved or pushed) may overwrite a mark
  // entry sharing its exact start index.
  bool startsOnMark(SplayTreeMap<int, TimelineExposure> timeline, int start) {
    final atStart = timeline[start];
    return atStart != null && atStart.isMark;
  }

  if (startsOnMark(target.timeline, destStart)) {
    return null;
  }
  for (final push in pushes) {
    if (push.newStart != push.block.startIndex &&
        startsOnMark(target.timeline, push.newStart)) {
      return null;
    }
  }

  SplayTreeMap<int, TimelineExposure> targetTimelineAfter() {
    final timeline = SplayTreeMap<int, TimelineExposure>.of(target.timeline);
    if (sameLayer) {
      timeline.remove(blockStartIndex);
    }
    for (final push in pushes) {
      timeline.remove(push.block.startIndex);
    }
    for (final push in pushes) {
      timeline[push.newStart] = push.block.entry;
    }
    timeline[destStart] = entry;
    return timeline;
  }

  if (sameLayer) {
    return DrawingBlockMovePlan(
      sourceAfter: source.copyWith(timeline: targetTimelineAfter()),
      destinationStartIndex: destStart,
    );
  }

  final frameId = entry.frameId!;
  final sourceTimeline = SplayTreeMap<int, TimelineExposure>.of(source.timeline)
    ..remove(blockStartIndex);
  return DrawingBlockMovePlan(
    sourceAfter: source.copyWith(
      timeline: sourceTimeline,
      frames: [
        for (final frame in source.frames)
          if (frame.id != frameId) frame,
      ],
    ),
    targetBefore: target,
    targetAfter: target.copyWith(
      timeline: targetTimelineAfter(),
      frames: [...target.frames, movedFrame!],
    ),
    movedFrameIds: [frameId],
    destinationStartIndex: destStart,
  );
}

/// Plans moving EVERY drawing block inside [rangeStartIndex,
/// rangeEndIndexExclusive) on [source] by [frameDelta] frames onto [target]
/// as ONE RIGID GROUP (relative offsets — internal gaps included — are
/// preserved). The UI-R8 range move: the selection is block-snapped, so
/// the range always holds whole blocks.
///
/// Same rules as [planDrawingBlockMove], applied group-wise:
/// - same-layer slides bulldoze (the group never passes a neighbour);
///   leftward clamps at frame 0;
/// - any landing (moved or pushed) on a mark's exact index is rejected;
/// - cross-layer moves carry the moved cels; a cel referenced by an entry
///   OUTSIDE the moved set stays (rejected) to keep links intact — entries
///   linked WITHIN the range travel together sharing their cel.
///
/// GHOST entries (derived repeat instances) never move and never obstruct:
/// both timelines are planned ghost-free and the caller re-derives repeats
/// afterwards. A range intersecting a ghost is rejected outright.
DrawingBlockMovePlan? planDrawingRangeMove({
  required Layer source,
  required Layer target,
  required int rangeStartIndex,
  required int rangeEndIndexExclusive,
  required int frameDelta,
}) {
  if (rangeEndIndexExclusive <= rangeStartIndex) {
    return null;
  }
  final sameLayer = source.id == target.id;
  if (sameLayer && frameDelta == 0) {
    return null;
  }

  // Plan on ghost-free timelines: derived entries neither move nor block.
  SplayTreeMap<int, TimelineExposure> baseTimeline(Layer layer) {
    final base = SplayTreeMap<int, TimelineExposure>();
    layer.timeline.forEach((index, entry) {
      if (!(entry.isDrawing && entry.ghost)) {
        base[index] = entry;
      }
    });
    return base;
  }

  final sourceBase = baseTimeline(source);
  final targetBase = sameLayer ? sourceBase : baseTimeline(target);

  final moved = <TimelineDrawingBlock>[];
  for (final block in drawingBlocks(sourceBase)) {
    if (block.startIndex >= rangeStartIndex &&
        block.endIndexExclusive <= rangeEndIndexExclusive) {
      moved.add(block);
    } else if (block.startIndex < rangeEndIndexExclusive &&
        block.endIndexExclusive > rangeStartIndex) {
      // A partially covered block means the range was not block-snapped.
      return null;
    }
  }
  if (moved.isEmpty) {
    return null;
  }
  // A range overlapping ghost instances cannot move (their timing is the
  // repeat region's). The snap already excludes them; stay defensive.
  for (final entry in source.timeline.entries) {
    if (entry.key >= rangeStartIndex &&
        entry.key < rangeEndIndexExclusive &&
        entry.value.isDrawing &&
        entry.value.ghost) {
      return null;
    }
  }

  final groupStart = moved.first.startIndex;
  final groupEndExclusive = moved.last.endIndexExclusive;
  final groupSpan = groupEndExclusive - groupStart;
  final movedStarts = {for (final block in moved) block.startIndex};

  // Cross-layer: the cels travel with the group. A cel referenced from
  // outside the moved set stays put (link preserved — move rejected).
  final movedFrames = <Frame>[];
  final movedFrameIds = <FrameId>[];
  if (!sameLayer) {
    final frameIds = <FrameId>{for (final block in moved) block.frameId};
    for (final candidate in source.timeline.entries) {
      if (movedStarts.contains(candidate.key)) {
        continue;
      }
      final entry = candidate.value;
      if (entry.isDrawing && frameIds.contains(entry.frameId)) {
        return null;
      }
    }
    for (final frameId in frameIds) {
      Frame? frame;
      for (final candidate in source.frames) {
        if (candidate.id == frameId) {
          frame = candidate;
          break;
        }
      }
      if (frame == null) {
        return null;
      }
      movedFrames.add(frame);
      movedFrameIds.add(frameId);
    }
  }

  final others = [
    for (final block in drawingBlocks(targetBase))
      if (!(sameLayer && movedStarts.contains(block.startIndex))) block,
  ];

  final resolved = _resolvePushedLanding(
    others: others,
    requestedStart: groupStart + frameDelta,
    movedLength: groupSpan,
    pushRight: frameDelta >= 0,
    leftwardCap: sameLayer ? groupStart : math.max(0, groupStart),
    sameLayerStart: sameLayer ? groupStart : null,
  );
  if (resolved == null) {
    return null;
  }
  final (:destStart, :pushes) = resolved;
  if (sameLayer && destStart == groupStart && pushes.isEmpty) {
    return null;
  }

  bool startsOnMark(SplayTreeMap<int, TimelineExposure> timeline, int start) {
    final atStart = timeline[start];
    return atStart != null && atStart.isMark;
  }

  for (final block in moved) {
    final landing = destStart + (block.startIndex - groupStart);
    if (startsOnMark(targetBase, landing)) {
      return null;
    }
  }
  for (final push in pushes) {
    if (push.newStart != push.block.startIndex &&
        startsOnMark(targetBase, push.newStart)) {
      return null;
    }
  }

  SplayTreeMap<int, TimelineExposure> targetTimelineAfter() {
    final timeline = SplayTreeMap<int, TimelineExposure>.of(targetBase);
    if (sameLayer) {
      for (final start in movedStarts) {
        timeline.remove(start);
      }
    }
    for (final push in pushes) {
      timeline.remove(push.block.startIndex);
    }
    for (final push in pushes) {
      timeline[push.newStart] = push.block.entry;
    }
    for (final block in moved) {
      timeline[destStart + (block.startIndex - groupStart)] = block.entry;
    }
    return timeline;
  }

  if (sameLayer) {
    return DrawingBlockMovePlan(
      sourceAfter: source.copyWith(timeline: targetTimelineAfter()),
      destinationStartIndex: destStart,
    );
  }

  final movedFrameIdSet = {for (final id in movedFrameIds) id};
  final sourceTimeline = SplayTreeMap<int, TimelineExposure>.of(sourceBase);
  for (final start in movedStarts) {
    sourceTimeline.remove(start);
  }
  return DrawingBlockMovePlan(
    sourceAfter: source.copyWith(
      timeline: sourceTimeline,
      frames: [
        for (final frame in source.frames)
          if (!movedFrameIdSet.contains(frame.id)) frame,
      ],
    ),
    targetBefore: target,
    targetAfter: target.copyWith(
      timeline: targetTimelineAfter(),
      frames: [...target.frames, ...movedFrames],
    ),
    movedFrameIds: movedFrameIds,
    destinationStartIndex: destStart,
  );
}

typedef _Push = ({TimelineDrawingBlock block, int newStart});

/// Where the moved block lands and which blocks it shoves aside.
///
/// Same-layer slides ([sameLayerStart] non-null) BULLDOZE: the moved block
/// never passes a neighbour — every block originally on its travel side
/// that its span reaches (directly or through the chain) is shoved along,
/// relative order preserved. Cross-layer landings ([sameLayerStart] null)
/// keep the plain overlap rules: only blocks the landing actually touches
/// move.
///
/// Rightward ([pushRight]): the landing is exactly [requestedStart]; the
/// shoved blocks shift to later frames, gaps between them absorbing first
/// — the frame axis is endless, so this always succeeds.
///
/// Leftward: blocks ahead are pushed toward frame 0, each one's own gap
/// absorbing before the wave reaches the next. When the chain hits the
/// wall the landing CLAMPS to the nearest feasible start at or above
/// [requestedStart] (never above [leftwardCap]); null when even the cap
/// cannot host the block leftward-style — the caller treats that as an
/// unchanged landing.
({int destStart, List<_Push> pushes})? _resolvePushedLanding({
  required List<TimelineDrawingBlock> others,
  required int requestedStart,
  required int movedLength,
  required bool pushRight,
  required int leftwardCap,
  required int? sameLayerStart,
}) {
  if (pushRight) {
    final destStart = math.max(0, requestedStart);
    final pushes = <_Push>[];
    var frontier = destStart + movedLength;
    for (final block in others) {
      // No-passing rule (same layer): every block originally BEHIND the
      // moved one rides the frontier — a passed block would otherwise be
      // left sitting before the landing. Cross-layer: touch-only.
      final participates = sameLayerStart != null
          ? block.startIndex > sameLayerStart
          : block.endIndexExclusive > destStart;
      if (!participates) {
        continue;
      }
      final newStart = math.max(block.startIndex, frontier);
      frontier = newStart + block.length;
      if (newStart != block.startIndex) {
        pushes.add((block: block, newStart: newStart));
      }
    }
    return (destStart: destStart, pushes: pushes);
  }

  // One leftward attempt: the pushes when the chain fits, or the deficit
  // (how far below frame 0 the deepest pushed block lands). Raising the
  // landing by d raises every chained position by AT MOST d, so the
  // deficit is an exact lower bound on the required raise — jumping by it
  // never skips a feasible landing.
  (List<_Push>?, int) tryLeftward(int destStart) {
    final pushes = <_Push>[];
    var frontier = destStart;
    for (final block in others.reversed) {
      if (sameLayerStart != null) {
        // No-passing rule (same layer): blocks originally AHEAD of the
        // moved one never move on a leftward slide; everything originally
        // before it may be bulldozed toward the wall.
        if (block.startIndex > sameLayerStart) {
          continue;
        }
      } else if (block.startIndex >= destStart + movedLength) {
        continue;
      }
      final newStart = math.min(block.startIndex, frontier - block.length);
      if (newStart < 0) {
        return (null, -newStart);
      }
      if (newStart != block.startIndex) {
        pushes.add((block: block, newStart: newStart));
        frontier = newStart;
      } else {
        // Untouched — everything further left is even further away.
        break;
      }
    }
    return (pushes, 0);
  }

  var destStart = math.max(0, requestedStart);
  while (destStart <= leftwardCap) {
    final (pushes, deficit) = tryLeftward(destStart);
    if (pushes != null) {
      return (destStart: destStart, pushes: pushes);
    }
    destStart += deficit;
  }
  return null;
}
