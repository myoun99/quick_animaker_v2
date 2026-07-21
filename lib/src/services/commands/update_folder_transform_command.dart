import '../../models/cut_id.dart';
import '../../models/folder_id.dart';
import '../../models/layer_folder.dart';
import '../../models/transform_track.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

/// Replaces a FOLDER's whole FX transform track in one undo step (L5c).
/// Folder FX lanes are PER-USE ("레인만 각자") — never mirrored into
/// linked cuts, unlike the folder's name/eye/static opacity.
class UpdateFolderTransformCommand implements Command {
  UpdateFolderTransformCommand({
    required this.repository,
    required this.cutId,
    required this.folderId,
    required this.transformTrack,
    this.description = 'Edit folder transform',
  });

  final ProjectRepository repository;
  final CutId cutId;
  final FolderId folderId;
  final TransformTrack transformTrack;

  @override
  final String description;

  TransformTrack? _previousTrack;
  bool _hasExecuted = false;

  @override
  void execute() {
    final folder = requireCut(
      repository.requireProject(),
      cutId,
    ).folders.byId(folderId);
    if (folder == null) {
      throw StateError('Folder not found: $folderId');
    }
    _previousTrack ??= folder.transformTrack;

    _write(transformTrack);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousTrack = _previousTrack;
    if (!_hasExecuted || previousTrack == null) {
      throw StateError('Command has not been executed.');
    }
    _write(previousTrack);
  }

  void _write(TransformTrack track) {
    repository.updateCutFolders(
      cutId: cutId,
      update: (folders) => [
        for (final folder in folders)
          folder.id == folderId
              ? folder.copyWith(transformTrack: track)
              : folder,
      ],
    );
  }
}
