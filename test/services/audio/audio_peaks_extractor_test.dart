import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_peaks_extractor.dart';

/// Stands in for ffmpeg decoding to PCM: emits [pcm] on stdout in small
/// odd-sized chunks (exercising the split-sample path) and exits with
/// [exitCodeValue].
class _FakePcmProcess implements Process {
  _FakePcmProcess(this.pcm, {this.exitCodeValue = 0, this.stderrText = ''});

  final Uint8List pcm;
  final int exitCodeValue;
  final String stderrText;

  @override
  Stream<List<int>> get stdout async* {
    // 3-byte chunks split s16 samples across chunk boundaries on purpose.
    for (var offset = 0; offset < pcm.length; offset += 3) {
      yield pcm.sublist(
        offset,
        offset + 3 > pcm.length ? pcm.length : offset + 3,
      );
    }
  }

  @override
  Stream<List<int>> get stderr => stderrText.isEmpty
      ? const Stream<List<int>>.empty()
      : Stream<List<int>>.value(utf8.encode(stderrText));

  @override
  Future<int> get exitCode => Future<int>.value(exitCodeValue);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Uint8List _pcm(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.view(bytes.buffer);
  for (var index = 0; index < samples.length; index += 1) {
    data.setInt16(index * 2, samples[index], Endian.little);
  }
  return bytes;
}

void main() {
  setUp(AudioPeaksExtractor.debugResetWorkingExecutable);

  test(
    'folds mono s16le into per-bucket |max| peaks across chunk splits',
    () async {
      // 1 second at 8000 Hz: silence for 0.5s, half amplitude for 0.5s.
      final samples = [...List.filled(4000, 0), ...List.filled(4000, -16384)];
      final extractor = AudioPeaksExtractor(
        executable: 'ffmpeg',
        processStarter: (executable, arguments) async {
          expect(executable, 'ffmpeg');
          expect(arguments, containsAllInOrder(['-ac', '1', '-ar', '8000']));
          return _FakePcmProcess(_pcm(samples));
        },
      );

      final peaks = (await extractor.extract('voice.wav')).peaks;

      expect(peaks, isNotNull);
      expect(peaks!.peaks, hasLength(80));
      expect(peaks.peaks.sublist(0, 40), everyElement(0));
      for (final peak in peaks.peaks.sublist(40)) {
        expect(peak, closeTo(0.5, 0.001));
      }
      expect(peaks.durationSeconds, closeTo(1.0, 0.001));
      expect(peaks.durationFrames(24), 24);
    },
  );

  test('a trailing partial bucket still lands', () async {
    // 150 samples = one full 100-sample bucket + a 50-sample tail.
    final extractor = AudioPeaksExtractor(
      executable: 'ffmpeg',
      processStarter: (_, _) async =>
          _FakePcmProcess(_pcm(List.filled(150, 3277))),
    );

    final result = await extractor.extract('short.wav');

    expect(result.peaks!.peaks, hasLength(2));
    expect(result.peaks!.peaks[1], closeTo(0.1, 0.001));
  });

  test('missing ffmpeg reports the tried candidates', () async {
    final missing = AudioPeaksExtractor(
      executableCandidates: () => ['ffmpeg'],
      processStarter: (_, _) async =>
          throw const ProcessException('ffmpeg', [], 'not found'),
    );

    final result = await missing.extract('x.wav');

    expect(result.peaks, isNull);
    expect(result.error, contains('could not start ffmpeg'));
    expect(result.error, contains('not found'));
  });

  test('decode failures carry the exit code and stderr tail', () async {
    final failed = AudioPeaksExtractor(
      executable: 'ffmpeg',
      processStarter: (_, _) async => _FakePcmProcess(
        Uint8List(0),
        exitCodeValue: 1,
        stderrText: 'x.wav: Invalid data found',
      ),
    );

    final result = await failed.extract('x.wav');

    expect(result.peaks, isNull);
    expect(result.error, contains('exited 1'));
    expect(result.error, contains('Invalid data found'));
  });

  test('an empty stream on a clean exit is still a failure', () async {
    final empty = AudioPeaksExtractor(
      executable: 'ffmpeg',
      processStarter: (_, _) async => _FakePcmProcess(Uint8List(0)),
    );

    final result = await empty.extract('silent.wav');

    expect(result.peaks, isNull);
    expect(result.error, contains('no audio samples'));
  });

  test('falls through PATH misses to the next candidate and remembers the '
      'winner', () async {
    final started = <String>[];
    final extractor = AudioPeaksExtractor(
      executableCandidates: () => [
        'ffmpeg',
        r'C:\Users\u\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe',
      ],
      processStarter: (executable, _) async {
        started.add(executable);
        if (executable == 'ffmpeg') {
          throw const ProcessException('ffmpeg', [], 'not on PATH');
        }
        return _FakePcmProcess(_pcm(List.filled(100, 16384)));
      },
    );

    final first = await extractor.extract('a.wav');
    expect(first.peaks, isNotNull);
    expect(started, [
      'ffmpeg',
      r'C:\Users\u\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe',
    ]);

    // The working candidate is tried first on the next extraction.
    started.clear();
    final second = await extractor.extract('b.wav');
    expect(second.peaks, isNotNull);
    expect(started, [
      r'C:\Users\u\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe',
    ]);
  });
}
