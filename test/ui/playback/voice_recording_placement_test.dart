import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_conform_pipeline.dart';
import 'package:quick_animaker_v2/src/services/audio/conform_wav_codec.dart';
import 'package:quick_animaker_v2/src/services/cut_frame_composite_plan.dart'
    show resolveExposedFrameAt;
import 'package:quick_animaker_v2/src/ui/audio/audio_conform_store.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/playback/audio_recorder.dart';

/// The landing half of guide-voice recording (AUDIO-PRO R5): a finished
/// take becomes a WAV in Media/, a pool entry, a carrier SE block at the
/// anchor frame and a linked clip — driven here with made recordings, the
/// microphone half being the real-DLL suite's job.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qa-voice-rec-test');
  });

  tearDown(() => directory.delete(recursive: true));

  EditorSessionManager session() => EditorSessionManager(
    initialProject: createDefaultProject(),
    audioConformStore: AudioConformStore(
      resolveConformPath: (_) => null,
      runner: (request) async => const ConformResult(
        outcome: ConformOutcome.undecodable,
        error: 'test stub',
      ),
      log: (_) {},
    ),
  );

  AudioRecording takeOfSeconds(
    double seconds, {
    int channels = 1,
    int sampleRate = 48000,
    int droppedFrames = 0,
  }) {
    final length = (seconds * sampleRate).round();
    final samples = Float32List(length * channels);
    for (var index = 0; index < samples.length; index += 1) {
      samples[index] = 0.25;
    }
    return AudioRecording(
      samples: samples,
      channels: channels,
      sampleRate: sampleRate,
      droppedFrames: droppedFrames,
    );
  }

  test('a take lands: WAV in Media/, pool entry, SE block, linked clip',
      () async {
    final manager = session();
    await manager.saveProjectToFile('${directory.path}/scene.qap');
    final cutId = manager.requireActiveCut.id;
    expect(manager.activeLayer?.kind, isNot(LayerKind.se),
        reason: 'the default active row is not SE — the placement must '
            'create its own carrier row');

    final placed = manager.placeVoiceRecording(
      takeOfSeconds(1.0),
      cutId: cutId,
      frameIndex: 0,
    );
    expect(placed, isTrue);

    final carrier = manager.activeLayer!;
    expect(carrier.kind, LayerKind.se);
    expect(carrier.audioClips, hasLength(1));
    final clip = carrier.audioClips.single;
    expect(clip.filePath, contains('.assets/Media/recording-'));
    expect(clip.filePath, endsWith('.wav'));
    expect(File(clip.filePath).existsSync(), isTrue);
    expect(
      manager.mediaAssets.map((asset) => asset.path),
      contains(clip.filePath),
    );

    // The WAV round-trips as a project-readable conform container with
    // the take inside, exactly as long as the recording.
    final decoded = decodeConformWav(
      File(clip.filePath).readAsBytesSync(),
    );
    expect(decoded.sampleRate, 48000);
    expect(decoded.channels, 1);
    expect(decoded.length, 48000);

    // The carrier block: at the anchor, covering the take (1 s @ 24 fps
    // = 24 frames, clamped into the cut's room).
    final frame = resolveExposedFrameAt(carrier, 0);
    expect(frame, isNotNull);
    expect(frame!.id, clip.frameId);
    manager.dispose();
  });

  test('recording along to playback trims the output latency off the head',
      () async {
    final manager = session();
    await manager.saveProjectToFile('${directory.path}/scene.qap');

    final placed = manager.placeVoiceRecording(
      takeOfSeconds(1.0),
      cutId: manager.requireActiveCut.id,
      frameIndex: 0,
      headTrimSamples: 12000, // 250 ms of monitoring delay
    );
    expect(placed, isTrue);
    final clip = manager.activeLayer!.audioClips.single;
    final decoded = decodeConformWav(File(clip.filePath).readAsBytesSync());
    expect(decoded.length, 48000 - 12000,
        reason: 'the performer spoke against delayed monitoring; the take '
            'shifts earlier by exactly that delay');
    manager.dispose();
  });

  test('a take shorter than the latency it rode on places nothing', () async {
    final manager = session();
    await manager.saveProjectToFile('${directory.path}/scene.qap');
    expect(
      manager.placeVoiceRecording(
        takeOfSeconds(0.1),
        cutId: manager.requireActiveCut.id,
        frameIndex: 0,
        headTrimSamples: 48000,
      ),
      isFalse,
    );
    manager.dispose();
  });

  test('an occupied anchor cell gets a NEW row — takes never overwrite',
      () async {
    final manager = session();
    await manager.saveProjectToFile('${directory.path}/scene.qap');
    final cutId = manager.requireActiveCut.id;

    expect(
      manager.placeVoiceRecording(takeOfSeconds(1.0), cutId: cutId,
          frameIndex: 0),
      isTrue,
    );
    final firstCarrier = manager.activeLayer!;
    expect(
      manager.placeVoiceRecording(takeOfSeconds(0.5), cutId: cutId,
          frameIndex: 0),
      isTrue,
    );
    final secondCarrier = manager.activeLayer!;
    expect(secondCarrier.id, isNot(firstCarrier.id),
        reason: 'the first take covers frame 0 on its row; the second '
            'must land on a row of its own');
    expect(secondCarrier.audioClips, hasLength(1));
    manager.dispose();
  });

  test('an unsaved project still records — the WAV degrades to temp, like '
      'an import', () {
    final manager = session();
    final placed = manager.placeVoiceRecording(
      takeOfSeconds(0.5),
      cutId: manager.requireActiveCut.id,
      frameIndex: 0,
    );
    expect(placed, isTrue);
    final clip = manager.activeLayer!.audioClips.single;
    expect(File(clip.filePath).existsSync(), isTrue);
    expect(clip.filePath, isNot(contains('.assets/Media/')));
    manager.dispose();
  });

  test('a vanished cut refuses the take rather than landing it anywhere',
      () async {
    final manager = session();
    await manager.saveProjectToFile('${directory.path}/scene.qap');
    expect(
      manager.placeVoiceRecording(
        takeOfSeconds(0.5),
        cutId: null,
        frameIndex: 0,
      ),
      isFalse,
    );
    manager.dispose();
  });

  test('placement is undoable back to a clean slate', () async {
    final manager = session();
    await manager.saveProjectToFile('${directory.path}/scene.qap');
    final cutId = manager.requireActiveCut.id;
    final beforeCount = manager.activeTrack.seLayers.length;

    expect(
      manager.placeVoiceRecording(takeOfSeconds(0.5), cutId: cutId,
          frameIndex: 0),
      isTrue,
    );
    // Placement is a short command run (row, block, pool, link) — undoing
    // through it must strip the take back out completely.
    var guard = 0;
    while (manager.canUndo && guard < 10) {
      manager.historyManager.undo();
      guard += 1;
    }
    final seRowsAfter = manager.activeTrack.seLayers;
    expect(seRowsAfter.length, beforeCount);
    expect(
      seRowsAfter.every((layer) => layer.audioClips.isEmpty),
      isTrue,
    );
    manager.dispose();
  });
}
