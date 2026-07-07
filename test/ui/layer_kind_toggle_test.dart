import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/cut_metadata.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/storyboard_frame_metadata.dart';
import 'package:quick_animaker_v2/src/models/stroke.dart';
import 'package:quick_animaker_v2/src/models/stroke_id.dart';
import 'package:quick_animaker_v2/src/models/stroke_point.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

const _toggleKey = ValueKey<String>('toggle-storyboard-layer-button');
const _seToggleKey = ValueKey<String>('toggle-se-layer-button');
const _undoKey = ValueKey<String>('undo-button');
const _redoKey = ValueKey<String>('redo-button');
const _cutId = CutId('phase-73-cut');
const _layerId = LayerId('phase-73-layer');
const _frameId = FrameId('phase-73-frame');

Future<void> _pumpHome(
  WidgetTester tester, {
  Project? project,
  void Function(ProjectRepository repository)? onRepositoryCreated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        initialProject: project ?? _projectWithLayer(),
        onRepositoryCreated: onRepositoryCreated,
      ),
    ),
  );
}

CutId? _mainCanvasCutId(WidgetTester tester) {
  final host = tester.widget<MainCanvasBrushHost>(
    find.byType(MainCanvasBrushHost),
  );
  return host.selection?.cutId;
}

Future<void> _tapKey(WidgetTester tester, ValueKey<String> key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Layer _layer(ProjectRepository repository) {
  return repository.requireProject().tracks.single.cuts.single.layers.single;
}

bool _isIconButtonEnabled(WidgetTester tester, ValueKey<String> key) {
  return tester.widget<IconButton>(find.byKey(key)).onPressed != null;
}

Project _projectWithLayer({LayerKind kind = LayerKind.animation}) {
  return Project(
    id: const ProjectId('phase-73-project'),
    name: 'Phase 73 Project',
    createdAt: DateTime.utc(2026, 6, 11),
    tracks: [
      Track(
        id: const TrackId('phase-73-track'),
        name: 'Video Track',
        cuts: [
          Cut(
            id: _cutId,
            name: 'Phase 73 Cut',
            duration: 2,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            metadata: const CutMetadata(note: 'cut note only'),
            layers: [
              Layer(
                id: _layerId,
                name: 'Target Layer',
                kind: kind,
                isVisible: false,
                opacity: 0.5,
                frames: [
                  Frame(
                    id: _frameId,
                    duration: 2,
                    name: 'A1',
                    storyboardMetadata: const StoryboardFrameMetadata(
                      actionMemo: 'action memo stays on frame',
                      dialogueMemo: 'dialogue memo stays on frame',
                      note: 'storyboard note stays on frame',
                    ),
                    strokes: [
                      Stroke(
                        id: const StrokeId('stroke-1'),
                        points: const [
                          StrokePoint(x: 1, y: 2),
                          StrokePoint(x: 3, y: 4),
                        ],
                        brushSettings: BrushSettings(
                          color: 0xFF112233,
                          size: 7,
                          opacity: 0.75,
                        ),
                      ),
                    ],
                  ),
                ],
                timeline: {
                  0: TimelineExposure.drawing(_frameId, length: 1),
                  1: const TimelineExposure.mark(),
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Project _projectWithNoLayers() {
  return Project(
    id: const ProjectId('phase-73-empty-layer-project'),
    name: 'Phase 73 No Layers Project',
    createdAt: DateTime.utc(2026, 6, 11),
    tracks: [
      Track(
        id: const TrackId('phase-73-track'),
        name: 'Video Track',
        cuts: [
          Cut(
            id: _cutId,
            name: 'No Layer Cut',
            duration: 1,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers: const [],
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('toggle button is visible', (tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byKey(_toggleKey), findsOneWidget);
    expect(find.byTooltip('Toggle Storyboard Layer'), findsOneWidget);
  });

  testWidgets('toggles animation layer to storyboard', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    expect(_layer(repository).kind, LayerKind.animation);
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);

    await _tapKey(tester, _toggleKey);

    expect(_layer(repository).kind, LayerKind.storyboard);
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);
  });

  testWidgets('toggles storyboard layer back to animation', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(
      tester,
      project: _projectWithLayer(kind: LayerKind.storyboard),
      onRepositoryCreated: (repo) => repository = repo,
    );

    expect(_layer(repository).kind, LayerKind.storyboard);
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);

    await _tapKey(tester, _toggleKey);

    expect(_layer(repository).kind, LayerKind.animation);
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);
  });

  testWidgets('undo and redo work after toggling to storyboard', (
    tester,
  ) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    await _tapKey(tester, _toggleKey);
    expect(_layer(repository).kind, LayerKind.storyboard);
    expect(_mainCanvasCutId(tester), _cutId);

    await _tapKey(tester, _undoKey);
    expect(_layer(repository).kind, LayerKind.animation);
    expect(_mainCanvasCutId(tester), _cutId);

    await _tapKey(tester, _redoKey);
    expect(_layer(repository).kind, LayerKind.storyboard);
    expect(_mainCanvasCutId(tester), _cutId);
  });

  testWidgets('undo and redo work after toggling to animation', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(
      tester,
      project: _projectWithLayer(kind: LayerKind.storyboard),
      onRepositoryCreated: (repo) => repository = repo,
    );

    await _tapKey(tester, _toggleKey);
    expect(_layer(repository).kind, LayerKind.animation);
    expect(_mainCanvasCutId(tester), _cutId);

    await _tapKey(tester, _undoKey);
    expect(_layer(repository).kind, LayerKind.storyboard);
    expect(_mainCanvasCutId(tester), _cutId);

    await _tapKey(tester, _redoKey);
    expect(_layer(repository).kind, LayerKind.animation);
    expect(_mainCanvasCutId(tester), _cutId);
  });

  testWidgets('active cut with no layers is safe and disabled', (tester) async {
    late ProjectRepository repository;
    await _pumpHome(
      tester,
      project: _projectWithNoLayers(),
      onRepositoryCreated: (repo) => repository = repo,
    );

    expect(find.byKey(_toggleKey), findsOneWidget);
    expect(_isIconButtonEnabled(tester, _toggleKey), isFalse);
    expect(
      repository.requireProject().tracks.single.cuts.single.layers,
      isEmpty,
    );
  });

  testWidgets('toggle preserves storyboard metadata, strokes, and layer data', (
    tester,
  ) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);
    final beforeLayer = _layer(repository);
    final beforeFrame = beforeLayer.frames.single;

    await _tapKey(tester, _toggleKey);

    final afterLayer = _layer(repository);
    final afterFrame = afterLayer.frames.single;
    expect(afterLayer.kind, LayerKind.storyboard);
    expect(afterFrame.storyboardMetadata, beforeFrame.storyboardMetadata);
    expect(afterFrame.strokes, beforeFrame.strokes);
    expect(afterLayer.frames, beforeLayer.frames);
    expect(afterLayer.timeline, beforeLayer.timeline);
    expect(afterLayer.isVisible, beforeLayer.isVisible);
    expect(afterLayer.opacity, beforeLayer.opacity);
    expect(
      repository.requireProject().tracks.single.cuts.single.metadata,
      const CutMetadata(note: 'cut note only'),
    );
  });

  testWidgets('SE toggle flips animation to SE and back with undo', (
    tester,
  ) async {
    late ProjectRepository repository;
    await _pumpHome(tester, onRepositoryCreated: (repo) => repository = repo);

    expect(find.byTooltip('Toggle SE Layer'), findsOneWidget);

    await _tapKey(tester, _seToggleKey);

    expect(_layer(repository).kind, LayerKind.se);
    expect(find.bySemanticsLabel('SE layer'), findsOneWidget);

    await _tapKey(tester, _undoKey);
    expect(_layer(repository).kind, LayerKind.animation);

    await _tapKey(tester, _redoKey);
    expect(_layer(repository).kind, LayerKind.se);

    // Back to animation via the same toggle.
    await _tapKey(tester, _seToggleKey);
    expect(_layer(repository).kind, LayerKind.animation);
  });

  // A storyboard layer cannot become SE directly, and an SE layer cannot
  // become a storyboard directly — go through animation.
  testWidgets('storyboard toggle is disabled for an SE layer', (tester) async {
    await _pumpHome(tester, project: _projectWithLayer(kind: LayerKind.se));

    expect(_isIconButtonEnabled(tester, _seToggleKey), isTrue);
    expect(_isIconButtonEnabled(tester, _toggleKey), isFalse);
  });

  testWidgets('SE toggle is disabled for a storyboard layer', (tester) async {
    await _pumpHome(
      tester,
      project: _projectWithLayer(kind: LayerKind.storyboard),
    );

    expect(_isIconButtonEnabled(tester, _seToggleKey), isFalse);
    expect(_isIconButtonEnabled(tester, _toggleKey), isTrue);
  });

  testWidgets('does not expose future storyboard or inspector UI', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.text('Storyboard Panel'), findsNothing);
    expect(find.text('Conte Panel'), findsNothing);
    expect(find.text('Layer Inspector'), findsNothing);
    expect(find.text('Cut Inspector'), findsNothing);
    expect(find.text('StoryboardFrameMetadata editor'), findsNothing);
    expect(find.text('actionMemo'), findsNothing);
    expect(find.text('dialogueMemo'), findsNothing);
    expect(find.byKey(const ValueKey<String>('panelNote')), findsNothing);
    expect(find.byKey(const ValueKey<String>('actionMemo')), findsNothing);
    expect(find.byKey(const ValueKey<String>('dialogueMemo')), findsNothing);
  });
}
