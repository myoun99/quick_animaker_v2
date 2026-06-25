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
import 'package:quick_animaker_v2/src/services/brush_edit_session_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_undo_service.dart';

void main() {
  group('BrushEditSessionState', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface({int width = 4, int height = 4}) => BitmapSurface(
      canvasSize: CanvasSize(width: width, height: height),
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

    test('stores canvasState and historyState', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final state = BrushEditSessionState(
        canvasState: canvasState,
        historyState: historyState,
      );

      expect(state.canvasState, canvasState);
      expect(state.historyState, historyState);
    });

    test('canUndo delegates to historyState.canUndo', () {
      final committed = commitBrushDabSequenceToBrushEditSession(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final state = BrushEditSessionState(
        canvasState: committed.canvasState,
        historyState: committed.historyState,
      );

      expect(state.canUndo, committed.historyState.canUndo);
      expect(state.canUndo, isTrue);
    });

    test('canRedo delegates to historyState.canRedo', () {
      final committed = commitBrushDabSequenceToBrushEditSession(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushEdit(
        canvasState: committed.canvasState,
        historyState: committed.historyState,
      );
      final state = BrushEditSessionState(
        canvasState: undone.canvasState,
        historyState: undone.historyState,
      );

      expect(state.canRedo, undone.historyState.canRedo);
      expect(state.canRedo, isTrue);
    });

    test('hasLastEdit delegates to canvasState.hasLastEdit', () {
      final committed = commitBrushDabSequenceToBrushEditSession(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final state = BrushEditSessionState(
        canvasState: committed.canvasState,
        historyState: committed.historyState,
      );

      expect(state.hasLastEdit, committed.canvasState.hasLastEdit);
      expect(state.hasLastEdit, isTrue);
    });

    test('copyWith preserves omitted values', () {
      final state = BrushEditSessionState(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
      );

      expect(state.copyWith(), state);
    });

    test('copyWith updates canvasState', () {
      final state = BrushEditSessionState(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
      );
      final nextCanvas = CanvasSurfaceState(
        currentSurface: surface(width: 8, height: 8),
      );

      expect(state.copyWith(canvasState: nextCanvas).canvasState, nextCanvas);
      expect(
        state.copyWith(canvasState: nextCanvas).historyState,
        state.historyState,
      );
    });

    test('copyWith updates historyState', () {
      final committed = commitBrushDabSequenceToBrushEditSession(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final state = BrushEditSessionState(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
      );

      expect(
        state.copyWith(historyState: committed.historyState).historyState,
        committed.historyState,
      );
      expect(
        state.copyWith(historyState: committed.historyState).canvasState,
        state.canvasState,
      );
    });

    test('equality / hashCode / toString', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final a = BrushEditSessionState(
        canvasState: canvasState,
        historyState: historyState,
      );
      final b = BrushEditSessionState(
        canvasState: canvasState,
        historyState: historyState,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('BrushEditSessionState'));
      expect(a.toString(), contains('canvasState'));
      expect(a.toString(), contains('historyState'));
    });
  });
}
