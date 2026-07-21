import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../models/project_frame_rate.dart';
import '../../native/qa_video_encoder.dart';
import '../../services/audio/conform_wav_stream.dart';
import 'png_sequence_export_service.dart' show ExportWriteSummary;

/// Injectable process launcher so tests can stand in for the real ffmpeg.
typedef VideoProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

Future<Process> _startProcess(String executable, List<String> arguments) =>
    Process.start(executable, arguments);

/// Resolves the OS encoder for this run; null keeps the ffmpeg path.
/// Widget tests must never bind a real encoder — same gate the audio
/// device uses.
typedef VideoEncoderResolver = QaVideoEncoder? Function();

QaVideoEncoder? _defaultEncoderResolver() =>
    Platform.environment['FLUTTER_TEST'] == 'true'
        ? null
        : QaVideoEncoder.instance;

/// Internal: the OS encoder refused the JOB (no encoder MFT, bad open) —
/// distinct from failing midway, because refusing up front means the
/// ffmpeg fallback can still carry the run.
class _OsEncoderRefused implements Exception {
  const _OsEncoderRefused();
}

/// A video export failure with a user-presentable [message] (missing ffmpeg,
/// non-zero exit); the dialog shows it verbatim.
class VideoExportException implements Exception {
  const VideoExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Encodes rendered frames into an H.264/AAC MP4.
///
/// The OS encoder carries the run when it can (AUDIO-PRO R7): Media
/// Foundation on Windows, AVAssetWriter on Apple, NDK MediaCodec on
/// Android — hardware-backed, nothing to install, and the only path a
/// tablet has. RGBA goes straight in; no PNG encode, no pipe.
///
/// The ffmpeg pipe remains as the FALLBACK — Linux, an old binary, or an
/// OS whose encoder refuses the job. It must be installed and on PATH (or
/// injected via [executable]). Either path finalizes a playable partial
/// on cancel instead of leaving a corrupt file.
class VideoExportService {
  const VideoExportService({
    this.executable = 'ffmpeg',
    this.processStarter = _startProcess,
    this.encoderResolver = _defaultEncoderResolver,
  });

  final String executable;
  final VideoProcessStarter processStarter;
  final VideoEncoderResolver encoderResolver;

  /// The ffmpeg pad filter keeping H.264-required even dimensions; odd
  /// sizes gain one white pixel instead of failing the whole export.
  static const String _evenPadFilter =
      'pad=ceil(iw/2)*2:ceil(ih/2)*2:color=white';

  /// Builds the full ffmpeg argument list.
  ///
  /// Audio, when present, arrives as ONE finished WAV ([audioMixPath]) —
  /// already mixed by the same mixer that carries playback (EXPORT-AUDIO
  /// round). ffmpeg's whole audio job is `-c:a aac`: no seeks, no filter
  /// graph, no second mixer to disagree with the preview.
  ///
  /// The rate goes out as ffmpeg's own fraction (`24000/1001`), so a
  /// 23.976 project exports at exactly the rate it was authored at — not
  /// at a decimal ffmpeg would have to round.
  @visibleForTesting
  static List<String> buildFfmpegArguments({
    required ProjectFrameRate frameRate,
    required String outputFilePath,
    String? audioMixPath,
  }) {
    final args = <String>[
      '-y',
      '-f',
      'image2pipe',
      '-framerate',
      frameRate.ffmpegRateArgument,
      '-i',
      '-',
    ];
    if (audioMixPath == null) {
      return args..addAll([
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-vf',
        _evenPadFilter,
        '-crf',
        '18',
        outputFilePath,
      ]);
    }
    return args..addAll([
      '-i',
      audioMixPath,
      '-map',
      '0:v',
      '-map',
      '1:a',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-vf',
      _evenPadFilter,
      '-crf',
      '18',
      '-c:a',
      'aac',
      '-shortest',
      outputFilePath,
    ]);
  }

  Future<ExportWriteSummary> exportVideo({
    required int count,
    required Future<ui.Image?> Function(int index) renderImage,
    required String outputFilePath,
    required ProjectFrameRate frameRate,
    String? audioMixPath,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final encoder = encoderResolver();
    if (encoder != null && encoder.isSupported) {
      try {
        return await _exportViaOsEncoder(
          encoder: encoder,
          count: count,
          renderImage: renderImage,
          outputFilePath: outputFilePath,
          frameRate: frameRate,
          audioMixPath: audioMixPath,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
      } on _OsEncoderRefused {
        // The OS could not take the job (an N-edition Windows with no
        // codec pack, a refused format) — the ffmpeg path below still can.
      }
    }
    return _exportViaFfmpeg(
      count: count,
      renderImage: renderImage,
      outputFilePath: outputFilePath,
      frameRate: frameRate,
      audioMixPath: audioMixPath,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// The OS-encoder run: raw RGBA frames straight into the system H.264
  /// encoder, the mixed WAV read back in per-frame chunks and fed to the
  /// system AAC encoder — interleaved, so neither side buffers the track.
  Future<ExportWriteSummary> _exportViaOsEncoder({
    required QaVideoEncoder encoder,
    required int count,
    required Future<ui.Image?> Function(int index) renderImage,
    required String outputFilePath,
    required ProjectFrameRate frameRate,
    String? audioMixPath,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (count <= 0) {
      return (written: 0, processed: 0);
    }
    var processed = 0;
    var written = 0;

    // The first renderable frame decides the geometry.
    ui.Image? first;
    var index = 0;
    while (index < count) {
      if (isCancelled?.call() ?? false) {
        return (written: 0, processed: processed);
      }
      first = await renderImage(index);
      index += 1;
      processed += 1;
      onProgress?.call(processed, count);
      if (first != null) {
        break;
      }
    }
    if (first == null) {
      // Nothing rendered at all — same outcome the pipe path reports.
      throw const VideoExportException('video export: nothing rendered');
    }

    final audio = audioMixPath == null
        ? null
        : ConformWavStreamReader.open(audioMixPath);
    if (!encoder.open(
      path: outputFilePath,
      width: first.width,
      height: first.height,
      fpsNumerator: frameRate.numerator,
      fpsDenominator: frameRate.denominator,
      sampleRate: audio?.sampleRate ?? 0,
      channels: audio?.channels ?? 0,
    )) {
      first.dispose();
      audio?.close();
      throw const _OsEncoderRefused();
    }

    var audioCursor = 0;
    var failed = false;
    var cancelled = false;

    // Feeds the audio the timeline owes up to [frames] written frames —
    // the same frameToSample pairing the clock uses, so A and V cannot
    // disagree about where a frame sits.
    bool feedAudioUpTo(int frames) {
      final reader = audio;
      if (reader == null) {
        return true;
      }
      final target = frameRate.frameToSample(frames, reader.sampleRate);
      while (audioCursor < target) {
        final window = reader.readWindow(
          audioCursor,
          math.min(target - audioCursor, 65536),
        );
        if (window.samples.isEmpty) {
          // Past the WAV's end (a cancelled mix, a rounding tail): pad
          // with silence rather than starving the encoder.
          final missing = target - audioCursor;
          if (!encoder.writeAudio(
            Int16List(missing * reader.channels),
            missing,
          )) {
            return false;
          }
          audioCursor = target;
          return true;
        }
        final frameCount = window.samples.length ~/ reader.channels;
        final pcm = Int16List(window.samples.length);
        for (var i = 0; i < window.samples.length; i += 1) {
          // The exact inverse of the WAV decode's /32768 — lossless.
          var value = (window.samples[i] * 32768.0).round();
          if (value > 32767) {
            value = 32767;
          } else if (value < -32768) {
            value = -32768;
          }
          pcm[i] = value;
        }
        if (!encoder.writeAudio(pcm, frameCount)) {
          return false;
        }
        audioCursor += frameCount;
      }
      return true;
    }

    Future<bool> feed(ui.Image image) async {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) {
        return false;
      }
      if (!encoder.writeFrame(data.buffer.asUint8List())) {
        return false;
      }
      written += 1;
      return feedAudioUpTo(written);
    }

    if (!await feed(first)) {
      failed = true;
    }
    while (!failed && index < count) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      final image = await renderImage(index);
      index += 1;
      if (image != null && !await feed(image)) {
        failed = true;
        break;
      }
      processed += 1;
      onProgress?.call(processed, count);
    }
    audio?.close();

    if (failed) {
      final detail = encoder.lastError;
      encoder.abort();
      throw VideoExportException(
        detail.isEmpty ? 'video export: the OS encoder failed' : detail,
      );
    }
    // A cancelled run finalizes a playable partial — the pipe path's
    // behavior, kept.
    if (!encoder.finish() && !cancelled) {
      final detail = encoder.lastError;
      throw VideoExportException(
        detail.isEmpty ? 'video export: the MP4 failed to finalize' : detail,
      );
    }
    return (written: written, processed: processed);
  }

  Future<ExportWriteSummary> _exportViaFfmpeg({
    required int count,
    required Future<ui.Image?> Function(int index) renderImage,
    required String outputFilePath,
    required ProjectFrameRate frameRate,
    String? audioMixPath,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final Process process;
    try {
      process = await processStarter(
        executable,
        buildFfmpegArguments(
          frameRate: frameRate,
          outputFilePath: outputFilePath,
          audioMixPath: audioMixPath,
        ),
      );
    } on ProcessException {
      throw const VideoExportException(
        'ffmpeg not found — install FFmpeg and make sure it is on PATH.',
      );
    }

    final stderrTail = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach((chunk) {
          stderrTail.write(chunk);
          // Keep only the tail: ffmpeg logs a lot and only the last lines
          // explain a failure.
          const cap = 4000;
          if (stderrTail.length > cap * 2) {
            final kept = stderrTail.toString();
            stderrTail
              ..clear()
              ..write(kept.substring(kept.length - cap));
          }
        })
        .catchError((Object _) {});
    final stdoutDone = process.stdout.drain<void>().catchError((Object _) {});

    var written = 0;
    var processed = 0;
    var pipeBroken = false;
    var cancelled = false;
    for (var index = 0; index < count; index += 1) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      final image = await renderImage(index);
      if (image != null) {
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          process.stdin.add(bytes!.buffer.asUint8List());
          await process.stdin.flush();
          written += 1;
        } on Object {
          // ffmpeg died mid-stream (broken pipe); its stderr explains why.
          pipeBroken = true;
          break;
        } finally {
          image.dispose();
        }
      }
      processed += 1;
      onProgress?.call(processed, count);
    }

    if (cancelled && written == 0) {
      // Nothing was fed; an empty pipe makes ffmpeg exit with an error and
      // there is no partial video to finalize.
      process.kill();
      await process.exitCode;
      await stderrDone;
      await stdoutDone;
      return (written: written, processed: processed);
    }

    try {
      await process.stdin.close();
    } on Object {
      pipeBroken = true;
    }
    final exitCode = await process.exitCode;
    await stderrDone;
    await stdoutDone;

    // A cancelled run keeps whatever partial video ffmpeg finalized; only a
    // completed run that failed to encode is an error.
    if (!cancelled && (exitCode != 0 || pipeBroken)) {
      final tail = stderrTail.toString().trim();
      final lines = tail.isEmpty
          ? 'no ffmpeg output'
          : (tail.split('\n')..removeWhere((line) => line.trim().isEmpty))
                .reversed
                .take(3)
                .toList()
                .reversed
                .join('\n');
      throw VideoExportException('ffmpeg failed (exit $exitCode): $lines');
    }
    return (written: written, processed: processed);
  }
}
