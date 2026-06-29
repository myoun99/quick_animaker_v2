import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Current brush architecture documentation', () {
    test('canonical document exists and protects deferred-bake policy', () {
      final file = File('docs/Brush_Architecture_Current.md');

      expect(file.existsSync(), isTrue);

      final source = file.readAsStringSync();
      for (final term in [
        'Deferred Bake Hybrid Brush History',
        'bakedBaseSurface',
        'deferredBakePaintCommands',
        'livePaintCommands',
        'hiddenByUndoPaintCommands',
        'inactivePreviewCache',
        'playbackPreviewCache',
        'userUndoLimit',
        'deferredBakeRatio',
        'deferredBakeLimit',
        '10%',
        'User-facing undo is based on recent live paint commands',
        'The deferred bake buffer is not user-facing undo',
        'derived images',
        'They are not the source of truth',
        'Playback must not replay live paint commands',
        'Playback must not run brush rasterization',
        'Tile delta is not the current user-facing undo policy',
      ]) {
        expect(source, contains(term), reason: 'Missing term: $term');
      }
    });

    test('legacy brush docs defer to the canonical document', () {
      final bitmapDoc = File('docs/Bitmap_Canvas_Brush_Architecture.md');
      if (bitmapDoc.existsSync()) {
        final source = bitmapDoc.readAsStringSync();
        expect(source, contains('Superseded notice'));
        expect(source, contains('docs/Brush_Architecture_Current.md'));
        expect(
          source,
          contains('tile delta is not the current user-facing undo policy'),
        );
      }

      for (final path in [
        'docs/Brush_V1_Complete.md',
        'docs/Brush_V1_Integration_Review.md',
      ]) {
        final file = File(path);
        if (!file.existsSync()) {
          continue;
        }

        final source = file.readAsStringSync();
        expect(source, contains('Legacy Brush V1'));
        expect(source, contains('docs/Brush_Architecture_Current.md'));
      }
    });
  });
}
