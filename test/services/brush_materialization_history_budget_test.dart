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
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/brush_materialization_history_budget.dart';

/// Bitmap undo snapshots are BYTE-budgeted (the count limit alone is
/// unbounded in bytes — a full-canvas stroke at 5000² pins ~100MB). The
/// deepest entries drop first; undoing past them takes the command-replay
/// fallback, so nothing is ever lost — deep undo just gets slower.
void main() {
  const canvasSize = CanvasSize(width: 8, height: 8);
  // tileSize 4 → one changed tile ≈ 4·4·4 = 64 bytes.
  const tileBytes = 4 * 4 * 4;

  BrushFrameKey key() => BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: const LayerId('layer'),
    frameId: const FrameId('frame'),
  );

  BrushFrameEditingCoordinator coordinator({
    int materializationByteBudget =
        BrushHistoryPolicy.defaultMaterializationByteBudget,
  }) {
    return BrushFrameEditingCoordinator(
      initialFrameKey: key(),
      frameStore: BrushFrameStore(),
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: canvasSize,
        tileSize: 4,
      ),
      historyPolicy: BrushHistoryPolicy(
        userUndoLimit: 8,
        deferredBakeRatio: 0,
        materializationByteBudget: materializationByteBudget,
      ),
    );
  }

  BrushDab dab(double x, double y) => BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: 0xFF000000,
    size: 2,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: 0,
  );

  int alphaAt(BrushFrameEditingCoordinator c, int x, int y) {
    final surface = c.activeSessionState.canvasState.currentSurface;
    final tileSize = surface.tileSize;
    final tile = surface.tileAt(TileCoord(x: x ~/ tileSize, y: y ~/ tileSize));
    if (tile == null) {
      return 0;
    }
    return tile.pixels[tile.byteOffsetForPixel(x: x % tileSize, y: y % tileSize) +
        3];
  }

  test('trim drops the DEEPEST undo entries first and keeps the newest '
      'even when it alone exceeds the budget', () {
    final c = coordinator();
    c.commitSourceStroke(sourceDabs: [dab(1, 1)]);
    c.commitSourceStroke(sourceDabs: [dab(5, 1)]);
    c.commitSourceStroke(sourceDabs: [dab(1, 5)]);
    final state = c.activeSessionState.materializationHistoryState;
    expect(state.undoCount, 3);

    // Under budget: the exact same state comes back.
    expect(
      identical(
        trimMaterializationHistoryToByteBudget(
          state,
          maxBytes: 3 * tileBytes,
        ),
        state,
      ),
      isTrue,
    );

    // Room for two: the deepest (first) entry drops, stack top intact.
    final two = trimMaterializationHistoryToByteBudget(
      state,
      maxBytes: 2 * tileBytes,
    );
    expect(two.undoCount, 2);
    expect(two.latestUndoEntry, state.latestUndoEntry);

    // Budget below a single entry: the newest one is still kept.
    final one = trimMaterializationHistoryToByteBudget(state, maxBytes: 1);
    expect(one.undoCount, 1);
    expect(one.latestUndoEntry, state.latestUndoEntry);
  });

  test('redo entries trim from the furthest-future end after undo depth', () {
    final c = coordinator();
    c.commitSourceStroke(sourceDabs: [dab(1, 1)]);
    c.commitSourceStroke(sourceDabs: [dab(5, 1)]);
    c.undo();
    c.undo();
    final state = c.activeSessionState.materializationHistoryState;
    expect(state.undoCount, 0);
    expect(state.redoCount, 2);

    final trimmed = trimMaterializationHistoryToByteBudget(
      state,
      maxBytes: tileBytes,
    );
    expect(trimmed.redoCount, 1);
    // The list front (furthest redo) dropped; the next redo stays aligned.
    expect(trimmed.latestRedoEntry, state.latestRedoEntry);
  });

  test('commits enforce the budget and deep undo falls back to the '
      'command replay — nothing is lost', () {
    // Budget below one entry: only the newest snapshot survives each commit.
    final c = coordinator(materializationByteBudget: 1);
    c.commitSourceStroke(sourceDabs: [dab(1, 1)]);
    c.commitSourceStroke(sourceDabs: [dab(5, 1)]);
    c.commitSourceStroke(sourceDabs: [dab(1, 5)]);

    expect(c.activeSessionState.materializationHistoryState.undoCount, 1);
    expect(alphaAt(c, 1, 1), greaterThan(0));
    expect(alphaAt(c, 5, 1), greaterThan(0));
    expect(alphaAt(c, 1, 5), greaterThan(0));

    // Undo 1 rides the kept snapshot; undos 2 and 3 replay from commands.
    c.undo();
    expect(alphaAt(c, 1, 5), 0);
    expect(alphaAt(c, 5, 1), greaterThan(0));
    c.undo();
    expect(alphaAt(c, 5, 1), 0);
    expect(alphaAt(c, 1, 1), greaterThan(0));
    c.undo();
    expect(alphaAt(c, 1, 1), 0);

    // Redo all three back.
    c.redo();
    expect(alphaAt(c, 1, 1), greaterThan(0));
    c.redo();
    expect(alphaAt(c, 5, 1), greaterThan(0));
    c.redo();
    expect(alphaAt(c, 1, 5), greaterThan(0));
  });

  test('the default budget leaves ordinary histories untouched', () {
    final c = coordinator();
    for (var index = 0; index < 6; index += 1) {
      c.commitSourceStroke(sourceDabs: [dab(1.0 + index, 1)]);
    }
    expect(c.activeSessionState.materializationHistoryState.undoCount, 6);
  });
}
