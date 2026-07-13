/// Track-global frame mapping between the session and the storyboard panel:
/// the active track's cuts laid end to end (the same layout allCuts
/// playback plays). Free functions so the storyboard host AND the tab host
/// (playhead clamp on tab switch) share one implementation.
library;

import 'dart:math' as math;

import 'editor_session_manager.dart';
import 'playback/canvas_playback_controller.dart';
import 'storyboard_timeline_layout.dart';

/// The active track's layout entries (the track containing the active cut;
/// every entry as fallback when it is not found).
List<StoryboardTimelineLayoutEntry> storyboardActiveTrackLayout(
  EditorSessionManager session,
) {
  final layout = buildStoryboardTimelineLayout(
    session.repository.requireProject(),
  );
  for (final entry in layout) {
    if (entry.cutId == session.activeCutId) {
      return layout
          .where((candidate) => candidate.trackId == entry.trackId)
          .toList(growable: false);
    }
  }
  return layout;
}

/// Where the storyboard playhead sits: the playback position while playback
/// is active (an activeCut-scope playlist is rebased to frame 0, so map
/// through the cut's track slot), the editing playhead otherwise. An
/// over-end playhead on the track's LAST cut stays unclamped — it lives in
/// the endless runway, exactly like the timeline shows it.
///
/// [layout] takes a prebuilt active-track layout so per-tick callers
/// (the storyboard host's playhead refresh) don't rebuild it every frame
/// (R12-⑥); omitted, it is derived here.
int? storyboardPlayheadFrame(
  EditorSessionManager session, {
  List<StoryboardTimelineLayoutEntry>? layout,
}) {
  final playback = session.playback;
  // All-cuts playback speaks TRACK-GLOBAL frames directly — including the
  // GAP frames between cuts, where there is no cut position to map
  // through (R10-⑤: the ruler must keep moving through gaps).
  if (playback.isActive && playback.scope == PlaybackScope.allCuts) {
    final global = playback.globalFrameIndexListenable.value;
    if (global != null) {
      return global;
    }
  }
  layout ??= storyboardActiveTrackLayout(session);
  final playbackPosition = session.playback.isActive
      ? session.playback.position
      : null;
  final cutId = playbackPosition?.cutId ?? session.activeCutId;
  final localFrame =
      playbackPosition?.localFrameIndex ?? session.currentFrameIndex;
  for (var index = 0; index < layout.length; index += 1) {
    final entry = layout[index];
    if (entry.cutId == cutId) {
      final isLastCut = index == layout.length - 1;
      if (playbackPosition == null) {
        // Editing playhead: over-end is LEGAL — the trailing gap is the
        // cut's runway (gap landing, R14-①), and the last cut's runway is
        // endless. Mid-track over-end clamps to the gap so a stale index
        // never paints on top of the next cut.
        final local = math.max(0, localFrame);
        return entry.startFrame +
            (isLastCut
                ? local
                : math.min(
                    local,
                    layout[index + 1].startFrame - entry.startFrame - 1,
                  ));
      }
      final maxLocal = entry.duration > 0 ? entry.duration - 1 : 0;
      return entry.startFrame + localFrame.clamp(0, maxLocal);
    }
  }
  return null;
}

/// Whether the track-global [globalFrame]'s playback composite is warmed —
/// the storyboard ruler's green bar. [layout] takes a prebuilt layout: the
/// ruler asks PER VISIBLE FRAME per repaint, and rebuilding the whole
/// track layout for each column was a fixed per-tick tax (R12-⑥).
bool storyboardFrameCached(
  EditorSessionManager session,
  int globalFrame, {
  List<StoryboardTimelineLayoutEntry>? layout,
}) {
  for (final entry in layout ?? storyboardActiveTrackLayout(session)) {
    if (globalFrame >= entry.startFrame && globalFrame < entry.endFrame) {
      return session.isPlaybackFrameCachedForCut(
        entry.cut,
        globalFrame - entry.startFrame,
      );
    }
  }
  return false;
}

/// The layout entry that OWNS [globalFrame]: the cut containing it, or —
/// inside a gap — the cut BEFORE it (a trailing gap is the preceding
/// cut's over-end runway, R14-①: the editing playhead lands in gaps as an
/// over-end frame of that cut, the same grammar as the last cut's endless
/// runway). Null only in the leading gap before the first cut, which has
/// no preceding cut to run over.
StoryboardTimelineLayoutEntry? storyboardEntryOwningFrame(
  List<StoryboardTimelineLayoutEntry> layout,
  int globalFrame,
) {
  StoryboardTimelineLayoutEntry? previous;
  for (final entry in layout) {
    if (globalFrame < entry.startFrame) {
      return previous;
    }
    if (globalFrame < entry.endFrame) {
      return entry;
    }
    previous = entry;
  }
  return previous;
}

/// Ruler seeks: playback seeks the clock, editing selects cut + frame;
/// beyond a cut's end — a GAP or past the last cut — the editing playhead
/// LANDS there as the owning cut's over-end frame (R14-①), exactly like
/// clicking past the cut end in the timeline. Playback seeks land in gaps
/// directly (background frame).
void seekStoryboardGlobalFrame(EditorSessionManager session, int globalFrame) {
  final layout = storyboardActiveTrackLayout(session);
  if (layout.isEmpty) {
    return;
  }
  final playback = session.playback;
  if (playback.isActive) {
    if (playback.scope == PlaybackScope.allCuts) {
      playback.seekToGlobalFrame(globalFrame);
      return;
    }
    // Single-cut playback: its playlist is rebased to frame 0, and seeks
    // outside the playing cut are a no-op.
    for (final entry in layout) {
      if (globalFrame >= entry.startFrame &&
          globalFrame < entry.endFrame &&
          entry.cutId == playback.position?.cutId) {
        playback.seekToGlobalFrame(globalFrame - entry.startFrame);
        return;
      }
    }
    return;
  }
  final owner = storyboardEntryOwningFrame(layout, globalFrame);
  if (owner == null) {
    // The leading gap before the FIRST cut: local frames cannot go
    // negative, so land on its first frame.
    final first = layout.first;
    if (first.cutId != session.activeCutId) {
      session.selectCut(first.cutId);
    }
    session.selectFrameIndex(0);
    return;
  }
  if (owner.cutId != session.activeCutId) {
    session.selectCut(owner.cutId);
  }
  session.selectFrameIndex(globalFrame - owner.startFrame);
}

/// Ruler drag moves: playback keeps seeking the clock per move; editing
/// scrubs ride the session cursor path inside the ACTIVE cut (no notify,
/// canvas preview follows) — including into its trailing gap (over-end
/// cursor) — and fall back to the full seek only when the drag crosses
/// into another cut's territory: the cut switch is a real selection.
void scrubStoryboardGlobalFrame(EditorSessionManager session, int globalFrame) {
  if (session.playback.isActive) {
    seekStoryboardGlobalFrame(session, globalFrame);
    return;
  }
  final layout = storyboardActiveTrackLayout(session);
  if (layout.isEmpty) {
    return;
  }
  final owner = storyboardEntryOwningFrame(layout, globalFrame);
  if (owner == null || owner.cutId != session.activeCutId) {
    seekStoryboardGlobalFrame(session, globalFrame);
    return;
  }
  session.scrubFrameIndex(math.max(0, globalFrame - owner.startFrame));
}

/// The storyboard ruler drag's release: commits the scrubbed playhead once
/// (playback drags have nothing to commit).
void commitStoryboardScrub(EditorSessionManager session) {
  if (!session.playback.isActive) {
    session.commitFrameScrub();
  }
}

/// Switching into the storyboard clamps an over-end playhead back into the
/// cut's territory — its frames PLUS its trailing gap (the over-end runway
/// gap landings live in, R14-①); the track's last cut keeps its endless
/// runway — so the frame counter and the playhead line agree.
void clampPlayheadForStoryboard(EditorSessionManager session) {
  if (session.playback.isActive) {
    return;
  }
  final layout = storyboardActiveTrackLayout(session);
  if (layout.isEmpty || layout.last.cutId == session.activeCutId) {
    return;
  }
  for (var index = 0; index < layout.length - 1; index += 1) {
    final entry = layout[index];
    if (entry.cutId != session.activeCutId) {
      continue;
    }
    final maxLocal = layout[index + 1].startFrame - entry.startFrame - 1;
    if (maxLocal >= 0 && session.currentFrameIndex > maxLocal) {
      session.selectFrameIndex(maxLocal);
    }
    return;
  }
}
