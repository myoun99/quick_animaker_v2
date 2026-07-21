import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/project.dart';

/// The (cut, layer) addresses a MIRRORED property edit must apply to:
/// every member of [layerId]'s link group, or just itself when unlinked.
///
/// "레인만 각자, 나머지는 하나" — commands touching shared layer
/// properties (name, mark, kind, eye, static opacity, structure) fan out
/// through this inside ONE command execution, which is what makes the
/// mirror drift-free and single-undo. Lane edits (timeline, FX) never
/// call this.
List<({CutId cutId, LayerId layerId})> linkMirrorTargets(
  Project project, {
  required CutId cutId,
  required LayerId layerId,
}) {
  final group = project.linkRegistry.groupOf(cutId: cutId, layerId: layerId);
  if (group == null) {
    return [(cutId: cutId, layerId: layerId)];
  }
  return [
    for (final member in group.members)
      (cutId: member.cutId, layerId: member.layerId),
  ];
}
