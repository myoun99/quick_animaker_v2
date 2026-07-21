import '../../models/cut_id.dart';
import '../../models/folder_id.dart';
import '../../models/layer_folder.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'folder_mirror.dart';

/// 폴더 해산 (L5): removes the folder, releasing direct member layers and
/// child folders to its parent (the layers themselves stay). Mirrors over
/// 겸용 cuts through the members' link groups; one undo restores the
/// folder (and its counterparts) with every membership.
class DissolveFolderCommand implements Command {
  DissolveFolderCommand({
    required this.repository,
    required this.cutId,
    required this.folderId,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final FolderId folderId;

  List<
    ({
      CutId cutId,
      LayerFolder folder,
      List<({LayerId layerId, FolderId previousFolderId})> releasedLayers,
      List<({FolderId childId, FolderId previousParentId})> releasedChildren,
    })
  >?
  _dissolved;

  @override
  String get description => 'Dissolve folder $folderId';

  @override
  void execute() {
    final project = repository.requireProject();
    // Resolve every counterpart folder BEFORE touching anything (member
    // links are the identity).
    final targets = folderMirrorFolderTargets(
      project,
      cutId: cutId,
      folderId: folderId,
    );

    final dissolved =
        <({
          CutId cutId,
          LayerFolder folder,
          List<({LayerId layerId, FolderId previousFolderId})> releasedLayers,
          List<({FolderId childId, FolderId previousParentId})>
          releasedChildren,
        })>[];
    for (final target in targets) {
      final cut = requireCut(project, target.cutId);
      final folder = cut.folders.byId(target.folderId);
      if (folder == null) {
        continue;
      }
      final releasedLayers = <({LayerId layerId, FolderId previousFolderId})>[];
      for (final layer in cut.layers) {
        if (layer.folderId == folder.id) {
          releasedLayers.add((
            layerId: layer.id,
            previousFolderId: folder.id,
          ));
          repository.updateLayerFolderId(
            cutId: target.cutId,
            layerId: layer.id,
            folderId: folder.parentId,
          );
        }
      }
      final releasedChildren =
          <({FolderId childId, FolderId previousParentId})>[];
      repository.updateCutFolders(
        cutId: target.cutId,
        update: (folders) => [
          for (final other in folders)
            if (other.id != folder.id)
              other.parentId == folder.id
                  ? () {
                      releasedChildren.add((
                        childId: other.id,
                        previousParentId: folder.id,
                      ));
                      return other.copyWith(parentId: folder.parentId);
                    }()
                  : other,
        ],
      );
      dissolved.add((
        cutId: target.cutId,
        folder: folder,
        releasedLayers: releasedLayers,
        releasedChildren: releasedChildren,
      ));
    }
    _dissolved ??= dissolved;
  }

  @override
  void undo() {
    final dissolved = _dissolved;
    if (dissolved == null) {
      throw StateError('Command has not been executed.');
    }
    for (final entry in dissolved) {
      repository.updateCutFolders(
        cutId: entry.cutId,
        update: (folders) => [
          for (final folder in folders)
            entry.releasedChildren.any(
                  (child) => child.childId == folder.id,
                )
                ? folder.copyWith(parentId: entry.folder.id)
                : folder,
          entry.folder,
        ],
      );
      for (final released in entry.releasedLayers) {
        repository.updateLayerFolderId(
          cutId: entry.cutId,
          layerId: released.layerId,
          folderId: released.previousFolderId,
        );
      }
    }
  }
}
