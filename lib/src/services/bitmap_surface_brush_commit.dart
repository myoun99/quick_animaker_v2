import 'dart:math' as math;
import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/brush_dab_sequence.dart';
import '../models/brush_tip_shape.dart';
import '../models/dirty_region.dart';
import '../models/dirty_tile_set.dart';
import '../models/tile_coord.dart';
import 'brush_dab_dirty_region.dart';

class BrushSurfaceMaterialization {
  const BrushSurfaceMaterialization({
    required this.surface,
    required this.dirtyTiles,
  });

  final BitmapSurface surface;
  final DirtyTileSet dirtyTiles;

  bool get hasChanges => dirtyTiles.isNotEmpty;
}

/// Rasterizes [sequence] onto [surface] and returns the updated surface plus
/// the tiles it changed.
///
/// This is the stroke-commit hot path. It blends dabs directly into per-tile
/// scratch byte buffers: each touched tile's pixels are copied at most once,
/// and no per-pixel objects are allocated. The blend math is kept identical to
/// the reference pixel pipeline (`brushPixelBlendOperationsForDabSequence` +
/// `applyBrushPixelBlendOperationsToBitmapTile`), which remains as the slow
/// per-pixel-operation oracle used by the parity test.
BrushSurfaceMaterialization materializeBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
}) {
  final canvasWidth = surface.canvasSize.width;
  final canvasHeight = surface.canvasSize.height;
  final tileSize = surface.tileSize;

  // Mutable scratch pixels per touched tile. `BitmapTile.pixels` already
  // returns a defensive copy, so it can be mutated freely; blank tiles start
  // as zeroed buffers without allocating a BitmapTile.
  final scratchBuffers = <TileCoord, Uint8List>{};
  final changedCoords = <TileCoord>{};

  Uint8List scratchBufferFor(TileCoord coord) {
    return scratchBuffers.putIfAbsent(coord, () {
      final tile = surface.tileAt(coord);
      if (tile == null) {
        return Uint8List(tileSize * tileSize * BitmapTile.bytesPerPixel);
      }
      return tile.pixels;
    });
  }

  for (final dab in sequence.dabs) {
    final region = dirtyRegionForBrushDab(dab);
    if (region == null) {
      continue;
    }

    final sourceArgb = dab.color;
    final sourceA = (sourceArgb >> 24) & 0xFF;
    if (sourceA == 0 || dab.opacity == 0.0 || dab.flow == 0.0) {
      continue;
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
    // byte-identical. Must match BrushLiveStrokeRasterizer exactly.
    final isEllipse = isRound && dab.roundness < 1.0;
    final isRotatedRect =
        !isRound && (dab.roundness < 1.0 || dab.angleDegrees != 0.0);
    var tipCos = 1.0;
    var tipSin = 0.0;
    var inverseRoundness = 1.0;
    if (isEllipse || isRotatedRect) {
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

    final top = region.top;
    final bottomExclusive = math.min(region.bottomExclusive, canvasHeight);
    final left = region.left;
    final rightExclusive = math.min(region.rightExclusive, canvasWidth);
    if (rightExclusive <= left || bottomExclusive <= top) {
      continue;
    }

    final tileXStart = left ~/ tileSize;
    final tileXEnd = (rightExclusive - 1) ~/ tileSize;

    for (var y = top; y < bottomExclusive; y += 1) {
      final tileY = y ~/ tileSize;
      final localRowOffset = (y - tileY * tileSize) * tileSize;
      final dy = y + 0.5 - centerY;
      final dySquared = dy * dy;

      for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
        final coord = TileCoord(x: tileX, y: tileY);
        final buffer = scratchBufferFor(coord);
        final tileLeft = tileX * tileSize;
        final spanLeft = math.max(left, tileLeft);
        final spanRightExclusive = math.min(
          rightExclusive,
          tileLeft + tileSize,
        );

        for (var x = spanLeft; x < spanRightExclusive; x += 1) {
          double coverage;
          if (isRound) {
            final dx = x + 0.5 - centerX;
            double distance;
            if (isEllipse) {
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              distance = math.sqrt(tipU * tipU + tipV * tipV);
            } else {
              distance = math.sqrt(dx * dx + dySquared);
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

          // Same grouping as the reference path:
          // effectiveOpacity = dab.opacity * coverage,
          // sourceAlpha = ((a/255) * effectiveOpacity) * flow.
          final effectiveOpacity = dabOpacity * coverage;
          if (effectiveOpacity == 0.0) {
            continue;
          }
          final sourceAlpha = sourceAlphaNorm * effectiveOpacity * dabFlow;

          final offset =
              (localRowOffset + (x - tileLeft)) * BitmapTile.bytesPerPixel;
          final destR = buffer[offset];
          final destG = buffer[offset + 1];
          final destB = buffer[offset + 2];
          final destA = buffer[offset + 3];

          final destinationAlpha = destA / 255.0;
          final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);

          int outRByte;
          int outGByte;
          int outBByte;
          int outAByte;
          if (outAlpha == 0.0) {
            outRByte = 0;
            outGByte = 0;
            outBByte = 0;
            outAByte = 0;
          } else {
            // Keep the exact floating-point grouping of the reference
            // rgbaSourceOver: (dest * destinationAlpha) * inverseSourceAlpha.
            final inverseSourceAlpha = 1.0 - sourceAlpha;
            outRByte =
                ((sourceR * sourceAlpha +
                            destR * destinationAlpha * inverseSourceAlpha) /
                        outAlpha)
                    .round()
                    .clamp(0, 255);
            outGByte =
                ((sourceG * sourceAlpha +
                            destG * destinationAlpha * inverseSourceAlpha) /
                        outAlpha)
                    .round()
                    .clamp(0, 255);
            outBByte =
                ((sourceB * sourceAlpha +
                            destB * destinationAlpha * inverseSourceAlpha) /
                        outAlpha)
                    .round()
                    .clamp(0, 255);
            outAByte = (outAlpha * 255.0).round().clamp(0, 255);
          }

          if (outRByte != destR ||
              outGByte != destG ||
              outBByte != destB ||
              outAByte != destA) {
            buffer[offset] = outRByte;
            buffer[offset + 1] = outGByte;
            buffer[offset + 2] = outBByte;
            buffer[offset + 3] = outAByte;
            changedCoords.add(coord);
          }
        }
      }
    }
  }

  if (changedCoords.isEmpty) {
    return BrushSurfaceMaterialization(
      surface: surface,
      dirtyTiles: DirtyTileSet.empty(),
    );
  }

  final sortedCoords = changedCoords.toList()
    ..sort((a, b) {
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) return yComparison;
      return a.x.compareTo(b.x);
    });

  var updatedSurface = surface;
  var dirtyTiles = DirtyTileSet.empty();
  for (final coord in sortedCoords) {
    updatedSurface = updatedSurface.putTile(
      BitmapTile(coord: coord, size: tileSize, pixels: scratchBuffers[coord]!),
    );
    dirtyTiles = dirtyTiles.add(coord);
  }

  return BrushSurfaceMaterialization(
    surface: updatedSurface,
    dirtyTiles: dirtyTiles,
  );
}

/// Composites a pre-rasterized straight-alpha stroke buffer onto [surface]
/// within [bounds].
///
/// This is the pen-up fast path: the interactive view rasterizes the stroke
/// incrementally while the pointer moves (`BrushLiveStrokeRasterizer`, same
/// per-dab math as [materializeBrushDabSequenceOnBitmapSurface]), so commit
/// only needs one source-over pass of the finished stroke over the existing
/// artwork instead of re-running the whole dab loop — removing the commit
/// hiccup for long dense strokes. The composited pixels are exactly the
/// stroke the user watched being drawn.
BrushSurfaceMaterialization compositeStrokePixelsOntoBitmapSurface({
  required BitmapSurface surface,
  required Uint8List strokePixels,
  required DirtyRegion bounds,
}) {
  final canvasWidth = surface.canvasSize.width;
  final canvasHeight = surface.canvasSize.height;
  final tileSize = surface.tileSize;

  final top = math.max(0, bounds.top);
  final bottomExclusive = math.min(bounds.bottomExclusive, canvasHeight);
  final left = math.max(0, bounds.left);
  final rightExclusive = math.min(bounds.rightExclusive, canvasWidth);
  if (rightExclusive <= left || bottomExclusive <= top) {
    return BrushSurfaceMaterialization(
      surface: surface,
      dirtyTiles: DirtyTileSet.empty(),
    );
  }

  final scratchBuffers = <TileCoord, Uint8List>{};
  final changedCoords = <TileCoord>{};

  Uint8List scratchBufferFor(TileCoord coord) {
    return scratchBuffers.putIfAbsent(coord, () {
      final tile = surface.tileAt(coord);
      if (tile == null) {
        return Uint8List(tileSize * tileSize * BitmapTile.bytesPerPixel);
      }
      return tile.pixels;
    });
  }

  final tileXStart = left ~/ tileSize;
  final tileXEnd = (rightExclusive - 1) ~/ tileSize;

  for (var y = top; y < bottomExclusive; y += 1) {
    final tileY = y ~/ tileSize;
    final localRowOffset = (y - tileY * tileSize) * tileSize;
    final strokeRowOffset = y * canvasWidth;

    for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
      final coord = TileCoord(x: tileX, y: tileY);
      final buffer = scratchBufferFor(coord);
      final tileLeft = tileX * tileSize;
      final spanLeft = math.max(left, tileLeft);
      final spanRightExclusive = math.min(rightExclusive, tileLeft + tileSize);

      for (var x = spanLeft; x < spanRightExclusive; x += 1) {
        final strokeOffset = (strokeRowOffset + x) * 4;
        final strokeA = strokePixels[strokeOffset + 3];
        if (strokeA == 0) {
          continue;
        }

        final offset =
            (localRowOffset + (x - tileLeft)) * BitmapTile.bytesPerPixel;
        final destR = buffer[offset];
        final destG = buffer[offset + 1];
        final destB = buffer[offset + 2];
        final destA = buffer[offset + 3];

        // Same source-over math and rounding as the per-dab rasterizer, with
        // the stroke pixel acting as the source.
        final sourceAlpha = strokeA / 255.0;
        final destinationAlpha = destA / 255.0;
        final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);

        int outRByte;
        int outGByte;
        int outBByte;
        int outAByte;
        if (outAlpha == 0.0) {
          outRByte = 0;
          outGByte = 0;
          outBByte = 0;
          outAByte = 0;
        } else {
          final inverseSourceAlpha = 1.0 - sourceAlpha;
          outRByte =
              ((strokePixels[strokeOffset] * sourceAlpha +
                          destR * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          outGByte =
              ((strokePixels[strokeOffset + 1] * sourceAlpha +
                          destG * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          outBByte =
              ((strokePixels[strokeOffset + 2] * sourceAlpha +
                          destB * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          outAByte = (outAlpha * 255.0).round().clamp(0, 255);
        }

        if (outRByte != destR ||
            outGByte != destG ||
            outBByte != destB ||
            outAByte != destA) {
          buffer[offset] = outRByte;
          buffer[offset + 1] = outGByte;
          buffer[offset + 2] = outBByte;
          buffer[offset + 3] = outAByte;
          changedCoords.add(coord);
        }
      }
    }
  }

  if (changedCoords.isEmpty) {
    return BrushSurfaceMaterialization(
      surface: surface,
      dirtyTiles: DirtyTileSet.empty(),
    );
  }

  final sortedCoords = changedCoords.toList()
    ..sort((a, b) {
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) return yComparison;
      return a.x.compareTo(b.x);
    });

  var updatedSurface = surface;
  var dirtyTiles = DirtyTileSet.empty();
  for (final coord in sortedCoords) {
    updatedSurface = updatedSurface.putTile(
      BitmapTile(coord: coord, size: tileSize, pixels: scratchBuffers[coord]!),
    );
    dirtyTiles = dirtyTiles.add(coord);
  }

  return BrushSurfaceMaterialization(
    surface: updatedSurface,
    dirtyTiles: dirtyTiles,
  );
}
