import '../../controllers/editing_session_state.dart';
import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/project.dart';
import '../../models/track_id.dart';
import '../history_manager.dart';
import '../project_repository.dart';
import 'cut_command_input_planner.dart';
import 'create_cut_command.dart';
import 'delete_cut_command.dart';
import 'duplicate_cut_command.dart';
import 'rename_cut_command.dart';

class CutCommandCoordinator {
  const CutCommandCoordinator({
    required this.repository,
    required this.editingSession,
    required this.historyManager,
  });

  final ProjectRepository repository;
  final EditingSessionState editingSession;
  final HistoryManager historyManager;

  void createCut({required TrackId trackId, String name = 'New Cut'}) {
    final project = repository.requireProject();
    final plan = planCreateCutCommandInput(project);

    historyManager.execute(
      CreateCutCommand(
        repository: repository,
        editingSession: editingSession,
        trackId: trackId,
        cutId: plan.cutId,
        layerId: plan.layerId,
        name: name,
      ),
    );
  }

  void renameCut({required CutId cutId, required String newName}) {
    historyManager.execute(
      RenameCutCommand(repository: repository, cutId: cutId, newName: newName),
    );
  }

  void deleteCut({required CutId cutId}) {
    final project = repository.requireProject();
    final replacementPlan = _cutCount(project) == 1
        ? planDeleteLastCutReplacementInput(project)
        : null;

    historyManager.execute(
      DeleteCutCommand(
        repository: repository,
        editingSession: editingSession,
        cutId: cutId,
        replacementCutId: replacementPlan?.replacementCutId,
        replacementLayerId: replacementPlan?.replacementLayerId,
      ),
    );
  }

  void duplicateCut({
    required CutId sourceCutId,
    required TrackId targetTrackId,
    String? newName,
  }) {
    final project = repository.requireProject();
    final sourceCut = _requireCut(sourceCutId);
    final plan = planDuplicateCutCommandInput(
      project: project,
      sourceCut: sourceCut,
    );

    historyManager.execute(
      DuplicateCutCommand(
        repository: repository,
        editingSession: editingSession,
        sourceCutId: sourceCutId,
        targetTrackId: targetTrackId,
        newCutId: plan.newCutId,
        newName: newName ?? '${sourceCut.name} Copy',
        layerIdMap: plan.layerIdMap,
        frameIdMap: plan.frameIdMap,
      ),
    );
  }

  int _cutCount(Project project) {
    var count = 0;
    for (final track in project.tracks) {
      count += track.cuts.length;
    }
    return count;
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
