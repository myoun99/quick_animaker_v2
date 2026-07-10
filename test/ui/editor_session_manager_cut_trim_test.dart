import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart'
    show TimelineBlockEdge;
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
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

  test('start-edge drag rolls the boundary with the previous cut', () {
    final (s, first, second) = twoCutSession();
    final beforeFirst = s.cutById(first)!.duration;
    final beforeSecond = s.cutById(second)!.duration;

    expect(
      s.beginCutEdgeDrag(cutId: second, edge: TimelineBlockEdge.start),
      isTrue,
    );

    // Boundary left: the previous cut shrinks, this one grows — the track's
    // total length is conserved (in the preview; the repo commits on end).
    s.updateCutEdgeDrag(-5);
    expect(previewedDuration(s, first), beforeFirst - 5);
    expect(previewedDuration(s, second), beforeSecond + 5);

    // Clamped so both cuts keep at least one frame.
    s.updateCutEdgeDrag(beforeSecond + 40);
    expect(previewedDuration(s, first), beforeFirst + beforeSecond - 1);
    expect(previewedDuration(s, second), 1);

    s.endCutEdgeDrag();
    expect(s.cutById(first)!.duration, beforeFirst + beforeSecond - 1);
    expect(s.cutById(second)!.duration, 1);

    s.undo();
    expect(s.cutById(first)!.duration, beforeFirst);
    expect(s.cutById(second)!.duration, beforeSecond);
  });

  test('the first cut has no start-edge roll partner', () {
    final (s, first, _) = twoCutSession();

    expect(
      s.beginCutEdgeDrag(cutId: first, edge: TimelineBlockEdge.start),
      isFalse,
    );
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
