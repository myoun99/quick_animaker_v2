import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('brush TileDelta eradication guard', () {
    test('TileDelta model files do not exist', () {
      expect(File('lib/src/models/tile_delta.dart').existsSync(), isFalse);
      expect(
        File('lib/src/models/tile_delta_command.dart').existsSync(),
        isFalse,
      );
    });

    test('production brush runtime files do not contain TileDeltaCommand', () {
      final files = Directory('lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) {
            final path = file.path.replaceAll('\\', '/');
            return path.contains('/models/brush') ||
                path.contains('/services/brush') ||
                path.contains('/ui/brush') ||
                path.contains('/ui/canvas/');
          })
          .toList();

      for (final file in files) {
        final text = file.readAsStringSync();
        expect(
          text,
          isNot(contains('TileDeltaCommand')),
          reason: '${file.path} must not use TileDeltaCommand.',
        );
        expect(
          text,
          isNot(contains("tile_delta_command.dart")),
          reason: '${file.path} must not import tile_delta_command.dart.',
        );
      }
    });

    test(
      'production brush runtime keeps user undo source-of-truth boundaries',
      () {
        final runtimeFiles = Directory('lib/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList();

        for (final file in runtimeFiles) {
          final path = file.path.replaceAll('\\', '/');
          final text = file.readAsStringSync();
          for (final forbidden in [
            'BrushEditHistoryState',
            'BrushEditHistoryEntry',
            'BrushEditUndoResult',
            'BrushEditRedoResult',
            'undoLatestBrushEdit',
            'redoLatestBrushEdit',
            'TileDelta',
            'TileDeltaCommand',
            'fromTileDeltaCommand',
          ]) {
            expect(
              text,
              isNot(contains(forbidden)),
              reason:
                  '$path must not restore legacy brush history/source-of-truth boundary $forbidden.',
            );
          }
        }
      },
    );

    test('UI-facing files do not import or call materialization undo routes', () {
      final uiFiles = Directory('lib/src/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      for (final file in uiFiles) {
        final path = file.path.replaceAll('\\', '/');
        final text = file.readAsStringSync();
        for (final forbidden in [
          'brush_bitmap_materialization_undo_service.dart',
          'brush_bitmap_materialization_redo_service.dart',
          'brush_bitmap_materialization_history_state.dart',
          'undoLatestBrushBitmapMaterialization',
          'redoLatestBrushBitmapMaterialization',
          'materializationHistoryState.undoEntries',
          'materializationHistoryState.redoEntries',
        ]) {
          expect(
            text,
            isNot(contains(forbidden)),
            reason:
                '$path must route UI-facing undo/redo through BrushFrameEditingCoordinator, not $forbidden.',
          );
        }
      }
    });

    test(
      'main-canvas brush route stays behind public coordinator undo boundary',
      () {
        final host = File(
          'lib/src/ui/brush/main_canvas_brush_host.dart',
        ).readAsStringSync();
        final panel = File(
          'lib/src/ui/brush/brush_canvas_panel.dart',
        ).readAsStringSync();
        final coordinator = File(
          'lib/src/services/brush_frame_editing_coordinator.dart',
        ).readAsStringSync();

        expect(host, contains('BrushFrameEditingCoordinator'));
        expect(panel, contains('applyBrushOperationResult'));
        expect(coordinator, contains('UndoPayloadRef.paintCommand'));
        expect(coordinator, contains('frameStore.addLivePaintCommand'));
        expect(
          coordinator,
          contains('frameStore.markPaintCommandHiddenByUndo'),
        );
        expect(coordinator, contains('frameStore.restorePaintCommandFromUndo'));

        for (final text in [host, panel]) {
          expect(
            text,
            isNot(contains('undoLatestBrushBitmapMaterialization')),
            reason:
                'UI-facing active-frame display routes must not call internal materialization undo.',
          );
          expect(
            text,
            isNot(contains('redoLatestBrushBitmapMaterialization')),
            reason:
                'UI-facing active-frame display routes must not call internal materialization redo.',
          );
        }
      },
    );

    test('Frame model remains lightweight and does not own brush payloads', () {
      final frameSource = File('lib/src/models/frame.dart').readAsStringSync();

      for (final forbidden in [
        'BitmapSurface',
        'BrushFrameStore',
        'BrushPaintCommand',
        'BrushFrameDrawingState',
        'BrushCommitResult',
        'inactivePreviewCache',
        'playbackPreviewCache',
        'bakedBaseSurface',
        'livePaintCommands',
        'hiddenByUndoPaintCommands',
        'deferredBakePaintCommands',
        'dirtyFlags',
        'cacheDirtyTiles',
        'inactivePreviewDirty',
      ]) {
        expect(
          frameSource,
          isNot(contains(forbidden)),
          reason: 'Frame must stay lightweight and must not own $forbidden.',
        );
      }
    });

    test(
      'HomePage main canvas mounts production brush host without preview toggle',
      () {
        final homePageSource = File(
          'lib/src/ui/home_page.dart',
        ).readAsStringSync();

        expect(homePageSource, contains('MainCanvasBrushHost'));
        expect(homePageSource, contains('_activeBrushEditorSelection'));
        expect(homePageSource, contains('main-canvas-brush-host-container'));
        expect(homePageSource, isNot(contains('Brush Host Preview')));
        expect(
          homePageSource,
          isNot(contains('_showMainCanvasBrushHostPreview')),
        );
        expect(homePageSource, isNot(contains('main-canvas-mode-toggle')));
        expect(homePageSource, isNot(contains('CanvasView(')));
      },
    );

    test(
      'HomePage toolbar does not expose legacy CanvasController brush state',
      () {
        final homePageSource = File(
          'lib/src/ui/home_page.dart',
        ).readAsStringSync();

        expect(homePageSource, isNot(contains('Active strokes:')));
        expect(homePageSource, isNot(contains('_canvasController.canUndo')));
        expect(homePageSource, isNot(contains('_canvasController.canRedo')));
        expect(homePageSource, isNot(contains('_canvasController.undo()')));
        expect(homePageSource, isNot(contains('_canvasController.redo()')));
        expect(homePageSource, contains('_historyManager.canUndo'));
        expect(homePageSource, contains('_undoProjectHistory'));
        expect(homePageSource, contains("Text('Undo')"));
        expect(homePageSource, contains("Text('Redo')"));
        expect(homePageSource, isNot(contains("Text('Project Undo')")));
        expect(homePageSource, isNot(contains("Text('Project Redo')")));
        expect(homePageSource, contains('_redoProjectHistory'));
      },
    );

    test(
      'TileDelta names stay out of brush commit undo redo and cache boundaries',
      () {
        final boundaryFiles = [
          'lib/src/services/brush_frame_editing_coordinator.dart',
          'lib/src/services/brush_frame_store.dart',
          'lib/src/services/brush_edit_session_cache_operations.dart',
          'lib/src/services/brush_edit_session_commit.dart',
          'lib/src/models/brush_commit_result.dart',
          'lib/src/models/brush_paint_command.dart',
          'lib/src/models/brush_frame_drawing_state.dart',
          'lib/src/models/brush_frame_cache_invalidation.dart',
          'lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart',
        ];

        for (final path in boundaryFiles) {
          final text = File(path).readAsStringSync();
          expect(
            text,
            isNot(contains('TileDelta')),
            reason:
                '$path is a brush commit/undo/redo/edit-history/cache boundary and must not use TileDelta.',
          );
          expect(
            text,
            isNot(contains('TileDeltaCommand')),
            reason:
                '$path is a brush commit/undo/redo/edit-history/cache boundary and must not use TileDeltaCommand.',
          );
        }
      },
    );

    test(
      'current brush runtime exposes production undo and payload ownership boundaries',
      () {
        final unifiedUndo = File(
          'lib/src/models/unified_undo_history.dart',
        ).readAsStringSync();
        final undoPayload = File(
          'lib/src/models/undo_payload_ref.dart',
        ).readAsStringSync();
        final frameStore = File(
          'lib/src/services/brush_frame_store.dart',
        ).readAsStringSync();
        final paintCommand = File(
          'lib/src/models/brush_paint_command.dart',
        ).readAsStringSync();
        final frameDrawingState = File(
          'lib/src/models/brush_frame_drawing_state.dart',
        ).readAsStringSync();
        final brushFrameCacheInvalidation = File(
          'lib/src/models/brush_frame_cache_invalidation.dart',
        ).readAsStringSync();
        final materializationState = File(
          'lib/src/models/brush_bitmap_materialization_history_state.dart',
        ).readAsStringSync();
        final commitResult = File(
          'lib/src/models/brush_commit_result.dart',
        ).readAsStringSync();

        expect(unifiedUndo, contains('class UnifiedUndoHistory'));
        expect(unifiedUndo, contains('pushNewEntry'));
        expect(unifiedUndo, contains('takeUndo'));
        expect(unifiedUndo, contains('takeRedo'));
        expect(undoPayload, contains('factory UndoPayloadRef.paintCommand'));
        expect(undoPayload, contains('brushFrameStore.paintCommand'));
        expect(frameStore, contains('class BrushFrameStore'));
        expect(frameStore, contains('addLivePaintCommand'));
        expect(frameStore, contains('markPaintCommandHiddenByUndo'));
        expect(frameStore, contains('restorePaintCommandFromUndo'));
        expect(frameStore, contains('movePaintCommandToDeferredBake'));
        expect(paintCommand, contains('class BrushPaintCommand'));
        expect(paintCommand, contains('materializationRef'));
        expect(paintCommand, contains('minimal bridge'));
        expect(frameDrawingState, contains('commandById'));
        expect(frameDrawingState, contains('cacheDirtyTiles'));
        expect(brushFrameCacheInvalidation, contains('BrushFrameKey'));
        expect(brushFrameCacheInvalidation, contains('DirtyTileSet'));
        for (final forbidden in [
          'BitmapSurface',
          'Uint8List',
          'ByteData',
          'inactivePreviewCache',
          'playbackPreviewCache',
          'cacheImage',
          'previewImage',
          'sourcePayload',
          'paintCommands',
        ]) {
          expect(
            brushFrameCacheInvalidation,
            isNot(contains(forbidden)),
            reason:
                'BrushFrameCacheInvalidation must stay metadata-only and must not carry $forbidden.',
          );
        }
        expect(
          materializationState,
          contains('Internal session-local bitmap materialization'),
        );
        expect(
          materializationState,
          contains('not the production user-facing brush undo source of truth'),
        );
        expect(
          commitResult,
          contains('Internal bitmap materialization bridge'),
        );
        expect(
          commitResult,
          contains('must not become user-facing undo history'),
        );
      },
    );

    test(
      'public brush undo boundary does not depend on materialization history APIs',
      () {
        final publicBoundaryFiles = [
          'lib/src/models/undo_payload_ref.dart',
          'lib/src/models/unified_undo_history.dart',
          'lib/src/models/undo_history_entry.dart',
          'lib/src/services/brush_frame_store.dart',
        ];

        for (final path in publicBoundaryFiles) {
          final text = File(path).readAsStringSync();

          for (final forbidden in [
            'brush_bitmap_materialization_undo_service.dart',
            'brush_bitmap_materialization_redo_service.dart',
            'BrushBitmapMaterializationHistoryState',
            'BrushBitmapMaterializationHistoryEntry',
            'BrushCommitResult',
            'undoLatestBrushBitmapMaterialization',
            'redoLatestBrushBitmapMaterialization',
            'undoEntries',
            'redoEntries',
          ]) {
            expect(
              text,
              isNot(contains(forbidden)),
              reason:
                  '$path must keep user undo refs pointed at BrushPaintCommand payloads, not $forbidden.',
            );
          }
        }
      },
    );

    test(
      'BrushPaintCommand materializationRef remains a minimal internal bridge',
      () {
        final text = File(
          'lib/src/models/brush_paint_command.dart',
        ).readAsStringSync();

        expect(text, contains('materializationRef'));
        expect(text, contains('minimal bridge'));
        expect(text, contains('session-local'));
        expect(text, contains('not'));
        for (final forbidden in [
          'Uint8List',
          'ByteData',
          'BitmapSurface',
          'BrushCommitResult',
          'BrushBitmapMaterializationHistoryEntry',
          'undoEntries',
          'redoEntries',
        ]) {
          expect(
            text,
            isNot(contains(forbidden)),
            reason:
                'BrushPaintCommand must not turn materializationRef into a heavy or public undo payload via $forbidden.',
          );
        }
      },
    );

    test(
      'current brush docs forbid TileDeltaCommand brush runtime boundaries',
      () {
        final text = File(
          'docs/Current_Brush_Architecture.md',
        ).readAsStringSync();

        expect(text, contains('TileDelta / TileDeltaCommand must not be used'));
        expect(text, contains('brush commit'));
        expect(text, contains('brush edit history'));
        expect(text, contains('brush undo/redo'));
        expect(text, contains('cache-invalidation'));
      },
    );
  });
}
