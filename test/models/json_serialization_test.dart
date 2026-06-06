import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/stroke.dart';
import 'package:quick_animaker_v2/src/models/stroke_id.dart';
import 'package:quick_animaker_v2/src/models/stroke_point.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';

void main() {
  frameNameJsonTests();
  test('round-trips a full project hierarchy through JSON', () {
    final project = Project(
      id: const ProjectId('project-1'),
      name: 'Project',
      tracks: [
        Track(
          id: const TrackId('track-1'),
          name: 'Video',
          cuts: [
            Cut(
              id: const CutId('cut-1'),
              name: 'Cut 1',
              layers: [
                Layer(
                  id: const LayerId('layer-1'),
                  name: 'Line',
                  frames: [
                    Frame(
                      id: const FrameId('frame-1'),
                      duration: 2,
                      strokes: [
                        Stroke(
                          id: const StrokeId('stroke-1'),
                          points: const [
                            StrokePoint(x: 10.5, y: 20.25),
                            StrokePoint(x: 30.5, y: 40.25),
                          ],
                          brushSettings: const BrushSettings(
                            color: 0xFFFFFFFF,
                            size: 6,
                            opacity: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              duration: 48,
              canvasSize: const CanvasSize(width: 1920, height: 1080),
            ),
          ],
        ),
      ],
      createdAt: DateTime.utc(2026, 6, 2),
      fps: 24,
    );

    final restored = Project.fromJson(project.toJson());

    expect(restored, project);
    expect(restored.toJson(), project.toJson());
  });

  test('layer timeline map serializes and deserializes blank entries', () {
    final layer = Layer(
      id: const LayerId('layer-timeline'),
      name: 'Timeline Layer',
      frames: [
        Frame(id: const FrameId('frame-a'), duration: 2, strokes: const []),
      ],
      timeline: {
        0: TimelineExposure.drawing(const FrameId('frame-a')),
        6: const TimelineExposure.blank(),
      },
    );

    final restored = Layer.fromJson(layer.toJson());

    expect(restored, layer);
    expect(restored.timeline[6], const TimelineExposure.blank());
  });

  test(
    'old layer JSON without timeline derives timeline from frame durations',
    () {
      final json = {
        'id': const LayerId('old-layer').toJson(),
        'name': 'Old Layer',
        'frames': [
          Frame(
            id: const FrameId('a'),
            duration: 3,
            strokes: const [],
          ).toJson(),
          Frame(
            id: const FrameId('b'),
            duration: 2,
            strokes: const [],
          ).toJson(),
        ],
        'isVisible': true,
        'opacity': 1.0,
      };

      final layer = Layer.fromJson(json);

      expect(layer.timeline[0], TimelineExposure.drawing(const FrameId('a')));
      expect(layer.timeline[3], TimelineExposure.drawing(const FrameId('b')));
    },
  );
}

void frameNameJsonTests() {
  test('frame JSON includes name when present and round trips it', () {
    final frame = Frame(
      id: const FrameId('named-frame'),
      duration: 2,
      strokes: const [],
      name: 'A1',
    );

    final json = frame.toJson();
    final decoded = Frame.fromJson(json);

    expect(json['name'], 'A1');
    expect(decoded, frame);
  });

  test('old frame JSON without name loads with null name', () {
    final frame = Frame.fromJson({
      'id': const FrameId('old-frame').toJson(),
      'duration': 1,
      'strokes': const <dynamic>[],
    });

    expect(frame.name, isNull);
    expect(frame.toJson().containsKey('name'), isFalse);
  });
}
