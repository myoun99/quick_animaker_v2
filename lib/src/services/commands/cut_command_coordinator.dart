import '../../controllers/editing_session_state.dart';
import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/project.dart';
import '../../models/storyboard_frame_metadata.dart';
import '../../models/track_id.dart';
import '../history_manager.dart';
import '../project_repository.dart';
import 'cut_command_input_planner.dart';
import 'create_cut_command.dart';
import 'delete_cut_command.dart';
import 'duplicate_cut_command.dart';
import 'rename_cut_command.dart';
import 'reorder_cut_command.dart';
import 'update_cut_note_command.dart';
import 'update_layer_kind_command.dart';
import 'update_layer_name_command.dart';
import 'update_storyboard_frame_metadata_command.dart';

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

  void updateCutNote({required CutId cutId, required String note}) {
    final cut = _requireCut(cutId);
    if (cut.metadata.note == note) {
      return;
    }

    historyManager.execute(
      UpdateCutNoteCommand(repository: repository, cutId: cutId, note: note),
    );
  }

  void renameLayer({
    required CutId cutId,
    required LayerId layerId,
    required String name,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Layer name cannot be empty.');
    }

    final cut = _requireCut(cutId);
    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    if (layer.name == trimmedName) {
      return;
    }

    final hasDuplicateName = cut.layers.any(
      (otherLayer) =>
          otherLayer.id != layerId && otherLayer.name == trimmedName,
    );
    if (hasDuplicateName) {
      throw ArgumentError.value(
        trimmedName,
        'name',
        'Layer name already exists in this cut.',
      );
    }

    historyManager.execute(
      UpdateLayerNameCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
        name: trimmedName,
      ),
    );
  }

  void updateLayerKind({
    required CutId cutId,
    required LayerId layerId,
    required LayerKind kind,
  }) {
    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    if (layer.kind == kind) {
      return;
    }

    historyManager.execute(
      UpdateLayerKindCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
        kind: kind,
      ),
    );
  }

  void updateStoryboardFrameMetadata({
    required CutId cutId,
    required LayerId layerId,
    required FrameId frameId,
    required StoryboardFrameMetadata metadata,
  }) {
    final target = _requireStoryboardFrameTarget(
      cutId: cutId,
      layerId: layerId,
      frameId: frameId,
    );
    if (target.frame.storyboardMetadata == metadata) {
      return;
    }

    historyManager.execute(
      UpdateStoryboardFrameMetadataCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
        frameId: frameId,
        metadata: metadata,
      ),
    );
  }

  void reorderCut({
    required TrackId trackId,
    required CutId cutId,
    required int newIndex,
  }) {
    historyManager.execute(
      ReorderCutCommand(
        repository: repository,
        trackId: trackId,
        cutId: cutId,
        newIndex: newIndex,
      ),
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

  _StoryboardFrameTarget _requireStoryboardFrameTarget({
    required CutId cutId,
    required LayerId layerId,
    required FrameId frameId,
  }) {
    final targetLayer = _requireLayer(cutId: cutId, layerId: layerId);
    if (targetLayer.kind != LayerKind.storyboard) {
      throw StateError('Layer is not a storyboard layer: $layerId');
    }

    Frame? targetFrame;
    for (final frame in targetLayer.frames) {
      if (frame.id == frameId) {
        targetFrame = frame;
        break;
      }
    }

    if (targetFrame == null) {
      throw StateError('Frame not found in layer $layerId: $frameId');
    }

    return _StoryboardFrameTarget(frame: targetFrame);
  }

  Layer _requireLayer({required CutId cutId, required LayerId layerId}) {
    final cut = _requireCut(cutId);
    for (final layer in cut.layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }

    throw StateError('Layer not found in cut $cutId: $layerId');
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

class _StoryboardFrameTarget {
  const _StoryboardFrameTarget({required this.frame});

  final Frame frame;
}
