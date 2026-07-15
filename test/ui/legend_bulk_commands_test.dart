import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/layer_mark.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_section_policy.dart';

/// The rail legend's bulk commands (R-toolbar round): project-state sweeps
/// (sheet/mark/fill-ref) land as ONE undo entry; the view-ish sweeps
/// (eye/mute/fx/opacity) mirror their per-row toggles.
void main() {
  EditorSessionManager session() {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(s.dispose);
    return s;
  }

  test('setAllLayersOnTimesheet flips every cut-owned layer in ONE undo', () {
    final s = session();
    final before = [for (final layer in s.activeCut.layers) layer.onTimesheet];
    expect(before, contains(true), reason: 'fixture has sheet-on layers');

    s.setAllLayersOnTimesheet(false);
    expect(s.activeCut.layers.every((layer) => !layer.onTimesheet), isTrue);

    s.undo();
    expect([for (final layer in s.activeCut.layers) layer.onTimesheet], before);
  });

  test('clearAllLayerMarks clears in one undo and no-ops when markless', () {
    final s = session();
    final markedId = s.activeCut.layers
        .firstWhere((layer) => layer.kind == LayerKind.animation)
        .id;
    s.setLayerMark(markedId, LayerMark.red);
    final undosAfterMark = s.canUndo;
    expect(undosAfterMark, isTrue);

    s.clearAllLayerMarks();
    expect(s.layers.every((layer) => layer.mark == LayerMark.none), isTrue);
    s.undo();
    expect(
      s.layers.firstWhere((layer) => layer.id == markedId).mark,
      LayerMark.red,
    );

    // A markless sweep adds no history: clearing twice then undoing ONCE
    // returns to the marked state (the second clear was a no-op).
    s.clearAllLayerMarks();
    s.clearAllLayerMarks();
    s.undo();
    expect(
      s.layers.firstWhere((layer) => layer.id == markedId).mark,
      LayerMark.red,
    );
  });

  test('visibility sweeps: hide all, show all, solo active', () {
    final s = session();
    s.setAllLayersVisibility(false);
    expect(s.layers.every((layer) => !layer.isVisible), isTrue);

    s.setAllLayersVisibility(true);
    expect(s.layers.every((layer) => layer.isVisible), isTrue);

    final activeId = s.activeLayerId!;
    s.soloActiveLayerVisibility();
    for (final layer in s.layers) {
      expect(layer.isVisible, layer.id == activeId);
    }
  });

  test('fx bulk bypass/restore rides the session view state', () {
    final s = session();
    expect(s.layers.every((layer) => s.isLayerFxEnabled(layer.id)), isTrue);

    s.setAllLayersFxBypassed(true);
    expect(s.layers.every((layer) => !s.isLayerFxEnabled(layer.id)), isTrue);

    s.setAllLayersFxBypassed(false);
    expect(s.layers.every((layer) => s.isLayerFxEnabled(layer.id)), isTrue);
  });

  test('SE mute sweep touches only SE layers', () {
    final s = session();
    s.setAllSeLayersMuted(true);
    for (final layer in s.layers) {
      if (layer.kind == LayerKind.se) {
        expect(layer.muted, isTrue);
      } else {
        expect(layer.muted, isFalse);
      }
    }
    s.setAllSeLayersMuted(false);
    expect(s.layers.every((layer) => !layer.muted), isTrue);
  });

  test('section visibility sweep hides one section only', () {
    final s = session();
    s.setSectionLayersVisibility(TimelineSection.se, false);
    for (final layer in s.layers) {
      final inSe =
          timelineSectionForLayerKind(layer.kind) == TimelineSection.se;
      expect(layer.isVisible, !inSe);
    }
  });

  test('resetAllLayersOpacity restores 1.0 for non-camera layers', () {
    final s = session();
    final target = s.layers
        .firstWhere((layer) => layer.kind != LayerKind.camera)
        .id;
    s.setLayerOpacity(layerId: target, opacity: 0.4);
    s.resetAllLayersOpacity();
    for (final layer in s.layers) {
      if (layer.kind != LayerKind.camera) {
        expect(layer.opacity, 1.0);
      }
    }
  });
}
