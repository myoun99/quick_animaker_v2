import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/layer_blend_mode.dart';
import 'package:quick_animaker_v2/src/models/layer_folder.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_layer_stack_view.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';

/// The EDITING canvas composites the same tree playback does, so a folder
/// buffer looks the same while you draw as it will when you play.
///
/// The one exception is stated in the split's own contract and pinned
/// here: the folder that CONTAINS the active layer cannot buffer while the
/// canvas paints in three sibling widgets, so it alone folds per member.
void main() {
  EditorSessionManager sessionWithFolder({
    LayerBlendMode blend = LayerBlendMode.passThrough,
    double opacity = 1,
  }) {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(s.dispose);
    s.createDrawingAtCurrentFrame();
    s.groupActiveLayerIntoFolder();
    final folderId = s.activeCutOrNull!.layers.folderLayers.single.id;
    if (blend != LayerBlendMode.passThrough) {
      s.setLayerBlendMode(folderId, blend);
    }
    if (opacity != 1) {
      s.setLayerOpacity(layerId: folderId, opacity: opacity);
    }
    return s;
  }

  int countGroups(List<CanvasLayerStackNode> nodes) {
    var total = 0;
    for (final node in nodes) {
      if (node is CanvasLayerGroupNode) {
        total += 1 + countGroups(node.children);
      }
    }
    return total;
  }

  bool holdsActive(List<CanvasLayerStackNode> nodes) => nodes.any(
    (node) =>
        node is CanvasActiveLayerNode ||
        (node is CanvasLayerGroupNode && holdsActive(node.children)),
  );

  test('a PASS-THROUGH folder produces no group node on the editing canvas '
      'either — an organizing folder costs nothing anywhere', () {
    final s = sessionWithFolder();
    expect(countGroups(s.editingCanvasStack.nodes), 0);
  });

  test('the ACTIVE layer stands in the tree as its own node', () {
    final s = sessionWithFolder();
    expect(
      holdsActive(s.editingCanvasStack.nodes),
      isTrue,
      reason: 'the merged painter needs a place to draw the live surface',
    );
  });

  test('a group NOT containing the active layer survives the split intact', () {
    final s = sessionWithFolder();
    // Fold the folder's member away from the selection: select a row
    // outside it, so the group sits wholly below/above the active layer.
    final cut = s.activeCutOrNull!;
    final outside = cut.layers.firstWhere(
      (layer) => layer.folderId == null && layer.id != s.activeLayerId,
    );
    final folderId = cut.layers.folderLayers.single.id;
    s.setLayerBlendMode(folderId, LayerBlendMode.multiply);
    s.selectLayer(outside.id);

    final split = s.editingCanvasStackSplit;
    expect(
      countGroups(split.below) + countGroups(split.above),
      1,
      reason: 'the buffer is whole on one side of the interactive view',
    );
  });

  test('the group that CONTAINS the active layer folds instead — the one '
      'honest gap, and it is scoped to that folder alone', () {
    final s = sessionWithFolder(blend: LayerBlendMode.multiply);
    // The active layer is the folder's member.
    expect(holdsActive(s.editingCanvasStack.nodes), isTrue);
    expect(
      countGroups(s.editingCanvasStack.nodes),
      1,
      reason: 'the TREE still has the buffer — playback and export use it',
    );

    final split = s.editingCanvasStackSplit;
    expect(
      countGroups(split.below) + countGroups(split.above),
      0,
      reason: 'the split cannot span the interactive view, so it folds',
    );
  });
}
