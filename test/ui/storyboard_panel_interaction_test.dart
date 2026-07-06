import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';

void main() {
  group('StoryboardPanel cut selection interactions', () {
    testWidgets('tapping an inactive cut calls onCutSelected once', (
      tester,
    ) async {
      final selectedCutIds = <CutId>[];

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: selectedCutIds.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
      );
      await tester.pumpAndSettle();

      expect(selectedCutIds, [const CutId('cut-b')]);
    });

    testWidgets('tapping the active cut does not call onCutSelected', (
      tester,
    ) async {
      final selectedCutIds = <CutId>[];

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: selectedCutIds.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-a')),
      );
      await tester.pumpAndSettle();

      expect(selectedCutIds, isEmpty);
    });

    testWidgets('cut selection works across multiple tracks', (tester) async {
      final selectedCutIds = <CutId>[];

      await _pumpStoryboardPanel(
        tester,
        _project([
          Track(
            id: const TrackId('track-a'),
            name: 'V1',
            cuts: [_cut('cut-a', name: 'Cut A')],
          ),
          Track(
            id: const TrackId('track-b'),
            name: 'V2',
            cuts: [_cut('cut-b', name: 'Cut B')],
          ),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: selectedCutIds.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
      );
      await tester.pumpAndSettle();

      expect(selectedCutIds, [const CutId('cut-b')]);
    });

    testWidgets('selection uses CutId identity, not cut name', (tester) async {
      final selectedCutIds = <CutId>[];

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Duplicate Cut'),
          _cut('cut-b', name: 'Duplicate Cut'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: selectedCutIds.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Cut'), findsNWidgets(2));
      expect(selectedCutIds, [const CutId('cut-b')]);
    });

    testWidgets(
      'storyboard layer presence does not change inactive cut selection',
      (tester) async {
        final selectedCutIds = <CutId>[];

        await _pumpStoryboardPanel(
          tester,
          _singleTrackProject([
            _cut(
              'cut-a',
              name: 'Cut A',
              layers: [_storyboardLayer('storyboard-a')],
            ),
            _cut('cut-b', name: 'Cut B'),
          ]),
          activeCutId: const CutId('cut-a'),
          onCutSelected: selectedCutIds.add,
        );

        expect(
          find.byKey(const ValueKey<String>('storyboard-layer-strip-cut-a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('storyboard-layer-empty-cut-b')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
        );
        await tester.pumpAndSettle();

        expect(selectedCutIds, [const CutId('cut-b')]);
      },
    );

    testWidgets(
      'storyboard layer absence does not change inactive cut selection',
      (tester) async {
        final selectedCutIds = <CutId>[];

        await _pumpStoryboardPanel(
          tester,
          _singleTrackProject([
            _cut('cut-a', name: 'Cut A'),
            _cut('cut-b', name: 'Cut B'),
          ]),
          activeCutId: const CutId('cut-a'),
          onCutSelected: selectedCutIds.add,
        );

        expect(
          find.byKey(const ValueKey<String>('storyboard-layer-empty-cut-a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('storyboard-layer-empty-cut-b')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
        );
        await tester.pumpAndSettle();

        expect(selectedCutIds, [const CutId('cut-b')]);
      },
    );
  });

  group('StoryboardPanel cut drag reorder', () {
    testWidgets('dragging a block onto another emits the target index', (
      tester,
    ) async {
      CutId? reorderedCutId;
      TrackId? capturedTargetTrackId;
      int? capturedTargetCutIndex;

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
          _cut('cut-c', name: 'Cut C'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        onCutReordered:
            ({
              required CutId draggedCutId,
              required TrackId targetTrackId,
              required int targetCutIndex,
            }) {
              reorderedCutId = draggedCutId;
              capturedTargetTrackId = targetTrackId;
              capturedTargetCutIndex = targetCutIndex;
            },
      );

      final source = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-a'),
      );
      final target = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-c'),
      );
      await tester.dragFrom(
        tester.getCenter(source),
        tester.getCenter(target) - tester.getCenter(source),
      );
      await tester.pumpAndSettle();

      expect(reorderedCutId, const CutId('cut-a'));
      expect(capturedTargetTrackId, const TrackId('track-a'));
      expect(capturedTargetCutIndex, 2);
    });

    testWidgets('dropping a block onto itself does not reorder', (
      tester,
    ) async {
      var reorderCalls = 0;

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        onCutReordered:
            ({
              required CutId draggedCutId,
              required TrackId targetTrackId,
              required int targetCutIndex,
            }) {
              reorderCalls += 1;
            },
      );

      final source = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-a'),
      );
      await tester.dragFrom(tester.getCenter(source), const Offset(4, 0));
      await tester.pumpAndSettle();

      expect(reorderCalls, 0);
    });

    testWidgets('without onCutReordered blocks are not draggable', (
      tester,
    ) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-draggable-cut-a')),
        findsNothing,
      );
    });

    testWidgets('a single-cut track is not draggable', (tester) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([_cut('cut-a', name: 'Cut A')]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        onCutReordered:
            ({
              required CutId draggedCutId,
              required TrackId targetTrackId,
              required int targetCutIndex,
            }) {},
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-draggable-cut-a')),
        findsNothing,
      );
    });

    testWidgets('ruler tap seeks the frame under the pointer', (tester) async {
      final seekedFrames = <int>[];

      // Two 24-frame cuts: the ruler spans 48 frames at 8px each.
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        onSeekGlobalFrame: seekedFrames.add,
      );

      final ruler = find.byKey(const ValueKey<String>('storyboard-ruler'));
      expect(ruler, findsOneWidget);

      final topLeft = tester.getTopLeft(ruler);
      // Frame 30 starts at 240px; tap inside its cell.
      await tester.tapAt(topLeft + const Offset(30 * 8 + 3, 10));
      await tester.pumpAndSettle();

      expect(seekedFrames, [30]);
    });

    testWidgets('ruler scrub reports frames while dragging', (tester) async {
      final seekedFrames = <int>[];

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        onSeekGlobalFrame: seekedFrames.add,
      );

      final topLeft = tester.getTopLeft(
        find.byKey(const ValueKey<String>('storyboard-ruler')),
      );
      final gesture = await tester.startGesture(
        topLeft + const Offset(8 * 8 + 3, 10),
      );
      await gesture.moveBy(const Offset(8 * 8, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(seekedFrames.first, 8);
      expect(seekedFrames.last, 16);
    });

    testWidgets('playhead line sits on the global frame', (tester) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        playheadGlobalFrame: 30,
      );

      final playhead = find.byKey(
        const ValueKey<String>('storyboard-playhead'),
      );
      expect(playhead, findsOneWidget);
      // 30 frames × 8px, minus the 1px centering of the 2px line.
      expect(tester.widget<Positioned>(playhead).left, 30 * 8 - 1);
    });

    testWidgets('no playhead line without a frame', (tester) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([_cut('cut-a', name: 'Cut A')]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-playhead')),
        findsNothing,
      );
    });

    testWidgets('blocks show resolver thumbnails, placeholder when pending', (
      tester,
    ) async {
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint());
        final picture = recorder.endRecording();
        try {
          return picture.toImage(2, 2);
        } finally {
          picture.dispose();
        }
      });
      addTearDown(() => image!.dispose());

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        thumbnailFor: (cut) => cut.id == const CutId('cut-a') ? image : null,
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-thumb-cut-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-thumb-empty-cut-b')),
        findsOneWidget,
      );
    });

    testWidgets('no thumbnail slots without a resolver', (tester) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([_cut('cut-a', name: 'Cut A')]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-thumb-empty-cut-a')),
        findsNothing,
      );
    });

    testWidgets('zoom buttons rescale blocks, ruler and playhead', (
      tester,
    ) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        playheadGlobalFrame: 24,
      );

      final blockA = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-a'),
      );
      final playhead = find.byKey(
        const ValueKey<String>('storyboard-playhead'),
      );
      expect(tester.getSize(blockA).width, 24 * 8);
      expect(tester.widget<Positioned>(playhead).left, 24 * 8 - 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-in-button')),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(blockA).width, 24 * 16);
      expect(tester.widget<Positioned>(playhead).left, 24 * 16 - 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-out-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-out-button')),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(blockA).width, 24 * 4);
    });

    testWidgets('zoom-out keeps blocks frame-linear (no overlap)', (
      tester,
    ) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
      );

      // Two zoom-outs: 24-frame cuts at 2px/frame are 48px wide — far
      // below the old 96px minimum that made neighbours overlap.
      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-out-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-out-button')),
      );
      await tester.pumpAndSettle();

      final rightOfA = tester
          .getTopRight(
            find.byKey(const ValueKey<String>('storyboard-cut-block-cut-a')),
          )
          .dx;
      final leftOfB = tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
          )
          .dx;
      expect(rightOfA, lessThanOrEqualTo(leftOfB));

      // Fully zoomed out: the out button disables.
      final zoomOut = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('storyboard-zoom-out-button'),
          ),
          matching: find.byType(IconButton),
        ),
      );
      expect(zoomOut.onPressed, isNull);
    });

    testWidgets('narrow blocks drop the thumbnail slot', (tester) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        thumbnailFor: (_) => null,
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-thumb-empty-cut-a')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-out-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-zoom-out-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-thumb-empty-cut-a')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('frame axis extends endlessly while scrolling right', (
      tester,
    ) async {
      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
      );

      final ruler = find.byKey(const ValueKey<String>('storyboard-ruler'));
      final initialWidth = tester.getSize(ruler).width;

      for (var i = 0; i < 3; i += 1) {
        await tester.drag(
          find.byKey(
            const ValueKey<String>('storyboard-timeline-horizontal-viewport'),
          ),
          const Offset(-1200, 0),
        );
        await tester.pumpAndSettle();
      }

      expect(tester.getSize(ruler).width, greaterThan(initialWidth));
    });

    testWidgets('tap-to-select still works when dragging is enabled', (
      tester,
    ) async {
      final selectedCutIds = <CutId>[];

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: selectedCutIds.add,
        onCutReordered:
            ({
              required CutId draggedCutId,
              required TrackId targetTrackId,
              required int targetCutIndex,
            }) {},
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
      );
      await tester.pumpAndSettle();

      expect(selectedCutIds, [const CutId('cut-b')]);
    });
  });
}

Future<void> _pumpStoryboardPanel(
  WidgetTester tester,
  Project project, {
  required CutId activeCutId,
  required ValueChanged<CutId> onCutSelected,
  CutReorderedCallback? onCutReordered,
  int? playheadGlobalFrame,
  ValueChanged<int>? onSeekGlobalFrame,
  ui.Image? Function(Cut cut)? thumbnailFor,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoryboardPanel(
          project: project,
          activeCutId: activeCutId,
          onCutSelected: onCutSelected,
          onCutReordered: onCutReordered,
          playheadGlobalFrame: playheadGlobalFrame,
          onSeekGlobalFrame: onSeekGlobalFrame,
          thumbnailFor: thumbnailFor,
        ),
      ),
    ),
  );
}

Project _singleTrackProject(List<Cut> cuts) {
  return _project([
    Track(id: const TrackId('track-a'), name: 'Track A', cuts: cuts),
  ]);
}

Project _project(List<Track> tracks) {
  return Project(
    id: const ProjectId('project-storyboard-interactions'),
    name: 'Project Storyboard Interactions',
    createdAt: DateTime.utc(2026, 6, 21),
    tracks: tracks,
  );
}

Cut _cut(String id, {required String name, List<Layer>? layers}) {
  return Cut(
    id: CutId(id),
    name: name,
    duration: 24,
    canvasSize: const CanvasSize(width: 1280, height: 720),
    layers: layers ?? [_animationLayer('animation-$id')],
  );
}

Layer _animationLayer(String id) {
  return _layer(id, LayerKind.animation, name: 'Animation $id');
}

Layer _storyboardLayer(String id) {
  return _layer(id, LayerKind.storyboard, name: 'Storyboard $id');
}

Layer _layer(String id, LayerKind kind, {required String name}) {
  return Layer(
    id: LayerId(id),
    name: name,
    kind: kind,
    frames: [Frame(id: FrameId('frame-$id'), duration: 1, strokes: const [])],
  );
}
