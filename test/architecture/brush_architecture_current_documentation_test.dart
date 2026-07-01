import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Current brush architecture documentation', () {
    test('canonical document exists and protects deferred-bake policy', () {
      final file = File('docs/Current_Brush_Architecture.md');

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
      ]) {
        expect(source, contains(term), reason: 'Missing term: $term');
      }

      final normalizedSource = _normalizeDocText(source);
      for (final term in [
        'tiledelta tiledeltacommand',
        'brush commit',
        'brush edit history',
        'brush undo redo',
        'cache invalidation',
      ]) {
        expect(normalizedSource, contains(term), reason: 'Missing term: $term');
      }
    });

    test('obsolete legacy brush docs were deleted after consolidation', () {
      for (final path in [
        'docs/Bitmap_Canvas_Brush_Architecture.md',
        'docs/Brush_V1_Complete.md',
        'docs/Brush_V1_Integration_Review.md',
      ]) {
        expect(
          File(path).existsSync(),
          isFalse,
          reason: '$path should be consolidated into Current_* docs.',
        );
      }
    });
  });
}

String _normalizeDocText(String source) {
  return source
      .toLowerCase()
      .replaceAll(RegExp(r'[`*_.,;:()\[\]/-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
