import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'link_mirror.dart';

/// Renames a layer — and, when it is LINKED, every member of its group
/// in the same command: renaming never breaks a link, it propagates
/// (the "이름이 같으면 같은 그림" invariant maintains itself). One undo
/// step restores every member's previous name.
class UpdateLayerNameCommand implements Command {
  UpdateLayerNameCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.name,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final String name;

  List<({CutId cutId, LayerId layerId, String previousName})>? _targets;

  @override
  String get description => 'Update layer name $layerId';

  @override
  void execute() {
    final project = repository.requireProject();
    _targets ??= [
      for (final target in linkMirrorTargets(
        project,
        cutId: cutId,
        layerId: layerId,
      ))
        (
          cutId: target.cutId,
          layerId: target.layerId,
          previousName: requireLayer(
            project,
            cutId: target.cutId,
            layerId: target.layerId,
          ).name,
        ),
    ];
    for (final target in _targets!) {
      repository.updateLayerName(
        cutId: target.cutId,
        layerId: target.layerId,
        name: name,
      );
    }
  }

  @override
  void undo() {
    final targets = _targets;
    if (targets == null) {
      throw StateError('Command has not been executed.');
    }
    for (final target in targets) {
      repository.updateLayerName(
        cutId: target.cutId,
        layerId: target.layerId,
        name: target.previousName,
      );
    }
  }
}
