import '../models/bitmap_surface.dart';
import '../models/brush_commit_result.dart';

BitmapSurface revertBrushCommitResultOnBitmapSurface({
  required BitmapSurface surface,
  required BrushCommitResult result,
}) {
  if (result.isNoOp) return surface;
  if (surface != result.afterSurface) {
    throw ArgumentError(
      'BrushCommitResult afterSurface must match the surface being reverted.',
    );
  }
  return result.beforeSurface;
}
