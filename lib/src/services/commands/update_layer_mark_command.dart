import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'link_mirror.dart';

/// Updates a layer's mark — mirrored across its link group ("레인만
/// 각자, 나머지는 하나": the mark is shared identity). One undo step.
class UpdateLayerMarkCommand implements Command {
  UpdateLayerMarkCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.mark,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final LayerMark mark;

  List<({CutId cutId, LayerId layerId, LayerMark previousMark})>? _targets;

  @override
  String get description => 'Update layer mark $layerId';

  @override
  void execute() {
    final project = repository.requireProject();
    // Anywhere lookup: track-owned SE rows are not in the cut's layer list
    // but carry marks like every row (unified layer controls). SE rows are
    // never linked, so their mirror target set is just themselves.
    _targets ??= [
      for (final target in linkMirrorTargets(
        project,
        cutId: cutId,
        layerId: layerId,
      ))
        (
          cutId: target.cutId,
          layerId: target.layerId,
          previousMark: requireLayerAnywhere(project, target.layerId).mark,
        ),
    ];
    for (final target in _targets!) {
      repository.updateLayerMark(
        cutId: target.cutId,
        layerId: target.layerId,
        mark: mark,
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
      repository.updateLayerMark(
        cutId: target.cutId,
        layerId: target.layerId,
        mark: target.previousMark,
      );
    }
  }
}
