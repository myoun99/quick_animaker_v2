import '../../services/canvas_selection.dart';
import '../../services/command.dart';
import 'canvas_selection_commands.dart';

/// One committed selection-region change (marquee release, click-away,
/// Ctrl+D) as an undoable step (R11-⑧: selecting is an action like any
/// other). Selection is VIEW state: execute/undo push the region through
/// the selection channel into whatever selection layer is mounted — with
/// none mounted (another tool active) the step no-ops harmlessly.
class SelectionShapeHistoryCommand implements Command {
  SelectionShapeHistoryCommand({
    required this.channel,
    required this.before,
    required this.after,
  });

  final CanvasSelectionCommands channel;
  final CanvasSelectionShape? before;
  final CanvasSelectionShape? after;

  @override
  String get description => after == null ? 'Deselect' : 'Select';

  @override
  void execute() {
    channel.applyShape(after);
  }

  @override
  void undo() {
    channel.applyShape(before);
  }
}
