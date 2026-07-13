import 'dart:math' as math;
import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
import '../models/brush_paint_command.dart';
import '../models/brush_paint_command_id.dart';
import '../models/brush_stamp_image.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_point.dart';
import '../models/tile_coord.dart';

/// A selection region in canvas coordinates (P9): a closed polygon — the
/// rectangle marquee is its 4-corner special case, the lasso is the
/// freehand path as drawn.
class CanvasSelectionShape {
  CanvasSelectionShape(List<CanvasPoint> points)
    : points = List<CanvasPoint>.unmodifiable(points),
      assert(points.length >= 3, 'a selection polygon needs 3+ points');

  factory CanvasSelectionShape.rect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final minX = math.min(left, right);
    final maxX = math.max(left, right);
    final minY = math.min(top, bottom);
    final maxY = math.max(top, bottom);
    return CanvasSelectionShape([
      CanvasPoint(x: minX, y: minY),
      CanvasPoint(x: maxX, y: minY),
      CanvasPoint(x: maxX, y: maxY),
      CanvasPoint(x: minX, y: maxY),
    ]);
  }

  final List<CanvasPoint> points;

  /// Even-odd ray cast (the polygon closes implicitly).
  bool containsPoint(CanvasPoint point) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i, i += 1) {
      final a = points[i];
      final b = points[j];
      final crosses =
          (a.y > point.y) != (b.y > point.y) &&
          point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
      if (crosses) {
        inside = !inside;
      }
    }
    return inside;
  }

  CanvasSelectionShape translated({required double dx, required double dy}) {
    return CanvasSelectionShape([
      for (final point in points) CanvasPoint(x: point.x + dx, y: point.y + dy),
    ]);
  }
}

/// The commands a selection shape captures (P9 backend rule): a command
/// joins when at least [threshold] of its dabs' CENTERS fall inside the
/// shape — stroke-level selection, deliberately not a raster cut-stamp.
Set<BrushPaintCommandId> selectCommandIdsInShape({
  required List<BrushPaintCommand> commands,
  required CanvasSelectionShape shape,
  double threshold = 0.6,
}) {
  final selected = <BrushPaintCommandId>{};
  for (final command in commands) {
    if (command.sourceDabs.isEmpty) {
      continue;
    }
    var inside = 0;
    for (final dab in command.sourceDabs) {
      if (shape.containsPoint(dab.center)) {
        inside += 1;
      }
    }
    if (inside / command.sourceDabs.length >= threshold) {
      selected.add(command.id);
    }
  }
  return selected;
}

/// The selected dabs translated by (dx, dy) — the P9 move. Only geometry
/// moves; every brush property (size, masks, dynamics) rides along
/// untouched so the re-render is stroke-identical elsewhere.
List<BrushDab> translateDabs(
  List<BrushDab> dabs, {
  required double dx,
  required double dy,
}) {
  return [
    for (final dab in dabs)
      dab.copyWith(
        center: CanvasPoint(x: dab.center.x + dx, y: dab.center.y + dy),
      ),
  ];
}

/// The Ctrl+T free-transform affine (P9b), canvas space:
/// `p' = R(θ) · S(sx, sy) · (p − pivot) + pivot + t` — rotate/scale about
/// the fixed [pivot] (the base box center at session start), then
/// translate. Anchored handle scaling (Photoshop's opposite-corner
/// anchor) is expressed by compensating [tx]/[ty], so ONE composite
/// covers every handle interaction.
class SelectionAffine {
  const SelectionAffine({
    required this.pivot,
    this.sx = 1,
    this.sy = 1,
    this.rotationDegrees = 0,
    this.tx = 0,
    this.ty = 0,
  });

  final CanvasPoint pivot;
  final double sx;
  final double sy;
  final double rotationDegrees;
  final double tx;
  final double ty;

  bool get isIdentity =>
      sx == 1 && sy == 1 && rotationDegrees == 0 && tx == 0 && ty == 0;

  double get _radians => rotationDegrees * math.pi / 180;

  CanvasPoint apply(CanvasPoint point) {
    final lx = (point.x - pivot.x) * sx;
    final ly = (point.y - pivot.y) * sy;
    final cos = math.cos(_radians);
    final sin = math.sin(_radians);
    return CanvasPoint(
      x: lx * cos - ly * sin + pivot.x + tx,
      y: lx * sin + ly * cos + pivot.y + ty,
    );
  }

  SelectionAffine copyWith({
    double? sx,
    double? sy,
    double? rotationDegrees,
    double? tx,
    double? ty,
  }) {
    return SelectionAffine(
      pivot: pivot,
      sx: sx ?? this.sx,
      sy: sy ?? this.sy,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      tx: tx ?? this.tx,
      ty: ty ?? this.ty,
    );
  }
}

/// The selected dabs through [affine] (the Ctrl+T commit): centers map
/// exactly, the scalar dab size scales by √|sx·sy| (the plan's mapping —
/// non-uniform scale approximates through the area factor) and the tip
/// angle turns with the rotation. Brush properties otherwise untouched.
List<BrushDab> transformDabs(List<BrushDab> dabs, SelectionAffine affine) {
  final sizeScale = math.sqrt((affine.sx * affine.sy).abs());
  return [
    for (final dab in dabs)
      dab.copyWith(
        center: affine.apply(dab.center),
        size: math.max(dab.size * sizeScale, 0.01),
        angleDegrees: dab.angleDegrees + affine.rotationDegrees,
      ),
  ];
}

/// The selection region through [affine] — the ants follow the transform.
CanvasSelectionShape transformShape(
  CanvasSelectionShape shape,
  SelectionAffine affine,
) {
  return CanvasSelectionShape([
    for (final point in shape.points) affine.apply(point),
  ]);
}

/// The bitmap-lift pair (R14-④): an erase mask dab that cuts the
/// selection's pixels out of the layer at their origin, and a stamp dab
/// carrying those exact pixels — the Move tool commits the pair (origin
/// vanishes), then drags the STAMP dab alone. Both ride the ordinary
/// stroke funnel, so undo and .qap serialization come free, and a
/// zero-move drop is byte-identical to the original by construction
/// (hard-edged mask: full erase + source-over of the same pixels).
class SelectionLiftDabs {
  const SelectionLiftDabs({required this.eraseDab, required this.stampDab});

  final BrushDab eraseDab;
  final BrushDab stampDab;
}

/// Builds the lift pair for [shape] over the active layer's committed
/// [surface]. Null when the selection covers no canvas pixels. The mask is
/// HARD-EDGED (a pixel is in or out by its center, the same even-odd rule
/// as [CanvasSelectionShape.containsPoint]) — partial coverage would make
/// erase + stamp lose paint at the seam.
SelectionLiftDabs? buildSelectionLiftDabs({
  required CanvasSelectionShape shape,
  required BitmapSurface surface,
  required String liftId,
}) {
  final canvasWidth = surface.canvasSize.width;
  final canvasHeight = surface.canvasSize.height;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final point in shape.points) {
    minX = math.min(minX, point.x);
    minY = math.min(minY, point.y);
    maxX = math.max(maxX, point.x);
    maxY = math.max(maxY, point.y);
  }
  final left = math.max(0, minX.floor());
  final top = math.max(0, minY.floor());
  final rightExclusive = math.min(canvasWidth, maxX.ceil() + 1);
  final bottomExclusive = math.min(canvasHeight, maxY.ceil() + 1);
  if (rightExclusive <= left || bottomExclusive <= top) {
    return null;
  }
  final width = rightExclusive - left;
  final height = bottomExclusive - top;

  // Even-odd scanline mask over the bbox: per row, collect the polygon
  // edge crossings at the pixel-center scanline and fill alternate spans —
  // O(edges × rows + pixels), where the naive per-pixel ray cast made
  // lasso lifts quadratic.
  final mask = Uint8List(width * height);
  final points = shape.points;
  final crossings = <double>[];
  for (var row = 0; row < height; row += 1) {
    final scanY = top + row + 0.5;
    crossings.clear();
    for (var i = 0, j = points.length - 1; i < points.length; j = i, i += 1) {
      final a = points[i];
      final b = points[j];
      if ((a.y > scanY) != (b.y > scanY)) {
        crossings.add((b.x - a.x) * (scanY - a.y) / (b.y - a.y) + a.x);
      }
    }
    crossings.sort();
    for (var c = 0; c + 1 < crossings.length; c += 2) {
      // Pixel centers strictly inside [start, end): x + 0.5 > crossing —
      // the same "point.x < intersection" strictness as containsPoint.
      var spanStart = (crossings[c] - 0.5).ceil();
      var spanEndExclusive = (crossings[c + 1] - 0.5).ceil();
      spanStart = math.max(spanStart, left);
      spanEndExclusive = math.min(spanEndExclusive, rightExclusive);
      for (var x = spanStart; x < spanEndExclusive; x += 1) {
        mask[row * width + (x - left)] = 255;
      }
    }
  }

  // Lift the surface pixels under the mask (straight alpha, byte copies —
  // tile buffers snapshot once per tile).
  final rgba = Uint8List(width * height * 4);
  final tileSize = surface.tileSize;
  var liftedAnything = false;
  final tileCache = <TileCoord, Uint8List?>{};
  for (var row = 0; row < height; row += 1) {
    final y = top + row;
    for (var col = 0; col < width; col += 1) {
      if (mask[row * width + col] == 0) {
        continue;
      }
      final x = left + col;
      final coord = TileCoord(x: x ~/ tileSize, y: y ~/ tileSize);
      final pixels = tileCache.putIfAbsent(
        coord,
        () => surface.tiles[coord]?.pixels,
      );
      if (pixels == null) {
        continue;
      }
      final sourceOffset =
          ((y % tileSize) * tileSize + (x % tileSize)) * 4;
      if (pixels[sourceOffset + 3] == 0) {
        continue;
      }
      final targetOffset = (row * width + col) * 4;
      rgba[targetOffset] = pixels[sourceOffset];
      rgba[targetOffset + 1] = pixels[sourceOffset + 1];
      rgba[targetOffset + 2] = pixels[sourceOffset + 2];
      rgba[targetOffset + 3] = pixels[sourceOffset + 3];
      liftedAnything = true;
    }
  }
  if (!liftedAnything) {
    return null;
  }

  // The erase rides the STAMP path too (R15-④): destination-out from the
  // exact mask bytes — tip-mask erases resample bilinearly and left a
  // half-alpha ring at the silhouette (the fringe + origin remnant).
  final eraseAlpha = Uint8List(width * height * 4);
  for (var index = 0; index < mask.length; index += 1) {
    eraseAlpha[index * 4 + 3] = mask[index];
  }
  final eraseDab = BrushDab(
    center: CanvasPoint(x: left + width / 2, y: top + height / 2),
    color: 0xFF000000,
    size: math.max(width, height).toDouble(),
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 0,
    stamp: BrushStampImage(
      id: 'lift-erase-$liftId',
      width: width,
      height: height,
      rgba: eraseAlpha,
    ),
    erase: true,
  );
  final stampDab = BrushDab(
    center: CanvasPoint(x: left + width / 2, y: top + height / 2),
    color: 0xFF000000,
    size: math.max(width, height).toDouble(),
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 1,
    stamp: BrushStampImage(
      id: 'lift-stamp-$liftId',
      width: width,
      height: height,
      rgba: rgba,
    ),
  );
  return SelectionLiftDabs(eraseDab: eraseDab, stampDab: stampDab);
}
