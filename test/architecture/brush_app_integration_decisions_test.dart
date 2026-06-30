import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush app integration decisions', () {
    test(
      'current brush document records required integration architecture terms',
      () {
        final file = File('docs/Current_Brush_Architecture.md');

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
      },
    );
  });
}
