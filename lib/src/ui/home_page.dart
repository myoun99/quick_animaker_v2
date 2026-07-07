import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
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
import 'export/export_frame_renderer.dart';
import 'export/export_plan.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/playback_prerender_scheduler.dart';
import 'playback/playback_transport_controls.dart';
import 'storyboard_cut_thumbnail_store.dart';
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

  // One shared zoom slider drives whichever view is shown; the values are
  // kept per view so each keeps a sensible default scale.
  double _timelinePixelsPerFrame = TimelinePanel.defaultPixelsPerFrame;
  double _storyboardPixelsPerFrame = 8;

  /// Shared frames↔seconds display toggle (conte-sheet 초+コマ notation).
  bool _showSecondsDisplay = false;

  late final StoryboardCutThumbnailStore _storyboardThumbnails;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject ?? createDefaultProject();
    _session = EditorSessionManager(initialProject: project)
      ..addListener(_onSessionChanged);
    _storyboardThumbnails = StoryboardCutThumbnailStore(
      render: _renderStoryboardThumbnail,
      invalidationHub: _session.cacheInvalidationHub,
    )..addListener(_onSessionChanged);
    widget.onRepositoryCreated?.call(_session.repository);
  }

  @override
  void dispose() {
    _storyboardThumbnails.removeListener(_onSessionChanged);
    _storyboardThumbnails.dispose();
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  /// Thumbnails render the cut's first frame THROUGH THE CAMERA (what the
  /// shot actually frames — conte-sheet style), scaled to a small output;
  /// always current (a fresh renderer replays surfaces straight from the
  /// brush store).
  Future<ui.Image?> _renderStoryboardThumbnail(Cut cut) {
    const thumbnailWidth = 128;
    final cameraSize = _session.cameraFrameSize;
    final height = math.max(
      1,
      (thumbnailWidth * cameraSize.height / cameraSize.width).round(),
    );
    return ExportFrameRenderer(session: _session).renderComposite(
      ExportFrameTask(cut: cut, frameIndex: 0),
      ExportSizeMode.camera,
      outputSize: CanvasSize(width: thumbnailWidth, height: height),
    );
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
  /// An over-end playhead on the track's LAST cut stays unclamped — it
  /// lives in the endless runway, exactly like the timeline shows it.
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
        final isLastCut = identical(entry, layout.last);
        final maxLocal = entry.duration > 0 ? entry.duration - 1 : 0;
        return entry.startFrame +
            (isLastCut && playbackPosition == null
                ? math.max(0, localFrame)
                : localFrame.clamp(0, maxLocal));
      }
    }
    return null;
  }

  /// Whether the track-global [globalFrame]'s playback composite is warmed
  /// — the storyboard ruler's green bar.
  bool _isStoryboardFrameCached(int globalFrame) {
    for (final entry in _activeTrackLayout()) {
      if (globalFrame >= entry.startFrame && globalFrame < entry.endFrame) {
        return _session.isPlaybackFrameCachedForCut(
          entry.cut,
          globalFrame - entry.startFrame,
        );
      }
    }
    return false;
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
    // Beyond the last cut: over-end selection on the last cut, exactly
    // like clicking past the cut end in the timeline.
    final last = layout.last;
    if (globalFrame >= last.endFrame) {
      if (last.cutId != _session.activeCutId) {
        _session.selectCut(last.cutId);
      }
      _session.selectFrameIndex(globalFrame - last.startFrame);
    }
  }

  /// Switching into the storyboard clamps an over-end playhead back onto
  /// the cut (except on the track's last cut, whose runway can show it) so
  /// the frame counter and the playhead line agree.
  void _clampPlayheadForStoryboard() {
    if (_session.playback.isActive) {
      return;
    }
    final layout = _activeTrackLayout();
    if (layout.isEmpty || layout.last.cutId == _session.activeCutId) {
      return;
    }
    final duration = _session.activeCut.duration;
    if (duration > 0 && _session.currentFrameIndex >= duration) {
      _session.selectFrameIndex(duration - 1);
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
        title: const Text('QuickAnimaker'),
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
                  if (show) {
                    _clampPlayheadForStoryboard();
                  }
                  setState(() => _showStoryboard = show);
                },
                pixelsPerFrame: _showStoryboard
                    ? _storyboardPixelsPerFrame
                    : _timelinePixelsPerFrame,
                onPixelsPerFrameChanged: (value) {
                  setState(() {
                    if (_showStoryboard) {
                      _storyboardPixelsPerFrame = value;
                    } else {
                      _timelinePixelsPerFrame = value;
                    }
                  });
                },
                showSeconds: _showSecondsDisplay,
                onShowSecondsChanged: (show) {
                  setState(() => _showSecondsDisplay = show);
                },
                projectFps: _session.projectFps,
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
                      // Play from the storyboard playhead, like the
                      // timeline's transport does.
                      playbackStartFrame: () => _storyboardPlayheadFrame() ?? 0,
                    ),
                    Expanded(
                      child: StoryboardPanel(
                        project: _session.repository.requireProject(),
                        // While playing, the highlight follows the PLAYING
                        // cut (onStopped syncs the real active cut).
                        activeCutId: _session.playback.isActive
                            ? _session.playback.position?.cutId ??
                                  _session.activeCutId
                            : _session.activeCutId,
                        onCutSelected: _session.selectCut,
                        onCutReordered: _session.reorderCut,
                        pixelsPerFrame: _storyboardPixelsPerFrame,
                        showSeconds: _showSecondsDisplay,
                        projectFps: _session.projectFps,
                        // Edge-grip trims preview live and commit ONE undo
                        // on release, like the timeline's comma drags.
                        cutTrim: StoryboardCutTrimCallbacks(
                          onBegin: (cutId, edge) => _session.beginCutEdgeDrag(
                            cutId: cutId,
                            edge: edge,
                          ),
                          onUpdate: _session.updateCutEdgeDrag,
                          onEnd: _session.endCutEdgeDrag,
                          onCancel: _session.cancelCutEdgeDrag,
                        ),
                        playheadGlobalFrame: _storyboardPlayheadFrame(),
                        onSeekGlobalFrame: _seekStoryboardGlobalFrame,
                        isFrameCached: _isStoryboardFrameCached,
                        thumbnailFor: _storyboardThumbnails.thumbnailFor,
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
