import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../controllers/default_layer_helpers.dart';
import '../controllers/editing_session_state.dart';
import '../controllers/layer_controller.dart';
import '../controllers/timeline_controller.dart';
import '../models/attached_layer_resolve.dart';
import '../models/attached_placement.dart';
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
import '../models/onion_skin_settings.dart';
import '../models/timesheet_document.dart' show timesheetMemoInstructionLine;
import '../models/project_background.dart';
import '../models/timesheet_info.dart';
import '../models/project.dart';
import '../models/property_track.dart';
import '../models/timeline_coverage.dart';
import '../models/timeline_frame_range.dart';
import '../models/timeline_repeat.dart';
import '../models/timeline_run_edit.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import '../models/track_se_window.dart';
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
import 'dev_profile.dart';
import 'playback/audio_playback_sync.dart';
import 'playback/audioplayers_clip_player.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/cut_frame_composite_cache.dart';
import 'playback/layer_frame_image_cache.dart';
import 'playback/playback_cache_budget.dart';
import 'playback/playback_prerender_scheduler.dart';
import 'storyboard_cut_fade_policy.dart';
import '../models/track_frame_axis.dart';
import 'storyboard_timeline_layout.dart';
import '../models/drawing_block_move.dart';
import '../services/command.dart';
import '../services/commands/attached_cel_command.dart';
import '../services/commands/cut_command_coordinator.dart';
import '../services/commands/rekey_brush_frames_command.dart';
import '../services/commands/update_layer_fill_reference_command.dart';
import '../services/commands/update_layer_mark_command.dart';
import '../services/commands/update_layer_timeline_command.dart';
import '../services/commands/update_layer_timesheet_command.dart';
import '../services/onion_skin_plan.dart';
import '../services/persistence/project_autosave_service.dart';
import '../services/persistence/qap_file_service.dart';
import '../services/commands/cut_reorder_planner.dart';
import '../services/commands/track_se_layer_commands.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';
import 'audio/audio_peaks_store.dart';
import 'brush/brush_canvas_panel.dart';
import 'brush/brush_editor_selection.dart';
import 'timeline/instruction_span_editing.dart';
import 'timeline/layer_timeline_display_adapter.dart'
    show horizontalLayerDisplayOrder;
import 'timeline/timeline_cell_exposure_state.dart';
import 'timeline/timeline_drag_preview.dart';
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
    // Dirty tracking (P3): every history change — commands, undo/redo and
    // brush strokes, which execute here straight from the canvas — marks
    // the project unsaved.
    _historyManager.addListener(_markProjectDirty);
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
        // Widget tests: zero idle delay, like before R13-3 — the
        // quiet-window polls otherwise leave a pending gate timer at
        // teardown (the session's tearDown dispose runs AFTER the
        // binding's timer invariant). The debounce/hold semantics have
        // their own scheduler unit tests with injected delays.
        //
        // Production: 1200ms (R13-4) — during an active work session the
        // warmer resumes only in REAL pauses; per-tile abort granularity
        // covers whatever still collides at the resume boundary.
        idleDelay: Platform.environment['FLUTTER_TEST'] == 'true'
            ? Duration.zero
            : const Duration(milliseconds: 1200),
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
    onStoppedInGap: _onPlaybackStoppedInGap,
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
    // Track-owned SE rows schedule from the tracks' global axes.
    resolveProject: () => _repository.currentProject,
  );

  void _onPlaybackStopped(PlaybackPosition lastPosition) {
    if (lastPosition.cutId != _editingSession.activeCutId) {
      selectCut(lastPosition.cutId);
    }
    selectFrameIndex(_clampedFrameIndex(lastPosition.localFrameIndex));
    // The mid-playback cut follow is QUIET (R12-B) — this is the one
    // session notify that catches every activeCut consumer up with where
    // playback landed.
    notifyListeners();
  }

  /// Stop landed on a playlist GAP frame (UI-R9 #3): match the editing
  /// gap semantics — park there with NO active cut.
  void _onPlaybackStoppedInGap(int globalFrame) {
    _gapGlobalFrame = globalFrame;
    _deselectActiveCutForGap();
    frameSeekCommitted.value += 1;
    notifyListeners();
  }

  /// Premiere-style follow: while playback crosses cut boundaries the
  /// ACTIVE cut tracks the playing cut and stays there when playback
  /// stops. Playback-only selection state — no command runs, the undo
  /// stack never sees it. QUIET by design (R12-B): no session notify and
  /// no warming — a boundary tick must not rebuild the visible panels
  /// mid-playback (that stutter was audible as the cut-transition lag).
  /// Live position display rides the playback listenables; activeCut
  /// consumers catch up on the stop notify.
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

  /// NULL = the editing playhead stands in a GAP (UI-R9 #3): no cut is
  /// selected. Cut-scoped surfaces show their empty states; cut-scoped
  /// commands stand down.
  CutId? get activeCutId => _editingSession.activeCutId;

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
      trackSeDisplayLayers: () => trackSeDisplayLayers,
    );
    _timelineController = TimelineController(
      repository: _repository,
      historyManager: _historyManager,
      cutId: activeCutId,
      initialFrameIndex: _clampedFrameIndex(preferredFrameIndex),
      // Track-SE mutations shift to the global axis inside the controller;
      // reads keep flowing through the cut-local display clones.
      frameOffsetForLayer: (layerId) =>
          isTrackSeLayerId(layerId) ? activeCutGlobalStartFrame : 0,
      trackSeLayers: () => activeTrack.seLayers,
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

  // --- Track-owned SE rows --------------------------------------------------
  //
  // SE rows live on the TRACK (global frame axis — sounds may cross cut
  // boundaries). Reads go through cut-local DISPLAY clones composed into
  // [layers]; mutations detect track-SE ids, convert local→global through
  // the window, and edit the track's GLOBAL layer (the clones are never
  // written back).

  Track get activeTrack {
    final trackId = activeCutTrackId;
    return _repository.requireProject().tracks.firstWhere(
      (track) => track.id == trackId,
    );
  }

  /// The active cut's global start frame on its track (cumulative cut
  /// durations — the storyboard layout's number for this cut).
  int get activeCutGlobalStartFrame {
    final activeCutId = _editingSession.activeCutId;
    var start = 0;
    for (final cut in activeTrack.cuts) {
      start += cut.leadingGapFrames;
      if (cut.id == activeCutId) {
        return start;
      }
      start += cut.duration;
    }
    return 0;
  }

  TrackSeWindow get trackSeWindow => TrackSeWindow(
    cutStartFrame: activeCutGlobalStartFrame,
    cutDurationFrames: activeCutOrNull?.duration ?? 0,
  );

  bool isTrackSeLayerId(LayerId layerId) =>
      activeTrack.seLayers.any((layer) => layer.id == layerId);

  /// The GLOBAL track layer for [layerId] (never a display clone).
  Layer? trackSeGlobalLayerById(LayerId layerId) {
    for (final layer in activeTrack.seLayers) {
      if (layer.id == layerId) {
        return layer;
      }
    }
    return null;
  }

  /// The track's SE rows as cut-local display clones for the active cut.
  List<Layer> get trackSeDisplayLayers {
    final window = trackSeWindow;
    return [
      for (final layer in activeTrack.seLayers) window.displayLayer(layer),
    ];
  }

  /// The track SE rows whose display clone starts with a spill-in block —
  /// a sound carrying over from an earlier cut (UI-R7 #6: the timeline
  /// draws the `~` continuation at the cut start and drops the start
  /// grip; the block's real start lives in that earlier cut).
  Set<LayerId> get trackSeSpillInLayerIds {
    final window = trackSeWindow;
    return {
      for (final layer in activeTrack.seLayers)
        if (window.spillInBlock(layer) != null) layer.id,
    };
  }

  void _refreshAfterCutCommand({
    LayerId? preferredActiveLayerId,
    int? preferredFrameIndex,
  }) {
    _copiedFrame = null;
    clearFrameRangeSelection();
    _rebuildActiveCutControllers(
      preferredActiveLayerId: preferredActiveLayerId,
      preferredFrameIndex:
          preferredFrameIndex ?? _timelineController.currentFrameIndex,
    );
    // Layer add/delete/undo may have moved the active row: keep the solo
    // mode following it (or exit if the command switched cuts).
    _syncVisibilitySolo();
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
    final cut = activeCutOrNull;
    if (cut == null) {
      return;
    }
    prerenderScheduler.requestWarmCut(
      cutId: cut.id,
      quality: playbackQuality,
      aroundFrameIndex: _timelineController.currentFrameIndex,
    );
  }

  @override
  void dispose() {
    cacheInvalidationHub.removeBrushFrameListener(_onBrushFrameInvalidated);
    playback.globalFrameIndexListenable.removeListener(_followPlaybackCut);
    _historyManager.removeListener(_markProjectDirty);
    audioPlaybackSync.dispose();
    playback.dispose();
    prerenderScheduler.dispose();
    cutFrameCompositeCache.dispose();
    layerFrameImageCache.dispose();
    audioPeaksStore.dispose();
    editingFrameCursor.dispose();
    frameScrubActive.dispose();
    frameSeekCommitted.dispose();
    _gapGlobalFrameNotifier.dispose();
    frameRangeSelection.dispose();
    brushInputActive.dispose();
    selectionInteractionActive.dispose();
    dragPreview.dispose();
    opacityDragPreview.dispose();
    onionSkinSettings.dispose();
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
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.resizeCutCanvas(
      cutId: cutId,
      canvasSize: canvasSize,
      anchor: anchor,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void duplicateActiveCut() {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.duplicateCut(
      sourceCutId: cutId,
      targetTrackId: activeCutTrackId,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void deleteActiveCut() {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.deleteCut(cutId: cutId);
    _refreshAfterCutCommand();
    notifyListeners();
  }

  CutPosition? get _activeCutPositionOrNull {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return null;
    }
    return _cutReorderPlanner.findCutPosition(
      project: _repository.requireProject(),
      cutId: cutId,
    );
  }

  CutPosition get _activeCutPosition {
    final position = _activeCutPositionOrNull;
    if (position == null) {
      throw StateError('Active Cut not found: ${_editingSession.activeCutId}');
    }
    return position;
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
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.updateCutNote(cutId: cutId, note: note);
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
    final cut = activeCutOrNull;
    if (cut == null) {
      return;
    }
    final frame = _timelineController.currentFrameIndex;
    final pinned = cut.metadata.thumbnailFrameIndex;
    _cutCommandCoordinator.updateCutThumbnailFrame(
      cutId: cut.id,
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

  int get activeCutPlaybackFrameCount =>
      math.max(1, activeCutOrNull?.duration ?? 1);

  /// The active cut, THROWING when none is selected (gap state) — every
  /// caller is a conscious decision that a cut must exist here (UI-R9 #3
  /// audit rename; reach for [activeCutOrNull] on read paths instead).
  Cut get requireActiveCut {
    final cut = activeCutOrNull;
    if (cut == null) {
      throw StateError(
        'No active Cut (gap state): ${_editingSession.activeCutId}',
      );
    }
    return cut;
  }

  void renameActiveCut(String newName) {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.renameCut(cutId: cutId, newName: newName);
    _refreshAfterCutCommand();
    notifyListeners();
  }

  // --- Camera --------------------------------------------------------------

  CutCamera get activeCutCamera => requireActiveCut.camera;

  /// The camera's output frame size (the exported picture size); the camera
  /// view rect on canvas is this divided by the pose zoom.
  CanvasSize get cameraFrameSize => _repository.requireProject().cameraSize;

  int get projectFps => _repository.requireProject().fps;

  /// Resolved camera pose at an arbitrary playback frame (for rendering).
  CameraPose cameraPoseAtFrame(int frameIndex) => resolveCameraPoseAt(
    camera: requireActiveCut.camera,
    canvasSize: requireActiveCut.canvasSize,
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
    // Opacity drag preview (R4 #4/#6, DISPLAY only): the dragged rows'
    // static opacity substitutes in before the shared visit, so the canvas
    // follows the drag without any repo write per move.
    final preview = opacityDragPreview.value;
    List<Layer> withOpacityPreview(List<Layer> source) => preview == null
        ? source
        : [
            for (final layer in source)
              preview.layerIds.contains(layer.id) &&
                      layer.kind != LayerKind.camera
                  ? layer.copyWith(opacity: preview.opacity)
                  : layer,
          ];
    final stackCut = preview == null
        ? cut
        : cut.copyWith(layers: withOpacityPreview(cut.layers));
    // The CUT layers ride the shared composite visit (skip rules, fx
    // sharing and the W5 attach-layer expansion agree with playback by
    // construction); the split around the active layer happens here.
    final entryByLayerId = {
      for (final entry in resolveCutFrameCompositeEntries(
        cut: stackCut,
        frameIndex: frameIndex,
        fxBypassedLayerIds: fxBypassedLayerIds,
      ))
        entry.layer.id: entry,
    };
    for (final layer in stackCut.layers) {
      // A brush-banned active layer (SE/instruction, R6-④) has no
      // interactive surface — it composites like any other stack layer so
      // its existing cels keep displaying read-only.
      if (layer.id == activeLayerId && layerKindAcceptsBrushInput(layer.kind)) {
        seenActiveLayer = true;
        activeLayerOpacity = !layer.isVisible
            ? 0.0
            : _stackLayerOpacity(layer, stackCut.layers, frameIndex);
        continue;
      }
      final entry = entryByLayerId[layer.id];
      if (entry == null) {
        continue;
      }
      (seenActiveLayer ? above : below).add(
        CanvasLayerImageRequest(
          frameKey: brushFrameKeyForCut(cut, entry.layer.id, entry.frame.id),
          opacity: entry.opacity,
          pose: entry.pose,
          anchorPoint: entry.anchorPoint,
        ),
      );
    }
    // Track-owned SE rows join as their cut-local display clones — they
    // composite read-only like before the ownership move (their transform
    // tracks are stripped, so the plain resolve path suffices).
    for (final layer in withOpacityPreview(trackSeDisplayLayers)) {
      final fxEnabled = isLayerFxEnabled(layer.id);
      if (!layer.isVisible || layer.opacity <= 0) {
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
          pose: null,
          anchorPoint: null,
        ),
      );
    }
    return (below: below, above: above, activeLayerOpacity: activeLayerOpacity);
  }

  /// The display opacity the editing stack (and the interactive view's
  /// dimming) uses for [layer]: the shared composite semantics — an attach
  /// layer multiplies its own static opacity with its BASE's animated
  /// Opacity sample (fx shared), a regular layer with its own.
  double _stackLayerOpacity(Layer layer, List<Layer> layers, int frameIndex) {
    final base = isAttachedLayer(layer) ? attachedBaseOf(layer, layers) : null;
    final fxCarrier = base ?? layer;
    if (!isLayerFxEnabled(fxCarrier.id)) {
      return layer.opacity.clamp(0.0, 1.0).toDouble();
    }
    return (layer.opacity *
            resolveOpacityTrackAt(fxCarrier.transformTrack.opacity, frameIndex))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// The geometric pose sample the interactive canvas shows for [layerId]
  /// at the playhead — the draw-through wrap input. Null = identity (no
  /// transform work, fx bypassed, or no such layer), which skips the wrap:
  /// the ALWAYS-APPLIED rule (the active layer shows its transform too; the
  /// old edit-in-artwork-space rule is retired, R3 ⑩).
  LayerPoseSample? layerCanvasPoseSample(LayerId layerId) {
    final cut = activeCutOrNull;
    if (cut == null) {
      return null;
    }
    for (final layer in cut.layers) {
      if (layer.id != layerId) {
        continue;
      }
      // An attach layer rides its BASE's transform (fx shared, W5): the
      // interactive view wraps in the base's pose so drawing on the attach
      // row lines up with the composite.
      final fxCarrier = isAttachedLayer(layer)
          ? (attachedBaseOf(layer, cut.layers) ?? layer)
          : layer;
      if (!isLayerFxEnabled(fxCarrier.id)) {
        return null;
      }
      final pose = resolveLayerPoseAt(
        layer: fxCarrier,
        canvasSize: cut.canvasSize,
        frameIndex: _timelineController.currentFrameIndex,
      );
      if (pose == null) {
        return null;
      }
      return (
        pose: pose,
        anchorPoint: resolveLayerAnchorPointAt(
          layer: fxCarrier,
          frameIndex: _timelineController.currentFrameIndex,
        ),
      );
    }
    return null;
  }

  /// The ACTIVE cut's cut-level pose over the CANVAS at [frameIndex]
  /// (default: the playhead) — the storyboard V-row fx preview on the
  /// EDITING canvas and the scrub preview (R9-B). Non-null only while the
  /// cut's geometric lanes carry keys AND its fx apply; canvas-space via
  /// the camera-frame conjugation (cutPoseForCanvasPreview — the exact
  /// remap playback uses, R8-③).
  LayerPoseSample? activeCutCanvasPoseSample({int? frameIndex}) {
    final cut = activeCutOrNull;
    if (cut == null || !isCutFxEnabled(cut.id) || !cutPoseIsActive(cut)) {
      return null;
    }
    final preview = cutPoseForCanvasPreview(
      cut,
      frameIndex ?? _timelineController.currentFrameIndex,
      cameraFrameSize: cameraFrameSize,
      canvasSize: cut.canvasSize,
    );
    return (pose: preview.pose, anchorPoint: preview.anchorPoint);
  }

  /// The cut fade the editing canvas (and the scrub preview) shows at
  /// [frameIndex] (default: the playhead) — the resolved opacity while the
  /// cut's fx apply, 1 when bypassed. R9-C rule: fx ALWAYS reflects; dark
  /// faded frames are worked with the fx switch off.
  double activeCutEditingFadeOpacity({int? frameIndex}) {
    final cut = activeCutOrNull;
    if (cut == null || !isCutFxEnabled(cut.id)) {
      return 1;
    }
    return cut.fadeOpacityAt(
      frameIndex ?? _timelineController.currentFrameIndex,
    );
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
  /// for camera preview/export compositing and the canvas tools (eyedropper
  /// sample, fill compose). The store's display cache is consumed when
  /// valid (the editing coordinator donates the session surface on every
  /// commit/undo/redo); a cold rebuild replays the frame's paint commands
  /// ONCE and stores the result back as the new display cache — repeated
  /// tool taps must not replay the whole stroke history per tap (R11-②③).
  BitmapSurface? brushSurfaceForLayerFrame(Layer layer, Frame frame) {
    final cut = activeCutOrNull;
    if (cut == null) {
      return null; // Gap state: no cut, no artwork.
    }
    final frameKey = BrushFrameKey(
      projectId: _repository.requireProject().id,
      trackId: activeCutTrackId,
      cutId: cut.id,
      layerId: layer.id,
      frameId: frame.id,
    );
    // R19 P3b: the baked raster is the truth — the resolver is a plain
    // reference read (valid display cache first, else baked). No replay
    // exists anymore.
    return brushFrameStore.currentSurfaceWithoutReplay(
      frameKey,
      canvasSize: cut.canvasSize,
    );
  }

  /// The resolved camera pose at the current playhead frame (keyframe,
  /// interpolation, or the default pose when the cut has no camera work).
  CameraPose get cameraPoseAtCurrentFrame => resolveCameraPoseAt(
    camera: requireActiveCut.camera,
    canvasSize: requireActiveCut.canvasSize,
    frameIndex: _timelineController.currentFrameIndex,
  );

  bool get hasCameraKeyframeAtCurrentFrame =>
      activeCutOrNull?.camera.keyframeAt(
        _timelineController.currentFrameIndex,
      ) !=
      null;

  void setCameraKeyframeAtCurrentFrame(CameraPose pose) {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.setCutCameraKeyframe(
      cutId: cutId,
      frameIndex: _timelineController.currentFrameIndex,
      pose: pose,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void removeCameraKeyframeAtCurrentFrame() {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.removeCutCameraKeyframe(
      cutId: cutId,
      frameIndex: _timelineController.currentFrameIndex,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  void clearActiveCutCamera() {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.clearCutCamera(cutId: cutId);
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Replaces the active cut's camera track (one undo step) — the property
  /// lanes' per-property key edits route through here.
  void updateActiveCutCameraTrack(
    TransformTrack track, {
    String description = 'Edit camera keyframes',
  }) {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.updateCutCamera(
      cutId: cutId,
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
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.updateLayerTransformTrack(
      cutId: cutId,
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
      orElse: () => layerIdentityPose(requireActiveCut.canvasSize),
    );
  }

  /// The layer's resolved anchor point at [frameIndex] — the anchor-point
  /// lane's value column and key-freeze source (canvas center while
  /// unkeyed).
  CanvasPoint layerAnchorPointAtFrame(Layer layer, int frameIndex) {
    return resolveLayerAnchorPointAt(layer: layer, frameIndex: frameIndex) ??
        CanvasPoint(
          x: requireActiveCut.canvasSize.width / 2,
          y: requireActiveCut.canvasSize.height / 2,
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

  // --- Visibility solo mode (session view state, not persisted) ------------

  /// The legend eye's SOLO MODE (R4 #7 rework — REAL eye flips, user rule):
  /// engaging it snapshots every row's eye (cut layers + track SE), turns
  /// every non-active eye OFF and the active one ON — the rows show it and
  /// playback/fill follow naturally, exactly like clicking the eyes by
  /// hand (view-ish controller writes, not undoable). Switching the active
  /// layer re-solos; disengaging restores each eye from the snapshot.
  /// Leaving the cut exits the mode (restoring first) — the snapshot is
  /// cut-scoped.
  bool _layerVisibilitySoloEnabled = false;
  Map<LayerId, bool>? _visibilitySoloSnapshot;
  CutId? _visibilitySoloCutId;

  bool get layerVisibilitySoloEnabled => _layerVisibilitySoloEnabled;

  void toggleLayerVisibilitySolo() {
    if (_layerVisibilitySoloEnabled) {
      _exitVisibilitySolo();
    } else {
      _layerVisibilitySoloEnabled = true;
      _visibilitySoloCutId = _editingSession.activeCutId;
      _visibilitySoloSnapshot = {
        for (final layer in layers) layer.id: layer.isVisible,
      };
      _applyVisibilitySolo();
    }
    notifyListeners();
  }

  /// Re-solos to the CURRENT active layer. Rows born during the solo join
  /// the snapshot with their pre-flip eye so exiting restores them too.
  void _applyVisibilitySolo() {
    final activeId = activeLayerId;
    if (activeId == null) {
      return;
    }
    for (final layer in layers) {
      _visibilitySoloSnapshot?.putIfAbsent(layer.id, () => layer.isVisible);
      final shouldShow = layer.id == activeId;
      if (layer.isVisible != shouldShow) {
        _layerController.toggleLayerVisibility(layer.id);
      }
    }
  }

  void _exitVisibilitySolo() {
    _layerVisibilitySoloEnabled = false;
    _visibilitySoloCutId = null;
    final snapshot = _visibilitySoloSnapshot;
    _visibilitySoloSnapshot = null;
    if (snapshot == null) {
      return;
    }
    // Restore through the repository's anywhere seam — rows deleted during
    // the solo have nothing to restore (skip).
    snapshot.forEach((layerId, visible) {
      try {
        _repository.updateLayer(
          layerId: layerId,
          update: (layer) => layer.isVisible == visible
              ? layer
              : layer.copyWith(isVisible: visible),
        );
      } on StateError {
        // Layer gone.
      }
    });
  }

  /// Keeps the solo mode consistent after active-layer/cut changes: same
  /// cut → re-solo to the new active row; different cut → exit (restore).
  void _syncVisibilitySolo() {
    if (!_layerVisibilitySoloEnabled) {
      return;
    }
    if (_editingSession.activeCutId != _visibilitySoloCutId) {
      _exitVisibilitySolo();
    } else {
      _applyVisibilitySolo();
    }
  }

  // --- Cut display toggles (session view state, not persisted) -------------

  /// Cuts whose cut-level FX (the V track's Transform group — the pose AND
  /// the fade, "opacity joins the transform system") are bypassed at
  /// DISPLAY time — the storyboard V-row fx switch (R9). Display-time only,
  /// like the cut pose itself: playback (canvas + camera view) skips
  /// pose/fade; the MP4 bake, PNG export and thumbnails are untouched.
  final Set<CutId> _fxBypassedCutIds = {};

  bool isCutFxEnabled(CutId cutId) => !_fxBypassedCutIds.contains(cutId);

  void toggleCutFx(CutId cutId) {
    if (!_fxBypassedCutIds.remove(cutId)) {
      _fxBypassedCutIds.add(cutId);
    }
    notifyListeners();
  }

  /// Cuts whose PICTURE is hidden in the playback display — the storyboard
  /// V-row eye (R9). The paper stays, the composite doesn't draw. A working
  /// aid: the editing canvas, exports and thumbnails ignore it.
  final Set<CutId> _hiddenPictureCutIds = {};

  bool isCutPictureVisible(CutId cutId) =>
      !_hiddenPictureCutIds.contains(cutId);

  void toggleCutPictureVisibility(CutId cutId) {
    if (!_hiddenPictureCutIds.remove(cutId)) {
      _hiddenPictureCutIds.add(cutId);
    }
    notifyListeners();
  }

  void undo() {
    final beforeLayers = List<Layer>.of(
      activeCutOrNull?.layers ?? const <Layer>[],
    );
    final previousActiveLayerId = _layerController.activeLayerId;
    final previousFrameIndex = _timelineController.currentFrameIndex;

    _historyManager.undo();
    final preferredLayerId = _preferredLayerAfterLayerListChange(
      beforeLayers: beforeLayers,
      afterLayers: activeCutOrNull?.layers ?? const <Layer>[],
      previousActiveLayerId: previousActiveLayerId,
    );
    _refreshAfterCutCommand(
      preferredActiveLayerId: preferredLayerId,
      preferredFrameIndex: previousFrameIndex,
    );
    notifyListeners();
  }

  void redo() {
    final beforeLayers = List<Layer>.of(
      activeCutOrNull?.layers ?? const <Layer>[],
    );
    final previousActiveLayerId = _layerController.activeLayerId;
    final previousFrameIndex = _timelineController.currentFrameIndex;

    _historyManager.redo();
    final preferredLayerId = _preferredLayerAfterLayerListChange(
      beforeLayers: beforeLayers,
      afterLayers: activeCutOrNull?.layers ?? const <Layer>[],
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
    // R15-⑤: never switch cuts under a live editing interaction.
    if (editingInteractionBusy) {
      return;
    }

    // The visibility solo is cut-scoped: restore the eyes before leaving.
    if (_layerVisibilitySoloEnabled) {
      _exitVisibilitySolo();
    }
    _editingSession.setActiveCutId(cutId);
    _copiedFrame = null;
    clearFrameRangeSelection();
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
    // R6-④: SE/instruction cels are data rows — no editable brush target,
    // so the canvas never accepts strokes on them (the drawn stack still
    // composites them read-only).
    if (!layerKindAcceptsBrushInput(activeLayer.kind)) {
      return null;
    }
    // R4 #1: a hidden layer takes no strokes either — you would be drawing
    // into something the canvas doesn't show. Flip the eye back on (or use
    // the solo mode) to draw.
    if (!activeLayer.isVisible) {
      return null;
    }

    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return null; // Gap state: no cut, no brush target.
    }
    return BrushEditorSelection(
      projectId: _repository.requireProject().id,
      trackId: activeCutTrackId,
      cutId: cutId,
      layerId: activeLayer.id,
      frameId: selectedFrame.id,
    );
  }

  bool get canDeleteActiveLayer {
    final activeLayer = this.activeLayer;
    if (activeLayer == null) {
      return false;
    }
    // Attach rows are accessories: always deletable, never counted toward
    // the drawing floor (deleting a BASE cascades over its attach rows).
    if (isAttachedLayer(activeLayer)) {
      return true;
    }
    final cut = activeCutOrNull;
    if (cut == null) {
      return false;
    }
    final layers = cut.layers;
    return switch (activeLayer.kind) {
      LayerKind.camera => false,
      // The sheet's fixture floors: at least two SE rows (S1·S2, now
      // track-owned) and one instruction row survive.
      LayerKind.se => activeTrack.seLayers.length > 2,
      LayerKind.instruction =>
        layers.where((layer) => layer.kind == LayerKind.instruction).length > 1,
      // Keep at least one drawing-section layer in the cut.
      LayerKind.animation || LayerKind.storyboard || LayerKind.art =>
        layers
                .where(
                  (layer) =>
                      !isAttachedLayer(layer) &&
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
    final cut = activeCutOrNull;
    if (cut == null) {
      return null;
    }
    final frameIndex = _timelineController.currentFrameIndex;
    for (final layer in cut.layers) {
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
        cutId: cut.id,
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
    // SE rows are track-owned (global frame axis) — copying a cut-local
    // window onto the cut-layer clipboard would recreate the retired
    // cut-owned SE shape; stands down for now. Attach rows stand down too
    // (their cel links point into THIS cut's base).
    if (activeLayer == null ||
        activeLayer.kind == LayerKind.camera ||
        activeLayer.kind == LayerKind.se ||
        isAttachedLayer(activeLayer)) {
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

    final cut = activeCutOrNull;
    if (cut == null) {
      return;
    }
    final activeLayer = this.activeLayer;
    final targetLayers = cut.layers;
    final activeLayerIndex = activeLayer == null
        ? -1
        : targetLayers.indexWhere((layer) => layer.id == activeLayer.id);
    final insertionIndex = activeLayerIndex == -1
        ? targetLayers.length
        : activeLayerIndex + 1;

    final pastedLayerId = _cutCommandCoordinator.pasteLayer(
      cutId: cut.id,
      payload: payload,
      insertionIndex: insertionIndex,
    );
    _refreshAfterCutCommand(preferredActiveLayerId: pastedLayerId);
    notifyListeners();
  }

  void duplicateActiveLayer() {
    final activeLayer = this.activeLayer;
    // Track-owned SE rows: duplication stands down (same clipboard-shape
    // reason as copyActiveLayer); attach rows too (v1 — a duplicate would
    // double-link the same base cels).
    if (activeLayer == null ||
        activeLayer.kind == LayerKind.camera ||
        activeLayer.kind == LayerKind.se ||
        isAttachedLayer(activeLayer)) {
      return;
    }

    final duplicatedLayerId = _cutCommandCoordinator.duplicateLayer(
      // A non-null active layer implies an active cut (gap state has no
      // rows at all).
      cutId: requireActiveCut.id,
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

    if (activeLayer.kind == LayerKind.se) {
      final beforeSe = activeTrack.seLayers;
      final nextActiveLayerId = _stableLayerIdAfterDeleting(
        beforeLayers: beforeSe,
        deletedLayerId: activeLayer.id,
      );
      _historyManager.execute(
        RemoveTrackSeLayerCommand(
          repository: _repository,
          trackId: activeCutTrackId,
          layerId: activeLayer.id,
        ),
      );
      _refreshAfterCutCommand(preferredActiveLayerId: nextActiveLayerId);
      notifyListeners();
      return;
    }

    final beforeLayers = List<Layer>.of(requireActiveCut.layers);
    final nextActiveLayerId = _stableLayerIdAfterDeleting(
      beforeLayers: beforeLayers,
      deletedLayerId: activeLayer.id,
    );

    _cutCommandCoordinator.deleteLayer(
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
  void addLayer() => addLayerOfKind(activeLayer?.kind ?? LayerKind.animation);

  /// Kind-explicit Add Layer (the split button's ▾ list): the same naming
  /// and insertion rules as [addLayer] with the requested kind.
  void addLayerOfKind(LayerKind kind) {
    if (activeCutOrNull == null) {
      return; // Gap state: no cut to add into (SE rows need one too —
      //         selection lives in the cut-scoped row list).
    }
    _layerSequence += 1;
    final layerId = defaultLayerIdForSequence(_layerSequence);
    switch (kind) {
      case LayerKind.se:
        // SE rows are track-owned: insert directly above the active SE row
        // in the TRACK list (the same S1,S3,S2 insertion order the
        // timeline shows — the single ordering every panel renders).
        final seLayers = activeTrack.seLayers;
        final activeIndex = seLayers.indexWhere(
          (layer) => layer.id == activeLayerId,
        );
        final newLayer = Layer(
          id: layerId,
          name: nextSeLayerName(seLayers),
          frames: const [],
          timeline: const {},
          kind: LayerKind.se,
        );
        _historyManager.execute(
          AddTrackSeLayerCommand(
            repository: _repository,
            trackId: activeCutTrackId,
            layer: newLayer,
            insertionIndex: activeIndex < 0 ? null : activeIndex + 1,
          ),
        );
        _layerController.selectLayer(layerId);
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
        // With an attach row active, the new regular layer lands ABOVE the
        // whole attach group — never inside it (the list keeps a base's
        // attach rows adjacent, W5).
        final active = activeLayer;
        if (active != null && isAttachedLayer(active)) {
          final cut = requireActiveCut;
          _layerController.addLayer(
            layer: createDefaultAnimationLayer(
              layerId: layerId,
              cut: cut,
            ).copyWith(kind: kind),
            insertionIndex: attachedGroupEndIndex(
              active.attachedToLayerId!,
              cut.layers,
            ),
          );
          break;
        }
        _layerController.addLayerWithDefaults(layerId: layerId, kind: kind);
      case LayerKind.camera:
        _layerController.addLayerWithDefaults(layerId: layerId);
    }
    notifyListeners();
  }

  /// Whether the active layer can carry (or already rides within) an
  /// attach group — the Add Attach Layer entrance's gate (W5).
  bool get canAddAttachedLayerToActive {
    final active = activeLayer;
    if (active == null) {
      return false;
    }
    if (isAttachedLayer(active)) {
      // Adding from an attach row targets ITS base (same group).
      return attachedBaseOf(active, requireActiveCut.layers) != null;
    }
    return canCarryAttachedLayers(active);
  }

  /// Adds an ATTACH LAYER riding the active layer (or the active attach
  /// row's base): own cels/eye/opacity/mark, the base's timing and FX;
  /// [placement] picks above or below the base's picture. Selected on
  /// creation; excluded from the timesheet by default.
  void addAttachedLayer(AttachedPlacement placement) {
    if (!canAddAttachedLayerToActive) {
      return;
    }
    final active = activeLayer!;
    final cut = requireActiveCut;
    final base = isAttachedLayer(active)
        ? attachedBaseOf(active, cut.layers)!
        : active;
    _layerSequence += 1;
    final layerId = defaultLayerIdForSequence(_layerSequence);
    final baseIndex = cut.layers.indexWhere((layer) => layer.id == base.id);
    if (baseIndex == -1) {
      return;
    }
    // [below…, base, above…]: a new below goes bottommost (before the
    // existing belows), a new above topmost (past the group).
    final insertionIndex = placement == AttachedPlacement.below
        ? baseIndex -
              attachedLayersOf(base.id, cut.layers)
                  .where(
                    (layer) =>
                        layer.attachedPlacement == AttachedPlacement.below,
                  )
                  .length
        : attachedGroupEndIndex(base.id, cut.layers);
    _layerController.addLayer(
      layer: Layer(
        id: layerId,
        name: nextAttachedLayerName(base, cut.layers),
        frames: const [],
        timeline: const {},
        kind: base.kind,
        onTimesheet: false,
        attachedToLayerId: base.id,
        attachedPlacement: placement,
      ),
      insertionIndex: insertionIndex,
    );
    notifyListeners();
  }

  void selectLayer(LayerId layerId) {
    // A frame-range selection is single-layer (UI-R8): moving to another
    // row drops it.
    if (frameRangeSelection.value != null &&
        frameRangeSelection.value!.layerId != layerId) {
      clearFrameRangeSelection();
    }
    _layerController.selectLayer(layerId);
    // The solo mode FOLLOWS the active layer (R4 #7).
    _syncVisibilitySolo();
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

  // --- Opacity drag preview (R4 #4/#6) ------------------------------------

  /// Live opacity-drag preview: per-move values ride this notifier into
  /// the editing canvas only (the dragged FieldSlider echoes locally)
  /// WITHOUT a session notify — the old per-move repo write rebuilt every
  /// panel per pointer move and made the slider feel heavy. Release
  /// commits ONE write + notify. The legend's master bar previews a SET of
  /// rows through the same channel.
  final ValueNotifier<({Set<LayerId> layerIds, double opacity})?>
  opacityDragPreview = ValueNotifier(null);

  void previewLayerOpacity(LayerId layerId, double opacity) {
    opacityDragPreview.value = (
      layerIds: {layerId},
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
    );
  }

  void commitLayerOpacity(LayerId layerId, double opacity) {
    opacityDragPreview.value = null;
    setLayerOpacity(layerId: layerId, opacity: opacity);
  }

  /// The master-bar preview/commit (R4 #6): [layerIds] = the rows the rail
  /// currently DISPLAYS (filter-passing), computed by the grid. Camera
  /// stays untouched (its slider is the camera-view dim).
  void previewLayersOpacity(Set<LayerId> layerIds, double opacity) {
    opacityDragPreview.value = (
      layerIds: layerIds,
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
    );
  }

  /// The master bar's LAST committed value — the bar rests on this, not a
  /// live average (UI-R6 #2).
  double lastMasterOpacity = 1.0;

  void commitLayersOpacity(Set<LayerId> layerIds, double opacity) {
    opacityDragPreview.value = null;
    final clamped = opacity.clamp(0.0, 1.0).toDouble();
    lastMasterOpacity = clamped;
    for (final layer in layers) {
      if (layerIds.contains(layer.id) &&
          layer.kind != LayerKind.camera &&
          layer.opacity != clamped) {
        _layerController.setLayerOpacity(layerId: layer.id, opacity: clamped);
      }
    }
    notifyListeners();
  }

  /// Filter-set hook (UI-R6 #3): when the active layer fails [passes], the
  /// selection moves to the nearest PASSING layer ABOVE it on screen
  /// (horizontal display order), falling back to the first passing layer.
  void moveSelectionToFilteredLayer(bool Function(Layer layer) passes) {
    final active = activeLayer;
    if (active == null || passes(active)) {
      return;
    }
    final display = horizontalLayerDisplayOrder(layers);
    final activeIndex = display.indexWhere((layer) => layer.id == active.id);
    Layer? target;
    // Screen-up = earlier in horizontal display order.
    for (var index = activeIndex - 1; index >= 0; index -= 1) {
      if (passes(display[index])) {
        target = display[index];
        break;
      }
    }
    if (target == null) {
      for (final layer in display) {
        if (passes(layer)) {
          target = layer;
          break;
        }
      }
    }
    if (target != null) {
      selectLayer(target.id);
    }
  }

  /// Flips whether [layerId] is recorded on the timesheet output. One undo
  /// step; no controller rebuild — the flag never affects rendering.
  void toggleLayerTimesheet(LayerId layerId) {
    final layer = layers.firstWhere((layer) => layer.id == layerId);
    // A resolvable row implies an active cut (gap state has no rows).
    _cutCommandCoordinator.setLayerTimesheet(
      cutId: requireActiveCut.id,
      layerId: layerId,
      onTimesheet: !layer.onTimesheet,
    );
    notifyListeners();
  }

  /// Flips the layer's FILL-reference flag (R20-C2, the CSP lighthouse):
  /// while any visible layer of the cut carries it, fills read ONLY the
  /// flagged layers as their source picture. One undo step; the display
  /// composite never changes.
  void toggleLayerFillReference(LayerId layerId) {
    final layer = layers.firstWhere((layer) => layer.id == layerId);
    _cutCommandCoordinator.setLayerFillReference(
      cutId: requireActiveCut.id,
      layerId: layerId,
      isFillReference: !layer.isFillReference,
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

  /// The project's paper/background (R10-⑥): canvas paper, playback gap
  /// fill and export backing.
  ProjectBackground get projectBackground =>
      _repository.requireProject().background;

  /// One undo step; no-op when unchanged. Composites are untouched — the
  /// background paints at display/export time, never baked (the camera
  /// rule).
  void setProjectBackground(ProjectBackground background) {
    _cutCommandCoordinator.setProjectBackground(background);
    notifyListeners();
  }

  /// Sets [layerId]'s organizational color mark. One undo step.
  void setLayerMark(LayerId layerId, LayerMark mark) {
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.setLayerMark(
      cutId: cutId,
      layerId: layerId,
      mark: mark,
    );
    notifyListeners();
  }

  // --- Legend bulk commands (R-toolbar round) -----------------------------
  //
  // One legend-flyout action sweeps every eligible layer of the active cut.
  // Semantics mirror the per-row toggles: visibility/mute/opacity ride the
  // layer controller (view-ish state, not undoable — same as their single
  // buttons), sheet/mark/fill-reference are undoable and land as ONE
  // CompositeCommand entry.

  /// Shows or hides every layer of the active cut.
  void setAllLayersVisibility(bool visible) {
    for (final layer in layers) {
      if (layer.isVisible != visible) {
        _layerController.toggleLayerVisibility(layer.id);
      }
    }
    notifyListeners();
  }

  /// Mutes/unmutes every SE layer of the active cut.
  void setAllSeLayersMuted(bool muted) {
    for (final layer in layers) {
      if (layer.kind == LayerKind.se && layer.muted != muted) {
        _layerController.toggleLayerMuted(layer.id);
      }
    }
    notifyListeners();
  }

  /// Resets every opacity-bearing layer back to fully opaque. The camera
  /// row's slider is the camera-view DIM (a host notifier), not layer
  /// opacity — it stays untouched.
  void resetAllLayersOpacity() => setAllLayersOpacity(1.0);

  /// Sets every non-camera layer's opacity to [opacity] (the legend's
  /// numeric bulk set). Camera stays untouched (its slider is the dim).
  void setAllLayersOpacity(double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    for (final layer in layers) {
      if (layer.kind != LayerKind.camera && layer.opacity != clamped) {
        _layerController.setLayerOpacity(layerId: layer.id, opacity: clamped);
      }
    }
    notifyListeners();
  }

  /// Turns the timesheet flag on/off for every eligible layer — one undo.
  /// Track-owned SE rows join the sweep: the flag commands resolve through
  /// the anywhere lookup now (the SE mark/sheet fix).
  void setAllLayersOnTimesheet(bool onTimesheet) {
    final cut = activeCutOrNull;
    if (cut == null) {
      return;
    }
    final cutId = cut.id;
    final commands = <Command>[
      for (final layer in [...cut.layers, ...activeTrack.seLayers])
        if (layer.attachedToLayerId == null && layer.onTimesheet != onTimesheet)
          UpdateLayerTimesheetCommand(
            repository: _repository,
            cutId: cutId,
            layerId: layer.id,
            onTimesheet: onTimesheet,
          ),
    ];
    if (commands.isEmpty) {
      return;
    }
    _historyManager.execute(
      CompositeCommand(
        description: onTimesheet
            ? 'Add all layers to timesheet'
            : 'Remove all layers from timesheet',
        commands: commands,
      ),
    );
    notifyListeners();
  }

  /// Clears every layer mark of the active cut (track-owned SE rows
  /// included, like the sheet sweep) — one undo.
  void clearAllLayerMarks() {
    final cut = activeCutOrNull;
    if (cut == null) {
      return;
    }
    final cutId = cut.id;
    final commands = <Command>[
      for (final layer in [...cut.layers, ...activeTrack.seLayers])
        if (layer.mark != LayerMark.none)
          UpdateLayerMarkCommand(
            repository: _repository,
            cutId: cutId,
            layerId: layer.id,
            mark: LayerMark.none,
          ),
    ];
    if (commands.isEmpty) {
      return;
    }
    _historyManager.execute(
      CompositeCommand(
        description: 'Clear all layer marks',
        commands: commands,
      ),
    );
    notifyListeners();
  }

  /// Drops the fill-reference flag from every layer — one undo (cut-owned
  /// layers, like the sheet sweep).
  void clearAllFillReferences() {
    final cut = activeCutOrNull;
    if (cut == null) {
      return;
    }
    final cutId = cut.id;
    final commands = <Command>[
      for (final layer in cut.layers)
        if (layer.isFillReference)
          UpdateLayerFillReferenceCommand(
            repository: _repository,
            cutId: cutId,
            layerId: layer.id,
            isFillReference: false,
          ),
    ];
    if (commands.isEmpty) {
      return;
    }
    _historyManager.execute(
      CompositeCommand(
        description: 'Clear all fill references',
        commands: commands,
      ),
    );
    notifyListeners();
  }

  /// Bypasses or restores EVERY layer's fx (session view state, like the
  /// per-row switch).
  void setAllLayersFxBypassed(bool bypassed) {
    if (bypassed) {
      _fxBypassedLayerIds.addAll(layers.map((layer) => layer.id));
    } else {
      _fxBypassedLayerIds.clear();
    }
    notifyListeners();
  }

  /// Shows/hides every layer belonging to [section] (the section bracket's
  /// flyout) — visibility semantics like [setAllLayersVisibility].
  void setSectionLayersVisibility(TimelineSection section, bool visible) {
    for (final layer in layers) {
      if (timelineSectionForLayerKind(layer.kind) == section &&
          layer.isVisible != visible) {
        _layerController.toggleLayerVisibility(layer.id);
      }
    }
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
    final cutId = _editingSession.activeCutId;
    if (cutId == null) {
      return;
    }
    _cutCommandCoordinator.updateLayerInstructions(
      cutId: cutId,
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
    // A resolvable instruction layer implies an active cut.
    final available = (requireActiveCut.duration - frameIndex).clamp(
      1,
      1 << 20,
    );
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
      layerId: layerId,
      audioClips: before,
    );
    _cutCommandCoordinator.updateLayerAudioClips(
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
      for (final layer in track.seLayers) {
        for (final clip in layer.audioClips) {
          if (clip.filePath == path) {
            return true;
          }
        }
      }
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
      cutId: requireActiveCut.id,
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
    // toggles (SE/art) or are fixed (camera/instruction/attach rows).
    if (targetLayer == null ||
        isAttachedLayer(targetLayer) ||
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
        !isAttachedLayer(targetLayer) &&
        (targetLayer.kind == LayerKind.animation ||
            targetLayer.kind == LayerKind.art);
  }

  void toggleTargetLayerArt() {
    final targetLayer = _targetLayerForKindToggle;
    if (targetLayer == null || !canToggleTargetLayerArt) {
      return;
    }

    _cutCommandCoordinator.updateLayerKind(
      cutId: requireActiveCut.id,
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
      cutId: requireActiveCut.id,
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
    // Attach rows (W5): "Create Drawing" makes a cel RIDING the base's
    // exposed cel at the playhead — possible only where the base shows a
    // cel that has no link on this row yet.
    if (isAttachedLayer(layer)) {
      return _attachTargetBaseFrameIdAt(layer) != null;
    }

    return _timelineController.canCreateDrawingAt(
      layer: layer,
      frameIndex: _timelineController.currentFrameIndex,
    );
  }

  /// The base cel id an attach cel would link to at the playhead; null
  /// when the base shows nothing there, the base is gone, or the cel is
  /// already linked on [attached].
  FrameId? _attachTargetBaseFrameIdAt(Layer attached) {
    final base = attachedBaseOf(
      attached,
      activeCutOrNull?.layers ?? const <Layer>[],
    );
    if (base == null) {
      return null;
    }
    final baseFrameId = _timelineController.resolveFrameIdForLayer(
      layer: base,
      frameIndex: _timelineController.currentFrameIndex,
    );
    if (baseFrameId == null ||
        attached.baseFrameLinks.containsKey(baseFrameId)) {
      return null;
    }
    return baseFrameId;
  }

  bool get canCopyFrameAtCurrentFrame {
    return selectedFrame != null;
  }

  bool get canPasteLinkedFrameAtCurrentFrame {
    final layer = activeLayer;
    final copiedFrame = _copiedFrame;
    if (layer == null ||
        copiedFrame == null ||
        layer.id != copiedFrame.layerId ||
        // Attach rows own no timeline — linked reuse happens through the
        // BASE's links (link the base cel instead).
        isAttachedLayer(layer)) {
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
    // Attach rows have no timing of their own (the base owns it).
    if (layer == null ||
        !layerKindHoldsDrawings(layer.kind) ||
        isAttachedLayer(layer)) {
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
    if (isAttachedLayer(layer)) {
      final baseFrameId = _attachTargetBaseFrameIdAt(layer);
      if (baseFrameId == null) {
        return;
      }
      _historyManager.execute(
        CreateAttachedCelCommand(
          repository: _repository,
          cutId: requireActiveCut.id,
          layerId: layer.id,
          baseFrameId: baseFrameId,
          frameId: FrameId(_nextFrameId(layer.id)),
        ),
      );
      notifyListeners();
      return;
    }
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
  // accounting) and publishing it on [dragPreview]; releasing commits the
  // before→after pair as ONE undoable command. The repository and the
  // session listeners stay untouched until the release — a step rebuilds
  // only the preview consumers (the dragged row's gate, the cursor
  // overlay, the storyboard strips), never the panels (R5-⑧ generalized).

  /// The scoped edit-drag preview channel (exposure commas + cut trims).
  /// Value-only: per-step updates never fire a session notify.
  final ValueNotifier<TimelineDragPreview?> dragPreview =
      ValueNotifier<TimelineDragPreview?>(null);

  Layer? _edgeDragBefore;
  TimelineBlockEdge? _edgeDragEdge;
  int? _edgeDragBlockStart;

  /// The drag's current result (GLOBAL layer for track SE): [dragPreview]
  /// carries the DISPLAY form, so the commit reads this instead.
  Layer? _edgeDragAfter;

  /// Non-null while a track-SE drag is in flight — previews window through
  /// it before publishing.
  TrackSeWindow? _edgeDragWindow;

  bool get isExposureEdgeDragActive => _edgeDragBefore != null;

  /// Starts a comma drag on [edge] of the block starting at
  /// [blockStartIndex] (as DISPLAYED — cut-local); returns false when
  /// there is no such block. Instruction rows join the same pipeline —
  /// their spans live on Layer.instructions and shift without ripple.
  /// Track-SE rows convert to the global axis here; a spill-in block's
  /// start edge is rejected (its real start lives in an earlier cut).
  /// Track-global hosts (the storyboard SE strips) pass
  /// [blockStartIsGlobal] with TRUE global starts — any cut's block drags
  /// there (UI-R7 #5), no window conversion, no spill synthesis.
  bool beginExposureEdgeDrag({
    required LayerId layerId,
    required int blockStartIndex,
    required TimelineBlockEdge edge,
    bool blockStartIsGlobal = false,
  }) {
    // Attach rows own no timing — no comma grips (the BASE's grips move
    // both, W5).
    if (_isAttachedLayerId(layerId)) {
      return false;
    }
    if (isTrackSeLayerId(layerId)) {
      final global = trackSeGlobalLayerById(layerId);
      if (global == null) {
        return false;
      }
      final window = trackSeWindow;
      if (!blockStartIsGlobal &&
          edge == TimelineBlockEdge.start &&
          window.isSpillInStart(global, blockStartIndex)) {
        return false;
      }
      final globalStart = blockStartIsGlobal
          ? blockStartIndex
          : window.globalBlockStartFor(global, blockStartIndex);
      if (!(global.timeline[globalStart]?.isDrawing ?? false)) {
        return false;
      }
      _edgeDragBefore = global;
      _edgeDragEdge = edge;
      _edgeDragBlockStart = globalStart;
      _edgeDragWindow = window;
      return true;
    }

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

  /// Applies the drag's current cumulative frame delta as a live preview
  /// on [dragPreview] — the repository is NOT touched.
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
    // No notifyEditActivity here: composites self-validate against the
    // committed edit, the drag-end warm request re-renders what changed,
    // and the idle gate's REAL-time delay would leave timers pending under
    // the fake test clock.
    _edgeDragAfter = after == before ? null : after;
    // Track-SE drags: the preview channel carries the DISPLAY form (the
    // row gates render cut-local clones) PLUS the global form for the
    // storyboard's track-global strips (UI-R7 #7); the commit uses
    // _edgeDragAfter.
    final window = _edgeDragWindow;
    dragPreview.value = after == before
        ? null
        : ExposureEdgeDragPreview(
            previewLayer: window == null ? after : window.displayLayer(after),
            globalPreviewLayer: window == null ? null : after,
          );
  }

  /// Commits the drag as a single undo step (no-op when nothing changed):
  /// the command's execute applies the final result to the repository.
  void endExposureEdgeDrag() {
    final before = _edgeDragBefore;
    final after = _edgeDragAfter;
    _edgeDragBefore = null;
    _edgeDragEdge = null;
    _edgeDragBlockStart = null;
    _edgeDragAfter = null;
    _edgeDragWindow = null;
    dragPreview.value = null;
    if (before == null) {
      return;
    }

    if (after == null || after == before) {
      return;
    }
    _timelineController.commitLayerTimelineDrag(before: before, after: after);
    _warmActiveCut();
    notifyListeners();
  }

  // --- Storyboard cut-trim edge drags --------------------------------------

  Map<CutId, int>? _cutTrimBeforeDurations;
  Map<CutId, int>? _cutTrimBeforeGaps;
  CutId? _cutTrimCutId;
  CutId? _cutTrimNextCutId;
  TimelineBlockEdge? _cutTrimEdge;

  /// Track cut order + the dragged cut's slot, snapshotted for START-edge
  /// slides (the leftward cascade pushes predecessor gaps, R12-⑦).
  List<CutId>? _cutTrimOrder;
  int? _cutTrimIndex;

  /// Starts a storyboard edge drag on [cutId]'s [edge]. The END edge trims
  /// the duration (growth eats the following gap first); the START edge
  /// TRIMS from the front (R12-B, timeline start-comma parity): the end
  /// stays put, the length changes, and the start's movement adjusts the
  /// leading gaps. Any cut's start may trim, the first one included.
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
    StoryboardTimelineLayoutEntry? next;
    if (edge == TimelineBlockEdge.end) {
      for (final candidate in layout) {
        if (candidate.trackId == entry.trackId &&
            candidate.cutIndex == entry.cutIndex + 1) {
          next = candidate;
          break;
        }
      }
    }

    _cutTrimBeforeDurations = {entry.cutId: entry.cut.duration};
    if (edge == TimelineBlockEdge.start) {
      // The start TRIM's leftward growth cascades through the
      // PREDECESSORS' gaps, so the whole track's order and gaps join the
      // drag snapshot.
      final trackEntries = [
        for (final candidate in layout)
          if (candidate.trackId == entry.trackId) candidate,
      ];
      _cutTrimOrder = [for (final candidate in trackEntries) candidate.cutId];
      _cutTrimIndex = entry.cutIndex;
      _cutTrimBeforeGaps = {
        for (final candidate in trackEntries)
          candidate.cutId: candidate.cut.leadingGapFrames,
      };
    } else {
      _cutTrimBeforeGaps = {
        entry.cutId: entry.cut.leadingGapFrames,
        if (next != null) next.cutId: next.cut.leadingGapFrames,
      };
    }
    _cutTrimCutId = cutId;
    _cutTrimNextCutId = next?.cutId;
    _cutTrimEdge = edge;
    return true;
  }

  /// Applies the drag's cumulative frame delta as a live preview on
  /// [dragPreview] (the repository is NOT touched).
  ///
  /// END edge: the duration changes; growth consumes the FOLLOWING cut's
  /// leading gap first (that cut holds still until the gap is spent, then
  /// ripples). Shrinking follows the timeline's block language (R10-⑦):
  /// only an ATTACHED next cut rides the boundary — a detached one holds
  /// its global position (its gap grows by the shrink). START edge: a
  /// TRIM (R12-B, timeline start-comma parity) — the END stays put and
  /// the LENGTH changes; leftward growth consumes its own gap then pushes
  /// the predecessors (cascade, frame-0 clamp), rightward shrink opens
  /// its gap (length clamps at 1).
  void updateCutEdgeDrag(int cumulativeDelta) {
    final beforeDurations = _cutTrimBeforeDurations;
    final beforeGaps = _cutTrimBeforeGaps;
    final cutId = _cutTrimCutId;
    final edge = _cutTrimEdge;
    if (beforeDurations == null ||
        beforeGaps == null ||
        cutId == null ||
        edge == null) {
      return;
    }

    final durations = <CutId, int>{};
    final gaps = <CutId, int>{};
    if (edge == TimelineBlockEdge.end) {
      final newDuration = math.max(
        1,
        beforeDurations[cutId]! + cumulativeDelta,
      );
      durations[cutId] = newDuration;
      final nextId = _cutTrimNextCutId;
      if (nextId != null) {
        final growth = newDuration - beforeDurations[cutId]!;
        final baseGap = beforeGaps[nextId]!;
        // Growth: consume the gap, then push. Shrink: an attached next
        // cut (gap 0 at drag start) ripples with the boundary; a DETACHED
        // one holds its global position — the gap absorbs the shrink.
        gaps[nextId] = growth > 0
            ? math.max(0, baseGap - growth)
            : (baseGap > 0 ? baseGap - growth : 0);
      }
    } else {
      // START edge = a TRIM (R12-B, timeline start-comma parity): the
      // cut's END stays put and its LENGTH changes. Rightward movement
      // shrinks the cut (its own gap grows; length clamps at 1 frame);
      // leftward movement grows it — its own gap absorbs first, then the
      // predecessors get pushed left through theirs (cascade, frame-0
      // clamp). Followers never move: the start's movement and the length
      // change cancel exactly at the end boundary.
      final beforeDuration = beforeDurations[cutId]!;
      if (cumulativeDelta >= 0) {
        final moved = math.min(cumulativeDelta, beforeDuration - 1);
        durations[cutId] = beforeDuration - moved;
        gaps[cutId] = beforeGaps[cutId]! + moved;
      } else {
        final order = _cutTrimOrder!;
        var remaining = -cumulativeDelta;
        for (var i = _cutTrimIndex!; i >= 0 && remaining > 0; i -= 1) {
          final id = order[i];
          final take = math.min(remaining, beforeGaps[id]!);
          if (take > 0) {
            gaps[id] = beforeGaps[id]! - take;
            remaining -= take;
          }
        }
        final moved = (-cumulativeDelta) - remaining;
        durations[cutId] = beforeDuration + moved;
      }
    }

    final changed =
        durations[cutId] != beforeDurations[cutId] ||
        gaps.entries.any((entry) => beforeGaps[entry.key] != entry.value);
    dragPreview.value = changed
        ? CutTrimDragPreview(previewDurations: durations, previewGaps: gaps)
        : null;
  }

  /// Commits the drag as a single undo step (no-op when nothing changed):
  /// the command's execute applies the final durations AND gaps, plus the
  /// fade re-anchor (W4 fade durability) — a trimmed cut's CANONICAL fade
  /// envelope is rebuilt for the new duration so the fade-out keeps riding
  /// the cut's end. Hand-keyed opacity lanes are left untouched (the
  /// "Opacity lane = fade envelope" invariant only owns the canonical
  /// shape).
  void endCutEdgeDrag() {
    final beforeDurations = _cutTrimBeforeDurations;
    final beforeGaps = _cutTrimBeforeGaps;
    final preview = dragPreview.value;
    _cutTrimBeforeDurations = null;
    _cutTrimBeforeGaps = null;
    _cutTrimCutId = null;
    _cutTrimNextCutId = null;
    _cutTrimEdge = null;
    _cutTrimOrder = null;
    _cutTrimIndex = null;
    dragPreview.value = null;
    if (beforeDurations == null || beforeGaps == null) {
      return;
    }

    final previewDurations = preview is CutTrimDragPreview
        ? preview.previewDurations
        : const <CutId, int>{};
    final previewGaps = preview is CutTrimDragPreview
        ? preview.previewGaps
        : const <CutId, int>{};
    final afterDurations = {
      for (final id in beforeDurations.keys)
        id: previewDurations[id] ?? beforeDurations[id]!,
    };
    final afterGaps = {
      for (final id in beforeGaps.keys) id: previewGaps[id] ?? beforeGaps[id]!,
    };
    final changed =
        afterDurations.entries.any(
          (entry) => beforeDurations[entry.key] != entry.value,
        ) ||
        afterGaps.entries.any((entry) => beforeGaps[entry.key] != entry.value);
    if (!changed) {
      return;
    }

    // Fade durability: re-anchor each resized cut's canonical fade to its
    // new duration. cutFadeLengths returns (0, 0) for unkeyed AND for
    // hand-keyed (non-canonical) lanes — both stay untouched.
    final beforeTransforms = <CutId, TransformTrack>{};
    final afterTransforms = <CutId, TransformTrack>{};
    for (final entry in afterDurations.entries) {
      if (entry.value == beforeDurations[entry.key]) {
        continue;
      }
      final cut = cutById(entry.key);
      if (cut == null) {
        continue;
      }
      final lengths = cutFadeLengths(cut);
      if (lengths.fadeInFrames == 0 && lengths.fadeOutFrames == 0) {
        continue;
      }
      final rebuilt = cutTransformWithFade(
        cut.copyWith(duration: entry.value),
        fadeInFrames: lengths.fadeInFrames,
        fadeOutFrames: lengths.fadeOutFrames,
      );
      if (rebuilt == cut.transformTrack) {
        continue;
      }
      beforeTransforms[entry.key] = cut.transformTrack;
      afterTransforms[entry.key] = rebuilt;
    }

    _cutCommandCoordinator.commitCutDurationDrag(
      beforeDurations: beforeDurations,
      afterDurations: afterDurations,
      beforeGaps: beforeGaps,
      afterGaps: afterGaps,
      beforeTransforms: beforeTransforms,
      afterTransforms: afterTransforms,
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Drops an in-flight trim preview without touching history (the
  /// repository was never written during the drag).
  void cancelCutEdgeDrag() {
    _cutTrimBeforeDurations = null;
    _cutTrimBeforeGaps = null;
    _cutTrimCutId = null;
    _cutTrimNextCutId = null;
    _cutTrimEdge = null;
    _cutTrimOrder = null;
    _cutTrimIndex = null;
    dragPreview.value = null;
  }

  // --- Storyboard cut-block MOVE drags (R10-④) ----------------------------

  List<CutId>? _cutMoveOrder;
  Map<CutId, int>? _cutMoveBeforeGaps;
  int? _cutMoveIndex;

  /// Starts a whole-block move drag on [cutId]: the cut SLIDES along the
  /// frame axis by adjusting gaps, and pushes neighbors edge-style on
  /// contact — rightward pushes the followers (their gap absorbs first),
  /// leftward pushes the predecessors (each one's own gap absorbs before
  /// the wave reaches the next), clamped when the chain hits frame 0.
  bool beginCutMoveDrag(CutId cutId) {
    final project = _repository.requireProject();
    for (final track in project.tracks) {
      final index = track.cuts.indexWhere((cut) => cut.id == cutId);
      if (index < 0) {
        continue;
      }
      _cutMoveOrder = [for (final cut in track.cuts) cut.id];
      _cutMoveBeforeGaps = {
        for (final cut in track.cuts) cut.id: cut.leadingGapFrames,
      };
      _cutMoveIndex = index;
      return true;
    }
    return false;
  }

  /// Applies the move's cumulative frame delta as a live preview on
  /// [dragPreview] (the repository is NOT touched).
  void updateCutMoveDrag(int cumulativeDelta) {
    final order = _cutMoveOrder;
    final beforeGaps = _cutMoveBeforeGaps;
    final index = _cutMoveIndex;
    if (order == null || beforeGaps == null || index == null) {
      return;
    }
    final gaps = _cutMoveGaps(
      order: order,
      beforeGaps: beforeGaps,
      index: index,
      delta: cumulativeDelta,
    );
    final changed = gaps.entries.any(
      (entry) => beforeGaps[entry.key] != entry.value,
    );
    dragPreview.value = changed
        ? CutTrimDragPreview(previewDurations: const {}, previewGaps: gaps)
        : null;
  }

  /// The previewed gap map for a move by [delta] (pure — shared by update
  /// and tests). Rightward: the moved cut's gap grows, the follower's gap
  /// absorbs (followers hold still) until spent, then the rest pushes.
  /// Leftward: the moved cut's own gap absorbs first, then each
  /// predecessor's in turn (pushing them left), clamped at the chain's
  /// total slack; the follower's gap grows by the applied movement so
  /// everything after holds still.
  static Map<CutId, int> _cutMoveGaps({
    required List<CutId> order,
    required Map<CutId, int> beforeGaps,
    required int index,
    required int delta,
  }) {
    final gaps = <CutId, int>{};
    if (delta > 0) {
      gaps[order[index]] = beforeGaps[order[index]]! + delta;
      if (index + 1 < order.length) {
        final nextId = order[index + 1];
        gaps[nextId] = math.max(0, beforeGaps[nextId]! - delta);
      }
    } else if (delta < 0) {
      var remaining = -delta;
      for (var i = index; i >= 0 && remaining > 0; i -= 1) {
        final id = order[i];
        final take = math.min(remaining, beforeGaps[id]!);
        if (take > 0) {
          gaps[id] = beforeGaps[id]! - take;
          remaining -= take;
        }
      }
      final applied = (-delta) - remaining;
      if (index + 1 < order.length && applied > 0) {
        final nextId = order[index + 1];
        gaps[nextId] = beforeGaps[nextId]! + applied;
      }
    }
    return gaps;
  }

  /// Commits the move as a single undo step (no-op when nothing changed).
  /// Durations are untouched, so no fade re-anchor is needed.
  void endCutMoveDrag() {
    final beforeGaps = _cutMoveBeforeGaps;
    final preview = dragPreview.value;
    _cutMoveOrder = null;
    _cutMoveBeforeGaps = null;
    _cutMoveIndex = null;
    dragPreview.value = null;
    if (beforeGaps == null) {
      return;
    }
    final previewGaps = preview is CutTrimDragPreview
        ? preview.previewGaps
        : const <CutId, int>{};
    final afterGaps = {
      for (final id in beforeGaps.keys) id: previewGaps[id] ?? beforeGaps[id]!,
    };
    final changed = afterGaps.entries.any(
      (entry) => beforeGaps[entry.key] != entry.value,
    );
    if (!changed) {
      return;
    }
    _cutCommandCoordinator.commitCutDurationDrag(
      beforeDurations: const {},
      afterDurations: const {},
      beforeGaps: beforeGaps,
      afterGaps: afterGaps,
      beforeTransforms: const {},
      afterTransforms: const {},
    );
    _refreshAfterCutCommand();
    notifyListeners();
  }

  /// Drops an in-flight move preview without touching history.
  void cancelCutMoveDrag() {
    _cutMoveOrder = null;
    _cutMoveBeforeGaps = null;
    _cutMoveIndex = null;
    dragPreview.value = null;
  }

  /// Drops an in-flight drag preview without touching history (the
  /// repository was never written during the drag).
  void cancelExposureEdgeDrag() {
    _edgeDragBefore = null;
    _edgeDragEdge = null;
    _edgeDragBlockStart = null;
    _edgeDragAfter = null;
    _edgeDragWindow = null;
    dragPreview.value = null;
  }

  // --- Whole-block move drags (R10-④b) --------------------------------------
  //
  // Grabbing a drawing block's BODY moves the block whole: along the frame
  // axis (slide) and across drawing layers (the cel travels, its brush
  // drawings re-keyed to the new layer). Landing requires empty space —
  // a block move never retimes other blocks. Same channel discipline as
  // the edge drags: repo untouched until release, one undo per drag.

  Layer? _blockMoveSourceBefore;
  int? _blockMoveBlockStart;
  DrawingBlockMovePlan? _blockMovePlan;

  bool get isBlockMoveDragActive => _blockMoveSourceBefore != null;

  /// Whether [layerId] can take part in a block move (source or target):
  /// a plain drawing-section layer. Track-SE rows live on the global axis
  /// with audio attached and attach rows own no timing — both stand down.
  bool _blockMoveEligible(LayerId layerId) {
    if (_isAttachedLayerId(layerId) || isTrackSeLayerId(layerId)) {
      return false;
    }
    final layer = _layerById(layerId);
    return layer != null &&
        layerKindHoldsDrawings(layer.kind) &&
        layer.kind != LayerKind.se;
  }

  // --- Frame RANGE selection (UI-R8, TVP-style) ----------------------------

  /// The selected frame range — ONE layer's [start,end) span snapped to
  /// whole exposure blocks. Value-only view state (drag moves never fire a
  /// session notify); cleared on layer/cut switches and plain cell taps.
  final ValueNotifier<TimelineFrameRangeSelection?> frameRangeSelection =
      ValueNotifier<TimelineFrameRangeSelection?>(null);

  /// A range-select drag step: [anchorIndex] is where the drag started,
  /// [headIndex] where the pointer is now (both cut-local cell indices).
  /// Rows that cannot range-edit (attach/SE/track rows) stay unselectable.
  void updateFrameRangeSelectionDrag({
    required LayerId layerId,
    required int anchorIndex,
    required int headIndex,
  }) {
    if (!_blockMoveEligible(layerId)) {
      return;
    }
    final layer = _layerById(layerId);
    if (layer == null) {
      return;
    }
    frameRangeSelection.value = snapFrameRangeToBlocks(
      layer: layer,
      anchorIndex: anchorIndex,
      headIndex: headIndex,
    );
  }

  void clearFrameRangeSelection() {
    if (frameRangeSelection.value != null) {
      frameRangeSelection.value = null;
    }
  }

  /// Starts a whole-block move on the block starting at [blockStartIndex];
  /// returns false when there is no such block or the row stands down.
  bool beginDrawingBlockMoveDrag({
    required LayerId layerId,
    required int blockStartIndex,
  }) {
    if (!_blockMoveEligible(layerId)) {
      return false;
    }
    final layer = _layerById(layerId);
    final entry = layer?.timeline[blockStartIndex];
    // Ghost repeat instances are DERIVED — their timing is the region's,
    // not draggable (UI-R8).
    if (layer == null || entry == null || !entry.isDrawing || entry.ghost) {
      return false;
    }
    _blockMoveSourceBefore = layer;
    _blockMoveBlockStart = blockStartIndex;
    return true;
  }

  /// Applies the drag's cumulative deltas as a live preview on
  /// [dragPreview] (repository untouched). [targetLayerId] is the layer row
  /// currently under the pointer (null or the source id = plain slide).
  /// Blocks in the way are pushed in the direction of travel (R12-②) and
  /// ride the preview live; the rare still-illegal landing (mark collision,
  /// ineligible row, linked cel) clears the preview — the block shows at
  /// its committed spot until the pointer reaches a legal one.
  void updateDrawingBlockMoveDrag({
    required int frameDelta,
    LayerId? targetLayerId,
  }) {
    final source = _blockMoveSourceBefore;
    final blockStart = _blockMoveBlockStart;
    if (source == null || blockStart == null) {
      return;
    }
    Layer? target = source;
    if (targetLayerId != null && targetLayerId != source.id) {
      target = _blockMoveEligible(targetLayerId)
          ? _layerById(targetLayerId)
          : null;
    }
    final plan = target == null
        ? null
        : planDrawingBlockMove(
            source: source,
            target: target,
            blockStartIndex: blockStart,
            frameDelta: frameDelta,
          );
    _blockMovePlan = plan;
    // Ghosts follow the moved run LIVE (UI-R8 rederive on the preview).
    dragPreview.value = plan == null
        ? null
        : BlockMoveDragPreview(
            previewLayers: {
              plan.sourceAfter.id: rederiveRepeatRegions(plan.sourceAfter),
              if (plan.targetAfter != null)
                plan.targetAfter!.id: rederiveRepeatRegions(plan.targetAfter!),
            },
          );
  }

  /// Commits the move as a single undo step (no-op when the drag ends on
  /// an illegal or unchanged landing). Cross-layer moves compose the two
  /// layer updates with the brush-store rekey so undo restores everything.
  void endDrawingBlockMoveDrag() {
    final source = _blockMoveSourceBefore;
    final plan = _blockMovePlan;
    _blockMoveSourceBefore = null;
    _blockMoveBlockStart = null;
    _blockMovePlan = null;
    dragPreview.value = null;
    if (source == null || plan == null) {
      return;
    }
    final commands = <Command>[
      UpdateLayerTimelineCommand(
        repository: _repository,
        before: source,
        after: rederiveRepeatRegions(plan.sourceAfter),
      ),
      if (plan.targetBefore != null)
        UpdateLayerTimelineCommand(
          repository: _repository,
          before: plan.targetBefore!,
          after: rederiveRepeatRegions(plan.targetAfter!),
        ),
    ];
    if (plan.isCrossLayer && plan.movedFrameIds.isNotEmpty) {
      final cut = requireActiveCut;
      commands.add(
        RekeyBrushFramesCommand(
          store: brushFrameStore,
          pairs: [
            for (final frameId in plan.movedFrameIds)
              (
                brushFrameKeyForCut(cut, source.id, frameId),
                brushFrameKeyForCut(cut, plan.targetAfter!.id, frameId),
              ),
          ],
        ),
      );
    }
    _historyManager.execute(
      commands.length == 1
          ? commands.single
          : CompositeCommand(
              description: 'Move drawing block',
              commands: commands,
            ),
    );
    // The selection follows the block onto its new layer (R12-④): the
    // user grabbed THAT drawing — keep working on it where it landed.
    if (plan.isCrossLayer) {
      _layerController.selectLayer(plan.targetAfter!.id);
    }
    _warmActiveCut();
    notifyListeners();
  }

  /// Drops an in-flight move preview without touching history.
  void cancelDrawingBlockMoveDrag() {
    _blockMoveSourceBefore = null;
    _blockMoveBlockStart = null;
    _blockMovePlan = null;
    dragPreview.value = null;
  }

  // --- Frame RANGE move drag (UI-R8: drag the selected range) --------------

  Layer? _rangeMoveSourceBefore;
  TimelineFrameRangeSelection? _rangeMoveSelectionBefore;
  int? _rangeMoveGroupStart;
  DrawingBlockMovePlan? _rangeMovePlan;

  /// Starts moving the CURRENT frame-range selection; returns false when
  /// there is none (or its row stands down).
  bool beginFrameRangeMoveDrag() {
    final selection = frameRangeSelection.value;
    if (selection == null || !_blockMoveEligible(selection.layerId)) {
      return false;
    }
    final layer = _layerById(selection.layerId);
    if (layer == null) {
      return false;
    }
    int? groupStart;
    for (final block in drawingBlocks(layer.timeline)) {
      if (block.entry.ghost) {
        continue;
      }
      if (block.startIndex >= selection.startIndex &&
          block.endIndexExclusive <= selection.endIndexExclusive) {
        groupStart = block.startIndex;
        break;
      }
    }
    if (groupStart == null) {
      return false; // Nothing but empty cells selected — nothing to move.
    }
    _rangeMoveSourceBefore = layer;
    _rangeMoveSelectionBefore = selection;
    _rangeMoveGroupStart = groupStart;
    return true;
  }

  /// A range-move drag step: live preview on [dragPreview] (repository
  /// untouched), the selection outline riding the previewed landing.
  void updateFrameRangeMoveDrag({
    required int frameDelta,
    LayerId? targetLayerId,
  }) {
    final source = _rangeMoveSourceBefore;
    final selection = _rangeMoveSelectionBefore;
    final groupStart = _rangeMoveGroupStart;
    if (source == null || selection == null || groupStart == null) {
      return;
    }
    Layer? target = source;
    if (targetLayerId != null && targetLayerId != source.id) {
      target = _blockMoveEligible(targetLayerId)
          ? _layerById(targetLayerId)
          : null;
    }
    final plan = target == null
        ? null
        : planDrawingRangeMove(
            source: source,
            target: target,
            rangeStartIndex: selection.startIndex,
            rangeEndIndexExclusive: selection.endIndexExclusive,
            frameDelta: frameDelta,
          );
    _rangeMovePlan = plan;
    dragPreview.value = plan == null
        ? null
        : BlockMoveDragPreview(
            previewLayers: {
              plan.sourceAfter.id: rederiveRepeatRegions(plan.sourceAfter),
              if (plan.targetAfter != null)
                plan.targetAfter!.id: rederiveRepeatRegions(plan.targetAfter!),
            },
          );
    // The selection outline follows the previewed landing live.
    if (plan != null) {
      final landedLayerId = plan.isCrossLayer
          ? plan.targetAfter!.id
          : source.id;
      final startShift = plan.destinationStartIndex - groupStart;
      final newStart = selection.startIndex + startShift;
      if (newStart >= 0) {
        frameRangeSelection.value = TimelineFrameRangeSelection(
          layerId: landedLayerId,
          startIndex: newStart,
          endIndexExclusive: selection.endIndexExclusive + startShift,
        );
      }
    } else {
      frameRangeSelection.value = selection;
    }
  }

  /// Commits the range move as ONE undo step (layer updates + the brush
  /// re-key on cross-layer carries), mirroring the block-move commit.
  void endFrameRangeMoveDrag() {
    final source = _rangeMoveSourceBefore;
    final selection = _rangeMoveSelectionBefore;
    final plan = _rangeMovePlan;
    final landedSelection = frameRangeSelection.value;
    _rangeMoveSourceBefore = null;
    _rangeMoveSelectionBefore = null;
    _rangeMoveGroupStart = null;
    _rangeMovePlan = null;
    dragPreview.value = null;
    if (source == null || selection == null) {
      return;
    }
    if (plan == null) {
      frameRangeSelection.value = selection;
      return;
    }
    final commands = <Command>[
      UpdateLayerTimelineCommand(
        repository: _repository,
        before: source,
        after: rederiveRepeatRegions(plan.sourceAfter),
      ),
      if (plan.targetBefore != null)
        UpdateLayerTimelineCommand(
          repository: _repository,
          before: plan.targetBefore!,
          after: rederiveRepeatRegions(plan.targetAfter!),
        ),
    ];
    if (plan.isCrossLayer && plan.movedFrameIds.isNotEmpty) {
      final cut = requireActiveCut;
      commands.add(
        RekeyBrushFramesCommand(
          store: brushFrameStore,
          pairs: [
            for (final frameId in plan.movedFrameIds)
              (
                brushFrameKeyForCut(cut, source.id, frameId),
                brushFrameKeyForCut(cut, plan.targetAfter!.id, frameId),
              ),
          ],
        ),
      );
    }
    _historyManager.execute(
      commands.length == 1
          ? commands.single
          : CompositeCommand(
              description: 'Move frame range',
              commands: commands,
            ),
    );
    // The selection stays on the moved frames where they landed.
    frameRangeSelection.value = landedSelection;
    if (plan.isCrossLayer) {
      _layerController.selectLayer(plan.targetAfter!.id);
    }
    _warmActiveCut();
    notifyListeners();
  }

  /// Drops an in-flight range-move preview, restoring the selection.
  void cancelFrameRangeMoveDrag() {
    final selection = _rangeMoveSelectionBefore;
    _rangeMoveSourceBefore = null;
    _rangeMoveSelectionBefore = null;
    _rangeMoveGroupStart = null;
    _rangeMovePlan = null;
    dragPreview.value = null;
    if (selection != null) {
      frameRangeSelection.value = selection;
    }
  }

  // --- Run-edge NEW FRAMES drag (UI-R8 [+] handle) --------------------------

  Layer? _addFramesBefore;
  int? _addFramesBlockStart;
  bool _addFramesAtEnd = true;
  Layer? _addFramesAfter;
  final List<FrameId> _addFramesReservedIds = [];

  /// Reserves project-unique frame ids for the drag, deterministically:
  /// the same ordinal always resolves the same id, so every preview step
  /// and the commit agree.
  FrameId _reservedNewFrameId(int ordinal) {
    while (_addFramesReservedIds.length <= ordinal) {
      final used = <String>{
        for (final id in _addFramesReservedIds) id.value,
      };
      for (final track in _repository.requireProject().tracks) {
        for (final layer in track.seLayers) {
          for (final frame in layer.frames) {
            used.add(frame.id.value);
          }
        }
        for (final cut in track.cuts) {
          for (final layer in cut.layers) {
            for (final frame in layer.frames) {
              used.add(frame.id.value);
            }
          }
        }
      }
      var candidate = 1;
      while (used.contains('frame-$candidate')) {
        candidate += 1;
      }
      _addFramesReservedIds.add(FrameId('frame-$candidate'));
    }
    return _addFramesReservedIds[ordinal];
  }

  /// Starts a "+ add frames" drag at the run edge (UI-R8): [atEnd] picks
  /// the side. Returns false when the row stands down or there is no run.
  bool beginRunFramesAddDrag({
    required LayerId layerId,
    required int blockStartIndex,
    required bool atEnd,
  }) {
    if (!_blockMoveEligible(layerId)) {
      return false;
    }
    final layer = _layerById(layerId);
    if (layer == null || gluedRunAt(layer, blockStartIndex) == null) {
      return false;
    }
    _addFramesBefore = layer;
    _addFramesBlockStart = blockStartIndex;
    _addFramesAtEnd = atEnd;
    _addFramesAfter = null;
    _addFramesReservedIds.clear();
    return true;
  }

  /// Live preview: [count] new one-frame drawings at the run edge (0 shows
  /// the committed state).
  void updateRunFramesAddDrag(int count) {
    final before = _addFramesBefore;
    final blockStart = _addFramesBlockStart;
    if (before == null || blockStart == null) {
      return;
    }
    if (count < 1) {
      _addFramesAfter = null;
      dragPreview.value = null;
      return;
    }
    final result = layerWithNewFramesAtRunEdge(
      before,
      blockStartIndex: blockStart,
      atEnd: _addFramesAtEnd,
      count: count,
      frameIdAt: _reservedNewFrameId,
    );
    _addFramesAfter = result == null
        ? null
        : rederiveRepeatRegions(result.layer);
    dragPreview.value = _addFramesAfter == null
        ? null
        : ExposureEdgeDragPreview(previewLayer: _addFramesAfter!);
  }

  /// Commits the added frames as ONE undo step.
  void endRunFramesAddDrag() {
    final before = _addFramesBefore;
    final after = _addFramesAfter;
    _addFramesBefore = null;
    _addFramesBlockStart = null;
    _addFramesAfter = null;
    _addFramesReservedIds.clear();
    dragPreview.value = null;
    if (before == null || after == null || after == before) {
      return;
    }
    _timelineController.commitLayerTimelineDrag(before: before, after: after);
    _warmActiveCut();
    notifyListeners();
  }

  void cancelRunFramesAddDrag() {
    _addFramesBefore = null;
    _addFramesBlockStart = null;
    _addFramesAfter = null;
    _addFramesReservedIds.clear();
    dragPreview.value = null;
  }

  // --- REPEAT region drag (UI-R8 [↻] handle) --------------------------------

  Layer? _repeatDragBefore;
  String? _repeatDragRegionId;
  FrameId? _repeatDragAnchorFrameId;
  int _repeatDragSpanFrames = 1;
  Layer? _repeatDragAfter;

  /// Starts a repeat drag (UI-R8 [↻]): [regionId] resizes an existing
  /// region; otherwise a NEW region repeats the current selection (when it
  /// covers the block) or the glued run containing [blockStartIndex].
  bool beginRepeatRegionDrag({
    required LayerId layerId,
    required int blockStartIndex,
    String? regionId,
  }) {
    if (!_blockMoveEligible(layerId)) {
      return false;
    }
    final layer = _layerById(layerId);
    if (layer == null) {
      return false;
    }
    if (regionId != null) {
      for (final region in layer.repeatRegions) {
        if (region.id == regionId) {
          _repeatDragBefore = layer;
          _repeatDragRegionId = regionId;
          _repeatDragAnchorFrameId = region.anchorFrameId;
          _repeatDragSpanFrames = region.sourceSpanFrames;
          _repeatDragAfter = null;
          return true;
        }
      }
      return false;
    }
    // The repeat unit (user rule): the selection when it covers this
    // block, else the glued run.
    final selection = frameRangeSelection.value;
    int spanStart;
    int spanEndExclusive;
    if (selection != null &&
        selection.layerId == layerId &&
        selection.contains(blockStartIndex)) {
      spanStart = selection.startIndex;
      spanEndExclusive = selection.endIndexExclusive;
    } else {
      final run = gluedRunAt(layer, blockStartIndex);
      if (run == null) {
        return false;
      }
      spanStart = run.startIndex;
      spanEndExclusive = run.endIndexExclusive;
    }
    final anchorEntry = layer.timeline[spanStart];
    FrameId? anchorFrameId = anchorEntry != null && anchorEntry.isDrawing
        ? anchorEntry.frameId
        : null;
    if (anchorFrameId == null) {
      // A selection may start on empty cells; anchor on the first block.
      for (final entry in layer.timeline.entries) {
        if (entry.key >= spanStart &&
            entry.key < spanEndExclusive &&
            entry.value.isDrawing &&
            !entry.value.ghost) {
          anchorFrameId = entry.value.frameId;
          spanEndExclusive =
              spanEndExclusive - (entry.key - spanStart);
          spanStart = entry.key;
          break;
        }
      }
    }
    if (anchorFrameId == null) {
      return false;
    }
    var ordinal = 1;
    final usedIds = {for (final region in layer.repeatRegions) region.id};
    while (usedIds.contains('repeat-$ordinal')) {
      ordinal += 1;
    }
    _repeatDragBefore = layer;
    _repeatDragRegionId = 'repeat-$ordinal';
    _repeatDragAnchorFrameId = anchorFrameId;
    _repeatDragSpanFrames = spanEndExclusive - spanStart;
    _repeatDragAfter = null;
    return true;
  }

  /// Live preview: the region covers [frameCount] ghost frames (0 removes
  /// it).
  void updateRepeatRegionDrag(int frameCount) {
    final before = _repeatDragBefore;
    final regionId = _repeatDragRegionId;
    final anchor = _repeatDragAnchorFrameId;
    if (before == null || regionId == null || anchor == null) {
      return;
    }
    final regions = [
      for (final region in before.repeatRegions)
        if (region.id != regionId) region,
      if (frameCount > 0)
        TimelineRepeatRegion(
          id: regionId,
          anchorFrameId: anchor,
          sourceSpanFrames: _repeatDragSpanFrames,
          frameCount: frameCount,
        ),
    ];
    final after = rederiveRepeatRegions(
      before.copyWith(repeatRegions: regions),
    );
    _repeatDragAfter = after == before ? null : after;
    dragPreview.value = _repeatDragAfter == null
        ? null
        : ExposureEdgeDragPreview(previewLayer: _repeatDragAfter!);
  }

  /// Commits the region change as ONE undo step.
  void endRepeatRegionDrag() {
    final before = _repeatDragBefore;
    final after = _repeatDragAfter;
    _repeatDragBefore = null;
    _repeatDragRegionId = null;
    _repeatDragAnchorFrameId = null;
    _repeatDragAfter = null;
    dragPreview.value = null;
    if (before == null || after == null || after == before) {
      return;
    }
    _timelineController.commitLayerTimelineDrag(before: before, after: after);
    _warmActiveCut();
    notifyListeners();
  }

  void cancelRepeatRegionDrag() {
    _repeatDragBefore = null;
    _repeatDragRegionId = null;
    _repeatDragAnchorFrameId = null;
    _repeatDragAfter = null;
    dragPreview.value = null;
  }

  /// One-shot region write (tests + future numeric input): create/resize
  /// the repeat anchored at the run containing [anchorIndex].
  void setRepeatRegionFrames({
    required LayerId layerId,
    required int anchorIndex,
    required int frameCount,
  }) {
    if (!beginRepeatRegionDrag(
      layerId: layerId,
      blockStartIndex: anchorIndex,
    )) {
      return;
    }
    updateRepeatRegionDrag(frameCount);
    endRepeatRegionDrag();
  }

  Layer? _layerById(LayerId layerId) {
    for (final layer in layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }
    return null;
  }

  /// Whether [layerId] names one of the active cut's ATTACH rows (W5).
  bool _isAttachedLayerId(LayerId layerId) {
    final cut = activeCutOrNull;
    if (cut == null) {
      return false;
    }
    for (final layer in cut.layers) {
      if (layer.id == layerId) {
        return isAttachedLayer(layer);
      }
    }
    return false;
  }

  bool get canToggleMarkAtCurrentFrame {
    final layer = activeLayer;
    // Attach rows carry no cell marks (the base's sheet row does).
    if (layer == null ||
        !layerKindHoldsDrawings(layer.kind) ||
        isAttachedLayer(layer)) {
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
    // Attach rows: cel removal is out of v1 scope (delete the row or undo
    // the creation) — cells are display material here.
    if (layer == null || isAttachedLayer(layer)) {
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
        requireActiveCut.duration - _timelineController.currentFrameIndex;
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
    // R15-⑤: a live editing interaction REFUSES the seek outright — a
    // flip under an in-flight edit tore widgets down inside the build
    // phase (red screens) and could land the edit on the wrong cel.
    if (editingInteractionBusy) {
      return;
    }
    // A direct cut-local seek leaves any gap parking (R16-⑥); the global
    // seek re-parks AFTER this call when it lands in a gap.
    _gapGlobalFrame = null;
    labProbe('selectFrameIndex(sync)', () {
      _timelineController.selectFrameIndex(frameIndex);
      editingFrameCursor.value = frameIndex;
      // A seek is activity (R13-3): rapid frame flipping keeps pushing the
      // warm window, so composite warming never lands a full-canvas build
      // in the middle of a flip run.
      prerenderScheduler.notifyEditActivity();
      _warmActiveCut();
      frameSeekCommitted.value += 1;
    });
  }

  /// Pen-down → warm stand-down (R13-3): while a stroke is live the
  /// prerender warmer must not touch the UI/raster threads at all — the
  /// idle debounce alone resumed warming MID-stroke. Latched: unbalanced
  /// end calls (view resets without an active stroke) are no-ops.
  ///
  /// Exposed as a listenable (R13-4) so the canvas retarget scope can PIN
  /// an in-progress stroke to its cel: a committed seek that lands while
  /// the pen is down defers the canvas retarget until the stroke ends.
  final ValueNotifier<bool> brushInputActive = ValueNotifier<bool>(false);

  void setBrushInputActive(bool active) {
    if (active == brushInputActive.value) {
      return;
    }
    brushInputActive.value = active;
    if (active) {
      prerenderScheduler.beginInputHold();
    } else {
      prerenderScheduler.endInputHold();
    }
  }

  /// Selection-tool interactions (marquee/move/transform drags) — counted
  /// so overlapping holds nest (R15-⑤).
  final ValueNotifier<bool> selectionInteractionActive = ValueNotifier<bool>(
    false,
  );
  int _selectionInteractionHolds = 0;

  void beginSelectionInteraction() {
    _selectionInteractionHolds += 1;
    selectionInteractionActive.value = true;
    prerenderScheduler.beginInputHold();
  }

  void endSelectionInteraction() {
    if (_selectionInteractionHolds > 0) {
      _selectionInteractionHolds -= 1;
      prerenderScheduler.endInputHold();
    }
    selectionInteractionActive.value = _selectionInteractionHolds > 0;
  }

  /// R15-⑤: any live editing interaction (brush stroke, selection drag)
  /// blocks frame seeks, scrubs and cut switches entirely — the playhead
  /// moves when the pen lifts, never under it.
  bool get editingInteractionBusy =>
      brushInputActive.value || selectionInteractionActive.value;

  // --- Track-global frame axis (R15-①) -----------------------------------

  /// THE structural model of the active track's timeline: cuts occupy
  /// [start, end) global ranges and the frames between them are REAL
  /// addresses (a layer timeline's empty frames, at track scale). The
  /// session playhead, the storyboard and the timeline consume THIS ONE
  /// axis — change it and every panel changes together.
  TrackFrameAxis trackFrameAxis() {
    final layout = buildStoryboardTimelineLayout(repository.requireProject());
    for (final entry in layout) {
      if (entry.cutId == activeCutId) {
        return TrackFrameAxis(
          layout
              .where((candidate) => candidate.trackId == entry.trackId)
              .toList(growable: false),
        );
      }
    }
    return TrackFrameAxis(layout);
  }

  /// Set while the editing playhead is PARKED IN A GAP (R16-⑥, user
  /// semantics: a gap has NO cut — the canvas shows a paperless void).
  /// Stores the exact global frame, which the leading gap before the
  /// first cut cannot express as any cut-local index. Notifier-backed
  /// (UI-R7 #9): gap scrubs park PER MOVE now, and the storyboard
  /// playhead must follow even where the cut-local cursor cannot change
  /// (the leading gap pins local 0).
  final ValueNotifier<int?> _gapGlobalFrameNotifier = ValueNotifier<int?>(null);

  int? get _gapGlobalFrame => _gapGlobalFrameNotifier.value;
  set _gapGlobalFrame(int? value) => _gapGlobalFrameNotifier.value = value;

  /// Fires when the gap parking is set, moved or cleared — the storyboard
  /// playhead subscribes (per-move gap scrubs, UI-R7 #9).
  ValueListenable<int?> get gapParkingListenable => _gapGlobalFrameNotifier;

  /// Whether the editing playhead sits in a gap (no cut there).
  bool get editingPlayheadInGap =>
      _gapGlobalFrame != null || trackFrameAxis().isGap(editingGlobalFrame);

  /// The gap parking's exact global frame, or null when the playhead sits
  /// on a cut. Cheap field read — per-tick consumers (the storyboard
  /// playhead) use it without rebuilding the axis.
  int? get gapParkedGlobalFrame => _gapGlobalFrame;

  /// The editing playhead as a track-global frame. A gap parking returns
  /// its stored global; otherwise over-end positions clamp to the active
  /// CUT's last frame (UI-R9 #4 — the timeline's runway is a clipped view
  /// of the cut, so the global axis never shows it inside the trailing
  /// gap).
  int get editingGlobalFrame {
    final parked = _gapGlobalFrame;
    if (parked != null) {
      return parked;
    }
    final cutId = activeCutId;
    if (cutId == null) {
      // No cut and no parking: a degenerate state (empty project open).
      return currentFrameIndex;
    }
    return trackFrameAxis().clampedToCutGlobalOf(cutId, currentFrameIndex) ??
        currentFrameIndex;
  }

  /// Deselects the active cut for a GAP landing (UI-R9 #3): standing in a
  /// gap means NO cut is selected — the timeline/timesheet show their
  /// empty states and the canvas shows the void. QUIET: callers notify
  /// (they batch it with the parking + commit signals). False when no cut
  /// was selected to begin with.
  bool _deselectActiveCutForGap() {
    if (_editingSession.activeCutId == null) {
      return false;
    }
    // The visibility solo is cut-scoped: restore the eyes before leaving
    // (the selectCut contract).
    if (_layerVisibilitySoloEnabled) {
      _exitVisibilitySolo();
    }
    _editingSession.setActiveCutId(null);
    _copiedFrame = null;
    clearFrameRangeSelection();
    _rebuildActiveCutControllers();
    return true;
  }

  /// THE canonical seek: a global frame in. Inside a cut it selects
  /// cut + local frame; in a GAP it deselects the cut ENTIRELY (UI-R9 #3)
  /// and PARKS there — the stored global addresses the gap exactly,
  /// including the leading gap before the first cut, and the canvas shows
  /// the no-cut void.
  void selectGlobalFrame(int globalFrame) {
    if (editingInteractionBusy) {
      return;
    }
    final axis = trackFrameAxis();
    if (axis.isEmpty) {
      return;
    }
    final local = axis.localOf(globalFrame);
    if (local == null || axis.isGap(globalFrame)) {
      // A GAP (leading or mid-track): no cut there — park + deselect.
      _gapGlobalFrame = globalFrame;
      _deselectActiveCutForGap();
      frameSeekCommitted.value += 1;
      notifyListeners();
      return;
    }
    if (local.cutId != activeCutId) {
      selectCut(local.cutId);
    }
    selectFrameIndex(local.localFrame);
  }

  /// Global scrub: rides the cursor path inside the active cut's
  /// territory, falls back to the full seek when the drag crosses into
  /// another cut's. GAP moves ride the cursor path too and park PER MOVE
  /// (UI-R7 #9): the playhead follows the exact gap frame, the canvas
  /// shows the no-cut void DURING the drag, and no committed seek fires
  /// per move (the old full-seek-per-move made gap scrubs crawl and the
  /// release commit wiped the leading-gap parking entirely).
  void scrubGlobalFrame(int globalFrame) {
    if (editingInteractionBusy) {
      return;
    }
    final axis = trackFrameAxis();
    if (axis.isEmpty) {
      return;
    }
    final owner = axis.ownerOf(globalFrame);
    if (axis.isGap(globalFrame)) {
      // Gap moves ride the cursor path and park PER MOVE (UI-R7 #9) — no
      // committed seek and no cut switch mid-drag; the RELEASE commits
      // the no-cut state (commitFrameScrub, UI-R9 #3). The cursor holds
      // the runway local inside the active cut's own trailing gap and 0
      // elsewhere (display rides the parking either way).
      final local = owner != null && owner.cutId == activeCutId
          ? math.max(0, globalFrame - owner.startFrame)
          : 0;
      scrubFrameIndex(local);
      _gapGlobalFrame = globalFrame;
      return;
    }
    if (owner == null || owner.cutId != activeCutId) {
      selectGlobalFrame(globalFrame);
      return;
    }
    // Scrubbing back onto the cut un-parks.
    _gapGlobalFrame = null;
    scrubFrameIndex(math.max(0, globalFrame - owner.startFrame));
  }

  // --- Onion skin (P2: Callipeg peg model) -----------------------------------

  /// Session view state — a ValueNotifier so the canvas underlay and the
  /// onion panel subscribe without whole-session notifies.
  final ValueNotifier<OnionSkinSettings> onionSkinSettings =
      ValueNotifier<OnionSkinSettings>(const OnionSkinSettings());

  /// The `O` shortcut / toolbar toggle.
  void toggleOnionSkin() {
    onionSkinSettings.value = onionSkinSettings.value.copyWith(
      enabled: !onionSkinSettings.value.enabled,
    );
  }

  /// The ghost frames to composite under the ACTIVE layer at the playhead:
  /// the onion plan (unique drawings, peg opacities, side tints) as canvas
  /// stack requests. Empty while disabled, on brush-banned rows, or with
  /// no active layer.
  List<CanvasLayerImageRequest> onionSkinCanvasRequests() {
    final settings = onionSkinSettings.value;
    final layer = activeLayer;
    final cut = activeCutOrNull;
    if (!settings.enabled ||
        layer == null ||
        cut == null ||
        !layerKindAcceptsBrushInput(layer.kind)) {
      return const [];
    }
    return [
      for (final plan in planOnionSkin(
        layer: layer,
        frameIndex: _timelineController.currentFrameIndex,
        settings: settings,
      ))
        CanvasLayerImageRequest(
          frameKey: brushFrameKeyForCut(cut, layer.id, plan.frameId),
          opacity: plan.opacity,
          tint: plan.tint,
        ),
    ];
  }

  // --- Project persistence (P3: the .qap container) -------------------------

  static const QapFileService _qapFileService = QapFileService();

  String? _projectFilePath;

  /// The open project's file path; null until first saved/opened (Save
  /// falls back to Save As).
  String? get projectFilePath => _projectFilePath;

  bool _hasUnsavedChanges = false;

  /// Whether edits exist since the last save/open (autosave + title dots).
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  void _markProjectDirty() {
    _hasUnsavedChanges = true;
  }

  /// The autosave sidecar for the CURRENT state: next to the saved file,
  /// or in the app-data autosave folder while never saved.
  String get autosaveSidecarPath {
    final path = _projectFilePath;
    if (path != null) {
      return '$path.autosave';
    }
    final projectId = _repository.requireProject().id.value;
    return '${ProjectAutosaveService.defaultUnsavedAutosaveDirectory()}/'
        '$projectId.qap.autosave';
  }

  /// Writes the current state to [path] WITHOUT touching the dirty flag or
  /// the project path — the autosave service's snapshot writer.
  Future<void> writeAutosaveSnapshot(String path) {
    return _qapFileService.save(
      project: _repository.requireProject(),
      brushFrameStore: brushFrameStore,
      filePath: path,
    );
  }

  /// Saves the project + every drawn frame into ONE .qap file (atomic
  /// temp-then-rename write; media stays external with relative paths
  /// recorded for Drive portability). A successful save retires the
  /// autosave sidecar.
  Future<void> saveProjectToFile(String filePath) async {
    final previousSidecar = autosaveSidecarPath;
    await _qapFileService.save(
      project: _repository.requireProject(),
      brushFrameStore: brushFrameStore,
      filePath: filePath,
    );
    _projectFilePath = filePath;
    _hasUnsavedChanges = false;
    // Awaited: a still-in-flight delete could otherwise race a following
    // autosave tick and eat its fresh sidecar.
    await ProjectAutosaveService.deleteSidecar(previousSidecar);
    await ProjectAutosaveService.deleteSidecar('$filePath.autosave');
    notifyListeners();
  }

  /// Opens a .qap file, replacing the WHOLE session state: project,
  /// drawings, selection (first cut, frame 0) — and BOTH undo stacks
  /// (loaded state has no history; the load→draw→undo path is pinned by
  /// test). [recoverAs] opens autosave SIDECAR bytes while keeping the
  /// real file as the project path (the recovery flow).
  Future<void> openProjectFromFile(String filePath, {String? recoverAs}) async {
    final result = await _qapFileService.open(filePath: filePath);
    playback.stop();
    _repository.replaceProject(result.project);
    // R22-C: opens land every cel FILE-BACKED — pixels stay in the .qap
    // until a cel is first shown (near-zero RAM for 1500-cut projects).
    brushFrameStore.restoreFromFile(result.cels);
    _historyManager.clear();
    _copiedFrame = null;
    _layerClipboard = null;
    _editingSession.setActiveCutId(result.project.tracks.first.cuts.first.id);
    _rebuildActiveCutControllers();
    _projectFilePath = recoverAs ?? filePath;
    // A recovered session stays dirty: its content differs from the real
    // file until the user saves.
    _hasUnsavedChanges = recoverAs != null;
    _warmActiveCut();
    frameSeekCommitted.value += 1;
    notifyListeners();
  }

  // --- Frame flipping (P1 shortcuts) ----------------------------------------

  /// Steps the playhead one frame back (flipping `,`) — a committed seek,
  /// clamped at the cut start.
  void selectPreviousFrame() {
    final current = _timelineController.currentFrameIndex;
    if (current <= 0) {
      return;
    }
    selectFrameIndex(current - 1);
  }

  /// Steps the playhead one frame forward (flipping `.`), clamped at the
  /// cut's last frame.
  void selectNextFrame() {
    final cut = activeCutOrNull;
    if (cut == null) {
      return; // Gap state: no cut axis to flip along.
    }
    final last = math.max(0, cut.duration - 1);
    final current = _timelineController.currentFrameIndex;
    if (current >= last) {
      return;
    }
    selectFrameIndex(current + 1);
  }

  /// Jumps to the previous drawing block's START on the active layer
  /// (Ctrl+`,`): from mid-block that is the current block's start — the
  /// clip-navigation convention.
  void selectPreviousDrawing() {
    final layer = activeLayer;
    if (layer == null) {
      return;
    }
    final block = previousDrawingBlockBefore(
      layer.timeline,
      _timelineController.currentFrameIndex,
    );
    if (block != null) {
      selectFrameIndex(block.startIndex);
    }
  }

  /// Jumps to the next drawing block's start on the active layer
  /// (Ctrl+`.`).
  void selectNextDrawing() {
    final layer = activeLayer;
    if (layer == null) {
      return;
    }
    final block = nextDrawingBlockAfter(
      layer.timeline,
      _timelineController.currentFrameIndex,
    );
    if (block != null) {
      selectFrameIndex(block.startIndex);
    }
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
    // R15-⑤: scrubs are seeks too — refused under a live edit.
    if (editingInteractionBusy) {
      return;
    }
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
  /// A gap-parked release COMMITS the no-cut state (UI-R9 #3): the active
  /// cut deselects and the parking carries the exact position.
  void commitFrameScrub() {
    if (frameScrubActive.value) {
      frameScrubActive.value = false;
    }
    if (_gapGlobalFrame != null) {
      _deselectActiveCutForGap();
      frameSeekCommitted.value += 1;
      notifyListeners();
      return;
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
      // A camera row exists only with a cut on screen.
      final track = requireActiveCut.camera.track;
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
      return activeCutOrNull?.camera.keyframeAt(frameIndex) != null
          ? TimelineCellExposureState.drawingStart
          : TimelineCellExposureState.uncovered;
    }

    if (_timelineController.isDrawingStartForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.drawingStart;
    }

    final held = _timelineController.isHeldExposureForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    // Block-owned dots live on held cells only (offsets 1..length-1), so
    // markUncovered is never produced anymore — the enum value survives
    // solely for exhaustive switches over legacy-visual states.
    if (held &&
        _timelineController.hasMarkAt(layer: layer, frameIndex: frameIndex)) {
      return TimelineCellExposureState.markHeld;
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
        // Dots are block-owned: an empty cell offers no Mark (author an
        // unnamed frame first).
        return canPaste ? 'X: Paste / New Frame' : 'X: New Frame';
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
    final cut = activeCutOrNull;
    final layer = _layerController.activeLayer;
    final frame = selectedFrame;
    return CanvasEditorSelectionLabels(
      projectLabel: project.name,
      // Gap state: no cut selected — the label says so.
      cutLabel: cut?.name ?? '—',
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
