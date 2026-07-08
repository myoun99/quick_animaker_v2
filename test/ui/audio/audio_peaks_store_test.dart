import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_peaks_extractor.dart';
import 'package:quick_animaker_v2/src/ui/audio/audio_peaks_store.dart';

final _peaks = AudioPeaks(
  bucketsPerSecond: 80,
  peaks: Float32List.fromList(List.filled(80, 0.5)),
);

class _StubExtractor extends AudioPeaksExtractor {
  const _StubExtractor(this._extract);

  final Future<AudioPeaksExtraction> Function(String filePath) _extract;

  @override
  Future<AudioPeaksExtraction> extract(String filePath) => _extract(filePath);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('a failed path retries after the delay, up to the attempt cap', () async {
    var calls = 0;
    final logs = <String>[];
    var now = DateTime.utc(2026, 7, 9);
    final store = AudioPeaksStore(
      extractor: _StubExtractor((_) async {
        calls += 1;
        return const AudioPeaksExtraction.failure('ffmpeg missing');
      }),
      now: () => now,
      maxAttempts: 3,
      retryDelay: const Duration(seconds: 2),
      log: logs.add,
    );
    addTearDown(store.dispose);

    // First attempt fails; a paint straight after stays gated.
    expect(store.peaksFor('a.wav'), isNull);
    await _settle();
    expect(calls, 1);
    expect(store.failureFor('a.wav'), 'ffmpeg missing');
    store.peaksFor('a.wav');
    await _settle();
    expect(calls, 1);

    // After the delay a paint retries — twice more up to the cap.
    now = now.add(const Duration(seconds: 3));
    store.peaksFor('a.wav');
    await _settle();
    expect(calls, 2);

    now = now.add(const Duration(seconds: 3));
    store.peaksFor('a.wav');
    await _settle();
    expect(calls, 3);

    // The cap holds no matter how much time passes.
    now = now.add(const Duration(hours: 1));
    store.peaksFor('a.wav');
    await _settle();
    expect(calls, 3);

    // Every failure was logged with the extractor's reason.
    expect(logs, hasLength(3));
    expect(logs.first, contains('ffmpeg missing'));
    expect(logs.first, contains('a.wav'));
  });

  test('a retry that succeeds clears the failure', () async {
    var calls = 0;
    var now = DateTime.utc(2026, 7, 9);
    final store = AudioPeaksStore(
      extractor: _StubExtractor((_) async {
        calls += 1;
        return calls == 1
            ? const AudioPeaksExtraction.failure('file busy')
            : AudioPeaksExtraction.success(_peaks);
      }),
      now: () => now,
      log: (_) {},
    );
    addTearDown(store.dispose);

    store.peaksFor('a.wav');
    await _settle();
    expect(store.failureFor('a.wav'), 'file busy');

    now = now.add(const Duration(seconds: 3));
    store.peaksFor('a.wav');
    await _settle();
    expect(store.peaksFor('a.wav'), same(_peaks));
    expect(store.failureFor('a.wav'), isNull);
  });

  test('retryFailures rearms exhausted paths', () async {
    var calls = 0;
    var now = DateTime.utc(2026, 7, 9);
    final store = AudioPeaksStore(
      extractor: _StubExtractor((_) async {
        calls += 1;
        return const AudioPeaksExtraction.failure('ffmpeg missing');
      }),
      now: () => now,
      maxAttempts: 1,
      log: (_) {},
    );
    addTearDown(store.dispose);

    store.peaksFor('a.wav');
    await _settle();
    now = now.add(const Duration(hours: 1));
    store.peaksFor('a.wav');
    await _settle();
    expect(calls, 1); // capped

    store.retryFailures();
    store.peaksFor('a.wav');
    await _settle();
    expect(calls, 2);
  });

  test('an extractor that throws is treated as a failure, not a crash', () async {
    final store = AudioPeaksStore(
      extractor: _StubExtractor((_) async => throw StateError('boom')),
      log: (_) {},
    );
    addTearDown(store.dispose);

    store.peaksFor('a.wav');
    await _settle();
    expect(store.failureFor('a.wav'), contains('boom'));
  });
}
