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
      for (final path in currentDocs.where(
        (path) => path.contains('Current_'),
      )) {
        expect(index, contains(path), reason: 'Index should reference $path.');
      }
      expect(
        index,
        contains('Phase task docs are historical task/order records'),
      );
      expect(
        index,
        contains('read the matching `Current_*` document directly'),
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
        expect(handoff, contains('## 6. Current source-of-truth docs'));
        expect(
          handoff,
          contains(
            'Before working on a module, read the matching current document directly',
          ),
        );
        expect(handoff, contains('docs/Current_Docs_Index.md'));
      },
    );

    test('current docs protect consolidated architecture policies', () {
      final brush = File(
        'docs/Current_Brush_Architecture.md',
      ).readAsStringSync();
      expect(
        brush,
        contains('User-facing undo is based on recent live paint commands'),
      );
      expect(
        brush,
        contains('The deferred bake buffer is not user-facing undo'),
      );
      expect(
        brush,
        contains('Tile delta is not the current user-facing undo policy'),
      );
      expect(brush, isNot(contains('Undo source = tile delta data')));
      expect(brush, isNot(contains('Undo should prefer tile deltas')));

      final timeline = File(
        'docs/Current_Timeline_Architecture.md',
      ).readAsStringSync();
      expect(
        timeline,
        contains(
          'Timeline range semantics must not drive canvas/cache/storage semantics',
        ),
      );
      expect(
        timeline,
        contains('Cut.duration is playback/export duration only'),
      );
      expect(
        timeline,
        contains('linked frames share drawing material/source identity'),
      );
      expect(
        timeline,
        contains('Linked frames do not share placement, exposure duration'),
      );
      expect(
        timeline,
        contains(
          '`+ Exposure` and `- Exposure` operate on the selected authored timeline entry',
        ),
      );
      expect(
        timeline,
        contains(
          'must not accidentally mutate every linked use of a `FrameId`',
        ),
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
      expect(project, contains('Same frame name means same drawing material'));
      expect(
        project,
        contains('Linked frames share drawing material/source identity'),
      );

      final storyboard = File(
        'docs/Current_Storyboard_Architecture.md',
      ).readAsStringSync();
      expect(
        storyboard,
        contains('Storyboard is an ordinary `Layer` with `kind: storyboard`'),
      );

      final canvas = File(
        'docs/Current_Canvas_Cache_Storage_Architecture.md',
      ).readAsStringSync();
      expect(canvas, contains('Playback must not replay live paint commands'));
      expect(canvas, contains('Cache images are derived, not source of truth'));
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
