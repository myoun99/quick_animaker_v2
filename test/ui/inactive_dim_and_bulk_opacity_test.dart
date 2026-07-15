import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';

/// R2 lighttable dim + numeric bulk opacity (session view state / bulk
/// setter). The dim is DISPLAY-only: it scales non-active stack layers in
/// [editingCanvasStack]; export/thumbnail paths never read it.
void main() {
  EditorSessionManager session() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(s.dispose);
    return s;
  }

  test('inactive dim scales non-active stack layers only, in the editing '
      'canvas display', () {
    final s = session();
    // Pick an active drawing layer that has other drawing layers to stack.
    final drawings = s.layers
        .where((layer) => layer.kind == LayerKind.animation)
        .toList();
    // The default project has one cel; add another so the stack is non-empty.
    s.addLayerOfKind(LayerKind.animation);
    final active = s.activeLayerId;
    expect(active, isNotNull);

    final before = s.editingCanvasStack;
    final beforeBelowAbove = [...before.below, ...before.above];

    s.setInactiveDimStrength(0.5);
    expect(s.inactiveDimStrength, 0.5);

    final after = s.editingCanvasStack;
    final afterBelowAbove = [...after.below, ...after.above];

    // Same number of non-active requests, each at half the opacity.
    expect(afterBelowAbove.length, beforeBelowAbove.length);
    for (var i = 0; i < afterBelowAbove.length; i += 1) {
      expect(
        afterBelowAbove[i].opacity,
        moreOrLessEquals(beforeBelowAbove[i].opacity * 0.5, epsilon: 1e-9),
      );
    }
    // The active layer's own opacity is NOT dimmed.
    expect(after.activeLayerOpacity, before.activeLayerOpacity);
    // Keep a reference to the drawings list to avoid an unused warning.
    expect(drawings, isNotEmpty);
  });

  test('setAllLayersOpacity sets every non-camera layer', () {
    final s = session();
    s.setAllLayersOpacity(0.4);
    for (final layer in s.layers) {
      if (layer.kind != LayerKind.camera) {
        expect(layer.opacity, moreOrLessEquals(0.4, epsilon: 1e-9));
      }
    }
    s.resetAllLayersOpacity();
    for (final layer in s.layers) {
      if (layer.kind != LayerKind.camera) {
        expect(layer.opacity, 1.0);
      }
    }
  });

  test('dim clamps and no-ops when unchanged', () {
    final s = session();
    var notifies = 0;
    s.addListener(() => notifies += 1);
    s.setInactiveDimStrength(2.0);
    expect(s.inactiveDimStrength, 1.0);
    final afterFirst = notifies;
    s.setInactiveDimStrength(1.0);
    expect(notifies, afterFirst, reason: 'same value = no notify');
  });
}
