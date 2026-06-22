import '../models/bitmap_surface.dart';
import '../models/brush_commit_result.dart';

BitmapSurface applyBrushCommitResultToBitmapSurface({
  required BitmapSurface surface,
  required BrushCommitResult result,
}) {
  final command = result.command;
  if (command == null) return surface;
  return command.applyAfter(surface);
}
