import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/playback/canvas_playback_controller.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_playhead_mapping.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_timeline_layout.dart';

/// W3c: editing seeks/scrubs landing in a cut GAP snap to the nearest cut
/// edge (the editing playhead is cut-local, a gap has no cut); playback
/// seeks land in the gap as-is (black frame).
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

  test('snapStoryboardGapToNearestEdge picks the closer cut edge and ties '
      'to the previous cut', () {
    final (s, _, second, aEnd) = gappedSession();
    final layout = buildStoryboardTimelineLayout(s.repository.requireProject());

    // Non-gap frames pass through untouched.
    expect(snapStoryboardGapToNearestEdge(layout, 0), 0);
    expect(snapStoryboardGapToNearestEdge(layout, aEnd - 1), aEnd - 1);
    expect(snapStoryboardGapToNearestEdge(layout, aEnd + 4), aEnd + 4);

    // Gap [aEnd, aEnd+4): frames closer to cut-a's LAST frame (aEnd-1)
    // snap back, frames closer to cut-b's first (aEnd+4) snap forward.
    expect(snapStoryboardGapToNearestEdge(layout, aEnd), aEnd - 1);
    expect(snapStoryboardGapToNearestEdge(layout, aEnd + 1), aEnd - 1);
    expect(snapStoryboardGapToNearestEdge(layout, aEnd + 2), aEnd + 4);
    expect(snapStoryboardGapToNearestEdge(layout, aEnd + 3), aEnd + 4);

    // A true tie (equidistant from both edges) snaps BACKWARD.
    s.repository.updateCutLeadingGap(cutId: second, leadingGapFrames: 3);
    final tightLayout = buildStoryboardTimelineLayout(
      s.repository.requireProject(),
    );
    // Gap [aEnd, aEnd+3): aEnd+1 is 2 from aEnd-1 and 2 from aEnd+3.
    expect(snapStoryboardGapToNearestEdge(tightLayout, aEnd + 1), aEnd - 1);
  });

  test('a leading gap before the FIRST cut snaps forward to its start', () {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    final cutId = s.repository.requireProject().tracks.first.cuts.first.id;
    s.repository.updateCutLeadingGap(cutId: cutId, leadingGapFrames: 3);
    final layout = buildStoryboardTimelineLayout(s.repository.requireProject());

    expect(snapStoryboardGapToNearestEdge(layout, 0), 3);
    expect(snapStoryboardGapToNearestEdge(layout, 2), 3);
  });

  test('an editing seek into the gap selects the snapped cut and frame', () {
    final (s, first, second, aEnd) = gappedSession();
    s.selectCut(first);

    // Early in the gap → cut-a's last frame.
    seekStoryboardGlobalFrame(s, aEnd + 1);
    expect(s.activeCutId, first);
    expect(s.currentFrameIndex, aEnd - 1);

    // Late in the gap → cut-b frame 0 (a real cut switch).
    seekStoryboardGlobalFrame(s, aEnd + 3);
    expect(s.activeCutId, second);
    expect(s.currentFrameIndex, 0);
  });

  test('an editing scrub through the gap rides the snapped edge on the '
      'cursor path', () {
    final (s, first, _, aEnd) = gappedSession();
    s.selectCut(first);
    var notifies = 0;
    s.addListener(() => notifies += 1);

    // Scrub within the active cut, then into the gap: the cursor pins to
    // the cut's last frame without a session notify (cursor path).
    scrubStoryboardGlobalFrame(s, aEnd - 2);
    expect(s.editingFrameCursor.value, aEnd - 2);
    scrubStoryboardGlobalFrame(s, aEnd + 1);
    expect(s.editingFrameCursor.value, aEnd - 1);
    expect(notifies, 0);
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
