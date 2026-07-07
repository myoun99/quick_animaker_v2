import '../models/brush_dab.dart';
import '../models/brush_pixel_coverage.dart';
import '../models/rgba_color.dart';
import 'rgba_blend.dart';

double effectiveBrushPixelOpacity({
  required BrushDab dab,
  required BrushPixelCoverage coverage,
}) {
  return dab.opacity * coverage.coverage;
}

RgbaColor blendBrushDabPixelCoverage({
  required BrushDab dab,
  required BrushPixelCoverage coverage,
  required RgbaColor destination,
}) {
  if (dab.erase) {
    return rgbaDestinationOut(
      source: RgbaColor.fromArgbInt(dab.color),
      destination: destination,
      opacity: effectiveBrushPixelOpacity(dab: dab, coverage: coverage),
      flow: dab.flow,
    );
  }
  return rgbaSourceOver(
    source: RgbaColor.fromArgbInt(dab.color),
    destination: destination,
    opacity: effectiveBrushPixelOpacity(dab: dab, coverage: coverage),
    flow: dab.flow,
  );
}
