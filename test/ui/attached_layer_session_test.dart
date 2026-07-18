import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/attached_layer_resolve.dart';
import 'package:quick_animaker_v2/src/models/attached_mode.dart';
import 'package:quick_animaker_v2/src/models/attached_placement.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart'
    show TimelineBlockEdge;
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart'
    show timelineIndexIsGhost;
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';

/// W5 attach layers through the session: creation/placement, the attach
/// cel flow (Create Drawing = cel + link), edit guards and the cascade
/// delete.
void main() {
  (EditorSessionManager, Layer) sessionWithBase() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    final base = s.activeLayer!;
    return (s, base);
  }

  List<Layer> cutLayers(EditorSessionManager s) => s.requireActiveCut.layers;

  test('addAttachedLayer places rows adjacent to the base — below before, '
      'above after — selected on creation and off the timesheet', () {
    final (s, base) = sessionWithBase();
    final baseIndexBefore = cutLayers(
      s,
    ).indexWhere((layer) => layer.id == base.id);

    expect(s.canAddAttachedLayerToActive, isTrue);
    s.addAttachedLayer(AttachedPlacement.above);
    final above = s.activeLayer!;
    expect(isAttachedLayer(above), isTrue);
    expect(above.attachedToLayerId, base.id);
    expect(above.attachedPlacement, AttachedPlacement.above);
    expect(above.kind, base.kind);
    expect(above.onTimesheet, isFalse);
    // Signed default names (UI-R20 #11): above rows count +1, +2, …
    expect(above.name, '+1');
    expect(
      cutLayers(s).indexWhere((layer) => layer.id == above.id),
      baseIndexBefore + 1,
    );

    // Adding from the attach row targets ITS base (same group); a below
    // row lands right before the base and counts its own side (-1).
    expect(s.canAddAttachedLayerToActive, isTrue);
    s.addAttachedLayer(AttachedPlacement.below);
    final below = s.activeLayer!;
    expect(below.attachedToLayerId, base.id);
    expect(below.name, '-1');
    final layers = cutLayers(s);
    final baseIndex = layers.indexWhere((layer) => layer.id == base.id);
    expect(layers[baseIndex - 1].id, below.id);
    expect(layers[baseIndex + 1].id, above.id);
  });

  test('the attach display clone shows the mirrored blocks as GHOSTS '
      '(UI-R20 #8) while the brush target still resolves through them', () {
    final (s, _) = sessionWithBase();
    s.createDrawingAtCurrentFrame();
    s.addAttachedLayer(AttachedPlacement.above);
    final attachId = s.activeLayer!.id;
    s.createDrawingAtCurrentFrame();

    final clone = s.layers.firstWhere((layer) => layer.id == attachId);
    expect(timelineIndexIsGhost(clone, 0), isTrue);
    // Anchor resolve-through (the R19b rule): the ghost cell IS the
    // attach cel — drawing lands on it.
    final cutAttach = cutLayers(s).firstWhere((l) => l.id == attachId);
    expect(s.activeBrushEditorSelection!.frameId, cutAttach.frames.single.id);
  });

  test('Create Drawing on an attach row makes a cel + link riding the '
      'base exposure; one per base cel; one undo removes it', () {
    final (s, base) = sessionWithBase();
    // Give the BASE an exposed cel at the playhead first (the default
    // layer starts empty).
    s.createDrawingAtCurrentFrame();
    s.addAttachedLayer(AttachedPlacement.above);
    final attachId = s.activeLayer!.id;

    // The base exposes a cel at frame 0 now — creatable.
    expect(s.canCreateDrawingAtCurrentFrame, isTrue);
    s.createDrawingAtCurrentFrame();

    final attached = cutLayers(s).firstWhere((layer) => layer.id == attachId);
    expect(attached.frames, hasLength(1));
    expect(attached.baseFrameLinks, hasLength(1));

    // The display clone resolves the linked cel at the playhead — the
    // brush target rides the base's exposure.
    expect(s.selectedFrame!.id, attached.frames.single.id);
    expect(s.activeBrushEditorSelection!.frameId, attached.frames.single.id);

    // The base cel is linked now: no second cel on the same exposure.
    expect(s.canCreateDrawingAtCurrentFrame, isFalse);

    // ONE undo removes cel + link together.
    s.undo();
    final restored = cutLayers(s).firstWhere((layer) => layer.id == attachId);
    expect(restored.frames, isEmpty);
    expect(restored.baseFrameLinks, isEmpty);
    expect(base.id, isNotNull); // base untouched throughout
  });

  test('a FREE attach row (UI-R21 #3) authors its own timeline like a '
      'normal drawing layer — create/cut/mark/delete/comma all live, no '
      'cell links, no ghost mirror', () {
    final (s, base) = sessionWithBase();
    s.createDrawingAtCurrentFrame(); // base cel at 0 (not required, but real)
    s.addAttachedLayer(AttachedPlacement.above, mode: AttachedMode.free);
    final attachId = s.activeLayer!.id;
    expect(
      cutLayers(s).firstWhere((l) => l.id == attachId).attachedMode,
      AttachedMode.free,
    );

    // Normal authoring path: a cel with a plain timeline entry, NO link.
    expect(s.canCreateDrawingAtCurrentFrame, isTrue);
    s.createDrawingAtCurrentFrame();
    final attached = cutLayers(s).firstWhere((l) => l.id == attachId);
    expect(attached.frames, hasLength(1));
    expect(attached.baseFrameLinks, isEmpty);
    expect(attached.timeline[0]?.isDrawing, isTrue);

    // The display list hands back the REAL layer — no clone, no ghosts.
    final display = s.layers.firstWhere((l) => l.id == attachId);
    expect(identical(display, attached), isTrue);
    expect(timelineIndexIsGhost(display, 0), isFalse);

    // Timing edits behave like any drawing layer. A COMMA DRAG stretches
    // the block to length 3 (the old attach standdown refused the begin):
    expect(
      s.beginExposureEdgeDrag(
        layerId: attachId,
        blockStartIndex: 0,
        edge: TimelineBlockEdge.end,
      ),
      isTrue,
    );
    s.updateExposureEdgeDrag(2);
    s.endExposureEdgeDrag();
    expect(
      cutLayers(s).firstWhere((l) => l.id == attachId).timeline[0]!.length,
      3,
    );

    // Breakdown marks live INSIDE a block (normal rule) and the covering
    // cel deletes from anywhere on it — both gates open now.
    s.selectFrameIndex(1);
    expect(s.canToggleMarkAtCurrentFrame, isTrue);
    expect(s.canDeleteCellAtCurrentFrame, isTrue);
    s.selectFrameIndex(0);

    // Range selection + move are open too (the synced mirror stands down
    // until the ghost-snap rework).
    s.updateFrameRangeSelectionDrag(
      layerId: attachId,
      anchorIndex: 0,
      headIndex: 0,
    );
    expect(s.frameRangeSelection.value, isNotNull);
    expect(s.beginFrameRangeMoveDrag(), isTrue);
    s.cancelFrameRangeMoveDrag();

    // Still an ATTACH row structurally: no nesting base, cascades with
    // the base's delete, and adding from it targets ITS base.
    expect(canCarryAttachedLayers(attached), isFalse);
    expect(s.canAddAttachedLayerToActive, isTrue);
  });

  test('deleting the base cascades over BOTH attach modes in one undo', () {
    final (s, base) = sessionWithBase();
    s.addAttachedLayer(AttachedPlacement.above, mode: AttachedMode.free);
    final freeId = s.activeLayer!.id;
    s.addAttachedLayer(AttachedPlacement.below);
    final syncedId = s.activeLayer!.id;

    s.selectLayer(base.id);
    s.addLayer(); // second standalone drawing layer = base deletable
    s.selectLayer(base.id);
    s.deleteActiveLayer();
    final after = cutLayers(s).map((l) => l.id).toList();
    expect(after.contains(freeId), isFalse);
    expect(after.contains(syncedId), isFalse);

    s.undo();
    final restored = cutLayers(s).map((l) => l.id).toList();
    expect(restored.contains(freeId), isTrue);
    expect(restored.contains(syncedId), isTrue);
    expect(
      cutLayers(s).firstWhere((l) => l.id == freeId).attachedMode,
      AttachedMode.free,
      reason: 'the mode survives the cascade undo',
    );
  });

  test('attach rows own no timing: exposure/mark/cell edits and comma '
      'drags stand down; kind toggles too', () {
    final (s, _) = sessionWithBase();
    s.addAttachedLayer(AttachedPlacement.above);
    s.createDrawingAtCurrentFrame();
    final attachId = s.activeLayer!.id;

    expect(s.canCutExposureAtCurrentFrame, isFalse);
    expect(s.canToggleMarkAtCurrentFrame, isFalse);
    expect(s.canDeleteCellAtCurrentFrame, isFalse);
    expect(s.canPasteLinkedFrameAtCurrentFrame, isFalse);
    expect(s.canToggleTargetLayerKind, isFalse);
    expect(
      s.beginExposureEdgeDrag(
        layerId: attachId,
        blockStartIndex: 0,
        edge: TimelineBlockEdge.end,
      ),
      isFalse,
    );
  });

  test('deleting the base cascades over its attach rows in ONE undo; the '
      'attach rows never count toward the drawing floor', () {
    final (s, base) = sessionWithBase();
    s.addAttachedLayer(AttachedPlacement.above);
    s.addAttachedLayer(AttachedPlacement.below);
    final layersBefore = cutLayers(s).map((layer) => layer.id).toList();

    // The base is the ONLY standalone drawing layer: its attach rows must
    // not satisfy the floor, so the base itself is not deletable...
    s.selectLayer(base.id);
    expect(s.canDeleteActiveLayer, isFalse);

    // ...but each attach row is (accessories are always deletable).
    final attachIds = attachedLayersOf(
      base.id,
      cutLayers(s),
    ).map((layer) => layer.id).toList();
    s.selectLayer(attachIds.first);
    expect(s.canDeleteActiveLayer, isTrue);

    // With a second standalone drawing layer, the base becomes deletable
    // and takes its attach rows with it — restored whole by ONE undo.
    s.selectLayer(base.id);
    s.addLayer(); // regular layer above the group
    s.selectLayer(base.id);
    expect(s.canDeleteActiveLayer, isTrue);
    s.deleteActiveLayer();
    final afterDelete = cutLayers(s).map((layer) => layer.id).toList();
    expect(afterDelete.contains(base.id), isFalse);
    for (final id in attachIds) {
      expect(afterDelete.contains(id), isFalse);
    }

    s.undo(); // the cascade
    final restored = cutLayers(s).map((layer) => layer.id).toList();
    expect(restored.contains(base.id), isTrue);
    for (final id in attachIds) {
      expect(restored.contains(id), isTrue);
    }
    s.undo(); // the added regular layer
    expect(cutLayers(s).map((layer) => layer.id).toList(), layersBefore);
  });

  test('adding a regular layer while an attach row is active lands ABOVE '
      'the whole group, never inside it', () {
    final (s, base) = sessionWithBase();
    s.addAttachedLayer(AttachedPlacement.above);
    final attachId = s.activeLayer!.id;

    s.addLayer();
    final added = s.activeLayer!;
    expect(isAttachedLayer(added), isFalse);

    final layers = cutLayers(s);
    final baseIndex = layers.indexWhere((layer) => layer.id == base.id);
    expect(layers[baseIndex + 1].id, attachId);
    expect(layers[baseIndex + 2].id, added.id);
  });

  test('attach rows are ineligible bases (no nesting) and non-drawing '
      'kinds cannot carry them', () {
    final (s, _) = sessionWithBase();
    s.addAttachedLayer(AttachedPlacement.above);
    // Active = attach row: adding again targets the BASE (allowed).
    expect(s.canAddAttachedLayerToActive, isTrue);

    // A camera row cannot carry attach layers.
    final camera = cutLayers(
      s,
    ).firstWhere((layer) => layer.id.value.endsWith('-camera'));
    s.selectLayer(camera.id);
    expect(s.canAddAttachedLayerToActive, isFalse);
  });
}
