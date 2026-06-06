import 'dart:convert';

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
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_mark.dart';
import 'package:quick_animaker_v2/src/services/project_json_serializer.dart';

void main() {
  group('ProjectJsonSerializer', () {
    const serializer = ProjectJsonSerializer();

    test('encodes a full project hierarchy to JSON', () {
      final project = _sampleProject();

      final jsonString = serializer.encode(project);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(jsonString, isNotEmpty);
      expect(decoded['name'], 'Sample Project');
      expect(decoded['fps'], 12);
      expect(decoded['tracks'], isA<List<dynamic>>());
    });

    test('decodes a full project hierarchy from JSON', () {
      final project = _sampleProject();
      final jsonString = serializer.encode(project);

      final restored = serializer.decode(jsonString);

      expect(restored, project);
    });

    test('preserves layer marks through JSON', () {
      final restored = serializer.decode(serializer.encode(_sampleProject()));

      expect(
        restored.tracks.single.cuts.single.layers.single.marks[3],
        const TimelineMark.inbetween(),
      );
      expect(
        restored.tracks.single.cuts.single.layers.single.frames,
        hasLength(1),
      );
      expect(
        restored.tracks.single.cuts.single.layers.single.timeline,
        hasLength(1),
      );
    });

    test('loads old layer JSON without marks as empty marks', () {
      final json = jsonDecode(serializer.encode(_sampleProject()))
          as Map<String, dynamic>;
      final layerJson = (((json['tracks'] as List<dynamic>).single
              as Map<String, dynamic>)['cuts']
          as List<dynamic>).single as Map<String, dynamic>;
      (((layerJson['layers'] as List<dynamic>).single)
          as Map<String, dynamic>).remove('marks');

      final restored = serializer.decode(jsonEncode(json));

      expect(restored.tracks.single.cuts.single.layers.single.marks, isEmpty);
    });

    test('rejects negative mark index in JSON', () {
      final json = jsonDecode(serializer.encode(_sampleProject()))
          as Map<String, dynamic>;
      final layer = ((((json['tracks'] as List<dynamic>).single
                      as Map<String, dynamic>)['cuts']
                  as List<dynamic>)
              .single as Map<String, dynamic>)['layers']
          as List<dynamic>;
      (layer.single as Map<String, dynamic>)['marks'] = [
        {
          'index': -1,
          'mark': {'type': 'inbetween'},
        },
      ];

      expect(() => serializer.decode(jsonEncode(json)), throwsFormatException);
    });

    test('throws a FormatException for invalid JSON', () {
      expect(() => serializer.decode('not json'), throwsFormatException);
    });

    test(
      'throws a FormatException when the root JSON value is not an object',
      () {
        expect(() => serializer.decode('[1, 2, 3]'), throwsFormatException);
      },
    );
  });
}

Project _sampleProject() {
  return Project(
    id: const ProjectId('project-1'),
    name: 'Sample Project',
    tracks: [_sampleTrack()],
    createdAt: DateTime.utc(2026, 6, 2, 12),
    fps: 12,
  );
}

Track _sampleTrack() {
  return Track(
    id: const TrackId('track-1'),
    name: 'Video Track',
    cuts: [_sampleCut()],
  );
}

Cut _sampleCut() {
  return Cut(
    id: const CutId('cut-1'),
    name: 'Cut 1',
    layers: [_sampleLayer()],
    duration: 24,
    canvasSize: const CanvasSize(width: 1280, height: 720),
  );
}

Layer _sampleLayer() {
  return Layer(
    id: const LayerId('layer-1'),
    name: 'Ink Layer',
    frames: [_sampleFrame()],
    opacity: 0.75,
    marks: const {3: TimelineMark.inbetween()},
  );
}

Frame _sampleFrame() {
  return Frame(
    id: const FrameId('frame-1'),
    duration: 2,
    strokes: [_sampleStroke()],
  );
}

Stroke _sampleStroke() {
  return Stroke(
    id: const StrokeId('stroke-1'),
    points: const [StrokePoint(x: 1.5, y: 2.5), StrokePoint(x: 3.5, y: 4.5)],
    brushSettings: const BrushSettings(
      color: 0xFF336699,
      size: 8,
      opacity: 0.5,
    ),
  );
}
