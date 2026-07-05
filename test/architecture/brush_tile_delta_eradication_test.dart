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

    test('UI-facing brush route avoids dangerous legacy APIs', () {
      final uiFiles = [
        File('lib/src/ui/brush/main_canvas_brush_host.dart'),
        File('lib/src/ui/brush/brush_canvas_panel.dart'),
        File('lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart'),
      ];

      for (final file in uiFiles) {
        final text = file.readAsStringSync();
        for (final forbidden in [
          'commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation',
          'brushSurfaceEditForBrushDabSequenceOnBitmapSurface',
          'applyBrushSurfaceEditToCanvasSurfaceState',
          'undoLatestBrushBitmapMaterialization',
          'redoLatestBrushBitmapMaterialization',
          'TileDelta',
          'TileDeltaCommand',
        ]) {
          expect(
            text,
            isNot(contains(forbidden)),
            reason:
                '${file.path} must not call dangerous legacy API $forbidden.',
          );
        }
      }
    });

    test(
      'active brush display avoids smooth path preview cache and bitmap hot paths',
      () {
        final activeOverlay = File(
          'lib/src/ui/canvas/active_stroke_overlay.dart',
        ).readAsStringSync();
        final interactiveView = File(
          'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
        ).readAsStringSync();
        final brushView = File(
          'lib/src/ui/canvas/brush_edit_canvas_view.dart',
        ).readAsStringSync();
        final brushPanel = File(
          'lib/src/ui/brush/brush_canvas_panel.dart',
        ).readAsStringSync();
        final surfacePainter = File(
          'lib/src/ui/canvas/bitmap_surface_painter.dart',
        ).readAsStringSync();

        expect(activeOverlay, isNot(contains('drawPath')));
        expect(interactiveView, isNot(contains('BitmapSurfacePainter')));
        for (final source in [interactiveView, brushView, brushPanel]) {
          expect(source, isNot(contains('displayPreviewSurface')));
          expect(source, isNot(contains('inactivePreviewCache')));
          expect(source, isNot(contains('playbackPreviewCache')));
        }
        // The live overlay must decode its images like the committed tiles
        // (decodeImageFromPixels): `toImageSync` textures are GPU-context-
        // backed and flash garbage for a frame when the context is lost or
        // the image is created/disposed (e.g. app focus switches), and any
        // non-image overlay rendering (rect geometry, pictures) rasterizes
        // differently from nearest-sampled images at fractional zoom,
        // visibly shifting the active stroke against committed strokes.
        for (final source in [activeOverlay, interactiveView, surfacePainter]) {
          expect(source, isNot(contains('toImageSync')));
        }
        // Intentionally no positive implementation-string checks here (per
        // Current_Test_Architecture source-string policy): only drawPath
        // vector smoothing and GPU-texture-backed overlay images are banned.
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
      'production brush route keeps smoke debug and fake selection boundaries out',
      () {
        final homePageSource = File(
          'lib/src/ui/home_page.dart',
        ).readAsStringSync();
        final hostSource = File(
          'lib/src/ui/brush/main_canvas_brush_host.dart',
        ).readAsStringSync();
        final panelSource = File(
          'lib/src/ui/brush/brush_canvas_panel.dart',
        ).readAsStringSync();
        final viewSource = File(
          'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
        ).readAsStringSync();

        for (final source in [homePageSource, hostSource, panelSource]) {
          expect(source, isNot(contains('brush_canvas_smoke_screen.dart')));
          expect(
            source,
            isNot(contains('interactive_brush_canvas_smoke_host')),
          );
          expect(source, isNot(contains('BrushCanvasSmokeScreen')));
          expect(source, isNot(contains('Debug Reset Session')));
          expect(source, isNot(contains('Brush Host Preview')));
        }

        expect(hostSource, isNot(contains('brush-host-placeholder-project')));
        expect(hostSource, isNot(contains('brush-host-placeholder-frame')));

        for (final source in [
          homePageSource,
          hostSource,
          panelSource,
          viewSource,
        ]) {
          for (final forbidden in [
            'BrushBitmapMaterializationHistoryState',
            'BrushBitmapMaterializationHistoryEntry',
            'BrushCommitResult',
            'undoLatestBrushBitmapMaterialization',
            'redoLatestBrushBitmapMaterialization',
            'paintCommands =',
            'cacheImage',
            'previewImage',
          ]) {
            expect(
              source,
              isNot(contains(forbidden)),
              reason:
                  'Production brush UI route must not own source payloads, cache images, or internal materialization undo via $forbidden.',
            );
          }
        }
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
        expect(homePageSource, isNot(contains("Text('Project Undo')")));
        expect(homePageSource, isNot(contains("Text('Project Redo')")));
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
  });
}
