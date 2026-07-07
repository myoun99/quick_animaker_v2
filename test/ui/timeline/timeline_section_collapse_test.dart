import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_section_policy.dart';

Layer _layer(String id, LayerKind kind) {
  return Layer(
    id: LayerId(id),
    name: id,
    kind: kind,
    frames: const [],
    timeline: const {},
  );
}

Project _project() {
  return Project(
    id: const ProjectId('fold-project'),
    name: 'Fold Project',
    createdAt: DateTime.utc(2026, 7, 8),
    tracks: [
      Track(
        id: const TrackId('fold-track'),
        name: 'Video',
        cuts: [
          Cut(
            id: const CutId('fold-cut'),
            name: 'Fold Cut',
            duration: 12,
            canvasSize: const CanvasSize(width: 640, height: 360),
            layers: [
              _layer('cel-a', LayerKind.animation),
              _layer('se-1', LayerKind.se),
              _layer('se-2', LayerKind.se),
              _layer('cam-inst', LayerKind.instruction),
              _layer('cam', LayerKind.camera),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(home: HomePage(initialProject: _project())),
  );
  await tester.pumpAndSettle();
}

Finder _row(String layerId) =>
    find.byKey(ValueKey<String>('timeline-layer-row-$layerId'));

/// Taps near a section bracket/strip's top-left corner: a long bracket
/// segment's CENTER can sit below the test viewport's fold, where a plain
/// tap() silently misses.
Future<void> _tapSectionControl(WidgetTester tester, Finder finder) async {
  await tester.tapAt(tester.getRect(finder).topLeft + const Offset(10, 8));
  await tester.pumpAndSettle();
}

void main() {
  group('buildTimelineDisplayRows collapsedSections', () {
    test('folds a section to one anchored stub row', () {
      final layers = [
        _layer('cel-a', LayerKind.animation),
        _layer('se-1', LayerKind.se),
        _layer('se-2', LayerKind.se),
        _layer('cam', LayerKind.camera),
      ];

      final rows = buildTimelineDisplayRows(
        layers: layers,
        expandedLayerIds: const {},
        lanesForLayer: (_) => const [],
        collapsedSections: const {TimelineSection.se},
      );

      expect(rows, hasLength(3));
      expect(rows[0].layer.id, const LayerId('cel-a'));
      expect(rows[1].isSectionStub, isTrue);
      expect(rows[1].stubSection, TimelineSection.se);
      expect(rows[1].layer.id, const LayerId('se-1'), reason: 'anchor');
      expect(rows[1].layerIndex, 1, reason: 'divider position');
      expect(rows[2].layer.id, const LayerId('cam'));
    });

    test('collapsed sections drop their lane rows too', () {
      final camera = _layer('cam', LayerKind.camera);
      final rows = buildTimelineDisplayRows(
        layers: [_layer('cel-a', LayerKind.animation), camera],
        expandedLayerIds: {camera.id},
        lanesForLayer: (layer) => layer.kind == LayerKind.camera
            ? const [
                PropertyLaneRow(
                  laneId: 'position',
                  label: 'Position',
                  keyedFrames: {},
                ),
              ]
            : const [],
        collapsedSections: const {TimelineSection.camera},
      );

      expect(rows, hasLength(2));
      expect(rows[1].isSectionStub, isTrue);
      expect(rows.any((row) => row.isLane), isFalse);
    });
  });

  group('section gutter + fold in the horizontal timeline', () {
    testWidgets('gutter shows section labels; SE folds to a stub and back', (
      tester,
    ) async {
      await _pump(tester);

      // Collapsible sections carry the toggle on their bracket segment.
      expect(
        find.byKey(const ValueKey<String>('timeline-section-collapse-se')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-section-collapse-camera')),
        findsOneWidget,
      );
      // The drawing section prints its bracket label without a toggle.
      expect(find.text('ACTION'), findsOneWidget);

      await _tapSectionControl(
        tester,
        find.byKey(const ValueKey<String>('timeline-section-collapse-se')),
      );

      expect(_row('se-1'), findsNothing);
      expect(_row('se-2'), findsNothing);
      final stub = find.byKey(
        const ValueKey<String>('timeline-section-stub-rail-se'),
      );
      expect(stub, findsOneWidget);
      expect(find.text('SE · 2'), findsOneWidget);
      // The other sections stay.
      expect(_row('cel-a'), findsOneWidget);
      expect(_row('cam'), findsOneWidget);

      await _tapSectionControl(tester, stub);
      expect(_row('se-1'), findsOneWidget);
      expect(_row('se-2'), findsOneWidget);
      expect(stub, findsNothing);
    });

    testWidgets('bracket labels read from the right; a collapsed section '
        'folds to the slim strip with no frame row', (tester) async {
      await _pump(tester);

      // The bracket label is rotated to read bottom-to-top (tilt your head
      // RIGHT — the paper sheet's heading laid time-axis-horizontal).
      final rotated = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.text('ACTION'),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(rotated.quarterTurns, 3);

      await _tapSectionControl(
        tester,
        find.byKey(const ValueKey<String>('timeline-section-collapse-se')),
      );

      // Fully folded: the rail strip and the frame-area band are both slim
      // (22px, not a 52px row) and the frame band carries no cells.
      final railStrip = tester.getSize(
        find.byKey(const ValueKey<String>('timeline-section-stub-rail-se')),
      );
      expect(railStrip.height, 22);
      final cellsBand = tester.getSize(
        find.byKey(const ValueKey<String>('timeline-section-stub-row-se')),
      );
      expect(cellsBand.height, 22);
    });

    testWidgets('camera fold hides the camera AND instruction rows', (
      tester,
    ) async {
      await _pump(tester);

      await _tapSectionControl(
        tester,
        find.byKey(const ValueKey<String>('timeline-section-collapse-camera')),
      );

      expect(_row('cam'), findsNothing);
      expect(_row('cam-inst'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('timeline-section-stub-rail-camera')),
        findsOneWidget,
      );
    });
  });

  group('section fold in the X-sheet', () {
    testWidgets('fold state is shared across orientations', (tester) async {
      await _pump(tester);

      // Collapse SE in the horizontal timeline first.
      await _tapSectionControl(
        tester,
        find.byKey(const ValueKey<String>('timeline-section-collapse-se')),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('timeline-orientation-toggle-button'),
        ),
      );
      await tester.pumpAndSettle();

      // The X-sheet shows the same fold as a slim stub column.
      final stubHeader = find.byKey(
        const ValueKey<String>('xsheet-section-stub-header-se'),
      );
      expect(stubHeader, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('xsheet-layer-header-se-1')),
        findsNothing,
      );

      // Expand from the X-sheet; the columns return, and the section band
      // above the headers carries the fold chevron.
      await _tapSectionControl(tester, stubHeader);
      expect(
        find.byKey(const ValueKey<String>('xsheet-layer-header-se-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xsheet-section-collapse-se')),
        findsOneWidget,
      );
    });
  });
}
