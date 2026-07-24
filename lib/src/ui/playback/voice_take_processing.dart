import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_sync_settings.dart' show VoiceInputChannelMode;

/// A take after the capture chain (REC1-D): channel fold + baked gain,
/// plus whether anything hit the ceiling on the way.
class ProcessedVoiceTake {
  const ProcessedVoiceTake({
    required this.samples,
    required this.channels,
    required this.clipped,
  });

  final Float32List samples;
  final int channels;

  /// True when any post-gain sample reached the ceiling: digital clipping
  /// is about to be baked into a 16-bit file, and the take should say so.
  final bool clipped;
}

/// |v| at or above this counts as clipped — 16-bit full scale minus
/// rounding headroom, the level OBS's indicator lights at.
const double voiceClipThreshold = 0.999;

/// The linear factor for a dB gain (0 dB = 1.0).
double micGainFactor(int gainDb) => math.pow(10.0, gainDb / 20.0).toDouble();

/// Applies the capture chain to a finished take: [channelMode] folds the
/// device's channels (an interface's mono mic otherwise lands one-sided
/// stereo), then [gainDb] bakes in (the OBS model — the meter showed
/// post-gain, the file must match). Output samples clamp to ±1.0; the
/// clip flag reports any sample that needed it (or arrived at the
/// ceiling already — analog overload shows the same way).
ProcessedVoiceTake processVoiceTake({
  required Float32List samples,
  required int channels,
  required int gainDb,
  required VoiceInputChannelMode channelMode,
}) {
  if (channels <= 0) {
    return ProcessedVoiceTake(
      samples: samples,
      channels: channels,
      clipped: false,
    );
  }
  final fold = channels >= 2 ? channelMode : VoiceInputChannelMode.device;
  final frames = samples.length ~/ channels;
  final outChannels = fold == VoiceInputChannelMode.device ? channels : 1;
  final factor = micGainFactor(gainDb);

  // The no-op chain (device channels, 0 dB) still has to CLAMP: a float
  // capture can hand us |v| > 1.0, and the take is about to be baked into
  // 16-bit. Returning those verbatim made "output clamps to +/-1.0" true
  // of every path except this one — and the one it was false of is the
  // default. Only a sample that actually needs it is written, so an
  // in-range take still passes through untouched.
  final identity = fold == VoiceInputChannelMode.device && gainDb == 0;
  var clipped = false;
  if (identity) {
    for (var index = 0; index < samples.length; index += 1) {
      final value = samples[index];
      if (value >= voiceClipThreshold) {
        clipped = true;
        if (value > 1.0) {
          samples[index] = 1.0;
        }
      } else if (value <= -voiceClipThreshold) {
        clipped = true;
        if (value < -1.0) {
          samples[index] = -1.0;
        }
      }
    }
    return ProcessedVoiceTake(
      samples: samples,
      channels: channels,
      clipped: clipped,
    );
  }

  final out = Float32List(frames * outChannels);
  for (var frame = 0; frame < frames; frame += 1) {
    final base = frame * channels;
    if (fold == VoiceInputChannelMode.device) {
      for (var channel = 0; channel < channels; channel += 1) {
        var value = samples[base + channel] * factor;
        if (value >= voiceClipThreshold) {
          if (value > 1.0) value = 1.0;
          clipped = true;
        } else if (value <= -voiceClipThreshold) {
          if (value < -1.0) value = -1.0;
          clipped = true;
        }
        out[frame * channels + channel] = value;
      }
    } else {
      double picked;
      switch (fold) {
        case VoiceInputChannelMode.monoMix:
          var sum = 0.0;
          for (var channel = 0; channel < channels; channel += 1) {
            sum += samples[base + channel];
          }
          picked = sum / channels;
        case VoiceInputChannelMode.right:
          picked = samples[base + 1];
        case VoiceInputChannelMode.left || VoiceInputChannelMode.device:
          picked = samples[base];
      }
      var value = picked * factor;
      if (value >= voiceClipThreshold) {
        if (value > 1.0) value = 1.0;
        clipped = true;
      } else if (value <= -voiceClipThreshold) {
        if (value < -1.0) value = -1.0;
        clipped = true;
      }
      out[frame] = value;
    }
  }
  return ProcessedVoiceTake(
    samples: out,
    channels: outChannels,
    clipped: clipped,
  );
}
