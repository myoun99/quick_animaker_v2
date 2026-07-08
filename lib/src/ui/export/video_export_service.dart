import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'png_sequence_export_service.dart' show ExportWriteSummary;

/// Injectable process launcher so tests can stand in for the real ffmpeg.
typedef VideoProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

Future<Process> _startProcess(String executable, List<String> arguments) =>
    Process.start(executable, arguments);

/// One SE audio clip laid on the exported video's timeline.
///
/// [seekSeconds] skips into the source (a clip that started before the
/// exported range), [delaySeconds] places it on the output timeline and
/// [durationSeconds] caps it at its cut's exported block — SE audio never
/// bleeds into the next cut, matching canvas playback. A source shorter
/// than the cap simply ends early.
class ExportAudioClip {
  const ExportAudioClip({
    required this.filePath,
    this.seekSeconds = 0,
    this.delaySeconds = 0,
    required this.durationSeconds,
  });

  final String filePath;
  final double seekSeconds;
  final double delaySeconds;
  final double durationSeconds;

  @override
  bool operator ==(Object other) =>
      other is ExportAudioClip &&
      other.filePath == filePath &&
      other.seekSeconds == seekSeconds &&
      other.delaySeconds == delaySeconds &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode =>
      Object.hash(filePath, seekSeconds, delaySeconds, durationSeconds);

  @override
  String toString() =>
      'ExportAudioClip(filePath: $filePath, seekSeconds: $seekSeconds, '
      'delaySeconds: $delaySeconds, durationSeconds: $durationSeconds)';
}

/// A video export failure with a user-presentable [message] (missing ffmpeg,
/// non-zero exit); the dialog shows it verbatim.
class VideoExportException implements Exception {
  const VideoExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Encodes rendered frames into an H.264 MP4 by piping PNGs into an external
/// `ffmpeg` process (image2pipe) — one frame rendered, encoded and released
/// at a time, mirroring [PngSequenceExportService]'s streaming shape.
///
/// ffmpeg is NOT bundled: it must be installed and on PATH (or injected via
/// [executable]). Cancelling closes the pipe early, so ffmpeg finalizes a
/// playable partial video instead of leaving a corrupt file.
class VideoExportService {
  const VideoExportService({
    this.executable = 'ffmpeg',
    this.processStarter = _startProcess,
  });

  final String executable;
  final VideoProcessStarter processStarter;

  /// The ffmpeg pad filter keeping H.264-required even dimensions; odd
  /// sizes gain one white pixel instead of failing the whole export.
  static const String _evenPadFilter =
      'pad=ceil(iw/2)*2:ceil(ih/2)*2:color=white';

  /// Builds the full ffmpeg argument list. Without [audioClips] this is the
  /// original video-only command; with clips, each file becomes an input
  /// (seeked/trimmed at the input) and a filter graph delays each onto the
  /// output timeline and mixes them (`normalize=0` keeps original volumes —
  /// needs ffmpeg ≥ 5.1). `-shortest` pins the output to the video length.
  @visibleForTesting
  static List<String> buildFfmpegArguments({
    required int fps,
    required String outputFilePath,
    List<ExportAudioClip> audioClips = const [],
  }) {
    String seconds(double value) => value.toStringAsFixed(3);

    final args = <String>[
      '-y',
      '-f',
      'image2pipe',
      '-framerate',
      '$fps',
      '-i',
      '-',
    ];
    if (audioClips.isEmpty) {
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

    for (final clip in audioClips) {
      if (clip.seekSeconds > 0) {
        args.addAll(['-ss', seconds(clip.seekSeconds)]);
      }
      args.addAll(['-t', seconds(clip.durationSeconds)]);
      args.addAll(['-i', clip.filePath]);
    }

    // -vf cannot coexist with -filter_complex, so the pad filter moves into
    // the graph alongside the audio chain.
    final filters = <String>['[0:v]$_evenPadFilter[vout]'];
    for (var index = 0; index < audioClips.length; index += 1) {
      final delayMs = (audioClips[index].delaySeconds * 1000).round();
      filters.add('[${index + 1}:a]adelay=$delayMs:all=1[a$index]');
    }
    final String audioOut;
    if (audioClips.length == 1) {
      audioOut = '[a0]';
    } else {
      audioOut = '[aout]';
      final labels = [
        for (var index = 0; index < audioClips.length; index += 1) '[a$index]',
      ].join();
      filters.add(
        '${labels}amix=inputs=${audioClips.length}:normalize=0$audioOut',
      );
    }

    return args..addAll([
      '-filter_complex',
      filters.join(';'),
      '-map',
      '[vout]',
      '-map',
      audioOut,
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
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
    required int fps,
    List<ExportAudioClip> audioClips = const [],
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final Process process;
    try {
      process = await processStarter(
        executable,
        buildFfmpegArguments(
          fps: fps,
          outputFilePath: outputFilePath,
          audioClips: audioClips,
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
