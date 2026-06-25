import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_redo_service.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_state_operations.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_undo_service.dart';

void main() {
  group('brush edit session state operations', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface() => BitmapSurface(
      canvasSize: const CanvasSize(width: 4, height: 4),
      tileSize: 2,
    );

    BrushDabSequence changedSequence() => BrushDabSequence([
      BrushDab(
        center: CanvasPoint(x: 0.5, y: 0.5),
        color: 0xFFFF0000,
        size: 1,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: 0,
      ),
    ]);

    BrushEditSessionState emptySession() => BrushEditSessionState(
      canvasState: CanvasSurfaceState(currentSurface: surface()),
      historyState: BrushEditHistoryState(),
    );

    test('commit facade returns same result as '
        'commitBrushDabSequenceToBrushEditSession', () {
      final sessionState = emptySession();
      final sequence = changedSequence();
      final direct = commitBrushDabSequenceToBrushEditSession(
        canvasState: sessionState.canvasState,
        historyState: sessionState.historyState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
      );
      final facade = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
      );

      expect(facade, direct);
    });

    test('commit facade no-op behavior matches existing commit service', () {
      final sessionState = emptySession();
      final direct = commitBrushDabSequenceToBrushEditSession(
        canvasState: sessionState.canvasState,
        historyState: sessionState.historyState,
        sequence: BrushDabSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final facade = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: BrushDabSequence(),
        layerId: layerId,
        frameId: frameId,
      );

      expect(facade, direct);
      expect(facade.didCommit, isFalse);
    });

    test('commit facade changed behavior matches existing commit service', () {
      final sessionState = emptySession();
      final sequence = changedSequence();
      final facade = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
      );

      expect(facade.didCommit, isTrue);
      expect(facade.historyState.undoEntries, [facade.historyEntry]);
      expect(facade.canvasState.hasLastEdit, isTrue);
    });

    test('undo facade returns same result as undoLatestBrushEdit', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final sessionState = sessionStateFromCommitResult(committed);
      final direct = undoLatestBrushEdit(
        canvasState: sessionState.canvasState,
        historyState: sessionState.historyState,
      );
      final facade = undoLatestBrushEditInSessionState(
        sessionState: sessionState,
      );

      expect(facade, direct);
    });

    test('undo facade no-op behavior matches existing undo service', () {
      final sessionState = emptySession();
      final facade = undoLatestBrushEditInSessionState(
        sessionState: sessionState,
      );

      expect(facade.didUndo, isFalse);
      expect(identical(facade.canvasState, sessionState.canvasState), isTrue);
      expect(identical(facade.historyState, sessionState.historyState), isTrue);
    });

    test('redo facade returns same result as redoLatestBrushEdit', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushEditInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );
      final sessionState = sessionStateFromUndoResult(undone);
      final direct = redoLatestBrushEdit(
        canvasState: sessionState.canvasState,
        historyState: sessionState.historyState,
      );
      final facade = redoLatestBrushEditInSessionState(
        sessionState: sessionState,
      );

      expect(facade, direct);
    });

    test('redo facade no-op behavior matches existing redo service', () {
      final sessionState = emptySession();
      final facade = redoLatestBrushEditInSessionState(
        sessionState: sessionState,
      );

      expect(facade.didRedo, isFalse);
      expect(identical(facade.canvasState, sessionState.canvasState), isTrue);
      expect(identical(facade.historyState, sessionState.historyState), isTrue);
    });

    test('sessionStateFromCommitResult maps canvasState and historyState', () {
      final result = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final sessionState = sessionStateFromCommitResult(result);

      expect(identical(sessionState.canvasState, result.canvasState), isTrue);
      expect(identical(sessionState.historyState, result.historyState), isTrue);
    });

    test('sessionStateFromUndoResult maps canvasState and historyState', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final result = undoLatestBrushEditInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );
      final sessionState = sessionStateFromUndoResult(result);

      expect(identical(sessionState.canvasState, result.canvasState), isTrue);
      expect(identical(sessionState.historyState, result.historyState), isTrue);
    });

    test('sessionStateFromRedoResult maps canvasState and historyState', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushEditInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );
      final result = redoLatestBrushEditInSessionState(
        sessionState: sessionStateFromUndoResult(undone),
      );
      final sessionState = sessionStateFromRedoResult(result);

      expect(identical(sessionState.canvasState, result.canvasState), isTrue);
      expect(identical(sessionState.historyState, result.historyState), isTrue);
    });

    test('commit -> sessionStateFromCommitResult -> undo works', () {
      final original = emptySession();
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: original,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushEditInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );

      expect(undone.didUndo, isTrue);
      expect(
        undone.canvasState.currentSurface,
        original.canvasState.currentSurface,
      );
      expect(undone.historyState.redoEntries, [committed.historyEntry]);
    });

    test('undo -> sessionStateFromUndoResult -> redo works', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushEditInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );
      final redone = redoLatestBrushEditInSessionState(
        sessionState: sessionStateFromUndoResult(undone),
      );

      expect(redone.didRedo, isTrue);
      expect(
        redone.canvasState.currentSurface,
        committed.canvasState.currentSurface,
      );
      expect(redone.historyState.undoEntries, [committed.historyEntry]);
    });

    test('does not mutate input BrushEditSessionState', () {
      final sessionState = emptySession();
      final snapshot = sessionState.copyWith();

      commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );

      expect(sessionState, snapshot);
    });

    test('does not mutate input CanvasSurfaceState', () {
      final sessionState = emptySession();
      final canvasState = sessionState.canvasState;

      commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );

      expect(identical(sessionState.canvasState, canvasState), isTrue);
      expect(sessionState.canvasState.currentSurface.tiles, isEmpty);
      expect(sessionState.canvasState.lastEdit, isNull);
    });

    test('does not mutate input BrushEditHistoryState', () {
      final sessionState = emptySession();
      final historyState = sessionState.historyState;

      commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );

      expect(identical(sessionState.historyState, historyState), isTrue);
      expect(sessionState.historyState.undoEntries, isEmpty);
      expect(sessionState.historyState.redoEntries, isEmpty);
    });

    test('does not execute cache invalidation', () {
      final result = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );

      expect(
        result.historyEntry!.commitResult.cacheInvalidationPlan,
        isNotNull,
      );
    });

    test('does not add UI/state management/timeline/storyboard changes', () {
      expect(commitBrushDabSequenceToBrushEditSessionState, isA<Function>());
      expect(undoLatestBrushEditInSessionState, isA<Function>());
      expect(redoLatestBrushEditInSessionState, isA<Function>());
    });
  });
}
