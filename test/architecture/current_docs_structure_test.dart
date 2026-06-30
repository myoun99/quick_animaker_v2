import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Current documentation structure', () {
    const currentDocs = [
      'docs/Current_Docs_Index.md',
      'docs/Current_Project_Architecture.md',
      'docs/Current_Implementation_Roadmap.md',
      'docs/Current_Brush_Architecture.md',
      'docs/Current_Timeline_Architecture.md',
      'docs/Current_Canvas_Cache_Storage_Architecture.md',
      'docs/Current_Storyboard_Architecture.md',
      'docs/Handoff_QuickAnimaker_v2_Current.md',
    ];

    test('required current docs exist and are indexed', () {
      for (final path in currentDocs) {
        expect(File(path).existsSync(), isTrue, reason: '$path should exist.');
      }

      final index = File('docs/Current_Docs_Index.md').readAsStringSync();
      for (final path in currentDocs.where((path) => path.contains('Current_'))) {
        expect(index, contains(path), reason: 'Index should reference $path.');
      }
      expect(index, contains('Phase task docs are historical task/order records'));
      expect(index, contains('read the matching `Current_*` document directly'));
    });

    test('handoff preserves user-managed sections and points to current docs', () {
      final handoff = File('docs/Handoff_QuickAnimaker_v2_Current.md').readAsStringSync();
      for (final heading in ['## 0.', '## 1.', '## 2.', '## 3.', '## 4.']) {
        expect(handoff, contains(heading));
      }
      expect(handoff, contains('## 6. Current source-of-truth docs'));
      expect(handoff, contains('Before working on a module, read the matching current document directly'));
      expect(handoff, contains('docs/Current_Docs_Index.md'));
    });

    test('current docs protect consolidated architecture policies', () {
      final brush = File('docs/Current_Brush_Architecture.md').readAsStringSync();
      expect(brush, contains('User-facing undo is based on recent live paint commands'));
      expect(brush, contains('The deferred bake buffer is not user-facing undo'));
      expect(brush, contains('Tile delta is not the current user-facing undo policy'));
      expect(brush, isNot(contains('Undo source = tile delta data')));
      expect(brush, isNot(contains('Undo should prefer tile deltas')));

      final timeline = File('docs/Current_Timeline_Architecture.md').readAsStringSync();
      expect(timeline, contains('Timeline range semantics must not drive canvas/cache/storage semantics'));
      expect(timeline, contains('Cut.duration is playback/export duration only'));

      final storyboard = File('docs/Current_Storyboard_Architecture.md').readAsStringSync();
      expect(storyboard, contains('Storyboard is an ordinary `Layer` with `kind: storyboard`'));

      final canvas = File('docs/Current_Canvas_Cache_Storage_Architecture.md').readAsStringSync();
      expect(canvas, contains('Playback must not replay live paint commands'));
      expect(canvas, contains('Cache images are derived, not source of truth'));
    });
  });
}
