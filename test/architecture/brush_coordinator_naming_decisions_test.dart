import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush coordinator naming decisions', () {
    test('documents BrushWorkspaceCoordinator naming cleanup decision', () {
      final doc = File(
        'docs/Brush_App_Integration_Decisions.md',
      ).readAsStringSync();

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

    test('keeps deleted workspace UI and runtime renames out of scope', () {
      final doc = File(
        'docs/Brush_App_Integration_Decisions.md',
      ).readAsStringSync();

      expect(doc, contains('Left runtime behavior unchanged.'));
      expect(doc, contains('Did not rename BrushWorkspaceCoordinator yet.'));
      expect(doc, contains('Did not rename BrushWorkspaceCacheInvalidationSink.'));
      expect(
        doc,
        contains('Did not reintroduce deleted workspace UI or debug controls.'),
      );
    });
  });
}
