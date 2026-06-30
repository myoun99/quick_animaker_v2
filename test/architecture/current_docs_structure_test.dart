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

    test(
      'handoff preserves user-managed sections and points to current docs',
      () {
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
        expect(
          normalizedSection5AndLater,
          contains('this handoff intentionally stays lightweight'),
        );
        expect(
          normalizedSection5AndLater,
          contains('not an architecture specification'),
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
          lessThan(1800),
          reason: 'Handoff section 5+ should stay lightweight.',
        );
        expect(
          handoffSection5AndLater,
          isNot(contains('핵심 도메인 모델')),
        );
      },
    );

    test('current docs protect consolidated architecture policies', () {
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
      expect(
        normalizedBrush,
        contains('tile delta is not the current user facing undo policy'),
      );
      expect(brush, isNot(contains('Undo source = tile delta data')));
      expect(brush, isNot(contains('Undo should prefer tile deltas')));

      final timeline = File(
        'docs/Current_Timeline_Architecture.md',
      ).readAsStringSync();
      final normalizedTimeline = _normalizeDocText(timeline);
      expect(
        normalizedTimeline,
        contains(
          'timeline range semantics must not drive canvas cache storage semantics',
        ),
      );
      expect(
        normalizedTimeline,
        contains('cut duration is playback export duration only'),
      );
      expect(
        normalizedTimeline,
        contains('linked frames share drawing material source identity'),
      );
      expect(
        normalizedTimeline,
        contains('linked frames do not share placement exposure duration'),
      );
      expect(
        normalizedTimeline,
        contains(
          'exposure and exposure operate on the selected authored timeline entry',
        ),
      );
      expect(
        normalizedTimeline,
        contains('must not accidentally mutate every linked use of a frameid'),
      );

      final cutManagement = File(
        'docs/Current_Cut_Management_Architecture.md',
      ).readAsStringSync();
      expect(
        cutManagement,
        contains('`activeCutId` is application/session/controller state'),
      );
      expect(cutManagement, contains('not persisted project structure'));
      expect(cutManagement, contains('Previous Cut in project order'));
      expect(cutManagement, contains('If no previous Cut exists, next Cut'));
      expect(
        cutManagement,
        contains('create a new default empty Cut and make it active'),
      );
      expect(
        cutManagement,
        contains(
          'Deleting a Cut must not leave the editor pointing at a missing Cut',
        ),
      );
      expect(
        cutManagement,
        contains(
          'must not mutate unrelated timeline, canvas, brush, cache, or storage state',
        ),
      );

      final project = File(
        'docs/Current_Project_Architecture.md',
      ).readAsStringSync();
      final normalizedProject = _normalizeDocText(project);
      expect(project, contains('Same frame name means same drawing material'));
      expect(
        project,
        contains('Linked frames share drawing material/source identity'),
      );
      for (final idName in [
        'ProjectId',
        'TrackId',
        'CutId',
        'LayerId',
        'FrameId',
        'StrokeId',
      ]) {
        expect(
          project,
          contains(idName),
          reason: '$idName should remain documented as a core ID.',
        );
      }
      expect(
        normalizedProject,
        contains('canvaspoint is canvas space'),
      );
      expect(
        normalizedProject,
        contains('viewportpoint is viewport widget local space'),
      );
      expect(
        normalizedProject,
        contains('canvasviewport performs pure coordinate conversion'),
      );
      for (final flutterType in [
        'Offset',
        'PointerEvent',
        'Canvas',
        'Paint',
        'CustomPainter',
      ]) {
        expect(
          project,
          contains(flutterType),
          reason: '$flutterType independence should stay documented.',
        );
      }
      expect(
        normalizedProject,
        contains('brushsettings is a frozen value snapshot stored with stroke'),
      );
      expect(
        normalizedProject,
        contains('brushpreset is reusable preset metadata'),
      );
      expect(
        normalizedProject,
        contains('brushpreset name is a display label'),
      );
      expect(
        normalizedProject,
        contains('brushpresetid is preset identity'),
      );
      expect(
        normalizedProject,
        contains('stroke should not directly reference brushpreset'),
      );
      expect(
        normalizedProject,
        contains('brushinputsample is pre stroke input data'),
      );
      expect(
        normalizedProject,
        contains('strokepoint is stored coordinate data inside stroke'),
      );

      final storyboard = File(
        'docs/Current_Storyboard_Architecture.md',
      ).readAsStringSync();
      final normalizedStoryboard = _normalizeDocText(storyboard);
      expect(
        normalizedStoryboard,
        contains('storyboard is an ordinary layer with kind storyboard'),
      );

      final canvas = File(
        'docs/Current_Canvas_Cache_Storage_Architecture.md',
      ).readAsStringSync();
      final normalizedCanvas = _normalizeDocText(canvas);
      expect(
        normalizedCanvas,
        contains('playback must not replay live paint commands'),
      );
      expect(
        normalizedCanvas,
        contains('cache images are derived not source of truth'),
      );
      expect(
        normalizedCanvas,
        contains(
          'project stroke paintcommand and brushframestore must stay conceptually distinct',
        ),
      );
      expect(
        normalizedCanvas,
        contains('heavy bitmap payloads paint command buffers baked surfaces'),
      );
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
