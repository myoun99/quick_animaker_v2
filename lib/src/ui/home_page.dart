import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/timeline/timeline_defaults.dart';
import '../controllers/canvas_controller.dart';
import '../controllers/cut_list_helpers.dart';
import '../controllers/editing_session_state.dart';
import '../controllers/layer_controller.dart';
import '../controllers/timeline_controller.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/project.dart';
import '../models/project_id.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import '../models/timeline_exposure.dart';
import '../services/clipboard/layer_copy_payload.dart';
import '../services/commands/cut_command_coordinator.dart';
import '../services/commands/cut_reorder_planner.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';
import 'canvas/canvas_view.dart';
import 'cut/cut_list_bar.dart';
import 'cut/cut_note_dialog.dart';
import 'storyboard_panel.dart';
import 'timeline/timeline_cell_exposure_state.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialProject, this.onRepositoryCreated});

  final Project? initialProject;
  final void Function(ProjectRepository repository)? onRepositoryCreated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const CutId _sampleCutId = CutId('sample-cut');
  static const FrameId _frameId = FrameId('sample-frame');

  late final EditingSessionState _editingSession;

  late final ProjectRepository _repository;
  late final HistoryManager _historyManager;
  late final CutCommandCoordinator _cutCommandCoordinator;
  final CutReorderPlanner _cutReorderPlanner = const CutReorderPlanner();
  late CanvasController _canvasController;
  late LayerController _layerController;
  late TimelineController _timelineController;

  int _layerSequence = 1;
  int _frameSequence = 0;
  TimelineOrientation _timelineOrientation = TimelineOrientation.horizontal;
  final ScrollController _topToolbarScrollController = ScrollController();
  _CopiedFrameReference? _copiedFrame;
  LayerCopyPayload? _layerClipboard;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject ?? _createSampleProject();
    _editingSession = EditingSessionState.forProject(project);

    _repository = ProjectRepository(initialProject: project);
    widget.onRepositoryCreated?.call(_repository);
    _historyManager = HistoryManager();
    _cutCommandCoordinator = CutCommandCoordinator(
      repository: _repository,
      editingSession: _editingSession,
      historyManager: _historyManager,
    );
    _rebuildActiveCutControllers();
  }

  @override
  void dispose() {
    _topToolbarScrollController.dispose();
    super.dispose();
  }

  void _rebuildActiveCutControllers({LayerId? preferredActiveLayerId}) {
    final activeCutId = _editingSession.activeCutId;
    final initialActiveLayerId = _activeCutHasLayer(preferredActiveLayerId)
        ? preferredActiveLayerId
        : null;

    _layerController = LayerController(
      repository: _repository,
      historyManager: _historyManager,
      cutId: activeCutId,
      frameId: _frameId,
      initialActiveLayerId: initialActiveLayerId,
    );
    _timelineController = TimelineController(
      repository: _repository,
      historyManager: _historyManager,
      cutId: activeCutId,
    );
    _canvasController = CanvasController(
      repository: _repository,
      historyManager: _historyManager,
      frameId: _frameId,
      layerController: _layerController,
      timelineController: _timelineController,
    );
  }

  TrackId get _activeCutTrackId {
    final activeCutId = _editingSession.activeCutId;
    final project = _repository.requireProject();
    for (final track in project.tracks) {
      if (track.cuts.any((cut) => cut.id == activeCutId)) {
        return track.id;
      }
    }

    if (project.tracks.isEmpty) {
      throw StateError('Cannot resolve active Cut track in an empty project.');
    }
    return project.tracks.first.id;
  }

  void _refreshAfterCutCommand({LayerId? preferredActiveLayerId}) {
    _copiedFrame = null;
    _rebuildActiveCutControllers(
      preferredActiveLayerId: preferredActiveLayerId,
    );
  }

  bool _activeCutHasLayer(LayerId? layerId) {
    if (layerId == null) {
      return false;
    }
    final cut = _activeCutOrNull;
    if (cut == null) {
      return false;
    }
    return cut.layers.any((layer) => layer.id == layerId);
  }

  void _createCutFromList() {
    setState(() {
      _cutCommandCoordinator.createCut(trackId: _activeCutTrackId);
      _refreshAfterCutCommand();
    });
  }

  void _duplicateActiveCutFromList() {
    setState(() {
      _cutCommandCoordinator.duplicateCut(
        sourceCutId: _editingSession.activeCutId,
        targetTrackId: _activeCutTrackId,
      );
      _refreshAfterCutCommand();
    });
  }

  void _deleteActiveCutFromList() {
    setState(() {
      _cutCommandCoordinator.deleteCut(cutId: _editingSession.activeCutId);
      _refreshAfterCutCommand();
    });
  }

  CutPosition? get _activeCutPositionOrNull {
    return _cutReorderPlanner.findCutPosition(
      project: _repository.requireProject(),
      cutId: _editingSession.activeCutId,
    );
  }

  CutPosition get _activeCutPosition {
    try {
      return _cutReorderPlanner.requireCutPosition(
        project: _repository.requireProject(),
        cutId: _editingSession.activeCutId,
      );
    } on StateError {
      throw StateError('Active Cut not found: ${_editingSession.activeCutId}');
    }
  }

  bool get _canMoveActiveCutLeft {
    final position = _activeCutPositionOrNull;
    return position != null && _cutReorderPlanner.canMoveLeft(position);
  }

  bool get _canMoveActiveCutRight {
    final position = _activeCutPositionOrNull;
    return position != null && _cutReorderPlanner.canMoveRight(position);
  }

  void _moveActiveCutLeftFromList() {
    final position = _activeCutPosition;
    if (!_cutReorderPlanner.canMoveLeft(position)) {
      return;
    }

    setState(() {
      _cutCommandCoordinator.reorderCut(
        trackId: position.trackId,
        cutId: position.cutId,
        newIndex: _cutReorderPlanner.moveLeftTargetIndex(position),
      );
      _refreshAfterCutCommand();
    });
  }

  void _moveActiveCutRightFromList() {
    final position = _activeCutPosition;
    if (!_cutReorderPlanner.canMoveRight(position)) {
      return;
    }

    setState(() {
      _cutCommandCoordinator.reorderCut(
        trackId: position.trackId,
        cutId: position.cutId,
        newIndex: _cutReorderPlanner.moveRightTargetIndex(position),
      );
      _refreshAfterCutCommand();
    });
  }

  void _reorderCutFromList({
    required CutId draggedCutId,
    required TrackId targetTrackId,
    required int targetCutIndex,
  }) {
    final plan = _cutReorderPlanner.planSameTrackDrop(
      project: _repository.requireProject(),
      draggedCutId: draggedCutId,
      targetTrackId: targetTrackId,
      targetCutIndex: targetCutIndex,
    );
    if (plan == null) {
      return;
    }

    setState(() {
      _cutCommandCoordinator.reorderCut(
        trackId: plan.trackId,
        cutId: plan.cutId,
        newIndex: plan.newIndex,
      );
      _refreshAfterCutCommand();
    });
  }

  Future<void> _editActiveCutNoteFromList() async {
    final activeCutId = _editingSession.activeCutId;
    final initialNote = _activeCutOrNull?.metadata.note;
    if (initialNote == null) {
      return;
    }

    final nextNote = await showDialog<String>(
      context: context,
      builder: (context) => CutNoteDialog(initialNote: initialNote),
    );
    if (!mounted || nextNote == null) {
      return;
    }

    setState(() {
      _cutCommandCoordinator.updateCutNote(cutId: activeCutId, note: nextNote);
      _refreshAfterCutCommand();
    });
  }

  Cut? get _activeCutOrNull {
    final project = _repository.requireProject();
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == _editingSession.activeCutId) {
          return cut;
        }
      }
    }

    return null;
  }

  int get _activeCutPlaybackFrameCount => math.max(1, _activeCut.duration);

  Cut get _activeCut {
    final project = _repository.requireProject();
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == _editingSession.activeCutId) {
          return cut;
        }
      }
    }

    throw StateError('Active Cut not found: ${_editingSession.activeCutId}');
  }

  Future<void> _renameActiveCutFromList() async {
    final activeCutId = _editingSession.activeCutId;
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameCutDialog(initialName: _activeCut.name),
    );
    if (!mounted || nextName == null || nextName.trim().isEmpty) {
      return;
    }

    setState(() {
      _cutCommandCoordinator.renameCut(cutId: activeCutId, newName: nextName);
      _refreshAfterCutCommand();
    });
  }

  void _undo() {
    final beforeLayers = List<Layer>.of(_activeCut.layers);
    final previousActiveLayerId = _layerController.activeLayerId;
    setState(() {
      _canvasController.undo();
      final preferredLayerId = _preferredLayerAfterLayerListChange(
        beforeLayers: beforeLayers,
        afterLayers: _activeCut.layers,
        previousActiveLayerId: previousActiveLayerId,
      );
      _refreshAfterCutCommand(preferredActiveLayerId: preferredLayerId);
    });
  }

  void _redo() {
    final beforeLayers = List<Layer>.of(_activeCut.layers);
    final previousActiveLayerId = _layerController.activeLayerId;
    setState(() {
      _canvasController.redo();
      final preferredLayerId = _preferredLayerAfterLayerListChange(
        beforeLayers: beforeLayers,
        afterLayers: _activeCut.layers,
        previousActiveLayerId: previousActiveLayerId,
      );
      _refreshAfterCutCommand(preferredActiveLayerId: preferredLayerId);
    });
  }

  void _handleCutSelected(CutId cutId) {
    if (cutId == _editingSession.activeCutId) {
      return;
    }

    setState(() {
      _editingSession.setActiveCutId(cutId);
      _copiedFrame = null;
      _rebuildActiveCutControllers();
    });
  }

  CutId get _activeCutId => _editingSession.activeCutId;

  Layer? get _activeLayer => _layerController.activeLayer;

  bool get _canDeleteActiveLayer =>
      _activeLayer != null && _activeCut.layers.length >= 2;

  LayerId? _stableLayerIdAfterDeleting({
    required List<Layer> beforeLayers,
    required LayerId deletedLayerId,
  }) {
    final deletedIndex = beforeLayers.indexWhere(
      (layer) => layer.id == deletedLayerId,
    );
    if (deletedIndex == -1) {
      return null;
    }

    final remainingLayers = beforeLayers
        .where((layer) => layer.id != deletedLayerId)
        .toList(growable: false);
    if (remainingLayers.isEmpty) {
      return null;
    }
    if (deletedIndex < remainingLayers.length) {
      return remainingLayers[deletedIndex].id;
    }
    return remainingLayers[deletedIndex - 1].id;
  }

  LayerId? _preferredLayerAfterLayerListChange({
    required List<Layer> beforeLayers,
    required List<Layer> afterLayers,
    required LayerId? previousActiveLayerId,
  }) {
    final afterIds = afterLayers.map((layer) => layer.id).toSet();
    final beforeIds = beforeLayers.map((layer) => layer.id).toSet();
    final insertedLayers = afterLayers
        .where((layer) => !beforeIds.contains(layer.id))
        .toList(growable: false);
    if (insertedLayers.isNotEmpty) {
      return insertedLayers.first.id;
    }

    if (previousActiveLayerId != null &&
        !afterIds.contains(previousActiveLayerId)) {
      return _stableLayerIdAfterDeleting(
        beforeLayers: beforeLayers,
        deletedLayerId: previousActiveLayerId,
      );
    }

    return previousActiveLayerId;
  }

  void _copyActiveLayer() {
    final activeLayer = _activeLayer;
    if (activeLayer == null) {
      return;
    }

    setState(() {
      _layerClipboard = copyLayerToPayload(activeLayer);
    });
  }

  void _pasteLayerFromClipboard() {
    final payload = _layerClipboard;
    if (payload == null) {
      return;
    }

    final activeLayer = _activeLayer;
    final targetLayers = _activeCut.layers;
    final activeLayerIndex = activeLayer == null
        ? -1
        : targetLayers.indexWhere((layer) => layer.id == activeLayer.id);
    final insertionIndex = activeLayerIndex == -1
        ? targetLayers.length
        : activeLayerIndex + 1;

    setState(() {
      final pastedLayerId = _cutCommandCoordinator.pasteLayer(
        cutId: _editingSession.activeCutId,
        payload: payload,
        insertionIndex: insertionIndex,
      );
      _refreshAfterCutCommand(preferredActiveLayerId: pastedLayerId);
    });
  }

  void _duplicateActiveLayer() {
    final activeLayer = _activeLayer;
    if (activeLayer == null) {
      return;
    }

    setState(() {
      final duplicatedLayerId = _cutCommandCoordinator.duplicateLayer(
        cutId: _editingSession.activeCutId,
        sourceLayerId: activeLayer.id,
      );
      _refreshAfterCutCommand(preferredActiveLayerId: duplicatedLayerId);
    });
  }

  Future<void> _deleteActiveLayer() async {
    final activeLayer = _activeLayer;
    if (activeLayer == null || !_canDeleteActiveLayer) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteLayerDialog(layerName: activeLayer.name),
    );
    if (!mounted || shouldDelete != true) {
      return;
    }

    final beforeLayers = List<Layer>.of(_activeCut.layers);
    final nextActiveLayerId = _stableLayerIdAfterDeleting(
      beforeLayers: beforeLayers,
      deletedLayerId: activeLayer.id,
    );

    setState(() {
      _cutCommandCoordinator.deleteLayer(
        cutId: _editingSession.activeCutId,
        layerId: activeLayer.id,
      );
      _refreshAfterCutCommand(preferredActiveLayerId: nextActiveLayerId);
    });
  }

  Future<void> _renameActiveLayer() async {
    final activeLayer = _activeLayer;
    if (activeLayer == null) {
      return;
    }

    final activeLayerId = activeLayer.id;
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameLayerDialog(initialName: activeLayer.name),
    );
    if (!mounted || nextName == null) {
      return;
    }

    setState(() {
      _cutCommandCoordinator.renameLayer(
        cutId: _editingSession.activeCutId,
        layerId: activeLayerId,
        name: nextName,
      );
      _refreshAfterCutCommand(preferredActiveLayerId: activeLayerId);
    });
  }

  Frame? get _selectedFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return null;
    }

    return _timelineController.getSelectedFrameForLayer(layer);
  }

  Layer? get _targetLayerForKindToggle => _activeLayer;

  bool get _canToggleTargetLayerKind {
    final targetLayer = _targetLayerForKindToggle;
    if (targetLayer == null) {
      return false;
    }
    if (targetLayer.kind == LayerKind.storyboard) {
      return true;
    }

    return !_layerController.layers.any(
      (layer) =>
          layer.id != targetLayer.id && layer.kind == LayerKind.storyboard,
    );
  }

  String get _activeLayerKindLabelText {
    final targetLayer = _targetLayerForKindToggle;
    return switch (targetLayer?.kind) {
      LayerKind.animation => 'Animation Layer',
      LayerKind.storyboard => 'Storyboard Layer',
      null => 'No Layer',
    };
  }

  void _toggleTargetLayerKind() {
    final targetLayer = _targetLayerForKindToggle;
    if (targetLayer == null) {
      return;
    }

    final nextKind = targetLayer.kind == LayerKind.storyboard
        ? LayerKind.animation
        : LayerKind.storyboard;

    _cutCommandCoordinator.updateLayerKind(
      cutId: _editingSession.activeCutId,
      layerId: targetLayer.id,
      kind: nextKind,
    );
    _refreshAfterCutCommand();
  }

  bool get _hasActiveNonNegativeCell {
    return _activeLayer != null && _timelineController.currentFrameIndex >= 0;
  }

  bool get _canCreateDrawingAtCurrentFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canCreateDrawingAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  bool get _canCopyFrameAtCurrentFrame {
    return _selectedFrame != null;
  }

  bool get _canPasteLinkedFrameAtCurrentFrame {
    final layer = _activeLayer;
    final copiedFrame = _copiedFrame;
    if (layer == null ||
        copiedFrame == null ||
        layer.id != copiedFrame.layerId) {
      return false;
    }

    return _timelineController.canPasteLinkedFrameAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
      copiedFrameId: copiedFrame.frameId,
    );
  }

  String get _copiedFrameStatusText {
    final copiedFrame = _copiedFrame;
    if (copiedFrame == null) {
      return 'Copy: -';
    }

    final label = copiedFrame.frameName?.isNotEmpty == true
        ? copiedFrame.frameName!
        : copiedFrame.frameId.value;
    return 'Copy: $label';
  }

  String get _linkedFrameUsesStatusText {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null) {
      return 'Links: -';
    }

    final uses = _timelineController.linkedUseCountForLayerFrame(
      layer: layer,
      frameId: frame.id,
    );
    return 'Links: $uses';
  }

  bool get _canCreateBlankAtCurrentFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canCreateBlankAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  void _createDrawingAtCurrentFrame() {
    final layer = _activeLayer;
    if (layer == null || !_canCreateDrawingAtCurrentFrame) {
      return;
    }

    _frameSequence += 1;
    _timelineController.createDrawingFrameForLayer(
      layerId: layer.id,
      frameId: FrameId(_nextFrameId(layer.id)),
    );
  }

  void _copyFrameAtCurrentFrame() {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null || !_canCopyFrameAtCurrentFrame) {
      return;
    }

    _copiedFrame = _CopiedFrameReference(
      layerId: layer.id,
      frameId: frame.id,
      frameName: frame.name,
    );
  }

  void _pasteLinkedFrameAtCurrentFrame() {
    final layer = _activeLayer;
    final copiedFrame = _copiedFrame;
    if (layer == null ||
        copiedFrame == null ||
        !_canPasteLinkedFrameAtCurrentFrame) {
      return;
    }

    _timelineController.pasteLinkedFrameForLayer(
      layerId: layer.id,
      frameId: copiedFrame.frameId,
    );
  }

  void _createBlankAtCurrentFrame() {
    final layer = _activeLayer;
    if (layer == null || !_canCreateBlankAtCurrentFrame) {
      return;
    }

    _timelineController.createBlankExposureForLayer(layerId: layer.id);
  }

  String _nextFrameId(LayerId layerId) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'ui-frame-${layerId.value}-$timestamp-$_frameSequence';
  }

  void _increaseSelectedExposure() {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null) {
      return;
    }

    _timelineController.increaseExposure(layerId: layer.id);
  }

  void _decreaseSelectedExposure() {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null) {
      return;
    }

    _timelineController.decreaseExposure(layerId: layer.id);
  }

  bool get _canToggleMarkAtCurrentFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canToggleMarkAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  void _toggleMarkAtCurrentFrame() {
    final layer = _activeLayer;
    if (layer == null || !_canToggleMarkAtCurrentFrame) {
      return;
    }

    _timelineController.toggleMarkForLayer(layerId: layer.id);
  }

  bool get _canRenameFrameAtCurrentFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canRenameFrameAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  bool get _canDeleteCellAtCurrentFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canDeleteCellAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  Future<void> _renameSelectedFrame() async {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null || !_canRenameFrameAtCurrentFrame) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameFrameDialog(initialName: frame.name ?? ''),
    );
    if (!mounted || nextName == null) {
      return;
    }

    final currentLayer = _activeLayer;
    if (currentLayer == null) {
      return;
    }

    final conflictingFrameId = _timelineController.conflictingFrameIdForRename(
      layer: currentLayer,
      frameId: frame.id,
      name: nextName,
    );
    if (conflictingFrameId == null) {
      setState(() {
        _timelineController.renameFrameForLayer(
          layerId: currentLayer.id,
          frameId: frame.id,
          name: nextName,
        );
      });
      return;
    }

    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) => const _FrameNameConflictDialog(),
    );
    if (!mounted || shouldLink != true) {
      return;
    }

    setState(() {
      _timelineController.linkFrameForLayer(
        layerId: currentLayer.id,
        sourceFrameId: frame.id,
        targetFrameId: conflictingFrameId,
      );
    });
  }

  void _deleteCellAtCurrentFrame() {
    final layer = _activeLayer;
    if (layer == null || !_canDeleteCellAtCurrentFrame) {
      return;
    }

    _timelineController.deleteCellForLayer(layerId: layer.id);
  }

  bool _hasMarkForLayer(Layer layer, int frameIndex) {
    return _timelineController.hasMarkAt(layer: layer, frameIndex: frameIndex);
  }

  String? _frameNameForLayer(Layer layer, int frameIndex) {
    return _timelineController
        .resolveFrameForLayer(layer: layer, frameIndex: frameIndex)
        ?.name;
  }

  TimelineCellExposureState _exposureStateForLayer(
    Layer layer,
    int frameIndex,
  ) {
    if (_timelineController.isDrawingStartForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.drawingStart;
    }

    if (_timelineController.isHeldExposureForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.heldExposure;
    }

    if (_timelineController.isBlankStartForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.blankStart;
    }

    if (_timelineController.isBlankHeldForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.blankHeld;
    }

    return TimelineCellExposureState.empty;
  }

  String get _currentLayerStatusText {
    final layer = _activeLayer;
    return 'Layer: ${layer?.name ?? 'None'}';
  }

  String get _currentFrameStatusText {
    return 'Frame: ${_timelineController.currentFrameIndex + 1}';
  }

  String get _currentCellStatusText {
    final layer = _activeLayer;
    if (layer == null) {
      return 'Cell: No layer';
    }

    return 'Cell: ${_cellStatusLabelForLayer(layer)}';
  }

  String get _compactCellActionText {
    final layer = _activeLayer;
    if (layer == null) {
      return 'No layer';
    }

    final frameIndex = _timelineController.currentFrameIndex;
    final hasMark = _hasMarkForLayer(layer, frameIndex);
    final exposureState = _exposureStateForLayer(layer, frameIndex);
    final canPaste = _canPasteLinkedFrameAtCurrentFrame;

    switch (exposureState) {
      case TimelineCellExposureState.drawingStart:
        return hasMark
            ? 'Drawing + ●: Copy / Rename / Delete'
            : 'Drawing: Copy / Rename / Delete';
      case TimelineCellExposureState.heldExposure:
        if (canPaste) {
          return hasMark
              ? 'Held + ●: Paste / Copy / Rename / Mark'
              : 'Held: Paste / Copy / Rename';
        }
        return hasMark
            ? 'Held + ●: Copy / Rename / Mark'
            : 'Held: Copy / Rename';
      case TimelineCellExposureState.blankStart:
        if (canPaste) {
          return hasMark
              ? 'X + ●: Paste / New Frame / Mark'
              : 'X: Paste / New Frame';
        }
        return hasMark ? 'X + ●: New Frame / Mark' : 'X: New Frame';
      case TimelineCellExposureState.blankHeld:
        if (canPaste) {
          return hasMark
              ? 'Blank held + ●: Paste / New Frame / Mark'
              : 'Blank held: Paste / New Frame';
        }
        return hasMark
            ? 'Blank held + ●: New Frame / Mark'
            : 'Blank held: New Frame';
      case TimelineCellExposureState.empty:
        if (canPaste) {
          return hasMark
              ? 'Empty + ●: Paste / Mark'
              : 'Empty: Paste / New Frame';
        }
        return hasMark ? 'Empty + ●: Mark' : 'Empty: New Frame';
    }
  }

  String _cellStatusLabelForLayer(Layer layer) {
    final frameIndex = _timelineController.currentFrameIndex;
    final exposureState = _exposureStateForLayer(layer, frameIndex);
    final baseLabel = switch (exposureState) {
      TimelineCellExposureState.drawingStart => _drawingStartStatusForLayer(
        layer,
        frameIndex,
      ),
      TimelineCellExposureState.heldExposure => 'Held drawing',
      TimelineCellExposureState.blankStart => 'Blank start (X)',
      TimelineCellExposureState.blankHeld => 'Blank held',
      TimelineCellExposureState.empty => 'Empty',
    };

    if (_hasMarkForLayer(layer, frameIndex)) {
      return '$baseLabel + Mark ●';
    }

    return baseLabel;
  }

  String _drawingStartStatusForLayer(Layer layer, int frameIndex) {
    final frameName = _frameNameForLayer(layer, frameIndex);
    if (frameName == null || frameName.isEmpty) {
      return 'Drawing start';
    }

    return 'Drawing start: $frameName';
  }

  Widget _timelineActionIconButton({
    required ValueKey<String> key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 20,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _timelineToolbarGroup({
    required ValueKey<String> key,
    required List<Widget> children,
  }) {
    return Row(key: key, mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _timelineToolbarGroupDivider(BuildContext context) {
    return SizedBox(
      height: 28,
      child: VerticalDivider(
        width: 16,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }

  Widget _buildTimelineActionToolbar(
    BuildContext context, {
    required Frame? selectedFrame,
    required int? selectedEffectiveDuration,
    required bool canDecreaseExposure,
    required bool canIncreaseExposure,
  }) {
    return DecoratedBox(
      key: const ValueKey<String>('timeline-action-toolbar'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    _currentLayerStatusText,
                    key: const ValueKey<String>('current-layer-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _activeLayerKindLabelText,
                    key: const ValueKey<String>('active-layer-kind-label'),
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>(
                      'toggle-storyboard-layer-button',
                    ),
                    tooltip: 'Toggle Storyboard Layer',
                    icon: Icons.auto_stories_outlined,
                    onPressed: _canToggleTargetLayerKind
                        ? () => setState(_toggleTargetLayerKind)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('rename-layer-button'),
                    tooltip: 'Rename Layer',
                    icon: Icons.drive_file_rename_outline,
                    onPressed: _activeLayer == null ? null : _renameActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('duplicate-layer-button'),
                    tooltip: 'Duplicate Layer',
                    icon: Icons.copy_outlined,
                    onPressed: _activeLayer == null
                        ? null
                        : _duplicateActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('copy-layer-button'),
                    tooltip: 'Copy Layer',
                    icon: Icons.content_copy,
                    onPressed: _activeLayer == null ? null : _copyActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('paste-layer-button'),
                    tooltip: 'Paste Layer',
                    icon: Icons.content_paste,
                    onPressed: _layerClipboard == null
                        ? null
                        : _pasteLayerFromClipboard,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _layerClipboard == null
                        ? 'Layer Clipboard: empty'
                        : 'Layer Clipboard: ${_layerClipboard!.name}',
                    key: const ValueKey<String>('layer-clipboard-status'),
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('delete-layer-button'),
                    tooltip: 'Delete Layer',
                    icon: Icons.delete_outline,
                    onPressed: _canDeleteActiveLayer
                        ? _deleteActiveLayer
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _currentFrameStatusText,
                    key: const ValueKey<String>('current-frame-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _currentCellStatusText,
                    key: const ValueKey<String>('current-cell-status'),
                  ),
                  const SizedBox(width: 16),
                  Text('Drawing: ${selectedFrame == null ? 'no' : 'yes'}'),
                  const SizedBox(width: 16),
                  Text('Duration: ${selectedEffectiveDuration ?? '-'}'),
                  const SizedBox(width: 16),
                  Text(
                    _linkedFrameUsesStatusText,
                    key: const ValueKey<String>('linked-frame-uses-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _copiedFrameStatusText,
                    key: const ValueKey<String>('copied-frame-status'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DecoratedBox(
                key: const ValueKey<String>('cell-actions-section'),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cell Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _timelineToolbarGroup(
                        key: const ValueKey<String>(
                          'timeline-toolbar-create-group',
                        ),
                        children: [
                          _timelineActionIconButton(
                            key: const ValueKey<String>('new-frame-button'),
                            tooltip: 'New Frame',
                            icon: Icons.add_box_outlined,
                            onPressed: _hasActiveNonNegativeCell
                                ? () => setState(_createDrawingAtCurrentFrame)
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'blank-exposure-button',
                            ),
                            tooltip: 'Blank / X',
                            icon: Icons.close,
                            onPressed: _hasActiveNonNegativeCell
                                ? () => setState(_createBlankAtCurrentFrame)
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>('toggle-mark-button'),
                            tooltip: 'Mark ●',
                            icon: Icons.circle,
                            onPressed: _hasActiveNonNegativeCell
                                ? () => setState(_toggleMarkAtCurrentFrame)
                                : null,
                          ),
                        ],
                      ),
                      _timelineToolbarGroupDivider(context),
                      _timelineToolbarGroup(
                        key: const ValueKey<String>(
                          'timeline-toolbar-copy-group',
                        ),
                        children: [
                          _timelineActionIconButton(
                            key: const ValueKey<String>('copy-frame-button'),
                            tooltip: 'Copy Frame',
                            icon: Icons.content_copy,
                            onPressed: _canCopyFrameAtCurrentFrame
                                ? () => setState(_copyFrameAtCurrentFrame)
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'paste-linked-frame-button',
                            ),
                            tooltip: 'Paste Linked Frame',
                            icon: Icons.link,
                            onPressed: _canPasteLinkedFrameAtCurrentFrame
                                ? () =>
                                      setState(_pasteLinkedFrameAtCurrentFrame)
                                : null,
                          ),
                        ],
                      ),
                      _timelineToolbarGroupDivider(context),
                      _timelineToolbarGroup(
                        key: const ValueKey<String>(
                          'timeline-toolbar-edit-group',
                        ),
                        children: [
                          _timelineActionIconButton(
                            key: const ValueKey<String>('rename-frame-button'),
                            tooltip: 'Rename Frame',
                            icon: Icons.edit_outlined,
                            onPressed: _canRenameFrameAtCurrentFrame
                                ? _renameSelectedFrame
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>('delete-cell-button'),
                            tooltip: 'Delete Cell',
                            icon: Icons.delete_outline,
                            onPressed: _canDeleteCellAtCurrentFrame
                                ? () => setState(_deleteCellAtCurrentFrame)
                                : null,
                          ),
                        ],
                      ),
                      _timelineToolbarGroupDivider(context),
                      _timelineToolbarGroup(
                        key: const ValueKey<String>(
                          'timeline-toolbar-exposure-group',
                        ),
                        children: [
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'decrease-exposure-button',
                            ),
                            tooltip: 'Decrease Exposure',
                            icon: Icons.remove,
                            onPressed: canDecreaseExposure
                                ? () => setState(_decreaseSelectedExposure)
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'increase-exposure-button',
                            ),
                            tooltip: 'Increase Exposure',
                            icon: Icons.add,
                            onPressed: canIncreaseExposure
                                ? () => setState(_increaseSelectedExposure)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _compactCellActionText,
              key: const ValueKey<String>('cell-action-hint'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLayer = _activeLayer;
    final selectedFrame = _selectedFrame;
    final selectedEffectiveDuration =
        activeLayer == null || selectedFrame == null
        ? null
        : _timelineController.effectiveDurationForLayerAt(layer: activeLayer);
    final canDecreaseExposure = activeLayer == null || selectedFrame == null
        ? false
        : _timelineController.canDecreaseExposure(layer: activeLayer);
    final canIncreaseExposure = activeLayer == null || selectedFrame == null
        ? false
        : _timelineController.canIncreaseExposure(layer: activeLayer);
    final cutEntries = cutListEntriesFor(
      _repository.requireProject(),
      activeCutId: _editingSession.activeCutId,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('QuickAnimaker v2.1')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Scrollbar(
              controller: _topToolbarScrollController,
              child: SingleChildScrollView(
                key: const ValueKey<String>('top-toolbar-scroll-view'),
                controller: _topToolbarScrollController,
                scrollDirection: Axis.horizontal,
                primary: false,
                child: Row(
                  key: const ValueKey<String>('top-toolbar-row'),
                  children: [
                    Text('Active strokes: ${_canvasController.strokes.length}'),
                    const SizedBox(width: 16),
                    CutListBar(
                      entries: cutEntries,
                      onCutSelected: _handleCutSelected,
                      onNewCut: _createCutFromList,
                      onRenameActiveCut: _renameActiveCutFromList,
                      onEditActiveCutNote: _editActiveCutNoteFromList,
                      onDuplicateActiveCut: _duplicateActiveCutFromList,
                      onMoveActiveCutLeft: _canMoveActiveCutLeft
                          ? _moveActiveCutLeftFromList
                          : null,
                      onMoveActiveCutRight: _canMoveActiveCutRight
                          ? _moveActiveCutRightFromList
                          : null,
                      onDeleteActiveCut: _deleteActiveCutFromList,
                      onCutReordered: _reorderCutFromList,
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      key: const ValueKey<String>('undo-button'),
                      onPressed: _canvasController.canUndo ? _undo : null,
                      child: const Text('Undo'),
                    ),
                    TextButton(
                      key: const ValueKey<String>('redo-button'),
                      onPressed: _canvasController.canRedo ? _redo : null,
                      child: const Text('Redo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFBDBDBD)),
                ),
                child: CanvasView(
                  controller: _canvasController,
                  cutId: _activeCutId,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
          StoryboardPanel(
            project: _repository.requireProject(),
            activeCutId: _editingSession.activeCutId,
            onCutSelected: _handleCutSelected,
          ),
          const SizedBox(height: 8),
          TimelinePanel(
            layers: _layerController.layers,
            activeLayerId: _layerController.activeLayerId,
            currentFrameIndex: _timelineController.currentFrameIndex,
            frameCount: _activeCutPlaybackFrameCount,
            exposureStateForLayer: _exposureStateForLayer,
            hasMarkForLayer: _hasMarkForLayer,
            frameNameForLayer: _frameNameForLayer,
            onSelectLayer: (layerId) {
              setState(() => _layerController.selectLayer(layerId));
            },
            onSelectFrame: (frameIndex) {
              setState(() => _timelineController.selectFrameIndex(frameIndex));
            },
            onAddLayer: () {
              setState(() {
                _layerSequence += 1;
                _layerController.addLayerWithDefaults(
                  layerId: LayerId('sample-layer-$_layerSequence'),
                );
              });
            },
            onToggleLayerVisibility: (layerId) {
              setState(() {
                _layerController.toggleLayerVisibility(layerId);
              });
            },
            onLayerOpacityChanged: (layerId, opacity) {
              setState(() {
                _layerController.setLayerOpacity(
                  layerId: layerId,
                  opacity: opacity,
                );
              });
            },
            orientation: _timelineOrientation,
            onOrientationChanged: (orientation) {
              setState(() => _timelineOrientation = orientation);
            },
            timelineActionToolbar: _buildTimelineActionToolbar(
              context,
              selectedFrame: selectedFrame,
              selectedEffectiveDuration: selectedEffectiveDuration,
              canDecreaseExposure: canDecreaseExposure,
              canIncreaseExposure: canIncreaseExposure,
            ),
          ),
        ],
      ),
    );
  }

  Project _createSampleProject() {
    return Project(
      id: const ProjectId('sample-project'),
      name: 'Sample Project',
      createdAt: DateTime.utc(2026),
      tracks: [
        Track(
          id: const TrackId('sample-track'),
          name: 'Video Track',
          cuts: [
            Cut(
              id: _sampleCutId,
              name: 'Cut 1',
              duration: defaultCutDurationFrames,
              canvasSize: const CanvasSize(width: 1280, height: 720),
              layers: [
                Layer(
                  id: const LayerId('sample-layer-1'),
                  name: 'A',
                  frames: const [],
                  timeline: const {0: TimelineExposure.blank()},
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DeleteLayerDialog extends StatelessWidget {
  const _DeleteLayerDialog({required this.layerName});

  final String layerName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('delete-layer-dialog'),
      title: const Text('Delete Layer'),
      content: Text('Delete layer "$layerName"?'),
      actions: [
        TextButton(
          key: const ValueKey<String>('delete-layer-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('delete-layer-confirm-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _RenameLayerDialog extends StatefulWidget {
  const _RenameLayerDialog({required this.initialName});
  final String initialName;

  @override
  State<_RenameLayerDialog> createState() => _RenameLayerDialogState();
}

class _RenameLayerDialogState extends State<_RenameLayerDialog> {
  late final TextEditingController _textController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmedName = _textController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorText = 'Layer name cannot be empty.');
      return;
    }
    Navigator.of(context).pop(trimmedName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('rename-layer-dialog'),
      title: const Text('Rename Layer'),
      content: TextField(
        key: const ValueKey<String>('rename-layer-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Layer name',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rename-layer-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('rename-layer-ok-button'),
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _RenameCutDialog extends StatefulWidget {
  const _RenameCutDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameCutDialog> createState() => _RenameCutDialogState();
}

class _RenameCutDialogState extends State<_RenameCutDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Cut'),
      content: TextField(
        key: const ValueKey<String>('rename-cut-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Cut name'),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rename-cut-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('rename-cut-confirm-button'),
          onPressed: () => Navigator.of(context).pop(_textController.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _CopiedFrameReference {
  const _CopiedFrameReference({
    required this.layerId,
    required this.frameId,
    required this.frameName,
  });

  final LayerId layerId;
  final FrameId frameId;
  final String? frameName;
}

class _FrameNameConflictDialog extends StatelessWidget {
  const _FrameNameConflictDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('frame-name-conflict-dialog'),
      title: const Text('Frame name already exists'),
      content: const Text(
        'This name is already used by another frame in this layer. Link to '
        'the existing named frame so the same name shares the same material?',
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('frame-name-conflict-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('frame-name-conflict-link-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Link'),
        ),
      ],
    );
  }
}

class _RenameFrameDialog extends StatefulWidget {
  const _RenameFrameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameFrameDialog> createState() => _RenameFrameDialogState();
}

class _RenameFrameDialogState extends State<_RenameFrameDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Frame'),
      content: TextField(
        key: const ValueKey<String>('rename-frame-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Frame name'),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rename-frame-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('rename-frame-ok-button'),
          onPressed: () => Navigator.of(context).pop(_textController.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
