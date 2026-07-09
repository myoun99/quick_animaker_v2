import 'package:flutter/material.dart';
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
import 'package:quick_animaker_v2/src/services/project_repository.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

/// ⑨b SE audio UX: the row's mute speaker + the audio lane's AE-style
/// offset value field.

const _seLayerId = LayerId('sea-voice');

Project _project() {
  return Project(
    id: const ProjectId('sea-project'),
    name: 'SEA Project',
    createdAt: DateTime.utc(2026, 7, 10),
    tracks: [
      Track(
        id: const TrackId('sea-track'),
        name: 'Video',
        cuts: [
          Cut(
            id: const CutId('sea-cut'),
            name: 'SEA Cut',
            duration: 12,
            canvasSize: const CanvasSize(width: 640, height: 360),
            layers: [
              Layer(
                id: const LayerId('sea-cel'),
                name: 'A',
                frames: const [],
                timeline: const {},
              ),
              Layer(
                id: _seLayerId,
                name: 'S1',
                kind: LayerKind.se,
                frames: [
                  Frame(
                    id: const FrameId('sea-f1'),
                    duration: 3,
                    name: 'Steps',
                    strokes: const [],
                  ),
                ],
                timeline: const {
                  1: TimelineExposure.drawing(FrameId('sea-f1'), length: 3),
                },
                audioClips: const [
                  AudioClip(filePath: 'steps.wav', frameId: FrameId('sea-f1')),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Layer _seLayer(ProjectRepository repository) {
  return repository
      .requireProject()
      .tracks
      .single
      .cuts
      .single
      .layers
      .firstWhere((layer) => layer.id == _seLayerId);
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required void Function(ProjectRepository repository) onRepositoryCreated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        initialProject: _project(),
        onRepositoryCreated: onRepositoryCreated,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ensureVisibleAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('Layer json round-trips muted (absent = false)', () {
    final layer = Layer(
      id: const LayerId('m'),
      name: 'S1',
      kind: LayerKind.se,
      frames: const [],
      muted: true,
    );
    expect(Layer.fromJson(layer.toJson()).muted, isTrue);

    final json = layer.copyWith(muted: false).toJson();
    expect(json.containsKey('muted'), isFalse);
    expect(Layer.fromJson(json).muted, isFalse);
  });

  testWidgets('the SE mute speaker silences the layer in both orientations '
      '(view state, not undoable)', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    final timelineMute = find.byKey(
      const ValueKey<String>('timeline-layer-mute-sea-voice'),
    );
    await _ensureVisibleAndTap(tester, timelineMute);
    expect(_seLayer(repository).muted, isTrue);
    expect(find.byTooltip('Unmute layer'), findsOneWidget);

    // The cel row carries no speaker — SE rows only.
    expect(
      find.byKey(const ValueKey<String>('timeline-layer-mute-sea-cel')),
      findsNothing,
    );

    // The X-sheet header carries the same control.
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-orientation-toggle-button')),
    );
    await tester.pumpAndSettle();
    await _ensureVisibleAndTap(
      tester,
      find.byKey(const ValueKey<String>('xsheet-layer-mute-sea-voice')),
    );
    expect(_seLayer(repository).muted, isFalse);
  });

  testWidgets('the audio lane value field types an offset trim and scrubs '
      'AE-style (one undo)', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    // Twirl the SE row down; the audio lane label carries the value cell.
    await _ensureVisibleAndTap(
      tester,
      find.byKey(const ValueKey<String>('timeline-lane-toggle-sea-voice')),
    );
    final valueCell = find.byKey(
      const ValueKey<String>('timeline-lane-value-sea-voice-se-audio'),
    );
    await tester.ensureVisible(valueCell);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.descendant(of: valueCell, matching: find.byType(Text)),
          )
          .data,
      '0f',
    );

    // Tap to type: Enter commits through session.setAudioClipOffset.
    await tester.tap(valueCell);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('timeline-lane-value-field-sea-voice-se-audio'),
      ),
      '7f',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_seLayer(repository).audioClips.single.offsetFrames, 7);

    // ONE undo restores the untouched trim.
    await tester.tap(find.byKey(const ValueKey<String>('undo-button')));
    await tester.pumpAndSettle();
    expect(_seLayer(repository).audioClips.single.offsetFrames, 0);

    // A drag on the value scrubs it: 4px per frame, rightward = deeper.
    await tester.ensureVisible(valueCell);
    await tester.pumpAndSettle();
    await tester.drag(valueCell, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(_seLayer(repository).audioClips.single.offsetFrames, 10);
  });
}
