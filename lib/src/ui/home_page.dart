import 'package:flutter/material.dart';

import '../controllers/canvas_controller.dart';
import '../controllers/layer_controller.dart';
import '../controllers/timeline_controller.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/project.dart';
import '../models/project_id.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import '../models/timeline_exposure.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';
import 'canvas/canvas_view.dart';
import 'timeline/timeline_cell_exposure_state.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const CutId _cutId = CutId('sample-cut');
  static const FrameId _frameId = FrameId('sample-frame');

  late final ProjectRepository _repository;
  late final HistoryManager _historyManager;
  late final CanvasController _canvasController;
  late final LayerController _layerController;
  late final TimelineController _timelineController;

  int _layerSequence = 2;
  int _frameSequence = 0;
  TimelineOrientation _timelineOrientation = TimelineOrientation.horizontal;
  _CopiedFrameReference? _copiedFrame;

  @override
  void initState() {
    super.initState();
    _repository = ProjectRepository(initialProject: _createSampleProject());
    _historyManager = HistoryManager();
    _layerController = LayerController(
      repository: _repository,
      historyManager: _historyManager,
      cutId: _cutId,
      frameId: _frameId,
    );
    _timelineController = TimelineController(
      repository: _repository,
      historyManager: _historyManager,
      cutId: _cutId,
    );
    _canvasController = CanvasController(
      repository: _repository,
      historyManager: _historyManager,
      frameId: _frameId,
      layerController: _layerController,
      timelineController: _timelineController,
    );
  }

  Layer? get _activeLayer => _layerController.activeLayer;

  Frame? get _selectedFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return null;
    }

    return _timelineController.getSelectedFrameForLayer(layer);
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
                                ? () => setState(
                                    _pasteLinkedFrameAtCurrentFrame,
                                  )
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

    return Scaffold(
      appBar: AppBar(title: const Text('QuickAnimaker v2.1')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('Active strokes: ${_canvasController.strokes.length}'),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _canvasController.canUndo
                        ? () => setState(_canvasController.undo)
                        : null,
                    child: const Text('Undo'),
                  ),
                  TextButton(
                    onPressed: _canvasController.canRedo
                        ? () => setState(_canvasController.redo)
                        : null,
                    child: const Text('Redo'),
                  ),
                ],
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
                  cutId: _cutId,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
          TimelinePanel(
            layers: _layerController.layers,
            activeLayerId: _layerController.activeLayerId,
            currentFrameIndex: _timelineController.currentFrameIndex,
            frameCount: _timelineController.totalFrameCount,
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
                  name: 'Layer $_layerSequence',
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
              id: _cutId,
              name: 'Cut 1',
              duration: 1,
              canvasSize: const CanvasSize(width: 1280, height: 720),
              layers: [
                Layer(
                  id: const LayerId('sample-layer-1'),
                  name: 'Layer 1',
                  frames: const [],
                  timeline: const {0: TimelineExposure.blank()},
                ),
                Layer(
                  id: const LayerId('sample-layer-2'),
                  name: 'Layer 2',
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
