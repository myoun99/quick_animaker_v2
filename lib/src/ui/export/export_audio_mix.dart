/// The export audio mix (EXPORT-AUDIO round): the SAME mixer that carries
/// playback renders the file.
///
/// Until this round, export audio went through an ffmpeg filter graph —
/// a SECOND mixer, with its own fade curves and its own rounding. Two
/// mixers is how a preview ends up telling a small lie about the render.
/// Now the schedule is mixed by our own reference (block by block, 64-bit
/// bus, output-stage clipping — everything the parity tests pin) into one
/// plain WAV, and ffmpeg's only audio job left is encoding that PCM.
///
/// The Dart reference mixes here on purpose, not the FFI path: this is an
/// offline render where determinism and simplicity beat throughput, and
/// the byte-parity contract makes the choice inaudible by construction.
library;

import 'dart:io';
import 'dart:typed_data';

import '../../models/project_frame_rate.dart';
import '../../services/audio/audio_mixer_reference.dart';
import '../playback/audio_playback_schedule.dart'
    show ScheduledAudioClip, audioMixScheduleFrom;

/// Resolves one source's conformed PCM (at the mix's own sample rate), or
/// null when it cannot be had — that clip renders silent, the export goes
/// on (a missing sound must not kill a deadline render; the log says so).
typedef ExportAudioSourceResolver =
    Future<AudioMixSource?> Function(String filePath);

/// Renders [schedule] to an int16 stereo WAV at [outputPath].
///
/// Returns false when there is nothing audible (empty schedule or no
/// resolvable source) — the caller then runs a video-only encode instead
/// of muxing a silent track.
///
/// The length is EXACTLY [totalFrames] of video time, sample-converted
/// with the same `frameToSample` pairing the clock uses; ffmpeg's
/// `-shortest` then has nothing to trim.
Future<bool> writeExportAudioMixWav({
  required List<ScheduledAudioClip> schedule,
  required ProjectFrameRate rate,
  required int totalFrames,
  required int sampleRate,
  required ExportAudioSourceResolver resolveSource,
  required String outputPath,
  int channels = 2,
  void Function(String message)? log,
}) async {
  if (schedule.isEmpty || totalFrames <= 0) {
    return false;
  }
  final mix = audioMixScheduleFrom(
    schedule: schedule,
    rate: rate,
    sampleRate: sampleRate,
  );
  final sources = <AudioMixSource>[];
  final resolvedIndexByOriginal = <int, int>{};
  for (var index = 0; index < mix.sourcePaths.length; index += 1) {
    final path = mix.sourcePaths[index];
    final source = await resolveSource(path);
    if (source == null) {
      log?.call(
        '[export audio] no decodable source for $path — that clip renders '
        'silent',
      );
      continue;
    }
    resolvedIndexByOriginal[index] = sources.length;
    sources.add(source);
  }
  if (sources.isEmpty) {
    return false;
  }
  final clips = [
    for (final clip in mix.clips)
      if (resolvedIndexByOriginal.containsKey(clip.sourceIndex))
        AudioMixClip(
          sourceIndex: resolvedIndexByOriginal[clip.sourceIndex]!,
          startSample: clip.startSample,
          endSample: clip.endSample,
          sourceOffset: clip.sourceOffset,
          gain: clip.gain,
          fadeInSamples: clip.fadeInSamples,
          fadeOutSamples: clip.fadeOutSamples,
        ),
  ];

  final totalSamples = rate.frameToSample(totalFrames, sampleRate);
  final dataBytes = totalSamples * channels * 2;
  final sink = File(outputPath).openSync(mode: FileMode.write);
  try {
    sink.writeFromSync(_wavHeader(
      dataBytes: dataBytes,
      sampleRate: sampleRate,
      channels: channels,
    ));
    // Block-mixed so a long timeline never holds its whole bus in memory;
    // the buffers are reused across blocks.
    const blockSamples = 65536;
    final bus = Float64List(blockSamples * channels);
    final out = Int16List(blockSamples * channels);
    var position = 0;
    while (position < totalSamples) {
      final count = (totalSamples - position).clamp(0, blockSamples);
      final busView = count == blockSamples
          ? bus
          : Float64List.sublistView(bus, 0, count * channels);
      mixAudioReference(
        clips: clips,
        sources: sources,
        startSample: position,
        sampleCount: count,
        outChannels: channels,
        into: busView,
      );
      final outView = count == blockSamples
          ? out
          : Int16List.sublistView(out, 0, count * channels);
      audioBusToInt16(busView, into: outView);
      sink.writeFromSync(outView.buffer.asUint8List(
        outView.offsetInBytes,
        outView.lengthInBytes,
      ));
      position += count;
    }
  } finally {
    sink.closeSync();
  }
  return true;
}

/// A plain 44-byte PCM WAV header — sizes are exact because the mix length
/// is known before a single sample renders.
Uint8List _wavHeader({
  required int dataBytes,
  required int sampleRate,
  required int channels,
}) {
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var index = 0; index < text.length; index += 1) {
      header.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  const bytesPerSample = 2;
  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  header.setUint16(32, channels * bytesPerSample, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}
