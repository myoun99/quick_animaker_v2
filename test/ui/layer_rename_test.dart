import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
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

const _renameButtonKey = ValueKey<String>('rename-layer-button');
const _dialogKey = ValueKey<String>('rename-layer-dialog');
const _textFieldKey = ValueKey<String>('rename-layer-text-field');
const _cancelButtonKey = ValueKey<String>('rename-layer-cancel-button');
const _okButtonKey = ValueKey<String>('rename-layer-ok-button');
const _undoKey = ValueKey<String>('undo-button');
const _redoKey = ValueKey<String>('redo-button');
const _cutId = CutId('rename-cut');
const _layerAId = LayerId('layer-a');
const _layerBId = LayerId('layer-b');
const _frameId = FrameId('frame-a');

void main() {
  testWidgets('Rename Layer button is visible and opens a prefilled dialog', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byKey(_renameButtonKey), findsOneWidget);
    expect(find.byTooltip('Rename Layer'), findsOneWidget);
    expect(_isIconButtonEnabled(tester, _renameButtonKey), isTrue);

    await _tapKey(tester, _renameButtonKey);

    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(_fieldText(tester), 'A');
  });

  testWidgets('Rename Layer button is disabled without an active layer', (
    tester,
  ) async {
    await _pumpHome(tester, project: _project(layers: const []));

    expect(find.byKey(_renameButtonKey), findsOneWidget);
    expect(_isIconButtonEnabled(tester, _renameButtonKey), isFalse);
  });

  testWidgets('renaming A to BG updates label and keeps active selection', (
    tester,
  ) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    expect(
      find.byKey(const ValueKey<String>('timeline-layer-name-layer-a')),
      findsOneWidget,
    );
    expect(find.text('Layer: A'), findsOneWidget);

    await _renameLayer(tester, 'BG');

    expect(_layer(repository, _layerAId).name, 'BG');
    expect(find.text('Layer: BG'), findsOneWidget);
    expect(find.text('BG'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('timeline-selected-layer')),
      findsOneWidget,
    );
    expect(_layerNameText(tester, _layerAId).data, 'BG');
  });

  testWidgets('cancel changes nothing', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    await _tapKey(tester, _renameButtonKey);
    await tester.enterText(find.byKey(_textFieldKey), 'BG');
    await _tapKey(tester, _cancelButtonKey);

    expect(_layer(repository, _layerAId).name, 'A');
    expect(find.text('Layer: A'), findsOneWidget);
    expect(find.byKey(_dialogKey), findsNothing);
  });

  testWidgets('empty and duplicate names keep dialog open and do not rename', (
    tester,
  ) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    await _tapKey(tester, _renameButtonKey);
    await tester.enterText(find.byKey(_textFieldKey), '   ');
    await _tapKey(tester, _okButtonKey);

    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(find.text('Layer name cannot be empty.'), findsOneWidget);
    expect(_layer(repository, _layerAId).name, 'A');

    await tester.enterText(find.byKey(_textFieldKey), 'B');
    await _tapKey(tester, _okButtonKey);

    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(find.text('Layer name already exists in this Cut.'), findsOneWidget);
    expect(_layer(repository, _layerAId).name, 'A');
    expect(_layer(repository, _layerBId).name, 'B');
  });

  testWidgets('undo and redo rename from the UI', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    await _renameLayer(tester, 'BG');
    expect(_layer(repository, _layerAId).name, 'BG');

    await _tapKey(tester, _undoKey);
    expect(_layer(repository, _layerAId).name, 'A');
    expect(find.text('Layer: A'), findsOneWidget);

    await _tapKey(tester, _redoKey);
    expect(_layer(repository, _layerAId).name, 'BG');
    expect(find.text('Layer: BG'), findsOneWidget);
  });

  testWidgets('layer kind icon remains visible after rename', (tester) async {
    await _pumpHome(tester);

    expect(
      find.byKey(const ValueKey<String>('timeline-layer-kind-icon-layer-a')),
      findsOneWidget,
    );
    expect(_layerKindIcon(tester, _layerAId), Icons.brush_outlined);

    await _renameLayer(tester, 'BG');

    expect(
      find.byKey(const ValueKey<String>('timeline-layer-kind-icon-layer-a')),
      findsOneWidget,
    );
    expect(_layerKindIcon(tester, _layerAId), Icons.brush_outlined);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  Project? project,
  void Function(ProjectRepository repository)? onRepositoryCreated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        initialProject: project ?? _project(),
        onRepositoryCreated: onRepositoryCreated,
      ),
    ),
  );
}

Future<void> _tapKey(WidgetTester tester, ValueKey<String> key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _renameLayer(WidgetTester tester, String name) async {
  await _tapKey(tester, _renameButtonKey);
  await tester.enterText(find.byKey(_textFieldKey), name);
  await _tapKey(tester, _okButtonKey);
}

bool _isIconButtonEnabled(WidgetTester tester, ValueKey<String> key) {
  return tester.widget<IconButton>(find.byKey(key)).onPressed != null;
}

String _fieldText(WidgetTester tester) {
  return tester.widget<TextField>(find.byKey(_textFieldKey)).controller!.text;
}

Layer _layer(ProjectRepository repository, LayerId layerId) {
  return repository
      .requireProject()
      .tracks
      .single
      .cuts
      .single
      .layers
      .singleWhere((layer) => layer.id == layerId);
}

Text _layerNameText(WidgetTester tester, LayerId layerId) {
  final nameFinder = find.byKey(
    ValueKey<String>('timeline-layer-name-$layerId'),
  );
  final textFinder = find.descendant(
    of: nameFinder,
    matching: find.byType(Text),
  );
  return tester.widget<Text>(textFinder.first);
}

IconData _layerKindIcon(WidgetTester tester, LayerId layerId) {
  return tester
      .widget<Icon>(
        find.byKey(ValueKey<String>('timeline-layer-kind-icon-$layerId')),
      )
      .icon!;
}

Project _project({List<Layer>? layers}) {
  return Project(
    id: const ProjectId('rename-project'),
    name: 'Rename Project',
    createdAt: DateTime.utc(2026, 6, 12),
    tracks: [
      Track(
        id: const TrackId('rename-track'),
        name: 'Track',
        cuts: [
          Cut(
            id: _cutId,
            name: 'Cut',
            duration: 1,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers:
                layers ??
                [_layerModel(_layerAId, 'A'), _layerModel(_layerBId, 'B')],
          ),
        ],
      ),
    ],
  );
}

Layer _layerModel(LayerId id, String name) {
  return Layer(
    id: id,
    name: name,
    kind: LayerKind.animation,
    frames: [Frame(id: _frameId, duration: 1, strokes: const [])],
    timeline: const {0: TimelineExposure.blank()},
  );
}
