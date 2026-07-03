import '../../models/brush_dab.dart';
import '../brush_frame_editing_coordinator.dart';
import '../cache_invalidation_executor.dart';
import '../command.dart';

/// Bridges a brush source stroke into the app-level [HistoryManager].
///
/// The first execute commits the source dabs as a BrushPaintCommand. Later
/// execute calls are redo operations that restore that same command through the
/// coordinator's unified brush undo history. The command never stores bitmap
/// deltas or cache payloads as user-facing undo state.
class BrushStrokeHistoryCommand implements Command {
  BrushStrokeHistoryCommand({
    required this.coordinator,
    required List<BrushDab> sourceDabs,
    this.cacheInvalidationSink,
  }) : sourceDabs = List<BrushDab>.unmodifiable(sourceDabs);

  final BrushFrameEditingCoordinator coordinator;
  final List<BrushDab> sourceDabs;
  final CacheInvalidationSink? cacheInvalidationSink;
  bool _hasCommitted = false;

  @override
  String get description => 'Brush stroke';

  @override
  void execute() {
    if (_hasCommitted) {
      coordinator.redo(cacheInvalidationSink: cacheInvalidationSink);
      return;
    }
    coordinator.commitSourceStroke(sourceDabs: sourceDabs);
    _hasCommitted = true;
  }

  @override
  void undo() {
    coordinator.undo(cacheInvalidationSink: cacheInvalidationSink);
  }
}
