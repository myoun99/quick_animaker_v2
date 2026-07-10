import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart'
    show TimelineBlockEdge;
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_timeline_layout.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_drag_preview.dart';

void main() {
  /// Two cuts on the default track; returns (session, first id, second id).
  (EditorSessionManager, CutId, CutId) twoCutSession() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createCut();
    final track = s.repository.requireProject().tracks.first;
    return (s, track.cuts[0].id, track.cuts[1].id);
  }

  /// The previewed duration for [cutId], falling back to the repository
  /// (what a preview consumer renders during the drag).
  int previewedDuration(EditorSessionManager s, CutId cutId) {
    final preview = s.dragPreview.value;
    if (preview is CutTrimDragPreview &&
        preview.previewDurations.containsKey(cutId)) {
      return preview.previewDurations[cutId]!;
    }
    return s.cutById(cutId)!.duration;
  }

  /// The previewed leading gap for [cutId], falling back to the repository.
  int previewedGap(EditorSessionManager s, CutId cutId) {
    final preview = s.dragPreview.value;
    if (preview is CutTrimDragPreview &&
        preview.previewGaps.containsKey(cutId)) {
      return preview.previewGaps[cutId]!;
    }
    return s.cutById(cutId)!.leadingGapFrames;
  }

  /// [cutId]'s committed global start frame on the track layout.
  int layoutStart(EditorSessionManager s, CutId cutId) {
    return buildStoryboardTimelineLayout(
      s.repository.requireProject(),
    ).firstWhere((entry) => entry.cutId == cutId).startFrame;
  }

  test('end-edge drag previews on the channel and commits one undo', () {
    final (s, first, _) = twoCutSession();
    final before = s.cutById(first)!.duration;
    var notifies = 0;
    s.addListener(() => notifies += 1);

    expect(
      s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.end),
      isTrue,
    );
    s.updateCutEdgeDrag(3);
    // The preview rides the channel; the REPOSITORY stays untouched and no
    // session notify fires per step (the drag-lag fix's core invariant).
    expect(previewedDuration(s, first), before + 3);
    expect(s.cutById(first)!.duration, before);
    expect(notifies, 0);

    // Cumulative deltas recompute from the snapshot; a huge negative clamps
    // at one frame.
    s.updateCutEdgeDrag(-before - 30);
    expect(previewedDuration(s, first), 1);

    s.updateCutEdgeDrag(6);
    expect(previewedDuration(s, first), before + 6);

    s.endCutEdgeDrag();
    expect(s.cutById(first)!.duration, before + 6);
    expect(s.dragPreview.value, isNull);
    expect(notifies, 1);

    // ONE undo step for the whole drag.
    s.undo();
    expect(s.cutById(first)!.duration, before);
    s.redo();
    expect(s.cutById(first)!.duration, before + 6);
  });

  test('start-edge drag SLIDES the cut: rightward creates a leading gap, '
      'leftward consumes it, clamped at contact', () {
    final (s, first, second) = twoCutSession();
    final firstDuration = s.cutById(first)!.duration;

    expect(
      s.beginCutEdgeDrag(cutId: second, edge: TimelineBlockEdge.start),
      isTrue,
    );

    // Rightward: the cut slides later — a gap opens before it; duration is
    // untouched on BOTH cuts (slide, not roll).
    s.updateCutEdgeDrag(5);
    expect(previewedGap(s, second), 5);
    expect(previewedDuration(s, first), firstDuration);
    expect(previewedDuration(s, second), s.cutById(second)!.duration);

    // Leftward past contact clamps at gap 0 (cuts never overlap).
    s.updateCutEdgeDrag(-9);
    expect(previewedGap(s, second), 0);

    s.updateCutEdgeDrag(4);
    s.endCutEdgeDrag();
    expect(s.cutById(second)!.leadingGapFrames, 4);
    expect(layoutStart(s, second), firstDuration + 4);

    // ONE undo step restores the gap.
    s.undo();
    expect(s.cutById(second)!.leadingGapFrames, 0);
    expect(layoutStart(s, second), firstDuration);
    s.redo();
    expect(s.cutById(second)!.leadingGapFrames, 4);
  });

  test('the FIRST cut slides too — its gap is black lead-in before the '
      'track begins', () {
    final (s, first, second) = twoCutSession();
    final firstDuration = s.cutById(first)!.duration;

    expect(
      s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.start),
      isTrue,
    );
    s.updateCutEdgeDrag(3);
    s.endCutEdgeDrag();

    expect(s.cutById(first)!.leadingGapFrames, 3);
    expect(layoutStart(s, first), 3);
    // The whole track shifts with it (the second cut stays adjacent).
    expect(layoutStart(s, second), 3 + firstDuration);
  });

  test('end-edge growth eats the following gap first — the next cut holds '
      'still until the gap is spent, then gets pushed', () {
    final (s, first, second) = twoCutSession();
    final firstDuration = s.cutById(first)!.duration;

    // Open a 4-frame gap before the second cut.
    s.beginCutEdgeDrag(cutId: second, edge: TimelineBlockEdge.start);
    s.updateCutEdgeDrag(4);
    s.endCutEdgeDrag();
    expect(layoutStart(s, second), firstDuration + 4);

    // Grow the first cut by 3: the gap absorbs it, the second cut's start
    // does not move.
    s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.end);
    s.updateCutEdgeDrag(3);
    expect(previewedDuration(s, first), firstDuration + 3);
    expect(previewedGap(s, second), 1);
    s.endCutEdgeDrag();
    expect(s.cutById(second)!.leadingGapFrames, 1);
    expect(layoutStart(s, second), firstDuration + 4);

    // Grow past the remaining gap: gap 0, the excess pushes the second cut.
    s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.end);
    s.updateCutEdgeDrag(3);
    s.endCutEdgeDrag();
    expect(s.cutById(second)!.leadingGapFrames, 0);
    expect(layoutStart(s, second), firstDuration + 6);
  });

  test('end-edge shrink leaves the following gap alone (the rest slides '
      'earlier with the boundary)', () {
    final (s, first, second) = twoCutSession();
    final firstDuration = s.cutById(first)!.duration;

    s.beginCutEdgeDrag(cutId: second, edge: TimelineBlockEdge.start);
    s.updateCutEdgeDrag(4);
    s.endCutEdgeDrag();

    s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.end);
    s.updateCutEdgeDrag(-2);
    expect(previewedGap(s, second), 4);
    s.endCutEdgeDrag();

    expect(s.cutById(first)!.duration, firstDuration - 2);
    expect(s.cutById(second)!.leadingGapFrames, 4);
    expect(layoutStart(s, second), firstDuration - 2 + 4);
  });

  test('cancel drops the preview without touching history or the repo', () {
    final (s, first, _) = twoCutSession();
    final before = s.cutById(first)!.duration;
    final undoDepthProbe = s.canUndo; // createCut is already undoable.

    s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.end);
    s.updateCutEdgeDrag(5);
    expect(previewedDuration(s, first), before + 5);
    expect(s.cutById(first)!.duration, before);

    s.cancelCutEdgeDrag();
    expect(s.dragPreview.value, isNull);
    expect(s.cutById(first)!.duration, before);
    expect(s.canUndo, undoDepthProbe);

    // Undo now reverts the CUT CREATION, not a phantom trim.
    s.undo();
    expect(s.repository.requireProject().tracks.first.cuts, hasLength(1));
  });

  test('ending an unchanged drag leaves no undo entry', () {
    final (s, first, _) = twoCutSession();

    s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.end);
    s.updateCutEdgeDrag(0);
    s.endCutEdgeDrag();

    // The only undoable step is still the cut creation.
    s.undo();
    expect(s.repository.requireProject().tracks.first.cuts, hasLength(1));
    expect(s.canUndo, isFalse);
  });
}
