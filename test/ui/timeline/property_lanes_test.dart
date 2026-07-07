import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/camera_pose.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_camera.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/property_track.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/models/transform_track.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';
import 'package:quick_animaker_v2/src/ui/timeline/transform_lane_policy.dart';

const _cameraLayerId = LayerId('lane-cam-layer');
const _laneToggleKey = ValueKey<String>('timeline-lane-toggle-lane-cam-layer');

Project _project({CutCamera? camera}) {
  return Project(
    id: const ProjectId('lanes-project'),
    name: 'Lanes Project',
    createdAt: DateTime.utc(2026, 7, 7),
    tracks: [
      Track(
        id: const TrackId('lanes-track'),
        name: 'Video Track',
        cuts: [
          Cut(
            id: const CutId('lanes-cut'),
            name: 'Lanes Cut',
            duration: 12,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            camera: camera ?? CutCamera.empty(),
            layers: [
              Layer(
                id: const LayerId('lane-draw-layer'),
                name: 'Drawing',
                frames: const [],
              ),
              Layer(
                id: _cameraLayerId,
                name: 'Camera',
                kind: LayerKind.camera,
                frames: const [],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CameraPose _pose(double x) => CameraPose(
  center: CanvasPoint(x: x, y: x),
  zoom: 1.5,
);

Future<void> _pump(WidgetTester tester, Project project) async {
  await tester.pumpWidget(MaterialApp(home: HomePage(initialProject: project)));
  await tester.pumpAndSettle();
}

Finder _laneLabel(String laneId) =>
    find.byKey(ValueKey<String>('timeline-lane-label-lane-cam-layer-$laneId'));

Finder _laneKey(String laneId, int frame) => find.byKey(
  ValueKey<String>('timeline-lane-key-lane-cam-layer-$laneId-$frame'),
);

void main() {
  group('buildTimelineDisplayRows', () {
    test('interleaves lane rows under expanded layers only', () {
      final drawing = Layer(
        id: const LayerId('a'),
        name: 'A',
        frames: const [],
      );
      final camera = Layer(
        id: const LayerId('cam'),
        name: 'Cam',
        kind: LayerKind.camera,
        frames: const [],
      );
      const lane = PropertyLaneRow(
        laneId: 'position',
        label: 'Position',
        keyedFrames: {1},
      );

      final collapsed = buildTimelineDisplayRows(
        layers: [drawing, camera],
        expandedLayerIds: const {},
        lanesForLayer: (layer) =>
            layer.kind == LayerKind.camera ? const [lane] : const [],
      );
      expect(collapsed.length, 2);
      expect(collapsed.every((row) => !row.isLane), isTrue);

      final expanded = buildTimelineDisplayRows(
        layers: [drawing, camera],
        expandedLayerIds: {const LayerId('cam')},
        lanesForLayer: (layer) =>
            layer.kind == LayerKind.camera ? const [lane] : const [],
      );
      expect(expanded.length, 3);
      expect(expanded[2].isLane, isTrue);
      expect(expanded[2].layer.id, const LayerId('cam'));
      // Lane rows keep their layer's index so section dividers stay put.
      expect(expanded[2].layerIndex, 1);
    });
  });

  group('transformPropertyLanes', () {
    test('exposes the AE transform group with keyed/hold frames', () {
      final track = TransformTrack.empty().copyWith(
        position: PropertyTrack<CanvasPoint>()
            .withKey(0, CanvasPoint(x: 0, y: 0))
            .withKey(
              6,
              CanvasPoint(x: 5, y: 5),
              interpolation: PropertyKeyInterpolation.hold,
            ),
        rotation: PropertyTrack<double>().withKey(3, 90),
      );

      final lanes = transformPropertyLanes(track);

      expect(lanes.map((lane) => lane.laneId), [
        'position',
        'scale',
        'rotation',
      ]);
      expect(lanes[0].keyedFrames, {0, 6});
      expect(lanes[0].holdOutFrames, {6});
      expect(lanes[1].keyedFrames, isEmpty);
      expect(lanes[2].keyedFrames, {3});
    });
  });

  group('camera property lanes in the timeline', () {
    testWidgets('twirl-down shows the AE transform lanes with key '
        'diamonds', (tester) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(0), 8: _pose(80)})),
      );

      // Collapsed by default: chevron present, lanes hidden.
      expect(find.byKey(_laneToggleKey), findsOneWidget);
      expect(_laneLabel('position'), findsNothing);

      await tester.tap(find.byKey(_laneToggleKey));
      await tester.pumpAndSettle();

      // The whole AE Transform group twirls down.
      expect(_laneLabel('position'), findsOneWidget);
      expect(_laneLabel('scale'), findsOneWidget);
      expect(_laneLabel('rotation'), findsOneWidget);
      // Pose keys write synchronized keys on all three lanes.
      for (final laneId in ['position', 'scale', 'rotation']) {
        expect(_laneKey(laneId, 0), findsOneWidget);
        expect(_laneKey(laneId, 8), findsOneWidget);
      }

      await tester.tap(find.byKey(_laneToggleKey));
      await tester.pumpAndSettle();
      expect(_laneLabel('position'), findsNothing);
    });

    testWidgets('independently keyed properties diamond only their own '
        'lane', (tester) async {
      await _pump(
        tester,
        _project(
          camera: CutCamera.fromTrack(
            TransformTrack.empty().copyWith(
              position: PropertyTrack<CanvasPoint>().withKey(
                4,
                CanvasPoint(x: 1, y: 1),
                interpolation: PropertyKeyInterpolation.hold,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(_laneToggleKey));
      await tester.pumpAndSettle();

      expect(_laneKey('position', 4), findsOneWidget);
      expect(_laneKey('scale', 4), findsNothing);
      expect(_laneKey('rotation', 4), findsNothing);
    });

    testWidgets('drawing layers have no lane toggle yet', (tester) async {
      await _pump(tester, _project());

      expect(
        find.byKey(
          const ValueKey<String>('timeline-lane-toggle-lane-draw-layer'),
        ),
        findsNothing,
      );
    });
  });
}
