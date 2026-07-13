import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_paint_command_id.dart';
import '../brush_frame_editing_coordinator.dart';
import '../cache_invalidation_executor.dart';
import '../command.dart';

/// Adopts a CONFIRMED move session (R16-①, TVP-style) into app history as
/// ONE undoable step.
///
/// The session's ERASE was committed OUTSIDE app history the moment the
/// move began (the origin must vanish instantly, but nothing is undoable
/// until the user confirms); the stamp floated un-committed through every
/// drag and nudge. The first execute lands the stamp at its confirmed
/// position by rewriting the lift command's dabs; undo/redo then ride the
/// coordinator's unified stack, whose single entry for the lift command
/// covers erase AND stamp — one Ctrl+Z restores the pre-lift picture
/// byte-exactly.
class BrushLiftMoveHistoryCommand implements Command {
  BrushLiftMoveHistoryCommand({
    required this.coordinator,
    required this.commandId,
    required List<BrushDab> confirmedDabs,
    this.frameKey,
    this.cacheInvalidationSink,
  }) : _confirmedDabs = confirmedDabs;

  final BrushFrameEditingCoordinator coordinator;
  final BrushPaintCommandId commandId;
  final BrushFrameKey? frameKey;
  final CacheInvalidationSink? cacheInvalidationSink;

  /// Dropped after the first execute — the stamp's RGBA payload can be
  /// megabytes, and redo rides the coordinator history instead (the same
  /// retention discipline as BrushStrokeHistoryCommand).
  List<BrushDab>? _confirmedDabs;
  bool _confirmed = false;

  @override
  String get description => 'Move selection';

  @override
  void execute() {
    if (_confirmed) {
      coordinator.redo(cacheInvalidationSink: cacheInvalidationSink);
      return;
    }
    coordinator.rewritePaintCommandDabs(
      {commandId: _confirmedDabs!},
      frameKey: frameKey,
      cacheInvalidationSink: cacheInvalidationSink,
    );
    _confirmed = true;
    _confirmedDabs = null;
  }

  @override
  void undo() {
    coordinator.undo(cacheInvalidationSink: cacheInvalidationSink);
  }
}
