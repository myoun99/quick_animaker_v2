import '../../models/cut_id.dart';
import '../command.dart';
import '../project_repository.dart';

/// One undoable cut-trim step (storyboard edge-grip drags): applies a set
/// of cut durations at once, because a roll edit moves the boundary between
/// TWO cuts. Execute is idempotent — the drag preview already left the
/// repository holding [after].
class UpdateCutDurationsCommand implements Command {
  UpdateCutDurationsCommand({
    required this.repository,
    required this.before,
    required this.after,
  }) : assert(before.keys.length == after.keys.length);

  final ProjectRepository repository;
  final Map<CutId, int> before;
  final Map<CutId, int> after;

  @override
  String get description => 'Trim cut duration';

  void _apply(Map<CutId, int> durations) {
    for (final entry in durations.entries) {
      repository.updateCutDuration(cutId: entry.key, duration: entry.value);
    }
  }

  @override
  void execute() => _apply(after);

  @override
  void undo() => _apply(before);
}
