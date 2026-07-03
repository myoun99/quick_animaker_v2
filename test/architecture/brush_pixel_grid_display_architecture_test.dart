import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 223 pixel-grid brush display architecture', () {
    test(
      'production active brush view uses raster surfaces instead of path painter display',
      () {
        final interactive = File(
          'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
        ).readAsStringSync();
        final canvasView = File(
          'lib/src/ui/canvas/brush_edit_canvas_view.dart',
        ).readAsStringSync();

        expect(interactive, contains('ActiveStrokeRasterOverlay'));
        expect(interactive, contains('BrushPixelGridRasterizer'));
        expect(canvasView, contains('activeEditCompositeSurface'));
        expect(canvasView, contains('activeStrokeTempSurface'));
        expect(interactive, isNot(contains('drawPath')));
        expect(interactive, isNot(contains('Path()')));
      },
    );

    test(
      'active brush panel does not pass inactive preview cache as active display path',
      () {
        final panel = File(
          'lib/src/ui/brush/brush_canvas_panel.dart',
        ).readAsStringSync();

        expect(panel, contains('BrushFrameEditCompositeService'));
        expect(panel, contains('activeEditCompositeSurface'));
        expect(panel, isNot(contains('displayPreviewSurface:')));
        expect(panel, isNot(contains('validPreviewSurfaceOrNull')));
        expect(panel, isNot(contains('prepareFramePreview')));
        expect(panel, isNot(contains('addPostFrameCallback')));
      },
    );

    test(
      'frame model remains free of brush display/cache payload ownership',
      () {
        final frameModel = File('lib/src/models/frame.dart').readAsStringSync();

        for (final forbidden in [
          'BrushPaintCommand',
          'BrushFrameEditComposite',
          'BrushCommandRasterCache',
          'BrushFramePreviewCache',
          'BitmapSurface',
          'DirtyTileSet',
        ]) {
          expect(frameModel, isNot(contains(forbidden)));
        }
      },
    );

    test(
      'brush runtime architecture does not reintroduce TileDelta command usage',
      () {
        final runtimeFiles = Directory('lib/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'));

        for (final file in runtimeFiles) {
          final source = file.readAsStringSync();
          expect(
            source,
            isNot(contains('TileDeltaCommand')),
            reason: file.path,
          );
        }
      },
    );
  });
}
