import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_conform_pipeline.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_conform_runner.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_peaks_extractor.dart';
import 'package:quick_animaker_v2/src/ui/audio/audio_conform_store.dart';
import 'package:quick_animaker_v2/src/ui/audio/audio_peaks_store.dart';

class _StubFallbackExtractor extends AudioPeaksExtractor {
  const _StubFallbackExtractor();

  @override
  Future<AudioPeaksExtraction> extract(String filePath) async =>
      AudioPeaksExtraction.success(
        AudioPeaks(
          bucketsPerSecond: 80,
          peaks: Float32List.fromList([0.5, 0.25]),
        ),
      );
}

ConformResult _usableResult() => ConformResult(
  outcome: ConformOutcome.built,
  conformPath: '/tmp/conformed/a.wav.wav',
  peaks: AudioPeaks(
    bucketsPerSecond: 80,
    peaks: Float32List.fromList([1.0]),
  ),
  samples: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
  channels: 2,
  sampleRate: 48000,
  frames: 2,
);

void main() {
  test('kicks ONE conform per path, caches the landed result and notifies '
      'listeners', () async {
    final requests = <ConformRequest>[];
    final store = AudioConformStore(
      resolveConformPath: (path) => '/tmp/conformed/$path.wav',
      runner: (request) async {
        requests.add(request);
        return _usableResult();
      },
      log: (_) {},
    );
    var notified = 0;
    store.addListener(() => notified += 1);

    expect(store.resultFor('a.wav'), isNull);
    expect(store.resultFor('a.wav'), isNull); // pending — no second kick
    await pumpEventQueue();

    expect(requests, hasLength(1));
    expect(requests.single.conformPath, '/tmp/conformed/a.wav.wav');
    expect(notified, 1);
    expect(store.resultFor('a.wav')?.isUsable, isTrue);
    expect(store.samplesFor('a.wav'), hasLength(4));
    expect(store.peaksFor('a.wav')?.peaks, hasLength(1));
    // Duration comes from the EXACT sample count, not the peaks buckets.
    expect(store.durationSecondsFor('a.wav'), 2 / 48000);
    store.dispose();
  });

  test('undecodable is a definitive answer: no retry, waveform and duration '
      'delegate to the ffmpeg fallback', () async {
    var runs = 0;
    final fallback = AudioPeaksStore(
      extractor: const _StubFallbackExtractor(),
      log: (_) {},
    );
    final store = AudioConformStore(
      resolveConformPath: (_) => null,
      runner: (request) async {
        runs += 1;
        return const ConformResult(
          outcome: ConformOutcome.undecodable,
          error: 'no decoder recognized this file',
        );
      },
      undecodableFallback: fallback,
      log: (_) {},
    );

    store.resultFor('voice.m4a');
    await pumpEventQueue();
    expect(runs, 1);
    expect(store.resultFor('voice.m4a')?.outcome, ConformOutcome.undecodable);

    // peaksFor routes to the fallback (which resolves async on its own).
    expect(store.peaksFor('voice.m4a'), isNull);
    await pumpEventQueue();
    expect(store.peaksFor('voice.m4a')?.peaks, hasLength(2));
    expect(store.durationSecondsFor('voice.m4a'), 2 / 80);
    expect(runs, 1); // still no reconform
    store.dispose();
    fallback.dispose();
  });

  test('transient failures retry on a fresh lookup after the delay, up to '
      'the attempt budget', () async {
    var runs = 0;
    var now = DateTime(2026, 7, 21);
    final store = AudioConformStore(
      resolveConformPath: (_) => null,
      runner: (request) async {
        runs += 1;
        return const ConformResult(
          outcome: ConformOutcome.sourceMissing,
          error: 'the source file is missing',
        );
      },
      now: () => now,
      log: (_) {},
    );

    store.resultFor('gone.wav');
    await pumpEventQueue();
    expect(runs, 1);

    // Inside the delay: gated.
    store.resultFor('gone.wav');
    await pumpEventQueue();
    expect(runs, 1);

    // Past the delay: retries — twice more, then the budget is spent.
    now = now.add(const Duration(seconds: 3));
    store.resultFor('gone.wav');
    await pumpEventQueue();
    expect(runs, 2);
    now = now.add(const Duration(seconds: 3));
    store.resultFor('gone.wav');
    await pumpEventQueue();
    expect(runs, 3);
    now = now.add(const Duration(seconds: 3));
    store.resultFor('gone.wav');
    await pumpEventQueue();
    expect(runs, 3);

    // invalidate() grants a fresh budget.
    store.invalidate('gone.wav');
    store.resultFor('gone.wav');
    await pumpEventQueue();
    expect(runs, 4);
    store.dispose();
  });

  test('samplesAtRate: the project rate is the samples themselves; another '
      'rate kicks ONE async conversion and serves it once landed', () async {
    final resampled = <(int, int)>[];
    final store = AudioConformStore(
      resolveConformPath: (_) => null,
      runner: (request) async => _usableResult(),
      resampleRunner: (request) async {
        resampled.add((request.inputRate, request.outputRate));
        return Float32List.fromList([0.9]);
      },
      log: (_) {},
    );
    store.resultFor('a.wav');
    await pumpEventQueue();

    // Project rate: the conform PCM itself, no conversion.
    expect(store.samplesAtRate('a.wav', 48000), hasLength(4));
    expect(resampled, isEmpty);

    // Device rate mismatch: null now (the transport stands down this run),
    // conversion kicked once, served after it lands.
    expect(store.samplesAtRate('a.wav', 44100), isNull);
    expect(store.samplesAtRate('a.wav', 44100), isNull);
    await pumpEventQueue();
    expect(resampled, [(48000, 44100)]);
    expect(store.samplesAtRate('a.wav', 44100), hasLength(1));
    store.dispose();
  });

  test('warmPaths kicks every unknown path once', () async {
    final seen = <String>[];
    final store = AudioConformStore(
      resolveConformPath: (_) => null,
      runner: (request) async {
        seen.add(request.sourcePath);
        return _usableResult();
      },
      log: (_) {},
    );
    store.warmPaths(['a.wav', 'b.wav']);
    store.warmPaths(['a.wav']); // pending — not kicked again
    await pumpEventQueue();
    expect(seen, ['a.wav', 'b.wav']);
    store.dispose();
  });
}
