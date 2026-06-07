import '../models/cut_id.dart';
import '../models/project.dart';
import 'active_cut_helpers.dart';

class EditingSessionState {
  EditingSessionState({required CutId activeCutId})
    : _activeCutId = activeCutId;

  factory EditingSessionState.forProject(Project project) {
    return EditingSessionState(activeCutId: defaultActiveCutIdFor(project));
  }

  CutId _activeCutId;

  CutId get activeCutId => _activeCutId;

  void setActiveCutId(CutId cutId) {
    _activeCutId = cutId;
  }
}
