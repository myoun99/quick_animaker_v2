/// Import → conform (audio program 2B, final wiring).
///
/// What happens when a sound enters a project, in the order professional
/// tools do it: the original is copied in beside the project, decoded once,
/// resampled to the project rate, and written back out as plain PCM. From
/// then on nothing reads the original — playback reads the conform.
///
/// This is what makes the audio callback able to promise anything. A
/// compressed codec decodes in variable time and cannot be asked to finish
/// inside a realtime buffer; a conform is `memcpy`. Pro Tools makes you
/// convert on import, Premiere writes a `.cfa`, Avid transcodes to MXF —
/// all the same move.
///
/// Layout, beside the `.qap` rather than inside it (user decision,
/// 2026-07-21): the project file stays light, and the parts that CAN be
/// regenerated are visibly separate from the parts that cannot.
///
/// ```
/// 프로젝트.qap
/// 프로젝트.assets/
///   Media/      대사.m4a      the original — deleting this loses work
///   Conformed/  대사.m4a.wav  regenerable; deleting it costs only time
/// ```
///
/// `Media/` sits under the save directory, so the .qap's existing
/// relative-path manifest picks it up for free and a folder moved to
/// another machine relinks itself.
library;

import 'dart:io';
import 'dart:typed_data';

import 'audio_peaks_extractor.dart';
import 'conform_wav_codec.dart';

/// Decodes container bytes to PCM at the file's own rate. The native
/// dr_libs path supplies this; tests supply a fake so the pipeline's logic
/// is exercised without a binary.
typedef AudioDecodeCallback =
    ({Float32List samples, int channels, int sampleRate})? Function(
      Uint8List bytes,
    );

/// Converts PCM to the project rate. The native polyphase resampler
/// supplies this.
typedef AudioResampleCallback =
    Float32List Function({
      required Float32List samples,
      required int channels,
      required int inputRate,
      required int outputRate,
    });

/// Why a conform attempt ended the way it did — enough for a log line that
/// explains itself, instead of a silent missing waveform.
enum ConformOutcome {
  /// Freshly decoded, resampled and written.
  built,

  /// An existing conform still matched the source, so nothing was redone.
  reused,

  /// The source could not be read at all.
  sourceMissing,

  /// No decoder recognized the container.
  undecodable,

  /// Writing failed (permissions, full disk, a cloud folder mid-sync).
  writeFailed,
}

class ConformResult {
  const ConformResult({
    required this.outcome,
    this.conformPath,
    this.peaks,
    this.channels = 0,
    this.sampleRate = 0,
    this.frames = 0,
    this.error,
  });

  final ConformOutcome outcome;
  final String? conformPath;

  /// Computed from the conformed PCM, so waveforms no longer need ffmpeg —
  /// which is why they have never appeared on a tablet.
  final AudioPeaks? peaks;

  final int channels;
  final int sampleRate;

  /// Samples per channel.
  final int frames;

  final String? error;

  bool get isUsable =>
      outcome == ConformOutcome.built || outcome == ConformOutcome.reused;
}

/// Where a project's imported media and conforms live.
class ProjectAssetLayout {
  const ProjectAssetLayout(this.projectFilePath);

  /// The `.qap` this layout belongs to.
  final String projectFilePath;

  static String _withoutExtension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final dot = normalized.lastIndexOf('.');
    return dot > slash ? normalized.substring(0, dot) : normalized;
  }

  /// `<project>.assets` — beside the file, not inside it.
  String get assetsDirectory => '${_withoutExtension(projectFilePath)}.assets';

  /// Originals. Deleting this loses work; the name says so.
  String get mediaDirectory => '$assetsDirectory/Media';

  /// Conforms. Regenerable — deleting it costs time, not content.
  String get conformedDirectory => '$assetsDirectory/Conformed';

  /// The conform for [mediaPath], derived by rule rather than recorded in
  /// the project. Nothing to keep in sync, and `project.json` stays small.
  String conformPathFor(String mediaPath) {
    final normalized = mediaPath.replaceAll('\\', '/');
    final name = normalized.substring(normalized.lastIndexOf('/') + 1);
    return '$conformedDirectory/$name.wav';
  }
}

/// Builds and reuses conforms.
///
/// Every file operation goes through injectable seams so the whole thing
/// is testable without touching a disk — the pipeline's decisions (is this
/// stale? what name avoids a collision?) are the part worth pinning, and
/// they should not need a temp directory to check.
class AudioConformPipeline {
  const AudioConformPipeline({
    required this.decode,
    required this.resample,
    this.projectSampleRate = 48000,
    this.bucketsPerSecond = 40,
  });

  final AudioDecodeCallback decode;
  final AudioResampleCallback resample;
  final int projectSampleRate;
  final int bucketsPerSecond;

  /// The fingerprint [sourcePath] currently has, or null when it is gone.
  static ConformSourceFingerprint? fingerprintOf(String sourcePath) {
    try {
      final file = File(sourcePath);
      if (!file.existsSync()) {
        return null;
      }
      final stat = file.statSync();
      return ConformSourceFingerprint(
        sourceLength: stat.size,
        sourceModifiedMicros: stat.modified.microsecondsSinceEpoch,
      );
    } on Object {
      return null;
    }
  }

  /// A name inside [directory] that no existing file claims: `x.wav`,
  /// then `x-1.wav`, `x-2.wav`. Pro Tools does the same on import, and the
  /// alternative is one sound silently overwriting another.
  static String uniqueNameIn(
    String directory,
    String fileName, {
    bool Function(String path)? exists,
  }) {
    final taken = exists ?? (path) => File(path).existsSync();
    if (!taken('$directory/$fileName')) {
      return fileName;
    }
    final dot = fileName.lastIndexOf('.');
    final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
    final extension = dot <= 0 ? '' : fileName.substring(dot);
    for (var index = 1; index < 10000; index += 1) {
      final candidate = '$stem-$index$extension';
      if (!taken('$directory/$candidate')) {
        return candidate;
      }
    }
    return fileName;
  }

  /// Ensures a usable conform exists for [sourcePath] at [conformPath].
  ///
  /// Reuses the existing one when its recorded fingerprint still matches
  /// the source. A conform with NO fingerprint counts as stale on purpose:
  /// it was not written by us, nothing is known about where it came from,
  /// and guessing wrong plays the wrong sound against someone's drawing.
  ConformResult ensureConform({
    required String sourcePath,
    required String conformPath,
  }) {
    final fingerprint = fingerprintOf(sourcePath);
    if (fingerprint == null) {
      return const ConformResult(
        outcome: ConformOutcome.sourceMissing,
        error: 'the source file is missing',
      );
    }

    final existing = _readConform(conformPath);
    if (existing != null && conformMatchesSource(existing, fingerprint)) {
      return ConformResult(
        outcome: ConformOutcome.reused,
        conformPath: conformPath,
        peaks: peaksFromSamples(
          samples: existing.samples,
          channels: existing.channels,
          sampleRate: existing.sampleRate,
          bucketsPerSecond: bucketsPerSecond,
        ),
        channels: existing.channels,
        sampleRate: existing.sampleRate,
        frames: existing.length,
      );
    }

    final Uint8List sourceBytes;
    try {
      sourceBytes = File(sourcePath).readAsBytesSync();
    } on Object catch (error) {
      return ConformResult(
        outcome: ConformOutcome.sourceMissing,
        error: 'could not read the source: $error',
      );
    }

    final decoded = decode(sourceBytes);
    if (decoded == null || decoded.channels <= 0 || decoded.sampleRate <= 0) {
      return const ConformResult(
        outcome: ConformOutcome.undecodable,
        error: 'no decoder recognized this file',
      );
    }

    // Equal rates skip the filter entirely and stay bit-exact — most SE
    // libraries and dialogue are already at the project rate, so this is
    // the common path.
    final converted = decoded.sampleRate == projectSampleRate
        ? decoded.samples
        : resample(
            samples: decoded.samples,
            channels: decoded.channels,
            inputRate: decoded.sampleRate,
            outputRate: projectSampleRate,
          );

    try {
      final directory = conformPath.substring(
        0,
        conformPath.replaceAll('\\', '/').lastIndexOf('/'),
      );
      Directory(directory).createSync(recursive: true);
      File(conformPath).writeAsBytesSync(
        encodeConformWav(
          samples: converted,
          channels: decoded.channels,
          sampleRate: projectSampleRate,
          fingerprint: fingerprint,
        ),
      );
    } on Object catch (error) {
      return ConformResult(
        outcome: ConformOutcome.writeFailed,
        error: 'could not write the conform: $error',
      );
    }

    return ConformResult(
      outcome: ConformOutcome.built,
      conformPath: conformPath,
      peaks: peaksFromSamples(
        samples: converted,
        channels: decoded.channels,
        sampleRate: projectSampleRate,
        bucketsPerSecond: bucketsPerSecond,
      ),
      channels: decoded.channels,
      sampleRate: projectSampleRate,
      frames: decoded.channels <= 0
          ? 0
          : converted.length ~/ decoded.channels,
    );
  }

  ConformAudio? _readConform(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      return decodeConformWav(file.readAsBytesSync());
    } on Object {
      // An unreadable or foreign conform is simply rebuilt.
      return null;
    }
  }
}
