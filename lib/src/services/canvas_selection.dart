import 'dart:math' as math;
import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
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

/// The lifted stamp through [affine] as a RESAMPLED bitmap stamp (R19
/// pixel selection — Ctrl+T on raster truth):
///
/// - identity returns the dab untouched;
/// - a pure translation only moves the center — byte-exact, the same
///   arithmetic as a drag move;
/// - anything else resamples the stamp's straight-alpha RGBA into the
///   transformed region's axis-aligned bounding box with a Catmull-Rom
///   BICUBIC kernel (R20-D1 — the PS default-quality tier; noticeably
///   sharper than bilinear on rotate/scale). The kernel is interpolating
///   (δ at integer alignment), so axis-aligned 90° rotations stay EXACT
///   pixel permutations. Sampling is alpha-weighted so transparent
///   texels never bleed dark fringes; the negative lobes clamp at the
///   byte edge (the usual bicubic ringing contract).
BrushDab transformStampDab(BrushDab stampDab, SelectionAffine affine) {
  final stamp = stampDab.stamp;
  if (stamp == null || affine.isIdentity) {
    return stampDab;
  }
  if (affine.sx == 1 && affine.sy == 1 && affine.rotationDegrees == 0) {
    return stampDab.copyWith(
      center: CanvasPoint(
        x: stampDab.center.x + affine.tx,
        y: stampDab.center.y + affine.ty,
      ),
    );
  }

  // The stamp draws 1:1 about its center: its canvas-space source rect.
  final srcLeft = stampDab.center.x - stamp.width / 2;
  final srcTop = stampDab.center.y - stamp.height / 2;

  // Output AABB = the transformed source corners.
  final corners = [
    affine.apply(CanvasPoint(x: srcLeft, y: srcTop)),
    affine.apply(CanvasPoint(x: srcLeft + stamp.width, y: srcTop)),
    affine.apply(
      CanvasPoint(x: srcLeft + stamp.width, y: srcTop + stamp.height),
    ),
    affine.apply(CanvasPoint(x: srcLeft, y: srcTop + stamp.height)),
  ];
  var minX = corners.first.x, maxX = corners.first.x;
  var minY = corners.first.y, maxY = corners.first.y;
  for (final corner in corners.skip(1)) {
    minX = math.min(minX, corner.x);
    maxX = math.max(maxX, corner.x);
    minY = math.min(minY, corner.y);
    maxY = math.max(maxY, corner.y);
  }
  final outLeft = minX.floor();
  final outTop = minY.floor();
  final outWidth = math.max(1, maxX.ceil() - outLeft);
  final outHeight = math.max(1, maxY.ceil() - outTop);

  // Inverse mapping: q = R·S·(p − pivot) + pivot + t
  //              ⇒  p = S⁻¹·R⁻¹·(q − pivot − t) + pivot.
  final radians = affine.rotationDegrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  final invSx = 1 / affine.sx;
  final invSy = 1 / affine.sy;

  final source = stamp.rgba;
  final bytes = Uint8List(outWidth * outHeight * 4);
  for (var oy = 0; oy < outHeight; oy += 1) {
    final qy = outTop + oy + 0.5 - affine.pivot.y - affine.ty;
    for (var ox = 0; ox < outWidth; ox += 1) {
      final qx = outLeft + ox + 0.5 - affine.pivot.x - affine.tx;
      // R(−θ) then S⁻¹, back into stamp pixel space.
      final px = (qx * cos + qy * sin) * invSx + affine.pivot.x;
      final py = (-qx * sin + qy * cos) * invSy + affine.pivot.y;
      final sampleX = px - srcLeft - 0.5;
      final sampleY = py - srcTop - 0.5;
      final x0 = sampleX.floor();
      final y0 = sampleY.floor();
      final fx = sampleX - x0;
      final fy = sampleY - y0;
      _catmullRomWeights(fx, _cubicWeightsX);
      _catmullRomWeights(fy, _cubicWeightsY);

      var alphaAcc = 0.0;
      var redAcc = 0.0, greenAcc = 0.0, blueAcc = 0.0;
      for (var tapJ = 0; tapJ < 4; tapJ += 1) {
        final tapY = y0 - 1 + tapJ;
        if (tapY < 0 || tapY >= stamp.height) {
          continue;
        }
        final weightY = _cubicWeightsY[tapJ];
        if (weightY == 0) {
          continue;
        }
        final rowOffset = tapY * stamp.width;
        for (var tapI = 0; tapI < 4; tapI += 1) {
          final tapX = x0 - 1 + tapI;
          if (tapX < 0 || tapX >= stamp.width) {
            continue;
          }
          final weight = _cubicWeightsX[tapI] * weightY;
          if (weight == 0) {
            continue;
          }
          final offset = (rowOffset + tapX) * 4;
          final alpha = source[offset + 3];
          if (alpha == 0) {
            continue;
          }
          final weightedAlpha = weight * alpha;
          alphaAcc += weightedAlpha;
          redAcc += weightedAlpha * source[offset];
          greenAcc += weightedAlpha * source[offset + 1];
          blueAcc += weightedAlpha * source[offset + 2];
        }
      }
      if (alphaAcc <= 0) {
        continue;
      }
      final offset = (oy * outWidth + ox) * 4;
      bytes[offset] = (redAcc / alphaAcc).round().clamp(0, 255);
      bytes[offset + 1] = (greenAcc / alphaAcc).round().clamp(0, 255);
      bytes[offset + 2] = (blueAcc / alphaAcc).round().clamp(0, 255);
      bytes[offset + 3] = alphaAcc.round().clamp(0, 255);
    }
  }

  return stampDab.copyWith(
    center: CanvasPoint(x: outLeft + outWidth / 2, y: outTop + outHeight / 2),
    size: math.max(outWidth, outHeight).toDouble(),
    stamp: BrushStampImage(
      id: '${stamp.id}-t${DateTime.now().microsecondsSinceEpoch}',
      width: outWidth,
      height: outHeight,
      rgba: bytes,
    ),
  );
}

/// Solves the 3×3 homography H mapping each `from[i]` onto `to[i]`
/// (4 point pairs, row-major 9 elements, h22 fixed at 1), via the
/// standard 8-unknown linear system with partial-pivot Gaussian
/// elimination. Null for degenerate quads (collinear/self-crossing
/// input) — callers refuse the warp rather than produce garbage.
Float64List? solveHomography(List<CanvasPoint> from, List<CanvasPoint> to) {
  assert(from.length == 4 && to.length == 4);
  // Rows: [x y 1 0 0 0 -x*u -y*u | u] and [0 0 0 x y 1 -x*v -y*v | v].
  final a = List.generate(8, (_) => Float64List(9));
  for (var i = 0; i < 4; i += 1) {
    final x = from[i].x, y = from[i].y;
    final u = to[i].x, v = to[i].y;
    a[i * 2]
      ..[0] = x
      ..[1] = y
      ..[2] = 1
      ..[6] = -x * u
      ..[7] = -y * u
      ..[8] = u;
    a[i * 2 + 1]
      ..[3] = x
      ..[4] = y
      ..[5] = 1
      ..[6] = -x * v
      ..[7] = -y * v
      ..[8] = v;
  }
  for (var column = 0; column < 8; column += 1) {
    var pivotRow = column;
    for (var row = column + 1; row < 8; row += 1) {
      if (a[row][column].abs() > a[pivotRow][column].abs()) {
        pivotRow = row;
      }
    }
    if (a[pivotRow][column].abs() < 1e-9) {
      return null;
    }
    final tmp = a[column];
    a[column] = a[pivotRow];
    a[pivotRow] = tmp;
    final pivot = a[column][column];
    for (var row = column + 1; row < 8; row += 1) {
      final factor = a[row][column] / pivot;
      if (factor == 0) {
        continue;
      }
      for (var k = column; k < 9; k += 1) {
        a[row][k] -= factor * a[column][k];
      }
    }
  }
  final h = Float64List(9);
  h[8] = 1;
  for (var row = 7; row >= 0; row -= 1) {
    var sum = a[row][8];
    for (var k = row + 1; k < 8; k += 1) {
      sum -= a[row][k] * h[k];
    }
    h[row] = sum / a[row][row];
  }
  return h;
}

/// The lifted stamp through a free QUAD (R20-D2 perspective transform,
/// the PS Ctrl+corner mode): [corners] are the destination positions of
/// the stamp rect's TL/TR/BR/BL corners in canvas space. Resamples with
/// the same alpha-weighted Catmull-Rom kernel as the affine path,
/// through the inverse homography. Corners exactly at the source rect =
/// untouched; a degenerate quad refuses (returns the dab unchanged).
BrushDab transformStampDabQuad(BrushDab stampDab, List<CanvasPoint> corners) {
  final stamp = stampDab.stamp;
  if (stamp == null) {
    return stampDab;
  }
  assert(corners.length == 4);
  final srcLeft = stampDab.center.x - stamp.width / 2;
  final srcTop = stampDab.center.y - stamp.height / 2;
  final base = [
    CanvasPoint(x: srcLeft, y: srcTop),
    CanvasPoint(x: srcLeft + stamp.width, y: srcTop),
    CanvasPoint(x: srcLeft + stamp.width, y: srcTop + stamp.height),
    CanvasPoint(x: srcLeft, y: srcTop + stamp.height),
  ];
  var identity = true;
  for (var i = 0; i < 4; i += 1) {
    if (corners[i].x != base[i].x || corners[i].y != base[i].y) {
      identity = false;
      break;
    }
  }
  if (identity) {
    return stampDab;
  }
  // dst → src directly: no matrix inversion, one solve.
  final h = solveHomography(corners, base);
  if (h == null) {
    return stampDab;
  }

  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final corner in corners) {
    minX = math.min(minX, corner.x);
    maxX = math.max(maxX, corner.x);
    minY = math.min(minY, corner.y);
    maxY = math.max(maxY, corner.y);
  }
  final outLeft = minX.floor();
  final outTop = minY.floor();
  final outWidth = math.max(1, maxX.ceil() - outLeft);
  final outHeight = math.max(1, maxY.ceil() - outTop);

  final source = stamp.rgba;
  final bytes = Uint8List(outWidth * outHeight * 4);
  for (var oy = 0; oy < outHeight; oy += 1) {
    final qy = outTop + oy + 0.5;
    for (var ox = 0; ox < outWidth; ox += 1) {
      final qx = outLeft + ox + 0.5;
      final w = h[6] * qx + h[7] * qy + h[8];
      if (w.abs() < 1e-12) {
        continue;
      }
      final px = (h[0] * qx + h[1] * qy + h[2]) / w;
      final py = (h[3] * qx + h[4] * qy + h[5]) / w;
      final sampleX = px - srcLeft - 0.5;
      final sampleY = py - srcTop - 0.5;
      final x0 = sampleX.floor();
      final y0 = sampleY.floor();
      _catmullRomWeights(sampleX - x0, _cubicWeightsX);
      _catmullRomWeights(sampleY - y0, _cubicWeightsY);

      var alphaAcc = 0.0;
      var redAcc = 0.0, greenAcc = 0.0, blueAcc = 0.0;
      for (var tapJ = 0; tapJ < 4; tapJ += 1) {
        final tapY = y0 - 1 + tapJ;
        if (tapY < 0 || tapY >= stamp.height) {
          continue;
        }
        final weightY = _cubicWeightsY[tapJ];
        if (weightY == 0) {
          continue;
        }
        final rowOffset = tapY * stamp.width;
        for (var tapI = 0; tapI < 4; tapI += 1) {
          final tapX = x0 - 1 + tapI;
          if (tapX < 0 || tapX >= stamp.width) {
            continue;
          }
          final weight = _cubicWeightsX[tapI] * weightY;
          if (weight == 0) {
            continue;
          }
          final offset = (rowOffset + tapX) * 4;
          final alpha = source[offset + 3];
          if (alpha == 0) {
            continue;
          }
          final weightedAlpha = weight * alpha;
          alphaAcc += weightedAlpha;
          redAcc += weightedAlpha * source[offset];
          greenAcc += weightedAlpha * source[offset + 1];
          blueAcc += weightedAlpha * source[offset + 2];
        }
      }
      if (alphaAcc <= 0) {
        continue;
      }
      final offset = (oy * outWidth + ox) * 4;
      bytes[offset] = (redAcc / alphaAcc).round().clamp(0, 255);
      bytes[offset + 1] = (greenAcc / alphaAcc).round().clamp(0, 255);
      bytes[offset + 2] = (blueAcc / alphaAcc).round().clamp(0, 255);
      bytes[offset + 3] = alphaAcc.round().clamp(0, 255);
    }
  }

  return stampDab.copyWith(
    center: CanvasPoint(x: outLeft + outWidth / 2, y: outTop + outHeight / 2),
    size: math.max(outWidth, outHeight).toDouble(),
    stamp: BrushStampImage(
      id: '${stamp.id}-q${DateTime.now().microsecondsSinceEpoch}',
      width: outWidth,
      height: outHeight,
      rgba: bytes,
    ),
  );
}

/// The lifted stamp through a MESH warp (R20-D3): an n×m control grid
/// over the stamp rect, each cell split into two triangles with a fixed
/// diagonal; destination triangles inverse-map affinely (barycentric)
/// onto the source and sample with the same alpha-weighted Catmull-Rom
/// kernel. The preview renders the SAME triangulation, so what warps on
/// screen is what commits. [points] holds `(columns+1)*(rows+1)`
/// destination grid positions, row-major; the base grid is the stamp
/// rect subdivided uniformly. All points at base = untouched. Fold-overs
/// resolve by triangle order (first hit wins — deterministic).
BrushDab transformStampDabMesh(
  BrushDab stampDab, {
  required int columns,
  required int rows,
  required List<CanvasPoint> points,
}) {
  final stamp = stampDab.stamp;
  if (stamp == null || columns < 1 || rows < 1) {
    return stampDab;
  }
  assert(points.length == (columns + 1) * (rows + 1));
  final srcLeft = stampDab.center.x - stamp.width / 2;
  final srcTop = stampDab.center.y - stamp.height / 2;
  final cellWidth = stamp.width / columns;
  final cellHeight = stamp.height / rows;
  CanvasPoint baseAt(int column, int row) => CanvasPoint(
    x: srcLeft + column * cellWidth,
    y: srcTop + row * cellHeight,
  );

  var identity = true;
  for (var row = 0; row <= rows && identity; row += 1) {
    for (var column = 0; column <= columns; column += 1) {
      final base = baseAt(column, row);
      final point = points[row * (columns + 1) + column];
      if (point.x != base.x || point.y != base.y) {
        identity = false;
        break;
      }
    }
  }
  if (identity) {
    return stampDab;
  }

  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final point in points) {
    minX = math.min(minX, point.x);
    maxX = math.max(maxX, point.x);
    minY = math.min(minY, point.y);
    maxY = math.max(maxY, point.y);
  }
  final outLeft = minX.floor();
  final outTop = minY.floor();
  final outWidth = math.max(1, maxX.ceil() - outLeft);
  final outHeight = math.max(1, maxY.ceil() - outTop);
  final source = stamp.rgba;
  final bytes = Uint8List(outWidth * outHeight * 4);
  final covered = Uint8List(outWidth * outHeight);

  void rasterizeTriangle(
    CanvasPoint d0,
    CanvasPoint d1,
    CanvasPoint d2,
    CanvasPoint s0,
    CanvasPoint s1,
    CanvasPoint s2,
  ) {
    final denominator =
        (d1.x - d0.x) * (d2.y - d0.y) - (d2.x - d0.x) * (d1.y - d0.y);
    if (denominator.abs() < 1e-12) {
      return; // Degenerate destination triangle.
    }
    final left = math.max(
      outLeft,
      math.min(d0.x, math.min(d1.x, d2.x)).floor(),
    );
    final top = math.max(outTop, math.min(d0.y, math.min(d1.y, d2.y)).floor());
    final right = math.min(
      outLeft + outWidth,
      math.max(d0.x, math.max(d1.x, d2.x)).ceil(),
    );
    final bottom = math.min(
      outTop + outHeight,
      math.max(d0.y, math.max(d1.y, d2.y)).ceil(),
    );
    for (var y = top; y < bottom; y += 1) {
      final qy = y + 0.5;
      for (var x = left; x < right; x += 1) {
        final index = (y - outTop) * outWidth + (x - outLeft);
        if (covered[index] != 0) {
          continue;
        }
        final qx = x + 0.5;
        // Barycentric coordinates in the destination triangle.
        final w1 =
            ((qx - d0.x) * (d2.y - d0.y) - (d2.x - d0.x) * (qy - d0.y)) /
            denominator;
        final w2 =
            ((d1.x - d0.x) * (qy - d0.y) - (qx - d0.x) * (d1.y - d0.y)) /
            denominator;
        final w0 = 1.0 - w1 - w2;
        const slack = -1e-9;
        if (w0 < slack || w1 < slack || w2 < slack) {
          continue;
        }
        final px = s0.x * w0 + s1.x * w1 + s2.x * w2;
        final py = s0.y * w0 + s1.y * w1 + s2.y * w2;
        final sampleX = px - srcLeft - 0.5;
        final sampleY = py - srcTop - 0.5;
        final x0 = sampleX.floor();
        final y0 = sampleY.floor();
        _catmullRomWeights(sampleX - x0, _cubicWeightsX);
        _catmullRomWeights(sampleY - y0, _cubicWeightsY);
        var alphaAcc = 0.0;
        var redAcc = 0.0, greenAcc = 0.0, blueAcc = 0.0;
        for (var tapJ = 0; tapJ < 4; tapJ += 1) {
          final tapY = y0 - 1 + tapJ;
          if (tapY < 0 || tapY >= stamp.height) {
            continue;
          }
          final weightY = _cubicWeightsY[tapJ];
          if (weightY == 0) {
            continue;
          }
          final rowOffset = tapY * stamp.width;
          for (var tapI = 0; tapI < 4; tapI += 1) {
            final tapX = x0 - 1 + tapI;
            if (tapX < 0 || tapX >= stamp.width) {
              continue;
            }
            final weight = _cubicWeightsX[tapI] * weightY;
            if (weight == 0) {
              continue;
            }
            final offset = (rowOffset + tapX) * 4;
            final alpha = source[offset + 3];
            if (alpha == 0) {
              continue;
            }
            final weightedAlpha = weight * alpha;
            alphaAcc += weightedAlpha;
            redAcc += weightedAlpha * source[offset];
            greenAcc += weightedAlpha * source[offset + 1];
            blueAcc += weightedAlpha * source[offset + 2];
          }
        }
        covered[index] = 1;
        if (alphaAcc <= 0) {
          continue;
        }
        final offset = index * 4;
        bytes[offset] = (redAcc / alphaAcc).round().clamp(0, 255);
        bytes[offset + 1] = (greenAcc / alphaAcc).round().clamp(0, 255);
        bytes[offset + 2] = (blueAcc / alphaAcc).round().clamp(0, 255);
        bytes[offset + 3] = alphaAcc.round().clamp(0, 255);
      }
    }
  }

  CanvasPoint destAt(int column, int row) =>
      points[row * (columns + 1) + column];
  for (var row = 0; row < rows; row += 1) {
    for (var column = 0; column < columns; column += 1) {
      // Fixed diagonal TL–BR mirror of the preview triangulation:
      // (TL, TR, BL) and (TR, BR, BL).
      rasterizeTriangle(
        destAt(column, row),
        destAt(column + 1, row),
        destAt(column, row + 1),
        baseAt(column, row),
        baseAt(column + 1, row),
        baseAt(column, row + 1),
      );
      rasterizeTriangle(
        destAt(column + 1, row),
        destAt(column + 1, row + 1),
        destAt(column, row + 1),
        baseAt(column + 1, row),
        baseAt(column + 1, row + 1),
        baseAt(column, row + 1),
      );
    }
  }

  return stampDab.copyWith(
    center: CanvasPoint(x: outLeft + outWidth / 2, y: outTop + outHeight / 2),
    size: math.max(outWidth, outHeight).toDouble(),
    stamp: BrushStampImage(
      id: '${stamp.id}-m${DateTime.now().microsecondsSinceEpoch}',
      width: outWidth,
      height: outHeight,
      rgba: bytes,
    ),
  );
}

/// Catmull-Rom weights for taps at offsets {-1, 0, +1, +2} around the
/// floor sample, written into [out] (reused scratch — the resample loop
/// is per-pixel hot). Interpolating: f == 0 → (0, 1, 0, 0).
void _catmullRomWeights(double f, Float64List out) {
  final f2 = f * f;
  final f3 = f2 * f;
  out[0] = 0.5 * (-f3 + 2.0 * f2 - f);
  out[1] = 0.5 * (3.0 * f3 - 5.0 * f2 + 2.0);
  out[2] = 0.5 * (-3.0 * f3 + 4.0 * f2 + f);
  out[3] = 0.5 * (f3 - f2);
}

final Float64List _cubicWeightsX = Float64List(4);
final Float64List _cubicWeightsY = Float64List(4);

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
      final sourceOffset = ((y % tileSize) * tileSize + (x % tileSize)) * 4;
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
