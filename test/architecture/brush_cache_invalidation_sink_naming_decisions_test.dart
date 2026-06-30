import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush cache invalidation sink naming decisions', () {
    test('documents BrushWorkspaceCacheInvalidationSink naming decision', () {
      final doc = File('docs/Current_Brush_Architecture.md').readAsStringSync();

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

    test(
      'documents Phase 209 BrushEditCacheInvalidationSink runtime rename',
      () {
        final doc = File(
          'docs/Current_Brush_Architecture.md',
        ).readAsStringSync();

        expect(
          doc,
          contains(
            '## Phase 209 BrushEditCacheInvalidationSink runtime rename',
          ),
        );
        expect(
          doc,
          contains(
            'Renamed BrushWorkspaceCacheInvalidationSink to '
            'BrushEditCacheInvalidationSink.',
          ),
        );
        expect(
          doc,
          contains(
            'Renamed brush_workspace_cache_invalidation_sink.dart to '
            'brush_edit_cache_invalidation_sink.dart.',
          ),
        );
        expect(
          doc,
          contains(
            'Updated production imports to use BrushEditCacheInvalidationSink.',
          ),
        );
        expect(
          doc,
          contains('Updated tests to use BrushEditCacheInvalidationSink.'),
        );
        expect(doc, contains('Kept cache invalidation semantics unchanged.'));
      },
    );

    test('Phase 209 runtime rename is reflected in lib source files', () {
      final renamedSink = File(
        'lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart',
      );
      final oldSink = File(
        'lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart',
      );

      expect(renamedSink.existsSync(), isTrue);
      expect(oldSink.existsSync(), isFalse);

      final source = renamedSink.readAsStringSync();
      expect(source, contains('class BrushEditCacheInvalidationSink'));
      expect(
        source,
        isNot(contains('class BrushWorkspaceCacheInvalidationSink')),
      );

      final libDartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in libDartFiles) {
        final fileSource = file.readAsStringSync();
        expect(
          fileSource,
          isNot(contains('brush_workspace_cache_invalidation_sink.dart')),
        );
        expect(
          fileSource,
          isNot(contains('BrushWorkspaceCacheInvalidationSink')),
        );
      }
    });
  });
}
