import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/cut_metadata.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_cut_thumbnail_store.dart';

/// Conte-sheet picture choice: the storyboard block thumbnail can pin to
/// any cut-local frame (null = first frame), toggled from the cut toolbar.
void main() {
  group('CutMetadata.thumbnailFrameIndex', () {
    test('serializes, omits null, and copyWith can CLEAR the pin', () {
      const pinned = CutMetadata(note: 'memo', thumbnailFrameIndex: 7);
      expect(CutMetadata.fromJson(pinned.toJson()), pinned);
      expect(pinned.toJson()['thumbnailFrame'], 7);

      const unpinned = CutMetadata(note: 'memo');
      expect(unpinned.toJson().containsKey('thumbnailFrame'), isFalse);
      expect(CutMetadata.fromJson(unpinned.toJson()), unpinned);

      expect(pinned.copyWith(note: 'x').thumbnailFrameIndex, 7);
      expect(pinned.copyWith(thumbnailFrameIndex: () => null), unpinned);
      expect(
        unpinned.copyWith(thumbnailFrameIndex: () => 3).thumbnailFrameIndex,
        3,
      );
    });
  });

  group('thumbnail store', () {
    Future<ui.Image> tinyImage() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint());
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(2, 2);
      } finally {
        picture.dispose();
      }
    }

    Cut cut({int? thumbnailFrame}) => Cut(
      id: const CutId('cut'),
      name: 'Cut',
      duration: 24,
      canvasSize: const CanvasSize(width: 8, height: 8),
      metadata: CutMetadata(thumbnailFrameIndex: thumbnailFrame),
      layers: [
        Layer(
          id: const LayerId('layer'),
          name: 'A',
          frames: [
            Frame(id: const FrameId('f1'), duration: 1, strokes: const []),
          ],
        ),
      ],
    );

    testWidgets('re-renders when the pinned thumbnail frame changes', (
      tester,
    ) async {
      var renderCount = 0;
      final store = StoryboardCutThumbnailStore(
        render: (_) {
          renderCount += 1;
          return tinyImage();
        },
      );
      addTearDown(store.dispose);

      await tester.runAsync(() async {
        store.thumbnailFor(cut());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        store.thumbnailFor(cut(thumbnailFrame: 12));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Unchanged pin does not re-render.
        store.thumbnailFor(cut(thumbnailFrame: 12));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      expect(renderCount, 2);
    });
  });

  group('session toggle', () {
    test('pins at the playhead, replaces on other frames, unpins on the '
        'pinned frame, one undo each', () {
      final session = EditorSessionManager(
        initialProject: createDefaultProject(),
      );
      addTearDown(session.dispose);

      expect(session.activeCut.metadata.thumbnailFrameIndex, isNull);
      expect(session.isActiveCutThumbnailPinnedHere, isFalse);

      session.toggleActiveCutThumbnailFrame();
      expect(session.activeCut.metadata.thumbnailFrameIndex, 0);
      expect(session.isActiveCutThumbnailPinnedHere, isTrue);

      session.selectFrameIndex(5);
      expect(session.isActiveCutThumbnailPinnedHere, isFalse);
      session.toggleActiveCutThumbnailFrame();
      expect(session.activeCut.metadata.thumbnailFrameIndex, 5);

      // Pressing on the pinned frame releases the pin.
      session.toggleActiveCutThumbnailFrame();
      expect(session.activeCut.metadata.thumbnailFrameIndex, isNull);

      session.undo();
      expect(session.activeCut.metadata.thumbnailFrameIndex, 5);
      session.undo();
      expect(session.activeCut.metadata.thumbnailFrameIndex, 0);
    });
  });

  group('storyboard toolbar button', () {
    testWidgets('toggles the pin and reflects it in the icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomePage(initialProject: createDefaultProject())),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-mode-storyboard-button')),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(
        const ValueKey<String>('set-cut-thumbnail-button'),
      );
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.image)),
        findsNothing,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.image)),
        findsOneWidget,
        reason: 'pinned at the playhead frame: filled icon',
      );

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.image_outlined),
        ),
        findsOneWidget,
        reason: 'pressing on the pinned frame releases the pin',
      );
    });
  });
}
