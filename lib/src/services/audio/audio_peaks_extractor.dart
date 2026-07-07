import 'dart:io';
import 'dart:typed_data';

/// Injectable process launcher so tests can stand in for the real ffmpeg
/// (mirrors VideoProcessStarter).
typedef AudioProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

Future<Process> _startProcess(String executable, List<String> arguments) =>
    Process.start(executable, arguments);

/// Downsampled |peak| envelope of one audio file: [bucketsPerSecond]
/// buckets, each the maximum absolute amplitude (0..1) of its slice — what
/// the waveform strips paint and where clip durations come from.
class AudioPeaks {
  const AudioPeaks({required this.bucketsPerSecond, required this.peaks});

  final int bucketsPerSecond;
  final Float32List peaks;

  double get durationSeconds =>
      bucketsPerSecond <= 0 ? 0 : peaks.length / bucketsPerSecond;

  /// Whole frames the clip covers at [fps] (at least 1 for non-empty audio).
  int durationFrames(int fps) {
    final frames = (durationSeconds * fps).ceil();
    return frames < 1 ? 1 : frames;
  }
}

/// Decodes an audio file to mono PCM through the external `ffmpeg` (same
/// PATH contract as the video export) and folds it into [AudioPeaks].
/// Returns null when ffmpeg is missing, the file cannot be decoded or the
/// stream is empty — waveform display simply stays absent.
class AudioPeaksExtractor {
  const AudioPeaksExtractor({
    this.executable = 'ffmpeg',
    this.processStarter = _startProcess,
    this.sampleRate = 8000,
    this.bucketsPerSecond = 80,
  });

  final String executable;
  final AudioProcessStarter processStarter;
  final int sampleRate;
  final int bucketsPerSecond;

  Future<AudioPeaks?> extract(String filePath) async {
    final Process process;
    try {
      process = await processStarter(executable, [
        '-v',
        'error',
        '-i',
        filePath,
        '-ac',
        '1',
        '-ar',
        '$sampleRate',
        '-f',
        's16le',
        '-',
      ]);
    } on ProcessException {
      return null;
    }

    // Drain stderr so the process never blocks on a full pipe.
    final stderrDone = process.stderr.drain<void>();

    final samplesPerBucket = sampleRate ~/ bucketsPerSecond;
    final peaks = <double>[];
    var bucketMax = 0;
    var bucketCount = 0;
    var pendingByte = -1;

    await for (final chunk in process.stdout) {
      var offset = 0;
      if (pendingByte >= 0 && chunk.isNotEmpty) {
        final sample = (pendingByte | (chunk[0] << 8)).toSigned(16);
        bucketMax = sample.abs() > bucketMax ? sample.abs() : bucketMax;
        bucketCount += 1;
        if (bucketCount == samplesPerBucket) {
          peaks.add(bucketMax / 32768);
          bucketMax = 0;
          bucketCount = 0;
        }
        pendingByte = -1;
        offset = 1;
      }
      final even = offset + ((chunk.length - offset) & ~1);
      for (var index = offset; index < even; index += 2) {
        final sample = (chunk[index] | (chunk[index + 1] << 8)).toSigned(16);
        bucketMax = sample.abs() > bucketMax ? sample.abs() : bucketMax;
        bucketCount += 1;
        if (bucketCount == samplesPerBucket) {
          peaks.add(bucketMax / 32768);
          bucketMax = 0;
          bucketCount = 0;
        }
      }
      if (even < chunk.length) {
        pendingByte = chunk[chunk.length - 1];
      }
    }
    if (bucketCount > 0) {
      peaks.add(bucketMax / 32768);
    }

    final exitCode = await process.exitCode;
    await stderrDone;
    if (exitCode != 0 || peaks.isEmpty) {
      return null;
    }
    return AudioPeaks(
      bucketsPerSecond: bucketsPerSecond,
      peaks: Float32List.fromList(peaks),
    );
  }
}
