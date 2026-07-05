import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/canvas_viewport.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import 'brush/brush_settings_panel.dart';
import 'brush/main_canvas_brush_host.dart';
import 'brush/brush_tool_state.dart';
import 'cut/cut_list_bar.dart';
import 'cut/cut_note_dialog.dart';
import 'dialogs/delete_layer_dialog.dart';
import 'dialogs/frame_name_conflict_dialog.dart';
import 'dialogs/rename_cut_dialog.dart';
import 'dialogs/rename_frame_dialog.dart';
import 'dialogs/rename_layer_dialog.dart';
import 'editor_session_manager.dart';
import 'storyboard_panel.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';
import 'panels/editor_panel_dock.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialProject, this.onRepositoryCreated});

  final Project? initialProject;
  final void Function(ProjectRepository repository)? onRepositoryCreated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final EditorSessionManager _session;

  TimelineOrientation _timelineOrientation = TimelineOrientation.horizontal;
  final ScrollController _topToolbarScrollController = ScrollController();
  CanvasViewport _canvasViewport = CanvasViewport();
  BrushToolState _brushToolState = BrushToolState.defaults;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject ?? createDefaultProject();
    _session = EditorSessionManager(initialProject: project)
      ..addListener(_onSessionChanged);
    widget.onRepositoryCreated?.call(_session.repository);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _topToolbarScrollController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    setState(() {});
  }

  // --- Dialog-driven commands --------------------------------------------
  // These orchestrate dialogs (which need a BuildContext) and then delegate the
  // actual mutation to the session.

  Future<void> _editActiveCutNote() async {
    final initialNote = _session.activeCutNote;
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

    _session.updateActiveCutNote(nextNote);
  }

  Future<void> _renameActiveCut() async {
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameCutDialog(initialName: _session.activeCut.name),
    );
    if (!mounted || nextName == null || nextName.trim().isEmpty) {
      return;
    }

    _session.renameActiveCut(nextName);
  }

  Future<void> _deleteActiveLayer() async {
    final activeLayer = _session.activeLayer;
    if (activeLayer == null || !_session.canDeleteActiveLayer) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteLayerDialog(layerName: activeLayer.name),
    );
    if (!mounted || shouldDelete != true) {
      return;
    }

    _session.deleteActiveLayer();
  }

  Future<void> _renameActiveLayer() async {
    final activeLayer = _session.activeLayer;
    if (activeLayer == null) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => RenameLayerDialog(initialName: activeLayer.name),
    );
    if (!mounted || nextName == null) {
      return;
    }

    _session.renameActiveLayer(nextName);
  }

  Future<void> _renameSelectedFrame() async {
    if (_session.selectedFrame == null ||
        !_session.canRenameFrameAtCurrentFrame) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameFrameDialog(initialName: _session.selectedFrameName ?? ''),
    );
    if (!mounted || nextName == null) {
      return;
    }

    final conflictingFrameId = _session.renameSelectedFrame(nextName);
    if (conflictingFrameId == null) {
      return;
    }

    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) => const FrameNameConflictDialog(),
    );
    if (!mounted || shouldLink != true) {
      return;
    }

    _session.linkSelectedFrame(conflictingFrameId);
  }

  // --- Timeline action toolbar -------------------------------------------

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

  Widget _buildTimelineActionToolbar(BuildContext context) {
    final selectedFrame = _session.selectedFrame;
    final selectedEffectiveDuration = _session.selectedEffectiveDuration;
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
                    _session.currentLayerStatusText,
                    key: const ValueKey<String>('current-layer-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _session.activeLayerKindLabelText,
                    key: const ValueKey<String>('active-layer-kind-label'),
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>(
                      'toggle-storyboard-layer-button',
                    ),
                    tooltip: 'Toggle Storyboard Layer',
                    icon: Icons.auto_stories_outlined,
                    onPressed: _session.canToggleTargetLayerKind
                        ? _session.toggleTargetLayerKind
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('rename-layer-button'),
                    tooltip: 'Rename Layer',
                    icon: Icons.drive_file_rename_outline,
                    onPressed: _session.activeLayer == null
                        ? null
                        : _renameActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('duplicate-layer-button'),
                    tooltip: 'Duplicate Layer',
                    icon: Icons.copy_outlined,
                    onPressed: _session.activeLayer == null
                        ? null
                        : _session.duplicateActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('copy-layer-button'),
                    tooltip: 'Copy Layer',
                    icon: Icons.content_copy,
                    onPressed: _session.activeLayer == null
                        ? null
                        : _session.copyActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('paste-layer-button'),
                    tooltip: 'Paste Layer',
                    icon: Icons.content_paste,
                    onPressed: _session.hasLayerClipboard
                        ? _session.pasteLayerFromClipboard
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _session.layerClipboardName == null
                        ? 'Layer Clipboard: empty'
                        : 'Layer Clipboard: ${_session.layerClipboardName}',
                    key: const ValueKey<String>('layer-clipboard-status'),
                  ),
                  const SizedBox(width: 8),
                  _timelineActionIconButton(
                    key: const ValueKey<String>('delete-layer-button'),
                    tooltip: 'Delete Layer',
                    icon: Icons.delete_outline,
                    onPressed: _session.canDeleteActiveLayer
                        ? _deleteActiveLayer
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _session.currentFrameStatusText,
                    key: const ValueKey<String>('current-frame-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _session.currentCellStatusText,
                    key: const ValueKey<String>('current-cell-status'),
                  ),
                  const SizedBox(width: 16),
                  Text('Drawing: ${selectedFrame == null ? 'no' : 'yes'}'),
                  const SizedBox(width: 16),
                  Text('Duration: ${selectedEffectiveDuration ?? '-'}'),
                  const SizedBox(width: 16),
                  Text(
                    _session.linkedFrameUsesStatusText,
                    key: const ValueKey<String>('linked-frame-uses-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _session.copiedFrameStatusText,
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
                            onPressed: _session.hasActiveNonNegativeCell
                                ? _session.createDrawingAtCurrentFrame
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'blank-exposure-button',
                            ),
                            tooltip: 'Blank / X',
                            icon: Icons.close,
                            onPressed: _session.hasActiveNonNegativeCell
                                ? _session.createBlankAtCurrentFrame
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>('toggle-mark-button'),
                            tooltip: 'Mark ●',
                            icon: Icons.circle,
                            onPressed: _session.hasActiveNonNegativeCell
                                ? _session.toggleMarkAtCurrentFrame
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
                            onPressed: _session.canCopyFrameAtCurrentFrame
                                ? _session.copyFrameAtCurrentFrame
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'paste-linked-frame-button',
                            ),
                            tooltip: 'Paste Linked Frame',
                            icon: Icons.link,
                            onPressed:
                                _session.canPasteLinkedFrameAtCurrentFrame
                                ? _session.pasteLinkedFrameAtCurrentFrame
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
                            onPressed: _session.canRenameFrameAtCurrentFrame
                                ? _renameSelectedFrame
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>('delete-cell-button'),
                            tooltip: 'Delete Cell',
                            icon: Icons.delete_outline,
                            onPressed: _session.canDeleteCellAtCurrentFrame
                                ? _session.deleteCellAtCurrentFrame
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
                            onPressed: _session.canDecreaseSelectedExposure
                                ? _session.decreaseSelectedExposure
                                : null,
                          ),
                          _timelineActionIconButton(
                            key: const ValueKey<String>(
                              'increase-exposure-button',
                            ),
                            tooltip: 'Increase Exposure',
                            icon: Icons.add,
                            onPressed: _session.canIncreaseSelectedExposure
                                ? _session.increaseSelectedExposure
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
              _session.compactCellActionText,
              key: const ValueKey<String>('cell-action-hint'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    CutListBar(
                      entries: _session.cutListEntries,
                      onCutSelected: _session.selectCut,
                      onNewCut: _session.createCut,
                      onRenameActiveCut: _renameActiveCut,
                      onEditActiveCutNote: _editActiveCutNote,
                      onDuplicateActiveCut: _session.duplicateActiveCut,
                      onMoveActiveCutLeft: _session.canMoveActiveCutLeft
                          ? _session.moveActiveCutLeft
                          : null,
                      onMoveActiveCutRight: _session.canMoveActiveCutRight
                          ? _session.moveActiveCutRight
                          : null,
                      onDeleteActiveCut: _session.deleteActiveCut,
                      onCutReordered: _session.reorderCut,
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      key: const ValueKey<String>('undo-button'),
                      onPressed: _session.canUndo ? _session.undo : null,
                      child: const Text('Undo'),
                    ),
                    TextButton(
                      key: const ValueKey<String>('redo-button'),
                      onPressed: _session.canRedo ? _session.redo : null,
                      child: const Text('Redo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFBDBDBD)),
                      ),
                      child: KeyedSubtree(
                        key: const ValueKey<String>(
                          'main-canvas-brush-host-container',
                        ),
                        child: MainCanvasBrushHost(
                          selection: _session.activeBrushEditorSelection,
                          canvasSize: _session.activeCut.canvasSize,
                          historyManager: _session.historyManager,
                          viewport: _canvasViewport,
                          onViewportChanged: (viewport) {
                            setState(() => _canvasViewport = viewport);
                          },
                          selectionLabels: _session.canvasSelectionLabels,
                          brushToolState: _brushToolState,
                        ),
                      ),
                    ),
                  ),
                ),
                EditorPanelDock(
                  children: [
                    BrushSettingsPanel(
                      state: _brushToolState,
                      onChanged: (state) {
                        setState(() => _brushToolState = state);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          StoryboardPanel(
            project: _session.repository.requireProject(),
            activeCutId: _session.activeCutId,
            onCutSelected: _session.selectCut,
          ),
          const SizedBox(height: 8),
          TimelinePanel(
            layers: _session.layers,
            activeLayerId: _session.activeLayerId,
            currentFrameIndex: _session.currentFrameIndex,
            playbackFrameCount: _session.activeCutPlaybackFrameCount,
            exposureStateForLayer: _session.exposureStateForLayer,
            hasMarkForLayer: _session.hasMarkForLayer,
            frameNameForLayer: _session.frameNameForLayer,
            onSelectLayer: _session.selectLayer,
            onSelectFrame: _session.selectFrameIndex,
            onAddLayer: _session.addLayer,
            onToggleLayerVisibility: _session.toggleLayerVisibility,
            onLayerOpacityChanged: (layerId, opacity) {
              _session.setLayerOpacity(layerId: layerId, opacity: opacity);
            },
            orientation: _timelineOrientation,
            onOrientationChanged: (orientation) {
              setState(() => _timelineOrientation = orientation);
            },
            timelineActionToolbar: _buildTimelineActionToolbar(context),
          ),
        ],
      ),
    );
  }
}
