import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/cut_metadata.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/storyboard_frame_metadata.dart';
import '../models/project.dart';
import '../models/stroke.dart';
import '../models/track.dart';
import '../models/track_id.dart';

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
    insertCut(trackId: trackId, cut: cut);
  }

  void insertCut({required TrackId trackId, required Cut cut, int? index}) {
    updateProject((project) {
      var foundTrack = false;

      final tracks = project.tracks
          .map((track) {
            if (track.id != trackId) {
              return track;
            }

            foundTrack = true;
            final cuts = [...track.cuts];
            if (index == null) {
              cuts.add(cut);
            } else {
              cuts.insert(index, cut);
            }

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundTrack) {
        throw StateError('Track not found: $trackId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void reorderCut({
    required TrackId trackId,
    required CutId cutId,
    required int newIndex,
  }) {
    updateProject((project) {
      var foundTrack = false;
      var foundCut = false;

      final tracks = project.tracks
          .map((track) {
            if (track.id != trackId) {
              return track;
            }

            foundTrack = true;
            final cuts = [...track.cuts];
            final oldIndex = cuts.indexWhere((cut) => cut.id == cutId);
            if (oldIndex == -1) {
              return track;
            }

            foundCut = true;
            final cut = cuts.removeAt(oldIndex);
            cuts.insert(newIndex, cut);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundTrack) {
        throw StateError('Track not found: $trackId');
      }
      if (!foundCut) {
        throw StateError('Cut not found in track $trackId: $cutId');
      }

      return project.copyWith(tracks: tracks);
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
      var foundCut = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  if (cut.id != cutId) {
                    return cut;
                  }

                  foundCut = true;
                  return cut.copyWith(name: name);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundCut) {
        throw StateError('Cut not found: $cutId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void updateCutMetadata({
    required CutId cutId,
    required CutMetadata metadata,
  }) {
    updateProject((project) {
      var foundCut = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  if (cut.id != cutId) {
                    return cut;
                  }

                  foundCut = true;
                  return cut.copyWith(metadata: metadata);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundCut) {
        throw StateError('Cut not found: $cutId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void addLayer({required CutId cutId, required Layer layer}) {
    insertLayer(cutId: cutId, layer: layer);
  }

  void insertLayer({required CutId cutId, required Layer layer, int? index}) {
    updateProject((project) {
      var foundCut = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  if (cut.id != cutId) {
                    return cut;
                  }

                  foundCut = true;
                  final layers = [...cut.layers];
                  if (index == null) {
                    layers.add(layer);
                  } else {
                    layers.insert(index.clamp(0, layers.length).toInt(), layer);
                  }
                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundCut) {
        throw StateError('Cut not found: $cutId');
      }

      return project.copyWith(tracks: tracks);
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
      var foundLayer = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  final layers = cut.layers
                      .map((layer) {
                        if (layer.id != layerId) {
                          return layer;
                        }

                        foundLayer = true;
                        return update(layer);
                      })
                      .toList(growable: false);

                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundLayer) {
        throw StateError('Layer not found: $layerId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void updateLayerKind({
    required CutId cutId,
    required LayerId layerId,
    required LayerKind kind,
  }) {
    updateProject((project) {
      var foundCut = false;
      var foundLayer = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  if (cut.id != cutId) {
                    return cut;
                  }

                  foundCut = true;
                  Layer? targetLayer;
                  for (final layer in cut.layers) {
                    if (layer.id == layerId) {
                      targetLayer = layer;
                      break;
                    }
                  }
                  if (targetLayer == null) {
                    return cut;
                  }

                  foundLayer = true;
                  if (kind == LayerKind.storyboard &&
                      targetLayer.kind != LayerKind.storyboard &&
                      cut.layers.any(
                        (layer) => layer.kind == LayerKind.storyboard,
                      )) {
                    throw StateError(
                      'Cut $cutId already has a storyboard layer.',
                    );
                  }

                  final layers = cut.layers
                      .map((layer) => layer.id == layerId
                          ? layer.copyWith(kind: kind)
                          : layer)
                      .toList(growable: false);

                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundCut) {
        throw StateError('Cut not found: $cutId');
      }
      if (!foundLayer) {
        throw StateError('Layer not found in cut $cutId: $layerId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void addFrame({required LayerId layerId, required Frame frame}) {
    updateProject((project) {
      var foundLayer = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  final layers = cut.layers
                      .map((layer) {
                        if (layer.id != layerId) {
                          return layer;
                        }

                        foundLayer = true;
                        return layer.copyWith(frames: [...layer.frames, frame]);
                      })
                      .toList(growable: false);

                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundLayer) {
        throw StateError('Layer not found: $layerId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void updateFrame({
    required FrameId frameId,
    required Frame Function(Frame frame) update,
  }) {
    updateProject((project) {
      var foundFrame = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  final layers = cut.layers
                      .map((layer) {
                        final frames = layer.frames
                            .map((frame) {
                              if (frame.id != frameId) {
                                return frame;
                              }

                              foundFrame = true;
                              return update(frame);
                            })
                            .toList(growable: false);

                        return layer.copyWith(frames: frames);
                      })
                      .toList(growable: false);

                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundFrame) {
        throw StateError('Frame not found: $frameId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void updateFrameStoryboardMetadata({
    required CutId cutId,
    required LayerId layerId,
    required FrameId frameId,
    required StoryboardFrameMetadata metadata,
  }) {
    updateProject((project) {
      var foundCut = false;
      var foundLayer = false;
      var foundFrame = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  if (cut.id != cutId) {
                    return cut;
                  }

                  foundCut = true;
                  final layers = cut.layers
                      .map((layer) {
                        if (layer.id != layerId) {
                          return layer;
                        }

                        foundLayer = true;
                        final frames = layer.frames
                            .map((frame) {
                              if (frame.id != frameId) {
                                return frame;
                              }

                              foundFrame = true;
                              return frame.copyWith(
                                storyboardMetadata: metadata,
                              );
                            })
                            .toList(growable: false);

                        return layer.copyWith(frames: frames);
                      })
                      .toList(growable: false);

                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundCut) {
        throw StateError('Cut not found: $cutId');
      }
      if (!foundLayer) {
        throw StateError('Layer not found in cut $cutId: $layerId');
      }
      if (!foundFrame) {
        throw StateError('Frame not found in layer $layerId: $frameId');
      }

      return project.copyWith(tracks: tracks);
    });
  }

  void addStroke({required FrameId frameId, required Stroke stroke}) {
    updateProject((project) {
      var foundFrame = false;

      final tracks = project.tracks
          .map((track) {
            final cuts = track.cuts
                .map((cut) {
                  final layers = cut.layers
                      .map((layer) {
                        final frames = layer.frames
                            .map((frame) {
                              if (frame.id != frameId) {
                                return frame;
                              }

                              foundFrame = true;
                              return frame.copyWith(
                                strokes: [...frame.strokes, stroke],
                              );
                            })
                            .toList(growable: false);

                        return layer.copyWith(frames: frames);
                      })
                      .toList(growable: false);

                  return cut.copyWith(layers: layers);
                })
                .toList(growable: false);

            return track.copyWith(cuts: cuts);
          })
          .toList(growable: false);

      if (!foundFrame) {
        throw StateError('Frame not found: $frameId');
      }

      return project.copyWith(tracks: tracks);
    });
  }
}
