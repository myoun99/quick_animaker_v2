import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/playback/canvas_playback_controller.dart';

/// ③ Premiere-style playback follow: while playing across cut boundaries
/// the ACTIVE cut tracks the playing cut (pure selection state — the undo
/// stack never sees it) and stays on that cut when playback stops.
void main() {
  (EditorSessionManager, CutId, CutId) twoCutSession() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createCut();
    final track = s.repository.requireProject().tracks.first;
    // createCut selects the new cut; playback starts from the first one.
    s.selectCut(track.cuts[0].id);
    return (s, track.cuts[0].id, track.cuts[1].id);
  }

  testWidgets('crossing a cut boundary switches the active cut and never '
      'touches undo', (tester) async {
    final (s, first, second) = twoCutSession();
    addTearDown(s.dispose);
    final firstDuration = s.cutById(first)!.duration;

    s.playback.play(scope: PlaybackScope.allCuts);
    expect(s.activeCutId, first);

    // Forward across the boundary → the second cut becomes active and the
    // playhead lands on the playing local frame.
    s.playback.seekToGlobalFrame(firstDuration + 2);
    expect(s.activeCutId, second);
    expect(s.currentFrameIndex, 2);

    // Backward across the boundary follows too (loop wrap, ruler seeks).
    s.playback.seekToGlobalFrame(0);
    expect(s.activeCutId, first);

    // Stopping stays on the cut playback reached (Premiere behavior).
    s.playback.seekToGlobalFrame(firstDuration + 3);
    s.playback.stop();
    expect(s.activeCutId, second);
    expect(s.currentFrameIndex, 3);

    // The whole ride left history untouched: the next undo is still the
    // fixture's createCut, nothing selection-shaped sits on top of it.
    s.undo();
    expect(s.repository.requireProject().tracks.first.cuts, hasLength(1));
    expect(s.canUndo, isFalse);

    // Drain the prerender scheduler's zero-delay warming loop.
    await tester.pumpAndSettle();
  });

  testWidgets('single-cut playback never follows anywhere', (tester) async {
    final (s, first, _) = twoCutSession();
    addTearDown(s.dispose);

    s.playback.play(scope: PlaybackScope.activeCut);
    s.playback.seekToGlobalFrame(2);
    expect(s.activeCutId, first);

    s.playback.stop();
    expect(s.activeCutId, first);
    expect(s.currentFrameIndex, 2);

    await tester.pumpAndSettle();
  });
}
