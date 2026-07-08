import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:quick_animaker_v2/src/ui/timeline/dialogue_fit_text.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_style.dart';

const _cutId = CutId('se-cut');
const _seLayerId = LayerId('se-voice');
const _celLayerId = LayerId('se-cel');

/// SE row fixture: one cel layer (empty) and one SE layer with a named
/// 3-frame entry at frame 1; the sheet fixtures (S1/S2/CAM) are omitted so
/// each behavior reads off exactly one row.
Project _project({
  Map<int, TimelineExposure>? seTimeline,
  List<Frame>? frames,
}) {
  return Project(
    id: const ProjectId('se-project'),
    name: 'SE Project',
    createdAt: DateTime.utc(2026, 7, 8),
    tracks: [
      Track(
        id: const TrackId('se-track'),
        name: 'Video',
        cuts: [
          Cut(
            id: _cutId,
            name: 'SE Cut',
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
                frames:
                    frames ??
                    [
                      Frame(
                        id: const FrameId('se-f1'),
                        duration: 3,
                        name: 'Hello!',
                        strokes: const [],
                      ),
                    ],
                timeline:
                    seTimeline ??
                    {
                      1: const TimelineExposure.drawing(
                        FrameId('se-f1'),
                        length: 3,
                      ),
                    },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  Project project, {
  void Function(ProjectRepository repository)? onRepositoryCreated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        initialProject: project,
        onRepositoryCreated: onRepositoryCreated,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ensureRowVisible(WidgetTester tester, LayerId layerId) async {
  await tester.ensureVisible(
    find.byKey(ValueKey<String>('timeline-layer-row-$layerId')),
  );
  await tester.pumpAndSettle();
}

Future<void> _doubleTapCell(WidgetTester tester, Finder cell) async {
  await tester.tap(cell);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

/// The dialogue text carried by an SE span overlay — painted glyphs, so
/// find.text cannot see it; read the widget field instead.
String _seDialogueAt(WidgetTester tester, String overlayKey) {
  final fit = tester.widget<DialogueFitText>(
    find.descendant(
      of: find.byKey(ValueKey<String>(overlayKey)),
      matching: find.byType(DialogueFitText),
    ),
  );
  return fit.text;
}

List<String> _allSeDialogues(WidgetTester tester) {
  return [
    for (final widget in tester.widgetList<DialogueFitText>(
      find.byType(DialogueFitText),
    ))
      widget.text,
  ];
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

void main() {
  testWidgets(
    'SE row paints paper blocks with the fitted dialogue overlay, no cell '
    'glyphs or X',
    (tester) async {
      await _pumpHome(tester, _project());
      await _ensureRowVisible(tester, _seLayerId);

      // The dialogue rides the block-span overlay as painted fitted glyphs.
      expect(
        find.byKey(const ValueKey<String>('timeline-se-label-se-voice-1')),
        findsOneWidget,
      );
      expect(_seDialogueAt(tester, 'timeline-se-label-se-voice-1'), 'Hello!');
      // No Text glyph duplicates the dialogue on the start cell.
      expect(find.text('Hello!'), findsNothing);

      // Covered SE cells paint the same white paper as drawing blocks.
      final startCell = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('timeline-cell-se-voice-1')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (startCell.decoration! as BoxDecoration).color,
        timelineDrawingHeldColor,
      );

      // No name box without a seName.
      expect(find.bySemanticsLabel(RegExp('^SE name')), findsNothing);

      // No X anywhere on the SE row; the empty cel row still gets its X.
      final seRowArea = find.byKey(
        const ValueKey<String>('timeline-frame-row-area-se-voice'),
      );
      expect(
        find.descendant(of: seRowArea, matching: find.text('X')),
        findsNothing,
      );
      await _ensureRowVisible(tester, _celLayerId);
      final celRowArea = find.byKey(
        const ValueKey<String>('timeline-frame-row-area-se-cel'),
      );
      expect(
        find.descendant(of: celRowArea, matching: find.text('X')),
        findsOneWidget,
      );
    },
  );

  testWidgets('an entry with a seName shows the accent name box at the '
      'block start', (tester) async {
    await _pumpHome(
      tester,
      _project(
        frames: [
          Frame(
            id: const FrameId('se-f1'),
            duration: 3,
            name: '그건 아니라고 생각해',
            seName: '앨리스',
            strokes: const [],
          ),
        ],
      ),
    );
    await _ensureRowVisible(tester, _seLayerId);

    expect(find.bySemanticsLabel('SE name 앨리스'), findsOneWidget);
    expect(
      _seDialogueAt(tester, 'timeline-se-label-se-voice-1'),
      '그건 아니라고 생각해',
    );
  });

  testWidgets('XSheet SE column shows the same label overlay', (tester) async {
    await _pumpHome(tester, _project());

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-orientation-toggle-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('xsheet-se-label-se-voice-1')),
      findsOneWidget,
    );
    expect(_seDialogueAt(tester, 'xsheet-se-label-se-voice-1'), 'Hello!');
  });

  testWidgets('double-tap on an empty SE cell creates a labeled entry to the '
      'cut end in one undo', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(
      tester,
      _project(seTimeline: const {}, frames: const []),
      onRepositoryCreated: (repo) => repository = repo,
    );
    await _ensureRowVisible(tester, _seLayerId);

    await _doubleTapCell(
      tester,
      find.byKey(const ValueKey<String>('timeline-cell-se-voice-4')),
    );
    expect(find.text('New SE'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('se-dialogue-field')),
      '와아!',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('se-name-field')),
      '앨리스',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('instance-edit-ok-button')),
    );
    await tester.pumpAndSettle();

    final layer = _seLayer(repository);
    final entry = layer.timeline[4]!;
    expect(layer.frames.single.name, '와아!');
    expect(layer.frames.single.seName, '앨리스');
    // Sheet semantics: holds to the cut end (duration 12, start 4).
    expect(entry.length, 8);
    expect(_seDialogueAt(tester, 'timeline-se-label-se-voice-4'), '와아!');
    expect(find.bySemanticsLabel('SE name 앨리스'), findsOneWidget);

    // ONE undo removes the entire labeled entry.
    await tester.tap(find.byKey(const ValueKey<String>('undo-button')));
    await tester.pumpAndSettle();
    expect(_seLayer(repository).timeline, isEmpty);
    expect(_seLayer(repository).frames, isEmpty);
  });

  testWidgets('double-tap on an existing SE entry edits its label; duplicate '
      'dialogue is allowed', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(
      tester,
      _project(
        frames: [
          Frame(
            id: const FrameId('se-f1'),
            duration: 3,
            name: 'Hello!',
            strokes: const [],
          ),
          Frame(
            id: const FrameId('se-f2'),
            duration: 2,
            name: 'Again',
            strokes: const [],
          ),
        ],
        seTimeline: {
          1: const TimelineExposure.drawing(FrameId('se-f1'), length: 3),
          6: const TimelineExposure.drawing(FrameId('se-f2'), length: 2),
        },
      ),
      onRepositoryCreated: (repo) => repository = repo,
    );
    await _ensureRowVisible(tester, _seLayerId);

    // Edit the second entry to the SAME text as the first: SE rows allow
    // duplicate dialogue (no link-conflict flow).
    await _doubleTapCell(
      tester,
      find.byKey(const ValueKey<String>('timeline-cell-se-voice-6')),
    );
    expect(find.text('Edit SE'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('se-dialogue-field')),
      'Hello!',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('instance-edit-ok-button')),
    );
    await tester.pumpAndSettle();

    final layer = _seLayer(repository);
    expect(layer.frames.map((frame) => frame.name), ['Hello!', 'Hello!']);
    expect(
      _allSeDialogues(tester).where((text) => text == 'Hello!').length,
      2,
    );
  });
}
