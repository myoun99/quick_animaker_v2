import '../../models/cut_id.dart';
import '../../models/folder_id.dart';
import '../../models/layer_folder.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'folder_mirror.dart';

/// 폴더 생성 (L5): folds [memberLayerIds] (a contiguous stack run — the
/// coordinator hands whole attach groups) into a new folder. In 겸용
/// cuts the same folder appears around the members' counterparts in the
/// SAME command (folder existence/membership are shared structure); one
/// undo removes them everywhere.
class CreateFolderCommand implements Command {
  CreateFolderCommand({
    required this.repository,
    required this.cutId,
    required this.name,
    required this.memberLayerIds,
    required this.folderIdByCut,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final String name;
  final List<LayerId> memberLayerIds;

  /// Planned new folder id per cut (the origin AND every mirror cut) —
  /// ids are per-cut, planned up front so redo reuses them.
  final Map<CutId, FolderId> folderIdByCut;

  /// (cut, layer) → previous folderId, for undo.
  List<({CutId cutId, LayerId layerId, FolderId? previousFolderId})>? _moved;

  @override
  String get description => 'Create folder "$name"';

  @override
  void execute() {
    final project = repository.requireProject();
    final targets = <({CutId cutId, List<LayerId> members})>[
      (cutId: cutId, members: memberLayerIds),
      for (final mirror in folderMirrorCuts(
        project,
        cutId: cutId,
        memberLayerIds: memberLayerIds,
      ))
        if (folderIdByCut.containsKey(mirror.cutId))
          (
            cutId: mirror.cutId,
            members: [
              for (final memberId in memberLayerIds)
                mirror.counterpartOf[memberId]!,
            ],
          ),
    ];

    final moved =
        <({CutId cutId, LayerId layerId, FolderId? previousFolderId})>[];
    for (final target in targets) {
      final cut = requireCut(project, target.cutId);
      final newFolderId = folderIdByCut[target.cutId]!;
      // The new folder nests under the members' common CURRENT folder
      // (null → top level; disagreement → top level, defensively).
      FolderId? parentId;
      var first = true;
      for (final memberId in target.members) {
        final member = cut.layers.firstWhere((layer) => layer.id == memberId);
        if (first) {
          parentId = member.folderId;
          first = false;
        } else if (parentId != member.folderId) {
          parentId = null;
        }
      }
      repository.updateCutFolders(
        cutId: target.cutId,
        update: (folders) => [
          ...folders,
          LayerFolder(id: newFolderId, name: name, parentId: parentId),
        ],
      );
      for (final memberId in target.members) {
        final member = cut.layers.firstWhere((layer) => layer.id == memberId);
        moved.add((
          cutId: target.cutId,
          layerId: memberId,
          previousFolderId: member.folderId,
        ));
        repository.updateLayerFolderId(
          cutId: target.cutId,
          layerId: memberId,
          folderId: newFolderId,
        );
      }
    }
    _moved ??= moved;
  }

  @override
  void undo() {
    final moved = _moved;
    if (moved == null) {
      throw StateError('Command has not been executed.');
    }
    for (final move in moved) {
      repository.updateLayerFolderId(
        cutId: move.cutId,
        layerId: move.layerId,
        folderId: move.previousFolderId,
      );
    }
    for (final entry in folderIdByCut.entries) {
      repository.updateCutFolders(
        cutId: entry.key,
        update: (folders) => [
          for (final folder in folders)
            if (folder.id != entry.value) folder,
        ],
      );
    }
  }
}
