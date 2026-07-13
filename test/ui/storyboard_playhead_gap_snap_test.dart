import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/playback/canvas_playback_controller.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_playhead_mapping.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_timeline_layout.dart';

/// R14-① (was R10-⑤b): the editing playhead LANDS in cut gaps. A trailing
/// gap is the preceding cut's over-end runway — seeks/scrubs into it keep
/// that cut active with an over-end frame index, the exact grammar of the
/// last cut's endless runway. Playback seeks land in gaps directly.
void main() {
  /// Two default-track cuts with a gap before the second:
  /// cut-a [0, aEnd), gap [aEnd, aEnd+4), cut-b [aEnd+4, ...).
  (EditorSessionManager, CutId, CutId, int) gappedSession() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createCut();
    final track = s.repository.requireProject().tracks.first;
    final first = track.cuts[0].id;
    final second = track.cuts[1].id;
    s.repository.updateCutLeadingGap(cutId: second, leadingGapFrames: 4);
    return (s, first, second, track.cuts[0].duration);
  }

  test('storyboardEntryOwningFrame: cut frames map to their cut, gap frames '
      'to the PRECEDING cut, past-the-end to the last cut', () {
    final (s, first, second, aEnd) = gappedSession();
    final layout = buildStoryboardTimelineLayout(s.repository.requireProject());

    expect(storyboardEntryOwningFrame(layout, 0)?.cutId, first);
    expect(storyboardEntryOwningFrame(layout, aEnd - 1)?.cutId, first);
    // Every gap frame belongs to cut-a's runway — no nearest-edge split.
    expect(storyboardEntryOwningFrame(layout, aEnd)?.cutId, first);
    expect(storyboardEntryOwningFrame(layout, aEnd + 3)?.cutId, first);
    expect(storyboardEntryOwningFrame(layout, aEnd + 4)?.cutId, second);
    expect(
      storyboardEntryOwningFrame(layout, aEnd + 400)?.cutId,
      second,
      reason: 'past the last cut = its endless runway',
    );
  });

  test('an editing seek into the gap LANDS there: preceding cut stays '
      'active with an over-end frame, and the playhead maps back to the '
      'same global frame', () {
    final (s, first, _, aEnd) = gappedSession();
    s.selectCut(first);

    seekStoryboardGlobalFrame(s, aEnd + 1);
    expect(s.activeCutId, first);
    expect(s.currentFrameIndex, aEnd + 1, reason: 'over-end local frame');
    expect(
      storyboardPlayheadFrame(s),
      aEnd + 1,
      reason: 'the ruler shows the gap landing, not a snapped edge',
    );

    // Late in the gap: STILL the preceding cut (the whole gap is its
    // runway — no nearest-edge handover).
    seekStoryboardGlobalFrame(s, aEnd + 3);
    expect(s.activeCutId, first);
    expect(s.currentFrameIndex, aEnd + 3);
    expect(storyboardPlayheadFrame(s), aEnd + 3);
  });

  test('a leading gap before the FIRST cut lands on its first frame — '
      'local frames cannot go negative', () {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    final cutId = s.repository.requireProject().tracks.first.cuts.first.id;
    s.repository.updateCutLeadingGap(cutId: cutId, leadingGapFrames: 3);

    seekStoryboardGlobalFrame(s, 1);
    expect(s.activeCutId, cutId);
    expect(s.currentFrameIndex, 0);
  });

  test('an editing scrub into the active cut\'s trailing gap rides the '
      'cursor path (no session notify) with an over-end cursor', () {
    final (s, first, _, aEnd) = gappedSession();
    s.selectCut(first);
    var notifies = 0;
    s.addListener(() => notifies += 1);

    scrubStoryboardGlobalFrame(s, aEnd - 2);
    expect(s.editingFrameCursor.value, aEnd - 2);
    scrubStoryboardGlobalFrame(s, aEnd + 1);
    expect(s.editingFrameCursor.value, aEnd + 1, reason: 'gap = over-end');
    expect(notifies, 0);
  });

  test('the mid-track playhead clamps to the END of the trailing gap, not '
      'the cut end — and the tab-switch clamp agrees', () {
    final (s, first, _, aEnd) = gappedSession();
    s.selectCut(first);

    // Over-end BEYOND the gap can't paint on top of cut-b: the mapping
    // clamps the displayed playhead to the gap's last frame.
    s.selectFrameIndex(aEnd + 40);
    expect(storyboardPlayheadFrame(s), aEnd + 3);

    clampPlayheadForStoryboard(s);
    expect(s.currentFrameIndex, aEnd + 3);

    // Within the gap the clamp leaves the landing alone.
    s.selectFrameIndex(aEnd + 2);
    clampPlayheadForStoryboard(s);
    expect(s.currentFrameIndex, aEnd + 2);
  });

  test('R15-①: the session speaks the axis natively — selectGlobalFrame '
      'round-trips through editingGlobalFrame, and the storyboard playhead '
      'is the SAME number (one model, both panels)', () {
    final (s, first, second, aEnd) = gappedSession();
    s.selectCut(first);

    for (final global in [0, aEnd - 1, aEnd, aEnd + 3, aEnd + 4, aEnd + 9]) {
      s.selectGlobalFrame(global);
      expect(s.editingGlobalFrame, global, reason: 'round trip at $global');
      expect(
        storyboardPlayheadFrame(s),
        global,
        reason: 'the storyboard reads the same axis at $global',
      );
    }
    // Ownership: gap frames belong to cut-a, cut-b starts at aEnd+4.
    s.selectGlobalFrame(aEnd + 2);
    expect(s.activeCutId, first);
    s.selectGlobalFrame(aEnd + 4);
    expect(s.activeCutId, second);

    // Territory clamp: a stale over-end local never addresses cut-b.
    s.selectCut(first);
    expect(
      s.trackFrameAxis().clampedGlobalOf(first, aEnd + 400),
      aEnd + 3,
      reason: 'mid-track territory ends at the gap\'s last frame',
    );
  });

  testWidgets('a playback seek lands IN the gap: background frame, no snap', (
    tester,
  ) async {
    final (s, first, _, aEnd) = gappedSession();
    addTearDown(s.dispose);
    s.selectCut(first);

    s.playback.play(scope: PlaybackScope.allCuts);
    seekStoryboardGlobalFrame(s, aEnd + 1);

    expect(s.playback.globalFrameIndexListenable.value, aEnd + 1);
    expect(s.playback.position, isNull, reason: 'gap frames resolve to null');
    // The gap belongs to no cut — the editing selection stays put.
    expect(s.activeCutId, first);
    s.playback.stop();
    // Drain the prerender scheduler's zero-delay warming loop.
    await tester.pumpAndSettle();
  });

  testWidgets('the storyboard playhead keeps MOVING through gaps during '
      'all-cuts playback (R10-⑤)', (tester) async {
    final (s, first, _, aEnd) = gappedSession();
    addTearDown(s.dispose);
    s.selectCut(first);
    s.selectFrameIndex(0);

    s.playback.play(scope: PlaybackScope.allCuts);
    // Inside cut-a: the mapped position and the global agree.
    seekStoryboardGlobalFrame(s, 1);
    expect(storyboardPlayheadFrame(s), 1);

    // IN the gap: the ruler playhead reads the playback clock's global
    // frame instead of freezing on the stale editing playhead.
    seekStoryboardGlobalFrame(s, aEnd + 2);
    expect(s.playback.position, isNull);
    expect(storyboardPlayheadFrame(s), aEnd + 2);

    s.playback.stop();
    await tester.pumpAndSettle();
  });
}
