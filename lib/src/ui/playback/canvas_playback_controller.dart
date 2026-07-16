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
    this.onStoppedInGap,
    this.onPlaylistWarmRequested,
  });

  final Project Function() resolveProject;

  /// Null = the session stands in a gap (no active cut, UI-R9 #3): an
  /// active-cut-scoped [play] resolves an empty playlist and no-ops.
  final CutId? Function() resolveActiveCutId;
  final TrackId Function() resolveActiveTrackId;
  final int Function() resolveFps;

  /// Fired on [stop] with the last position so the owner can sync the real
  /// playhead (and switch the active cut after a play-all run).
  final void Function(PlaybackPosition lastPosition)? onStopped;

  /// Fired on [stop] when the last frame was a playlist GAP (no position):
  /// the owner parks the editing playhead there with NO active cut
  /// (UI-R9 #3 — stopping in a gap matches the editing gap semantics).
  final void Function(int globalFrame)? onStoppedInGap;

  /// Fired on [play] so the prerender scheduler can warm the playlist;
  /// [startGlobalFrame] lets warming run playhead-forward (wrapping) so the
  /// frames about to play always warm first.
  final void Function(
    List<StoryboardTimelineLayoutEntry> playlist,
    PlaybackScope scope,
    int startGlobalFrame,
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

  final ValueNotifier<int?> _globalFrameIndexNotifier = ValueNotifier<int?>(
    null,
  );

  /// The playlist-global frame index, `null` while playback is inactive.
  ///
  /// Superset signal of [localFrameIndexListenable]: it also fires on
  /// cross-cut seeks that happen to land on the same local frame (the
  /// storyboard playhead follows this one).
  ValueListenable<int?> get globalFrameIndexListenable =>
      _globalFrameIndexNotifier;

  final ValueNotifier<bool> _isActiveNotifier = ValueNotifier<bool>(false);

  /// Fires only when playback mode is entered/left — the canvas area swaps
  /// its content on this instead of listening to every tick (subscribing the
  /// whole canvas subtree to ticks rebuilt it at fps and caused real frame
  /// drops).
  ValueListenable<bool> get isActiveListenable => _isActiveNotifier;

  List<StoryboardTimelineLayoutEntry>? _playlist;
  PlaybackScope _scope = PlaybackScope.activeCut;
  PlaybackLoopMode _loopMode = PlaybackLoopMode.loop;
  bool _isPlaying = false;
  int _baseGlobalFrame = 0;
  int _currentGlobalFrame = 0;
  int _droppedFrames = 0;
  int? _lastRawFrame;
  int _lastLap = 0;

  /// Frames skipped to keep real time during the CURRENT loop pass
  /// (DaVinci-style dropped frame indicator); resets on every wrap-around
  /// and on play/seek.
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
    _resetDropAccounting();
    _currentGlobalFrame = (startGlobalFrame ?? 0).clamp(
      0,
      playlistTotalFrames(playlist) - 1,
    );
    onPlaylistWarmRequested?.call(playlist, scope, _currentGlobalFrame);
    _isPlaying = true;
    _startTicker();
    _syncFrameNotifiers();
    _isActiveNotifier.value = true;
    notifyListeners();
  }

  /// Jumps playback to a frame of the currently playing cut (ruler scrubs
  /// during playback); keeps playing/paused state.
  void seekToLocalFrame(int localFrameIndex) {
    final playlist = _playlist;
    final current = position;
    if (playlist == null || current == null) {
      return;
    }
    for (final entry in playlist) {
      if (current.globalFrameIndex >= entry.startFrame &&
          current.globalFrameIndex < entry.endFrame) {
        final clamped = localFrameIndex.clamp(0, entry.duration - 1);
        seekToGlobalFrame(entry.startFrame + clamped);
        return;
      }
    }
  }

  /// Jumps playback to a playlist-global frame (storyboard ruler seeks can
  /// cross cut boundaries); keeps playing/paused state.
  void seekToGlobalFrame(int globalFrameIndex) {
    final playlist = _playlist;
    if (playlist == null) {
      return;
    }
    final total = playlistTotalFrames(playlist);
    if (total == 0) {
      return;
    }
    _currentGlobalFrame = globalFrameIndex.clamp(0, total - 1);
    _resetDropAccounting();
    if (_isPlaying) {
      // Restart the ticker so its elapsed epoch rebases on the new frame.
      _startTicker();
    }
    _syncFrameNotifiers();
    notifyListeners();
  }

  void _resetDropAccounting() {
    _droppedFrames = 0;
    _lastRawFrame = null;
    _lastLap = 0;
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
    final lastGlobal = _playlist == null ? null : _currentGlobalFrame;
    _stopTicker();
    _playlist = null;
    _isPlaying = false;
    _syncFrameNotifiers();
    _isActiveNotifier.value = false;
    notifyListeners();
    if (lastPosition != null) {
      onStopped?.call(lastPosition);
    } else if (lastGlobal != null) {
      onStoppedInGap?.call(lastGlobal);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _localFrameIndex.dispose();
    _globalFrameIndexNotifier.dispose();
    _isActiveNotifier.dispose();
    super.dispose();
  }

  void _syncFrameNotifiers() {
    _localFrameIndex.value = position?.localFrameIndex;
    _globalFrameIndexNotifier.value = _playlist == null
        ? null
        : _currentGlobalFrame;
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
    // more than one frame between ticks means rendering fell behind. The
    // counter reports the CURRENT loop pass only, resetting on wrap.
    final lap = frame ~/ math.max(1, total);
    if (lap != _lastLap) {
      _droppedFrames = 0;
      _lastRawFrame = null;
      _lastLap = lap;
    }
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
    _syncFrameNotifiers();
    notifyListeners();
  }
}
