import 'dart:collection';

import 'frame.dart';
import 'frame_id.dart';
import 'layer.dart';
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
/// - the destination must be fully EMPTY on the target timeline (no push —
///   a block move never silently retimes other blocks), and its start must
///   not collide with a mark entry;
/// - the destination cannot start before frame 0;
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
  final destStart = blockStartIndex + frameDelta;
  if (destStart < 0) {
    return null;
  }
  final length = entry.length!;
  final destEnd = destStart + length;

  // Destination emptiness on the target timeline (the block's own entry is
  // ignored when sliding within the source layer).
  for (final candidate in target.timeline.entries) {
    if (sameLayer && candidate.key == blockStartIndex) {
      continue;
    }
    if (candidate.value.isDrawing) {
      final start = candidate.key;
      final end = start + candidate.value.length!;
      if (start < destEnd && destStart < end) {
        return null;
      }
    } else if (candidate.key == destStart) {
      // A mark may sit INSIDE the moved block's hold, but the block start
      // would overwrite a mark sharing its exact index.
      return null;
    }
  }

  if (sameLayer) {
    final timeline = SplayTreeMap<int, TimelineExposure>.of(source.timeline)
      ..remove(blockStartIndex);
    timeline[destStart] = entry;
    return DrawingBlockMovePlan(
      sourceAfter: source.copyWith(timeline: timeline),
      destinationStartIndex: destStart,
    );
  }

  // Cross-layer: the cel travels with the block. Linked cels (the same
  // frame exposed by another entry) stay: rejecting keeps the link intact.
  final frameId = entry.frameId!;
  for (final candidate in source.timeline.entries) {
    if (candidate.key != blockStartIndex &&
        candidate.value.isDrawing &&
        candidate.value.frameId == frameId) {
      return null;
    }
  }
  Frame? movedFrame;
  for (final frame in source.frames) {
    if (frame.id == frameId) {
      movedFrame = frame;
      break;
    }
  }
  if (movedFrame == null) {
    return null;
  }

  final sourceTimeline = SplayTreeMap<int, TimelineExposure>.of(source.timeline)
    ..remove(blockStartIndex);
  final targetTimeline = SplayTreeMap<int, TimelineExposure>.of(
    target.timeline,
  );
  targetTimeline[destStart] = entry;
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
      timeline: targetTimeline,
      frames: [...target.frames, movedFrame],
    ),
    movedFrameIds: [frameId],
    destinationStartIndex: destStart,
  );
}
