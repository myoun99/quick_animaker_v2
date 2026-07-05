import '../../models/cut_id.dart';
import '../../models/cut_metadata.dart';
import '../command.dart';
import '../project_lookup.dart';
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
    _previousMetadata ??= requireCut(
      repository.requireProject(),
      cutId,
    ).metadata;
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
}
