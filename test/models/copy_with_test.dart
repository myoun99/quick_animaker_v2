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

void main() {
  test('copyWith changes only specified value object fields', () {
    const size = CanvasSize(width: 100, height: 200);
    const brush = BrushSettings(size: 4);
    const point = StrokePoint(x: 1, y: 2);

    expect(size.copyWith(width: 300), const CanvasSize(width: 300, height: 200));
    expect(brush.copyWith(opacity: 0.25), const BrushSettings(size: 4, opacity: 0.25));
    expect(point.copyWith(y: 3), const StrokePoint(x: 1, y: 3));
  });

  test('copyWith preserves nested lists unless replaced and leaves original unchanged', () {
    final stroke = Stroke(
      id: const StrokeId('stroke-1'),
      points: const [StrokePoint(x: 1, y: 2)],
      brushSettings: const BrushSettings(),
    );
    final frame = Frame(id: const FrameId('frame-1'), duration: 1, strokes: [stroke]);
    final layer = Layer(id: const LayerId('layer-1'), name: 'Line', frames: [frame]);
    final cut = Cut(
      id: const CutId('cut-1'),
      name: 'Cut 1',
      layers: [layer],
      duration: 24,
      canvasSize: const CanvasSize(width: 1280, height: 720),
    );
    final track = Track(id: const TrackId('track-1'), name: 'Video', cuts: [cut]);
    final project = Project(
      id: const ProjectId('project-1'),
      name: 'Project',
      tracks: [track],
      createdAt: DateTime.utc(2026),
    );

    final renamedProject = project.copyWith(name: 'Renamed');
    final extendedCut = cut.copyWith(duration: 48);
    final hiddenLayer = layer.copyWith(isVisible: false);
    final longerFrame = frame.copyWith(duration: 2);
    final recoloredStroke = stroke.copyWith(
      brushSettings: const BrushSettings(color: 0xFFFFFFFF),
    );

    expect(renamedProject.name, 'Renamed');
    expect(renamedProject.tracks, project.tracks);
    expect(project.name, 'Project');
    expect(extendedCut.layers, cut.layers);
    expect(cut.duration, 24);
    expect(hiddenLayer.frames, layer.frames);
    expect(layer.isVisible, isTrue);
    expect(longerFrame.strokes, frame.strokes);
    expect(frame.duration, 1);
    expect(recoloredStroke.points, stroke.points);
    expect(stroke.brushSettings, const BrushSettings());
  });
}
