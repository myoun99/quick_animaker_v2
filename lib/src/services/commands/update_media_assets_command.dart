import '../../models/media_asset.dart';
import '../command.dart';
import '../project_repository.dart';

/// Replaces the project's media pool in one undo step (import, rename,
/// remove — the pool list is the unit, like the instruction vocabulary).
/// Clip references stay untouched: pool edits never rewrite links, only
/// [RelinkMediaAssetCommand] does.
class UpdateMediaAssetsCommand implements Command {
  UpdateMediaAssetsCommand({
    required this.repository,
    required this.mediaAssets,
    this.description = 'Edit media pool',
  });

  final ProjectRepository repository;
  final List<MediaAsset> mediaAssets;

  @override
  final String description;

  List<MediaAsset>? _previousAssets;
  bool _hasExecuted = false;

  @override
  void execute() {
    _previousAssets ??= repository.requireProject().mediaAssets;
    repository.updateMediaAssets(mediaAssets);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousAssets = _previousAssets;
    if (!_hasExecuted || previousAssets == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateMediaAssets(previousAssets);
  }
}
