import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_entry.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_history_entry_builder.dart';
import 'package:quick_animaker_v2/src/services/brush_surface_edit_builder.dart';

void main() {
  group('BrushEditSessionCommitResult', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface({int width = 4, int height = 4}) => BitmapSurface(
      canvasSize: CanvasSize(width: width, height: height),
      tileSize: 2,
    );

    BrushDab dab() => BrushDab(
      center: CanvasPoint(x: 0.5, y: 0.5),
      color: 0xFFFF0000,
      size: 1,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.round,
      pressure: 1,
      sequence: 0,
    );

    BrushEditHistoryEntry entry() {
      final edit = brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence([dab()]),
        layerId: layerId,
        frameId: frameId,
      );
      return brushEditHistoryEntryFromBrushSurfaceEdit(
        edit: edit,
        layerId: layerId,
        frameId: frameId,
      )!;
    }

    test('stores canvasState, historyState, historyEntry', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final historyEntry = entry();
      final result = BrushEditSessionCommitResult(
        canvasState: canvasState,
        historyState: historyState,
        historyEntry: historyEntry,
      );

      expect(result.canvasState, canvasState);
      expect(result.historyState, historyState);
      expect(result.historyEntry, historyEntry);
    });

    test('didCommit false when historyEntry is null', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: null,
      );

      expect(result.didCommit, isFalse);
    });

    test('didCommit true when historyEntry is non-null', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: entry(),
      );

      expect(result.didCommit, isTrue);
    });

    test('copyWith preserves omitted values', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: entry(),
      );

      expect(result.copyWith(), result);
    });

    test('copyWith updates canvasState', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: null,
      );
      final nextCanvas = CanvasSurfaceState(
        currentSurface: surface(width: 8, height: 8),
      );

      expect(result.copyWith(canvasState: nextCanvas).canvasState, nextCanvas);
    });

    test('copyWith updates historyState', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: null,
      );
      final nextHistory = BrushEditHistoryState(undoEntries: [entry()]);

      expect(
        result.copyWith(historyState: nextHistory).historyState,
        nextHistory,
      );
    });

    test('copyWith can set historyEntry', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: null,
      );
      final historyEntry = entry();

      expect(
        result.copyWith(historyEntry: historyEntry).historyEntry,
        historyEntry,
      );
    });

    test('copyWith can clear historyEntry with null', () {
      final result = BrushEditSessionCommitResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        historyEntry: entry(),
      );

      expect(result.copyWith(historyEntry: null).historyEntry, isNull);
    });

    test('equality / hashCode / toString', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyEntry = entry();
      final historyState = BrushEditHistoryState(undoEntries: [historyEntry]);
      final a = BrushEditSessionCommitResult(
        canvasState: canvasState,
        historyState: historyState,
        historyEntry: historyEntry,
      );
      final b = BrushEditSessionCommitResult(
        canvasState: canvasState,
        historyState: historyState,
        historyEntry: historyEntry,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('BrushEditSessionCommitResult'));
      expect(a.toString(), contains('historyEntry'));
    });
  });
}
