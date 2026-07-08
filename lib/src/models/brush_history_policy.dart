import 'dart:math' as math;

class BrushHistoryPolicy {
  const BrushHistoryPolicy({
    required this.userUndoLimit,
    required this.deferredBakeRatio,
    this.minimumDeferredBakeBuffer = 16,
    this.materializationByteBudget = defaultMaterializationByteBudget,
  }) : assert(userUndoLimit > 0),
       assert(deferredBakeRatio >= 0),
       assert(minimumDeferredBakeBuffer >= 0),
       assert(materializationByteBudget > 0);

  /// Default cap for the per-frame bitmap undo snapshots (≈ 6 full-canvas
  /// strokes at the 2340×1654 default canvas; huge-canvas strokes trim to
  /// fewer fast entries, older undos fall back to the command replay).
  static const int defaultMaterializationByteBudget = 256 * 1024 * 1024;

  final int userUndoLimit;
  final double deferredBakeRatio;
  final int minimumDeferredBakeBuffer;

  /// Byte cap for a frame's bitmap materialization history (the changed
  /// tiles each undo/redo snapshot retains). The undo COUNT limit alone is
  /// unbounded in bytes — one full-canvas stroke at 5000×5000 pins ~100MB,
  /// so 24 of them could pin gigabytes. Entries beyond the budget drop from
  /// the deep end; undoing past them still works through the command
  /// replay fallback (the resize path's mechanism), just slower.
  final int materializationByteBudget;

  int get deferredBakeLimit => math.max(
    minimumDeferredBakeBuffer,
    (userUndoLimit * deferredBakeRatio).round(),
  );
}
