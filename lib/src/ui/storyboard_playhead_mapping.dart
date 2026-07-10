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
int? storyboardPlayheadFrame(EditorSessionManager session) {
  final layout = storyboardActiveTrackLayout(session);
  final playbackPosition = session.playback.isActive
      ? session.playback.position
      : null;
  final cutId = playbackPosition?.cutId ?? session.activeCutId;
  final localFrame =
      playbackPosition?.localFrameIndex ?? session.currentFrameIndex;
  for (final entry in layout) {
    if (entry.cutId == cutId) {
      final isLastCut = identical(entry, layout.last);
      final maxLocal = entry.duration > 0 ? entry.duration - 1 : 0;
      return entry.startFrame +
          (isLastCut && playbackPosition == null
              ? math.max(0, localFrame)
              : localFrame.clamp(0, maxLocal));
    }
  }
  return null;
}

/// Whether the track-global [globalFrame]'s playback composite is warmed —
/// the storyboard ruler's green bar.
bool storyboardFrameCached(EditorSessionManager session, int globalFrame) {
  for (final entry in storyboardActiveTrackLayout(session)) {
    if (globalFrame >= entry.startFrame && globalFrame < entry.endFrame) {
      return session.isPlaybackFrameCachedForCut(
        entry.cut,
        globalFrame - entry.startFrame,
      );
    }
  }
  return false;
}

/// A GAP frame (empty space between cuts) snapped to the nearest cut edge
/// — the editing playhead is cut-local and has no home in a gap. Returns
/// [globalFrame] unchanged when it is not in a gap.
int snapStoryboardGapToNearestEdge(
  List<StoryboardTimelineLayoutEntry> layout,
  int globalFrame,
) {
  StoryboardTimelineLayoutEntry? previous;
  for (final entry in layout) {
    if (globalFrame < entry.startFrame) {
      final previousLast = previous == null ? null : previous.endFrame - 1;
      if (previousLast == null) {
        return entry.startFrame;
      }
      return (globalFrame - previousLast) <= (entry.startFrame - globalFrame)
          ? previousLast
          : entry.startFrame;
    }
    if (globalFrame < entry.endFrame) {
      return globalFrame;
    }
    previous = entry;
  }
  return globalFrame;
}

/// Ruler seeks: playback seeks the clock, editing selects cut + frame;
/// beyond the last cut = over-end selection on the last cut, exactly like
/// clicking past the cut end in the timeline. Editing seeks into a GAP
/// snap to the nearest cut edge (playback seeks land in the gap — black).
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
  final snapped = snapStoryboardGapToNearestEdge(layout, globalFrame);
  for (final entry in layout) {
    if (snapped >= entry.startFrame && snapped < entry.endFrame) {
      if (entry.cutId != session.activeCutId) {
        session.selectCut(entry.cutId);
      }
      session.selectFrameIndex(snapped - entry.startFrame);
      return;
    }
  }
  final last = layout.last;
  if (snapped >= last.endFrame) {
    if (last.cutId != session.activeCutId) {
      session.selectCut(last.cutId);
    }
    session.selectFrameIndex(snapped - last.startFrame);
  }
}

/// Ruler drag moves: playback keeps seeking the clock per move; editing
/// scrubs ride the session cursor path inside the ACTIVE cut (no notify,
/// canvas preview follows) and fall back to the full seek only when the
/// drag crosses into another cut — the cut switch is a real selection.
void scrubStoryboardGlobalFrame(EditorSessionManager session, int globalFrame) {
  if (session.playback.isActive) {
    seekStoryboardGlobalFrame(session, globalFrame);
    return;
  }
  final layout = storyboardActiveTrackLayout(session);
  if (layout.isEmpty) {
    return;
  }
  // Editing scrubs through a gap ride the nearest cut edge (the same snap
  // the seek applies).
  final snapped = snapStoryboardGapToNearestEdge(layout, globalFrame);
  for (final entry in layout) {
    if (snapped >= entry.startFrame && snapped < entry.endFrame) {
      if (entry.cutId == session.activeCutId) {
        session.scrubFrameIndex(snapped - entry.startFrame);
      } else {
        seekStoryboardGlobalFrame(session, snapped);
      }
      return;
    }
  }
  final last = layout.last;
  if (snapped >= last.endFrame) {
    if (last.cutId == session.activeCutId) {
      session.scrubFrameIndex(snapped - last.startFrame);
    } else {
      seekStoryboardGlobalFrame(session, snapped);
    }
  }
}

/// The storyboard ruler drag's release: commits the scrubbed playhead once
/// (playback drags have nothing to commit).
void commitStoryboardScrub(EditorSessionManager session) {
  if (!session.playback.isActive) {
    session.commitFrameScrub();
  }
}

/// Switching into the storyboard clamps an over-end playhead back onto the
/// cut (except on the track's last cut, whose runway can show it) so the
/// frame counter and the playhead line agree.
void clampPlayheadForStoryboard(EditorSessionManager session) {
  if (session.playback.isActive) {
    return;
  }
  final layout = storyboardActiveTrackLayout(session);
  if (layout.isEmpty || layout.last.cutId == session.activeCutId) {
    return;
  }
  final duration = session.activeCut.duration;
  if (duration > 0 && session.currentFrameIndex >= duration) {
    session.selectFrameIndex(duration - 1);
  }
}
