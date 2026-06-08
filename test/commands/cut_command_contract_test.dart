import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/commands/create_cut_command.dart';
import 'package:quick_animaker_v2/src/services/commands/delete_cut_command.dart';
import 'package:quick_animaker_v2/src/services/commands/duplicate_cut_command.dart';
import 'package:quick_animaker_v2/src/services/commands/rename_cut_command.dart';
import 'package:quick_animaker_v2/src/controllers/editing_session_state.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('Cut command contracts', () {
    group('activeCutId safety after execute', () {
      test('create cut makes the created cut active and valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);

        CreateCutCommand(
          repository: repository,
          editingSession: editingSession,
          trackId: _trackId,
          cutId: const CutId('cut-created'),
          layerId: const LayerId('layer-created'),
          name: 'Created Cut',
        ).execute();

        expect(editingSession.activeCutId, const CutId('cut-created'));
        _expectActiveCutExists(repository, editingSession);
      });

      test('rename cut leaves the current active cut valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final repository = _repositoryWithCuts([cutA, cutB]);
        final editingSession = EditingSessionState(activeCutId: cutB.id);

        RenameCutCommand(
          repository: repository,
          cutId: cutA.id,
          newName: 'Renamed Cut A',
        ).execute();

        expect(editingSession.activeCutId, cutB.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('duplicate cut makes the duplicate active and valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);

        DuplicateCutCommand(
          repository: repository,
          editingSession: editingSession,
          sourceCutId: cutA.id,
          targetTrackId: _trackId,
          newCutId: const CutId('cut-copy'),
          newName: 'Cut A Copy',
          layerIdMap: <LayerId, LayerId>{},
          frameIdMap: <FrameId, FrameId>{},
        ).execute();

        expect(editingSession.activeCutId, const CutId('cut-copy'));
        _expectActiveCutExists(repository, editingSession);
      });

      test('delete inactive cut preserves the current active cut as valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final repository = _repositoryWithCuts([cutA, cutB]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);

        DeleteCutCommand(
          repository: repository,
          editingSession: editingSession,
          cutId: cutB.id,
        ).execute();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('delete active cut falls back to the previous cut first', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final cutC = _cut(id: 'cut-c', name: 'Cut C');
        final repository = _repositoryWithCuts([cutA, cutB, cutC]);
        final editingSession = EditingSessionState(activeCutId: cutB.id);

        DeleteCutCommand(
          repository: repository,
          editingSession: editingSession,
          cutId: cutB.id,
        ).execute();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('delete active first cut falls back to the next cut', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final repository = _repositoryWithCuts([cutA, cutB]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);

        DeleteCutCommand(
          repository: repository,
          editingSession: editingSession,
          cutId: cutA.id,
        ).execute();

        expect(editingSession.activeCutId, cutB.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('delete the last remaining cut creates an active replacement', () {
        final onlyCut = _cut(id: 'cut-only', name: 'Only Cut');
        final repository = _repositoryWithCuts([onlyCut]);
        final editingSession = EditingSessionState(activeCutId: onlyCut.id);

        DeleteCutCommand(
          repository: repository,
          editingSession: editingSession,
          cutId: onlyCut.id,
          replacementCutId: const CutId('cut-replacement'),
          replacementLayerId: const LayerId('layer-replacement'),
        ).execute();

        final cuts = _allCuts(repository);
        expect(cuts, hasLength(1));
        expect(cuts.single.id, const CutId('cut-replacement'));
        expect(editingSession.activeCutId, const CutId('cut-replacement'));
        _expectActiveCutExists(repository, editingSession);
      });
    });

    group('activeCutId safety after undo', () {
      test('undo create cut restores a valid previous active cut', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          CreateCutCommand(
            repository: repository,
            editingSession: editingSession,
            trackId: _trackId,
            cutId: const CutId('cut-created'),
            layerId: const LayerId('layer-created'),
            name: 'Created Cut',
          ),
        );
        historyManager.undo();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('undo rename cut leaves the active cut valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          RenameCutCommand(
            repository: repository,
            cutId: cutA.id,
            newName: 'Renamed Cut A',
          ),
        );
        historyManager.undo();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('undo delete cut restores the deleted active cut as valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final repository = _repositoryWithCuts([cutA, cutB]);
        final editingSession = EditingSessionState(activeCutId: cutB.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          DeleteCutCommand(
            repository: repository,
            editingSession: editingSession,
            cutId: cutB.id,
          ),
        );
        historyManager.undo();

        expect(editingSession.activeCutId, cutB.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('undo duplicate cut restores a valid previous active cut', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          DuplicateCutCommand(
            repository: repository,
            editingSession: editingSession,
            sourceCutId: cutA.id,
            targetTrackId: _trackId,
            newCutId: const CutId('cut-copy'),
            newName: 'Cut A Copy',
            layerIdMap: <LayerId, LayerId>{},
            frameIdMap: <FrameId, FrameId>{},
          ),
        );
        historyManager.undo();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('undo delete last cut removes replacement and restores active cut', () {
        final onlyCut = _cut(id: 'cut-only', name: 'Only Cut');
        final repository = _repositoryWithCuts([onlyCut]);
        final editingSession = EditingSessionState(activeCutId: onlyCut.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          DeleteCutCommand(
            repository: repository,
            editingSession: editingSession,
            cutId: onlyCut.id,
            replacementCutId: const CutId('cut-replacement'),
            replacementLayerId: const LayerId('layer-replacement'),
          ),
        );
        historyManager.undo();

        expect(_allCuts(repository), [onlyCut]);
        expect(editingSession.activeCutId, onlyCut.id);
        _expectActiveCutExists(repository, editingSession);
      });
    });

    group('activeCutId safety after redo', () {
      test('redo create cut returns to a valid created active cut', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          CreateCutCommand(
            repository: repository,
            editingSession: editingSession,
            trackId: _trackId,
            cutId: const CutId('cut-created'),
            layerId: const LayerId('layer-created'),
            name: 'Created Cut',
          ),
        );
        historyManager.undo();
        historyManager.redo();

        expect(editingSession.activeCutId, const CutId('cut-created'));
        _expectActiveCutExists(repository, editingSession);
      });

      test('redo rename cut leaves the active cut valid', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          RenameCutCommand(
            repository: repository,
            cutId: cutA.id,
            newName: 'Renamed Cut A',
          ),
        );
        historyManager.undo();
        historyManager.redo();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('redo delete cut returns to a valid fallback active cut', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Cut B');
        final repository = _repositoryWithCuts([cutA, cutB]);
        final editingSession = EditingSessionState(activeCutId: cutB.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          DeleteCutCommand(
            repository: repository,
            editingSession: editingSession,
            cutId: cutB.id,
          ),
        );
        historyManager.undo();
        historyManager.redo();

        expect(editingSession.activeCutId, cutA.id);
        _expectActiveCutExists(repository, editingSession);
      });

      test('redo duplicate cut returns to a valid duplicate active cut', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final repository = _repositoryWithCuts([cutA]);
        final editingSession = EditingSessionState(activeCutId: cutA.id);
        final historyManager = HistoryManager();

        historyManager.execute(
          DuplicateCutCommand(
            repository: repository,
            editingSession: editingSession,
            sourceCutId: cutA.id,
            targetTrackId: _trackId,
            newCutId: const CutId('cut-copy'),
            newName: 'Cut A Copy',
            layerIdMap: <LayerId, LayerId>{},
            frameIdMap: <FrameId, FrameId>{},
          ),
        );
        historyManager.undo();
        historyManager.redo();

        expect(editingSession.activeCutId, const CutId('cut-copy'));
        _expectActiveCutExists(repository, editingSession);
      });
    });

    group('Cut rename duplicate-name policy', () {
      test('renaming a cut to another cut display name is allowed', () {
        final cutA = _cut(id: 'cut-a', name: 'Cut A');
        final cutB = _cut(id: 'cut-b', name: 'Shared Name');
        final repository = _repositoryWithCuts([cutA, cutB]);

        RenameCutCommand(
          repository: repository,
          cutId: cutA.id,
          newName: 'Shared Name',
        ).execute();

        expect(_cutNames(repository), ['Shared Name', 'Shared Name']);
        expect(_cutIds(repository), [cutA.id, cutB.id]);
      });

      test('duplicate cut names do not merge cut identities or contents', () {
        final cutA = _cutWithLayer(
          id: 'cut-a',
          name: 'Shared Name',
          layerId: 'layer-a',
        );
        final cutB = _cutWithLayer(
          id: 'cut-b',
          name: 'Cut B',
          layerId: 'layer-b',
        );
        final repository = _repositoryWithCuts([cutA, cutB]);

        RenameCutCommand(
          repository: repository,
          cutId: cutB.id,
          newName: 'Shared Name',
        ).execute();

        final cuts = _allCuts(repository);
        expect(cuts, hasLength(2));
        expect(cuts.map((cut) => cut.name), ['Shared Name', 'Shared Name']);
        expect(cuts.map((cut) => cut.id), [cutA.id, cutB.id]);
        expect(cuts[0].layers.single.id, const LayerId('layer-a'));
        expect(cuts[1].layers.single.id, const LayerId('layer-b'));
      });
    });
  });
}

const _projectId = ProjectId('project-1');
const _trackId = TrackId('track-1');
const _canvasSize = CanvasSize(width: 1280, height: 720);

ProjectRepository _repositoryWithCuts(List<Cut> cuts) {
  return ProjectRepository(
    initialProject: Project(
      id: _projectId,
      name: 'Project',
      tracks: [Track(id: _trackId, name: 'Video', cuts: cuts)],
      createdAt: DateTime.utc(2024),
    ),
  );
}

Cut _cut({required String id, required String name}) {
  return Cut(
    id: CutId(id),
    name: name,
    layers: const [],
    duration: 24,
    canvasSize: _canvasSize,
  );
}

Cut _cutWithLayer({
  required String id,
  required String name,
  required String layerId,
}) {
  return Cut(
    id: CutId(id),
    name: name,
    layers: [Layer(id: LayerId(layerId), name: 'Layer', frames: const [])],
    duration: 24,
    canvasSize: _canvasSize,
  );
}

List<Cut> _allCuts(ProjectRepository repository) {
  return repository
      .requireProject()
      .tracks
      .expand((track) => track.cuts)
      .toList();
}

Iterable<CutId> _cutIds(ProjectRepository repository) {
  return _allCuts(repository).map((cut) => cut.id);
}

Iterable<String> _cutNames(ProjectRepository repository) {
  return _allCuts(repository).map((cut) => cut.name);
}

void _expectActiveCutExists(
  ProjectRepository repository,
  EditingSessionState editingSession,
) {
  expect(_cutIds(repository), contains(editingSession.activeCutId));
}
