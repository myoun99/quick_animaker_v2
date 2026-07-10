import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_paint_command_id.dart';
import '../brush_frame_editing_coordinator.dart';
import '../cache_invalidation_executor.dart';
import '../command.dart';

/// One selection move/transform as ONE app-level undo entry (P9): the
/// before/after dab maps of the affected commands, applied through the
/// coordinator's in-place rewrite. Dab lists are compact source geometry
/// (never bitmaps), so holding both sides on the undo stack stays cheap —
/// the R8-B rule (no raster payloads on the app stack) holds.
class BrushSelectionTransformHistoryCommand implements Command {
  BrushSelectionTransformHistoryCommand({
    required this.coordinator,
    required this.frameKey,
    required Map<BrushPaintCommandId, List<BrushDab>> before,
    required Map<BrushPaintCommandId, List<BrushDab>> after,
    this.cacheInvalidationSink,
    this.description = 'Move selection',
  }) : _before = Map.unmodifiable(before),
       _after = Map.unmodifiable(after);

  final BrushFrameEditingCoordinator coordinator;

  /// The frame the selection lived on — undo/redo target it even after
  /// the playhead moved elsewhere.
  final BrushFrameKey frameKey;

  final CacheInvalidationSink? cacheInvalidationSink;

  final Map<BrushPaintCommandId, List<BrushDab>> _before;
  final Map<BrushPaintCommandId, List<BrushDab>> _after;

  @override
  final String description;

  @override
  void execute() {
    coordinator.rewritePaintCommandDabs(
      _after,
      frameKey: frameKey,
      cacheInvalidationSink: cacheInvalidationSink,
    );
  }

  @override
  void undo() {
    coordinator.rewritePaintCommandDabs(
      _before,
      frameKey: frameKey,
      cacheInvalidationSink: cacheInvalidationSink,
    );
  }
}
