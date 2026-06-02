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
      var foundTrack = false;
      final tracks = project.tracks.map((track) {
        if (track.id != trackId) {
          return track;
        }

        foundTrack = true;
        return track.copyWith(cuts: [...track.cuts, cut]);
      }).toList(growable: false);

      if (!foundTrack) {
        throw StateError('Track not found: $trackId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void addLayer({required CutId cutId, required Layer layer}) {
    updateProject((project) {
      var foundCut = false;
      final tracks = project.tracks.map((track) {
        final cuts = track.cuts.map((cut) {
          if (cut.id != cutId) {
            return cut;
          }

          foundCut = true;
          return cut.copyWith(layers: [...cut.layers, layer]);
        }).toList(growable: false);

        return track.copyWith(cuts: cuts);
      }).toList(growable: false);

      if (!foundCut) {
        throw StateError('Cut not found: $cutId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void addFrame({required LayerId layerId, required Frame frame}) {
    updateProject((project) {
      var foundLayer = false;
      final tracks = project.tracks.map((track) {
        final cuts = track.cuts.map((cut) {
          final layers = cut.layers.map((layer) {
            if (layer.id != layerId) {
              return layer;
            }

            foundLayer = true;
            return layer.copyWith(frames: [...layer.frames, frame]);
          }).toList(growable: false);

          return cut.copyWith(layers: layers);
        }).toList(growable: false);

        return track.copyWith(cuts: cuts);
      }).toList(growable: false);

      if (!foundLayer) {
        throw StateError('Layer not found: $layerId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void addStroke({required FrameId frameId, required Stroke stroke}) {
    updateProject((project) {
      var foundFrame = false;
      final tracks = project.tracks.map((track) {
        final cuts = track.cuts.map((cut) {
          final layers = cut.layers.map((layer) {
            final frames = layer.frames.map((frame) {
              if (frame.id != frameId) {
                return frame;
              }

              foundFrame = true;
              return frame.copyWith(strokes: [...frame.strokes, stroke]);
            }).toList(growable: false);

            return layer.copyWith(frames: frames);
          }).toList(growable: false);

          return cut.copyWith(layers: layers);
        }).toList(growable: false);

        return track.copyWith(cuts: cuts);
      }).toList(growable: false);

      if (!foundFrame) {
        throw StateError('Frame not found: $frameId');
      }

      return project.copyWith(tracks: tracks);
    });
  }
}
