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
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/commands/cut_command_coordinator.dart';
import 'package:quick_animaker_v2/src/services/commands/cut_reorder_planner.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('CutCommandCoordinator', () {
    test('createCut plans first-available IDs and records undo/redo', () {
      final existingCut = _cut(
        id: 'cut-2',
        name: 'Existing',
        layers: [_layer(id: 'layer-2')],
      );
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-1', name: 'Video', cuts: [existingCut]),
          ],
        ),
        activeCutId: existingCut.id,
      );

      fixture.coordinator.createCut(
        trackId: const TrackId('track-1'),
        name: 'Created',
      );

      var cuts = fixture.cutsFor(const TrackId('track-1'));
      expect(cuts.map((cut) => cut.id), [
        const CutId('cut-2'),
        const CutId('cut-1'),
      ]);
      expect(cuts.last.name, 'Created');
      expect(cuts.last.layers.single.id, const LayerId('layer-1'));
      expect(fixture.editingSession.activeCutId, const CutId('cut-1'));
      expect(fixture.historyManager.undoCount, 1);
      expect(fixture.historyManager.redoCount, 0);

      fixture.historyManager.undo();

      cuts = fixture.cutsFor(const TrackId('track-1'));
      expect(cuts, [existingCut]);
      expect(fixture.editingSession.activeCutId, existingCut.id);
      expect(fixture.historyManager.undoCount, 0);
      expect(fixture.historyManager.redoCount, 1);

      fixture.historyManager.redo();

      cuts = fixture.cutsFor(const TrackId('track-1'));
      expect(cuts.map((cut) => cut.id), [
        const CutId('cut-2'),
        const CutId('cut-1'),
      ]);
      expect(fixture.editingSession.activeCutId, const CutId('cut-1'));
      expect(fixture.historyManager.undoCount, 1);
      expect(fixture.historyManager.redoCount, 0);
    });

    test(
      'renameCut renames by ID, allows duplicate names, and records history',
      () {
        final cutA = _cut(id: 'cut-1', name: 'Cut A');
        final cutB = _cut(id: 'cut-2', name: 'Cut B');
        final fixture = _fixture(
          _project(
            tracks: [
              _track(id: 'track-1', name: 'Video', cuts: [cutA, cutB]),
            ],
          ),
          activeCutId: cutA.id,
        );

        fixture.coordinator.renameCut(cutId: cutB.id, newName: 'Cut A');

        expect(_cutById(fixture.project, cutA.id).name, 'Cut A');
        expect(_cutById(fixture.project, cutB.id).name, 'Cut A');
        expect(_cutById(fixture.project, cutB.id).id, cutB.id);
        expect(fixture.historyManager.undoCount, 1);

        fixture.historyManager.undo();

        expect(_cutById(fixture.project, cutB.id).name, 'Cut B');
        expect(fixture.historyManager.redoCount, 1);

        fixture.historyManager.redo();

        expect(_cutById(fixture.project, cutB.id).name, 'Cut A');
        expect(fixture.historyManager.undoCount, 1);
      },
    );

    test(
      'reorderCut executes through history without changing activeCutId',
      () {
        final cutA = _cut(id: 'cut-1', name: 'Cut A');
        final cutB = _cut(id: 'cut-2', name: 'Cut B');
        final cutC = _cut(id: 'cut-3', name: 'Cut C');
        final fixture = _fixture(
          _project(
            tracks: [
              _track(id: 'track-1', name: 'Video', cuts: [cutA, cutB, cutC]),
            ],
          ),
          activeCutId: cutB.id,
        );

        fixture.coordinator.reorderCut(
          trackId: const TrackId('track-1'),
          cutId: cutA.id,
          newIndex: 2,
        );

        expect(fixture.cutsFor(const TrackId('track-1')), [cutB, cutC, cutA]);
        expect(fixture.editingSession.activeCutId, cutB.id);
        expect(fixture.historyManager.undoCount, 1);
        expect(fixture.historyManager.redoCount, 0);

        fixture.historyManager.undo();

        expect(fixture.cutsFor(const TrackId('track-1')), [cutA, cutB, cutC]);
        expect(fixture.editingSession.activeCutId, cutB.id);
        expect(fixture.historyManager.undoCount, 0);
        expect(fixture.historyManager.redoCount, 1);

        fixture.historyManager.redo();

        expect(fixture.cutsFor(const TrackId('track-1')), [cutB, cutC, cutA]);
        expect(fixture.editingSession.activeCutId, cutB.id);
        expect(fixture.historyManager.undoCount, 1);
        expect(fixture.historyManager.redoCount, 0);
      },
    );

    test('drag reorder plan uses track-local index in a later Track', () {
      final cutA1 = _cut(id: 'a1', name: 'A1');
      final cutA2 = _cut(id: 'a2', name: 'A2');
      final cutB1 = _cut(id: 'b1', name: 'B1');
      final cutB2 = _cut(id: 'b2', name: 'B2');
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-a', name: 'Track A', cuts: [cutA1, cutA2]),
            _track(id: 'track-b', name: 'Track B', cuts: [cutB1, cutB2]),
          ],
        ),
        activeCutId: cutB1.id,
      );
      const planner = CutReorderPlanner();

      final plan = planner.planSameTrackDrop(
        project: fixture.project,
        draggedCutId: cutB1.id,
        targetTrackId: const TrackId('track-b'),
        targetCutIndex: 1,
      );

      expect(plan, isNotNull);
      fixture.coordinator.reorderCut(
        trackId: plan!.trackId,
        cutId: plan.cutId,
        newIndex: plan.newIndex,
      );

      expect(fixture.cutsFor(const TrackId('track-a')), [cutA1, cutA2]);
      expect(fixture.cutsFor(const TrackId('track-b')), [cutB2, cutB1]);
      expect(fixture.editingSession.activeCutId, cutB1.id);
    });

    test('cross-track drag reorder plan is ignored without mutation', () {
      final cutA1 = _cut(id: 'a1', name: 'A1');
      final cutB1 = _cut(id: 'b1', name: 'B1');
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-a', name: 'Track A', cuts: [cutA1]),
            _track(id: 'track-b', name: 'Track B', cuts: [cutB1]),
          ],
        ),
        activeCutId: cutA1.id,
      );
      const planner = CutReorderPlanner();

      final plan = planner.planSameTrackDrop(
        project: fixture.project,
        draggedCutId: cutA1.id,
        targetTrackId: const TrackId('track-b'),
        targetCutIndex: 0,
      );
      if (plan != null) {
        fixture.coordinator.reorderCut(
          trackId: plan.trackId,
          cutId: plan.cutId,
          newIndex: plan.newIndex,
        );
      }

      expect(plan, isNull);
      expect(fixture.cutsFor(const TrackId('track-a')), [cutA1]);
      expect(fixture.cutsFor(const TrackId('track-b')), [cutB1]);
      expect(fixture.historyManager.undoCount, 0);
    });

    test(
      'missing dragged Cut drag reorder plan is ignored without history',
      () {
        final cutA1 = _cut(id: 'a1', name: 'A1');
        final fixture = _fixture(
          _project(
            tracks: [
              _track(id: 'track-a', name: 'Track A', cuts: [cutA1]),
            ],
          ),
          activeCutId: cutA1.id,
        );
        const planner = CutReorderPlanner();

        final plan = planner.planSameTrackDrop(
          project: fixture.project,
          draggedCutId: const CutId('missing-cut'),
          targetTrackId: const TrackId('track-a'),
          targetCutIndex: 0,
        );
        if (plan != null) {
          fixture.coordinator.reorderCut(
            trackId: plan.trackId,
            cutId: plan.cutId,
            newIndex: plan.newIndex,
          );
        }

        expect(plan, isNull);
        expect(fixture.cutsFor(const TrackId('track-a')), [cutA1]);
        expect(fixture.editingSession.activeCutId, cutA1.id);
        expect(fixture.historyManager.undoCount, 0);
        expect(fixture.historyManager.redoCount, 0);
      },
    );

    test('same-Cut drag reorder plan is ignored without history', () {
      final cutA1 = _cut(id: 'a1', name: 'A1');
      final cutA2 = _cut(id: 'a2', name: 'A2');
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-a', name: 'Track A', cuts: [cutA1, cutA2]),
          ],
        ),
        activeCutId: cutA2.id,
      );
      const planner = CutReorderPlanner();

      final plan = planner.planSameTrackDrop(
        project: fixture.project,
        draggedCutId: cutA2.id,
        targetTrackId: const TrackId('track-a'),
        targetCutIndex: 1,
      );
      if (plan != null) {
        fixture.coordinator.reorderCut(
          trackId: plan.trackId,
          cutId: plan.cutId,
          newIndex: plan.newIndex,
        );
      }

      expect(plan, isNull);
      expect(fixture.cutsFor(const TrackId('track-a')), [cutA1, cutA2]);
      expect(fixture.editingSession.activeCutId, cutA2.id);
      expect(fixture.historyManager.undoCount, 0);
      expect(fixture.historyManager.redoCount, 0);
    });

    test(
      'deleteCut deletes an active cut and lets the command select fallback',
      () {
        final cutA = _cut(id: 'cut-1', name: 'Cut A');
        final cutB = _cut(id: 'cut-2', name: 'Cut B');
        final fixture = _fixture(
          _project(
            tracks: [
              _track(id: 'track-1', name: 'Video', cuts: [cutA, cutB]),
            ],
          ),
          activeCutId: cutA.id,
        );

        fixture.coordinator.deleteCut(cutId: cutA.id);

        expect(fixture.cutsFor(const TrackId('track-1')), [cutB]);
        expect(fixture.editingSession.activeCutId, cutB.id);
        expect(fixture.historyManager.undoCount, 1);

        fixture.historyManager.undo();

        expect(fixture.cutsFor(const TrackId('track-1')), [cutA, cutB]);
        expect(fixture.editingSession.activeCutId, cutA.id);
        expect(fixture.historyManager.redoCount, 1);

        fixture.historyManager.redo();

        expect(fixture.cutsFor(const TrackId('track-1')), [cutB]);
        expect(fixture.editingSession.activeCutId, cutB.id);
        expect(fixture.historyManager.undoCount, 1);
      },
    );

    test('deleteCut removes a non-active cut without changing activeCutId', () {
      final activeCut = _cut(id: 'cut-1', name: 'Active');
      final deletedCut = _cut(id: 'cut-2', name: 'Deleted');
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-1', name: 'Video', cuts: [activeCut, deletedCut]),
          ],
        ),
        activeCutId: activeCut.id,
      );

      fixture.coordinator.deleteCut(cutId: deletedCut.id);

      expect(fixture.cutsFor(const TrackId('track-1')), [activeCut]);
      expect(fixture.editingSession.activeCutId, activeCut.id);
      expect(fixture.historyManager.undoCount, 1);

      fixture.historyManager.undo();

      expect(fixture.cutsFor(const TrackId('track-1')), [
        activeCut,
        deletedCut,
      ]);
      expect(fixture.editingSession.activeCutId, activeCut.id);
      expect(fixture.historyManager.redoCount, 1);

      fixture.historyManager.redo();

      expect(fixture.cutsFor(const TrackId('track-1')), [activeCut]);
      expect(fixture.editingSession.activeCutId, activeCut.id);
      expect(fixture.historyManager.undoCount, 1);
    });

    test('deleteCut plans replacement IDs when deleting the last cut', () {
      final onlyCut = _cut(
        id: 'cut-1',
        name: 'Only',
        layers: [_layer(id: 'layer-1')],
      );
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-1', name: 'Video', cuts: [onlyCut]),
          ],
        ),
        activeCutId: onlyCut.id,
      );

      fixture.coordinator.deleteCut(cutId: onlyCut.id);

      var cuts = fixture.cutsFor(const TrackId('track-1'));
      expect(cuts, hasLength(1));
      expect(cuts.single.id, const CutId('cut-2'));
      expect(cuts.single.layers.single.id, const LayerId('layer-2'));
      expect(fixture.editingSession.activeCutId, const CutId('cut-2'));
      expect(fixture.historyManager.undoCount, 1);

      fixture.historyManager.undo();

      expect(fixture.cutsFor(const TrackId('track-1')), [onlyCut]);
      expect(fixture.editingSession.activeCutId, onlyCut.id);
      expect(fixture.historyManager.redoCount, 1);

      fixture.historyManager.redo();

      cuts = fixture.cutsFor(const TrackId('track-1'));
      expect(cuts.single.id, const CutId('cut-2'));
      expect(fixture.editingSession.activeCutId, const CutId('cut-2'));
    });

    test(
      'duplicateCut plans IDs, uses default copy name, and records undo/redo',
      () {
        final sourceCut = _cut(
          id: 'cut-1',
          name: 'Source',
          layers: [
            _layer(
              id: 'layer-1',
              frames: [
                _frame(id: 'frame-1'),
                _frame(id: 'frame-3'),
              ],
            ),
          ],
        );
        final targetCut = _cut(
          id: 'cut-3',
          name: 'Target Existing',
          layers: [
            _layer(
              id: 'layer-3',
              frames: [_frame(id: 'frame-2')],
            ),
          ],
        );
        final fixture = _fixture(
          _project(
            tracks: [
              _track(
                id: 'track-source',
                name: 'Source Track',
                cuts: [sourceCut],
              ),
              _track(
                id: 'track-target',
                name: 'Target Track',
                cuts: [targetCut],
              ),
            ],
          ),
          activeCutId: sourceCut.id,
        );

        fixture.coordinator.duplicateCut(
          sourceCutId: sourceCut.id,
          targetTrackId: const TrackId('track-target'),
        );

        var targetCuts = fixture.cutsFor(const TrackId('track-target'));
        expect(targetCuts, hasLength(2));
        final duplicate = targetCuts.last;
        expect(duplicate.id, const CutId('cut-2'));
        expect(duplicate.name, 'Source Copy');
        expect(duplicate.layers.single.id, const LayerId('layer-2'));
        expect(duplicate.layers.single.frames.map((frame) => frame.id), [
          const FrameId('frame-4'),
          const FrameId('frame-5'),
        ]);
        expect(fixture.cutsFor(const TrackId('track-source')), [sourceCut]);
        expect(fixture.editingSession.activeCutId, const CutId('cut-2'));
        expect(fixture.historyManager.undoCount, 1);

        fixture.historyManager.undo();

        expect(fixture.cutsFor(const TrackId('track-target')), [targetCut]);
        expect(fixture.editingSession.activeCutId, sourceCut.id);
        expect(fixture.historyManager.redoCount, 1);

        fixture.historyManager.redo();

        targetCuts = fixture.cutsFor(const TrackId('track-target'));
        expect(targetCuts.last, duplicate);
        expect(fixture.editingSession.activeCutId, const CutId('cut-2'));
        expect(fixture.historyManager.undoCount, 1);
      },
    );

    test('duplicateCut throws StateError when source cut is missing', () {
      final existingCut = _cut(id: 'cut-1', name: 'Existing');
      final project = _project(
        tracks: [
          _track(id: 'track-1', name: 'Video', cuts: [existingCut]),
        ],
      );
      final fixture = _fixture(project, activeCutId: existingCut.id);
      final beforeJson = fixture.project.toJson();

      expect(
        () => fixture.coordinator.duplicateCut(
          sourceCutId: const CutId('cut-missing'),
          targetTrackId: const TrackId('track-1'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Cut not found: cut-missing'),
          ),
        ),
      );

      expect(fixture.project.toJson(), beforeJson);
      expect(fixture.historyManager.undoCount, 0);
      expect(fixture.historyManager.redoCount, 0);
      expect(fixture.cutsFor(const TrackId('track-1')), [existingCut]);
    });

    test('duplicateCut uses caller-provided duplicate name when supplied', () {
      final sourceCut = _cut(id: 'cut-1', name: 'Source');
      final fixture = _fixture(
        _project(
          tracks: [
            _track(id: 'track-1', name: 'Video', cuts: [sourceCut]),
          ],
        ),
        activeCutId: sourceCut.id,
      );

      fixture.coordinator.duplicateCut(
        sourceCutId: sourceCut.id,
        targetTrackId: const TrackId('track-1'),
        newName: 'Custom Duplicate',
      );

      expect(
        fixture.cutsFor(const TrackId('track-1')).last.name,
        'Custom Duplicate',
      );
    });
  });
}

_Fixture _fixture(Project project, {required CutId activeCutId}) {
  final repository = ProjectRepository(initialProject: project);
  final editingSession = EditingSessionState(activeCutId: activeCutId);
  final historyManager = HistoryManager();
  return _Fixture(
    repository: repository,
    editingSession: editingSession,
    historyManager: historyManager,
    coordinator: CutCommandCoordinator(
      repository: repository,
      editingSession: editingSession,
      historyManager: historyManager,
    ),
  );
}

class _Fixture {
  const _Fixture({
    required this.repository,
    required this.editingSession,
    required this.historyManager,
    required this.coordinator,
  });

  final ProjectRepository repository;
  final EditingSessionState editingSession;
  final HistoryManager historyManager;
  final CutCommandCoordinator coordinator;

  Project get project => repository.requireProject();

  List<Cut> cutsFor(TrackId trackId) {
    for (final track in project.tracks) {
      if (track.id == trackId) {
        return track.cuts;
      }
    }

    throw StateError('Track not found: $trackId');
  }
}

Project _project({required List<Track> tracks}) {
  return Project(
    id: const ProjectId('project-1'),
    name: 'Project',
    tracks: tracks,
    createdAt: DateTime.utc(2024),
  );
}

Track _track({
  required String id,
  required String name,
  List<Cut> cuts = const [],
}) {
  return Track(id: TrackId(id), name: name, cuts: cuts);
}

Cut _cut({String id = 'cut-1', String name = 'Cut', List<Layer>? layers}) {
  return Cut(
    id: CutId(id),
    name: name,
    layers: layers ?? [_layer(id: 'layer-$id')],
    duration: 1,
    canvasSize: const CanvasSize(width: 1280, height: 720),
  );
}

Layer _layer({required String id, List<Frame> frames = const []}) {
  return Layer(id: LayerId(id), name: id, frames: frames);
}

Frame _frame({required String id}) {
  return Frame(id: FrameId(id), duration: 1, strokes: const []);
}

Cut _cutById(Project project, CutId cutId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      if (cut.id == cutId) {
        return cut;
      }
    }
  }

  throw StateError('Cut not found: $cutId');
}
