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
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('ProjectRepository', () {
    test('starts empty when no initial project is provided', () {
      final repository = ProjectRepository();

      expect(repository.currentProject, isNull);
      expect(repository.hasProject, isFalse);
      expect(repository.requireProject, throwsStateError);
    });

    test('holds and replaces the current project', () {
      final firstProject = _project(id: 'project-1', name: 'First');
      final secondProject = _project(id: 'project-2', name: 'Second');
      final repository = ProjectRepository(initialProject: firstProject);

      expect(repository.currentProject, firstProject);
      expect(repository.hasProject, isTrue);

      repository.replaceProject(secondProject);

      expect(repository.currentProject, secondProject);
      expect(repository.requireProject(), secondProject);
    });

    test('updates the current project with immutable copies', () {
      final originalProject = _project(id: 'project-1', name: 'Original');
      final repository = ProjectRepository(initialProject: originalProject);

      repository.updateProject((project) => project.copyWith(name: 'Updated'));

      expect(repository.requireProject().name, 'Updated');
      expect(originalProject.name, 'Original');
    });

    test('adds, replaces, and removes tracks through project copies', () {
      final originalProject = _project(id: 'project-1', name: 'Project');
      final repository = ProjectRepository(initialProject: originalProject);
      final track = _track(id: 'track-1', name: 'Video');
      final replacementTrack = _track(id: 'track-1', name: 'Renamed Video');

      repository.addTrack(track);

      expect(repository.requireProject().tracks, [track]);
      expect(originalProject.tracks, isEmpty);

      repository.replaceTrack(replacementTrack);

      expect(repository.requireProject().tracks, [replacementTrack]);

      repository.removeTrack(const TrackId('track-1'));

      expect(repository.requireProject().tracks, isEmpty);
    });

    test('throws when replacing or removing a missing track', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.replaceTrack(_track(id: 'missing', name: 'Missing')),
        throwsStateError,
      );

      expect(
        () => repository.removeTrack(const TrackId('missing')),
        throwsStateError,
      );
    });

    test('adds a cut to an existing track', () {
      final track = _track(id: 'track-1', name: 'Video');
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);
      final cut = _cut(id: 'cut-1', name: 'Cut 1');

      repository.addCut(trackId: const TrackId('track-1'), cut: cut);

      expect(repository.requireProject().tracks.single.cuts, [cut]);
      expect(project.tracks.single.cuts, isEmpty);
    });

    test('throws when adding a cut to a missing track', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.addCut(
          trackId: const TrackId('missing'),
          cut: _cut(id: 'cut-1', name: 'Cut 1'),
        ),
        throwsStateError,
      );
    });

    test('adds a layer to an existing cut', () {
      final cut = _cut(id: 'cut-1', name: 'Cut 1');
      final track = _track(id: 'track-1', name: 'Video', cuts: [cut]);
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);
      final layer = _layer(id: 'layer-1', name: 'Line');

      repository.addLayer(cutId: const CutId('cut-1'), layer: layer);

      expect(repository.requireProject().tracks.single.cuts.single.layers, [
        layer,
      ]);
      expect(project.tracks.single.cuts.single.layers, isEmpty);
    });

    test('throws when adding a layer to a missing cut', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.addLayer(
          cutId: const CutId('missing'),
          layer: _layer(id: 'layer-1', name: 'Line'),
        ),
        throwsStateError,
      );
    });

    test('adds a frame to an existing layer', () {
      final layer = _layer(id: 'layer-1', name: 'Line');
      final cut = _cut(id: 'cut-1', name: 'Cut 1', layers: [layer]);
      final track = _track(id: 'track-1', name: 'Video', cuts: [cut]);
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);
      final frame = _frame(id: 'frame-1');

      repository.addFrame(layerId: const LayerId('layer-1'), frame: frame);

      expect(
        repository
            .requireProject()
            .tracks
            .single
            .cuts
            .single
            .layers
            .single
            .frames,
        [frame],
      );
      expect(project.tracks.single.cuts.single.layers.single.frames, isEmpty);
    });

    test('throws when adding a frame to a missing layer', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.addFrame(
          layerId: const LayerId('missing'),
          frame: _frame(id: 'frame-1'),
        ),
        throwsStateError,
      );
    });

    test('adds a stroke to an existing frame', () {
      final frame = _frame(id: 'frame-1');
      final layer = _layer(id: 'layer-1', name: 'Line', frames: [frame]);
      final cut = _cut(id: 'cut-1', name: 'Cut 1', layers: [layer]);
      final track = _track(id: 'track-1', name: 'Video', cuts: [cut]);
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);
      final stroke = _stroke(id: 'stroke-1');

      repository.addStroke(frameId: const FrameId('frame-1'), stroke: stroke);

      expect(
        repository
            .requireProject()
            .tracks
            .single
            .cuts
            .single
            .layers
            .single
            .frames
            .single
            .strokes,
        [stroke],
      );
      expect(
        project.tracks.single.cuts.single.layers.single.frames.single.strokes,
        isEmpty,
      );
    });

    test('updates only the target frame through immutable copies', () {
      final frameA = _frame(id: 'frame-a');
      final frameB = _frame(id: 'frame-b');
      final layer = _layer(
        id: 'layer-1',
        name: 'Line',
        frames: [frameA, frameB],
      );
      final cut = _cut(id: 'cut-1', name: 'Cut 1', layers: [layer]);
      final track = _track(id: 'track-1', name: 'Video', cuts: [cut]);
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);

      repository.updateFrame(
        frameId: const FrameId('frame-b'),
        update: (frame) => frame.copyWith(duration: 3),
      );

      final updatedFrames = repository
          .requireProject()
          .tracks
          .single
          .cuts
          .single
          .layers
          .single
          .frames;
      expect(updatedFrames.first, frameA);
      expect(updatedFrames.last.duration, 3);
      expect(
        project.tracks.single.cuts.single.layers.single.frames.last,
        frameB,
      );
      expect(updatedFrames.last, isNot(same(frameB)));
    });

    test('throws when updating a missing frame', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.updateFrame(
          frameId: const FrameId('missing'),
          update: (frame) => frame,
        ),
        throwsStateError,
      );
    });

    test('throws when adding a stroke to a missing frame', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.addStroke(
          frameId: const FrameId('missing'),
          stroke: _stroke(id: 'stroke-1'),
        ),
        throwsStateError,
      );
    });

    test(
      'keeps original project and frame unchanged after adding a stroke',
      () {
        final originalFrame = _frame(id: 'frame-1');
        final originalLayer = _layer(
          id: 'layer-1',
          name: 'Line',
          frames: [originalFrame],
        );
        final originalCut = _cut(
          id: 'cut-1',
          name: 'Cut 1',
          layers: [originalLayer],
        );
        final originalTrack = _track(
          id: 'track-1',
          name: 'Video',
          cuts: [originalCut],
        );
        final originalProject = _project(
          id: 'project-1',
          name: 'Project',
          tracks: [originalTrack],
        );
        final repository = ProjectRepository(initialProject: originalProject);
        final stroke = _stroke(id: 'stroke-1');

        repository.addStroke(frameId: const FrameId('frame-1'), stroke: stroke);

        final updatedProject = repository.requireProject();
        final updatedFrame = updatedProject
            .tracks
            .single
            .cuts
            .single
            .layers
            .single
            .frames
            .single;

        expect(updatedProject, isNot(same(originalProject)));
        expect(updatedFrame, isNot(same(originalFrame)));
        expect(updatedFrame.strokes, [stroke]);
        expect(
          originalProject
              .tracks
              .single
              .cuts
              .single
              .layers
              .single
              .frames
              .single
              .strokes,
          isEmpty,
        );
        expect(originalFrame.strokes, isEmpty);
      },
    );

    test('replaces an existing layer', () {
      final layer = _layer(id: 'layer-1', name: 'Line');
      final cut = _cut(id: 'cut-1', name: 'Cut 1', layers: [layer]);
      final track = _track(id: 'track-1', name: 'Video', cuts: [cut]);
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);
      final replacement = _layer(id: 'layer-1', name: 'Paint');

      repository.replaceLayer(layer: replacement);

      expect(
        repository.requireProject().tracks.single.cuts.single.layers.single,
        replacement,
      );
      expect(project.tracks.single.cuts.single.layers.single, layer);
    });

    test('updates an existing layer', () {
      final layer = _layer(id: 'layer-1', name: 'Line');
      final cut = _cut(id: 'cut-1', name: 'Cut 1', layers: [layer]);
      final track = _track(id: 'track-1', name: 'Video', cuts: [cut]);
      final project = _project(
        id: 'project-1',
        name: 'Project',
        tracks: [track],
      );
      final repository = ProjectRepository(initialProject: project);

      repository.updateLayer(
        layerId: const LayerId('layer-1'),
        update: (layer) => layer.copyWith(isVisible: false, opacity: 0.5),
      );

      final updatedLayer = repository
          .requireProject()
          .tracks
          .single
          .cuts
          .single
          .layers
          .single;
      expect(updatedLayer.isVisible, isFalse);
      expect(updatedLayer.opacity, 0.5);
      expect(project.tracks.single.cuts.single.layers.single.isVisible, isTrue);
    });

    test('throws when replacing or updating a missing layer', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.replaceLayer(
          layer: _layer(id: 'missing', name: 'Missing'),
        ),
        throwsStateError,
      );

      expect(
        () => repository.updateLayer(
          layerId: const LayerId('missing'),
          update: (layer) => layer,
        ),
        throwsStateError,
      );
    });

    test('clears the current project', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      repository.clearProject();

      expect(repository.currentProject, isNull);
      expect(repository.hasProject, isFalse);
    });
  });
}

Project _project({
  required String id,
  required String name,
  List<Track> tracks = const [],
}) {
  return Project(
    id: ProjectId(id),
    name: name,
    tracks: tracks,
    createdAt: DateTime.utc(2026, 6, 2),
  );
}

Track _track({
  required String id,
  required String name,
  List<Cut> cuts = const [],
}) {
  return Track(id: TrackId(id), name: name, cuts: cuts);
}

Cut _cut({
  required String id,
  required String name,
  List<Layer> layers = const [],
}) {
  return Cut(
    id: CutId(id),
    name: name,
    layers: layers,
    duration: 24,
    canvasSize: const CanvasSize(width: 1920, height: 1080),
  );
}

Layer _layer({
  required String id,
  required String name,
  List<Frame> frames = const [],
}) {
  return Layer(id: LayerId(id), name: name, frames: frames);
}

Frame _frame({required String id, List<Stroke> strokes = const []}) {
  return Frame(id: FrameId(id), duration: 1, strokes: strokes);
}

Stroke _stroke({required String id}) {
  return Stroke(
    id: StrokeId(id),
    points: const [StrokePoint(x: 1, y: 2)],
    brushSettings: const BrushSettings(),
  );
}
