import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart'
    show drawingBlocks;
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_orientation.dart';
import 'package:quick_animaker_v2/src/ui/timeline_tab_host.dart';

const _importKey = ValueKey<String>('import-audio-button');
const _seLayerId = LayerId('audio-se');
const _celLayerId = LayerId('audio-cel');

EditorSessionManager _session() {
  return EditorSessionManager(
    initialProject: Project(
      id: const ProjectId('audio-project'),
      name: 'Audio Project',
      createdAt: DateTime.utc(2026, 7, 8),
      tracks: [
        Track(
          id: const TrackId('audio-track'),
          name: 'Video',
          cuts: [
            Cut(
              id: const CutId('audio-cut'),
              name: 'Audio Cut',
              duration: 12,
              canvasSize: const CanvasSize(width: 640, height: 360),
              layers: [
                Layer(
                  id: _celLayerId,
                  name: 'A',
                  frames: const [],
                  timeline: const {},
                ),
                Layer(
                  id: _seLayerId,
                  name: 'S1',
                  kind: LayerKind.se,
                  frames: const [],
                  timeline: const {},
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _pumpHost(
  WidgetTester tester,
  EditorSessionManager session, {
  Future<String?> Function()? audioFilePicker,
}) async {
  // The test owns the session (HomePage normally does) — dispose it so
  // playback/prerender machinery cancels its timers before teardown.
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: session,
          builder: (context, _) => TimelineTabHost(
            session: session,
            orientation: TimelineOrientation.horizontal,
            onOrientationChanged: (_) {},
            pixelsPerFrame: 48,
            onPixelsPerFrameChanged: (_) {},
            showSeconds: false,
            onShowSecondsChanged: (_) {},
            audioFilePicker: audioFilePicker,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _importEnabled(WidgetTester tester) {
  return tester.widget<IconButton>(find.byKey(_importKey)).onPressed != null;
}

void main() {
  testWidgets('import audio is SE-only and places the clip at the playhead '
      'with one undo', (tester) async {
    final session = _session();
    var picks = 0;
    await _pumpHost(
      tester,
      session,
      audioFilePicker: () async {
        picks += 1;
        return r'C:\sound\voice.wav';
      },
    );

    // Animation layer active: disabled.
    session.selectLayer(_celLayerId);
    await tester.pumpAndSettle();
    expect(_importEnabled(tester), isFalse);

    // SE layer at frame 4: imports at the playhead.
    session.selectLayer(_seLayerId);
    session.selectFrameIndex(4);
    await tester.pumpAndSettle();
    expect(_importEnabled(tester), isTrue);

    await tester.ensureVisible(find.byKey(_importKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_importKey));
    await tester.pumpAndSettle();

    expect(picks, 1);
    Layer seLayer() =>
        session.layers.firstWhere((layer) => layer.id == _seLayerId);
    expect(seLayer().audioClips.single.filePath, r'C:\sound\voice.wav');
    // Frame-linked: importing onto the empty cell created an SE instance
    // at the playhead and linked the sound to ITS frame — the block is the
    // sound's window.
    final carrierBlock = drawingBlocks(seLayer().timeline).single;
    expect(carrierBlock.startIndex, 4);
    expect(seLayer().audioClips.single.frameId, carrierBlock.frameId);

    session.undo();
    await tester.pumpAndSettle();
    expect(seLayer().audioClips, isEmpty);

    // Removal API round-trip.
    session.redo();
    session.removeAudioClipAt(_seLayerId, 0);
    expect(seLayer().audioClips, isEmpty);
    // Flush the prerender scheduler's zero-delay yields before teardown.
    await tester.pumpAndSettle();
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    final session = _session();
    await _pumpHost(tester, session, audioFilePicker: () async => null);

    session.selectLayer(_seLayerId);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_importKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_importKey));
    await tester.pumpAndSettle();

    expect(
      session.layers.firstWhere((layer) => layer.id == _seLayerId).audioClips,
      isEmpty,
    );
  });
}
