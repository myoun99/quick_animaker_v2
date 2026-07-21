import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'link_mirror.dart';

/// Changes a layer's kind — and, when it is LINKED, every member of its
/// group in the same command (kind is a shared property like name/mark:
/// linked members are "the same layer" seen from different cuts). One
/// undo step restores every member's previous kind.
class UpdateLayerKindCommand implements Command {
  UpdateLayerKindCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.kind,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final LayerKind kind;

  List<({CutId cutId, LayerId layerId, LayerKind previousKind})>? _targets;

  @override
  String get description => 'Update layer kind $layerId';

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
          previousKind: requireLayer(
            project,
            cutId: target.cutId,
            layerId: target.layerId,
          ).kind,
        ),
    ];
    for (final target in _targets!) {
      repository.updateLayerKind(
        cutId: target.cutId,
        layerId: target.layerId,
        kind: kind,
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
      repository.updateLayerKind(
        cutId: target.cutId,
        layerId: target.layerId,
        kind: target.previousKind,
      );
    }
  }
}
