import '../../controllers/default_cut_helpers.dart';
import '../../controllers/editing_session_state.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/track_id.dart';
import '../command.dart';
import '../project_repository.dart';

class CreateCutCommand implements Command {
  CreateCutCommand({
    required this.repository,
    required this.editingSession,
    required this.trackId,
    required CutId cutId,
    required LayerId layerId,
    required String name,
    this.index,
    CanvasSize canvasSize = defaultCutCanvasSize,
  }) : cut = createDefaultCut(
         cutId: cutId,
         name: name,
         layerId: layerId,
         canvasSize: canvasSize,
       );

  final ProjectRepository repository;
  final EditingSessionState editingSession;
  final TrackId trackId;
  final int? index;
  final Cut cut;

  CutId? _previousActiveCutId;
  int? _resolvedIndex;
  bool _hasExecuted = false;

  @override
  String get description => 'Create cut ${cut.name}';

  @override
  void execute() {
    _previousActiveCutId = editingSession.activeCutId;
    _resolvedIndex ??= index ?? _cutCountForTrack();

    repository.insertCut(trackId: trackId, cut: cut, index: _resolvedIndex);
    editingSession.setActiveCutId(cut.id);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousActiveCutId = _previousActiveCutId;
    if (!_hasExecuted || previousActiveCutId == null) {
      throw StateError('Command has not been executed.');
    }

    repository.removeCut(cutId: cut.id);
    editingSession.setActiveCutId(previousActiveCutId);
  }

  int _cutCountForTrack() {
    final project = repository.requireProject();
    for (final track in project.tracks) {
      if (track.id == trackId) {
        return track.cuts.length;
      }
    }

    throw StateError('Track not found: $trackId');
  }
}
