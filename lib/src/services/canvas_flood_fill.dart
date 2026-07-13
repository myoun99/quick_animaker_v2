import 'dart:math' as math;
import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
import '../models/brush_stamp_image.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/layer_id.dart';
import '../models/tile_coord.dart';
import '../ui/dev_profile.dart';
import 'canvas_color_sampler.dart';
import 'cut_frame_composite_plan.dart';

/// P6 fill options — the Tool Settings panel's knobs (R11-④).
class FloodFillOptions {
  const FloodFillOptions({
    this.tolerance = 32,
    this.expandPx = 1,
    this.antiAlias = true,
  });

  /// Max per-channel distance from the seed color that still fills.
  final int tolerance;

  /// Region growth in pixels AFTER the fill — closes the classic hairline
  /// gap between the fill and anti-aliased ink edges.
  final int expandPx;

  /// One soft pass over the mask edge.
  final bool antiAlias;

  FloodFillOptions copyWith({int? tolerance, int? expandPx, bool? antiAlias}) {
    return FloodFillOptions(
      tolerance: tolerance ?? this.tolerance,
      expandPx: expandPx ?? this.expandPx,
      antiAlias: antiAlias ?? this.antiAlias,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FloodFillOptions &&
      other.tolerance == tolerance &&
      other.expandPx == expandPx &&
      other.antiAlias == antiAlias;

  @override
  int get hashCode => Object.hash(tolerance, expandPx, antiAlias);
}

/// The filled region as a coverage mask in canvas coordinates.
class FloodFillRegion {
  const FloodFillRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.mask,
  });

  final int left;
  final int top;
  final int width;
  final int height;

  /// Row-major coverage bytes (width × height), 0..255.
  final Uint8List mask;
}

/// The fill's sampling target ("fill what you see"): the visible picture
/// as a straight-RGB raster, composited LAZILY tile by tile as the flood
/// visits pixels — a fill only pays for the region it actually floods,
/// never the whole canvas (R11-③: the eager full-canvas compose froze the
/// tap for seconds on big canvases). Posed layers are skipped (v1, same
/// rule as the eyedropper).
class LazyCanvasRasterRgb {
  LazyCanvasRasterRgb({
    required Cut cut,
    required int frameIndex,
    required LayerFrameSurfaceResolver surfaceResolver,
    Set<LayerId> fxBypassedLayerIds = const {},
    int paperColor = canvasPaperColor,
  }) : width = cut.canvasSize.width,
       height = cut.canvasSize.height,
       rgb = Uint8List(cut.canvasSize.width * cut.canvasSize.height * 3),
       _paperR = (paperColor >> 16) & 0xFF,
       _paperG = (paperColor >> 8) & 0xFF,
       _paperB = paperColor & 0xFF,
       _tilesX = (cut.canvasSize.width + _tileSize - 1) ~/ _tileSize,
       _composed = Uint8List(
         ((cut.canvasSize.width + _tileSize - 1) ~/ _tileSize) *
             ((cut.canvasSize.height + _tileSize - 1) ~/ _tileSize),
       ) {
    // Surfaces resolve ONCE (a cold resolve may replay paint commands).
    for (final entry in resolveCutFrameCompositeEntries(
      cut: cut,
      frameIndex: frameIndex,
      fxBypassedLayerIds: fxBypassedLayerIds,
    )) {
      if (entry.pose != null) {
        continue;
      }
      final surface = surfaceResolver(entry.layer, entry.frame);
      if (surface != null) {
        _layers.add((surface: surface, opacity: entry.opacity));
      }
    }
  }

  static const int _tileSize = 256;

  final int width;
  final int height;

  /// `width*height*3` bytes; only composed tiles hold real pixels — read
  /// through [ensureComposedAt].
  final Uint8List rgb;

  final int _paperR;
  final int _paperG;
  final int _paperB;
  final int _tilesX;
  final Uint8List _composed;
  final List<({BitmapSurface surface, double opacity})> _layers = [];

  /// Guarantees the tile containing pixel [index] (row-major) is composed.
  void ensureComposedAt(int index) {
    final x = index % width;
    final y = index ~/ width;
    final tileIndex = (y ~/ _tileSize) * _tilesX + (x ~/ _tileSize);
    if (_composed[tileIndex] != 0) {
      return;
    }
    _composed[tileIndex] = 1;
    _composeTile((x ~/ _tileSize) * _tileSize, (y ~/ _tileSize) * _tileSize);
  }

  void _composeTile(int left, int top) {
    final right = math.min(left + _tileSize, width);
    final bottom = math.min(top + _tileSize, height);
    for (var y = top; y < bottom; y += 1) {
      var target = (y * width + left) * 3;
      for (var x = left; x < right; x += 1) {
        rgb[target] = _paperR;
        rgb[target + 1] = _paperG;
        rgb[target + 2] = _paperB;
        target += 3;
      }
    }
    for (final layer in _layers) {
      final surface = layer.surface;
      // Integer blend (R15-⑥): the per-pixel double multiply/round path
      // was a whole-canvas-scale cost on big fills; the raster only feeds
      // seed MATCHING (tolerance compares), so byte-rounded source-over
      // is exact enough by construction.
      final opacityInt = (layer.opacity * 255).round();
      final surfaceTileSize = surface.tileSize;
      for (
        var ty = top ~/ surfaceTileSize;
        ty <= (bottom - 1) ~/ surfaceTileSize;
        ty += 1
      ) {
        for (
          var tx = left ~/ surfaceTileSize;
          tx <= (right - 1) ~/ surfaceTileSize;
          tx += 1
        ) {
          final tile = surface.tiles[TileCoord(x: tx, y: ty)];
          if (tile == null) {
            continue;
          }
          // Snapshot the tile's buffer ONCE (the getter copies).
          final pixels = tile.pixels;
          final baseX = tx * surfaceTileSize;
          final baseY = ty * surfaceTileSize;
          final clipLeft = math.max(left, baseX);
          final clipRight = math.min(right, baseX + surfaceTileSize);
          final clipTop = math.max(top, baseY);
          final clipBottom = math.min(bottom, baseY + surfaceTileSize);
          for (var y = clipTop; y < clipBottom; y += 1) {
            var source =
                ((y - baseY) * surfaceTileSize + (clipLeft - baseX)) * 4;
            var target = (y * width + clipLeft) * 3;
            for (var x = clipLeft; x < clipRight; x += 1) {
              final alphaByte = pixels[source + 3];
              if (alphaByte != 0) {
                final effective = (alphaByte * opacityInt + 127) ~/ 255;
                final inverse = 255 - effective;
                rgb[target] =
                    (pixels[source] * effective + rgb[target] * inverse + 127) ~/
                    255;
                rgb[target + 1] =
                    (pixels[source + 1] * effective +
                        rgb[target + 1] * inverse +
                        127) ~/
                    255;
                rgb[target + 2] =
                    (pixels[source + 2] * effective +
                        rgb[target + 2] * inverse +
                        127) ~/
                    255;
              }
              source += 4;
              target += 3;
            }
          }
        }
      }
    }
  }
}

/// Scanline flood fill over an RGB raster from the seed, within
/// [FloodFillOptions.tolerance] of the SEED color; null when the seed is
/// out of bounds. Includes expand + anti-alias post passes.
///
/// R14-② performance contract: [ensureComposed] fires per COMPOSE-TILE
/// crossing (256px, [LazyCanvasRasterRgb]'s tile), never per pixel — the
/// old per-visit dynamic dispatch across tens of millions of pixels was
/// the multi-second fill freeze on large regions. The vertical seeding
/// enqueues one seed per contiguous run (not every matching pixel), and
/// the expand/anti-alias passes operate on the CROPPED region instead of
/// copying the full canvas array per pass.
FloodFillRegion? floodFillRegion({
  required Uint8List rgb,
  required int width,
  required int height,
  required int seedX,
  required int seedY,
  FloodFillOptions options = const FloodFillOptions(),
  void Function(int index)? ensureComposed,
}) {
  if (seedX < 0 || seedY < 0 || seedX >= width || seedY >= height) {
    return null;
  }
  ensureComposed?.call(seedY * width + seedX);
  final seedIndex = (seedY * width + seedX) * 3;
  final seedR = rgb[seedIndex];
  final seedG = rgb[seedIndex + 1];
  final seedB = rgb[seedIndex + 2];
  final tolerance = options.tolerance;

  // Pure byte compare — the caller guarantees the pixel's compose tile via
  // the crossing checks below (one ensure per 256px boundary).
  bool matchesComposed(int index) {
    final base = index * 3;
    return (rgb[base] - seedR).abs() <= tolerance &&
        (rgb[base + 1] - seedG).abs() <= tolerance &&
        (rgb[base + 2] - seedB).abs() <= tolerance;
  }

  final filled = Uint8List(width * height);
  final stack = <int>[seedY * width + seedX];
  filled[seedY * width + seedX] = 255;
  var minX = seedX, maxX = seedX, minY = seedY, maxY = seedY;

  while (stack.isNotEmpty) {
    final index = stack.removeLast();
    final y = index ~/ width;
    final rowStart = y * width;

    // Expand the scanline run left and right; ensure fires only when the
    // walk crosses into a new 256px compose tile.
    var left = index - rowStart;
    while (left > 0 && filled[rowStart + left - 1] == 0) {
      if ((left & 0xFF) == 0) {
        ensureComposed?.call(rowStart + left - 1);
      }
      if (!matchesComposed(rowStart + left - 1)) {
        break;
      }
      left -= 1;
      filled[rowStart + left] = 255;
    }
    var right = index - rowStart;
    while (right < width - 1 && filled[rowStart + right + 1] == 0) {
      if (((right + 1) & 0xFF) == 0) {
        ensureComposed?.call(rowStart + right + 1);
      }
      if (!matchesComposed(rowStart + right + 1)) {
        break;
      }
      right += 1;
      filled[rowStart + right] = 255;
    }
    minX = math.min(minX, left);
    maxX = math.max(maxX, right);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);

    // Seed the rows above and below across the run — ONE seed per
    // contiguous matching run (the seed's own expansion fills the rest);
    // enqueueing every matching pixel used to flood the queue with the
    // whole region.
    for (final dy in const [-1, 1]) {
      final neighborY = y + dy;
      if (neighborY < 0 || neighborY >= height) {
        continue;
      }
      final neighborRow = neighborY * width;
      ensureComposed?.call(neighborRow + left);
      var runOpen = false;
      for (var x = left; x <= right; x += 1) {
        if ((x & 0xFF) == 0 && x != left) {
          ensureComposed?.call(neighborRow + x);
        }
        final neighborIndex = neighborRow + x;
        if (filled[neighborIndex] == 0 && matchesComposed(neighborIndex)) {
          if (!runOpen) {
            filled[neighborIndex] = 255;
            stack.add(neighborIndex);
            runOpen = true;
          }
        } else {
          runOpen = false;
        }
      }
    }
  }

  // Crop FIRST (with room for the expand growth), then run the expand and
  // anti-alias passes region-locally: the old grow pass copied and scanned
  // a full-canvas array per pass.
  final cropLeft = math.max(0, minX - options.expandPx);
  final cropTop = math.max(0, minY - options.expandPx);
  final cropRight = math.min(width - 1, maxX + options.expandPx);
  final cropBottom = math.min(height - 1, maxY + options.expandPx);
  final regionWidth = cropRight - cropLeft + 1;
  final regionHeight = cropBottom - cropTop + 1;
  final mask = Uint8List(regionWidth * regionHeight);
  for (var y = 0; y < regionHeight; y += 1) {
    final sourceStart = (cropTop + y) * width + cropLeft;
    mask.setRange(
      y * regionWidth,
      y * regionWidth + regionWidth,
      filled,
      sourceStart,
    );
  }

  // Expand: grow the region by N pixels (covers anti-aliased ink edges).
  for (var pass = 0; pass < options.expandPx; pass += 1) {
    final grown = Uint8List.fromList(mask);
    for (var y = 0; y < regionHeight; y += 1) {
      for (var x = 0; x < regionWidth; x += 1) {
        final index = y * regionWidth + x;
        if (mask[index] != 0) {
          continue;
        }
        final touches =
            (x > 0 && mask[index - 1] != 0) ||
            (x < regionWidth - 1 && mask[index + 1] != 0) ||
            (y > 0 && mask[index - regionWidth] != 0) ||
            (y < regionHeight - 1 && mask[index + regionWidth] != 0);
        if (touches) {
          grown[index] = 255;
        }
      }
    }
    mask.setAll(0, grown);
  }

  if (options.antiAlias) {
    // One soft edge pass: boundary mask pixels average their 4-neighbors.
    final smoothed = Uint8List.fromList(mask);
    for (var y = 0; y < regionHeight; y += 1) {
      for (var x = 0; x < regionWidth; x += 1) {
        final index = y * regionWidth + x;
        final center = mask[index];
        final leftV = x > 0 ? mask[index - 1] : 0;
        final rightV = x < regionWidth - 1 ? mask[index + 1] : 0;
        final upV = y > 0 ? mask[index - regionWidth] : 0;
        final downV = y < regionHeight - 1 ? mask[index + regionWidth] : 0;
        final sum = center + leftV + rightV + upV + downV;
        if (sum != center * 5) {
          smoothed[index] = ((center * 3 + (sum - center)) / 7).round();
        }
      }
    }
    mask.setAll(0, smoothed);
  }

  return FloodFillRegion(
    left: cropLeft,
    top: cropTop,
    width: regionWidth,
    height: regionHeight,
    mask: mask,
  );
}

/// The whole P6 tap: compose → fill from [point] → the region as ONE
/// mask-tipped dab ("fill = one dab"), committed through the exact stroke
/// funnel — three-route parity, undo and .qap serialization come free.
/// Null when nothing fills (seed off canvas).
BrushDab? buildFillDab({
  required Cut cut,
  required int frameIndex,
  required LayerFrameSurfaceResolver surfaceResolver,
  required CanvasPoint point,
  required int color,
  Set<LayerId> fxBypassedLayerIds = const {},
  FloodFillOptions options = const FloodFillOptions(),
  int paperColor = canvasPaperColor,
}) {
  final CanvasSize canvasSize = cut.canvasSize;
  final raster = labProbe(
    'fill.raster-ctor',
    () => LazyCanvasRasterRgb(
      cut: cut,
      frameIndex: frameIndex,
      surfaceResolver: surfaceResolver,
      fxBypassedLayerIds: fxBypassedLayerIds,
      paperColor: paperColor,
    ),
  );
  final region = labProbe(
    'fill.flood',
    () => floodFillRegion(
      rgb: raster.rgb,
      width: canvasSize.width,
      height: canvasSize.height,
      seedX: point.x.floor(),
      seedY: point.y.floor(),
      options: options,
      ensureComposed: raster.ensureComposedAt,
    ),
  );
  if (region == null) {
    return null;
  }

  // The fill lands as a COLOR STAMP (R15-⑥): rgba = fill color × mask
  // coverage, drawn 1:1 by the stamp blend path. The old square-padded
  // tip-mask dab re-sampled the giant mask bilinearly per pixel at every
  // materialization — a multi-second slice on large fills — and the stamp
  // is byte-exact by construction.
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  final rgba = labProbe('fill.stamp-build', () {
    final bytes = Uint8List(region.width * region.height * 4);
    for (var index = 0; index < region.mask.length; index += 1) {
      final coverage = region.mask[index];
      if (coverage == 0) {
        continue;
      }
      final offset = index * 4;
      bytes[offset] = r;
      bytes[offset + 1] = g;
      bytes[offset + 2] = b;
      bytes[offset + 3] = coverage;
    }
    return bytes;
  });
  return BrushDab(
    center: CanvasPoint(
      x: region.left + region.width / 2,
      y: region.top + region.height / 2,
    ),
    color: color,
    size: math.max(region.width, region.height).toDouble(),
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 0,
    stamp: BrushStampImage(
      id: 'fill-${DateTime.now().microsecondsSinceEpoch}',
      width: region.width,
      height: region.height,
      rgba: rgba,
    ),
  );
}
