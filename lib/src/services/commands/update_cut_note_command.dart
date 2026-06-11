import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/cut_metadata.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateCutNoteCommand implements Command {
  UpdateCutNoteCommand({
    required this.repository,
    required this.cutId,
    required this.note,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final String note;

  CutMetadata? _previousMetadata;
  bool _hasExecuted = false;

  @override
  String get description => 'Update cut note $cutId';

  @override
  void execute() {
    _previousMetadata ??= _requireCut(cutId).metadata;
    repository.updateCutMetadata(
      cutId: cutId,
      metadata: _previousMetadata!.copyWith(note: note),
    );
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousMetadata = _previousMetadata;
    if (!_hasExecuted || previousMetadata == null) {
      throw StateError('Command has not been executed.');
    }

    repository.updateCutMetadata(cutId: cutId, metadata: previousMetadata);
  }

  Cut _requireCut(CutId cutId) {
    final project = repository.requireProject();
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == cutId) {
          return cut;
        }
      }
    }

    throw StateError('Cut not found: $cutId');
  }
}
