import '../../models/cut_id.dart';
import '../../models/folder_id.dart';
import '../../models/layer_folder.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'folder_mirror.dart';

/// 폴더 이름 변경 (L5): folder names are shared structure in 겸용 cuts —
/// renaming mirrors to every counterpart folder in the same command; one
/// undo restores every previous name.
class RenameFolderCommand implements Command {
  RenameFolderCommand({
    required this.repository,
    required this.cutId,
    required this.folderId,
    required this.name,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final FolderId folderId;
  final String name;

  List<({CutId cutId, FolderId folderId, String previousName})>? _targets;

  @override
  String get description => 'Rename folder $folderId';

  @override
  void execute() {
    final project = repository.requireProject();
    _targets ??= [
      for (final target in folderMirrorFolderTargets(
        project,
        cutId: cutId,
        folderId: folderId,
      ))
        (
          cutId: target.cutId,
          folderId: target.folderId,
          previousName:
              requireCut(project, target.cutId).folders
                  .byId(target.folderId)!
                  .name,
        ),
    ];
    for (final target in _targets!) {
      _rename(target.cutId, target.folderId, name);
    }
  }

  @override
  void undo() {
    final targets = _targets;
    if (targets == null) {
      throw StateError('Command has not been executed.');
    }
    for (final target in targets) {
      _rename(target.cutId, target.folderId, target.previousName);
    }
  }

  void _rename(CutId cutId, FolderId folderId, String next) {
    repository.updateCutFolders(
      cutId: cutId,
      update: (folders) => [
        for (final folder in folders)
          folder.id == folderId ? folder.copyWith(name: next) : folder,
      ],
    );
  }
}
