import 'dart:async';
import 'dart:math' as math;

import '../../models/layer_kind.dart';
import '../storyboard_timeline_layout.dart';
import 'canvas_playback_controller.dart';

/// One playing audio clip. The production implementation wraps an
/// `audioplayers` player; tests inject fakes (plugins are unavailable under
/// FLUTTER_TEST). Calls are fire-and-forget from the sync's point of view —
/// audio must never block the frame ticker.
abstract class AudioClipPlayer {
  Future<void> play(String filePath, {required Duration position});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

typedef AudioClipPlayerFactory = AudioClipPlayer Function();

/// Keeps SE-layer audio clips in sync with canvas playback.
///
/// Playback derives frames from wall-clock elapsed time (frames drop, time
/// never stretches), so a clip started at the right offset stays in sync by
/// construction. This class therefore only mirrors the controller's
/// lifecycle:
///
/// - play / activation → start every clip overlapping the start frame at
///   position `(frame - clipStart) / fps`;
/// - forward ticking → start clips whose start frame was crossed, stop
///   clips past their end (clip length, clamped at the cut boundary — an SE
///   clip belongs to its cut, it never bleeds into the next one);
/// - pause / resume / stop → forwarded to every live player;
/// - backward jumps (loop wrap, seeks) and forward jumps larger than
///   [resyncThresholdFrames] → stop everything and restart what overlaps.
///   Smaller forward jumps are indistinguishable from dropped frames, where
///   the audio kept real time on the native thread and restarting it would
///   glitch — those keep playing untouched.
///
/// Clip lengths come from the waveform peaks ([durationSecondsFor]); clips
/// whose peaks are not extracted yet fall back to the cut end (a shorter
/// file simply completes early, stopping a completed player is a no-op).
class AudioPlaybackSync {
  AudioPlaybackSync({
    required this.controller,
    required this.resolveFps,
    required this.durationSecondsFor,
    required this.playerFactory,
  });

  final CanvasPlaybackController controller;
  final int Function() resolveFps;
  final double? Function(String filePath) durationSecondsFor;
  final AudioClipPlayerFactory playerFactory;

  List<_ScheduledClip> _schedule = const [];
  final Map<int, AudioClipPlayer> _livePlayers = {};
  bool _wasActive = false;
  bool _wasPlaying = false;
  int? _lastFrame;
  bool _attached = false;

  /// Forward jumps beyond half a second restart overlapping clips at the
  /// new position; anything smaller is treated as dropped frames.
  int get resyncThresholdFrames => math.max(2, resolveFps() ~/ 2);

  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    controller.addListener(_onControllerChanged);
    controller.globalFrameIndexListenable.addListener(_onFrameTick);
  }

  void dispose() {
    if (_attached) {
      controller.removeListener(_onControllerChanged);
      controller.globalFrameIndexListenable.removeListener(_onFrameTick);
      _attached = false;
    }
    _stopAll();
  }

  void _onControllerChanged() {
    final active = controller.isActive;
    final playing = controller.isPlaying;
    if (active && !_wasActive) {
      _schedule = _buildSchedule(controller.playlist);
      _lastFrame = controller.globalFrameIndexListenable.value;
      if (playing) {
        _resyncAt(_lastFrame ?? 0);
      }
    } else if (!active && _wasActive) {
      _stopAll();
      _schedule = const [];
      _lastFrame = null;
    } else if (active) {
      if (playing && !_wasPlaying) {
        // Resume — unless a paused seek already stopped the stale players,
        // in which case restart whatever overlaps the current frame.
        if (_livePlayers.isEmpty) {
          _resyncAt(_lastFrame ?? 0);
        } else {
          for (final player in _livePlayers.values) {
            unawaited(player.resume());
          }
        }
      } else if (!playing && _wasPlaying) {
        for (final player in _livePlayers.values) {
          unawaited(player.pause());
        }
      }
    }
    _wasActive = active;
    _wasPlaying = playing;
  }

  void _onFrameTick() {
    final frame = controller.globalFrameIndexListenable.value;
    if (frame == null) {
      // Deactivation is handled by the controller listener.
      return;
    }
    final last = _lastFrame;
    _lastFrame = frame;
    if (!_wasActive) {
      // play() fires the frame notifier before notifyListeners; activation
      // (schedule build + initial sync) happens in the controller listener.
      return;
    }
    if (!controller.isPlaying) {
      // Paused seek: live positions are stale now — stop them; resuming
      // restarts whatever overlaps the (empty-pool) current frame.
      _stopAll();
      return;
    }
    if (last == null || frame < last || frame - last > resyncThresholdFrames) {
      _resyncAt(frame);
      return;
    }
    for (var index = 0; index < _schedule.length; index += 1) {
      final clip = _schedule[index];
      if (clip.startFrame > last &&
          clip.startFrame <= frame &&
          frame < clip.endFrameExclusive) {
        _startClip(index, frame);
      } else if (clip.endFrameExclusive > last &&
          clip.endFrameExclusive <= frame) {
        _stopClip(index);
      }
    }
  }

  /// Stops everything and starts every clip overlapping [frame] at the
  /// matching position.
  void _resyncAt(int frame) {
    _stopAll();
    for (var index = 0; index < _schedule.length; index += 1) {
      final clip = _schedule[index];
      if (clip.startFrame <= frame && frame < clip.endFrameExclusive) {
        _startClip(index, frame);
      }
    }
  }

  void _startClip(int index, int frame) {
    if (_livePlayers.containsKey(index)) {
      return;
    }
    final clip = _schedule[index];
    final player = playerFactory();
    _livePlayers[index] = player;
    final fps = math.max(1, resolveFps());
    unawaited(
      player.play(
        clip.filePath,
        position: Duration(
          microseconds:
              (frame - clip.startFrame) * Duration.microsecondsPerSecond ~/ fps,
        ),
      ),
    );
  }

  void _stopClip(int index) {
    final player = _livePlayers.remove(index);
    if (player == null) {
      return;
    }
    unawaited(player.stop().then((_) => player.dispose()));
  }

  void _stopAll() {
    for (final player in _livePlayers.values) {
      unawaited(player.stop().then((_) => player.dispose()));
    }
    _livePlayers.clear();
  }

  List<_ScheduledClip> _buildSchedule(
    List<StoryboardTimelineLayoutEntry> playlist,
  ) {
    final fps = math.max(1, resolveFps());
    final schedule = <_ScheduledClip>[];
    for (final entry in playlist) {
      for (final layer in entry.cut.layers) {
        if (layer.kind != LayerKind.se) {
          continue;
        }
        for (final clip in layer.audioClips) {
          if (clip.startFrame >= entry.duration) {
            continue;
          }
          final startFrame = entry.startFrame + clip.startFrame;
          var endFrameExclusive = entry.endFrame;
          final seconds = durationSecondsFor(clip.filePath);
          if (seconds != null) {
            endFrameExclusive = math.min(
              endFrameExclusive,
              startFrame + (seconds * fps).ceil(),
            );
          }
          if (endFrameExclusive <= startFrame) {
            continue;
          }
          schedule.add(
            _ScheduledClip(
              filePath: clip.filePath,
              startFrame: startFrame,
              endFrameExclusive: endFrameExclusive,
            ),
          );
        }
      }
    }
    return schedule;
  }
}

/// A clip laid out on the playlist-global frame axis, end clamped at its
/// cut's boundary.
class _ScheduledClip {
  const _ScheduledClip({
    required this.filePath,
    required this.startFrame,
    required this.endFrameExclusive,
  });

  final String filePath;
  final int startFrame;
  final int endFrameExclusive;
}
