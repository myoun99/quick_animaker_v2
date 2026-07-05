import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_bitmap_materialization_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/services/brush_bitmap_materialization_redo_service.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_state_operations.dart';
import 'package:quick_animaker_v2/src/services/brush_bitmap_materialization_undo_service.dart';

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
      materializationHistoryState: BrushBitmapMaterializationHistoryState(),
    );

    test('commit facade returns same result as '
        'commitBrushDabSequenceToBrushEditSession', () {
      final sessionState = emptySession();
      final sequence = changedSequence();
      final direct = commitBrushDabSequenceToBrushEditSession(
        canvasState: sessionState.canvasState,
        materializationHistoryState: sessionState.materializationHistoryState,
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
        materializationHistoryState: sessionState.materializationHistoryState,
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
      expect(facade.materializationHistoryState.undoEntries, [
        facade.historyEntry,
      ]);
      expect(facade.canvasState.hasLastEdit, isTrue);
    });

    test(
      'undo facade returns same result as undoLatestBrushBitmapMaterialization',
      () {
        final committed = commitBrushDabSequenceToBrushEditSessionState(
          sessionState: emptySession(),
          sequence: changedSequence(),
          layerId: layerId,
          frameId: frameId,
        );
        final sessionState = sessionStateFromCommitResult(committed);
        final direct = undoLatestBrushBitmapMaterialization(
          canvasState: sessionState.canvasState,
          materializationHistoryState: sessionState.materializationHistoryState,
        );
        final facade = undoLatestBrushBitmapMaterializationInSessionState(
          sessionState: sessionState,
        );

        expect(facade, direct);
      },
    );

    test('undo facade no-op behavior matches existing undo service', () {
      final sessionState = emptySession();
      final facade = undoLatestBrushBitmapMaterializationInSessionState(
        sessionState: sessionState,
      );

      expect(facade.didApply, isFalse);
      expect(identical(facade.canvasState, sessionState.canvasState), isTrue);
      expect(
        identical(
          facade.materializationHistoryState,
          sessionState.materializationHistoryState,
        ),
        isTrue,
      );
    });

    test(
      'redo facade returns same result as redoLatestBrushBitmapMaterialization',
      () {
        final committed = commitBrushDabSequenceToBrushEditSessionState(
          sessionState: emptySession(),
          sequence: changedSequence(),
          layerId: layerId,
          frameId: frameId,
        );
        final undone = undoLatestBrushBitmapMaterializationInSessionState(
          sessionState: sessionStateFromCommitResult(committed),
        );
        final sessionState = sessionStateFromStepResult(undone);
        final direct = redoLatestBrushBitmapMaterialization(
          canvasState: sessionState.canvasState,
          materializationHistoryState: sessionState.materializationHistoryState,
        );
        final facade = redoLatestBrushBitmapMaterializationInSessionState(
          sessionState: sessionState,
        );

        expect(facade, direct);
      },
    );

    test('redo facade no-op behavior matches existing redo service', () {
      final sessionState = emptySession();
      final facade = redoLatestBrushBitmapMaterializationInSessionState(
        sessionState: sessionState,
      );

      expect(facade.didApply, isFalse);
      expect(identical(facade.canvasState, sessionState.canvasState), isTrue);
      expect(
        identical(
          facade.materializationHistoryState,
          sessionState.materializationHistoryState,
        ),
        isTrue,
      );
    });

    test(
      'sessionStateFromCommitResult maps canvasState and materializationHistoryState',
      () {
        final result = commitBrushDabSequenceToBrushEditSessionState(
          sessionState: emptySession(),
          sequence: changedSequence(),
          layerId: layerId,
          frameId: frameId,
        );
        final sessionState = sessionStateFromCommitResult(result);

        expect(identical(sessionState.canvasState, result.canvasState), isTrue);
        expect(
          identical(
            sessionState.materializationHistoryState,
            result.materializationHistoryState,
          ),
          isTrue,
        );
      },
    );

    test(
      'sessionStateFromStepResult maps canvasState and materializationHistoryState',
      () {
        final committed = commitBrushDabSequenceToBrushEditSessionState(
          sessionState: emptySession(),
          sequence: changedSequence(),
          layerId: layerId,
          frameId: frameId,
        );
        final result = undoLatestBrushBitmapMaterializationInSessionState(
          sessionState: sessionStateFromCommitResult(committed),
        );
        final sessionState = sessionStateFromStepResult(result);

        expect(identical(sessionState.canvasState, result.canvasState), isTrue);
        expect(
          identical(
            sessionState.materializationHistoryState,
            result.materializationHistoryState,
          ),
          isTrue,
        );
      },
    );

    test(
      'sessionStateFromStepResult maps canvasState and materializationHistoryState',
      () {
        final committed = commitBrushDabSequenceToBrushEditSessionState(
          sessionState: emptySession(),
          sequence: changedSequence(),
          layerId: layerId,
          frameId: frameId,
        );
        final undone = undoLatestBrushBitmapMaterializationInSessionState(
          sessionState: sessionStateFromCommitResult(committed),
        );
        final result = redoLatestBrushBitmapMaterializationInSessionState(
          sessionState: sessionStateFromStepResult(undone),
        );
        final sessionState = sessionStateFromStepResult(result);

        expect(identical(sessionState.canvasState, result.canvasState), isTrue);
        expect(
          identical(
            sessionState.materializationHistoryState,
            result.materializationHistoryState,
          ),
          isTrue,
        );
      },
    );

    test('commit -> sessionStateFromCommitResult -> undo works', () {
      final original = emptySession();
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: original,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushBitmapMaterializationInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );

      expect(undone.didApply, isTrue);
      expect(
        undone.canvasState.currentSurface,
        original.canvasState.currentSurface,
      );
      expect(undone.materializationHistoryState.redoEntries, [
        committed.historyEntry,
      ]);
    });

    test('undo -> sessionStateFromStepResult -> redo works', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushBitmapMaterializationInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );
      final redone = redoLatestBrushBitmapMaterializationInSessionState(
        sessionState: sessionStateFromStepResult(undone),
      );

      expect(redone.didApply, isTrue);
      expect(
        redone.canvasState.currentSurface,
        committed.canvasState.currentSurface,
      );
      expect(redone.materializationHistoryState.undoEntries, [
        committed.historyEntry,
      ]);
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

    test('does not mutate input BrushBitmapMaterializationHistoryState', () {
      final sessionState = emptySession();
      final materializationHistoryState =
          sessionState.materializationHistoryState;

      commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );

      expect(
        identical(
          sessionState.materializationHistoryState,
          materializationHistoryState,
        ),
        isTrue,
      );
      expect(sessionState.materializationHistoryState.undoEntries, isEmpty);
      expect(sessionState.materializationHistoryState.redoEntries, isEmpty);
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
      expect(
        undoLatestBrushBitmapMaterializationInSessionState,
        isA<Function>(),
      );
      expect(
        redoLatestBrushBitmapMaterializationInSessionState,
        isA<Function>(),
      );
    });
  });
}
