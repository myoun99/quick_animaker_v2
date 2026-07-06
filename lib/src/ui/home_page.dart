import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import 'cut/cut_note_dialog.dart';
import 'dialogs/canvas_size_dialog.dart';
import 'dialogs/delete_layer_dialog.dart';
import 'dialogs/frame_name_conflict_dialog.dart';
import 'dialogs/rename_cut_dialog.dart';
import 'dialogs/rename_frame_dialog.dart';
import 'dialogs/rename_layer_dialog.dart';
import 'editor_canvas_area.dart';
import 'editor_session_manager.dart';
import 'export/export_dialog.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/playback_prerender_scheduler.dart';
import 'playback/playback_transport_controls.dart';
import 'storyboard_panel.dart';
import 'storyboard_timeline_layout.dart';
import 'timeline/timeline_action_toolbar.dart';
import 'timeline/timeline_exposure_comma_drag_policy.dart';
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
    super.dispose();
  }

  void _onSessionChanged() {
    setState(() {});
  }

  // --- Storyboard playhead mapping -----------------------------------------
  // The storyboard ruler/playhead work in track-global frames: the active
  // track's cuts laid end to end (the same layout allCuts playback plays).

  List<StoryboardTimelineLayoutEntry> _activeTrackLayout() {
    final layout = buildStoryboardTimelineLayout(
      _session.repository.requireProject(),
    );
    for (final entry in layout) {
      if (entry.cutId == _session.activeCutId) {
        return layout
            .where((candidate) => candidate.trackId == entry.trackId)
            .toList(growable: false);
      }
    }
    return layout;
  }

  /// Where the storyboard playhead sits: the playback position while
  /// playback is active (an activeCut-scope playlist is rebased to frame 0,
  /// so map through the cut's track slot), the editing playhead otherwise.
  int? _storyboardPlayheadFrame() {
    final layout = _activeTrackLayout();
    final playbackPosition = _session.playback.isActive
        ? _session.playback.position
        : null;
    final cutId = playbackPosition?.cutId ?? _session.activeCutId;
    final localFrame =
        playbackPosition?.localFrameIndex ?? _session.currentFrameIndex;
    for (final entry in layout) {
      if (entry.cutId == cutId) {
        final maxLocal = entry.duration > 0 ? entry.duration - 1 : 0;
        return entry.startFrame + localFrame.clamp(0, maxLocal);
      }
    }
    return null;
  }

  void _seekStoryboardGlobalFrame(int globalFrame) {
    final layout = _activeTrackLayout();
    if (layout.isEmpty) {
      return;
    }
    final playback = _session.playback;
    if (playback.isActive) {
      if (playback.scope == PlaybackScope.allCuts) {
        playback.seekToGlobalFrame(globalFrame);
        return;
      }
      // Single-cut playback: its playlist is rebased to frame 0, and seeks
      // outside the playing cut are a no-op.
      for (final entry in layout) {
        if (globalFrame >= entry.startFrame &&
            globalFrame < entry.endFrame &&
            entry.cutId == playback.position?.cutId) {
          playback.seekToGlobalFrame(globalFrame - entry.startFrame);
          return;
        }
      }
      return;
    }
    for (final entry in layout) {
      if (globalFrame >= entry.startFrame && globalFrame < entry.endFrame) {
        if (entry.cutId != _session.activeCutId) {
          _session.selectCut(entry.cutId);
        }
        _session.selectFrameIndex(globalFrame - entry.startFrame);
        return;
      }
    }
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
            tooltip: 'Export',
            onPressed: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder: (context) => ExportDialog(session: _session),
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
          // Cut switching lives in the storyboard panel (blocks select and
          // drag-reorder); the old top chips bar is retired.
          Expanded(child: EditorCanvasArea(session: _session)),
          // Playback ticks flow through the playback-only frame listenable —
          // never the session's notifyListeners — so during playback only
          // this panel rebuilds and the playhead follows every frame. The
          // prerender progress listenable keeps the cached-range green bar
          // live while frames warm in the background.
          ValueListenableBuilder<PrerenderProgress>(
            valueListenable: _session.prerenderScheduler.progress,
            // The global-frame listenable is a superset of the local one
            // (it also fires on cross-cut seeks), so both the timeline and
            // the storyboard playheads ride this single subscription.
            builder: (context, _, _) => ValueListenableBuilder<int?>(
              valueListenable: _session.playback.globalFrameIndexListenable,
              builder: (context, playbackGlobalFrame, _) => TimelinePanel(
                layers: _session.layers,
                activeLayerId: _session.activeLayerId,
                currentFrameIndex: playbackGlobalFrame == null
                    ? _session.currentFrameIndex
                    : _session.playback.position?.localFrameIndex ??
                          _session.currentFrameIndex,
                isFrameCached: _session.isPlaybackFrameCached,
                playbackFrameCount: _session.activeCutPlaybackFrameCount,
                exposureStateForLayer: _session.exposureStateForLayer,
                frameNameForLayer: _session.frameNameForLayer,
                onSelectLayer: _session.selectLayer,
                // Ruler scrubs during playback SEEK the playback clock
                // instead of moving the (hidden) editing playhead.
                onSelectFrame: (frameIndex) {
                  if (_session.playback.isActive) {
                    _session.playback.seekToLocalFrame(frameIndex);
                  } else {
                    _session.selectFrameIndex(frameIndex);
                  }
                },
                onAddLayer: _session.addLayer,
                onToggleLayerVisibility: _session.toggleLayerVisibility,
                onLayerOpacityChanged: (layerId, opacity) {
                  _session.setLayerOpacity(layerId: layerId, opacity: opacity);
                },
                onToggleLayerTimesheet: _session.toggleLayerTimesheet,
                onLayerMarkSelected: _session.setLayerMark,
                // Comma edge drags preview live from the session's
                // drag-start snapshot and commit as ONE undo entry on
                // release.
                commaDrag: TimelineCommaDragCallbacks(
                  onBegin: (layerId, blockStartIndex, edge) =>
                      _session.beginExposureEdgeDrag(
                        layerId: layerId,
                        blockStartIndex: blockStartIndex,
                        edge: edge,
                      ),
                  onUpdate: _session.updateExposureEdgeDrag,
                  onEnd: _session.endExposureEdgeDrag,
                  onCancel: _session.cancelExposureEdgeDrag,
                ),
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
                        onCutReordered: _session.reorderCut,
                        playheadGlobalFrame: _storyboardPlayheadFrame(),
                        onSeekGlobalFrame: _seekStoryboardGlobalFrame,
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
            ),
          ),
        ],
      ),
    );
  }
}
