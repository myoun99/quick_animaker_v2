import '../../controllers/default_cut_helpers.dart';
import '../../controllers/editing_session_state.dart';
import '../../core/collection_equality.dart';
import '../../models/camera_instruction.dart';
import '../../models/camera_pose.dart';
import '../../models/canvas_resize_anchor.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/cut_camera.dart';
import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_mark.dart';
import '../../models/project.dart';
import '../../models/timesheet_info.dart';
import '../../models/storyboard_frame_metadata.dart';
import '../../models/track_id.dart';
import '../brush_frame_store.dart';
import '../clipboard/layer_copy_payload.dart';
import '../history_manager.dart';
import '../project_lookup.dart';
import '../project_repository.dart';
import 'cut_command_input_planner.dart';
import 'create_cut_command.dart';
import 'delete_cut_command.dart';
import 'delete_layer_command.dart';
import 'duplicate_cut_command.dart';
import 'paste_layer_command.dart';
import 'rename_cut_command.dart';
import 'update_cut_durations_command.dart';
import 'reorder_cut_command.dart';
import 'resize_cut_canvas_command.dart';
import 'update_camera_instruction_set_command.dart';
import 'update_cut_camera_command.dart';
import 'update_cut_note_command.dart';
import 'update_layer_instructions_command.dart';
import 'update_layer_kind_command.dart';
import 'update_layer_mark_command.dart';
import 'update_layer_name_command.dart';
import 'update_layer_timesheet_command.dart';
import 'update_timesheet_info_command.dart';
import 'update_storyboard_frame_metadata_command.dart';

class CutCommandCoordinator {
  const CutCommandCoordinator({
    required this.repository,
    required this.editingSession,
    required this.historyManager,
    this.brushFrameStore,
  });

  final ProjectRepository repository;
  final EditingSessionState editingSession;
  final HistoryManager historyManager;

  /// Optional app-level brush stroke store; when present, canvas resizes
  /// translate the cut's strokes to honor the chosen anchor.
  final BrushFrameStore? brushFrameStore;

  void createCut({
    required TrackId trackId,
    String name = 'New Cut',
    CanvasSize? canvasSize,
  }) {
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
        canvasSize: canvasSize ?? defaultCutCanvasSize,
      ),
    );
  }

  void resizeCutCanvas({
    required CutId cutId,
    required CanvasSize canvasSize,
    CanvasResizeAnchor anchor = CanvasResizeAnchor.topLeft,
  }) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      throw ArgumentError.value(
        canvasSize,
        'canvasSize',
        'Canvas size must be positive.',
      );
    }

    final cut = _requireCut(cutId);
    if (cut.canvasSize == canvasSize) {
      return;
    }

    historyManager.execute(
      ResizeCutCanvasCommand(
        repository: repository,
        cutId: cutId,
        canvasSize: canvasSize,
        anchor: anchor,
        brushFrameStore: brushFrameStore,
      ),
    );
  }

  void renameCut({required CutId cutId, required String newName}) {
    historyManager.execute(
      RenameCutCommand(repository: repository, cutId: cutId, newName: newName),
    );
  }

  /// Commits an already-applied storyboard trim drag as one undoable step
  /// (the drag preview left the repository holding [after]; execute is
  /// idempotent).
  void commitCutDurationDrag({
    required Map<CutId, int> before,
    required Map<CutId, int> after,
  }) {
    historyManager.execute(
      UpdateCutDurationsCommand(
        repository: repository,
        before: before,
        after: after,
      ),
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

  void setCutCameraKeyframe({
    required CutId cutId,
    required int frameIndex,
    required CameraPose pose,
  }) {
    if (frameIndex < 0) {
      throw ArgumentError.value(
        frameIndex,
        'frameIndex',
        'Camera keyframe index must be non-negative.',
      );
    }

    final cut = _requireCut(cutId);
    if (cut.camera.keyframeAt(frameIndex) == pose) {
      return;
    }

    historyManager.execute(
      UpdateCutCameraCommand(
        repository: repository,
        cutId: cutId,
        camera: cut.camera.withKeyframe(frameIndex, pose),
        description: 'Set camera keyframe at frame ${frameIndex + 1}',
      ),
    );
  }

  void removeCutCameraKeyframe({
    required CutId cutId,
    required int frameIndex,
  }) {
    final cut = _requireCut(cutId);
    if (cut.camera.keyframeAt(frameIndex) == null) {
      return;
    }

    historyManager.execute(
      UpdateCutCameraCommand(
        repository: repository,
        cutId: cutId,
        camera: cut.camera.withoutKeyframe(frameIndex),
        description: 'Remove camera keyframe at frame ${frameIndex + 1}',
      ),
    );
  }

  void clearCutCamera({required CutId cutId}) {
    final cut = _requireCut(cutId);
    if (cut.camera.isEmpty) {
      return;
    }

    historyManager.execute(
      UpdateCutCameraCommand(
        repository: repository,
        cutId: cutId,
        camera: CutCamera.empty(),
        description: 'Clear camera keyframes',
      ),
    );
  }

  /// Replaces the cut's whole camera track in one undo step — the property
  /// lanes edit per-property keys (move/toggle/hold) that the pose-level
  /// APIs above cannot express.
  void updateCutCamera({
    required CutId cutId,
    required CutCamera camera,
    String description = 'Edit camera keyframes',
  }) {
    final cut = _requireCut(cutId);
    if (cut.camera == camera) {
      return;
    }

    historyManager.execute(
      UpdateCutCameraCommand(
        repository: repository,
        cutId: cutId,
        camera: camera,
        description: description,
      ),
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

    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    if (layer.name == trimmedName) {
      return;
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

  void deleteLayer({required CutId cutId, required LayerId layerId}) {
    final cut = _requireCut(cutId);
    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    // Mirrors the session's canDeleteActiveLayer floors: camera fixed, at
    // least two SE rows (S1·S2), one instruction row and one drawing cel.
    final refused = switch (layer.kind) {
      LayerKind.camera => true,
      LayerKind.se =>
        cut.layers.where((other) => other.kind == LayerKind.se).length <= 2,
      LayerKind.instruction =>
        cut.layers
                .where((other) => other.kind == LayerKind.instruction)
                .length <=
            1,
      LayerKind.animation || LayerKind.storyboard || LayerKind.art =>
        cut.layers
                .where(
                  (other) =>
                      other.kind == LayerKind.animation ||
                      other.kind == LayerKind.storyboard ||
                      other.kind == LayerKind.art,
                )
                .length <=
            1,
    };
    if (refused) {
      return;
    }

    historyManager.execute(
      DeleteLayerCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
      ),
    );
  }

  LayerId duplicateLayer({
    required CutId cutId,
    required LayerId sourceLayerId,
  }) {
    final cut = _requireCut(cutId);
    final sourceLayer = _requireLayer(cutId: cutId, layerId: sourceLayerId);
    if (sourceLayer.kind == LayerKind.camera) {
      throw StateError('The camera layer cannot be duplicated.');
    }
    final sourceIndex = cut.layers.indexWhere(
      (layer) => layer.id == sourceLayerId,
    );
    if (sourceIndex == -1) {
      throw StateError('Layer not found in cut $cutId: $sourceLayerId');
    }

    return pasteLayer(
      cutId: cutId,
      payload: copyLayerToPayload(sourceLayer),
      insertionIndex: sourceIndex + 1,
    );
  }

  LayerId pasteLayer({
    required CutId cutId,
    required LayerCopyPayload payload,
    required int insertionIndex,
  }) {
    if (payload.kind == LayerKind.camera) {
      throw StateError('The camera layer cannot be pasted.');
    }

    final project = repository.requireProject();
    final cut = _requireCut(cutId);
    final plan = planPasteLayerCommandInput(
      project: project,
      targetCut: cut,
      payload: payload,
      insertionIndex: insertionIndex,
    );

    historyManager.execute(
      PasteLayerCommand(
        repository: repository,
        cutId: cutId,
        layer: plan.layer,
        insertionIndex: plan.insertionIndex,
      ),
    );

    return plan.layer.id;
  }

  /// Project-level sheet-header text; one undo step, no-op when unchanged.
  void setTimesheetInfo(TimesheetInfo info) {
    if (repository.requireProject().timesheetInfo == info) {
      return;
    }
    historyManager.execute(
      UpdateTimesheetInfoCommand(repository: repository, info: info),
    );
  }

  void setLayerTimesheet({
    required CutId cutId,
    required LayerId layerId,
    required bool onTimesheet,
  }) {
    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    if (layer.kind == LayerKind.camera) {
      throw StateError('The camera layer is always recorded on the timesheet.');
    }
    if (layer.onTimesheet == onTimesheet) {
      return;
    }

    historyManager.execute(
      UpdateLayerTimesheetCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
        onTimesheet: onTimesheet,
      ),
    );
  }

  void setLayerMark({
    required CutId cutId,
    required LayerId layerId,
    required LayerMark mark,
  }) {
    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    if (layer.mark == mark) {
      return;
    }

    historyManager.execute(
      UpdateLayerMarkCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
        mark: mark,
      ),
    );
  }

  /// Replaces an instruction row's span map; one undo step, no-op when
  /// unchanged.
  void updateLayerInstructions({
    required CutId cutId,
    required LayerId layerId,
    required Map<int, InstructionEvent> instructions,
    String description = 'Edit instructions',
  }) {
    final layer = _requireLayer(cutId: cutId, layerId: layerId);
    if (layer.kind != LayerKind.instruction) {
      throw StateError('Instruction spans belong on instruction rows only.');
    }
    if (mapEquals(layer.instructions, instructions)) {
      return;
    }

    historyManager.execute(
      UpdateLayerInstructionsCommand(
        repository: repository,
        cutId: cutId,
        layerId: layerId,
        instructions: instructions,
        description: description,
      ),
    );
  }

  /// Replaces the project's instruction vocabulary; one undo step, no-op
  /// when unchanged.
  void updateCameraInstructionSet(CameraInstructionSet instructionSet) {
    if (repository.requireProject().cameraInstructions == instructionSet) {
      return;
    }
    historyManager.execute(
      UpdateCameraInstructionSetCommand(
        repository: repository,
        instructionSet: instructionSet,
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
    if (layer.kind == LayerKind.camera || kind == LayerKind.camera) {
      throw StateError(
        'The camera layer kind is fixed; layers cannot become cameras.',
      );
    }
    if (layer.kind == LayerKind.instruction || kind == LayerKind.instruction) {
      throw StateError(
        'Instruction rows are created as such; layer kinds cannot cross '
        'into or out of instruction.',
      );
    }
    if (layer.kind == LayerKind.se) {
      final cut = _requireCut(cutId);
      // Converting an SE row away must not break the S1·S2 floor of two.
      if (cut.layers.where((other) => other.kind == LayerKind.se).length <= 2) {
        return;
      }
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
    return requireLayer(
      repository.requireProject(),
      cutId: cutId,
      layerId: layerId,
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
    return requireCut(repository.requireProject(), cutId);
  }
}

class _StoryboardFrameTarget {
  const _StoryboardFrameTarget({required this.frame});

  final Frame frame;
}
