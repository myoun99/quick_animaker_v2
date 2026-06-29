import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush cache invalidation sink naming decisions', () {
    test('documents BrushWorkspaceCacheInvalidationSink naming decision', () {
      final doc = File(
        'docs/Brush_App_Integration_Decisions.md',
      ).readAsStringSync();

      expect(
        doc,
        contains(
          '## Phase 208 BrushWorkspaceCacheInvalidationSink naming decision',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink is no longer tied to deleted '
          'BrushWorkspaceScreen / BrushWorkspaceView UI.',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink currently acts as the cache '
          'invalidation sink boundary used by brush editing flows.',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink -> '
          'BrushEditCacheInvalidationSink',
        ),
      );
      expect(doc, contains('Why BrushEditCacheInvalidationSink:'));
      expect(doc, contains('Left runtime behavior unchanged.'));
      expect(
        doc,
        contains('Did not rename BrushWorkspaceCacheInvalidationSink yet.'),
      );
      expect(
        doc,
        contains(
          'Did not rename brush_workspace_cache_invalidation_sink.dart yet.',
        ),
      );
    });

    test('keeps runtime sink rename out of Phase 208 scope', () {
      final currentSink = File(
        'lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart',
      );
      final futureSink = File(
        'lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart',
      );

      expect(currentSink.existsSync(), isTrue);
      expect(futureSink.existsSync(), isFalse);

      final source = currentSink.readAsStringSync();
      expect(source, contains('class BrushWorkspaceCacheInvalidationSink'));
      expect(source, isNot(contains('class BrushEditCacheInvalidationSink')));
    });
  });
}
