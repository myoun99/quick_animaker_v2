import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
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
/// [promotedTiles] (promotion round) go one step further: the live
/// overlay already blended the stroke into FINISHED tiles — the exact
/// bytes the commit would compute — against [promotedBase]. When the cel
/// surface is still that same object, the commit is a tile PUT: no
/// re-blend, no re-decode, and the images the user watched hand over to
/// the new tiles. If the surface moved underneath (anything committed in
/// between), the commit falls back to the dab route and the promotion is
/// simply ignored — correctness never depends on the fast path.
class BrushStrokeCommitData {
  BrushStrokeCommitData({
    required List<BrushDab> sourceDabs,
    this.strokePixels,
    this.strokeBounds,
    this.blendMode = BrushBlendMode.color,
    this.promotedBase,
    this.promotedTiles,
  }) : sourceDabs = List<BrushDab>.unmodifiable(sourceDabs);

  final List<BrushDab> sourceDabs;
  final Uint8List? strokePixels;
  final DirtyRegion? strokeBounds;
  final BrushBlendMode blendMode;

  /// The cel surface the promoted tiles were blended against.
  final BitmapSurface? promotedBase;

  /// Finished tiles ready to adopt (only the coordinates whose pixels
  /// actually differ from [promotedBase]).
  final List<BitmapTile>? promotedTiles;
}
