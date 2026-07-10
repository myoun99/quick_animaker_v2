import '../../models/cut_id.dart';
import '../../models/cut_metadata.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

/// Sets what the cut fade fades TO — black (FO) or white (WO). One undo
/// step; playback and the MP4 bake read the same value.
class UpdateCutFadeTargetCommand implements Command {
  UpdateCutFadeTargetCommand({
    required this.repository,
    required this.cutId,
    required this.fadeTarget,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final CutFadeTarget fadeTarget;

  CutMetadata? _previousMetadata;
  bool _hasExecuted = false;

  @override
  String get description => 'Fade cut $cutId to ${fadeTarget.name}';

  @override
  void execute() {
    _previousMetadata ??= requireCut(
      repository.requireProject(),
      cutId,
    ).metadata;
    repository.updateCutMetadata(
      cutId: cutId,
      metadata: _previousMetadata!.copyWith(fadeTarget: fadeTarget),
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
