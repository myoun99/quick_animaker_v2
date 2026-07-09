import 'dart:async';
import 'dart:math' as math;

import '../../models/layer_kind.dart';
import '../../models/se_audio_spans.dart';
import '../storyboard_timeline_layout.dart';
import 'canvas_playback_controller.dart';

/// One playing audio clip. The production implementation wraps an
/// `audioplayers` player; tests inject fakes (plugins are unavailable under
/// FLUTTER_TEST). Calls are fire-and-forget from the sync's point of view —
/// audio must never block the frame ticker.
///
/// The contract splits loading from starting: [prepare] does the heavy
/// source opening once, [startAt] just seeks and resumes. The sync prepares
/// every scheduled clip at playback activation so boundary ticks stay
/// cheap — playback must NEVER stall at a cut boundary.
abstract class AudioClipPlayer {
  /// Loads [filePath]; called once per player at playback activation.
  Future<void> prepare(String filePath);

  /// Seeks the prepared source to [position] and plays.
  Future<void> startAt(Duration position);

  /// Sets the playback volume, already clamped into 0..1 by the sync (the
  /// gain × fade ramp; platforms don't amplify past 1).
  Future<void> setVolume(double volume);

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
/// - activation → build the schedule, create ONE player per scheduled clip
///   and prepare (load) them all up front; then start every clip
///   overlapping the start frame at position `(frame - clipStart) / fps`;
/// - forward ticking → start clips whose start frame was crossed, stop
///   clips past their end (clip length, clamped at the cut boundary — an SE
///   clip belongs to its cut, it never bleeds into the next one). Starting
///   and stopping only seeks/resumes/stops prepared players; no media
///   pipeline is opened or torn down on a tick, so cut boundaries never
///   stall the frame ticker;
/// - pause / resume / stop → forwarded to every playing player;
/// - backward jumps (loop wrap, seeks) and forward jumps larger than
///   [resyncThresholdFrames] → stop everything and restart what overlaps.
///   Smaller forward jumps are indistinguishable from dropped frames, where
///   the audio kept real time on the native thread and restarting it would
///   glitch — those keep playing untouched;
/// - deactivation → stop and dispose every player.
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
  List<AudioClipPlayer> _players = const [];
  final Set<int> _playing = {};

  /// Last volume sent per playing clip — the per-tick fade ramp only
  /// touches the platform channel when the value actually moves.
  final Map<int, double> _sentVolume = {};
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
    _teardown();
  }

  void _onControllerChanged() {
    final active = controller.isActive;
    final playing = controller.isPlaying;
    if (active && !_wasActive) {
      _schedule = _buildSchedule(controller.playlist);
      _players = [for (final _ in _schedule) playerFactory()];
      for (var index = 0; index < _schedule.length; index += 1) {
        unawaited(_players[index].prepare(_schedule[index].filePath));
      }
      _lastFrame = controller.globalFrameIndexListenable.value;
      if (playing) {
        _resyncAt(_lastFrame ?? 0);
      }
    } else if (!active && _wasActive) {
      _teardown();
    } else if (active) {
      if (playing && !_wasPlaying) {
        // Resume — unless a paused seek already stopped the stale players,
        // in which case restart whatever overlaps the current frame.
        if (_playing.isEmpty) {
          _resyncAt(_lastFrame ?? 0);
        } else {
          for (final index in _playing) {
            unawaited(_players[index].resume());
          }
        }
      } else if (!playing && _wasPlaying) {
        for (final index in _playing) {
          unawaited(_players[index].pause());
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
    _updateVolumes(frame);
  }

  /// The gain × fade envelope at [frame]: fade-in ramps from the clip's
  /// start, fade-out ramps into its scheduled end (block/cut/file clamp),
  /// overlapping fades multiply. Clamped into 0..1 — platform players
  /// don't amplify past 1 (export applies the exact gain instead).
  double _volumeAt(_ScheduledClip clip, int frame) {
    var volume = clip.gain;
    final position = frame - clip.startFrame;
    if (clip.fadeInFrames > 0 && position < clip.fadeInFrames) {
      volume *= math.max(0, position / clip.fadeInFrames);
    }
    final remaining = clip.endFrameExclusive - frame;
    if (clip.fadeOutFrames > 0 && remaining < clip.fadeOutFrames) {
      volume *= math.max(0, remaining / clip.fadeOutFrames);
    }
    return volume.clamp(0.0, 1.0);
  }

  /// Sends the ramp to every playing clip whose volume moved this tick.
  void _updateVolumes(int frame) {
    for (final index in _playing) {
      final volume = _volumeAt(_schedule[index], frame);
      if (_sentVolume[index] != volume) {
        _sentVolume[index] = volume;
        unawaited(_players[index].setVolume(volume));
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
    if (!_playing.add(index)) {
      return;
    }
    final clip = _schedule[index];
    final fps = math.max(1, resolveFps());
    // Volume lands before the first samples so a fade-in never pops.
    final volume = _volumeAt(clip, frame);
    _sentVolume[index] = volume;
    unawaited(_players[index].setVolume(volume));
    unawaited(
      _players[index].startAt(
        Duration(
          // The clip's offset trim seeks past the skipped head of the file.
          microseconds:
              (frame - clip.startFrame + clip.offsetFrames) *
              Duration.microsecondsPerSecond ~/
              fps,
        ),
      ),
    );
  }

  void _stopClip(int index) {
    if (!_playing.remove(index)) {
      return;
    }
    _sentVolume.remove(index);
    unawaited(_players[index].stop());
  }

  void _stopAll() {
    for (final index in _playing.toList()) {
      _stopClip(index);
    }
  }

  void _teardown() {
    _stopAll();
    for (final player in _players) {
      unawaited(player.dispose());
    }
    _players = const [];
    _schedule = const [];
    _lastFrame = null;
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
        for (final span in seAudioSpans(layer)) {
          if (span.startFrame >= entry.duration) {
            continue;
          }
          final startFrame = entry.startFrame + span.startFrame;
          // The BLOCK is the instance: playback never runs past its end
          // (nor past the cut end, nor past the file's own length — the
          // offset trim shortens the remaining file accordingly).
          var endFrameExclusive = math.min(
            entry.endFrame,
            startFrame + span.lengthFrames,
          );
          final seconds = durationSecondsFor(span.clip.filePath);
          if (seconds != null) {
            endFrameExclusive = math.min(
              endFrameExclusive,
              startFrame + (seconds * fps).ceil() - span.clip.offsetFrames,
            );
          }
          if (endFrameExclusive <= startFrame) {
            continue;
          }
          schedule.add(
            _ScheduledClip(
              filePath: span.clip.filePath,
              startFrame: startFrame,
              endFrameExclusive: endFrameExclusive,
              offsetFrames: span.clip.offsetFrames,
              gain: span.clip.gain,
              fadeInFrames: span.clip.fadeInFrames,
              fadeOutFrames: span.clip.fadeOutFrames,
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
    this.offsetFrames = 0,
    this.gain = 1.0,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
  });

  final String filePath;
  final int startFrame;
  final int endFrameExclusive;

  /// Frames skipped into the file where the block starts (the clip's trim).
  final int offsetFrames;

  /// The clip's volume envelope (see [AudioClip]); fades anchor to this
  /// schedule entry's own start/end.
  final double gain;
  final int fadeInFrames;
  final int fadeOutFrames;
}
