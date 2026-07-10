import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../controllers/default_layer_helpers.dart';
import '../controllers/editing_session_state.dart';
import '../controllers/layer_controller.dart';
import '../controllers/timeline_controller.dart';
import '../models/bitmap_surface.dart';
import '../models/audio_clip.dart';
import '../models/brush_frame_key.dart';
import '../models/camera_instruction.dart';
import '../models/camera_pose.dart';
import '../models/canvas_point.dart';
import '../models/canvas_resize_anchor.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_camera.dart';
import '../models/transform_track.dart';
import '../models/cut_id.dart';
import '../models/cut_metadata.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/layer_mark.dart';
import '../models/layer_section_defaults.dart';
import '../models/media_asset.dart';
import '../models/timesheet_document.dart' show timesheetMemoInstructionLine;
import '../models/timesheet_info.dart';
import '../models/project.dart';
import '../models/property_track.dart';
import '../models/timeline_coverage.dart';
import '../models/track_id.dart';
import '../services/brush_frame_display_cache_renderer.dart';
import '../services/brush_frame_store.dart';
import '../services/camera_pose_resolver.dart';
import '../services/clipboard/layer_copy_payload.dart';
import '../models/brush_frame_cache_invalidation.dart';
import '../models/playback_quality.dart';
import '../services/cut_frame_composite_plan.dart';
import '../services/playback/editor_cache_invalidation_hub.dart';
import '../services/playback/playback_frame_mapping.dart';
import 'canvas/canvas_layer_stack_view.dart';
import 'canvas/layer_pose_paint.dart';
import 'playback/audio_playback_sync.dart';
import 'playback/audioplayers_clip_player.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/cut_frame_composite_cache.dart';
import 'playback/layer_frame_image_cache.dart';
import 'playback/playback_cache_budget.dart';
import 'playback/playback_prerender_scheduler.dart';
import 'storyboard_cut_fade_policy.dart';
import 'storyboard_timeline_layout.dart';
import '../services/commands/cut_command_coordinator.dart';
import '../services/commands/cut_reorder_planner.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';
import 'audio/audio_peaks_store.dart';
import 'brush/brush_canvas_panel.dart';
import 'brush/brush_editor_selection.dart';
import 'timeline/instruction_span_editing.dart';
import 'timeline/timeline_cell_exposure_state.dart';
import 'timeline/timeline_section_policy.dart';

/// Owns the editable project session for [HomePage]: the repository, undo
/// history, cut/layer/timeline controllers, the cut command coordinator and the
/// transient clipboards.
///
/// It is a lightweight [ChangeNotifier] (Flutter built-in — no external state
/// package): mutations notify listeners so the hosting widget can rebuild. Pure
/// view state (viewport, brush tool, timeline orientation) intentionally stays
/// in the widget.
class EditorSessionManager extends ChangeNotifier {
  EditorSessionManager({
    required Project initialProject,
    AudioPeaksStore? audioPeaksStore,
  }) : _editingSession = EditingSessionState.forProject(initialProject),
       _injectedAudioPeaksStore = audioPeaksStore,
       _repository = ProjectRepository(initialProject: initialProject) {
    _historyManager = HistoryManager();
    _cutCommandCoordinator = CutCommandCoordinator(
      repository: _repository,
      editingSession: _editingSession,
      historyManager: _historyManager,
      brushFrameStore: brushFrameStore,
    );
    _rebuildActiveCutControllers();
    cacheInvalidationHub.addBrushFrameListener(_onBrushFrameInvalidated);
    audioPlaybackSync.attach();
    playback.globalFrameIndexListenable.addListener(_followPlaybackCut);
  }

  static const FrameId _frameId = FrameId('default-frame');

  final EditingSessionState _editingSession;
  final ProjectRepository _repository;

  /// App-level brush stroke store shared with the canvas host, so commands
  /// (e.g. anchored canvas resize) can transform stroke data.
  final BrushFrameStore brushFrameStore = BrushFrameStore();

  /// Production sink for brush edit invalidations; playback caches and the
  /// prerender scheduler listen here.
  final EditorCacheInvalidationHub cacheInvalidationHub =
      EditorCacheInvalidationHub();

  // --- Playback render cache stack (all non-notifying; see plan R2-R4) -----

  late final LayerFrameImageCache layerFrameImageCache = LayerFrameImageCache(
    frameStore: brushFrameStore,
  );

  late final CutFrameCompositeCache cutFrameCompositeCache =
      CutFrameCompositeCache(
        layerImages: layerFrameImageCache,
        frameStore: brushFrameStore,
        frameKeyOf: brushFrameKeyForCut,
        fxBypassedLayerIdsOf: () => _fxBypassedLayerIds,
      );

  late final PlaybackCacheBudgetEnforcer _playbackCacheBudgetEnforcer =
      PlaybackCacheBudgetEnforcer(
        layerImages: layerFrameImageCache,
        composites: cutFrameCompositeCache,
      );

  late final PlaybackPrerenderScheduler prerenderScheduler =
      PlaybackPrerenderScheduler(
        composites: cutFrameCompositeCache,
        resolveCut: cutById,
        afterFrameCached: () => _playbackCacheBudgetEnforcer.enforce(
          protect: _playbackProtectedRanges(),
        ),
      );

  /// What budget eviction must never touch: the full PLAYING playlist while
  /// playback is active (a looping pass must keep every cut warm so the
  /// second pass plays fully cached), otherwise the active cut's range.
  List<PlaybackProtectedRange> _playbackProtectedRanges() {
    if (playback.isActive) {
      return [
        for (final entry in playback.playlist)
          PlaybackProtectedRange(
            cutId: entry.cutId,
            startFrame: 0,
            endFrame: math.max(0, entry.duration - 1),
            quality: playbackQuality,
          ),
      ];
    }

    final cut = activeCutOrNull;
    if (cut == null) {
      return const [];
    }
    return [
      PlaybackProtectedRange(
        cutId: cut.id,
        startFrame: 0,
        endFrame: math.max(0, cut.duration - 1),
        quality: playbackQuality,
      ),
    ];
  }

  /// Playback preview quality (Premiere/AE monitor resolution analogue).
  PlaybackQuality playbackQuality = defaultPlaybackQuality;

  void setPlaybackQuality(PlaybackQuality quality) {
    if (playbackQuality == quality) {
      return;
    }
    playbackQuality = quality;
    _warmActiveCut();
    notifyListeners();
  }

  /// Canvas playback state machine; only the playback view and transport
  /// controls listen (the session playhead syncs once on stop).
  late final CanvasPlaybackController playback = CanvasPlaybackController(
    resolveProject: () => _repository.requireProject(),
    resolveActiveCutId: () => _editingSession.activeCutId,
    resolveActiveTrackId: () => activeCutTrackId,
    resolveFps: () => projectFps,
    onStopped: _onPlaybackStopped,
    onPlaylistWarmRequested: _onPlaybackPlaylistWarmRequested,
  );

  /// Frame-synced SE audio riding [playback]'s frame signals; clip lengths
  /// come from the waveform peaks store.
  late final AudioPlaybackSync audioPlaybackSync = AudioPlaybackSync(
    controller: playback,
    resolveFps: () => projectFps,
    durationSecondsFor: (filePath) =>
        audioPeaksStore.peaksFor(filePath)?.durationSeconds,
    playerFactory: AudioplayersClipPlayer.new,
  );

  void _onPlaybackStopped(PlaybackPosition lastPosition) {
    if (lastPosition.cutId != _editingSession.activeCutId) {
      selectCut(lastPosition.cutId);
    }
    selectFrameIndex(_clampedFrameIndex(lastPosition.localFrameIndex));
  }

  /// Premiere-style follow: while playback crosses cut boundaries the
  /// ACTIVE cut tracks the playing cut (the timesheet and timeline hosts
  /// show the playing cut's data live) and stays there when playback
  /// stops. Playback-only selection state — no command runs, the undo
  /// stack never sees it. Warming is skipped too: the playlist was warmed
  /// at play start and a boundary tick must stay cheap.
  void _followPlaybackCut() {
    if (playback.globalFrameIndexListenable.value == null) {
      return;
    }
    final position = playback.position;
    if (position == null || position.cutId == _editingSession.activeCutId) {
      return;
    }
    _editingSession.setActiveCutId(position.cutId);
    _copiedFrame = null;
    _rebuildActiveCutControllers(preferredFrameIndex: position.localFrameIndex);
    notifyListeners();
  }

  void _onPlaybackPlaylistWarmRequested(
    List<StoryboardTimelineLayoutEntry> playlist,
    PlaybackScope scope,
    int startGlobalFrame,
  ) {
    // Playhead-forward with wrap-around: the frames about to play warm
    // first, so first-pass misses shrink toward zero and a looping second
    // pass starts fully cached.
    final frames = <(CutId, int)>[
      for (final entry in playlist)
        for (var index = 0; index < entry.duration; index += 1)
          (entry.cutId, index),
    ];
    if (frames.isEmpty) {
      return;
    }
    final start = startGlobalFrame.clamp(0, frames.length - 1);
    prerenderScheduler.requestWarmFrames(
      frames: [...frames.sublist(start), ...frames.sublist(0, start)],
      quality: playbackQuality,
    );
  }

  late final HistoryManager _historyManager;
  late final CutCommandCoordinator _cutCommandCoordinator;
  final CutReorderPlanner _cutReorderPlanner = const CutReorderPlanner();
  late LayerController _layerController;
  late TimelineController _timelineController;

  int _layerSequence = 1;
  int _frameSequence = 0;
  _CopiedFrameReference? _copiedFrame;
  LayerCopyPayload? _layerClipboard;

  ProjectRepository get repository => _repository;
  HistoryManager get historyManager => _historyManager;
  CutId get activeCutId => _editingSession.activeCutId;

  bool get canUndo => _historyManager.canUndo;
  bool get canRedo => _historyManager.canRedo;

  void _rebuildActiveCutControllers({
    LayerId? preferredActiveLayerId,
    int preferredFrameIndex = 0,
  }) {
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
      initialFrameIndex: _clampedFrameIndex(preferredFrameIndex),
    );
    editingFrameCursor.value = _timelineController.currentFrameIndex;
  }

  int _clampedFrameIndex(int frameIndex) {
    final maxIndex = math.max(0, activeCutPlaybackFrameCount - 1);
    return frameIndex.clamp(0, maxIndex);
  }

  TrackId get activeCutTrackId {
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

  void _refreshAfterCutCommand({
    LayerId? preferredActiveLayerId,
    int? preferredFrameIndex,
  }) {
    _copiedFrame = null;
    _rebuildActiveCutControllers(
      preferredActiveLayerId: preferredActiveLayerId,
      preferredFrameIndex:
          preferredFrameIndex ?? _timelineController.currentFrameIndex,
    );
    _warmActiveCut();
  }

  /// The cut with [cutId] anywhere in the project, or `null`.
  Cut? cutById(CutId cutId) {
    for (final track in _repository.requireProject().tracks) {
      for (final cut in track.cuts) {
        if (cut.id == cutId) {
          return cut;
        }
      }
    }
    return null;
  }

  /// The brush store key of a layer frame within [cut] — same derivation the
  /// canvas selection uses (track containing the cut, first track fallback).
  BrushFrameKey brushFrameKeyForCut(Cut cut, LayerId layerId, FrameId frameId) {
    final project = _repository.requireProject();
    var trackId = project.tracks.isEmpty
        ? const TrackId('')
        : project.tracks.first.id;
    for (final track in project.tracks) {
      if (track.cuts.any((candidate) => candidate.id == cut.id)) {
        trackId = track.id;
        break;
      }
    }
    return BrushFrameKey(
      projectId: project.id,
      trackId: trackId,
      cutId: cut.id,
      layerId: layerId,
      frameId: frameId,
    );
  }

  void _onBrushFrameInvalidated(BrushFrameCacheInvalidation invalidation) {
    layerFrameImageCache.invalidateFrame(invalidation.frameKey);
    cutFrameCompositeCache.invalidateWhereLayerFrame(
      layerId: invalidation.frameKey.layerId,
      frameId: invalidation.frameKey.frameId,
    );
    // Warming yields to the edit and then re-renders the dirty frames.
    prerenderScheduler.notifyEditActivity();
    _warmActiveCut();
  }

  /// Warms the active cut's composites around the playhead ("navigate away
  /// from a frame and it gets pre-rendered").
  void _warmActiveCut() {
    if (activeCutOrNull == null) {
      return;
    }
    prerenderScheduler.requestWarmCut(
      cutId: _editingSession.activeCutId,
      quality: playbackQuality,
      aroundFrameIndex: _timelineController.currentFrameIndex,
    );
  }

  @override
  void dispose() {
    cacheInvalidationHub.removeBrushFrameListener(_onBrushFrameInvalidated);
    playback.globalFrameIndexListenable.removeListener(_followPlaybackCut);
    audioPlaybackSync.dispose();
    playback.dispose();
    prerenderScheduler.dispose();
    cutFrameCompositeCache.dispose();
    layerFrameImageCache.dispose();
    audioPeaksStore.dispose();
    editingFrameCursor.dispose();
    frameScrubActive.dispose();
    frameSeekCommitted.dispose();
    _historyManager.dispose();
    super.dispose();
  }

  /// Test seam: widget tests inject a store with a stub extractor so SE-row
  /// rebuilds never spawn the real ffmpeg inside fake async.
  final AudioPeaksStore? _injectedAudioPeaksStore;

  /// Waveform peaks per audio file (ffmpeg extraction, cached); its
  /// notifications forward through the session so SE rows repaint when a
  /// waveform lands.
  late final AudioPeaksStore audioPeaksStore =
      (_injectedAudioPeaksStore ?? AudioPeaksStore())
        ..addListener(notifyListeners);

  bool _activeCutHasLayer(LayerId? layerId) {
    if (layerId == null) {
      return false;
    }
    final cut = activeCutOrNull;
    if (cut == null) {
      return false;
    }
    return cut.layers.any((layer) => layer.id == layerId);
  }

  // --- Cut commands -------------------------------------------------------

  void createCut() {
    _cutCommandCoordinator.createCut(
      trackId: activeCutTrackId,
      // New cuts inherit the active cut's canvas size, like new scenes in
      // TVPaint/Clip Studio inherit the project size.
      canvasSize: activeCutOrNull?.canvasSize,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void resizeActiveCutCanvas(
    CanvasSize canvasSize, {
    CanvasResizeAnchor anchor = CanvasResizeAnchor.center,
  }) {
    _cutCommandCoordinator.resizeCutCanvas(
      cutId: _editingSession.activeCutId,
      canvasSize: canvasSize,
      anchor: anchor,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void duplicateActiveCut() {
    _cutCommandCoordinator.duplicateCut(
      sourceCutId: _editingSession.activeCutId,
      targetTrackId: activeCutTrackId,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void deleteActiveCut() {
    _cutCommandCoordinator.deleteCut(cutId: _editingSession.activeCutId);
    _refreshAfterCutCommand();
    notifyListeners();
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

  bool get canMoveActiveCutLeft {
    final position = _activeCutPositionOrNull;
    return position != null && _cutReorderPlanner.canMoveLeft(position);
  }

  bool get canMoveActiveCutRight {
    final position = _activeCutPositionOrNull;
    return position != null && _cutReorderPlanner.canMoveRight(position);
  }

  void moveActiveCutLeft() {
    final position = _activeCutPosition;
    if (!_cutReorderPlanner.canMoveLeft(position)) {
      return;
    }

    _cutCommandCoordinator.reorderCut(
      trackId: position.trackId,
      cutId: position.cutId,
      newIndex: _cutReorderPlanner.moveLeftTargetIndex(position),
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void moveActiveCutRight() {
    final position = _activeCutPosition;
    if (!_cutReorderPlanner.canMoveRight(position)) {
      return;
    }

    _cutCommandCoordinator.reorderCut(
      trackId: position.trackId,
      cutId: position.cutId,
      newIndex: _cutReorderPlanner.moveRightTargetIndex(position),
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void reorderCut({
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

    _cutCommandCoordinator.reorderCut(
      trackId: plan.trackId,
      cutId: plan.cutId,
      newIndex: plan.newIndex,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  String? get activeCutNote => activeCutOrNull?.metadata.note;

  void updateActiveCutNote(String note) {
    _cutCommandCoordinator.updateCutNote(
      cutId: _editingSession.activeCutId,
      note: note,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Whether the active cut's storyboard thumbnail is pinned to the
  /// playhead frame (drives the toolbar toggle's state).
  bool get isActiveCutThumbnailPinnedHere =>
      activeCutOrNull?.metadata.thumbnailFrameIndex ==
          _timelineController.currentFrameIndex &&
      activeCutOrNull?.metadata.thumbnailFrameIndex != null;

  /// Pins the active cut's storyboard thumbnail to the playhead frame, or
  /// releases the pin back to the first frame when pressed on the pinned
  /// frame itself (toggle; one undo step either way).
  void toggleActiveCutThumbnailFrame() {
    final frame = _timelineController.currentFrameIndex;
    final pinned = activeCutOrNull?.metadata.thumbnailFrameIndex;
    _cutCommandCoordinator.updateCutThumbnailFrame(
      cutId: _editingSession.activeCutId,
      frameIndex: pinned == frame ? null : frame,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  Cut? get activeCutOrNull {
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

  int get activeCutPlaybackFrameCount => math.max(1, activeCut.duration);

  Cut get activeCut {
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

  void renameActiveCut(String newName) {
    _cutCommandCoordinator.renameCut(
      cutId: _editingSession.activeCutId,
      newName: newName,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  // --- Camera --------------------------------------------------------------

  CutCamera get activeCutCamera => activeCut.camera;

  /// The camera's output frame size (the exported picture size); the camera
  /// view rect on canvas is this divided by the pose zoom.
  CanvasSize get cameraFrameSize => _repository.requireProject().cameraSize;

  int get projectFps => _repository.requireProject().fps;

  /// Resolved camera pose at an arbitrary playback frame (for rendering).
  CameraPose cameraPoseAtFrame(int frameIndex) => resolveCameraPoseAt(
    camera: activeCut.camera,
    canvasSize: activeCut.canvasSize,
    frameIndex: frameIndex,
  );

  /// Resolved camera pose for any cut (play-all renders other cuts too).
  /// The camera ROW's fx switch bypasses the camera work on this render
  /// route (playback, export, storyboard thumbnails all resolve through
  /// here) — the authoring overlays keep reading the real pose.
  CameraPose cameraPoseForCut(Cut cut, int frameIndex) {
    if (_cameraFxBypassedFor(cut)) {
      return CameraPose(
        center: CanvasPoint(
          x: cut.canvasSize.width / 2,
          y: cut.canvasSize.height / 2,
        ),
      );
    }
    return resolveCameraPoseAt(
      camera: cut.camera,
      canvasSize: cut.canvasSize,
      frameIndex: frameIndex,
    );
  }

  /// Whether [cut]'s camera layer sits in the fx-bypass set.
  bool _cameraFxBypassedFor(Cut cut) {
    for (final layer in cut.layers) {
      if (layer.kind == LayerKind.camera) {
        return _fxBypassedLayerIds.contains(layer.id);
      }
    }
    return false;
  }

  /// The editing canvas's layer stack at the playhead: which non-active
  /// layers composite below/above the interactive layer (bottom → top,
  /// hidden/transparent/undrawn layers skipped) and the active layer's own
  /// display opacity (0 while hidden; includes its animated Opacity). The
  /// active layer's pose rides separately ([layerCanvasPoseSample]) into
  /// the interactive view's draw-through wrap.
  ({
    List<CanvasLayerImageRequest> below,
    List<CanvasLayerImageRequest> above,
    double activeLayerOpacity,
  })
  get editingCanvasStack {
    final cut = activeCutOrNull;
    final activeLayerId = this.activeLayerId;
    final below = <CanvasLayerImageRequest>[];
    final above = <CanvasLayerImageRequest>[];
    var activeLayerOpacity = 1.0;
    if (cut == null) {
      return (below: below, above: above, activeLayerOpacity: 1.0);
    }

    final frameIndex = _timelineController.currentFrameIndex;
    var seenActiveLayer = false;
    for (final layer in cut.layers) {
      final fxEnabled = isLayerFxEnabled(layer.id);
      if (layer.id == activeLayerId) {
        seenActiveLayer = true;
        activeLayerOpacity = !layer.isVisible
            ? 0.0
            : fxEnabled
            ? resolveLayerEffectiveOpacityAt(
                layer: layer,
                frameIndex: frameIndex,
              )
            : layer.opacity.clamp(0.0, 1.0).toDouble();
        continue;
      }
      if (layer.kind == LayerKind.camera ||
          !layer.isVisible ||
          layer.opacity <= 0) {
        continue;
      }
      final opacity = fxEnabled
          ? resolveLayerEffectiveOpacityAt(layer: layer, frameIndex: frameIndex)
          : layer.opacity.clamp(0.0, 1.0).toDouble();
      if (opacity <= 0) {
        continue;
      }
      final frame = resolveExposedFrameAt(layer, frameIndex);
      if (frame == null) {
        continue;
      }
      (seenActiveLayer ? above : below).add(
        CanvasLayerImageRequest(
          frameKey: brushFrameKeyForCut(cut, layer.id, frame.id),
          opacity: opacity,
          pose: fxEnabled
              ? resolveLayerPoseAt(
                  layer: layer,
                  canvasSize: cut.canvasSize,
                  frameIndex: frameIndex,
                )
              : null,
          anchorPoint: fxEnabled
              ? resolveLayerAnchorPointAt(layer: layer, frameIndex: frameIndex)
              : null,
        ),
      );
    }
    return (below: below, above: above, activeLayerOpacity: activeLayerOpacity);
  }

  /// The geometric pose sample the interactive canvas shows for [layerId]
  /// at the playhead — the draw-through wrap input. Null = identity (no
  /// transform work, fx bypassed, or no such layer), which skips the wrap:
  /// the ALWAYS-APPLIED rule (the active layer shows its transform too; the
  /// old edit-in-artwork-space rule is retired, R3 ⑩).
  LayerPoseSample? layerCanvasPoseSample(LayerId layerId) {
    final cut = activeCutOrNull;
    if (cut == null || !isLayerFxEnabled(layerId)) {
      return null;
    }
    for (final layer in cut.layers) {
      if (layer.id != layerId) {
        continue;
      }
      final pose = resolveLayerPoseAt(
        layer: layer,
        canvasSize: cut.canvasSize,
        frameIndex: _timelineController.currentFrameIndex,
      );
      if (pose == null) {
        return null;
      }
      return (
        pose: pose,
        anchorPoint: resolveLayerAnchorPointAt(
          layer: layer,
          frameIndex: _timelineController.currentFrameIndex,
        ),
      );
    }
    return null;
  }

  /// Whether the playback composite for [frameIndex] is warmed at the
  /// current quality (the timeline's cached-range "green bar").
  bool isPlaybackFrameCached(int frameIndex) {
    final cut = activeCutOrNull;
    if (cut == null) {
      return false;
    }
    return isPlaybackFrameCachedForCut(cut, frameIndex);
  }

  /// [isPlaybackFrameCached] for an arbitrary cut — the storyboard's green
  /// bar spans every cut of the track.
  bool isPlaybackFrameCachedForCut(Cut cut, int frameIndex) {
    return cutFrameCompositeCache.validCompositeOrNull(
          cut: cut,
          frameIndex: frameIndex,
          quality: playbackQuality,
        ) !=
        null;
  }

  /// The drawable artwork of one layer frame in the active cut; `null` when
  /// nothing is drawn. This is the production [LayerFrameSurfaceResolver]
  /// for camera preview/export compositing. The store's display cache is
  /// consumed READ-ONLY when valid (the editing coordinator donates the
  /// session surface on every commit/undo/redo); replaying the frame's
  /// paint commands is the cold fallback.
  BitmapSurface? brushSurfaceForLayerFrame(Layer layer, Frame frame) {
    final frameKey = BrushFrameKey(
      projectId: _repository.requireProject().id,
      trackId: activeCutTrackId,
      cutId: _editingSession.activeCutId,
      layerId: layer.id,
      frameId: frame.id,
    );
    final drawing = brushFrameStore.frameOrNull(frameKey);
    if (drawing == null || drawing.allPaintCommandsInDisplayOrder.isEmpty) {
      return null;
    }
    final cached = brushFrameStore.displayCacheOrNull(frameKey);
    if (cached != null &&
        cached.isValid &&
        cached.previewSurface.canvasSize == activeCut.canvasSize) {
      return cached.previewSurface;
    }
    return BrushFrameDisplayCacheRenderer(
      canvasSize: activeCut.canvasSize,
    ).rebuildPreview(drawing);
  }

  /// The resolved camera pose at the current playhead frame (keyframe,
  /// interpolation, or the default pose when the cut has no camera work).
  CameraPose get cameraPoseAtCurrentFrame => resolveCameraPoseAt(
    camera: activeCut.camera,
    canvasSize: activeCut.canvasSize,
    frameIndex: _timelineController.currentFrameIndex,
  );

  bool get hasCameraKeyframeAtCurrentFrame =>
      activeCut.camera.keyframeAt(_timelineController.currentFrameIndex) !=
      null;

  void setCameraKeyframeAtCurrentFrame(CameraPose pose) {
    _cutCommandCoordinator.setCutCameraKeyframe(
      cutId: _editingSession.activeCutId,
      frameIndex: _timelineController.currentFrameIndex,
      pose: pose,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void removeCameraKeyframeAtCurrentFrame() {
    _cutCommandCoordinator.removeCutCameraKeyframe(
      cutId: _editingSession.activeCutId,
      frameIndex: _timelineController.currentFrameIndex,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void clearActiveCutCamera() {
    _cutCommandCoordinator.clearCutCamera(cutId: _editingSession.activeCutId);
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Replaces the active cut's camera track (one undo step) — the property
  /// lanes' per-property key edits route through here.
  void updateActiveCutCameraTrack(
    TransformTrack track, {
    String description = 'Edit camera keyframes',
  }) {
    _cutCommandCoordinator.updateCutCamera(
      cutId: _editingSession.activeCutId,
      camera: CutCamera.fromTrack(track),
      description: description,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Sets [cutId]'s fade in/out lengths (the storyboard V-track's fade
  /// handles): rewrites the cut-level transform's opacity lane to the
  /// canonical fade shape; one undo step, no-op when unchanged.
  void setCutFade(
    CutId cutId, {
    required int fadeInFrames,
    required int fadeOutFrames,
  }) {
    final cut = cutById(cutId);
    if (cut == null) {
      return;
    }
    _cutCommandCoordinator.updateCutTransform(
      cutId: cutId,
      transformTrack: cutTransformWithFade(
        cut,
        fadeInFrames: fadeInFrames,
        fadeOutFrames: fadeOutFrames,
      ),
      description: 'Fade cut',
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Replaces [cutId]'s cut-level transform track (the storyboard V
  /// track's Transform lanes — the whole cut's finished picture moving on
  /// the display space, applied at display time like the fade, never
  /// baked into composites); one undo step, no-op when unchanged. The
  /// fade handles keep writing the same track through [setCutFade].
  void updateCutTransformTrack(
    CutId cutId,
    TransformTrack track, {
    String description = 'Edit cut transform',
  }) {
    _cutCommandCoordinator.updateCutTransform(
      cutId: cutId,
      transformTrack: track,
      description: description,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Sets what [cutId]'s fade fades TO — black (FO) or white (WO); one
  /// undo step, no-op when unchanged. Playback and the MP4 bake share the
  /// value.
  void setCutFadeTarget(CutId cutId, CutFadeTarget fadeTarget) {
    _cutCommandCoordinator.updateCutFadeTarget(
      cutId: cutId,
      fadeTarget: fadeTarget,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Replaces [layerId]'s transform track (the AE Transform lanes on every
  /// drawing layer — applied at composite time, never baked); one undo
  /// step, no-op when unchanged.
  void updateLayerTransformTrack(
    LayerId layerId,
    TransformTrack track, {
    String description = 'Edit layer transform',
  }) {
    _cutCommandCoordinator.updateLayerTransformTrack(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      transformTrack: track,
      description: description,
    );
    notifyListeners();
  }

  /// The layer's resolved transform pose at [frameIndex] (identity while
  /// the track is empty) — the lane value column and key-freeze source.
  TransformPose layerPoseAtFrame(Layer layer, int frameIndex) {
    return layer.transformTrack.resolveAt(
      frameIndex: frameIndex,
      orElse: () => layerIdentityPose(activeCut.canvasSize),
    );
  }

  /// The layer's resolved anchor point at [frameIndex] — the anchor-point
  /// lane's value column and key-freeze source (canvas center while
  /// unkeyed).
  CanvasPoint layerAnchorPointAtFrame(Layer layer, int frameIndex) {
    return resolveLayerAnchorPointAt(layer: layer, frameIndex: frameIndex) ??
        CanvasPoint(
          x: activeCut.canvasSize.width / 2,
          y: activeCut.canvasSize.height / 2,
        );
  }

  /// The layer's animated Opacity sample (0..1; 1 while unkeyed) — the
  /// opacity lane's value column and key-freeze source.
  double layerOpacityAtFrame(Layer layer, int frameIndex) {
    return resolveOpacityTrackAt(layer.transformTrack.opacity, frameIndex);
  }

  // --- Layer FX bypass (session view state, not persisted) -----------------

  /// Layers whose FX (transform + animated opacity) are bypassed on every
  /// composite route — the layer-label fx switch. The set joins the
  /// composite signatures, so toggling self-invalidates the caches.
  final Set<LayerId> _fxBypassedLayerIds = {};

  Set<LayerId> get fxBypassedLayerIds => _fxBypassedLayerIds;

  bool isLayerFxEnabled(LayerId layerId) =>
      !_fxBypassedLayerIds.contains(layerId);

  void toggleLayerFx(LayerId layerId) {
    if (!_fxBypassedLayerIds.remove(layerId)) {
      _fxBypassedLayerIds.add(layerId);
    }
    notifyListeners();
  }

  void undo() {
    final beforeLayers = List<Layer>.of(activeCut.layers);
    final previousActiveLayerId = _layerController.activeLayerId;
    final previousFrameIndex = _timelineController.currentFrameIndex;

    _historyManager.undo();
    final preferredLayerId = _preferredLayerAfterLayerListChange(
      beforeLayers: beforeLayers,
      afterLayers: activeCut.layers,
      previousActiveLayerId: previousActiveLayerId,
    );
    _refreshAfterCutCommand(
      preferredActiveLayerId: preferredLayerId,
      preferredFrameIndex: previousFrameIndex,
    );
    notifyListeners();
  }

  void redo() {
    final beforeLayers = List<Layer>.of(activeCut.layers);
    final previousActiveLayerId = _layerController.activeLayerId;
    final previousFrameIndex = _timelineController.currentFrameIndex;

    _historyManager.redo();
    final preferredLayerId = _preferredLayerAfterLayerListChange(
      beforeLayers: beforeLayers,
      afterLayers: activeCut.layers,
      previousActiveLayerId: previousActiveLayerId,
    );
    _refreshAfterCutCommand(
      preferredActiveLayerId: preferredLayerId,
      preferredFrameIndex: previousFrameIndex,
    );
    notifyListeners();
  }

  void selectCut(CutId cutId) {
    if (cutId == _editingSession.activeCutId) {
      return;
    }

    _editingSession.setActiveCutId(cutId);
    _copiedFrame = null;
    _rebuildActiveCutControllers();
    _warmActiveCut();
    notifyListeners();
  }

  // --- Layer state / commands --------------------------------------------

  List<Layer> get layers => _layerController.layers;
  LayerId? get activeLayerId => _layerController.activeLayerId;
  Layer? get activeLayer => _layerController.activeLayer;

  BrushEditorSelection? get activeBrushEditorSelection {
    final activeLayer = this.activeLayer;
    final selectedFrame = this.selectedFrame;
    if (activeLayer == null || selectedFrame == null) {
      return null;
    }

    return BrushEditorSelection(
      projectId: _repository.requireProject().id,
      trackId: activeCutTrackId,
      cutId: _editingSession.activeCutId,
      layerId: activeLayer.id,
      frameId: selectedFrame.id,
    );
  }

  bool get canDeleteActiveLayer {
    final activeLayer = this.activeLayer;
    if (activeLayer == null) {
      return false;
    }
    final layers = activeCut.layers;
    return switch (activeLayer.kind) {
      LayerKind.camera => false,
      // The sheet's fixture floors: at least two SE rows (S1·S2) and one
      // instruction row survive.
      LayerKind.se =>
        layers.where((layer) => layer.kind == LayerKind.se).length > 2,
      LayerKind.instruction =>
        layers.where((layer) => layer.kind == LayerKind.instruction).length > 1,
      // Keep at least one drawing-section layer in the cut.
      LayerKind.animation || LayerKind.storyboard || LayerKind.art =>
        layers
                .where(
                  (layer) =>
                      timelineSectionForLayerKind(layer.kind) ==
                      TimelineSection.drawing,
                )
                .length >=
            2,
    };
  }

  /// Whether the canvas is in camera manipulation mode.
  bool get isCameraLayerActive => activeLayer?.kind == LayerKind.camera;

  /// What the canvas shows while the camera layer is active: the first
  /// visible drawing layer with a frame at the playhead, so there is artwork
  /// to frame. `null` when the cut has nothing drawn at this frame.
  BrushEditorSelection? get cameraBackdropSelection {
    final frameIndex = _timelineController.currentFrameIndex;
    for (final layer in activeCut.layers) {
      if (layer.kind == LayerKind.camera || !layer.isVisible) {
        continue;
      }
      final frame = _timelineController.resolveFrameForLayer(
        layer: layer,
        frameIndex: frameIndex,
      );
      if (frame == null) {
        continue;
      }
      return BrushEditorSelection(
        projectId: _repository.requireProject().id,
        trackId: activeCutTrackId,
        cutId: _editingSession.activeCutId,
        layerId: layer.id,
        frameId: frame.id,
      );
    }
    return null;
  }

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

  String? get layerClipboardName => _layerClipboard?.name;
  bool get hasLayerClipboard => _layerClipboard != null;

  void copyActiveLayer() {
    final activeLayer = this.activeLayer;
    if (activeLayer == null || activeLayer.kind == LayerKind.camera) {
      return;
    }

    _layerClipboard = copyLayerToPayload(activeLayer);
    notifyListeners();
  }

  void pasteLayerFromClipboard() {
    final payload = _layerClipboard;
    if (payload == null) {
      return;
    }

    final activeLayer = this.activeLayer;
    final targetLayers = activeCut.layers;
    final activeLayerIndex = activeLayer == null
        ? -1
        : targetLayers.indexWhere((layer) => layer.id == activeLayer.id);
    final insertionIndex = activeLayerIndex == -1
        ? targetLayers.length
        : activeLayerIndex + 1;

    final pastedLayerId = _cutCommandCoordinator.pasteLayer(
      cutId: _editingSession.activeCutId,
      payload: payload,
      insertionIndex: insertionIndex,
    );
    _refreshAfterCutCommand(preferredActiveLayerId: pastedLayerId);
    notifyListeners();
  }

  void duplicateActiveLayer() {
    final activeLayer = this.activeLayer;
    if (activeLayer == null || activeLayer.kind == LayerKind.camera) {
      return;
    }

    final duplicatedLayerId = _cutCommandCoordinator.duplicateLayer(
      cutId: _editingSession.activeCutId,
      sourceLayerId: activeLayer.id,
    );
    _refreshAfterCutCommand(preferredActiveLayerId: duplicatedLayerId);
    notifyListeners();
  }

  /// Deletes the active layer. Callers should confirm via dialog first and check
  /// [canDeleteActiveLayer]; this is a no-op when deletion is not allowed.
  void deleteActiveLayer() {
    final activeLayer = this.activeLayer;
    if (activeLayer == null || !canDeleteActiveLayer) {
      return;
    }

    final beforeLayers = List<Layer>.of(activeCut.layers);
    final nextActiveLayerId = _stableLayerIdAfterDeleting(
      beforeLayers: beforeLayers,
      deletedLayerId: activeLayer.id,
    );

    _cutCommandCoordinator.deleteLayer(
      cutId: _editingSession.activeCutId,
      layerId: activeLayer.id,
    );
    _refreshAfterCutCommand(preferredActiveLayerId: nextActiveLayerId);
    notifyListeners();
  }

  void renameActiveLayer(String name) {
    final activeLayer = this.activeLayer;
    if (activeLayer == null) {
      return;
    }

    final activeLayerId = activeLayer.id;
    _cutCommandCoordinator.renameLayer(
      cutId: _editingSession.activeCutId,
      layerId: activeLayerId,
      name: name,
    );
    _refreshAfterCutCommand(preferredActiveLayerId: activeLayerId);
    notifyListeners();
  }

  /// THE unified Add Layer entrance: a new layer of the ACTIVE layer's
  /// kind, inserted directly above it, named by its section's own scheme
  /// (cel letters / S3 / CAM 2). The camera cannot be duplicated (exactly
  /// one per cut) — with it (or nothing) active, a default cel is added.
  void addLayer() {
    _layerSequence += 1;
    final layerId = defaultLayerIdForSequence(_layerSequence);
    final kind = activeLayer?.kind ?? LayerKind.animation;
    switch (kind) {
      case LayerKind.se:
        _layerController.addLayer(
          layer: Layer(
            id: layerId,
            name: nextSeLayerName(_layerController.layers),
            frames: const [],
            timeline: const {},
            kind: LayerKind.se,
          ),
        );
      case LayerKind.instruction:
        _layerController.addLayer(
          layer: Layer(
            id: layerId,
            name: nextInstructionLayerName(_layerController.layers),
            frames: const [],
            timeline: const {},
            kind: LayerKind.instruction,
          ),
        );
      case LayerKind.animation:
      case LayerKind.storyboard:
      case LayerKind.art:
        _layerController.addLayerWithDefaults(layerId: layerId, kind: kind);
      case LayerKind.camera:
        _layerController.addLayerWithDefaults(layerId: layerId);
    }
    notifyListeners();
  }

  void selectLayer(LayerId layerId) {
    _layerController.selectLayer(layerId);
    notifyListeners();
  }

  void toggleLayerVisibility(LayerId layerId) {
    _layerController.toggleLayerVisibility(layerId);
    notifyListeners();
  }

  /// Silences/unsilences an SE row's sounds (the mute button — view state
  /// like visibility, not undoable): playback and export skip muted
  /// layers' clips, waveforms keep displaying.
  void toggleLayerMuted(LayerId layerId) {
    _layerController.toggleLayerMuted(layerId);
    notifyListeners();
  }

  void setLayerOpacity({required LayerId layerId, required double opacity}) {
    _layerController.setLayerOpacity(layerId: layerId, opacity: opacity);
    notifyListeners();
  }

  /// Flips whether [layerId] is recorded on the timesheet output. One undo
  /// step; no controller rebuild — the flag never affects rendering.
  void toggleLayerTimesheet(LayerId layerId) {
    final layer = layers.firstWhere((layer) => layer.id == layerId);
    _cutCommandCoordinator.setLayerTimesheet(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      onTimesheet: !layer.onTimesheet,
    );
    notifyListeners();
  }

  /// Project-level sheet-header text (title/episode/artist) the timesheet
  /// document reads.
  TimesheetInfo get timesheetInfo => _repository.requireProject().timesheetInfo;

  /// One undo step; no-op when unchanged.
  void updateTimesheetInfo(TimesheetInfo info) {
    _cutCommandCoordinator.setTimesheetInfo(info);
    notifyListeners();
  }

  /// Sets [layerId]'s organizational color mark. One undo step.
  void setLayerMark(LayerId layerId, LayerMark mark) {
    _cutCommandCoordinator.setLayerMark(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      mark: mark,
    );
    notifyListeners();
  }

  /// The project's instruction vocabulary (FI/FO/PAN …, user-editable).
  CameraInstructionSet get cameraInstructionSet =>
      _repository.requireProject().cameraInstructions;

  /// One undo step; no-op when unchanged.
  void updateCameraInstructionSet(CameraInstructionSet instructionSet) {
    _cutCommandCoordinator.updateCameraInstructionSet(instructionSet);
    notifyListeners();
  }

  /// Replaces [layerId]'s instruction span map (instruction rows only).
  /// One undo step; no-op when unchanged. Never touches rendering caches —
  /// instruction spans are timeline annotations, not composite inputs.
  void updateLayerInstructions(
    LayerId layerId,
    Map<int, InstructionEvent> instructions, {
    String description = 'Edit instructions',
  }) {
    _cutCommandCoordinator.updateLayerInstructions(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      instructions: instructions,
      description: description,
    );
    notifyListeners();
  }

  /// The instruction span covering [frameIndex] on [layerId], as
  /// (startIndex, event); null on empty cells / non-instruction rows.
  MapEntry<int, InstructionEvent>? instructionSpanAt(
    LayerId layerId,
    int frameIndex,
  ) {
    final layer = _layerById(layerId);
    if (layer == null || layer.kind != LayerKind.instruction) {
      return null;
    }
    return instructionSpanCovering(layer.instructions, frameIndex);
  }

  /// Creates or edits the instruction event at [frameIndex] in ONE undo
  /// step: a covered cell replaces its span's event (start/length stay), an
  /// empty cell starts a new span holding to the next one / the cut's end.
  void upsertInstructionEventAt(
    LayerId layerId,
    int frameIndex,
    InstructionEvent event, {
    int? createLengthFrames,
  }) {
    final layer = _layerById(layerId);
    if (layer == null || layer.kind != LayerKind.instruction) {
      return;
    }

    // New events take the dialog's length (clamped into the cut; the add
    // helper clamps at the next span too); null fills to the cut end.
    final available = (activeCut.duration - frameIndex).clamp(1, 1 << 20);
    final covering = instructionSpanCovering(layer.instructions, frameIndex);
    final next = covering != null
        ? instructionMapWithEventReplaced(
            layer.instructions,
            spanStartIndex: covering.key,
            event: event,
          )
        : instructionMapWithEventAdded(
            layer.instructions,
            startIndex: frameIndex,
            event: event.copyWith(
              length: (createLengthFrames ?? available).clamp(1, available),
            ),
          );
    if (next == null) {
      return;
    }
    // The sheet's memo shorthand ('A→B PAN memo') writes itself ONCE at
    // creation and stays user-editable note text from then on (R5-⑥ — the
    // derived always-printed line could not be edited). Edits and removals
    // never rewrite the note; the user owns it. Event + note = ONE undo.
    String? appendedNote;
    if (covering == null) {
      final line = timesheetMemoInstructionLine(
        event,
        cameraInstructionSet.defById(event.instructionId),
      );
      if (line.isNotEmpty) {
        final note = activeCutNote ?? '';
        appendedNote = note.isEmpty ? line : '$note\n$line';
      }
    }
    _cutCommandCoordinator.updateLayerInstructions(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      instructions: next,
      description: covering == null ? 'Add instruction' : 'Edit instruction',
      note: appendedNote,
    );
    notifyListeners();
  }

  /// Removes the instruction span covering [frameIndex]; one undo step.
  void removeInstructionEventAt(LayerId layerId, int frameIndex) {
    final layer = _layerById(layerId);
    if (layer == null || layer.kind != LayerKind.instruction) {
      return;
    }
    final covering = instructionSpanCovering(layer.instructions, frameIndex);
    if (covering == null) {
      return;
    }
    final next = instructionMapWithEventRemoved(
      layer.instructions,
      spanStartIndex: covering.key,
    );
    if (next == null) {
      return;
    }
    updateLayerInstructions(layerId, next, description: 'Delete instruction');
  }

  /// Whether the active layer can take an audio clip (SE rows only).
  bool get canImportAudioToActiveLayer => activeLayer?.kind == LayerKind.se;

  /// Links [filePath] to the SE instance under the playhead — sounds are
  /// FRAME-LINKED like drawings: the carrying block is the sound's window
  /// (start, length) and deleting the block silences it. Importing onto an
  /// empty cell creates the SE instance first (its own undo step), then
  /// links the sound (one more).
  void addAudioClipToActiveSeLayer(String filePath) {
    final layer = activeLayer;
    if (layer == null || layer.kind != LayerKind.se) {
      return;
    }
    // Re-importing a path restarts its waveform extraction from scratch
    // (fresh attempt budget — the file may have changed on disk).
    audioPeaksStore.invalidate(filePath);
    final frameIndex = _timelineController.currentFrameIndex < 0
        ? 0
        : _timelineController.currentFrameIndex;
    var frame = resolveExposedFrameAt(layer, frameIndex);
    if (frame == null) {
      createSeEntryAtCurrentFrame(name: '');
      final created = activeLayer;
      frame = created == null
          ? null
          : resolveExposedFrameAt(created, frameIndex);
      if (frame == null) {
        return;
      }
    }
    final carrier = activeLayer ?? layer;
    // The pool learns every imported file (its own undo step, like the
    // SE-instance creation above) so the browser can offer it for reuse.
    addMediaAssets([filePath]);
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: carrier.id,
      audioClips: [
        ...carrier.audioClips,
        AudioClip(filePath: filePath, frameId: frame.id),
      ],
      description: 'Import audio',
    );
    notifyListeners();
  }

  /// Removes the [clipIndex]th clip of [layerId]; one undo step.
  void removeAudioClipAt(LayerId layerId, int clipIndex) {
    final layer = _layerById(layerId);
    if (layer == null ||
        layer.kind != LayerKind.se ||
        clipIndex < 0 ||
        clipIndex >= layer.audioClips.length) {
      return;
    }
    final next = [...layer.audioClips]..removeAt(clipIndex);
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: next,
      description: 'Remove audio',
    );
    notifyListeners();
  }

  /// Sets the [clipIndex]th clip's offset trim (frames skipped into the
  /// file where its block starts) — the audio lane's slide edit; one undo
  /// step, clamped non-negative, no-op when unchanged.
  void setAudioClipOffset(LayerId layerId, int clipIndex, int offsetFrames) {
    final layer = _layerById(layerId);
    if (layer == null ||
        layer.kind != LayerKind.se ||
        clipIndex < 0 ||
        clipIndex >= layer.audioClips.length) {
      return;
    }
    final clamped = offsetFrames < 0 ? 0 : offsetFrames;
    if (layer.audioClips[clipIndex].offsetFrames == clamped) {
      return;
    }
    final next = [...layer.audioClips];
    next[clipIndex] = next[clipIndex].copyWith(offsetFrames: clamped);
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: next,
      description: 'Slide sound',
    );
    notifyListeners();
  }

  // --- Audio offset live drags (comma-drag idiom) --------------------------

  List<AudioClip>? _audioOffsetDragBefore;
  LayerId? _audioOffsetDragLayerId;
  int? _audioOffsetDragClipIndex;

  /// Starts a live slide of [layerId]'s [clipIndex]th sound: the drag
  /// previews repo-direct (every waveform view repaints from the model in
  /// real time) and [endAudioClipOffsetDrag] commits ONE undo step.
  bool beginAudioClipOffsetDrag({
    required LayerId layerId,
    required int clipIndex,
  }) {
    final layer = _layerById(layerId);
    if (layer == null ||
        layer.kind != LayerKind.se ||
        clipIndex < 0 ||
        clipIndex >= layer.audioClips.length) {
      return false;
    }
    _audioOffsetDragBefore = layer.audioClips;
    _audioOffsetDragLayerId = layerId;
    _audioOffsetDragClipIndex = clipIndex;
    return true;
  }

  /// Applies the dragged ABSOLUTE offset as a live preview (clamped ≥ 0);
  /// no-op while no drag is in flight or the value is unchanged.
  void updateAudioClipOffsetDrag(int offsetFrames) {
    final layerId = _audioOffsetDragLayerId;
    final clipIndex = _audioOffsetDragClipIndex;
    if (layerId == null || clipIndex == null) {
      return;
    }
    final layer = _layerById(layerId);
    if (layer == null || clipIndex >= layer.audioClips.length) {
      return;
    }
    final clamped = offsetFrames < 0 ? 0 : offsetFrames;
    if (layer.audioClips[clipIndex].offsetFrames == clamped) {
      return;
    }
    final next = [...layer.audioClips];
    next[clipIndex] = next[clipIndex].copyWith(offsetFrames: clamped);
    _repository.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: next,
    );
    notifyListeners();
  }

  /// Commits the slide as a single undo step: the preview reverts
  /// silently, then the normal clip command applies the final list (its
  /// before-snapshot stays correct).
  void endAudioClipOffsetDrag() {
    final before = _audioOffsetDragBefore;
    final layerId = _audioOffsetDragLayerId;
    _audioOffsetDragBefore = null;
    _audioOffsetDragLayerId = null;
    _audioOffsetDragClipIndex = null;
    if (before == null || layerId == null) {
      return;
    }
    final layer = _layerById(layerId);
    if (layer == null) {
      return;
    }
    final after = layer.audioClips;
    if (listEquals(after, before)) {
      return;
    }
    _repository.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: before,
    );
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: after,
      description: 'Slide sound',
    );
    notifyListeners();
  }

  /// Reverts an in-flight slide preview without touching history.
  void cancelAudioClipOffsetDrag() {
    final before = _audioOffsetDragBefore;
    final layerId = _audioOffsetDragLayerId;
    _audioOffsetDragBefore = null;
    _audioOffsetDragLayerId = null;
    _audioOffsetDragClipIndex = null;
    if (before == null || layerId == null) {
      return;
    }
    final layer = _layerById(layerId);
    if (layer == null || listEquals(layer.audioClips, before)) {
      return;
    }
    _repository.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: before,
    );
    notifyListeners();
  }

  /// Sets the [clipIndex]th clip's fade lengths (the audio lane's edge
  /// handles); one undo step, clamped non-negative, no-op when unchanged.
  void setAudioClipFades(
    LayerId layerId,
    int clipIndex, {
    required int fadeInFrames,
    required int fadeOutFrames,
  }) {
    final layer = _layerById(layerId);
    if (layer == null ||
        layer.kind != LayerKind.se ||
        clipIndex < 0 ||
        clipIndex >= layer.audioClips.length) {
      return;
    }
    final clampedIn = fadeInFrames < 0 ? 0 : fadeInFrames;
    final clampedOut = fadeOutFrames < 0 ? 0 : fadeOutFrames;
    final clip = layer.audioClips[clipIndex];
    if (clip.fadeInFrames == clampedIn && clip.fadeOutFrames == clampedOut) {
      return;
    }
    final next = [...layer.audioClips];
    next[clipIndex] = clip.copyWith(
      fadeInFrames: clampedIn,
      fadeOutFrames: clampedOut,
    );
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: next,
      description: 'Fade sound',
    );
    notifyListeners();
  }

  /// Sets the [clipIndex]th clip's gain (the audio lane's volume dialog);
  /// one undo step, clamped non-negative, no-op when unchanged.
  void setAudioClipGain(LayerId layerId, int clipIndex, double gain) {
    final layer = _layerById(layerId);
    if (layer == null ||
        layer.kind != LayerKind.se ||
        clipIndex < 0 ||
        clipIndex >= layer.audioClips.length) {
      return;
    }
    final clamped = gain < 0 ? 0.0 : gain;
    if (layer.audioClips[clipIndex].gain == clamped) {
      return;
    }
    final next = [...layer.audioClips];
    next[clipIndex] = next[clipIndex].copyWith(gain: clamped);
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: next,
      description: 'Sound gain',
    );
    notifyListeners();
  }

  /// The project's media pool, in pool order (the browser panel's list).
  List<MediaAsset> get mediaAssets => _repository.requireProject().mediaAssets;

  /// Whether any clip anywhere still references [path] (remove-guard and
  /// the browser's usage badge).
  bool isMediaAssetReferenced(String path) {
    for (final track in _repository.requireProject().tracks) {
      for (final cut in track.cuts) {
        for (final layer in cut.layers) {
          for (final clip in layer.audioClips) {
            if (clip.filePath == path) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Adds [paths] to the pool (skipping known ones) without linking them
  /// anywhere — import-to-browse, one undo step.
  void addMediaAssets(List<String> paths) {
    final pool = mediaAssets;
    final known = {for (final asset in pool) asset.path};
    final added = [
      for (final path in paths)
        if (known.add(path))
          MediaAsset(path: path, name: mediaAssetDefaultName(path)),
    ];
    if (added.isEmpty) {
      return;
    }
    _cutCommandCoordinator.updateMediaAssets([
      ...pool,
      ...added,
    ], description: 'Import media');
    notifyListeners();
  }

  /// Renames the [path] asset's display name; one undo step.
  void renameMediaAsset(String path, String name) {
    _cutCommandCoordinator.updateMediaAssets([
      for (final asset in mediaAssets)
        asset.path == path ? asset.copyWith(name: name) : asset,
    ], description: 'Rename media');
    notifyListeners();
  }

  /// Removes the [path] asset from the pool; refuses while any clip still
  /// references it (returns false). One undo step.
  bool removeMediaAsset(String path) {
    if (isMediaAssetReferenced(path)) {
      return false;
    }
    final next = mediaAssets.where((asset) => asset.path != path).toList();
    if (next.length == mediaAssets.length) {
      return false;
    }
    _cutCommandCoordinator.updateMediaAssets(next, description: 'Remove media');
    notifyListeners();
    return true;
  }

  /// Points the [oldPath] asset at [newPath] — the pool entry AND every
  /// referencing clip, one undo step (Resolve-style relink for moved
  /// files). Waveforms re-extract from the new file.
  void relinkMediaAsset(String oldPath, String newPath) {
    audioPeaksStore.invalidate(newPath);
    _cutCommandCoordinator.relinkMediaAsset(oldPath: oldPath, newPath: newPath);
    notifyListeners();
  }

  /// Links the pool asset at [path] to the SE block of [layerId] starting
  /// at [blockStartFrame] (the browser's drag-drop target hook). The block
  /// carries the sound exactly like an import at that spot; unknown pool
  /// paths register first (their own undo step, same as import).
  void linkMediaAssetToSeBlock({
    required LayerId layerId,
    required int blockStartFrame,
    required String path,
  }) {
    final layer = _layerById(layerId);
    if (layer == null || layer.kind != LayerKind.se) {
      return;
    }
    FrameId? frameId;
    for (final block in drawingBlocks(layer.timeline)) {
      if (block.startIndex == blockStartFrame) {
        frameId = block.frameId;
        break;
      }
    }
    if (frameId == null) {
      return;
    }
    final resolvedFrameId = frameId;
    // The same frame already carrying this sound is a no-op (a second link
    // would double the playback).
    if (layer.audioClips.any(
      (clip) => clip.filePath == path && clip.frameId == resolvedFrameId,
    )) {
      return;
    }
    addMediaAssets([path]);
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: _editingSession.activeCutId,
      layerId: layerId,
      audioClips: [
        ...layer.audioClips,
        AudioClip(filePath: path, frameId: resolvedFrameId),
      ],
      description: 'Link sound',
    );
    notifyListeners();
  }

  Frame? get selectedFrame {
    final layer = activeLayer;
    if (layer == null) {
      return null;
    }

    return _timelineController.getSelectedFrameForLayer(layer);
  }

  Layer? get _targetLayerForKindToggle => activeLayer;

  bool get canToggleTargetLayerKind {
    final targetLayer = _targetLayerForKindToggle;
    // Only the animation ⇄ storyboard pair; other kinds have their own
    // toggles (SE/art) or are fixed (camera/instruction).
    if (targetLayer == null ||
        targetLayer.kind != LayerKind.animation &&
            targetLayer.kind != LayerKind.storyboard) {
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

  /// SE toggle: animation ⇄ se. Any number of SE rows per cut (a sheet can
  /// carry several SE columns), but converting one away must not break the
  /// S1·S2 floor of two.
  String get activeLayerKindLabelText {
    final targetLayer = _targetLayerForKindToggle;
    return switch (targetLayer?.kind) {
      LayerKind.animation => 'Animation Layer',
      LayerKind.storyboard => 'Storyboard Layer',
      LayerKind.art => 'Art Layer',
      LayerKind.se => 'SE Layer',
      LayerKind.instruction => 'Instruction Layer',
      LayerKind.camera => 'Camera Layer',
      null => 'No Layer',
    };
  }

  /// Art toggle: animation ⇄ art (BG/BOOK cels behave like animation cels;
  /// only the material differs).
  bool get canToggleTargetLayerArt {
    final targetLayer = _targetLayerForKindToggle;
    return targetLayer != null &&
        (targetLayer.kind == LayerKind.animation ||
            targetLayer.kind == LayerKind.art);
  }

  void toggleTargetLayerArt() {
    final targetLayer = _targetLayerForKindToggle;
    if (targetLayer == null || !canToggleTargetLayerArt) {
      return;
    }

    _cutCommandCoordinator.updateLayerKind(
      cutId: _editingSession.activeCutId,
      layerId: targetLayer.id,
      kind: targetLayer.kind == LayerKind.art
          ? LayerKind.animation
          : LayerKind.art,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void toggleTargetLayerKind() {
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
    notifyListeners();
  }

  // --- Frame / cell state / commands -------------------------------------

  bool get hasActiveNonNegativeCell {
    return activeLayer != null && _timelineController.currentFrameIndex >= 0;
  }

  bool get canCreateDrawingAtCurrentFrame {
    final layer = activeLayer;
    if (layer == null || !layerKindHoldsDrawings(layer.kind)) {
      return false;
    }

    return _timelineController.canCreateDrawingAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  bool get canCopyFrameAtCurrentFrame {
    return selectedFrame != null;
  }

  bool get canPasteLinkedFrameAtCurrentFrame {
    final layer = activeLayer;
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

  String get copiedFrameStatusText {
    final copiedFrame = _copiedFrame;
    if (copiedFrame == null) {
      return 'Copy: -';
    }

    final label = copiedFrame.frameName?.isNotEmpty == true
        ? copiedFrame.frameName!
        : copiedFrame.frameId.value;
    return 'Copy: $label';
  }

  String get linkedFrameUsesStatusText {
    final layer = activeLayer;
    final frame = selectedFrame;
    if (layer == null || frame == null) {
      return 'Links: -';
    }

    final uses = _timelineController.linkedUseCountForLayerFrame(
      layer: layer,
      frameId: frame.id,
    );
    return 'Links: $uses';
  }

  /// The timesheet "X here" action: cuts the covering block's hold so the
  /// current cell (and the rest of the old hold) becomes empty.
  bool get canCutExposureAtCurrentFrame {
    final layer = activeLayer;
    if (layer == null || !layerKindHoldsDrawings(layer.kind)) {
      return false;
    }

    return _timelineController.canCutExposureAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  void createDrawingAtCurrentFrame() {
    final layer = activeLayer;
    if (layer == null || !canCreateDrawingAtCurrentFrame) {
      return;
    }

    _frameSequence += 1;
    _timelineController.createDrawingFrameForLayer(
      layerId: layer.id,
      frameId: FrameId(_nextFrameId(layer.id)),
    );
    notifyListeners();
  }

  void copyFrameAtCurrentFrame() {
    final layer = activeLayer;
    final frame = selectedFrame;
    if (layer == null || frame == null || !canCopyFrameAtCurrentFrame) {
      return;
    }

    _copiedFrame = _CopiedFrameReference(
      layerId: layer.id,
      frameId: frame.id,
      frameName: frame.name,
    );
    notifyListeners();
  }

  void pasteLinkedFrameAtCurrentFrame() {
    final layer = activeLayer;
    final copiedFrame = _copiedFrame;
    if (layer == null ||
        copiedFrame == null ||
        !canPasteLinkedFrameAtCurrentFrame) {
      return;
    }

    _timelineController.pasteLinkedFrameForLayer(
      layerId: layer.id,
      frameId: copiedFrame.frameId,
    );
    notifyListeners();
  }

  void cutExposureAtCurrentFrame() {
    final layer = activeLayer;
    if (layer == null || !canCutExposureAtCurrentFrame) {
      return;
    }

    _timelineController.cutExposureForLayer(layerId: layer.id);
    notifyListeners();
  }

  String _nextFrameId(LayerId layerId) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'ui-frame-${layerId.value}-$timestamp-$_frameSequence';
  }

  /// The toolbar +/- buttons are one-frame comma adjustments of the
  /// selected block's end edge (the same op the drag grips use).
  void increaseSelectedExposure() => _shiftSelectedExposureEnd(1);

  void decreaseSelectedExposure() => _shiftSelectedExposureEnd(-1);

  void _shiftSelectedExposureEnd(int delta) {
    final layer = activeLayer;
    if (layer == null) {
      return;
    }
    final block = _timelineController.blockForLayerAt(layer: layer);
    if (block == null) {
      return;
    }

    _timelineController.shiftExposureEdge(
      layerId: layer.id,
      blockStartIndex: block.startIndex,
      edge: TimelineBlockEdge.end,
      delta: delta,
    );
    notifyListeners();
  }

  // --- Comma edge drag ------------------------------------------------------
  //
  // A drag previews live by recomputing the shifted layer from the drag-start
  // snapshot with the CUMULATIVE frame delta (idempotent — no per-step
  // accounting) and writing it straight to the repository; releasing commits
  // the before→after pair as ONE undoable command.

  Layer? _edgeDragBefore;
  TimelineBlockEdge? _edgeDragEdge;
  int? _edgeDragBlockStart;

  bool get isExposureEdgeDragActive => _edgeDragBefore != null;

  /// Starts a comma drag on [edge] of the block starting at
  /// [blockStartIndex]; returns false when there is no such block.
  /// Instruction rows join the same pipeline — their spans live on
  /// Layer.instructions and shift without ripple.
  bool beginExposureEdgeDrag({
    required LayerId layerId,
    required int blockStartIndex,
    required TimelineBlockEdge edge,
  }) {
    final layer = _layerById(layerId);
    if (layer == null) {
      return false;
    }
    final isInstructionSpan =
        layer.kind == LayerKind.instruction &&
        layer.instructions.containsKey(blockStartIndex);
    final isDrawingBlock =
        layerKindHoldsDrawings(layer.kind) &&
        (layer.timeline[blockStartIndex]?.isDrawing ?? false);
    if (!isInstructionSpan && !isDrawingBlock) {
      return false;
    }

    _edgeDragBefore = layer;
    _edgeDragEdge = edge;
    _edgeDragBlockStart = blockStartIndex;
    return true;
  }

  Layer _edgeDraggedLayer({
    required Layer before,
    required int blockStart,
    required TimelineBlockEdge edge,
    required int delta,
  }) {
    if (before.kind == LayerKind.instruction) {
      final shifted = instructionMapWithEdgeShifted(
        before.instructions,
        spanStartIndex: blockStart,
        startEdge: edge == TimelineBlockEdge.start,
        delta: delta,
      );
      return shifted == null ? before : before.copyWith(instructions: shifted);
    }
    return _timelineController.shiftedLayerForEdge(
          layer: before,
          blockStartIndex: blockStart,
          edge: edge,
          delta: delta,
        ) ??
        before;
  }

  /// Applies the drag's current cumulative frame delta as a live preview.
  void updateExposureEdgeDrag(int cumulativeDelta) {
    final before = _edgeDragBefore;
    final edge = _edgeDragEdge;
    final blockStart = _edgeDragBlockStart;
    if (before == null || edge == null || blockStart == null) {
      return;
    }

    final after = _edgeDraggedLayer(
      before: before,
      blockStart: blockStart,
      edge: edge,
      delta: cumulativeDelta,
    );
    final current = _layerById(before.id);
    if (current == null || current == after) {
      return;
    }

    // No notifyEditActivity here: composites self-validate against the
    // preview edits, the drag-end warm request re-renders what changed, and
    // the idle gate's REAL-time delay would leave timers pending under the
    // fake test clock.
    _repository.replaceLayer(layer: after);
    notifyListeners();
  }

  /// Commits the drag as a single undo step (no-op when nothing changed).
  void endExposureEdgeDrag() {
    final before = _edgeDragBefore;
    _edgeDragBefore = null;
    _edgeDragEdge = null;
    _edgeDragBlockStart = null;
    if (before == null) {
      return;
    }

    final current = _layerById(before.id);
    if (current == null || current == before) {
      return;
    }
    _timelineController.commitLayerTimelineDrag(before: before, after: current);
    _warmActiveCut();
    notifyListeners();
  }

  // --- Storyboard cut-trim edge drags --------------------------------------

  Map<CutId, int>? _cutTrimBeforeDurations;
  CutId? _cutTrimCutId;
  CutId? _cutTrimPreviousCutId;
  TimelineBlockEdge? _cutTrimEdge;

  /// Starts a storyboard trim drag on [cutId]'s [edge]. The first cut's
  /// start is fixed at frame 0, so a start-edge drag needs a previous cut
  /// in the same track (its roll partner).
  bool beginCutEdgeDrag({
    required CutId cutId,
    required TimelineBlockEdge edge,
  }) {
    final layout = buildStoryboardTimelineLayout(_repository.requireProject());
    StoryboardTimelineLayoutEntry? entry;
    for (final candidate in layout) {
      if (candidate.cutId == cutId) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) {
      return false;
    }
    StoryboardTimelineLayoutEntry? previous;
    if (edge == TimelineBlockEdge.start) {
      for (final candidate in layout) {
        if (candidate.trackId == entry.trackId &&
            candidate.cutIndex == entry.cutIndex - 1) {
          previous = candidate;
          break;
        }
      }
      if (previous == null) {
        return false;
      }
    }

    _cutTrimBeforeDurations = {
      entry.cutId: entry.cut.duration,
      if (previous != null) previous.cutId: previous.cut.duration,
    };
    _cutTrimCutId = cutId;
    _cutTrimPreviousCutId = previous?.cutId;
    _cutTrimEdge = edge;
    return true;
  }

  /// Applies the trim drag's cumulative frame delta as a live preview: the
  /// END edge changes this cut's own duration (later cuts ripple through
  /// the cumulative layout), the START edge rolls the boundary with the
  /// previous cut. Both cuts stay at least one frame long.
  void updateCutEdgeDrag(int cumulativeDelta) {
    final before = _cutTrimBeforeDurations;
    final cutId = _cutTrimCutId;
    final edge = _cutTrimEdge;
    if (before == null || cutId == null || edge == null) {
      return;
    }

    final Map<CutId, int> target;
    if (edge == TimelineBlockEdge.end) {
      target = {cutId: math.max(1, before[cutId]! + cumulativeDelta)};
    } else {
      final previousCutId = _cutTrimPreviousCutId!;
      final delta = cumulativeDelta.clamp(
        1 - before[previousCutId]!,
        before[cutId]! - 1,
      );
      target = {
        previousCutId: before[previousCutId]! + delta,
        cutId: before[cutId]! - delta,
      };
    }

    var changed = false;
    for (final entry in target.entries) {
      if (cutById(entry.key)?.duration != entry.value) {
        _repository.updateCutDuration(cutId: entry.key, duration: entry.value);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Commits the trim drag as a single undo step (no-op when nothing
  /// changed).
  void endCutEdgeDrag() {
    final before = _cutTrimBeforeDurations;
    _cutTrimBeforeDurations = null;
    _cutTrimCutId = null;
    _cutTrimPreviousCutId = null;
    _cutTrimEdge = null;
    if (before == null) {
      return;
    }

    final after = {
      for (final id in before.keys) id: cutById(id)?.duration ?? before[id]!,
    };
    var changed = false;
    for (final id in before.keys) {
      if (after[id] != before[id]) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return;
    }
    _cutCommandCoordinator.commitCutDurationDrag(before: before, after: after);
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Reverts an in-flight trim preview without touching history.
  void cancelCutEdgeDrag() {
    final before = _cutTrimBeforeDurations;
    _cutTrimBeforeDurations = null;
    _cutTrimCutId = null;
    _cutTrimPreviousCutId = null;
    _cutTrimEdge = null;
    if (before == null) {
      return;
    }

    var changed = false;
    for (final entry in before.entries) {
      if (cutById(entry.key)?.duration != entry.value) {
        _repository.updateCutDuration(cutId: entry.key, duration: entry.value);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Reverts an in-flight drag preview without touching history.
  void cancelExposureEdgeDrag() {
    final before = _edgeDragBefore;
    _edgeDragBefore = null;
    _edgeDragEdge = null;
    _edgeDragBlockStart = null;
    if (before == null) {
      return;
    }

    final current = _layerById(before.id);
    if (current != null && current != before) {
      _repository.replaceLayer(layer: before);
    }
    notifyListeners();
  }

  Layer? _layerById(LayerId layerId) {
    for (final layer in layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }
    return null;
  }

  bool get canToggleMarkAtCurrentFrame {
    final layer = activeLayer;
    if (layer == null || !layerKindHoldsDrawings(layer.kind)) {
      return false;
    }

    return _timelineController.canToggleMarkAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  void toggleMarkAtCurrentFrame() {
    final layer = activeLayer;
    if (layer == null || !canToggleMarkAtCurrentFrame) {
      return;
    }

    _timelineController.toggleMarkForLayer(layerId: layer.id);
    notifyListeners();
  }

  bool get canRenameFrameAtCurrentFrame {
    final layer = activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canRenameFrameAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  bool get canDeleteCellAtCurrentFrame {
    final layer = activeLayer;
    if (layer == null) {
      return false;
    }

    return _timelineController.canDeleteCellAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  String? get selectedFrameName => selectedFrame?.name;

  /// SE rows: the selected entry's speaker/effect name (the accent box).
  String? get selectedFrameSeName => selectedFrame?.seName;

  /// Applies a rename to the currently selected frame.
  ///
  /// Returns `null` when the rename was applied (or was not possible). When the
  /// new [name] collides with another frame, returns that frame's id without
  /// mutating so the caller can offer to link instead (see [linkSelectedFrame]).
  /// SE rows are exempt from the collision rule — the same dialogue can
  /// legitimately repeat on a sheet, so duplicates just apply.
  FrameId? renameSelectedFrame(String name) {
    final layer = activeLayer;
    final frame = selectedFrame;
    if (layer == null || frame == null || !canRenameFrameAtCurrentFrame) {
      return null;
    }

    final allowDuplicateName = layer.kind == LayerKind.se;
    if (!allowDuplicateName) {
      final conflictingFrameId = _timelineController
          .conflictingFrameIdForRename(
            layer: layer,
            frameId: frame.id,
            name: name,
          );
      if (conflictingFrameId != null) {
        return conflictingFrameId;
      }
    }

    _timelineController.renameFrameForLayer(
      layerId: layer.id,
      frameId: frame.id,
      name: name,
      allowDuplicateName: allowDuplicateName,
    );
    notifyListeners();
    return null;
  }

  /// Creates an SE entry at the current cell carrying [name] (the sheet's
  /// dialogue text) and the optional [seName] (speaker/effect, the accent
  /// box) in ONE undo step. The entry takes [lengthFrames] (the dialog's
  /// length input), clamped into the room to the next entry / cut end;
  /// null falls back to filling that room (legacy behavior).
  void createSeEntryAtCurrentFrame({
    required String name,
    String? seName,
    int? lengthFrames,
  }) {
    final layer = activeLayer;
    if (layer == null ||
        layer.kind != LayerKind.se ||
        !canCreateDrawingAtCurrentFrame) {
      return;
    }

    final remaining =
        activeCut.duration - _timelineController.currentFrameIndex;
    final available = remaining < 1 ? 1 : remaining;
    _frameSequence += 1;
    _timelineController.createDrawingFrameForLayer(
      layerId: layer.id,
      frameId: FrameId(_nextFrameId(layer.id)),
      length: (lengthFrames ?? available).clamp(1, available),
      name: name,
      seName: seName,
    );
    notifyListeners();
  }

  /// SE rows: updates the selected entry's dialogue (Frame.name) and
  /// speaker name in ONE undo step. Duplicates are allowed — the same
  /// dialogue can legitimately repeat on a sheet.
  void updateSelectedSeEntry({required String dialogue, String? seName}) {
    final layer = activeLayer;
    final frame = selectedFrame;
    if (layer == null ||
        frame == null ||
        layer.kind != LayerKind.se ||
        !canRenameFrameAtCurrentFrame) {
      return;
    }

    _timelineController.renameFrameForLayer(
      layerId: layer.id,
      frameId: frame.id,
      name: dialogue,
      allowDuplicateName: true,
      seName: seName,
      updateSeName: true,
    );
    notifyListeners();
  }

  void linkSelectedFrame(FrameId targetFrameId) {
    final layer = activeLayer;
    final frame = selectedFrame;
    if (layer == null || frame == null) {
      return;
    }

    _timelineController.linkFrameForLayer(
      layerId: layer.id,
      sourceFrameId: frame.id,
      targetFrameId: targetFrameId,
    );
    notifyListeners();
  }

  void deleteCellAtCurrentFrame() {
    final layer = activeLayer;
    if (layer == null || !canDeleteCellAtCurrentFrame) {
      return;
    }

    _timelineController.deleteCellForLayer(layerId: layer.id);
    notifyListeners();
  }

  int get currentFrameIndex => _timelineController.currentFrameIndex;

  /// A seek is NOT a session notify: the playhead move rebuilds nothing by
  /// itself. Cursor-driven widgets follow [editingFrameCursor]; the few
  /// seek-dependent surfaces (editing canvas, timeline toolbar enablement,
  /// camera pose panel, timesheet playhead) subscribe to
  /// [frameSeekCommitted] and rebuild once per committed seek.
  void selectFrameIndex(int frameIndex) {
    _timelineController.selectFrameIndex(frameIndex);
    editingFrameCursor.value = frameIndex;
    _warmActiveCut();
    frameSeekCommitted.value += 1;
  }

  // --- Editing frame scrub (ruler drags ride the cursor path) --------------

  /// The editing playhead as a VALUE stream: every seek — scrub moves
  /// included — lands here, so cursor-driven widgets (timeline cursor
  /// layer, frame counter, the canvas scrub preview) follow pointer-fast
  /// without a session notify rebuilding the tree.
  final ValueNotifier<int> editingFrameCursor = ValueNotifier<int>(0);

  /// Bumped once per committed seek ([selectFrameIndex]) — a serial, not a
  /// frame (a same-frame commit must still fire after a scrub returned to
  /// its start). Seek-dependent panels subscribe here instead of the full
  /// session notify.
  final ValueNotifier<int> frameSeekCommitted = ValueNotifier<int>(0);

  /// True while a ruler scrub is in flight — the canvas swaps to the
  /// composite-cache preview (the playback display machinery) until the
  /// release commit.
  final ValueNotifier<bool> frameScrubActive = ValueNotifier<bool>(false);

  /// A scrub move: repositions the playhead WITHOUT notifying — only the
  /// cursor listenables fire; the full session notify is deferred to
  /// [commitFrameScrub] on release. The canvas preview engages on the
  /// first move that actually changes the frame, so a same-frame tap
  /// never flashes it.
  void scrubFrameIndex(int frameIndex) {
    if (frameIndex != _timelineController.currentFrameIndex) {
      _timelineController.selectFrameIndex(frameIndex);
      editingFrameCursor.value = frameIndex;
      if (!frameScrubActive.value) {
        frameScrubActive.value = true;
        // One warm per gesture: the preview reads the composite cache, so
        // a cold cut starts filling immediately (per-move warms would only
        // thrash the scheduler's ordering).
        _warmActiveCut();
      }
    } else {
      editingFrameCursor.value = frameIndex;
    }
  }

  /// The scrub gesture's release: ends the preview and commits the
  /// scrubbed playhead as ONE ordinary seek (warm + committed-seek signal).
  void commitFrameScrub() {
    if (frameScrubActive.value) {
      frameScrubActive.value = false;
    }
    selectFrameIndex(_timelineController.currentFrameIndex);
  }

  bool hasMarkForLayer(Layer layer, int frameIndex) {
    if (!layerKindHoldsDrawings(layer.kind)) {
      return false;
    }
    return _timelineController.hasMarkAt(layer: layer, frameIndex: frameIndex);
  }

  /// Camera rows summarize their property lanes Blender-dopesheet style:
  /// the union of lane keys per frame, ■ when every keyed lane holds there
  /// and ◆ otherwise. The glyph rides the frame-name channel — the cell
  /// renders it marker-styled (no paper block).
  String? frameNameForLayer(Layer layer, int frameIndex) {
    if (layer.kind == LayerKind.camera) {
      final track = activeCut.camera.track;
      final interpolations = [
        track.anchorPoint.keyAt(frameIndex)?.interpolation,
        track.position.keyAt(frameIndex)?.interpolation,
        track.scale.keyAt(frameIndex)?.interpolation,
        track.rotation.keyAt(frameIndex)?.interpolation,
        track.opacity.keyAt(frameIndex)?.interpolation,
      ].whereType<PropertyKeyInterpolation>().toList();
      if (interpolations.isEmpty) {
        return null;
      }
      return interpolations.every(
            (interpolation) => interpolation == PropertyKeyInterpolation.hold,
          )
          ? '■'
          : '◆';
    }
    return _timelineController
        .resolveFrameForLayer(layer: layer, frameIndex: frameIndex)
        ?.name;
  }

  TimelineCellExposureState exposureStateForLayer(Layer layer, int frameIndex) {
    if (layer.kind == LayerKind.camera) {
      // The camera row's cells mirror the cut's camera keyframes.
      return activeCut.camera.keyframeAt(frameIndex) != null
          ? TimelineCellExposureState.drawingStart
          : TimelineCellExposureState.uncovered;
    }

    if (_timelineController.isDrawingStartForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.drawingStart;
    }

    final hasMark = _timelineController.hasMarkAt(
      layer: layer,
      frameIndex: frameIndex,
    );
    final held = _timelineController.isHeldExposureForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    if (hasMark) {
      return held
          ? TimelineCellExposureState.markHeld
          : TimelineCellExposureState.markUncovered;
    }
    return held
        ? TimelineCellExposureState.held
        : TimelineCellExposureState.uncovered;
  }

  int? get selectedEffectiveDuration {
    final layer = activeLayer;
    if (layer == null || selectedFrame == null) {
      return null;
    }
    return _timelineController.effectiveDurationForLayerAt(layer: layer);
  }

  bool get canDecreaseSelectedExposure {
    final layer = activeLayer;
    if (layer == null) {
      return false;
    }
    final block = _timelineController.blockForLayerAt(layer: layer);
    return block != null && block.length > 1;
  }

  bool get canIncreaseSelectedExposure {
    final layer = activeLayer;
    if (layer == null) {
      return false;
    }
    return _timelineController.blockForLayerAt(layer: layer) != null;
  }

  // --- Status text --------------------------------------------------------

  String get currentLayerStatusText {
    final layer = activeLayer;
    return 'Layer: ${layer?.name ?? 'None'}';
  }

  String get currentFrameStatusText {
    return 'Frame: ${_timelineController.currentFrameIndex + 1}';
  }

  String get currentCellStatusText {
    final layer = activeLayer;
    if (layer == null) {
      return 'Cell: No layer';
    }

    return 'Cell: ${_cellStatusLabelForLayer(layer)}';
  }

  String get compactCellActionText {
    final layer = activeLayer;
    if (layer == null) {
      return 'No layer';
    }

    final frameIndex = _timelineController.currentFrameIndex;
    final exposureState = exposureStateForLayer(layer, frameIndex);
    final canPaste = canPasteLinkedFrameAtCurrentFrame;

    switch (exposureState) {
      case TimelineCellExposureState.drawingStart:
        return 'Drawing: Copy / Rename / Delete';
      case TimelineCellExposureState.held:
        return canPaste
            ? 'Held: Paste / Copy / Rename / Mark'
            : 'Held: Copy / Rename / Mark';
      case TimelineCellExposureState.markHeld:
        return canPaste
            ? 'Held + ●: Paste / Copy / Rename / Mark'
            : 'Held + ●: Copy / Rename / Mark';
      case TimelineCellExposureState.uncovered:
        return canPaste ? 'X: Paste / New Frame / Mark' : 'X: New Frame / Mark';
      case TimelineCellExposureState.markUncovered:
        return canPaste
            ? 'X + ●: Paste / New Frame / Mark'
            : 'X + ●: New Frame / Mark';
    }
  }

  String _cellStatusLabelForLayer(Layer layer) {
    final frameIndex = _timelineController.currentFrameIndex;
    final exposureState = exposureStateForLayer(layer, frameIndex);
    return switch (exposureState) {
      TimelineCellExposureState.drawingStart => _drawingStartStatusForLayer(
        layer,
        frameIndex,
      ),
      TimelineCellExposureState.held => 'Held drawing',
      TimelineCellExposureState.markHeld => 'Held drawing + Mark ●',
      TimelineCellExposureState.uncovered => 'Empty (X)',
      TimelineCellExposureState.markUncovered => 'Empty (X) + Mark ●',
    };
  }

  String _drawingStartStatusForLayer(Layer layer, int frameIndex) {
    final frameName = frameNameForLayer(layer, frameIndex);
    if (frameName == null || frameName.isEmpty) {
      return 'Drawing start';
    }

    return 'Drawing start: $frameName';
  }

  // --- Canvas selection labels -------------------------------------------

  CanvasEditorSelectionLabels get canvasSelectionLabels {
    final project = _repository.requireProject();
    final cut = activeCut;
    final layer = _layerController.activeLayer;
    final frame = selectedFrame;
    return CanvasEditorSelectionLabels(
      projectLabel: project.name,
      cutLabel: cut.name,
      layerLabel: layer?.name ?? '-',
      frameLabel: _currentFrameDisplayLabel(layer, frame),
    );
  }

  String _currentFrameDisplayLabel(Layer? layer, Frame? frame) {
    if (layer == null) {
      return '-';
    }
    final frameIndex = _timelineController.currentFrameIndex;
    final frameName = frame?.name;
    final exposureState = exposureStateForLayer(layer, frameIndex);
    return switch (exposureState) {
      TimelineCellExposureState.drawingStart =>
        frameName == null || frameName.isEmpty ? '○' : frameName,
      TimelineCellExposureState.held =>
        frameName == null || frameName.isEmpty ? '' : frameName,
      TimelineCellExposureState.markHeld =>
        frameName == null || frameName.isEmpty ? '●' : '$frameName ●',
      TimelineCellExposureState.uncovered => 'X',
      TimelineCellExposureState.markUncovered => '●',
    };
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
