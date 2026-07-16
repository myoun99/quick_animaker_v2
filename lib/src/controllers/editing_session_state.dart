import '../models/cut_id.dart';
import '../models/project.dart';
import 'active_cut_helpers.dart';

class EditingSessionState {
  EditingSessionState({required CutId? activeCutId})
    : _activeCutId = activeCutId;

  factory EditingSessionState.forProject(Project project) {
    return EditingSessionState(activeCutId: defaultActiveCutIdFor(project));
  }

  /// NULL = the editing playhead stands in a track GAP (UI-R9 #3): no cut
  /// is selected — the timeline/timesheet show their empty states and the
  /// canvas shows the void. Playback FOLLOW keeps the last cut through
  /// gaps; only editing seeks/scrub commits land here.
  CutId? _activeCutId;

  CutId? get activeCutId => _activeCutId;

  void setActiveCutId(CutId? cutId) {
    _activeCutId = cutId;
  }
}
