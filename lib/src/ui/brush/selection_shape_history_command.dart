import '../../services/canvas_selection_region.dart';
import '../../services/command.dart';
import 'canvas_selection_commands.dart';

/// One committed selection-region change (marquee release, click-away,
/// Ctrl+D) as an undoable step (R11-⑧: selecting is an action like any
/// other). R28-S: the region is APP state on the selection channel, so
/// execute/undo restore it whether or not a selection layer is mounted —
/// undoing a selection while the brush is armed puts the ants back.
class SelectionShapeHistoryCommand implements Command {
  SelectionShapeHistoryCommand({
    required this.channel,
    required this.before,
    required this.after,
  });

  final CanvasSelectionCommands channel;
  final CanvasSelectionRegion? before;
  final CanvasSelectionRegion? after;

  @override
  String get description => after == null ? 'Deselect' : 'Select';

  @override
  void execute() {
    channel.applyRegion(after);
  }

  @override
  void undo() {
    channel.applyRegion(before);
  }
}
