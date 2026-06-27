import 'dart:math' as math;

class BrushHistoryPolicy {
  const BrushHistoryPolicy({
    required this.userUndoLimit,
    required this.deferredBakeRatio,
    this.minimumDeferredBakeBuffer = 16,
  }) : assert(userUndoLimit > 0),
       assert(deferredBakeRatio >= 0),
       assert(minimumDeferredBakeBuffer >= 0);

  final int userUndoLimit;
  final double deferredBakeRatio;
  final int minimumDeferredBakeBuffer;

  int get deferredBakeLimit => math.max(
    minimumDeferredBakeBuffer,
    (userUndoLimit * deferredBakeRatio).round(),
  );
}
