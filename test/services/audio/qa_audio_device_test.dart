import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/project_frame_rate.dart';
import 'package:quick_animaker_v2/src/native/qa_audio_device.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_mixer_reference.dart';

import '../../helpers/native_engine_path.dart';

/// The device stage, driven for real.
///
/// miniaudio's NULL backend runs the actual callback on an actual thread
/// with no hardware, so everything below is genuinely exercised on a CI
/// runner with no sound card: the transport advances, the mixer is called,
/// the position moves, looping wraps on the sample.
///
/// What this canNOT prove is that a real device produces audible sound in
/// the right speaker — that needs hardware and a person. The line is drawn
/// here on purpose rather than left implied.
void main() {
  final libraryPath = nativeEngineLibraryPathOrNull();
  final available = libraryPath != null;
  final skip = available ? false : nativeEngineMissingSkipReason;

  setUp(() {
    QaAudioDevice.debugResetForTests();
    QaAudioDevice.debugLibraryPathOverride = libraryPath;
  });

  tearDown(() {
    try {
      QaAudioDevice.instance?.close();
    } on Object {
      // A device that never opened is fine to "close".
    }
    QaAudioDevice.debugResetForTests();
    QaAudioDevice.debugLibraryPathOverride = null;
  });

  QaAudioDevice openNull({int sampleRate = 48000, int channels = 2}) {
    final device = QaAudioDevice.instance;
    expect(device, isNotNull, reason: 'the binary did not bind');
    final rate = device!.open(
      sampleRate: sampleRate,
      channels: channels,
      useNullBackend: true,
    );
    expect(rate, greaterThan(0), reason: 'the null device failed to open');
    return device;
  }

  /// Waits until [check] holds or the budget runs out. The callback runs
  /// on the device's own thread, so the test has to wait for real time
  /// rather than pump anything.
  Future<bool> waitFor(bool Function() check, {int millis = 3000}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: millis));
    while (DateTime.now().isBefore(deadline)) {
      if (check()) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return check();
  }

  AudioMixSource constantSource(double value, int frames, int channels) {
    final data = Float32List(frames * channels);
    for (var index = 0; index < data.length; index += 1) {
      data[index] = value;
    }
    return AudioMixSource(samples: data, channels: channels);
  }

  group('the device opens and reports itself', () {
    test('a null device opens, states its geometry, and closes', () {
      final device = openNull();
      expect(device.isOpen, isTrue);
      expect(device.sampleRate, 48000);
      expect(device.channels, 2);
      expect(
        device.latencySamples,
        greaterThan(0),
        reason: 'the latency report is what the picture gets pulled forward by',
      );
      device.close();
      expect(device.isOpen, isFalse);
    }, skip: skip);

    test('opening twice is idempotent rather than a second device', () {
      final device = openNull();
      expect(device.open(useNullBackend: true), device.sampleRate);
      expect(device.isOpen, isTrue);
    }, skip: skip);
  });

  group('the transport is the clock', () {
    test('the position advances only while playing', () async {
      final device = openNull();
      device.setSchedule(
        clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 480000)],
        sources: [constantSource(0.25, 48000, 2)],
      );

      expect(device.positionSamples, 0);
      expect(device.isPlaying, isFalse);

      device.play(startSample: 0);
      expect(await waitFor(() => device.positionSamples > 0), isTrue,
          reason: 'the callback never ran — the transport is not the clock');

      device.stop();
      final parked = device.positionSamples;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        device.positionSamples,
        parked,
        reason: 'a stopped transport must not keep counting',
      );
    }, skip: skip);

    test('playback starts where it is told, not at zero', () async {
      final device = openNull();
      device.setSchedule(
        clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 480000)],
        sources: [constantSource(0.25, 48000, 2)],
      );
      const start = 96000;
      device.play(startSample: start);
      expect(
        await waitFor(() => device.positionSamples > start),
        isTrue,
      );
      expect(device.positionSamples, greaterThanOrEqualTo(start));
    }, skip: skip);

    test('a seek moves the transport without restarting anything', () async {
      // Because the mixer BUILDS a mix rather than starting clips, seeking
      // is just a change of where the next block is read from.
      final device = openNull();
      device.setSchedule(
        clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 4800000)],
        sources: [constantSource(0.25, 48000, 2)],
      );
      device.play(startSample: 0);
      expect(await waitFor(() => device.positionSamples > 0), isTrue);

      device.seek(1000000);
      expect(
        await waitFor(() => device.positionSamples >= 1000000),
        isTrue,
      );
      expect(device.isPlaying, isTrue, reason: 'a seek must not stop playback');
    }, skip: skip);

    test('a stop point ends playback instead of running on', () async {
      final device = openNull();
      device.setSchedule(
        clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 48000)],
        sources: [constantSource(0.25, 48000, 2)],
      );
      device.play(startSample: 0, stopSample: 24000);
      expect(await waitFor(() => !device.isPlaying), isTrue);
      expect(
        device.positionSamples,
        greaterThanOrEqualTo(24000),
        reason: 'it should reach the stop point, not fall short',
      );
    }, skip: skip);

    test('looping wraps on the sample, not the buffer boundary', () async {
      // The wrap has to land exactly, or every loop pass would drift by up
      // to a buffer — which is how a long session ends up out of sync.
      final device = openNull();
      device.setSchedule(
        clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 48000)],
        sources: [constantSource(0.25, 48000, 2)],
      );
      device.play(startSample: 0, stopSample: 12000, looping: true);
      expect(await waitFor(() => device.positionSamples > 0), isTrue);
      // It must keep playing and stay inside the loop window.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(device.isPlaying, isTrue);
      expect(
        device.positionSamples,
        lessThanOrEqualTo(12000),
        reason: 'a looping transport must never leave its window',
      );
    }, skip: skip);
  });

  group('the schedule handoff', () {
    test('a schedule can be set while stopped', () {
      final device = openNull();
      expect(
        device.setSchedule(
          clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 100)],
          sources: [constantSource(0.5, 100, 2)],
        ),
        isTrue,
      );
    }, skip: skip);

    test('a schedule is REFUSED while playing, not raced', () async {
      // The realtime thread is reading these arrays. Refusing is the whole
      // reason the handoff needs no lock-free machinery.
      final device = openNull();
      device.setSchedule(
        clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 480000)],
        sources: [constantSource(0.25, 48000, 2)],
      );
      device.play(startSample: 0);
      expect(await waitFor(() => device.positionSamples > 0), isTrue);

      expect(
        device.setSchedule(
          clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 10)],
          sources: [constantSource(0.5, 10, 2)],
        ),
        isFalse,
        reason: 'changing the schedule under the callback would be a race',
      );
      device.stop();
      expect(
        device.setSchedule(
          clips: const [AudioMixClip(sourceIndex: 0, startSample: 0, endSample: 10)],
          sources: [constantSource(0.5, 10, 2)],
        ),
        isTrue,
        reason: 'and it must be allowed again once stopped',
      );
    }, skip: skip);

    test('an empty schedule plays silence rather than failing', () async {
      final device = openNull();
      expect(
        device.setSchedule(clips: const [], sources: const []),
        isTrue,
      );
      device.play(startSample: 0);
      expect(await waitFor(() => device.positionSamples > 0), isTrue,
          reason: 'the clock must run even with nothing to play');
    }, skip: skip);
  });

  group('position to frame', () {
    test('the picture is pulled forward by the reported latency', () {
      // The position counts what has been HANDED to the device; what is
      // being heard is that minus the buffer still in flight.
      const rate = ProjectFrameRate.integer(24);
      final frame = audioClockFrame(
        positionSamples: 48000, // one second queued
        latencySamples: 2000,
        extraOffsetSamples: 0,
        sampleRate: 48000,
        frameRateNumerator: rate.numerator,
        frameRateDenominator: rate.denominator,
      );
      expect(frame, (48000 - 2000) * 24 ~/ 48000);
    });

    test('the user offset moves it either way', () {
      int at(int offset) => audioClockFrame(
        positionSamples: 48000,
        latencySamples: 0,
        extraOffsetSamples: offset,
        sampleRate: 48000,
        frameRateNumerator: 24,
        frameRateDenominator: 1,
      );
      expect(at(0), 24);
      expect(at(48000), 48);
      expect(at(-24000), 12);
    });

    test('23.976 converts through the exact fraction', () {
      const rate = ProjectFrameRate.ntsc(24);
      final frame = audioClockFrame(
        positionSamples: 48000,
        latencySamples: 0,
        extraOffsetSamples: 0,
        sampleRate: 48000,
        frameRateNumerator: rate.numerator,
        frameRateDenominator: rate.denominator,
      );
      // One second at 23.976 is frame 23, not 24 — the pulldown rate is
      // genuinely slower and the clock must not round that away.
      expect(frame, 23);
    });

    test('a position before anything is heard clamps at zero', () {
      expect(
        audioClockFrame(
          positionSamples: 100,
          latencySamples: 2000,
          extraOffsetSamples: 0,
          sampleRate: 48000,
          frameRateNumerator: 24,
          frameRateDenominator: 1,
        ),
        0,
      );
    });

    test('nonsense geometry returns zero rather than dividing by it', () {
      expect(
        audioClockFrame(
          positionSamples: 48000,
          latencySamples: 0,
          extraOffsetSamples: 0,
          sampleRate: 0,
          frameRateNumerator: 24,
          frameRateDenominator: 1,
        ),
        0,
      );
    });
  });
}
