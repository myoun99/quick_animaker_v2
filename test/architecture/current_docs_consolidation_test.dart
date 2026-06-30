import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const currentDocs = [
    'docs/Current_Docs_Index.md',
    'docs/Current_Project_Architecture.md',
    'docs/Current_Implementation_Roadmap.md',
    'docs/Current_Brush_Architecture.md',
    'docs/Current_Timeline_Architecture.md',
    'docs/Current_Canvas_Cache_Storage_Architecture.md',
    'docs/Current_Storyboard_Architecture.md',
  ];

  group('current documentation consolidation', () {
    test('required Current-prefixed docs exist and index references all of them', () {
      final index = File('docs/Current_Docs_Index.md').readAsStringSync();

      for (final path in currentDocs) {
        expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
        expect(index, contains(path.split('/').last));
      }

      expect(
        File('docs/Handoff_QuickAnimaker_v2_Current.md').existsSync(),
        isTrue,
      );
    });

    test('handoff keeps user-owned sections 0 through 4', () {
      final handoff = File(
        'docs/Handoff_QuickAnimaker_v2_Current.md',
      ).readAsStringSync();

      for (final heading in [
        '## 0. 문서 목적',
        '## 1. 프로젝트 개요',
        '## 2. 저장소 정보',
        '## 3. GPT와의 대화 흐름',
        '## 4. 코딩의 목표',
      ]) {
        expect(handoff, contains(heading), reason: 'Missing $heading');
      }

      expect(handoff, contains('## 5. Current documentation entry point'));
      expect(handoff, contains('Current_*'));
    });

    test('module-specific current docs contain protected key rules', () {
      final brush = File(
        'docs/Current_Brush_Architecture.md',
      ).readAsStringSync();
      for (final term in [
        'Deferred Bake Hybrid Brush History',
        'UnifiedUndoHistory',
        'BrushFrameStore',
        'userUndoLimit',
        'The deferred bake buffer is not user-facing undo',
        'Playback must not replay live paint commands',
        'Tile delta is not the current user-facing undo policy',
      ]) {
        expect(brush, contains(term), reason: 'Missing brush term: $term');
      }

      final timeline = File(
        'docs/Current_Timeline_Architecture.md',
      ).readAsStringSync();
      for (final term in [
        'Playback range',
        'Visible/display range',
        'Virtualized frame window',
        'Authored/data extent',
        'viewport-based two-axis virtualization',
      ]) {
        expect(timeline, contains(term), reason: 'Missing timeline term: $term');
      }

      final canvas = File(
        'docs/Current_Canvas_Cache_Storage_Architecture.md',
      ).readAsStringSync();
      for (final term in [
        'CanvasViewport is pure coordinate conversion',
        'Derived cache images are not source of truth',
        'Playback must not replay live paint commands',
        'Low-level tile/delta concepts are not the current user-facing brush '
            'undo policy',
      ]) {
        expect(canvas, contains(term), reason: 'Missing canvas/cache term: $term');
      }

      final storyboard = File(
        'docs/Current_Storyboard_Architecture.md',
      ).readAsStringSync();
      for (final term in [
        'Layer(kind: LayerKind.storyboard)',
        'A Cut may have at most one storyboard layer',
        'storyboard-panel',
        'storyboard-track-row-<trackId>',
        'Do not wire brush drawing into StoryboardPanel yet',
      ]) {
        expect(storyboard, contains(term), reason: 'Missing storyboard term: $term');
      }
    });

    test('obsolete non-phase docs were removed and phase tasks are allowed', () {
      final docsFiles = Directory('docs').listSync().whereType<File>().toList();
      expect(
        docsFiles.every((file) {
          final name = file.uri.pathSegments.last;
          return name == 'Handoff_QuickAnimaker_v2_Current.md' ||
              name.startsWith('Current_') ||
              (name.startsWith('Phase_') &&
                  name.endsWith('_Codex_Task.md')) ||
              name.endsWith('_Task.md');
        }),
        isTrue,
      );

      expect(
        docsFiles.any((file) =>
            file.uri.pathSegments.last.startsWith('Phase_') &&
            file.uri.pathSegments.last.endsWith('_Codex_Task.md')),
        isTrue,
      );
    });

    test('active docs do not reference obsolete non-phase docs', () {
      final obsoleteTerms = [
        'Long' 'Term_',
        'Brush_' 'Architecture_Current',
        'Bitmap_Canvas_' 'Brush_Architecture',
        'Brush_App_' 'Integration_Decisions',
        'Timeline_' 'Stabilization_Checkpoint',
        'Brush_V1_' 'Complete',
        'Brush_V1_' 'Integration_Review',
      ];
      final activeDocs = Directory('docs')
          .listSync()
          .whereType<File>()
          .where((file) {
            final name = file.uri.pathSegments.last;
            return name == 'Handoff_QuickAnimaker_v2_Current.md' ||
                name.startsWith('Current_');
          });

      for (final file in activeDocs) {
        final source = file.readAsStringSync();
        for (final term in obsoleteTerms) {
          expect(
            source,
            isNot(contains(term)),
            reason: '${file.path}: $term',
          );
        }
      }
    });
  });
}
