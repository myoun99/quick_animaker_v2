import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_display_cache_renderer.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/canvas_color_sampler.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection.dart';
import 'package:quick_animaker_v2/src/services/commands/brush_selection_transform_history_command.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';

/// P9 backend: the in-place dab rewrite (store + coordinator) and the
/// app-level selection-transform undo command.
void main() {
  const canvasSize = CanvasSize(width: 16, height: 16);

  BrushFrameKey key(String frameId) => BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: const LayerId('layer'),
    frameId: FrameId(frameId),
  );

  BrushFrameEditingCoordinator coordinator() => BrushFrameEditingCoordinator(
    initialFrameKey: key('frame-a'),
    frameStore: BrushFrameStore(),
    sessionStore: BrushFrameEditSessionStore(
      canvasSize: canvasSize,
      tileSize: 8,
    ),
    historyPolicy: const BrushHistoryPolicy(
      userUndoLimit: 8,
      deferredBakeRatio: 0,
    ),
  );

  BrushDab dab(double x, double y, {int color = 0xFFFF0000}) => BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: color,
    size: 2,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 0,
  );

  /// The committed frame's pixels replayed through the display renderer —
  /// what every composite route shows.
  int? pixelAt(BrushFrameEditingCoordinator c, int x, int y) {
    final drawing = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    final surface = BrushFrameDisplayCacheRenderer(
      canvasSize: canvasSize,
    ).rebuildPreview(drawing);
    return surfacePixelRgba(surface, x, y);
  }

  test('store rewrite is in place: same ids, same z-order, revision bump', () {
    final c = coordinator();
    final first = c.commitSourceStroke(sourceDabs: [dab(2, 2)])!;
    final second = c.commitSourceStroke(sourceDabs: [dab(10, 10)])!;
    final before = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    final revisionBefore = before.sourceRevision;

    c.frameStore.replacePaintCommandDabs(c.activeFrameKey, {
      first.id: translateDabs(first.sourceDabs, dx: 4, dy: 0),
    });

    final after = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(after.visibleActivePaintCommands.map((cmd) => cmd.id), [
      first.id,
      second.id,
    ]);
    expect(
      after.commandById(first.id)!.sourceDabs.single.center,
      CanvasPoint(x: 6, y: 2),
    );
    expect(
      after.commandById(second.id)!.sourceDabs,
      second.sourceDabs,
      reason: 'untouched commands keep their dabs',
    );
    expect(after.sourceRevision, greaterThan(revisionBefore));
  });

  test('coordinator rewrite moves the committed pixels', () {
    final c = coordinator();
    final stroke = c.commitSourceStroke(sourceDabs: [dab(2, 2)])!;
    expect(pixelAt(c, 2, 2), isNot(0));
    expect(pixelAt(c, 10, 2), 0);

    c.rewritePaintCommandDabs({
      stroke.id: translateDabs(stroke.sourceDabs, dx: 8, dy: 0),
    });

    expect(pixelAt(c, 2, 2), 0);
    expect(pixelAt(c, 10, 2), isNot(0));
    // The session surface matches the replay (the donation path).
    expect(c.frameStore.validPreviewSurfaceOrNull(c.activeFrameKey), isNotNull);
  });

  test('older stroke undo still works after a rewrite (replay fallback)', () {
    final c = coordinator();
    final first = c.commitSourceStroke(sourceDabs: [dab(2, 2)])!;
    c.commitSourceStroke(sourceDabs: [dab(12, 12, color: 0xFF00FF00)]);

    c.rewritePaintCommandDabs({
      first.id: translateDabs(first.sourceDabs, dx: 4, dy: 0),
    });

    // Undo the SECOND stroke: the materialization history was reset by the
    // rewrite, so this exercises the replay fallback — the moved first
    // stroke must survive at its new position.
    c.undo();
    expect(pixelAt(c, 12, 12), 0);
    expect(pixelAt(c, 6, 2), isNot(0));

    c.redo();
    expect(pixelAt(c, 12, 12), isNot(0));
    expect(pixelAt(c, 6, 2), isNot(0));
  });

  test('the history command round-trips exactly through the app stack', () {
    final c = coordinator();
    final history = HistoryManager();
    final stroke = c.commitSourceStroke(sourceDabs: [dab(2, 2)])!;
    final originalDabs = stroke.sourceDabs;

    history.execute(
      BrushSelectionTransformHistoryCommand(
        coordinator: c,
        frameKey: c.activeFrameKey,
        before: {stroke.id: originalDabs},
        after: {stroke.id: translateDabs(originalDabs, dx: 5, dy: 3)},
      ),
    );
    expect(pixelAt(c, 7, 5), isNot(0));
    expect(pixelAt(c, 2, 2), 0);

    history.undo();
    expect(
      c.frameStore
          .getOrCreateFrame(c.activeFrameKey)
          .commandById(stroke.id)!
          .sourceDabs,
      originalDabs,
      reason: 'undo restores the EXACT original dab payload',
    );
    expect(pixelAt(c, 2, 2), isNot(0));

    history.redo();
    expect(pixelAt(c, 7, 5), isNot(0));
  });

  test('undo targets the recorded frame even after the playhead moved', () {
    final c = coordinator();
    final history = HistoryManager();
    final stroke = c.commitSourceStroke(sourceDabs: [dab(2, 2)])!;
    final frameA = c.activeFrameKey;

    history.execute(
      BrushSelectionTransformHistoryCommand(
        coordinator: c,
        frameKey: frameA,
        before: {stroke.id: stroke.sourceDabs},
        after: {stroke.id: translateDabs(stroke.sourceDabs, dx: 5, dy: 0)},
      ),
    );

    c.selectFrame(key('frame-b'));
    history.undo();

    expect(
      c.frameStore.getOrCreateFrame(frameA).commandById(stroke.id)!.sourceDabs,
      stroke.sourceDabs,
    );
    expect(
      c.frameStore.getOrCreateFrame(key('frame-b')).visibleActivePaintCommands,
      isEmpty,
      reason: 'the other frame stays untouched',
    );
  });
}
