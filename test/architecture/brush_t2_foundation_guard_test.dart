import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Brush T2 source model does not reintroduce local visible counts', () {
    final drawingState = File(
      'lib/src/models/brush_frame_drawing_state.dart',
    ).readAsStringSync();
    final store = File(
      'lib/src/services/brush_frame_store.dart',
    ).readAsStringSync();

    expect(drawingState, isNot(contains('visibleCommandCount')));
    expect(store, isNot(contains('visibleCommandCount')));
  });

  test('production brush route no longer owns the 320x240 canvas default', () {
    final productionFiles = [
      'lib/src/ui/brush/brush_canvas_defaults.dart',
      'lib/src/ui/brush/main_canvas_brush_host.dart',
      'lib/src/ui/brush/brush_canvas_panel.dart',
      'lib/src/ui/home_page.dart',
    ];

    for (final path in productionFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('CanvasSize(width: 320, height: 240)')),
        reason: '$path must use active Cut canvas settings or T2 defaults.',
      );
    }
  });

  test(
    'live active stroke overlay stays a UI overlay and not cache generation',
    () {
      final interactiveView = File(
        'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
      ).readAsStringSync();
      final bitmapPainter = File(
        'lib/src/ui/canvas/bitmap_surface_painter.dart',
      ).readAsStringSync();

      expect(
        interactiveView,
        isNot(contains('_collectedDabs.add(_dabFromPosition)')),
      );
      for (final forbidden in [
        'commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation',
        'brushSurfaceEditForBrushDabSequenceOnBitmapSurface',
        'applyBrushSurfaceEditToCanvasSurfaceState',
        'generateCache',
      ]) {
        expect(interactiveView, isNot(contains(forbidden)));
        expect(bitmapPainter, isNot(contains(forbidden)));
      }
    },
  );

  test(
    'Frame remains lightweight and production brush UI has no local undo/debug controls',
    () {
      final frame = File('lib/src/models/frame.dart').readAsStringSync();
      final brushPanel = File(
        'lib/src/ui/brush/brush_canvas_panel.dart',
      ).readAsStringSync();
      final homePage = File('lib/src/ui/home_page.dart').readAsStringSync();

      for (final forbidden in [
        'BrushFrameDrawing',
        'BrushPaintCommand',
        'hiddenCommandIds',
        'bakedBaseSurface',
        'playbackPreviewCache',
        'inactivePreviewCache',
      ]) {
        expect(frame, isNot(contains(forbidden)));
      }

      for (final forbidden in [
        'Brush Undo',
        'Brush Redo',
        'Debug Reset Session',
        'brush-workspace-screen',
        'tutorial',
      ]) {
        expect(brushPanel, isNot(contains(forbidden)));
        expect(homePage, isNot(contains(forbidden)));
      }
    },
  );
}
