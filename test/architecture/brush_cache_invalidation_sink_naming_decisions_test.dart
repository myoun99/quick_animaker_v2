import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush cache invalidation sink naming', () {
    test('runtime rename is reflected in lib source files', () {
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
