import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/project_frame_rate.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_mixer_reference.dart';
import 'package:quick_animaker_v2/src/services/audio/conform_wav_codec.dart';
import 'package:quick_animaker_v2/src/ui/export/export_audio_mix.dart';
import 'package:quick_animaker_v2/src/ui/playback/audio_playback_schedule.dart';

/// The export mix renderer: the same mixer that carries playback writes
/// the WAV, and the WAV says so — exact length, exact levels, output-stage
/// clipping, silence where a source could not be had.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qa-export-mix-test');
  });

  tearDown(() => directory.delete(recursive: true));

  const rate = ProjectFrameRate.integer(10);

  AudioMixSource constantSource(double value, int frames) {
    final samples = Float32List(frames);
    for (var index = 0; index < frames; index += 1) {
      samples[index] = value;
    }
    return AudioMixSource(samples: samples, channels: 1);
  }

  test('renders the schedule to EXACTLY the video length, at the level the '
      'preview played', () async {
    final path = '${directory.path}/mix.wav';
    final written = await writeExportAudioMixWav(
      schedule: const [
        ScheduledAudioClip(
          filePath: 'tone.wav',
          startFrame: 2,
          endFrameExclusive: 8,
        ),
      ],
      rate: rate,
      totalFrames: 10,
      sampleRate: 48000,
      resolveSource: (_) async => constantSource(0.5, 48000),
      outputPath: path,
    );
    expect(written, isTrue);

    final wav = decodeConformWav(File(path).readAsBytesSync());
    expect(wav.sampleRate, 48000);
    expect(wav.channels, 2);
    // 10 frames at 10fps/48k = one second exactly — nothing for ffmpeg's
    // -shortest to trim.
    expect(wav.length, 48000);
    // Before the clip: silence. Inside: the mono source on BOTH channels
    // at unity (0.5 survives the int16 round-trip bit-exactly). After:
    // silence again.
    expect(wav.samples[2 * 4800 * 2 - 2], 0);
    expect(wav.samples[5 * 4800 * 2], 0.5);
    expect(wav.samples[5 * 4800 * 2 + 1], 0.5);
    expect(wav.samples[9 * 4800 * 2], 0);
  });

  test('overlapping clips sum with headroom and clip at the OUTPUT stage — '
      'the same semantics playback mixes with', () async {
    final path = '${directory.path}/mix.wav';
    await writeExportAudioMixWav(
      schedule: const [
        ScheduledAudioClip(filePath: 'a', startFrame: 0, endFrameExclusive: 10),
        ScheduledAudioClip(filePath: 'a', startFrame: 0, endFrameExclusive: 10),
      ],
      rate: rate,
      totalFrames: 10,
      sampleRate: 48000,
      resolveSource: (_) async => constantSource(0.6, 48000),
      outputPath: path,
    );
    final wav = decodeConformWav(File(path).readAsBytesSync());
    // 0.6 + 0.6 = 1.2 on the bus; the int16 output stage clamps to just
    // under full scale (32767/32768).
    expect(wav.samples[24000], closeTo(32767 / 32768, 1e-6));
  });

  test('a fade-in ramps from silence exactly like the playback envelope',
      () async {
    final path = '${directory.path}/mix.wav';
    await writeExportAudioMixWav(
      schedule: const [
        ScheduledAudioClip(
          filePath: 'a',
          startFrame: 0,
          endFrameExclusive: 10,
          fadeInFrames: 5,
        ),
      ],
      rate: rate,
      totalFrames: 10,
      sampleRate: 48000,
      resolveSource: (_) async => constantSource(0.8, 48000),
      outputPath: path,
    );
    final wav = decodeConformWav(File(path).readAsBytesSync());
    expect(wav.samples[0], 0, reason: 'the ramp starts at silence');
    // Halfway through the 5-frame fade (~frame 2.5 = sample 12000): half
    // the level.
    expect(wav.samples[12000 * 2], closeTo(0.4, 0.01));
    // Past the fade: full level.
    expect(wav.samples[8 * 4800 * 2], closeTo(0.8, 0.001));
  });

  test('an unresolvable source renders ITS clip silent; nothing at all '
      'renders no file', () async {
    final path = '${directory.path}/mix.wav';
    final written = await writeExportAudioMixWav(
      schedule: const [
        ScheduledAudioClip(filePath: 'ok', startFrame: 0, endFrameExclusive: 5),
        ScheduledAudioClip(
          filePath: 'gone',
          startFrame: 5,
          endFrameExclusive: 10,
        ),
      ],
      rate: rate,
      totalFrames: 10,
      sampleRate: 48000,
      resolveSource: (filePath) async =>
          filePath == 'ok' ? constantSource(0.5, 48000) : null,
      outputPath: path,
      log: (_) {},
    );
    expect(written, isTrue);
    final wav = decodeConformWav(File(path).readAsBytesSync());
    expect(wav.samples[2 * 4800 * 2], 0.5);
    expect(wav.samples[7 * 4800 * 2], 0, reason: 'the missing clip is silent');

    expect(
      await writeExportAudioMixWav(
        schedule: const [
          ScheduledAudioClip(
            filePath: 'gone',
            startFrame: 0,
            endFrameExclusive: 5,
          ),
        ],
        rate: rate,
        totalFrames: 10,
        sampleRate: 48000,
        resolveSource: (_) async => null,
        outputPath: '${directory.path}/none.wav',
        log: (_) {},
      ),
      isFalse,
      reason: 'nothing audible means video-only encode, no silent track',
    );

    expect(
      await writeExportAudioMixWav(
        schedule: const [],
        rate: rate,
        totalFrames: 10,
        sampleRate: 48000,
        resolveSource: (_) async => null,
        outputPath: '${directory.path}/empty.wav',
      ),
      isFalse,
    );
  });
}
