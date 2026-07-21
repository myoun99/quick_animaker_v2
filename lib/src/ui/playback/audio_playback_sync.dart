import 'dart:async';
import 'dart:math' as math;

import '../../models/project.dart';
import '../../models/project_frame_rate.dart';
import 'audio_playback_schedule.dart';
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
///   overlapping the start frame at the exact time of `frame - clipStart`;
/// - forward ticking → start clips whose start frame was crossed, stop
///   clips past their end. A sound is TRACK-owned, so it runs to its own
///   end and across cut boundaries — dialogue and music span cuts, and a
///   cut boundary never restarts anything. Starting and stopping only
///   seeks/resumes/stops prepared players; no media pipeline is opened or
///   torn down on a tick, so boundaries never stall the frame ticker;
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
    required this.resolveFrameRate,
    required this.durationSecondsFor,
    required this.playerFactory,
    this.resolveProject,
    this.deviceCarriesPlayback,
  });

  /// Consulted ONCE at activation: true means the native device transport
  /// carries this run's audio, so no platform players are built — playing
  /// both would double every sound. (The transport attaches FIRST, so its
  /// decision is made by the time this is read.) This class remains the
  /// fallback: no binary, no device, or PCM not resident yet, and it
  /// carries the run exactly as before.
  final bool Function()? deviceCarriesPlayback;

  final CanvasPlaybackController controller;

  /// The exact rate: clip positions are REAL TIME, so this is one of the
  /// few places that needs the fraction rather than the counting base.
  final ProjectFrameRate Function() resolveFrameRate;
  final double? Function(String filePath) durationSecondsFor;
  final AudioClipPlayerFactory playerFactory;

  /// Resolves the project the SE rows live on. SE is TRACK-owned and sits
  /// on the track's global frame axis, so this is the ONLY source of
  /// scheduled audio — null means no sound at all, not a fallback.
  final Project? Function()? resolveProject;

  List<ScheduledAudioClip> _schedule = const [];
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
  int get resyncThresholdFrames =>
      math.max(2, resolveFrameRate().countingBase ~/ 2);

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
      _schedule = (deviceCarriesPlayback?.call() ?? false)
          ? const []
          : buildAudioPlaybackSchedule(
              playlist: controller.playlist,
              project: resolveProject?.call(),
              rate: resolveFrameRate(),
              durationSecondsFor: durationSecondsFor,
            );
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
  double _volumeAt(ScheduledAudioClip clip, int frame) {
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
    final rate = resolveFrameRate();
    // Volume lands before the first samples so a fade-in never pops.
    final volume = _volumeAt(clip, frame);
    _sentVolume[index] = volume;
    unawaited(_players[index].setVolume(volume));
    unawaited(
      _players[index].startAt(
        // The clip's offset trim seeks past the skipped head of the file.
        // Exact at any distance from zero: the seek for frame 100000 is
        // as accurate as the seek for frame 1.
        rate.frameStart(frame - clip.startFrame + clip.offsetFrames),
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

}
