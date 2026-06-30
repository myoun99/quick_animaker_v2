import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush coordinator naming', () {
    test('runtime rename is reflected in lib source files', () {
      final renamedService = File(
        'lib/src/services/brush_frame_editing_coordinator.dart',
      );
      final oldService = File(
        'lib/src/services/brush_workspace_coordinator.dart',
      );

      expect(renamedService.existsSync(), isTrue);
      expect(oldService.existsSync(), isFalse);

      final libDartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in libDartFiles) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('brush_workspace_coordinator.dart')));
      }
    });
  });
}
