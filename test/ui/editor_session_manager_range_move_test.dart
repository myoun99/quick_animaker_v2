import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_drag_preview.dart';

/// UI-R8: frame-range selection (block-snapped) + the range move drag
/// session — channel-only previews, one undo per drag, selection follows
/// the landing.
void main() {
  /// A session with TWO blocks on layer A (frames 0 and 3, length 1 each)
  /// and an empty layer B below.
  (EditorSessionManager, Layer a, Layer b) fixture() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createDrawingAtCurrentFrame();
    final layerA = s.activeLayer!;
    s.selectFrameIndex(3);
    s.createDrawingAtCurrentFrame();
    s.addLayer();
    final layerB = s.activeLayer!;
    s.selectLayer(layerA.id);
    s.selectFrameIndex(0);
    return (
      s,
      s.layers.firstWhere((l) => l.id == layerA.id),
      s.layers.firstWhere((l) => l.id == layerB.id),
    );
  }

  test('a drag SNAPS to whole blocks: half-covering a block extends the '
      'selection through it', () {
    final (s, a, _) = fixture();

    // Raw drag from frame 1 (inside nothing — the blocks are at 0 and 3,
    // both length 1)… drag 0→3 half-covers nothing; drag over block cells
    // snaps outward.
    s.updateFrameRangeSelectionDrag(
      layerId: a.id,
      anchorIndex: 0,
      headIndex: 3,
    );
    final selection = s.frameRangeSelection.value;
    expect(selection, isNotNull);
    expect(selection!.layerId, a.id);
    expect(selection.startIndex, 0);
    // The head cell (3) is a block start: the block extends the range to
    // its end.
    expect(selection.endIndexExclusive, 4);
  });

  test('selection clears on layer switch and cut refresh', () {
    final (s, a, b) = fixture();
    s.updateFrameRangeSelectionDrag(
      layerId: a.id,
      anchorIndex: 0,
      headIndex: 0,
    );
    expect(s.frameRangeSelection.value, isNotNull);

    s.selectLayer(b.id);
    expect(s.frameRangeSelection.value, isNull);
  });

  test('range move slides BOTH blocks as one rigid group: channel-only '
      'preview, one commit notify, one undo', () {
    final (s, a, _) = fixture();
    s.updateFrameRangeSelectionDrag(
      layerId: a.id,
      anchorIndex: 0,
      headIndex: 3,
    );
    var notifies = 0;
    s.addListener(() => notifies += 1);

    expect(s.beginFrameRangeMoveDrag(), isTrue);
    s.updateFrameRangeMoveDrag(frameDelta: 2);

    final preview = s.dragPreview.value;
    expect(preview, isA<BlockMoveDragPreview>());
    final previewLayer = (preview as BlockMoveDragPreview).previewLayers[a.id]!;
    expect(previewLayer.timeline[0], isNull);
    expect(previewLayer.timeline[2], isNotNull);
    expect(previewLayer.timeline[5], isNotNull, reason: 'gap preserved');
    // The selection outline follows the previewed landing.
    expect(s.frameRangeSelection.value!.startIndex, 2);
    expect(s.frameRangeSelection.value!.endIndexExclusive, 6);
    // Repository untouched, no session notify per step.
    expect(s.layers.firstWhere((l) => l.id == a.id).timeline[0], isNotNull);
    expect(notifies, 0);

    s.endFrameRangeMoveDrag();
    expect(s.dragPreview.value, isNull);
    expect(notifies, 1);
    final moved = s.layers.firstWhere((l) => l.id == a.id);
    expect(moved.timeline[2], isNotNull);
    expect(moved.timeline[5], isNotNull);
    expect(moved.timeline[0], isNull);
    // The selection stays on the landed frames.
    expect(s.frameRangeSelection.value!.startIndex, 2);

    s.undo();
    final back = s.layers.firstWhere((l) => l.id == a.id);
    expect(back.timeline[0], isNotNull);
    expect(back.timeline[3], isNotNull);
    expect(back.timeline[2], isNull);
  });

  test('cross-layer range move carries BOTH cels, re-keys the store, one '
      'undo restores everything', () {
    final (s, a, b) = fixture();
    final frameIds = [a.timeline[0]!.frameId!, a.timeline[3]!.frameId!];
    final cut = s.requireActiveCut;
    final fromKeys = [
      for (final id in frameIds) s.brushFrameKeyForCut(cut, a.id, id),
    ];
    final toKeys = [
      for (final id in frameIds) s.brushFrameKeyForCut(cut, b.id, id),
    ];
    for (final key in fromKeys) {
      s.brushFrameStore.getOrCreateFrame(key);
    }

    s.updateFrameRangeSelectionDrag(
      layerId: a.id,
      anchorIndex: 0,
      headIndex: 3,
    );
    expect(s.beginFrameRangeMoveDrag(), isTrue);
    s.updateFrameRangeMoveDrag(frameDelta: 0, targetLayerId: b.id);
    s.endFrameRangeMoveDrag();

    expect(s.activeLayer!.id, b.id, reason: 'selection follows the frames');
    final movedA = s.layers.firstWhere((l) => l.id == a.id);
    final movedB = s.layers.firstWhere((l) => l.id == b.id);
    expect(movedA.timeline, isEmpty);
    expect(movedB.timeline[0], isNotNull);
    expect(movedB.timeline[3], isNotNull);
    for (var i = 0; i < frameIds.length; i += 1) {
      expect(s.brushFrameStore.frameOrNull(fromKeys[i]), isNull);
      expect(s.brushFrameStore.frameOrNull(toKeys[i]), isNotNull);
    }

    s.undo();
    final backA = s.layers.firstWhere((l) => l.id == a.id);
    final backB = s.layers.firstWhere((l) => l.id == b.id);
    expect(backA.timeline[0], isNotNull);
    expect(backA.timeline[3], isNotNull);
    expect(backB.timeline, isEmpty);
    for (var i = 0; i < frameIds.length; i += 1) {
      expect(s.brushFrameStore.frameOrNull(fromKeys[i]), isNotNull);
      expect(s.brushFrameStore.frameOrNull(toKeys[i]), isNull);
    }
  });

  test('a selection over a repeat GHOST clamps out of it and the move '
      'rederives the ghosts at the landing', () {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createDrawingAtCurrentFrame();
    final layerId = s.activeLayer!.id;
    // Author a repeat edge after the single 1-frame block at 0 (UI-R9
    // #10: ghosts fill to the cut end).
    s.setRunEdgeBehavior(
      layerId: layerId,
      blockStartIndex: 0,
      side: TimelineRunEdgeSide.end,
      mode: TimelineRunEdgeMode.repeat,
    );
    final layer = s.layers.firstWhere((l) => l.id == layerId);
    expect(layer.timeline[1]!.ghost, isTrue);
    expect(layer.timeline[2]!.ghost, isTrue);

    // A drag sweeping across the ghosts clamps the selection before them.
    s.updateFrameRangeSelectionDrag(
      layerId: layerId,
      anchorIndex: 0,
      headIndex: 2,
    );
    expect(s.frameRangeSelection.value!.endIndexExclusive, 1);

    // Moving the source block drags its ghosts along (live sync).
    expect(s.beginFrameRangeMoveDrag(), isTrue);
    s.updateFrameRangeMoveDrag(frameDelta: 4);
    s.endFrameRangeMoveDrag();
    final moved = s.layers.firstWhere((l) => l.id == layerId);
    expect(moved.timeline[4]!.ghost, isFalse);
    expect(moved.timeline[5]!.ghost, isTrue);
    expect(moved.timeline[6]!.ghost, isTrue);
    expect(moved.timeline.containsKey(1), isFalse);
  });
}
