import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../models/project_frame_rate.dart';
import 'ffmpeg_locator.dart';

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

  /// Whole frames the clip covers at [rate] (at least 1 for non-empty
  /// audio).
  ///
  /// The length is exactly `peaks.length / bucketsPerSecond` seconds —
  /// a ratio of two integers — so the frame count is computed from that
  /// ratio directly. Going through [durationSeconds] as a double was how
  /// an exactly-2-second file at 24fps used to measure 49 frames.
  int durationFrames(ProjectFrameRate rate) {
    if (bucketsPerSecond <= 0) {
      return 1;
    }
    final frames = rate.framesCoveringExactSeconds(
      peaks.length,
      bucketsPerSecond,
    );
    return frames < 1 ? 1 : frames;
  }
}

/// The outcome of one extraction attempt: [peaks] on success, otherwise a
/// human-readable [error] (spawn failure per candidate, ffmpeg's stderr
/// tail, empty stream) so the store can log WHY a waveform is missing
/// instead of silently staying blank.
class AudioPeaksExtraction {
  const AudioPeaksExtraction.success(AudioPeaks this.peaks) : error = null;
  const AudioPeaksExtraction.failure(String this.error) : peaks = null;

  final AudioPeaks? peaks;
  final String? error;
}

/// Decodes an audio file to mono PCM through the external `ffmpeg` and folds
/// it into [AudioPeaks]. The executable resolves through
/// [ffmpegExecutableCandidates] (PATH first, then well-known install
/// locations a GUI app's inherited PATH tends to miss); the first candidate
/// that spawns is remembered for the rest of the app run.
class AudioPeaksExtractor {
  const AudioPeaksExtractor({
    this.executable,
    this.processStarter = _startProcess,
    this.sampleRate = 8000,
    this.bucketsPerSecond = 80,
    this.executableCandidates,
  });

  /// Explicit ffmpeg path; null resolves through
  /// [ffmpegExecutableCandidates].
  final String? executable;
  final AudioProcessStarter processStarter;
  final int sampleRate;
  final int bucketsPerSecond;

  /// Test seam for the candidate list; null uses the real locator.
  final List<String> Function()? executableCandidates;

  /// The candidate that spawned successfully last time — tried first so the
  /// probe list is walked at most once per app run.
  static String? _workingExecutable;

  /// Test-only: forgets the remembered working candidate.
  static void debugResetWorkingExecutable() => _workingExecutable = null;

  Future<AudioPeaksExtraction> extract(String filePath) async {
    final explicit = executable;
    final candidates = <String>{
      if (explicit != null)
        explicit
      else ...[
        ?_workingExecutable,
        ...(executableCandidates ?? ffmpegExecutableCandidates)(),
      ],
    };

    final spawnFailures = <String>[];
    for (final candidate in candidates) {
      final Process process;
      try {
        process = await processStarter(candidate, [
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
      } on ProcessException catch (error) {
        spawnFailures.add('$candidate (${error.message})');
        continue;
      }
      if (explicit == null) {
        _workingExecutable = candidate;
      }
      return _foldProcess(process, filePath);
    }
    return AudioPeaksExtraction.failure(
      'could not start ffmpeg — tried ${spawnFailures.join('; ')}. '
      'Install ffmpeg or make it reachable on PATH.',
    );
  }

  Future<AudioPeaksExtraction> _foldProcess(
    Process process,
    String filePath,
  ) async {
    // Keep the tail of stderr for diagnostics while still draining the pipe
    // so the process never blocks on it.
    final stderrTail = StringBuffer();
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          if (stderrTail.length < 2048) {
            stderrTail.write(chunk);
          }
        });

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
    final detail = stderrTail.isEmpty
        ? ''
        : ': ${stderrTail.toString().trim()}';
    if (exitCode != 0) {
      return AudioPeaksExtraction.failure(
        'ffmpeg exited $exitCode for $filePath$detail',
      );
    }
    if (peaks.isEmpty) {
      return AudioPeaksExtraction.failure(
        'ffmpeg decoded no audio samples from $filePath$detail',
      );
    }
    return AudioPeaksExtraction.success(
      AudioPeaks(
        bucketsPerSecond: bucketsPerSecond,
        peaks: Float32List.fromList(peaks),
      ),
    );
  }
}
