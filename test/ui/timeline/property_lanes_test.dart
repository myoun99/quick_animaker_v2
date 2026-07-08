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
import 'package:quick_animaker_v2/src/ui/timeline/transform_lane_editing.dart';
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

  group('collapsed camera row key-union summary', () {
    Finder cameraCell(int frame) =>
        find.byKey(ValueKey<String>('timeline-cell-lane-cam-layer-$frame'));

    testWidgets('keyed frames show ◆ markers instead of paper cells', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(0), 8: _pose(80)})),
      );

      expect(
        find.descendant(of: cameraCell(0), matching: find.text('◆')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cameraCell(8), matching: find.text('◆')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cameraCell(4), matching: find.text('◆')),
        findsNothing,
      );
      // The old paper-cell ○ glyph is gone from the camera row.
      final rowArea = find.byKey(
        const ValueKey<String>('timeline-frame-row-area-lane-cam-layer'),
      );
      expect(
        find.descendant(of: rowArea, matching: find.text('○')),
        findsNothing,
      );
      expect(find.bySemanticsLabel('camera keyframe'), findsNWidgets(2));
    });

    testWidgets('a frame whose keyed lanes ALL hold shows ■', (tester) async {
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
              rotation: PropertyTrack<double>()
                  .withKey(8, 12, interpolation: PropertyKeyInterpolation.hold)
                  .withKey(8, 12),
            ),
          ),
        ),
      );

      expect(
        find.descendant(of: cameraCell(4), matching: find.text('■')),
        findsOneWidget,
      );
      // A linear key (the second withKey overwrote hold with the default
      // linear) reads ◆ even when another lane would hold elsewhere.
      expect(
        find.descendant(of: cameraCell(8), matching: find.text('◆')),
        findsOneWidget,
      );
    });
  });

  group('transform lane editing policy', () {
    test('toggle adds a key with the resolved value and removes it again', () {
      final track = TransformTrack(keyframes: {0: _pose(0), 8: _pose(80)});

      final added = transformTrackWithLaneKeyToggled(
        track,
        laneId: 'position',
        frameIndex: 4,
        resolvedPose: track.resolveAt(frameIndex: 4, orElse: () => _pose(0)),
      )!;
      expect(added.position.keyAt(4)!.value, CanvasPoint(x: 40, y: 40));
      // Only the position lane changed.
      expect(added.scale.keyAt(4), isNull);

      final removed = transformTrackWithLaneKeyToggled(
        added,
        laneId: 'position',
        frameIndex: 4,
        resolvedPose: _pose(0),
      )!;
      expect(removed.position.keyAt(4), isNull);
    });

    test('move keeps value + interpolation and overwrites the target', () {
      final track = TransformTrack.empty().copyWith(
        scale: PropertyTrack<double>()
            .withKey(2, 1.5, interpolation: PropertyKeyInterpolation.hold)
            .withKey(6, 3),
      );

      final moved = transformTrackWithLaneKeyMoved(
        track,
        laneId: 'scale',
        fromFrame: 2,
        toFrame: 6,
      )!;

      expect(moved.scale.keyAt(2), isNull);
      expect(moved.scale.keyAt(6)!.value, 1.5);
      expect(
        moved.scale.keyAt(6)!.interpolation,
        PropertyKeyInterpolation.hold,
      );
    });

    test('move to a negative frame or same frame is a no-op', () {
      final track = TransformTrack.empty().copyWith(
        rotation: PropertyTrack<double>().withKey(3, 45),
      );

      expect(
        transformTrackWithLaneKeyMoved(
          track,
          laneId: 'rotation',
          fromFrame: 3,
          toFrame: 3,
        ),
        isNull,
      );
      expect(
        transformTrackWithLaneKeyMoved(
          track,
          laneId: 'rotation',
          fromFrame: 3,
          toFrame: -1,
        ),
        isNull,
      );
    });

    test('value edits parse AE units and preserve interpolation', () {
      final track = TransformTrack.empty().copyWith(
        scale: PropertyTrack<double>().withKey(
          0,
          1,
          interpolation: PropertyKeyInterpolation.hold,
        ),
      );

      final scaled = transformTrackWithLaneValueEdited(
        track,
        laneId: 'scale',
        frameIndex: 0,
        input: '250%',
      )!;
      expect(scaled.scale.keyAt(0)!.value, 2.5);
      expect(
        scaled.scale.keyAt(0)!.interpolation,
        PropertyKeyInterpolation.hold,
        reason: 'editing a value keeps the key interpolation',
      );

      final positioned = transformTrackWithLaneValueEdited(
        track,
        laneId: 'position',
        frameIndex: 4,
        input: ' 320, 180 ',
      )!;
      expect(positioned.position.keyAt(4)!.value, CanvasPoint(x: 320, y: 180));

      final rotated = transformTrackWithLaneValueEdited(
        track,
        laneId: 'rotation',
        frameIndex: 2,
        input: '-45°',
      )!;
      expect(rotated.rotation.keyAt(2)!.value, -45);

      // Garbage input is rejected.
      expect(
        transformTrackWithLaneValueEdited(
          track,
          laneId: 'scale',
          frameIndex: 0,
          input: 'abc',
        ),
        isNull,
      );
      expect(
        transformTrackWithLaneValueEdited(
          track,
          laneId: 'position',
          frameIndex: 0,
          input: '12',
        ),
        isNull,
      );
    });

    test('hold toggle flips a key between linear and hold', () {
      final track = TransformTrack.empty().copyWith(
        rotation: PropertyTrack<double>().withKey(3, 45),
      );

      final held = transformTrackWithLaneHoldToggled(
        track,
        laneId: 'rotation',
        frameIndex: 3,
      )!;
      expect(
        held.rotation.keyAt(3)!.interpolation,
        PropertyKeyInterpolation.hold,
      );

      final linear = transformTrackWithLaneHoldToggled(
        held,
        laneId: 'rotation',
        frameIndex: 3,
      )!;
      expect(
        linear.rotation.keyAt(3)!.interpolation,
        PropertyKeyInterpolation.linear,
      );
    });
  });

  group('camera lane key editing in the timeline', () {
    Future<void> expand(WidgetTester tester) async {
      await tester.tap(find.byKey(_laneToggleKey));
      await tester.pumpAndSettle();
    }

    testWidgets('the navigator diamond toggles a key at the playhead on '
        'ONE lane', (tester) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(0), 8: _pose(80)})),
      );
      await expand(tester);

      // Playhead starts at frame 0 where all lanes are keyed; toggling the
      // position lane removes only its key.
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'timeline-lane-key-toggle-lane-cam-layer-position',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_laneKey('position', 0), findsNothing);
      expect(_laneKey('scale', 0), findsOneWidget);

      // Toggling again re-keys the property at its resolved value.
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'timeline-lane-key-toggle-lane-cam-layer-position',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_laneKey('position', 0), findsOneWidget);

      // One undo step per toggle.
      await tester.tap(find.byKey(const ValueKey<String>('undo-button')));
      await tester.pumpAndSettle();
      expect(_laneKey('position', 0), findsNothing);
    });

    testWidgets('dragging a marker moves the key (frame-snapped)', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(0), 8: _pose(80)})),
      );
      await expand(tester);

      // Default zoom = 48px per frame: +96px = +2 frames.
      await tester.drag(_laneKey('position', 8), const Offset(96, 0));
      await tester.pumpAndSettle();

      expect(_laneKey('position', 8), findsNothing);
      expect(_laneKey('position', 10), findsOneWidget);
      // Other lanes keep their key at 8.
      expect(_laneKey('scale', 8), findsOneWidget);
    });

    testWidgets('the long-press menu deletes a key', (tester) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(0), 8: _pose(80)})),
      );
      await expand(tester);

      await tester.ensureVisible(_laneKey('rotation', 8));
      await tester.pumpAndSettle();
      await tester.longPress(_laneKey('rotation', 8));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('lane-key-menu-delete')),
      );
      await tester.pumpAndSettle();

      expect(_laneKey('rotation', 8), findsNothing);
      expect(_laneKey('position', 8), findsOneWidget);
    });

    testWidgets('the value column shows AE units and typing keys the '
        'value at the playhead', (tester) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(100), 8: _pose(80)})),
      );
      await expand(tester);

      // Resolved values at the playhead (frame 0), AE display units.
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(
                  const ValueKey<String>(
                    'timeline-lane-value-lane-cam-layer-scale',
                  ),
                ),
                matching: find.byType(Text),
              ),
            )
            .data,
        '150%',
      );

      // Type a new scale: Enter commits and keys the value there.
      await tester.tap(
        find.byKey(
          const ValueKey<String>('timeline-lane-value-lane-cam-layer-scale'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>(
            'timeline-lane-value-field-lane-cam-layer-scale',
          ),
        ),
        '200%',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(
                  const ValueKey<String>(
                    'timeline-lane-value-lane-cam-layer-scale',
                  ),
                ),
                matching: find.byType(Text),
              ),
            )
            .data,
        '200%',
      );
      // The scale lane stays keyed at frame 0 with the new value; other
      // lanes are untouched.
      expect(_laneKey('scale', 0), findsOneWidget);
    });

    test('scrubTransformLaneValue maps drag axes onto components in the '
        'editor text form', () {
      expect(
        scrubTransformLaneValue('position', '12, -3', const Offset(10, 5)),
        '22, 2',
      );
      expect(
        scrubTransformLaneValue('scale', '150%', const Offset(40, 0)),
        '170%',
      );
      expect(
        scrubTransformLaneValue('rotation', '0°', const Offset(-10, 0)),
        '-5°',
      );
      expect(scrubTransformLaneValue('opacity', '100', Offset.zero), isNull);
      expect(
        scrubTransformLaneValue('scale', 'garbage', const Offset(1, 0)),
        isNull,
      );
    });

    testWidgets('dragging the value scrubs it and commits ONE key on '
        'release', (tester) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(100), 8: _pose(80)})),
      );
      await expand(tester);

      // +40px horizontally = +20% at the scale lane's 0.5%/px rate.
      await tester.drag(
        find.byKey(
          const ValueKey<String>('timeline-lane-value-lane-cam-layer-scale'),
        ),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(
                  const ValueKey<String>(
                    'timeline-lane-value-lane-cam-layer-scale',
                  ),
                ),
                matching: find.byType(Text),
              ),
            )
            .data,
        '170%',
      );
      expect(_laneKey('scale', 0), findsOneWidget);
    });

    testWidgets('prev/next navigator jumps the playhead between keys', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(camera: CutCamera(keyframes: {0: _pose(0), 8: _pose(80)})),
      );
      await expand(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'timeline-lane-next-key-lane-cam-layer-position',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey<String>('timeline-current-frame-counter'),
              ),
            )
            .data,
        '9',
      );
    });
  });
}
