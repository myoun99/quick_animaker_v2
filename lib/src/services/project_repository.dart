import '../models/audio_clip.dart';
import '../models/camera_instruction.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_camera.dart';
import '../models/cut_id.dart';
import '../models/cut_metadata.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/layer_mark.dart';
import '../models/media_asset.dart';
import '../models/storyboard_frame_metadata.dart';
import '../models/timesheet_info.dart';
import '../models/project.dart';
import '../models/stroke.dart';
import '../models/transform_track.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import 'project_tree_editor.dart';

class ProjectRepository {
  ProjectRepository({Project? initialProject})
    : _currentProject = initialProject;

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

  void updateTimesheetInfo(TimesheetInfo info) {
    updateProject((project) => project.copyWith(timesheetInfo: info));
  }

  void addTrack(Track track) {
    updateProject((project) {
      return project.copyWith(tracks: [...project.tracks, track]);
    });
  }

  void replaceTrack(Track track) {
    updateProject((project) {
      final next = updateTrackById(project, track.id, (_) => track);
      if (next == null) {
        throw StateError('Track not found: ${track.id}');
      }
      return next;
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
    insertCut(trackId: trackId, cut: cut);
  }

  void insertCut({required TrackId trackId, required Cut cut, int? index}) {
    updateProject((project) {
      final next = updateTrackById(project, trackId, (track) {
        final cuts = [...track.cuts];
        if (index == null) {
          cuts.add(cut);
        } else {
          cuts.insert(index, cut);
        }
        return track.copyWith(cuts: cuts);
      });
      if (next == null) {
        throw StateError('Track not found: $trackId');
      }
      return next;
    });
  }

  void reorderCut({
    required TrackId trackId,
    required CutId cutId,
    required int newIndex,
  }) {
    updateProject((project) {
      final next = updateTrackById(project, trackId, (track) {
        final cuts = [...track.cuts];
        final oldIndex = cuts.indexWhere((cut) => cut.id == cutId);
        if (oldIndex == -1) {
          throw StateError('Cut not found in track $trackId: $cutId');
        }

        final cut = cuts.removeAt(oldIndex);
        cuts.insert(newIndex, cut);
        return track.copyWith(cuts: cuts);
      });
      if (next == null) {
        throw StateError('Track not found: $trackId');
      }
      return next;
    });
  }

  Cut removeCut({required CutId cutId}) {
    Cut? removedCut;

    updateProject((project) {
      final tracks = project.tracks
          .map((track) {
            final cutIndex = track.cuts.indexWhere((cut) => cut.id == cutId);
            if (cutIndex == -1) {
              return track;
            }

            removedCut = track.cuts[cutIndex];
            final cuts = [...track.cuts]..removeAt(cutIndex);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (removedCut == null) {
        throw StateError('Cut not found: $cutId');
      }

      return project.copyWith(tracks: tracks);
    });

    return removedCut!;
  }

  void renameCut({required CutId cutId, required String name}) {
    updateProject((project) {
      final next = updateCutAnywhere(
        project,
        cutId,
        (cut) => cut.copyWith(name: name),
      );
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateCutCanvasSize({
    required CutId cutId,
    required CanvasSize canvasSize,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(
        project,
        cutId,
        (cut) => cut.copyWith(canvasSize: canvasSize),
      );
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateCutDuration({required CutId cutId, required int duration}) {
    updateProject((project) {
      final next = updateCutAnywhere(
        project,
        cutId,
        (cut) => cut.copyWith(duration: duration),
      );
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateCutCamera({required CutId cutId, required CutCamera camera}) {
    updateProject((project) {
      final next = updateCutAnywhere(
        project,
        cutId,
        (cut) => cut.copyWith(camera: camera),
      );
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateCutMetadata({
    required CutId cutId,
    required CutMetadata metadata,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(
        project,
        cutId,
        (cut) => cut.copyWith(metadata: metadata),
      );
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void addLayer({required CutId cutId, required Layer layer}) {
    insertLayer(cutId: cutId, layer: layer);
  }

  Layer deleteLayer({required CutId cutId, required LayerId layerId}) {
    Layer? deletedLayer;

    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final index = cut.layers.indexWhere((layer) => layer.id == layerId);
        if (index == -1) {
          return cut;
        }

        deletedLayer = cut.layers[index];
        final layers = [...cut.layers]..removeAt(index);
        return cut.copyWith(layers: layers);
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      if (deletedLayer == null) {
        throw StateError('Layer not found in cut $cutId: $layerId');
      }
      return next;
    });

    return deletedLayer!;
  }

  void insertLayer({required CutId cutId, required Layer layer, int? index}) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final layers = [...cut.layers];
        if (index == null) {
          layers.add(layer);
        } else {
          layers.insert(index.clamp(0, layers.length).toInt(), layer);
        }
        return cut.copyWith(layers: layers);
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void replaceLayer({required Layer layer}) {
    updateLayer(layerId: layer.id, update: (_) => layer);
  }

  void updateLayer({
    required LayerId layerId,
    required Layer Function(Layer layer) update,
  }) {
    updateProject((project) {
      final next = updateLayerAnywhere(project, layerId, update);
      if (next == null) {
        throw StateError('Layer not found: $layerId');
      }
      return next;
    });
  }

  void updateLayerName({
    required CutId cutId,
    required LayerId layerId,
    required String name,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(
          cut,
          layerId,
          (layer) => layer.copyWith(name: name),
        );
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateLayerTimesheet({
    required CutId cutId,
    required LayerId layerId,
    required bool onTimesheet,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(
          cut,
          layerId,
          (layer) => layer.copyWith(onTimesheet: onTimesheet),
        );
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateLayerMark({
    required CutId cutId,
    required LayerId layerId,
    required LayerMark mark,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(
          cut,
          layerId,
          (layer) => layer.copyWith(mark: mark),
        );
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateLayerInstructions({
    required CutId cutId,
    required LayerId layerId,
    required Map<int, InstructionEvent> instructions,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(
          cut,
          layerId,
          (layer) => layer.copyWith(instructions: instructions),
        );
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateCameraInstructionSet(CameraInstructionSet instructionSet) {
    updateProject(
      (project) => project.copyWith(cameraInstructions: instructionSet),
    );
  }

  void updateMediaAssets(List<MediaAsset> mediaAssets) {
    updateProject((project) => project.copyWith(mediaAssets: mediaAssets));
  }

  void updateLayerTransformTrack({
    required CutId cutId,
    required LayerId layerId,
    required TransformTrack transformTrack,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(
          cut,
          layerId,
          (layer) => layer.copyWith(transformTrack: transformTrack),
        );
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateLayerAudioClips({
    required CutId cutId,
    required LayerId layerId,
    required List<AudioClip> audioClips,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(
          cut,
          layerId,
          (layer) => layer.copyWith(audioClips: audioClips),
        );
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void updateLayerKind({
    required CutId cutId,
    required LayerId layerId,
    required LayerKind kind,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(cut, layerId, (layer) {
          if (kind == LayerKind.storyboard &&
              layer.kind != LayerKind.storyboard &&
              cut.layers.any((other) => other.kind == LayerKind.storyboard)) {
            throw StateError('Cut $cutId already has a storyboard layer.');
          }
          return layer.copyWith(kind: kind);
        });
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void addFrame({required LayerId layerId, required Frame frame}) {
    updateProject((project) {
      final next = updateLayerAnywhere(
        project,
        layerId,
        (layer) => layer.copyWith(frames: [...layer.frames, frame]),
      );
      if (next == null) {
        throw StateError('Layer not found: $layerId');
      }
      return next;
    });
  }

  void updateFrame({
    required FrameId frameId,
    required Frame Function(Frame frame) update,
  }) {
    updateProject((project) {
      final next = updateFrameAnywhere(project, frameId, update);
      if (next == null) {
        throw StateError('Frame not found: $frameId');
      }
      return next;
    });
  }

  void updateFrameStoryboardMetadata({
    required CutId cutId,
    required LayerId layerId,
    required FrameId frameId,
    required StoryboardFrameMetadata metadata,
  }) {
    updateProject((project) {
      final next = updateCutAnywhere(project, cutId, (cut) {
        final updatedCut = updateLayerInCut(cut, layerId, (layer) {
          final updatedLayer = updateFrameInLayer(
            layer,
            frameId,
            (frame) => frame.copyWith(storyboardMetadata: metadata),
          );
          if (updatedLayer == null) {
            throw StateError('Frame not found in layer $layerId: $frameId');
          }
          return updatedLayer;
        });
        if (updatedCut == null) {
          throw StateError('Layer not found in cut $cutId: $layerId');
        }
        return updatedCut;
      });
      if (next == null) {
        throw StateError('Cut not found: $cutId');
      }
      return next;
    });
  }

  void addStroke({required FrameId frameId, required Stroke stroke}) {
    updateProject((project) {
      final next = updateFrameAnywhere(
        project,
        frameId,
        (frame) => frame.copyWith(strokes: [...frame.strokes, stroke]),
      );
      if (next == null) {
        throw StateError('Frame not found: $frameId');
      }
      return next;
    });
  }
}
