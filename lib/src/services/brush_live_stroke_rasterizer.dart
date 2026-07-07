import 'dart:math' as math;
import 'dart:typed_data';

import '../models/brush_dab.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_size.dart';
import '../models/dirty_region.dart';
import 'brush_dab_dirty_region.dart';
import 'brush_tip_mask_sampling.dart';

/// Read access to the in-progress stroke's straight-alpha pixels — what
/// the live overlay snapshots its tile images from.
abstract interface class ActiveStrokePixelSource {
  int get canvasWidth;
  int get canvasHeight;

  /// Copies [count] straight-alpha RGBA pixels starting at canvas (x, y)
  /// into [target] at [targetOffset]. Unpainted pixels read as transparent
  /// zeros.
  void copyRow(int x, int y, int count, Uint8List target, int targetOffset);
}

/// Rasterizes the in-progress stroke incrementally into SPARSE
/// straight-alpha RGBA tiles allocated on demand.
///
/// Storage is tile-sparse so the cost of a stroke scales with the region
/// it actually paints, never with the canvas: the old canvas-sized buffer
/// made big logical surfaces (the timesheet ink planes at high resolution)
/// pay tens/hundreds of MB per stroke.
///
/// This runs the exact blend math of the commit rasterizer
/// (`materializeBrushDabSequenceOnBitmapSurface`) — same coverage sampling of
/// pixel centers against the true fractional dab center, same floating-point
/// grouping, same rounding — so the pixels painted while drawing are
/// byte-identical to the committed result. The live display and the commit
/// fast-path both consume these pixels, which is what unifies the on-screen
/// stroke with the committed artwork. Equivalence with the commit rasterizer
/// is locked by `active_stroke_overlay_parity_test.dart` (byte-exact).
class BrushLiveStrokeRasterizer implements ActiveStrokePixelSource {
  BrushLiveStrokeRasterizer({required this.canvasSize});

  /// Edge length of a sparse stroke tile in canvas pixels.
  static const int tileSize = 128;

  final CanvasSize canvasSize;

  @override
  int get canvasWidth => canvasSize.width;

  @override
  int get canvasHeight => canvasSize.height;

  /// Straight-alpha RGBA tile buffers keyed by `tileY * tilesPerRow +
  /// tileX`, allocated (zeroed) the first time a dab touches the tile.
  final Map<int, Uint8List> _tiles = <int, Uint8List>{};

  late final int _tilesPerRow = (canvasSize.width + tileSize - 1) ~/ tileSize;

  DirtyRegion? _strokeBounds;
  int _blendedDabCount = 0;

  /// Union of every blended dab's dirty region, or `null` when nothing has
  /// been painted yet.
  DirtyRegion? get strokeBounds => _strokeBounds;

  /// Number of dabs blended so far.
  int get blendedDabCount => _blendedDabCount;

  /// Number of allocated stroke tiles (test/debug oracle for sparseness).
  int get allocatedTileCount => _tiles.length;

  /// Drops the stroke's tiles so the rasterizer can host the next stroke.
  void clear() {
    _tiles.clear();
    _strokeBounds = null;
    _blendedDabCount = 0;
  }

  Uint8List _tileBuffer(int tileX, int tileY) {
    return _tiles.putIfAbsent(
      tileY * _tilesPerRow + tileX,
      () => Uint8List(tileSize * tileSize * 4),
    );
  }

  @override
  void copyRow(int x, int y, int count, Uint8List target, int targetOffset) {
    var remaining = count;
    var sourceX = x;
    var writeOffset = targetOffset;
    final tileY = y ~/ tileSize;
    final localRowOffset = (y - tileY * tileSize) * tileSize;
    while (remaining > 0) {
      final tileX = sourceX ~/ tileSize;
      final tileLeft = tileX * tileSize;
      final spanCount = math.min(remaining, tileLeft + tileSize - sourceX);
      final buffer = _tiles[tileY * _tilesPerRow + tileX];
      if (buffer == null) {
        target.fillRange(writeOffset, writeOffset + spanCount * 4, 0);
      } else {
        final sourceOffset = (localRowOffset + (sourceX - tileLeft)) * 4;
        target.setRange(
          writeOffset,
          writeOffset + spanCount * 4,
          buffer,
          sourceOffset,
        );
      }
      remaining -= spanCount;
      sourceX += spanCount;
      writeOffset += spanCount * 4;
    }
  }

  /// Materializes the stroke's pixels within [strokeBounds] as one
  /// row-major straight-alpha buffer (stride = bounds width) — the pen-up
  /// commit fast path's input. Allocation scales with the STROKE, not the
  /// canvas.
  Uint8List? strokePixelsWithinBounds() {
    final bounds = _strokeBounds;
    if (bounds == null) {
      return null;
    }
    final boundsWidth = bounds.rightExclusive - bounds.left;
    final boundsHeight = bounds.bottomExclusive - bounds.top;
    final buffer = Uint8List(boundsWidth * boundsHeight * 4);
    for (var row = 0; row < boundsHeight; row += 1) {
      copyRow(
        bounds.left,
        bounds.top + row,
        boundsWidth,
        buffer,
        row * boundsWidth * 4,
      );
    }
    return buffer;
  }

  /// Blends `dabs[from..]` into the stroke tiles and returns the union of
  /// the newly touched region (clamped to the canvas), or `null` if nothing
  /// changed.
  DirtyRegion? blendFrom(List<BrushDab> dabs, {int? from}) {
    final start = from ?? _blendedDabCount;
    DirtyRegion? touched;

    for (var index = start; index < dabs.length; index += 1) {
      final region = _blendDab(dabs[index]);
      if (region != null) {
        touched = touched == null ? region : touched.union(region);
      }
    }
    _blendedDabCount = math.max(_blendedDabCount, dabs.length);
    if (touched != null) {
      _strokeBounds = _strokeBounds == null
          ? touched
          : _strokeBounds!.union(touched);
    }
    return touched;
  }

  DirtyRegion? _blendDab(BrushDab dab) {
    final region = dirtyRegionForBrushDab(dab);
    if (region == null) {
      return null;
    }

    final sourceArgb = dab.color;
    final sourceA = (sourceArgb >> 24) & 0xFF;
    if (sourceA == 0 || dab.opacity == 0.0 || dab.flow == 0.0) {
      return null;
    }
    final sourceR = (sourceArgb >> 16) & 0xFF;
    final sourceG = (sourceArgb >> 8) & 0xFF;
    final sourceB = sourceArgb & 0xFF;
    final sourceAlphaNorm = sourceA / 255.0;

    final radius = dab.size / 2.0;
    final hardRadius = radius * dab.hardness;
    final edgeSpan = radius - hardRadius;
    final isRound = dab.tipShape == BrushTipShape.round;
    // Elliptical / rotated tips evaluate coverage in tip space: rotate the
    // pixel offset onto the tip axes and stretch the minor axis by
    // 1/roundness, turning the ellipse test back into the circle test. The
    // classic circle (roundness == 1, rotation-invariant) and axis-aligned
    // square keep their original code path so existing strokes stay
    // byte-identical.
    final tipMask = dab.tipMask;
    final isEllipse = tipMask == null && isRound && dab.roundness < 1.0;
    final isRotatedRect =
        tipMask == null &&
        !isRound &&
        (dab.roundness < 1.0 || dab.angleDegrees != 0.0);
    var tipCos = 1.0;
    var tipSin = 0.0;
    var inverseRoundness = 1.0;
    if (isEllipse || isRotatedRect || tipMask != null) {
      final angleRadians = dab.angleDegrees * (math.pi / 180.0);
      tipCos = math.cos(angleRadians);
      tipSin = math.sin(angleRadians);
      inverseRoundness = 1.0 / dab.roundness;
    }
    final minorRadius = radius * dab.roundness;
    final centerX = dab.center.x;
    final centerY = dab.center.y;
    final dabOpacity = dab.opacity;
    final dabFlow = dab.flow;
    final width = canvasSize.width;

    final top = region.top;
    final bottomExclusive = math.min(region.bottomExclusive, canvasSize.height);
    final left = region.left;
    final rightExclusive = math.min(region.rightExclusive, width);
    if (rightExclusive <= left || bottomExclusive <= top) {
      return null;
    }
    final columnCount = rightExclusive - left;
    final rowCount = bottomExclusive - top;

    // Per-dab hoists and axis lattices (see brush_tip_mask_sampling.dart):
    // unrotated tips and the never-rotating tiled masks sample through
    // per-axis precomputes with the scalar samplers' exact arithmetic, so
    // the resulting bytes are unchanged — the parity suites pin this.
    final dualMask = dab.dualMask;
    final textureMask = dab.textureMask;
    final textureDensity = dab.textureDensity;
    final textureOneMinusDensity = 1.0 - textureDensity;
    final unrotatedTip = tipMask != null && dab.angleDegrees == 0.0;
    // Conservative squared-distance cull for plain round tips: only pixels
    // PROVABLY outside the radius skip the sqrt; anything within the float
    // margin still runs the exact scalar test.
    final radiusSqSkip = radius * radius * (1.0 + 1e-12);

    final tipULattice = unrotatedTip
        ? BrushTipMaskAxisLattice.compute(
            mask: tipMask,
            radius: radius,
            start: left,
            count: columnCount,
            center: centerX,
          )
        : null;
    final tipVLattice = unrotatedTip
        ? BrushTipMaskAxisLattice.compute(
            mask: tipMask,
            radius: radius,
            start: top,
            count: rowCount,
            center: centerY,
            inverseRoundness: inverseRoundness,
          )
        : null;
    final dualULattice = dualMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: dualMask,
            start: left,
            count: columnCount,
            originOffset: -centerX,
            period: dab.size * dab.dualMaskScale,
            offset: dab.dualOffsetU,
          );
    final dualVLattice = dualMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: dualMask,
            start: top,
            count: rowCount,
            originOffset: -centerY,
            period: dab.size * dab.dualMaskScale,
            offset: dab.dualOffsetV,
          );
    final textureULattice = textureMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: textureMask,
            start: left,
            count: columnCount,
            originOffset: 0.0,
            period: textureMask.size * dab.textureScale,
            offset: 0.0,
          );
    final textureVLattice = textureMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: textureMask,
            start: top,
            count: rowCount,
            originOffset: 0.0,
            period: textureMask.size * dab.textureScale,
            offset: 0.0,
          );

    final tileXStart = left ~/ tileSize;
    final tileXEnd = (rightExclusive - 1) ~/ tileSize;

    for (var y = top; y < bottomExclusive; y += 1) {
      final dy = y + 0.5 - centerY;
      final dySquared = dy * dy;
      final vIndex = y - top;
      if (tipVLattice != null && tipVLattice.inRange[vIndex] == 0) {
        // Same effect as the scalar |tipV| > radius per-pixel cull.
        continue;
      }
      final tileY = y ~/ tileSize;
      final localRowOffset = (y - tileY * tileSize) * tileSize;

      for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
        final buffer = _tileBuffer(tileX, tileY);
        final tileLeft = tileX * tileSize;
        final spanLeft = math.max(left, tileLeft);
        final spanRightExclusive = math.min(
          rightExclusive,
          tileLeft + tileSize,
        );

        for (var x = spanLeft; x < spanRightExclusive; x += 1) {
          double coverage;
          if (tipMask != null) {
            if (unrotatedTip) {
              final uIndex = x - left;
              if (tipULattice!.inRange[uIndex] == 0) {
                continue;
              }
              coverage = sampleBrushTipMaskCoverageLattice(
                mask: tipMask,
                uAxis: tipULattice,
                uIndex: uIndex,
                vAxis: tipVLattice!,
                vIndex: vIndex,
              );
            } else {
              final dx = x + 0.5 - centerX;
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              if (tipU.abs() > radius || tipV.abs() > radius) {
                continue;
              }
              coverage = sampleBrushTipMaskCoverage(
                mask: tipMask,
                tipU: tipU,
                tipV: tipV,
                radius: radius,
              );
            }
            if (coverage <= 0.0) {
              continue;
            }
          } else if (isRound) {
            final dx = x + 0.5 - centerX;
            double distance;
            if (isEllipse) {
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              distance = math.sqrt(tipU * tipU + tipV * tipV);
            } else {
              final dxSquared = dx * dx;
              if (dxSquared + dySquared > radiusSqSkip) {
                continue;
              }
              distance = math.sqrt(dxSquared + dySquared);
            }
            if (distance > radius) {
              continue;
            }
            if (distance <= hardRadius || edgeSpan <= 0.0) {
              coverage = 1.0;
            } else {
              coverage = (1.0 - ((distance - hardRadius) / edgeSpan)).clamp(
                0.0,
                1.0,
              );
            }
            if (coverage <= 0.0) {
              continue;
            }
          } else {
            if (isRotatedRect) {
              final dx = x + 0.5 - centerX;
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = dx * tipSin + dy * tipCos;
              if (tipU.abs() > radius || tipV.abs() > minorRadius) {
                continue;
              }
            }
            coverage = 1.0;
          }

          // Dual-brush texture: a second tiled mask multiplies the coverage
          // (must match the commit rasterizer and oracle exactly).
          if (dualMask != null) {
            coverage *= sampleBrushTipMaskTiledCoverageLattice(
              mask: dualMask,
              uAxis: dualULattice!,
              uIndex: x - left,
              vAxis: dualVLattice!,
              vIndex: vIndex,
            );
            if (coverage <= 0.0) {
              continue;
            }
          }

          // Paper texture: canvas-anchored tiled mask, blended in by density
          // (must match the commit rasterizer and oracle exactly).
          if (textureMask != null) {
            final textureSample = sampleBrushTipMaskTiledCoverageLattice(
              mask: textureMask,
              uAxis: textureULattice!,
              uIndex: x - left,
              vAxis: textureVLattice!,
              vIndex: vIndex,
            );
            coverage *= textureOneMinusDensity + textureDensity * textureSample;
            if (coverage <= 0.0) {
              continue;
            }
          }

          // Same grouping as the commit rasterizer:
          // effectiveOpacity = dab.opacity * coverage,
          // sourceAlpha = ((a/255) * effectiveOpacity) * flow.
          final effectiveOpacity = dabOpacity * coverage;
          if (effectiveOpacity == 0.0) {
            continue;
          }
          final sourceAlpha = sourceAlphaNorm * effectiveOpacity * dabFlow;

          final offset = (localRowOffset + (x - tileLeft)) * 4;
          final destR = buffer[offset];
          final destG = buffer[offset + 1];
          final destB = buffer[offset + 2];
          final destA = buffer[offset + 3];

          final destinationAlpha = destA / 255.0;
          final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);
          if (outAlpha == 0.0) {
            buffer[offset] = 0;
            buffer[offset + 1] = 0;
            buffer[offset + 2] = 0;
            buffer[offset + 3] = 0;
            continue;
          }

          final inverseSourceAlpha = 1.0 - sourceAlpha;
          buffer[offset] =
              ((sourceR * sourceAlpha +
                          destR * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          buffer[offset + 1] =
              ((sourceG * sourceAlpha +
                          destG * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          buffer[offset + 2] =
              ((sourceB * sourceAlpha +
                          destB * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          buffer[offset + 3] = (outAlpha * 255.0).round().clamp(0, 255);
        }
      }
    }

    return DirtyRegion(
      left: left,
      top: top,
      rightExclusive: rightExclusive,
      bottomExclusive: bottomExclusive,
    );
  }
}
