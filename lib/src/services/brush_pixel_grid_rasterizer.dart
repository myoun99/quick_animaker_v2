import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
import '../models/brush_dab_sequence.dart';
import '../models/brush_paint_command.dart';
import 'bitmap_surface_brush_commit.dart';

/// Pixel-grid rasterizer for every visible brush display path.
///
/// Source commands may contain floating point dab/input data, but visible output
/// is always materialized into [BitmapSurface] tiles rather than painted as
/// smooth paths or vector primitives.
class BrushPixelGridRasterizer {
  const BrushPixelGridRasterizer();

  BrushSurfaceMaterialization rasterizeCommand({
    required BitmapSurface baseSurface,
    required BrushPaintCommand command,
  }) {
    return rasterizeDabs(baseSurface: baseSurface, dabs: command.sourceDabs);
  }

  BrushSurfaceMaterialization rasterizeDabs({
    required BitmapSurface baseSurface,
    required Iterable<BrushDab> dabs,
  }) {
    return materializeBrushDabSequenceOnBitmapSurface(
      surface: baseSurface,
      sequence: BrushDabSequence(List.unmodifiable(dabs)),
    );
  }
}
