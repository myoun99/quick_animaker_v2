import '../../models/cut_id.dart';
import '../../models/cut_metadata.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

/// Pins (or clears, with null) the cut-local frame the storyboard block's
/// thumbnail renders.
class UpdateCutThumbnailFrameCommand implements Command {
  UpdateCutThumbnailFrameCommand({
    required this.repository,
    required this.cutId,
    required this.frameIndex,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final int? frameIndex;

  CutMetadata? _previousMetadata;
  bool _hasExecuted = false;

  @override
  String get description => frameIndex == null
      ? 'Reset cut thumbnail $cutId'
      : 'Pin cut thumbnail $cutId to frame ${frameIndex! + 1}';

  @override
  void execute() {
    _previousMetadata ??= requireCut(
      repository.requireProject(),
      cutId,
    ).metadata;
    repository.updateCutMetadata(
      cutId: cutId,
      metadata: _previousMetadata!.copyWith(
        thumbnailFrameIndex: () => frameIndex,
      ),
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
