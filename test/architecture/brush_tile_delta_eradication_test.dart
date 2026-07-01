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
