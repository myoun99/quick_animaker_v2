import '../../controllers/cut_deletion_helpers.dart';
import '../../controllers/default_cut_helpers.dart';
import '../../controllers/editing_session_state.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/track_id.dart';
import '../command.dart';
import '../project_repository.dart';

class DeleteCutCommand implements Command {
  DeleteCutCommand({
    required this.repository,
    required this.editingSession,
    required this.cutId,
    this.replacementCutId,
    this.replacementLayerId,
    this.replacementName = 'Cut 1',
    this.replacementCanvasSize = defaultCutCanvasSize,
  });

  final ProjectRepository repository;
  final EditingSessionState editingSession;
  final CutId cutId;
  final CutId? replacementCutId;
  final LayerId? replacementLayerId;
  final String replacementName;
  final CanvasSize replacementCanvasSize;

  Cut? _deletedCut;
  TrackId? _originalTrackId;
  int? _originalIndex;
  CutId? _previousActiveCutId;
  bool _createdReplacementCut = false;
  bool _hasExecuted = false;

  @override
  String get description => 'Delete cut $cutId';

  @override
  void execute() {
    final project = repository.requireProject();
    final location = _findCutLocation(cutId);
    final previousActiveCutId = editingSession.activeCutId;
    final isDeletingActiveCut = previousActiveCutId == cutId;
    final fallbackDecision = isDeletingActiveCut
        ? cutDeletionFallbackFor(project, deletingCutId: cutId)
        : null;

    if (fallbackDecision?.kind == CutDeletionFallbackKind.createDefaultCut &&
        (replacementCutId == null || replacementLayerId == null)) {
      throw StateError(
        'Replacement CutId and LayerId are required when deleting the only cut.',
      );
    }

    _previousActiveCutId = previousActiveCutId;
    _originalTrackId = location.trackId;
    _originalIndex = location.index;
    _deletedCut = repository.removeCut(cutId: cutId);
    _createdReplacementCut = false;

    if (!isDeletingActiveCut) {
      _hasExecuted = true;
      return;
    }

    switch (fallbackDecision!.kind) {
      case CutDeletionFallbackKind.useExistingCut:
        editingSession.setActiveCutId(fallbackDecision.cutId!);
        break;
      case CutDeletionFallbackKind.createDefaultCut:
        final replacement = createDefaultCut(
          cutId: replacementCutId!,
          name: replacementName,
          layerId: replacementLayerId!,
          canvasSize: replacementCanvasSize,
        );
        repository.insertCut(
          trackId: location.trackId,
          cut: replacement,
          index: location.index,
        );
        _createdReplacementCut = true;
        editingSession.setActiveCutId(replacement.id);
        break;
    }

    _hasExecuted = true;
  }

  @override
  void undo() {
    final deletedCut = _deletedCut;
    final originalTrackId = _originalTrackId;
    final originalIndex = _originalIndex;
    final previousActiveCutId = _previousActiveCutId;
    if (!_hasExecuted ||
        deletedCut == null ||
        originalTrackId == null ||
        originalIndex == null ||
        previousActiveCutId == null) {
      throw StateError('Command has not been executed.');
    }

    if (_createdReplacementCut) {
      repository.removeCut(cutId: replacementCutId!);
    }

    repository.insertCut(
      trackId: originalTrackId,
      cut: deletedCut,
      index: originalIndex,
    );
    editingSession.setActiveCutId(previousActiveCutId);
  }

  _CutLocation _findCutLocation(CutId cutId) {
    final project = repository.requireProject();
    for (final track in project.tracks) {
      final cutIndex = track.cuts.indexWhere((cut) => cut.id == cutId);
      if (cutIndex != -1) {
        return _CutLocation(trackId: track.id, index: cutIndex);
      }
    }

    throw StateError('Cut not found: $cutId');
  }
}

class _CutLocation {
  const _CutLocation({required this.trackId, required this.index});

  final TrackId trackId;
  final int index;
}
