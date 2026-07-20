/// Sample-rate conversion (audio program 2B) — Dart REFERENCE.
///
/// A conform has to land at the project's sample rate, and 44.1k → 48k
/// means computing sample values at instants that do not exist in the
/// source: the ratio is 147:160, so almost every output falls between two
/// inputs. Linear interpolation gets about −30 dB of alias rejection,
/// which is audible as dullness and grit. Professional converters all use
/// the same thing instead — a windowed-sinc FIR run in polyphase form —
/// and reach −100 dB or better.
///
/// **Linear phase, and the delay removed exactly.** A symmetric FIR delays
/// everything by a constant `(taps − 1) / 2`. At 4096 taps and 48 kHz that
/// is 42.6 ms — MORE than a frame at 24fps. Left uncompensated, every
/// resampled clip would sit a frame late, which is precisely the defect
/// this whole program exists to remove. Because the delay is constant it
/// cancels exactly, and [resampleAudio] does that in the index arithmetic
/// rather than by trimming afterwards, so nothing depends on the delay
/// happening to be a whole number of output samples.
///
/// Minimum phase would trade that away: it has no pre-ringing, but its
/// group delay varies with frequency, so low and high content shift by
/// different amounts and no single correction fixes both. For a program
/// about sync, a delay that cancels exactly beats one that is merely
/// small.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Stopband attenuation target in dB. 120 puts both the aliasing and the
/// pre-ringing more than 20 dB below the quantization noise of a 16-bit
/// source — under the material's own noise floor.
const double defaultResamplerStopbandDb = 120.0;

/// How much of the available band stays flat, as a fraction of the lower
/// of the two Nyquist limits. The remainder is the transition band.
///
/// 0.90 keeps everything below 19.8 kHz flat on a 44.1k → 48k conform and
/// spends 19.8–22.05 kHz rolling off. Pushing this toward 1.0 costs filter
/// length quadratically for band nobody can hear.
const double defaultResamplerBandwidth = 0.90;

/// Ceiling on the prototype length, so a pathological rate pair (44100 →
/// 44101 shares no factors and would ask for billions of taps) degrades
/// into a merely-good filter instead of hanging. Every standard pair —
/// 8k, 16k, 22.05k, 32k, 44.1k, 48k, 96k — lands far below this.
const int maxResamplerTaps = 131071;

/// The result of a conversion, plus what it took to get there — exposed so
/// tests can assert the filter is the one that was asked for.
class ResampledAudio {
  const ResampledAudio({
    required this.samples,
    required this.channels,
    required this.sampleRate,
    required this.taps,
    required this.beta,
    required this.passthrough,
  });

  /// Interleaved by channel.
  final Float32List samples;
  final int channels;
  final int sampleRate;

  /// Prototype filter length (odd, symmetric). 0 when [passthrough].
  final int taps;

  /// The Kaiser shape parameter the stopband target produced.
  final double beta;

  /// True when the source was already at the target rate and the samples
  /// were handed back untouched.
  final bool passthrough;

  int get length => channels <= 0 ? 0 : samples.length ~/ channels;
}

int _gcd(int a, int b) {
  var x = a < 0 ? -a : a;
  var y = b < 0 ? -b : b;
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x;
}

/// Modified Bessel function of the first kind, order 0 — the Kaiser
/// window's kernel.
///
/// Fixed termination (relative epsilon, hard iteration cap) so the C twin
/// runs the identical number of terms. A loop that stopped "when it feels
/// converged" would be a parity hazard.
double besselI0(double x) {
  final half = x / 2.0;
  var term = 1.0;
  var sum = 1.0;
  for (var k = 1; k <= 64; k += 1) {
    final ratio = half / k;
    term *= ratio * ratio;
    sum += term;
    if (term < sum * 1e-16) {
      break;
    }
  }
  return sum;
}

/// Kaiser β for a stopband attenuation of [stopbandDb] — the standard
/// empirical fit.
double kaiserBeta(double stopbandDb) {
  if (stopbandDb > 50.0) {
    return 0.1102 * (stopbandDb - 8.7);
  }
  if (stopbandDb >= 21.0) {
    return 0.5842 * math.pow(stopbandDb - 21.0, 0.4).toDouble() +
        0.07886 * (stopbandDb - 21.0);
  }
  return 0.0;
}

double _sinc(double x) {
  if (x == 0.0) {
    return 1.0;
  }
  final pix = math.pi * x;
  return math.sin(pix) / pix;
}

/// Builds the prototype lowpass: a sinc at [cutoff] (normalized to the
/// interpolated rate) under a Kaiser window, with DC gain [interpolation]
/// to make up for the zero-stuffing.
Float64List buildResamplerKernel({
  required int taps,
  required double cutoff,
  required double beta,
  required int interpolation,
}) {
  final kernel = Float64List(taps);
  final center = (taps - 1) / 2.0;
  final denominator = besselI0(beta);
  for (var index = 0; index < taps; index += 1) {
    final offset = index - center;
    final ratio = offset / center;
    final inside = 1.0 - ratio * ratio;
    final window = inside <= 0.0
        ? 0.0
        : besselI0(beta * math.sqrt(inside)) / denominator;
    kernel[index] = 2.0 * cutoff * _sinc(2.0 * cutoff * offset) * window *
        interpolation;
  }
  return kernel;
}

/// Converts [samples] from [inputRate] to [outputRate].
///
/// Equal rates return the input UNTOUCHED — bit-exact, no filter, no
/// rounding. Most SE libraries and dialogue are already at 44.1k or 48k,
/// so this is the common path, and it costing nothing is the point.
ResampledAudio resampleAudioReference({
  required Float32List samples,
  required int channels,
  required int inputRate,
  required int outputRate,
  double stopbandDb = defaultResamplerStopbandDb,
  double bandwidth = defaultResamplerBandwidth,
}) {
  if (channels <= 0 || inputRate <= 0 || outputRate <= 0) {
    return ResampledAudio(
      samples: Float32List(0),
      channels: channels < 0 ? 0 : channels,
      sampleRate: outputRate < 0 ? 0 : outputRate,
      taps: 0,
      beta: 0,
      passthrough: false,
    );
  }
  if (inputRate == outputRate) {
    return ResampledAudio(
      samples: samples,
      channels: channels,
      sampleRate: outputRate,
      taps: 0,
      beta: 0,
      passthrough: true,
    );
  }

  final divisor = _gcd(inputRate, outputRate);
  final interpolation = outputRate ~/ divisor; // L
  final decimation = inputRate ~/ divisor; // M
  final larger = interpolation > decimation ? interpolation : decimation;

  // Everything is normalized to the INTERPOLATED rate (L × inputRate).
  // The lower of the two Nyquist limits sits at 0.5 / larger; the passband
  // stops short of it and the transition band covers the rest.
  final nyquist = 0.5 / larger;
  final passbandEdge = nyquist * bandwidth;
  final transition = nyquist - passbandEdge;
  final cutoff = (passbandEdge + nyquist) / 2.0;
  final beta = kaiserBeta(stopbandDb);

  // Length comes from the Kaiser design formula, NOT a fixed multiple of
  // the ratio. Sizing it as a multiple looks reasonable until a simple
  // ratio arrives: 48k → 24k has larger = 2, which bought 65 taps and only
  // 93 dB of rejection — a 15 kHz source folding back to an audible 9 kHz
  // tone that was never played. The transition band is what sets the
  // length, and it does not get easier just because the ratio is tidy.
  final estimated = transition <= 0
      ? maxResamplerTaps
      : ((stopbandDb - 8.0) / (2.285 * 2.0 * math.pi * transition)).ceil();
  var taps = estimated < 15 ? 15 : estimated;
  if (taps > maxResamplerTaps) {
    taps = maxResamplerTaps;
  }
  // Odd, so the centre lands ON a sample and the group delay is an exact
  // integer at the interpolated rate — which is what lets the delay cancel
  // exactly rather than approximately.
  if (taps.isEven) {
    taps += 1;
  }
  final halfLength = (taps - 1) ~/ 2;
  final kernel = buildResamplerKernel(
    taps: taps,
    cutoff: cutoff,
    beta: beta,
    interpolation: interpolation,
  );

  final inputFrames = samples.length ~/ channels;
  final outputFrames =
      inputFrames <= 0 ? 0 : (inputFrames * interpolation) ~/ decimation;
  final out = Float32List(outputFrames * channels);

  for (var frame = 0; frame < outputFrames; frame += 1) {
    // The + halfLength is the delay compensation: it centres the filter on
    // the output instant, so the result carries NO net time shift. Doing it
    // here rather than trimming later means it never has to be a whole
    // number of output samples.
    final position = frame * decimation + halfLength;
    final phase = position % interpolation;
    final base = position ~/ interpolation;

    for (var channel = 0; channel < channels; channel += 1) {
      var sum = 0.0;
      var tap = phase;
      var source = base;
      // Walking one polyphase branch: tap strides by L while the source
      // index walks backwards. Once source goes negative every later one
      // does too, so the loop ends there; a source past the END is merely
      // skipped, since the branch may still reach back into range.
      while (tap < taps && source >= 0) {
        if (source < inputFrames) {
          sum += kernel[tap] * samples[source * channels + channel];
        }
        tap += interpolation;
        source -= 1;
      }
      out[frame * channels + channel] = sum;
    }
  }

  return ResampledAudio(
    samples: out,
    channels: channels,
    sampleRate: outputRate,
    taps: taps,
    beta: beta,
    passthrough: false,
  );
}
