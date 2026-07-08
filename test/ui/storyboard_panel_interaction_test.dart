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
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart'
    show TimelineBlockEdge;
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
      // Timeline-style frame-wide tint: sits ON the frame, one cell wide.
      expect(tester.widget<Positioned>(playhead).left, 30 * 8);
      expect(tester.widget<Positioned>(playhead).width, 8);
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

    testWidgets('pixelsPerFrame rescales blocks, ruler and playhead', (
      tester,
    ) async {
      Future<void> pumpAt(double pixelsPerFrame) {
        return _pumpStoryboardPanel(
          tester,
          _singleTrackProject([
            _cut('cut-a', name: 'Cut A'),
            _cut('cut-b', name: 'Cut B'),
          ]),
          activeCutId: const CutId('cut-a'),
          onCutSelected: (_) {},
          playheadGlobalFrame: 24,
          pixelsPerFrame: pixelsPerFrame,
        );
      }

      final blockA = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-a'),
      );
      final playhead = find.byKey(
        const ValueKey<String>('storyboard-playhead'),
      );

      await pumpAt(8);
      expect(tester.getSize(blockA).width, 24 * 8);
      expect(tester.widget<Positioned>(playhead).left, 24 * 8);

      await pumpAt(16);
      expect(tester.getSize(blockA).width, 24 * 16);
      expect(tester.widget<Positioned>(playhead).left, 24 * 16);

      // Fully zoomed out blocks stay frame-linear (no min-width overlap).
      await pumpAt(4);
      expect(tester.getSize(blockA).width, 24 * 4);
      final rightOfA = tester.getTopRight(blockA).dx;
      final leftOfB = tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
          )
          .dx;
      expect(rightOfA, lessThanOrEqualTo(leftOfB));
      expect(tester.takeException(), isNull);
    });

    testWidgets('thumbnails fill the block background, centered', (
      tester,
    ) async {
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 2), Paint());
        final picture = recorder.endRecording();
        try {
          return picture.toImage(4, 2);
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

      final thumb = find.byKey(
        const ValueKey<String>('storyboard-cut-thumb-cut-a'),
      );
      expect(thumb, findsOneWidget);
      // Centered inside the block (not a left strip).
      final blockCenter = tester
          .getCenter(
            find.byKey(const ValueKey<String>('storyboard-cut-block-cut-a')),
          )
          .dx;
      expect(
        tester.getCenter(thumb).dx,
        moreOrLessEquals(blockCenter, epsilon: 1),
      );
      // Pending cuts show the placeholder tile.
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-thumb-empty-cut-b')),
        findsOneWidget,
      );
      // The old duration/range row and ACTIVE badge are gone.
      expect(find.text('ACTIVE'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-duration-cut-a')),
        findsNothing,
      );
    });

    testWidgets('cut totals switch between frames and seconds', (tester) async {
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
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('storyboard-cut-total-cut-b')),
            )
            .data,
        '48f',
      );

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        showSeconds: true,
        projectFps: 24,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('storyboard-cut-total-cut-b')),
            )
            .data,
        '2+00',
      );
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

    testWidgets('cut edge grips report trim drags', (tester) async {
      final began = <(CutId, TimelineBlockEdge)>[];
      final updates = <int>[];
      var ended = 0;

      await _pumpStoryboardPanel(
        tester,
        _singleTrackProject([
          _cut('cut-a', name: 'Cut A'),
          _cut('cut-b', name: 'Cut B'),
        ]),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (_) {},
        cutTrim: StoryboardCutTrimCallbacks(
          onBegin: (cutId, edge) {
            began.add((cutId, edge));
            return true;
          },
          onUpdate: updates.add,
          onEnd: () => ended += 1,
          onCancel: () {},
        ),
      );

      // The first cut has no roll partner: no start grip; the second does.
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-edge-grip-start-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-edge-grip-start-1')),
        findsOneWidget,
      );

      final endGrip = find.byKey(
        const ValueKey<String>('storyboard-cut-edge-grip-end-0'),
      );
      expect(endGrip, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(endGrip));
      await gesture.moveBy(const Offset(19, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(16, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(began, [(const CutId('cut-a'), TimelineBlockEdge.end)]);
      expect(updates, isNotEmpty);
      expect(updates.last, greaterThanOrEqualTo(2));
      expect(ended, 1);
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

  group('StoryboardPanel zoom-around-playhead', () {
    testWidgets('zooming keeps a visible playhead at the same screen spot', (
      tester,
    ) async {
      Future<void> pumpAtZoom(double pixelsPerFrame) {
        return _pumpStoryboardPanel(
          tester,
          _singleTrackProject([
            _cut('cut-a', name: 'Cut A', duration: 60),
            _cut('cut-b', name: 'Cut B', duration: 60),
          ]),
          activeCutId: const CutId('cut-a'),
          onCutSelected: (_) {},
          playheadGlobalFrame: 30,
          pixelsPerFrame: pixelsPerFrame,
        );
      }

      await pumpAtZoom(8);
      final playhead = find.byKey(
        const ValueKey<String>('storyboard-playhead'),
      );
      final centerBefore = tester.getRect(playhead).center.dx;

      await pumpAtZoom(16);
      await tester.pumpAndSettle();

      expect(tester.getRect(playhead).center.dx, centerBefore);
    });

    testWidgets('zooming with the playhead off screen keeps the leading '
        'edge anchored', (tester) async {
      Future<void> pumpAtZoom(double pixelsPerFrame) {
        return _pumpStoryboardPanel(
          tester,
          _singleTrackProject([
            _cut('cut-a', name: 'Cut A', duration: 60),
            _cut('cut-b', name: 'Cut B', duration: 60),
          ]),
          activeCutId: const CutId('cut-a'),
          onCutSelected: (_) {},
          // Far beyond the viewport at either zoom.
          playheadGlobalFrame: 118,
          pixelsPerFrame: pixelsPerFrame,
        );
      }

      await pumpAtZoom(8);
      final blockA = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-a'),
      );
      final blockBefore = tester.getTopLeft(blockA).dx;

      await pumpAtZoom(16);
      await tester.pumpAndSettle();

      // Offset 0 scales to 0: the track start stays at the same edge.
      expect(tester.getTopLeft(blockA).dx, blockBefore);
    });
  });

  group('StoryboardPanel pinned ruler', () {
    testWidgets('the ruler stays put while tracks scroll vertically', (
      tester,
    ) async {
      // Enough tracks that the panel scrolls vertically.
      await _pumpStoryboardPanel(
        tester,
        _project([
          for (var index = 0; index < 10; index += 1)
            Track(
              id: TrackId('track-$index'),
              name: 'V${index + 1}',
              cuts: [_cut('cut-$index', name: 'Cut $index')],
            ),
        ]),
        activeCutId: const CutId('cut-0'),
        onCutSelected: (_) {},
      );

      final ruler = find.byKey(const ValueKey<String>('storyboard-ruler'));
      final firstRow = find.byKey(
        const ValueKey<String>('storyboard-track-row-track-0'),
      );
      final rulerTopLeft = tester.getTopLeft(ruler);
      final firstRowTop = tester.getTopLeft(firstRow).dy;

      await tester.drag(
        find.byKey(const ValueKey<String>('storyboard-vertical-viewport')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Tracks scrolled under the ruler; the ruler did not move.
      expect(tester.getTopLeft(firstRow).dy, lessThan(firstRowTop));
      expect(tester.getTopLeft(ruler), rulerTopLeft);
    });

    testWidgets('the pinned ruler follows horizontal scrolling with the '
        'blocks', (tester) async {
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
      final block = find.byKey(
        const ValueKey<String>('storyboard-cut-block-cut-a'),
      );
      final rulerX = tester.getTopLeft(ruler).dx;
      final blockX = tester.getTopLeft(block).dx;

      await tester.drag(
        find.byKey(
          const ValueKey<String>('storyboard-timeline-horizontal-viewport'),
        ),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();

      final rulerShift = rulerX - tester.getTopLeft(ruler).dx;
      final blockShift = blockX - tester.getTopLeft(block).dx;
      expect(rulerShift, greaterThan(0));
      // Frame labels stay aligned with the blocks under them.
      expect(rulerShift, blockShift);
    });
  });
}

Future<void> _pumpStoryboardPanel(
  WidgetTester tester,
  Project project, {
  required CutId activeCutId,
  required ValueChanged<CutId> onCutSelected,
  CutReorderedCallback? onCutReordered,
  StoryboardCutTrimCallbacks? cutTrim,
  int? playheadGlobalFrame,
  ValueChanged<int>? onSeekGlobalFrame,
  ui.Image? Function(Cut cut)? thumbnailFor,
  double pixelsPerFrame = 8,
  bool showSeconds = false,
  int projectFps = 24,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoryboardPanel(
          project: project,
          activeCutId: activeCutId,
          onCutSelected: onCutSelected,
          onCutReordered: onCutReordered,
          cutTrim: cutTrim,
          playheadGlobalFrame: playheadGlobalFrame,
          onSeekGlobalFrame: onSeekGlobalFrame,
          thumbnailFor: thumbnailFor,
          pixelsPerFrame: pixelsPerFrame,
          showSeconds: showSeconds,
          projectFps: projectFps,
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

Cut _cut(
  String id, {
  required String name,
  List<Layer>? layers,
  int duration = 24,
}) {
  return Cut(
    id: CutId(id),
    name: name,
    duration: duration,
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
