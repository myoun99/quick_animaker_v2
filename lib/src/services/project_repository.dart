import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/project.dart';
import '../models/stroke.dart';
import '../models/track.dart';
import '../models/track_id.dart';

class ProjectRepository {
  ProjectRepository({Project? initialProject}) : _currentProject = initialProject;

  Project? _currentProject;

  Project? get currentProject => _currentProject;

  bool get hasProject => _currentProject != null;

  Project requireProject() {
    final project = _currentProject;
    if (project == null) {
      throw StateError('No project is loaded.');
    }
    return project;
  }

  void replaceProject(Project project) {
    _currentProject = project;
  }

  void clearProject() {
    _currentProject = null;
  }

  void updateProject(Project Function(Project project) update) {
    _currentProject = update(requireProject());
  }

  void addTrack(Track track) {
    updateProject((project) {
      return project.copyWith(tracks: [...project.tracks, track]);
    });
  }

  void replaceTrack(Track track) {
    updateProject((project) {
      final index = project.tracks.indexWhere(
        (existingTrack) => existingTrack.id == track.id,
      );
      if (index == -1) {
        throw StateError('Track not found: ${track.id}');
      }

      final tracks = [...project.tracks];
      tracks[index] = track;
      return project.copyWith(tracks: tracks);
    });
  }

  void removeTrack(TrackId trackId) {
    updateProject((project) {
      final tracks = project.tracks
          .where((track) => track.id != trackId)
          .toList(growable: false);
      if (tracks.length == project.tracks.length) {
        throw StateError('Track not found: $trackId');
      }
      return project.copyWith(tracks: tracks);
    });
  }

  void addCut({required TrackId trackId, required Cut cut}) {
    updateProject((project) {
      final trackIndex = project.tracks.indexWhere(
        (track) => track.id == trackId,
      );
      if (trackIndex == -1) {
        throw StateError('Track not found: $trackId');
      }

      final track = project.tracks[trackIndex];
      final updatedTrack = track.copyWith(cuts: [...track.cuts, cut]);
      final tracks = [...project.tracks];
      tracks[trackIndex] = updatedTrack;

      return project.copyWith(tracks: tracks);
    });
  }

  void addLayer({required CutId cutId, required Layer layer}) {
    updateProject((project) {
      for (
        var trackIndex = 0;
        trackIndex < project.tracks.length;
        trackIndex += 1
      ) {
        final track = project.tracks[trackIndex];
        final cutIndex = track.cuts.indexWhere(
          (cut) => cut.id == cutId,
        );
        if (cutIndex == -1) {
          continue;
        }

        final cut = track.cuts[cutIndex];
        final updatedCut = cut.copyWith(layers: [...cut.layers, layer]);
        final cuts = [...track.cuts];
        cuts[cutIndex] = updatedCut;

        final updatedTrack = track.copyWith(cuts: cuts);
        final tracks = [...project.tracks];
        tracks[trackIndex] = updatedTrack;

        return project.copyWith(tracks: tracks);
      }

      throw StateError('Cut not found: $cutId');
    });
  }

  void addFrame({required LayerId layerId, required Frame frame}) {
    updateProject((project) {
      for (
        var trackIndex = 0;
        trackIndex < project.tracks.length;
        trackIndex += 1
      ) {
        final track = project.tracks[trackIndex];

        for (
          var cutIndex = 0;
          cutIndex < track.cuts.length;
          cutIndex += 1
        ) {
          final cut = track.cuts[cutIndex];
          final layerIndex = cut.layers.indexWhere(
            (layer) => layer.id == layerId,
          );
          if (layerIndex == -1) {
            continue;
          }

          final layer = cut.layers[layerIndex];
          final updatedLayer = layer.copyWith(frames: [...layer.frames, frame]);
          final layers = [...cut.layers];
          layers[layerIndex] = updatedLayer;

          final updatedCut = cut.copyWith(layers: layers);
          final cuts = [...track.cuts];
          cuts[cutIndex] = updatedCut;

          final updatedTrack = track.copyWith(cuts: cuts);
          final tracks = [...project.tracks];
          tracks[trackIndex] = updatedTrack;

          return project.copyWith(tracks: tracks);
        }
      }

      throw StateError('Layer not found: $layerId');
    });
  }

  void addStroke({required FrameId frameId, required Stroke stroke}) {
    updateProject((project) {
      for (
        var trackIndex = 0;
        trackIndex < project.tracks.length;
        trackIndex += 1
      ) {
        final track = project.tracks[trackIndex];

        for (
          var cutIndex = 0;
          cutIndex < track.cuts.length;
          cutIndex += 1
        ) {
          final cut = track.cuts[cutIndex];

          for (
            var layerIndex = 0;
            layerIndex < cut.layers.length;
            layerIndex += 1
          ) {
            final layer = cut.layers[layerIndex];
            final frameIndex = layer.frames.indexWhere(
              (frame) => frame.id == frameId,
            );
            if (frameIndex == -1) {
              continue;
            }

            final frame = layer.frames[frameIndex];
            final updatedFrame = frame.copyWith(
              strokes: [...frame.strokes, stroke],
            );
            final frames = [...layer.frames];
            frames[frameIndex] = updatedFrame;

            final updatedLayer = layer.copyWith(frames: frames);
            final layers = [...cut.layers];
            layers[layerIndex] = updatedLayer;

            final updatedCut = cut.copyWith(layers: layers);
            final cuts = [...track.cuts];
            cuts[cutIndex] = updatedCut;

            final updatedTrack = track.copyWith(cuts: cuts);
            final tracks = [...project.tracks];
            tracks[trackIndex] = updatedTrack;

            return project.copyWith(tracks: tracks);
          }
        }
      }

      throw StateError('Frame not found: $frameId');
    });
  }
}
