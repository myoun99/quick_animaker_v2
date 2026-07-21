/// Audio scrub (audio program 2D, final piece): dragging the playhead
/// plays each frame's slice of the mix.
///
/// This is the anime-tool scrub — TVPaint, and every NLE's JKL shuttle at
/// its slowest, do the same thing: as the playhead crosses a frame, that
/// frame's worth of sound plays. Because the mixer builds a mix rather
/// than starting clips, a scrub tick is just `play(frame, frame+1)` on
/// the same transport playback uses — one arm per crossed frame, samples
/// exact, no media pipeline opened per tick.
///
/// The schedule uploads ONCE per gesture (the first frame the scrub
/// actually crosses), from the same scheduler playback uses, over the
/// active-cut playlist — so scrubbed sound and played sound can never
/// disagree. Standing down is silent and per-gesture: no device, no
/// resident PCM, or a cut with no sound leaves the scrub visual-only,
/// exactly as it was before this class existed.
library;

import '../../models/project.dart';
import '../../models/project_frame_rate.dart';
import '../../native/qa_audio_device.dart';
import '../../services/audio/audio_mixer_reference.dart';
import '../audio/audio_conform_store.dart';
import 'audio_playback_schedule.dart';
import 'canvas_playback_controller.dart';

class AudioScrubber {
  AudioScrubber({
    required this.controller,
    required this.resolveFrameRate,
    required this.resolveProject,
    required this.conformStore,
    QaAudioDevice? Function()? resolveDevice,
  }) : _resolveDevice = resolveDevice ?? (() => QaAudioDevice.instance);

  final CanvasPlaybackController controller;
  final ProjectFrameRate Function() resolveFrameRate;
  final Project? Function() resolveProject;
  final AudioConformStore conformStore;
  final QaAudioDevice? Function() _resolveDevice;

  bool _armed = false;
  bool _stoodDown = false;
  QaAudioDevice? _device;
  ProjectFrameRate _rate = const ProjectFrameRate.integer(24);
  int _deviceRate = 0;

  /// Whether the current gesture is playing sound (test surface).
  bool get isArmed => _armed;

  /// A scrub move that CHANGED the frame: plays that frame's slice.
  ///
  /// [localFrame] is the active cut's local frame — the same coordinate
  /// the editing scrub rides.
  void onScrubFrame(int localFrame) {
    if (controller.isActive) {
      // Playback (even paused) owns the device and its schedule.
      return;
    }
    if (!_armed && !_stoodDown) {
      _prepare();
    }
    if (!_armed) {
      return;
    }
    _device!.play(
      startSample: _rate.frameToSample(localFrame, _deviceRate),
      stopSample: _rate.frameToSample(localFrame + 1, _deviceRate),
    );
  }

  /// The gesture's release: silence, and a fresh decision next gesture.
  void onScrubEnd() {
    if (_armed) {
      _device?.stop();
    }
    _armed = false;
    _stoodDown = false;
  }

  /// One decision per gesture, mirroring the transport's activation: the
  /// schedule from the shared scheduler, PCM from the conform store, all
  /// resident or nothing. A stand-down kicks the missing pieces so the
  /// NEXT gesture (or the next play) has them.
  void _prepare() {
    _stoodDown = true;
    _rate = resolveFrameRate();
    final schedule = buildAudioPlaybackSchedule(
      playlist: controller.playlistForScope(PlaybackScope.activeCut),
      project: resolveProject(),
      rate: _rate,
      durationSecondsFor: conformStore.durationSecondsFor,
    );
    if (schedule.isEmpty) {
      // A silent cut: do not even open a device for it.
      return;
    }
    final device = _resolveDevice();
    if (device == null) {
      return;
    }
    if (!device.isOpen) {
      if (device.open(sampleRate: conformStore.projectSampleRate) <= 0) {
        return;
      }
    }
    _deviceRate = device.sampleRate;
    final mix = audioMixScheduleFrom(
      schedule: schedule,
      rate: _rate,
      sampleRate: _deviceRate,
    );
    final sources = <AudioMixSource>[];
    for (final path in mix.sourcePaths) {
      final samples = conformStore.samplesAtRate(path, _deviceRate);
      final entry = conformStore.resultFor(path);
      if (samples == null || entry == null || !entry.isUsable) {
        return; // kicked by the lookups above; this gesture stays visual
      }
      sources.add(AudioMixSource(samples: samples, channels: entry.channels));
    }
    device.stop();
    if (!device.setSchedule(clips: mix.clips, sources: sources)) {
      return;
    }
    _device = device;
    _armed = true;
    _stoodDown = false;
  }

  void dispose() {
    if (_armed) {
      _device?.stop();
      _armed = false;
    }
  }
}
