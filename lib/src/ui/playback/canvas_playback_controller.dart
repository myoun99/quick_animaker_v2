import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../models/cut_id.dart';
import '../../models/project.dart';
import '../../models/track_id.dart';
import '../../services/playback/playback_frame_mapping.dart';
import '../storyboard_timeline_layout.dart';

/// What plays: the active cut (timeline context) or every cut of the active
/// track in sequence (storyboard context).
enum PlaybackScope { activeCut, allCuts }

enum PlaybackLoopMode { loop, once }

/// Real-time canvas playback state machine.
///
/// Frame indexes derive from the ticker's wall-clock elapsed time, so when
/// rendering falls behind, frames are skipped rather than time stretched
/// (Premiere/AE behavior). Notifies only when the resolved frame actually
/// changes; the heavyweight session playhead syncs once via [onStopped].
class CanvasPlaybackController extends ChangeNotifier {
  CanvasPlaybackController({
    required this.resolveProject,
    required this.resolveActiveCutId,
    required this.resolveActiveTrackId,
    required this.resolveFps,
    this.onStopped,
    this.onPlaylistWarmRequested,
  });

  final Project Function() resolveProject;
  final CutId Function() resolveActiveCutId;
  final TrackId Function() resolveActiveTrackId;
  final int Function() resolveFps;

  /// Fired on [stop] with the last position so the owner can sync the real
  /// playhead (and switch the active cut after a play-all run).
  final void Function(PlaybackPosition lastPosition)? onStopped;

  /// Fired on [play] so the prerender scheduler can warm the playlist.
  final void Function(
    List<StoryboardTimelineLayoutEntry> playlist,
    PlaybackScope scope,
  )?
  onPlaylistWarmRequested;

  TickerProvider? _vsync;
  Ticker? _ticker;

  final ValueNotifier<int?> _localFrameIndex = ValueNotifier<int?>(null);

  /// The playing cut's local frame index, `null` while playback is inactive.
  ///
  /// Playback-only signal for the timeline playhead: subscribing here lets
  /// the playhead follow every tick WITHOUT rebuilding the whole editor
  /// (never route ticks through the session's notifyListeners).
  ValueListenable<int?> get localFrameIndexListenable => _localFrameIndex;

  List<StoryboardTimelineLayoutEntry>? _playlist;
  PlaybackScope _scope = PlaybackScope.activeCut;
  PlaybackLoopMode _loopMode = PlaybackLoopMode.loop;
  bool _isPlaying = false;
  int _baseGlobalFrame = 0;
  int _currentGlobalFrame = 0;
  int _droppedFrames = 0;
  int? _lastRawFrame;

  /// Frames skipped to keep real time since [play] (DaVinci-style dropped
  /// frame indicator).
  int get droppedFrames => _droppedFrames;

  /// Playback mode is entered (playing or paused); the canvas shows the
  /// playback view while active.
  bool get isActive => _playlist != null;

  bool get isPlaying => _isPlaying;
  PlaybackScope get scope => _scope;

  PlaybackLoopMode get loopMode => _loopMode;
  set loopMode(PlaybackLoopMode mode) {
    if (_loopMode == mode) {
      return;
    }
    _loopMode = mode;
    notifyListeners();
  }

  List<StoryboardTimelineLayoutEntry> get playlist =>
      List.unmodifiable(_playlist ?? const []);

  PlaybackPosition? get position {
    final playlist = _playlist;
    if (playlist == null) {
      return null;
    }
    return resolvePlaybackPosition(
      playlist: playlist,
      globalFrameIndex: _currentGlobalFrame,
    );
  }

  /// The playback view provides vsync; transport controls can call [play]
  /// before or after attachment (ticking starts once both are ready).
  void attachTicker(TickerProvider vsync) {
    _vsync = vsync;
    if (_isPlaying && _ticker == null) {
      _startTicker();
    }
  }

  void detachTicker() {
    _ticker?.dispose();
    _ticker = null;
    _vsync = null;
  }

  void play({required PlaybackScope scope, int? startGlobalFrame}) {
    final playlist = _buildPlaylist(scope);
    if (playlistTotalFrames(playlist) == 0) {
      return;
    }
    _scope = scope;
    _playlist = playlist;
    _droppedFrames = 0;
    _lastRawFrame = null;
    _currentGlobalFrame = (startGlobalFrame ?? 0).clamp(
      0,
      playlistTotalFrames(playlist) - 1,
    );
    onPlaylistWarmRequested?.call(playlist, scope);
    _isPlaying = true;
    _startTicker();
    _localFrameIndex.value = position?.localFrameIndex;
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) {
      return;
    }
    _stopTicker();
    _isPlaying = false;
    notifyListeners();
  }

  void resume() {
    if (!isActive || _isPlaying) {
      return;
    }
    _isPlaying = true;
    _startTicker();
    notifyListeners();
  }

  void stop() {
    if (!isActive) {
      return;
    }
    final lastPosition = position;
    _stopTicker();
    _playlist = null;
    _isPlaying = false;
    _localFrameIndex.value = null;
    notifyListeners();
    if (lastPosition != null) {
      onStopped?.call(lastPosition);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _localFrameIndex.dispose();
    super.dispose();
  }

  List<StoryboardTimelineLayoutEntry> _buildPlaylist(PlaybackScope scope) {
    switch (scope) {
      case PlaybackScope.activeCut:
        final activeCutId = resolveActiveCutId();
        for (final entry in buildStoryboardTimelineLayout(resolveProject())) {
          if (entry.cutId == activeCutId) {
            final duration = math.max(1, entry.cut.duration);
            return [
              StoryboardTimelineLayoutEntry(
                trackId: entry.trackId,
                cutId: entry.cutId,
                trackIndex: entry.trackIndex,
                cutIndex: entry.cutIndex,
                startFrame: 0,
                endFrame: duration,
                duration: duration,
                cut: entry.cut,
              ),
            ];
          }
        }
        return const [];
      case PlaybackScope.allCuts:
        final trackId = resolveActiveTrackId();
        return buildStoryboardTimelineLayout(
          resolveProject(),
        ).where((entry) => entry.trackId == trackId).toList();
    }
  }

  void _startTicker() {
    final vsync = _vsync;
    if (vsync == null) {
      return;
    }
    _ticker?.dispose();
    _baseGlobalFrame = _currentGlobalFrame;
    _ticker = vsync.createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    final playlist = _playlist;
    if (playlist == null) {
      return;
    }
    final total = playlistTotalFrames(playlist);
    var frame = _baseGlobalFrame + elapsedToGlobalFrame(elapsed, resolveFps());
    // Dropped-frame accounting on the raw (pre-wrap) frame: any advance of
    // more than one frame between ticks means rendering fell behind.
    final lastRawFrame = _lastRawFrame;
    if (lastRawFrame != null && frame > lastRawFrame + 1) {
      _droppedFrames += frame - lastRawFrame - 1;
    }
    _lastRawFrame = frame;
    if (frame >= total) {
      if (_loopMode == PlaybackLoopMode.loop) {
        frame %= total;
      } else {
        _setFrame(total - 1);
        stop();
        return;
      }
    }
    _setFrame(frame);
  }

  void _setFrame(int frame) {
    if (frame == _currentGlobalFrame) {
      return;
    }
    _currentGlobalFrame = frame;
    _localFrameIndex.value = position?.localFrameIndex;
    notifyListeners();
  }
}
