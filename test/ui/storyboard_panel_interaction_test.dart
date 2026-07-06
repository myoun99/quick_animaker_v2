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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoryboardPanel(
          project: project,
          activeCutId: activeCutId,
          onCutSelected: onCutSelected,
          onCutReordered: onCutReordered,
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
