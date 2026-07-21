import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/folder_id.dart';
import '../../models/layer_id.dart';
import '../../models/project.dart';
import '../project_lookup.dart';

/// Folder-structure mirroring over 겸용 (linked) cuts: folder EXISTENCE,
/// name, membership and static properties are shared structure ("레인만
/// 각자, 나머지는 하나" — only the FX lanes and the collapse twirl stay
/// per-use). Folders have no registry of their own; the correspondence
/// rides the MEMBER LAYERS' link groups.

/// The OTHER cuts where [memberLayerIds]'s folder edit must mirror, with
/// each member resolved to its linked counterpart there. A cut qualifies
/// only when EVERY member has a counterpart in it (겸용 cuts always do —
/// partial matches mean the structure diverged, so we stand down rather
/// than guess).
List<({CutId cutId, Map<LayerId, LayerId> counterpartOf})> folderMirrorCuts(
  Project project, {
  required CutId cutId,
  required List<LayerId> memberLayerIds,
}) {
  if (memberLayerIds.isEmpty) {
    return const [];
  }
  // cut → (source member → counterpart) for every OTHER cut any member
  // links into.
  final byCut = <CutId, Map<LayerId, LayerId>>{};
  for (final memberId in memberLayerIds) {
    final group = project.linkRegistry.groupOf(
      cutId: cutId,
      layerId: memberId,
    );
    if (group == null) {
      continue;
    }
    for (final member in group.members) {
      if (member.cutId == cutId) {
        continue;
      }
      byCut.putIfAbsent(member.cutId, () => {})[memberId] = member.layerId;
    }
  }
  return [
    for (final entry in byCut.entries)
      if (entry.value.length == memberLayerIds.length)
        (cutId: entry.key, counterpartOf: entry.value),
  ];
}

/// The (cut, folder) addresses a mirrored FOLDER property edit must apply
/// to: the folder itself plus its counterpart in every 겸용 cut (resolved
/// through the direct members' link groups). Shared folder properties —
/// name, eye, static opacity — fan out through this inside one command;
/// the FX lanes and the collapse twirl never do.
List<({CutId cutId, FolderId folderId})> folderMirrorFolderTargets(
  Project project, {
  required CutId cutId,
  required FolderId folderId,
}) {
  final cut = requireCut(project, cutId);
  final directMemberIds = [
    for (final layer in cut.layers)
      if (layer.folderId == folderId) layer.id,
  ];
  return [
    (cutId: cutId, folderId: folderId),
    for (final mirror in folderMirrorCuts(
      project,
      cutId: cutId,
      memberLayerIds: directMemberIds,
    ))
      if (counterpartFolderId(
            project,
            cutId: cutId,
            folderId: folderId,
            targetCut: requireCut(project, mirror.cutId),
          )
          case final FolderId counterpart)
        (cutId: mirror.cutId, folderId: counterpart),
  ];
}

/// The folder in [targetCut] corresponding to [folderId] in the cut
/// [cutId]: the folder every counterpart of [folderId]'s DIRECT member
/// layers sits in (folder ids differ per cut — the members are the
/// identity). Null when the members disagree or have no counterparts —
/// mirroring stands down.
FolderId? counterpartFolderId(
  Project project, {
  required CutId cutId,
  required FolderId folderId,
  required Cut targetCut,
}) {
  final cut = requireCut(project, cutId);
  final directMemberIds = [
    for (final layer in cut.layers)
      if (layer.folderId == folderId) layer.id,
  ];
  if (directMemberIds.isEmpty) {
    return null;
  }
  FolderId? found;
  for (final memberId in directMemberIds) {
    final group = project.linkRegistry.groupOf(
      cutId: cutId,
      layerId: memberId,
    );
    if (group == null) {
      return null;
    }
    LayerId? counterpartId;
    for (final member in group.members) {
      if (member.cutId == targetCut.id) {
        counterpartId = member.layerId;
      }
    }
    if (counterpartId == null) {
      return null;
    }
    FolderId? counterpartFolder;
    for (final layer in targetCut.layers) {
      if (layer.id == counterpartId) {
        counterpartFolder = layer.folderId;
      }
    }
    if (counterpartFolder == null) {
      return null;
    }
    if (found != null && found != counterpartFolder) {
      return null;
    }
    found = counterpartFolder;
  }
  return found;
}
