import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../native/qa_audio_device.dart';

/// The settings dialog's live input meter (REC1-D2): opens the capture
/// device while running and keeps only the LATEST drained |peak| — no
/// accumulation, no take, nothing written anywhere.
///
/// The recorder always wins the microphone (capture is single-open): the
/// session stops this monitor before arming a take and resumes it after.
/// [peak] is RAW — the display applies the gain factor itself, so the
/// gain slider reacts live without reopening the device.
class AudioInputMonitor {
  AudioInputMonitor({QaAudioDevice? device}) : _device = device;

  final QaAudioDevice? _device;

  /// The last drained block's |peak|, 0..1. Untouched across ticks that
  /// drained nothing (the device delivers in its own cadence).
  final ValueNotifier<double> peak = ValueNotifier<double>(0);

  Timer? _timer;
  Pointer<Float>? _scratch;
  int _scratchFloats = 0;
  bool _ownsCapture = false;

  bool get isRunning => _timer != null;

  /// Opens the capture device and starts polling. False when it would
  /// not open (no binary, no microphone, or the recorder holds it) —
  /// the meter simply stays empty then.
  bool start({int sampleRate = 48000, int deviceIndex = -1}) {
    final device = _device;
    if (device == null || isRunning || device.captureIsOpen) {
      return false;
    }
    var rate = device.captureStart(
      sampleRate: sampleRate,
      deviceIndex: deviceIndex,
    );
    if (rate == 0 && deviceIndex >= 0) {
      rate = device.captureStart(sampleRate: sampleRate);
    }
    if (rate == 0) {
      return false;
    }
    _ownsCapture = true;
    _scratchFloats = rate; // ~1s of mono floats: one read drains a tick.
    _scratch = calloc<Float>(_scratchFloats);
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _poll());
    return true;
  }

  void _poll() {
    final device = _device;
    final scratch = _scratch;
    if (device == null || scratch == null) {
      return;
    }
    var maxPeak = 0.0;
    var drainedAny = false;
    while (true) {
      final got = device.captureRead(scratch, _scratchFloats);
      if (got <= 0) {
        break;
      }
      drainedAny = true;
      final view = scratch.asTypedList(got);
      for (var index = 0; index < view.length; index += 1) {
        final value = view[index];
        final size = value < 0 ? -value : value;
        if (size > maxPeak) {
          maxPeak = size;
        }
      }
      if (got < _scratchFloats) {
        break;
      }
    }
    if (drainedAny) {
      peak.value = maxPeak;
    }
  }

  /// Releases the microphone (recording is taking it, the dialog closed,
  /// or the device choice changed). Only closes a capture THIS monitor
  /// opened — never one the recorder owns.
  void stop() {
    _timer?.cancel();
    _timer = null;
    final scratch = _scratch;
    if (scratch != null) {
      calloc.free(scratch);
      _scratch = null;
    }
    if (_ownsCapture) {
      _ownsCapture = false;
      _device?.captureStop();
    }
    peak.value = 0;
  }

  void dispose() {
    stop();
    peak.dispose();
  }
}
