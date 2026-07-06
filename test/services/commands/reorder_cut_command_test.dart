import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/editing_session_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/commands/reorder_cut_command.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('ReorderCutCommand', () {
    test('execute reorders cuts while preserving IDs and content', () {
      final richCut = _cut(
        id: 'cut-a',
        name: 'Cut A',
        layers: [
          _layer(
            id: 'layer-a',
            frames: [_frame(id: 'frame-a')],
            timeline: {0: TimelineExposure.drawing(const FrameId('frame-a'), length: 1)},
          ),
        ],
        duration: 48,
        canvasSize: const CanvasSize(width: 1920, height: 1080),
      );
      final cutB = _cut(id: 'cut-b', name: 'Cut B');
      final cutC = _cut(id: 'cut-c', name: 'Cut C');
      final fixture = _fixture([richCut, cutB, cutC], activeCutId: cutB.id);

      ReorderCutCommand(
        repository: fixture.repository,
        trackId: _trackId,
        cutId: richCut.id,
        newIndex: 2,
      ).execute();

      final cuts = fixture.cuts;
      expect(cuts, [cutB, cutC, richCut]);
      expect(cuts.last.id, richCut.id);
      expect(cuts.last.name, richCut.name);
      expect(cuts.last.layers, richCut.layers);
      expect(cuts.last.duration, richCut.duration);
      expect(cuts.last.canvasSize, richCut.canvasSize);
      expect(fixture.editingSession.activeCutId, cutB.id);
    });

    test('undo restores the original order without changing activeCutId', () {
      final cutA = _cut(id: 'cut-a', name: 'Cut A');
      final cutB = _cut(id: 'cut-b', name: 'Cut B');
      final cutC = _cut(id: 'cut-c', name: 'Cut C');
      final fixture = _fixture([cutA, cutB, cutC], activeCutId: cutC.id);
      final command = ReorderCutCommand(
        repository: fixture.repository,
        trackId: _trackId,
        cutId: cutA.id,
        newIndex: 2,
      );

      command.execute();
      command.undo();

      expect(fixture.cuts, [cutA, cutB, cutC]);
      expect(fixture.editingSession.activeCutId, cutC.id);
    });

    test('redo reapplies the target order without changing activeCutId', () {
      final cutA = _cut(id: 'cut-a', name: 'Cut A');
      final cutB = _cut(id: 'cut-b', name: 'Cut B');
      final cutC = _cut(id: 'cut-c', name: 'Cut C');
      final fixture = _fixture([cutA, cutB, cutC], activeCutId: cutB.id);
      final historyManager = HistoryManager();

      historyManager.execute(
        ReorderCutCommand(
          repository: fixture.repository,
          trackId: _trackId,
          cutId: cutC.id,
          newIndex: 0,
        ),
      );
      historyManager.undo();
      historyManager.redo();

      expect(fixture.cuts, [cutC, cutA, cutB]);
      expect(fixture.editingSession.activeCutId, cutB.id);
    });

    test('active moved cut remains active through execute, undo, and redo', () {
      final cutA = _cut(id: 'cut-a', name: 'Cut A');
      final cutB = _cut(id: 'cut-b', name: 'Cut B');
      final cutC = _cut(id: 'cut-c', name: 'Cut C');
      final fixture = _fixture([cutA, cutB, cutC], activeCutId: cutA.id);
      final historyManager = HistoryManager();

      historyManager.execute(
        ReorderCutCommand(
          repository: fixture.repository,
          trackId: _trackId,
          cutId: cutA.id,
          newIndex: 2,
        ),
      );
      expect(fixture.editingSession.activeCutId, cutA.id);
      _expectActiveCutExists(fixture);

      historyManager.undo();
      expect(fixture.editingSession.activeCutId, cutA.id);
      _expectActiveCutExists(fixture);

      historyManager.redo();
      expect(fixture.editingSession.activeCutId, cutA.id);
      _expectActiveCutExists(fixture);
    });

    test(
      'different active cut remains active through execute, undo, and redo',
      () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final cutC = _cut(id: 'cut-c', name: 'Cut C');
        final fixture = _fixture([cutA, cutB, cutC], activeCutId: cutB.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          ReorderCutCommand(
            repository: fixture.repository,
            trackId: _trackId,
            cutId: cutA.id,
            newIndex: 2,
          ),
        );
        expect(fixture.editingSession.activeCutId, cutB.id);
        _expectActiveCutExists(fixture);

        historyManager.undo();
        expect(fixture.editingSession.activeCutId, cutB.id);
        _expectActiveCutExists(fixture);

        historyManager.redo();
        expect(fixture.editingSession.activeCutId, cutB.id);
        _expectActiveCutExists(fixture);
      },
    );
  });
}

const _trackId = TrackId('track-1');

_Fixture _fixture(List<Cut> cuts, {required CutId activeCutId}) {
  final repository = ProjectRepository(
    initialProject: Project(
      id: const ProjectId('project-1'),
      name: 'Project',
      tracks: [Track(id: _trackId, name: 'Video', cuts: cuts)],
      createdAt: DateTime.utc(2026, 6, 8),
    ),
  );
  return _Fixture(
    repository: repository,
    editingSession: EditingSessionState(activeCutId: activeCutId),
  );
}

class _Fixture {
  const _Fixture({required this.repository, required this.editingSession});

  final ProjectRepository repository;
  final EditingSessionState editingSession;

  List<Cut> get cuts => repository.requireProject().tracks.single.cuts;
}

Cut _cut({
  required String id,
  required String name,
  List<Layer>? layers,
  int duration = 24,
  CanvasSize canvasSize = const CanvasSize(width: 1280, height: 720),
}) {
  return Cut(
    id: CutId(id),
    name: name,
    layers: layers ?? [_layer(id: 'layer-$id')],
    duration: duration,
    canvasSize: canvasSize,
  );
}

Layer _layer({
  required String id,
  List<Frame> frames = const [],
  Map<int, TimelineExposure> timeline = const {},
}) {
  return Layer(id: LayerId(id), name: id, frames: frames, timeline: timeline);
}

Frame _frame({required String id}) {
  return Frame(id: FrameId(id), duration: 1, strokes: const []);
}

void _expectActiveCutExists(_Fixture fixture) {
  expect(
    fixture.cuts.any((cut) => cut.id == fixture.editingSession.activeCutId),
    isTrue,
  );
}
