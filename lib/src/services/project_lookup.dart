import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/project.dart';

/// Read-only lookups into the `Project` -> `Track` -> `Cut` -> `Layer`
/// hierarchy, shared by the edit commands and coordinator that previously each
/// carried a private copy of the same track/cut walk.

/// Returns the cut matching [cutId] anywhere in [project]. Throws a [StateError]
/// if no cut matches.
Cut requireCut(Project project, CutId cutId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      if (cut.id == cutId) {
        return cut;
      }
    }
  }

  throw StateError('Cut not found: $cutId');
}

/// Returns the layer matching [layerId] within the cut matching [cutId]. Throws
/// a [StateError] if the cut or the layer is missing.
Layer requireLayer(
  Project project, {
  required CutId cutId,
  required LayerId layerId,
}) {
  final cut = requireCut(project, cutId);
  for (final layer in cut.layers) {
    if (layer.id == layerId) {
      return layer;
    }
  }

  throw StateError('Layer not found in cut $cutId: $layerId');
}
