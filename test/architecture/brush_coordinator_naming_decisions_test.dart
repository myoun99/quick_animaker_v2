import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush coordinator naming decisions', () {
    test('documents BrushWorkspaceCoordinator naming cleanup decision', () {
      final doc = File('docs/Current_Brush_Architecture.md').readAsStringSync();

      expect(
        doc,
        contains(
          '## Phase 206 BrushWorkspaceCoordinator naming cleanup preparation',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCoordinator is no longer tied to the deleted '
          'BrushWorkspaceScreen route.',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCoordinator is currently a production brush editing '
          'coordination service.',
        ),
      );
      expect(
        doc,
        contains('BrushWorkspaceCoordinator -> BrushFrameEditingCoordinator'),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink should be considered separately',
        ),
      );
    });

    test(
      'kept deleted workspace UI and runtime renames out of Phase 206 scope',
      () {
        final doc = File(
          'docs/Current_Brush_Architecture.md',
        ).readAsStringSync();

        expect(doc, contains('Left runtime behavior unchanged.'));
        expect(doc, contains('Did not rename BrushWorkspaceCoordinator yet.'));
        expect(
          doc,
          contains('Did not rename BrushWorkspaceCacheInvalidationSink.'),
        );
        expect(
          doc,
          contains(
            'Did not reintroduce deleted workspace UI or debug controls.',
          ),
        );
      },
    );

    test('documents Phase 207 BrushFrameEditingCoordinator runtime rename', () {
      final doc = File('docs/Current_Brush_Architecture.md').readAsStringSync();

      expect(
        doc,
        contains('## Phase 207 BrushFrameEditingCoordinator runtime rename'),
      );
      expect(
        doc,
        contains(
          'Renamed BrushWorkspaceCoordinator to BrushFrameEditingCoordinator.',
        ),
      );
      expect(
        doc,
        contains(
          'Renamed brush_workspace_coordinator.dart to '
          'brush_frame_editing_coordinator.dart.',
        ),
      );
      expect(doc, contains('Kept runtime behavior unchanged.'));
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink was not renamed in this phase.',
        ),
      );
    });

    test('Phase 207 runtime rename is reflected in lib source files', () {
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
