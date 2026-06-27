import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush app integration decisions', () {
    test('decision document exists and records required architecture terms', () {
      final file = File('docs/Brush_App_Integration_Decisions.md');

      expect(file.existsSync(), isTrue);

      final source = file.readAsStringSync();
      for (final term in [
        'Deferred Bake Hybrid Brush History',
        'UnifiedUndoHistory',
        'BrushFrameStore',
        'BrushFrameKey',
        'Playback must not replay live paint commands',
        'Frame remains lightweight',
      ]) {
        expect(source, contains(term), reason: 'Missing term: $term');
      }
    });
  });
}
