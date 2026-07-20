import 'dart:async';
import 'dart:math' as math;

import '../../models/cut_id.dart';
import '../../models/layer_kind.dart';
import '../../models/project.dart';
import '../../models/project_frame_rate.dart';
import '../../models/se_audio_spans.dart';
import '../../models/track.dart';
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
///   overlapping the start frame at the exact time of `frame - clipStart`;
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
    required this.resolveFrameRate,
    required this.durationSecondsFor,
    required this.playerFactory,
    this.resolveProject,
  });

  final CanvasPlaybackController controller;

  /// The exact rate: clip positions are REAL TIME, so this is one of the
  /// few places that needs the fraction rather than the counting base.
  final ProjectFrameRate Function() resolveFrameRate;
  final double? Function(String filePath) durationSecondsFor;
  final AudioClipPlayerFactory playerFactory;

  /// Resolves the project for the TRACK-owned SE rows (sounds on the
  /// track's global axis, allowed to cross cut boundaries). Null skips
  /// them (legacy fixtures with cut-owned SE layers keep working through
  /// the per-cut loop).
  final Project? Function()? resolveProject;

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

  /// Clamps [endFrameExclusive] to the file's own audible length.
  ///
  /// Rounding UP is deliberate — a file ending mid-frame still has audio
  /// in that frame, and truncating would clip real sound. What must not
  /// happen is rounding up on float noise alone: a 2.000s file at 24fps
  /// computes as 48.000000000000004, and a bare `.ceil()` would hand it a
  /// 49th frame of silence. [ProjectFrameRate.framesCoveringSeconds]
  /// treats a value within a millionth of a frame of whole as whole.
  int _clampToFileLength({
    required int startFrame,
    required int endFrameExclusive,
    required String filePath,
    required int offsetFrames,
    required ProjectFrameRate rate,
  }) {
    final seconds = durationSecondsFor(filePath);
    if (seconds == null) {
      return endFrameExclusive;
    }
    return math.min(
      endFrameExclusive,
      startFrame + rate.framesCoveringSeconds(seconds) - offsetFrames,
    );
  }

  List<_ScheduledClip> _buildSchedule(
    List<StoryboardTimelineLayoutEntry> playlist,
  ) {
    final rate = resolveFrameRate();
    final schedule = <_ScheduledClip>[];

    // Legacy path: cut-owned SE layers (test fixtures; production cuts no
    // longer carry SE rows). Ends clamp at the cut boundary as before.
    for (final entry in playlist) {
      for (final layer in entry.cut.layers) {
        if (layer.kind != LayerKind.se || layer.muted) {
          continue;
        }
        for (final span in seAudioSpans(layer)) {
          if (span.startFrame >= entry.duration) {
            continue;
          }
          final startFrame = entry.startFrame + span.startFrame;
          var endFrameExclusive = math.min(
            entry.endFrame,
            startFrame + span.lengthFrames,
          );
          endFrameExclusive = _clampToFileLength(
            startFrame: startFrame,
            endFrameExclusive: endFrameExclusive,
            filePath: span.clip.filePath,
            offsetFrames: span.clip.offsetFrames,
            rate: rate,
          );
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

    // Track-owned SE rows: spans live on each track's GLOBAL frame axis
    // and may cross cut boundaries. Each span maps into the playlist axis
    // once — at the entry containing its start (or the first overlapping
    // entry when the playlist begins mid-sound, bumping the file offset by
    // the clipped lead) — and its end runs to the span's true end, clamped
    // only where the playlist run stops being contiguous with the track.
    final project = resolveProject?.call();
    if (project != null && playlist.isNotEmpty) {
      final trackStartByCutId = <CutId, int>{};
      final trackByCutId = <CutId, Track>{};
      for (final track in project.tracks) {
        var start = 0;
        for (final cut in track.cuts) {
          start += cut.leadingGapFrames;
          trackStartByCutId[cut.id] = start;
          trackByCutId[cut.id] = track;
          start += cut.duration;
        }
      }

      /// The playlist frame where the contiguous run starting at
      /// [entryIndex] ends. Contiguous = the playlist and track axes
      /// advance by the SAME amount between entries — back-to-back cuts,
      /// or a leading gap the playlist plays through as black. Sounds keep
      /// running through played gaps (audio lives on the global axis).
      int contiguousPlaylistEndFrom(int entryIndex) {
        var end = playlist[entryIndex].endFrame;
        var trackEnd =
            (trackStartByCutId[playlist[entryIndex].cutId] ?? 0) +
            playlist[entryIndex].duration;
        final track = trackByCutId[playlist[entryIndex].cutId];
        for (var i = entryIndex + 1; i < playlist.length; i += 1) {
          final next = playlist[i];
          final nextTrackStart = trackStartByCutId[next.cutId];
          if (nextTrackStart == null ||
              next.startFrame < end ||
              next.startFrame - end != nextTrackStart - trackEnd ||
              !identical(trackByCutId[next.cutId], track)) {
            break;
          }
          end = next.endFrame;
          trackEnd = nextTrackStart + next.duration;
        }
        return end;
      }

      for (var i = 0; i < playlist.length; i += 1) {
        final entry = playlist[i];
        final track = trackByCutId[entry.cutId];
        final cutTrackStart = trackStartByCutId[entry.cutId];
        if (track == null || cutTrackStart == null) {
          continue;
        }
        // A run-start entry also carries sounds spilling in from before
        // the playlist window (offset-bumped); interior entries only emit
        // spans STARTING in their window (no duplicates). The window
        // extends back over the entry's PLAYED leading gap — playlist
        // frames before the cut that map 1:1 onto the track frames before
        // it — so sounds starting inside a gap are scheduled too.
        final previous = i == 0 ? null : playlist[i - 1];
        final previousTrackStart = previous == null
            ? null
            : trackStartByCutId[previous.cutId];
        final playlistLead = entry.startFrame - (previous?.endFrame ?? 0);
        final axesAligned = previous == null
            // The playlist head maps straight onto the track axis
            // (all-cuts playlists ARE the track axis; a rebased
            // single-cut playlist has no lead at all).
            ? playlistLead >= 0
            : previousTrackStart != null &&
                  identical(trackByCutId[previous.cutId], track) &&
                  playlistLead >= 0 &&
                  cutTrackStart - (previousTrackStart + previous.duration) ==
                      playlistLead;
        final coveredLead = axesAligned ? playlistLead : 0;
        final isRunStart = previous == null || !axesAligned;
        final windowStart = cutTrackStart - coveredLead;
        final windowEnd = cutTrackStart + entry.duration;
        final runEnd = contiguousPlaylistEndFrom(i);

        for (final layer in track.seLayers) {
          if (layer.muted) {
            continue;
          }
          for (final span in seAudioSpans(layer)) {
            final spanEnd = span.startFrame + span.lengthFrames;
            final startsHere =
                span.startFrame >= windowStart && span.startFrame < windowEnd;
            final spillsIntoRunStart =
                isRunStart &&
                span.startFrame < windowStart &&
                spanEnd > windowStart;
            if (!startsHere && !spillsIntoRunStart) {
              continue;
            }
            final clippedLead = spillsIntoRunStart
                ? windowStart - span.startFrame
                : 0;
            // entry.startFrame - coveredLead = the playlist frame the
            // (gap-extended) window begins at.
            final startFrame =
                entry.startFrame -
                coveredLead +
                (spillsIntoRunStart ? 0 : span.startFrame - windowStart);
            var endFrameExclusive = math.min(
              runEnd,
              startFrame + span.lengthFrames - clippedLead,
            );
            final offsetFrames = span.clip.offsetFrames + clippedLead;
            endFrameExclusive = _clampToFileLength(
              startFrame: startFrame,
              endFrameExclusive: endFrameExclusive,
              filePath: span.clip.filePath,
              offsetFrames: offsetFrames,
              rate: rate,
            );
            if (endFrameExclusive <= startFrame) {
              continue;
            }
            schedule.add(
              _ScheduledClip(
                filePath: span.clip.filePath,
                startFrame: startFrame,
                endFrameExclusive: endFrameExclusive,
                offsetFrames: offsetFrames,
                gain: span.clip.gain,
                fadeInFrames: span.clip.fadeInFrames,
                fadeOutFrames: span.clip.fadeOutFrames,
              ),
            );
          }
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
