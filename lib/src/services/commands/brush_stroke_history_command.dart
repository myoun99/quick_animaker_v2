import '../brush_frame_editing_coordinator.dart';
import '../brush_stroke_commit_data.dart';
import '../cache_invalidation_executor.dart';
import '../command.dart';

/// Bridges a brush source stroke into the app-level [HistoryManager].
///
/// The first execute commits the stroke as a BrushPaintCommand (with the
/// pen-up composite fast path when the stroke arrives pre-rasterized). Later
/// execute calls are redo operations that restore that same command through
/// the coordinator's unified brush undo history. The command never stores
/// bitmap deltas or cache payloads as user-facing undo state.
class BrushStrokeHistoryCommand implements Command {
  BrushStrokeHistoryCommand({
    required this.coordinator,
    required this.strokeData,
    this.cacheInvalidationSink,
  });

  final BrushFrameEditingCoordinator coordinator;
  final BrushStrokeCommitData strokeData;
  final CacheInvalidationSink? cacheInvalidationSink;
  bool _hasCommitted = false;
  bool _committedChanges = false;

  @override
  String get description => 'Brush stroke';

  @override
  void execute() {
    if (_hasCommitted) {
      if (_committedChanges) {
        coordinator.redo(cacheInvalidationSink: cacheInvalidationSink);
      }
      return;
    }
    // A stroke that changes no pixels creates no brush undo entry; this
    // app-level command then stays inert so undo/redo never pops an
    // unrelated brush entry.
    _committedChanges =
        coordinator.commitSourceStroke(
          sourceDabs: strokeData.sourceDabs,
          cacheInvalidationSink: cacheInvalidationSink,
          prerasterizedStrokePixels: strokeData.strokePixels,
          prerasterizedStrokeBounds: strokeData.strokeBounds,
        ) !=
        null;
    _hasCommitted = true;
  }

  @override
  void undo() {
    if (!_committedChanges) {
      return;
    }
    coordinator.undo(cacheInvalidationSink: cacheInvalidationSink);
  }
}
