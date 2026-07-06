import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import 'cut/cut_list_bar.dart';
import 'cut/cut_note_dialog.dart';
import 'dialogs/canvas_size_dialog.dart';
import 'dialogs/delete_layer_dialog.dart';
import 'dialogs/frame_name_conflict_dialog.dart';
import 'dialogs/rename_cut_dialog.dart';
import 'dialogs/rename_frame_dialog.dart';
import 'dialogs/rename_layer_dialog.dart';
import 'editor_canvas_area.dart';
import 'editor_session_manager.dart';
import 'export/png_sequence_export_dialog.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/playback_transport_controls.dart';
import 'panels/panel_scrollbar.dart';
import 'storyboard_panel.dart';
import 'timeline/timeline_action_toolbar.dart';
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
  late final EditorSessionManager _session;

  TimelineOrientation _timelineOrientation = TimelineOrientation.horizontal;
  bool _showStoryboard = false;
  final ScrollController _topToolbarScrollController = ScrollController();

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

  Future<void> _resizeActiveCutCanvas() async {
    final request = await showDialog<CanvasResizeRequest>(
      context: context,
      builder: (context) =>
          CanvasSizeDialog(initialSize: _session.activeCut.canvasSize),
    );
    if (!mounted || request == null) {
      return;
    }

    _session.resizeActiveCutCanvas(request.size, anchor: request.anchor);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickAnimaker v2.1'),
        actions: [
          IconButton(
            key: const ValueKey<String>('undo-button'),
            tooltip: 'Undo',
            onPressed: _session.canUndo ? _session.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const ValueKey<String>('redo-button'),
            tooltip: 'Redo',
            onPressed: _session.canRedo ? _session.redo : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            key: const ValueKey<String>('export-png-button'),
            tooltip: 'Export PNG Sequence',
            onPressed: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder: (context) =>
                      PngSequenceExportDialog(session: _session),
                ),
              );
            },
            icon: const Icon(Icons.save_alt),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: PanelScrollbar(
              controller: _topToolbarScrollController,
              child: SingleChildScrollView(
                key: const ValueKey<String>('top-toolbar-scroll-view'),
                controller: _topToolbarScrollController,
                scrollDirection: Axis.horizontal,
                primary: false,
                padding: const EdgeInsets.only(bottom: panelScrollbarGutter),
                child: Row(
                  key: const ValueKey<String>('top-toolbar-row'),
                  children: [
                    CutListBar(
                      entries: _session.cutListEntries,
                      onCutSelected: _session.selectCut,
                      onCutReordered: _session.reorderCut,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: EditorCanvasArea(session: _session)),
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
            showStoryboard: _showStoryboard,
            onShowStoryboardChanged: (show) {
              setState(() => _showStoryboard = show);
            },
            // The storyboard context plays every cut of the track; the
            // timeline context plays the active cut from the playhead.
            // Composing the transports into the existing slots keeps
            // TimelinePanel/StoryboardPanel untouched.
            storyboardPanel: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlaybackTransportControls(
                  controller: _session.playback,
                  scope: PlaybackScope.allCuts,
                  quality: _session.playbackQuality,
                  onQualityChanged: _session.setPlaybackQuality,
                ),
                Expanded(
                  child: StoryboardPanel(
                    project: _session.repository.requireProject(),
                    activeCutId: _session.activeCutId,
                    onCutSelected: _session.selectCut,
                    onNewCut: _session.createCut,
                    onRenameActiveCut: _renameActiveCut,
                    onEditActiveCutNote: _editActiveCutNote,
                    onResizeActiveCutCanvas: _resizeActiveCutCanvas,
                    onDuplicateActiveCut: _session.duplicateActiveCut,
                    onMoveActiveCutLeft: _session.canMoveActiveCutLeft
                        ? _session.moveActiveCutLeft
                        : null,
                    onMoveActiveCutRight: _session.canMoveActiveCutRight
                        ? _session.moveActiveCutRight
                        : null,
                    onDeleteActiveCut: _session.deleteActiveCut,
                  ),
                ),
              ],
            ),
            timelineActionToolbar: Row(
              children: [
                PlaybackTransportControls(
                  controller: _session.playback,
                  scope: PlaybackScope.activeCut,
                  quality: _session.playbackQuality,
                  onQualityChanged: _session.setPlaybackQuality,
                  playbackStartFrame: () => _session.currentFrameIndex,
                ),
                Expanded(
                  child: TimelineActionToolbar(
                    session: _session,
                    onRenameLayer: _renameActiveLayer,
                    onDeleteLayer: _deleteActiveLayer,
                    onRenameFrame: _renameSelectedFrame,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
