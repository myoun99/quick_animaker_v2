import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Brush T2 source model uses commands plus hiddenCommandIds only', () {
    final drawingState = File(
      'lib/src/models/brush_frame_drawing_state.dart',
    ).readAsStringSync();
    final store = File('lib/src/services/brush_frame_store.dart').readAsStringSync();

    expect(drawingState, contains('List<BrushPaintCommand> get commands'));
    expect(drawingState, contains('hiddenCommandIds'));
    expect(store, contains('hiddenCommandIds'));
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

  test('live active stroke overlay stays a UI overlay and not cache generation', () {
    final interactiveView = File(
      'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
    ).readAsStringSync();
    final bitmapPainter = File(
      'lib/src/ui/canvas/bitmap_surface_painter.dart',
    ).readAsStringSync();

    expect(interactiveView, contains('activeStrokeOverlay'));
    expect(bitmapPainter, contains('_paintActiveStrokeOverlay'));
    expect(interactiveView, isNot(contains('generateCache')));
    expect(bitmapPainter, isNot(contains('generateCache')));
  });
}
