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
      'docs/Current_Cut_Management_Architecture.md',
      'docs/Current_Canvas_Cache_Storage_Architecture.md',
      'docs/Current_Storyboard_Architecture.md',
      'docs/Handoff_QuickAnimaker_v2_Current.md',
    ];

    test('required current docs exist and are indexed', () {
      for (final path in currentDocs) {
        expect(File(path).existsSync(), isTrue, reason: '$path should exist.');
      }

      final index = File('docs/Current_Docs_Index.md').readAsStringSync();
      final normalizedIndex = _normalizeDocText(index);
      for (final path in currentDocs.where(
        (path) => path.contains('Current_'),
      )) {
        expect(index, contains(path), reason: 'Index should reference $path.');
      }
      expect(
        normalizedIndex,
        contains('phase task docs are historical task order records'),
      );
      expect(
        normalizedIndex,
        contains('read the matching current document directly'),
      );
    });

    test('handoff preserves user-managed sections and current doc links', () {
      final handoff = File(
        'docs/Handoff_QuickAnimaker_v2_Current.md',
      ).readAsStringSync();
      for (final heading in ['## 0.', '## 1.', '## 2.', '## 3.', '## 4.']) {
        expect(handoff, contains(heading));
      }

      final handoffSection5AndLater = _sectionFrom(handoff, '## 5.');
      final normalizedSection5AndLater = _normalizeDocText(
        handoffSection5AndLater,
      );

      expect(handoff, contains('## 5.'));
      expect(normalizedSection5AndLater, contains('lightweight entry point'));
      expect(
        normalizedSection5AndLater,
        contains('not a detailed architecture specification'),
      );
      expect(
        normalizedSection5AndLater,
        contains(
          'before working on a module read the matching current document directly',
        ),
      );
      expect(handoffSection5AndLater, contains('docs/Current_Docs_Index.md'));
      for (final path in currentDocs.where(
        (path) => path.contains('Current_'),
      )) {
        expect(
          handoffSection5AndLater,
          contains(path),
          reason: 'Handoff section 5+ should point to $path.',
        );
      }
      expect(
        handoffSection5AndLater.length,
        lessThan(2400),
        reason: 'Handoff section 5+ should stay lightweight.',
      );
    });

    test('current docs protect stable architecture boundaries', () {
      final brush = File(
        'docs/Current_Brush_Architecture.md',
      ).readAsStringSync();
      final normalizedBrush = _normalizeDocText(brush);
      expect(
        normalizedBrush,
        contains('user facing undo is based on recent live paint commands'),
      );
      expect(
        normalizedBrush,
        contains('the deferred bake buffer is not user facing undo'),
      );
      for (final term in [
        'tiledelta tiledeltacommand',
        'brush commit',
        'brush edit history',
        'brush undo redo',
        'cache invalidation',
      ]) {
        expect(normalizedBrush, contains(term), reason: 'Missing term: $term');
      }
      expect(brush, isNot(contains('Undo source = tile delta data')));
      expect(brush, isNot(contains('Undo should prefer tile deltas')));

      final timeline = File(
        'docs/Current_Timeline_Architecture.md',
      ).readAsStringSync();
      final normalizedTimeline = _normalizeDocText(timeline);
      for (final term in [
        'timeline range semantics must not drive canvas cache storage semantics',
        'cut duration is playback export duration only',
        'linked frames share drawing material source identity',
        'linked frames do not share placement exposure duration',
      ]) {
        expect(
          normalizedTimeline,
          contains(term),
          reason: 'Missing term: $term',
        );
      }

      final project = File(
        'docs/Current_Project_Architecture.md',
      ).readAsStringSync();
      final normalizedProject = _normalizeDocText(project);
      for (final term in [
        'same frame name means same drawing material',
        'linked frames share drawing material source identity',
        'canvaspoint is canvas space',
        'viewportpoint is viewport widget local space',
        'canvasviewport performs pure coordinate conversion',
        'brushsettings is a frozen value snapshot stored with stroke',
      ]) {
        expect(
          normalizedProject,
          contains(term),
          reason: 'Missing term: $term',
        );
      }
      for (final idName in [
        'ProjectId',
        'TrackId',
        'CutId',
        'LayerId',
        'FrameId',
        'StrokeId',
      ]) {
        expect(project, contains(idName));
      }

      final canvas = File(
        'docs/Current_Canvas_Cache_Storage_Architecture.md',
      ).readAsStringSync();
      final normalizedCanvas = _normalizeDocText(canvas);
      for (final term in [
        'playback must not replay live paint commands',
        'cache images are derived not source of truth',
        'project stroke paintcommand and brushframestore must stay conceptually distinct',
        'heavy bitmap payloads paint command buffers baked surfaces',
      ]) {
        expect(normalizedCanvas, contains(term), reason: 'Missing term: $term');
      }
    });

    test(
      'obsolete non-phase docs are deleted while task records remain historical',
      () {
        for (final path in [
          'docs/Active_Cut_State_Design.md',
          'docs/Cut_Management_Policy.md',
          'docs/Product_Direction_Notes.md',
        ]) {
          expect(
            File(path).existsSync(),
            isFalse,
            reason: '$path should stay consolidated into Current_* docs.',
          );
        }

        expect(File('docs/Phase_211_Codex_Task.md').existsSync(), isTrue);
        final index = File('docs/Current_Docs_Index.md').readAsStringSync();
        expect(
          index,
          contains(
            'Phase task docs and other task-order docs are preserved as historical records',
          ),
        );
        expect(index, contains('Current_*'));
        expect(index, contains('source of truth'));
      },
    );
  });
}

String _normalizeDocText(String source) {
  return source
      .toLowerCase()
      .replaceAll(RegExp(r'[`*_.,;:()\[\]/-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _sectionFrom(String source, String headingPrefix) {
  final index = source.indexOf(headingPrefix);
  if (index == -1) {
    return '';
  }
  return source.substring(index);
}
