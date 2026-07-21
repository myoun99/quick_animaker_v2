import 'dart:typed_data';

import '../models/brush_blend_mode.dart';
import '../models/brush_dab.dart';
import '../models/dirty_region.dart';

/// A finished stroke handed from the interactive canvas to the commit route.
///
/// [sourceDabs] remain the durable source of truth. [strokePixels] /
/// [strokeBounds], when present, carry the stroke already rasterized
/// incrementally while drawing (`BrushLiveStrokeRasterizer`, straight-alpha
/// RGBA, BOUNDS-LOCAL: row-major with stride = the bounds width): the
/// commit then composites this buffer over the existing artwork in one
/// pass instead of re-running the per-dab loop, which both removes the
/// pen-up hiccup and guarantees the committed pixels are exactly the
/// pixels that were on screen while drawing.
///
/// [blendMode] (BB-1, R26 #9) is the stroke's BRUSH blend — carried here
/// so a history REDO reproduces the same pixels no matter what the tool
/// state says by then.
class BrushStrokeCommitData {
  BrushStrokeCommitData({
    required List<BrushDab> sourceDabs,
    this.strokePixels,
    this.strokeBounds,
    this.blendMode = BrushBlendMode.color,
  }) : sourceDabs = List<BrushDab>.unmodifiable(sourceDabs);

  final List<BrushDab> sourceDabs;
  final Uint8List? strokePixels;
  final DirtyRegion? strokeBounds;
  final BrushBlendMode blendMode;
}
