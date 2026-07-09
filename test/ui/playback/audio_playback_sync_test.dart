import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/playback/audio_playback_sync.dart';
import 'package:quick_animaker_v2/src/ui/playback/canvas_playback_controller.dart';

class _FakeClipPlayer implements AudioClipPlayer {
  _FakeClipPlayer(this.log);

  final List<String> log;
  String? _path;

  @override
  Future<void> prepare(String filePath) async {
    _path = filePath;
    log.add('prepare $filePath');
  }

  @override
  Future<void> startAt(Duration position) async =>
      log.add('start $_path @${position.inMilliseconds}ms');

  @override
  Future<void> pause() async => log.add('pause $_path');

  @override
  Future<void> resume() async => log.add('resume $_path');

  @override
  Future<void> stop() async => log.add('stop $_path');

  @override
  Future<void> dispose() async => log.add('dispose $_path');
}

/// One SE layer with one sound linked to a single block (frame-linked
/// model: the block is the sound's window).
Layer _seLayer(
  String id, {
  required String file,
  required int start,
  required int length,
}) => Layer(
  id: LayerId(id),
  name: 'S1',
  kind: LayerKind.se,
  frames: [Frame(id: FrameId('$id-frame'), duration: 1, strokes: const [])],
  timeline: {
    start: TimelineExposure.drawing(FrameId('$id-frame'), length: length),
  },
  audioClips: [AudioClip(filePath: file, frameId: FrameId('$id-frame'))],
);

// fps 10: cut-a (10 frames) carries a.wav on a full-cut block (1.0 s = the
// whole window) and b.wav on a 6..10 block (unknown length → clamped to
// the block/cut end); cut-b (20 frames, global 10..30) carries c.wav on a
// block at local 3 (0.5 s → global 13..18).
final Project _project = Project(
  id: const ProjectId('sync-project'),
  name: 'Sync',
  createdAt: DateTime.utc(2026, 7, 8),
  tracks: [
    Track(
      id: const TrackId('track'),
      name: 'Video',
      cuts: [
        Cut(
          id: const CutId('cut-a'),
          name: 'A',
          duration: 10,
          canvasSize: const CanvasSize(width: 640, height: 360),
          layers: [
            _seLayer('se-a1', file: 'a.wav', start: 0, length: 10),
            _seLayer('se-a2', file: 'b.wav', start: 6, length: 4),
          ],
        ),
        Cut(
          id: const CutId('cut-b'),
          name: 'B',
          duration: 20,
          canvasSize: const CanvasSize(width: 640, height: 360),
          layers: [_seLayer('se-b', file: 'c.wav', start: 3, length: 17)],
        ),
      ],
    ),
  ],
);

const _durations = {'a.wav': 1.0, 'c.wav': 0.5};

void main() {
  late CanvasPlaybackController controller;
  late List<String> log;

  setUp(() {
    log = [];
    controller = CanvasPlaybackController(
      resolveProject: () => _project,
      resolveActiveCutId: () => const CutId('cut-a'),
      resolveActiveTrackId: () => const TrackId('track'),
      resolveFps: () => 10,
    );
    final sync = AudioPlaybackSync(
      controller: controller,
      resolveFps: () => 10,
      durationSecondsFor: (path) => _durations[path],
      playerFactory: () => _FakeClipPlayer(log),
    )..attach();
    addTearDown(sync.dispose);
    addTearDown(controller.dispose);
  });

  test('play prepares every scheduled clip once and starts the overlapping '
      'ones', () {
    controller.play(scope: PlaybackScope.activeCut);
    expect(log, ['prepare a.wav', 'prepare b.wav', 'start a.wav @0ms']);

    log.clear();
    controller.seekToGlobalFrame(3); // small forward step = dropped frames
    expect(log, isEmpty);

    controller.seekToGlobalFrame(6); // crosses b.wav's start
    expect(log, ['start b.wav @0ms']);
  });

  test('play mid-timeline starts clips at the matching position', () {
    controller.play(scope: PlaybackScope.activeCut, startGlobalFrame: 5);
    expect(log, ['prepare a.wav', 'prepare b.wav', 'start a.wav @500ms']);
  });

  test('a forward jump past the threshold restarts at the new position', () {
    controller.play(scope: PlaybackScope.activeCut);
    log.clear();

    controller.seekToGlobalFrame(8); // 8 frames > fps/2 → resync
    expect(log, ['stop a.wav', 'start a.wav @800ms', 'start b.wav @200ms']);
  });

  test('a backward jump (loop wrap) stops everything and re-evaluates', () {
    controller.play(scope: PlaybackScope.activeCut);
    controller.seekToGlobalFrame(6);
    log.clear();

    controller.seekToGlobalFrame(0);
    expect(log, ['stop a.wav', 'stop b.wav', 'start a.wav @0ms']);
  });

  test('pause/resume forward to playing clips; a paused seek restarts', () {
    controller.play(scope: PlaybackScope.activeCut);
    log.clear();

    controller.pause();
    expect(log, ['pause a.wav']);

    log.clear();
    controller.resume();
    expect(log, ['resume a.wav']);

    // Positions go stale on a paused seek — stop now, restart on resume.
    controller.pause();
    log.clear();
    controller.seekToGlobalFrame(6);
    expect(log, ['stop a.wav']);

    log.clear();
    controller.resume();
    expect(log, ['start a.wav @600ms', 'start b.wav @0ms']);
  });

  test('stopping playback stops and disposes every player', () {
    controller.play(scope: PlaybackScope.activeCut);
    controller.seekToGlobalFrame(6);
    log.clear();

    controller.stop();
    expect(log, ['stop a.wav', 'stop b.wav', 'dispose a.wav', 'dispose b.wav']);
  });

  test('all-cuts playback lays clips globally and clamps at cut ends', () {
    // Frame 12 = cut-b local 2: everything is prepared, nothing plays yet.
    controller.play(scope: PlaybackScope.allCuts, startGlobalFrame: 12);
    expect(log, ['prepare a.wav', 'prepare b.wav', 'prepare c.wav']);

    log.clear();
    controller.seekToGlobalFrame(13); // c.wav's global start
    expect(log, ['start c.wav @0ms']);

    log.clear();
    controller.seekToGlobalFrame(18); // c.wav ends (0.5 s = 5 frames)
    expect(log, ['stop c.wav']);
  });

  test('an unknown-length clip stops at its cut boundary', () {
    // b.wav has no extracted peaks → its end clamps to cut-a's end (10).
    controller.play(scope: PlaybackScope.allCuts, startGlobalFrame: 7);
    expect(log, [
      'prepare a.wav',
      'prepare b.wav',
      'prepare c.wav',
      'start a.wav @700ms',
      'start b.wav @100ms',
    ]);

    log.clear();
    controller.seekToGlobalFrame(10); // cut-a → cut-b boundary
    expect(log, ['stop a.wav', 'stop b.wav']);
  });

  test('a cut boundary tick never opens or tears down a media pipeline', () {
    // Playback must never stall at a cut boundary: crossing one only
    // seeks/starts/stops PREPARED players — no prepare, no dispose.
    controller.play(scope: PlaybackScope.allCuts, startGlobalFrame: 9);
    log.clear();

    controller.seekToGlobalFrame(13); // crosses the boundary, starts c.wav
    expect(log, ['stop a.wav', 'stop b.wav', 'start c.wav @0ms']);
    expect(log.where((line) => line.startsWith('prepare')), isEmpty);
    expect(log.where((line) => line.startsWith('dispose')), isEmpty);
  });

  test('a loop wrap restarts clips on the same prepared players', () {
    controller.play(scope: PlaybackScope.activeCut);
    controller.seekToGlobalFrame(6);
    log.clear();

    controller.seekToGlobalFrame(0); // loop wrap
    expect(log, ['stop a.wav', 'stop b.wav', 'start a.wav @0ms']);
    expect(log.where((line) => line.startsWith('prepare')), isEmpty);
  });

  test('an offset trim seeks into the file and shortens the audible '
      'window', () {
    // One 10-frame cut: a 1.0 s file (10 frames at fps 10) trimmed by 4 —
    // playback starts 0.4 s into the file and only 6 frames remain audible.
    final trimmedLog = <String>[];
    final project = Project(
      id: const ProjectId('trim-project'),
      name: 'Trim',
      createdAt: DateTime.utc(2026, 7, 9),
      tracks: [
        Track(
          id: const TrackId('trim-track'),
          name: 'Video',
          cuts: [
            Cut(
              id: const CutId('trim-cut'),
              name: 'T',
              duration: 10,
              canvasSize: const CanvasSize(width: 640, height: 360),
              layers: [
                _seLayer(
                  'se-trim',
                  file: 'a.wav',
                  start: 0,
                  length: 10,
                ).copyWith(
                  audioClips: const [
                    AudioClip(
                      filePath: 'a.wav',
                      frameId: FrameId('se-trim-frame'),
                      offsetFrames: 4,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final trimmedController = CanvasPlaybackController(
      resolveProject: () => project,
      resolveActiveCutId: () => const CutId('trim-cut'),
      resolveActiveTrackId: () => const TrackId('trim-track'),
      resolveFps: () => 10,
    );
    final sync = AudioPlaybackSync(
      controller: trimmedController,
      resolveFps: () => 10,
      durationSecondsFor: (path) => _durations[path],
      playerFactory: () => _FakeClipPlayer(trimmedLog),
    )..attach();
    addTearDown(sync.dispose);
    addTearDown(trimmedController.dispose);

    trimmedController.play(scope: PlaybackScope.activeCut);
    expect(trimmedLog, ['prepare a.wav', 'start a.wav @400ms']);

    // The remaining file is 6 frames (10 - 4): a resync PAST the shortened
    // end stops the clip and starts nothing.
    trimmedLog.clear();
    trimmedController.seekToGlobalFrame(8); // > fps/2 → resync
    expect(trimmedLog, ['stop a.wav']);

    // A resync inside the window compounds elapsed time with the trim.
    trimmedLog.clear();
    trimmedController.seekToGlobalFrame(2);
    expect(trimmedLog, ['start a.wav @600ms']);

    // Ticking across the shortened end (frame 6) stops the clip.
    trimmedLog.clear();
    trimmedController.seekToGlobalFrame(5); // dropped-frames step: silent
    trimmedController.seekToGlobalFrame(6); // shortened end crossed
    expect(trimmedLog, ['stop a.wav']);
  });

  test('muted SE layers are skipped by the schedule entirely', () {
    final mutedLog = <String>[];
    final project = Project(
      id: const ProjectId('mute-project'),
      name: 'Mute',
      createdAt: DateTime.utc(2026, 7, 10),
      tracks: [
        Track(
          id: const TrackId('mute-track'),
          name: 'Video',
          cuts: [
            Cut(
              id: const CutId('mute-cut'),
              name: 'M',
              duration: 10,
              canvasSize: const CanvasSize(width: 640, height: 360),
              layers: [
                _seLayer(
                  'se-muted',
                  file: 'a.wav',
                  start: 0,
                  length: 10,
                ).copyWith(muted: true),
                _seLayer('se-live', file: 'c.wav', start: 0, length: 10),
              ],
            ),
          ],
        ),
      ],
    );
    final mutedController = CanvasPlaybackController(
      resolveProject: () => project,
      resolveActiveCutId: () => const CutId('mute-cut'),
      resolveActiveTrackId: () => const TrackId('mute-track'),
      resolveFps: () => 10,
    );
    final sync = AudioPlaybackSync(
      controller: mutedController,
      resolveFps: () => 10,
      durationSecondsFor: (path) => _durations[path],
      playerFactory: () => _FakeClipPlayer(mutedLog),
    )..attach();
    addTearDown(sync.dispose);
    addTearDown(mutedController.dispose);

    mutedController.play(scope: PlaybackScope.activeCut);
    // The muted layer's a.wav never even prepares; the live layer plays.
    expect(mutedLog, ['prepare c.wav', 'start c.wav @0ms']);
  });
}
