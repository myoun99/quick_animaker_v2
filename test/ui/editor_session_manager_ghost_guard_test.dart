import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';

/// UI-R19 #1: ghost frames (derived repeat/hold instances) are DISPLAY
/// material — no delete, no rename, no brush target. The playhead may
/// stand on them, but every editing gate stands down.
void main() {
  (EditorSessionManager, LayerId) sessionWithGhostTail() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createDrawingAtCurrentFrame();
    final layerId = s.activeLayer!.id;
    // End REPEAT: frames 1.. become derived ghost instances of frame 0.
    s.setRunEdgeBehavior(
      layerId: layerId,
      blockStartIndex: 0,
      side: TimelineRunEdgeSide.end,
      mode: TimelineRunEdgeMode.repeat,
    );
    return (s, layerId);
  }

  test('the ghost tail exists (fixture sanity)', () {
    final (s, layerId) = sessionWithGhostTail();
    final layer = s.layers.firstWhere((layer) => layer.id == layerId);
    expect(layer.timeline[1]!.ghost, isTrue);
  });

  test('delete stands down on a ghost frame (pin)', () {
    final (s, _) = sessionWithGhostTail();
    s.selectFrameIndex(0);
    expect(s.canDeleteCellAtCurrentFrame, isTrue);

    s.selectFrameIndex(2);
    expect(s.canDeleteCellAtCurrentFrame, isFalse);
  });

  test('rename stands down on a ghost frame — resolving it would rename '
      'the ANCHOR cel (UI-R19 #1)', () {
    final (s, _) = sessionWithGhostTail();
    s.selectFrameIndex(0);
    expect(s.canRenameFrameAtCurrentFrame, isTrue);

    s.selectFrameIndex(2);
    expect(s.canRenameFrameAtCurrentFrame, isFalse);
    expect(
      s.renameSelectedFrame('7'),
      isNull,
      reason: 'the guarded rename applies nothing',
    );
    final layer = s.activeLayer!;
    expect(layer.frames.single.name, isNot('7'));
  });

  test('no brush target on a ghost frame — strokes would edit the anchor '
      'cel from a derived instance (UI-R19 #1)', () {
    final (s, _) = sessionWithGhostTail();
    s.selectFrameIndex(0);
    expect(s.activeBrushEditorSelection, isNotNull);

    s.selectFrameIndex(2);
    expect(s.activeBrushEditorSelection, isNull);
  });
}
