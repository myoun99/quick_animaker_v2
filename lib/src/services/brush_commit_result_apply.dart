import '../models/bitmap_surface.dart';
import '../models/brush_commit_result.dart';

BitmapSurface applyBrushCommitResultToBitmapSurface({
  required BitmapSurface surface,
  required BrushCommitResult result,
}) {
  if (result.isNoOp) return surface;
  if (surface != result.beforeSurface) {
    throw ArgumentError(
      'BrushCommitResult beforeSurface must match the surface being applied.',
    );
  }
  return result.afterSurface;
}
