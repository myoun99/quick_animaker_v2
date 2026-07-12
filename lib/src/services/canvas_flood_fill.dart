import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
import '../models/brush_tip_mask.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/layer_id.dart';
import '../models/tile_coord.dart';
import 'canvas_color_sampler.dart';
import 'cut_frame_composite_plan.dart';

/// P6 fill options (the tool's panel knobs later; sane defaults now).
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
      final opacity = layer.opacity;
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
                final alpha = alphaByte / 255.0 * opacity;
                rgb[target] =
                    (pixels[source] * alpha + rgb[target] * (1 - alpha))
                        .round();
                rgb[target + 1] =
                    (pixels[source + 1] * alpha + rgb[target + 1] * (1 - alpha))
                        .round();
                rgb[target + 2] =
                    (pixels[source + 2] * alpha + rgb[target + 2] * (1 - alpha))
                        .round();
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

  bool matches(int index) {
    ensureComposed?.call(index);
    final base = index * 3;
    return (rgb[base] - seedR).abs() <= tolerance &&
        (rgb[base + 1] - seedG).abs() <= tolerance &&
        (rgb[base + 2] - seedB).abs() <= tolerance;
  }

  final filled = Uint8List(width * height);
  final queue = Queue<int>()..add(seedY * width + seedX);
  filled[seedY * width + seedX] = 255;
  var minX = seedX, maxX = seedX, minY = seedY, maxY = seedY;

  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final y = index ~/ width;
    // Expand the scanline run left and right.
    var left = index;
    while (left % width > 0 && filled[left - 1] == 0 && matches(left - 1)) {
      left -= 1;
      filled[left] = 255;
    }
    var right = index;
    while ((right + 1) % width != 0 &&
        filled[right + 1] == 0 &&
        matches(right + 1)) {
      right += 1;
      filled[right] = 255;
    }
    final runMinX = left % width;
    final runMaxX = right % width;
    minX = math.min(minX, runMinX);
    maxX = math.max(maxX, runMaxX);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
    // Seed the rows above and below across the run.
    for (final rowStart in [
      if (y > 0) left - width,
      if (y < height - 1) left + width,
    ]) {
      for (var i = rowStart; i <= rowStart + (right - left); i += 1) {
        if (filled[i] == 0 && matches(i)) {
          filled[i] = 255;
          queue.add(i);
        }
      }
    }
  }

  // Expand: grow the region by N pixels (covers anti-aliased ink edges).
  for (var pass = 0; pass < options.expandPx; pass += 1) {
    final grown = Uint8List.fromList(filled);
    for (
      var y = math.max(0, minY - pass - 1);
      y <= math.min(height - 1, maxY + pass + 1);
      y += 1
    ) {
      for (
        var x = math.max(0, minX - pass - 1);
        x <= math.min(width - 1, maxX + pass + 1);
        x += 1
      ) {
        final index = y * width + x;
        if (filled[index] != 0) {
          continue;
        }
        final touches =
            (x > 0 && filled[index - 1] != 0) ||
            (x < width - 1 && filled[index + 1] != 0) ||
            (y > 0 && filled[index - width] != 0) ||
            (y < height - 1 && filled[index + width] != 0);
        if (touches) {
          grown[index] = 255;
        }
      }
    }
    filled.setAll(0, grown);
    minX = math.max(0, minX - 1);
    minY = math.max(0, minY - 1);
    maxX = math.min(width - 1, maxX + 1);
    maxY = math.min(height - 1, maxY + 1);
  }

  final regionWidth = maxX - minX + 1;
  final regionHeight = maxY - minY + 1;
  final mask = Uint8List(regionWidth * regionHeight);
  for (var y = 0; y < regionHeight; y += 1) {
    for (var x = 0; x < regionWidth; x += 1) {
      mask[y * regionWidth + x] = filled[(minY + y) * width + (minX + x)];
    }
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
    left: minX,
    top: minY,
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
  final raster = LazyCanvasRasterRgb(
    cut: cut,
    frameIndex: frameIndex,
    surfaceResolver: surfaceResolver,
    fxBypassedLayerIds: fxBypassedLayerIds,
    paperColor: paperColor,
  );
  final region = floodFillRegion(
    rgb: raster.rgb,
    width: canvasSize.width,
    height: canvasSize.height,
    seedX: point.x.floor(),
    seedY: point.y.floor(),
    options: options,
    ensureComposed: raster.ensureComposedAt,
  );
  if (region == null) {
    return null;
  }

  // Pad the region into the SQUARE mask BrushTipMask requires, centered so
  // the dab center = the region center (1:1 pixel mapping at dab size =
  // square size, hardness 1 = no falloff).
  final square = math.max(region.width, region.height);
  final offsetX = (square - region.width) ~/ 2;
  final offsetY = (square - region.height) ~/ 2;
  final alpha = Uint8List(square * square);
  for (var y = 0; y < region.height; y += 1) {
    alpha.setRange(
      (y + offsetY) * square + offsetX,
      (y + offsetY) * square + offsetX + region.width,
      region.mask,
      y * region.width,
    );
  }

  // The square's canvas top-left is (region.left - offsetX,
  // region.top - offsetY); the dab covers [center - size/2, center +
  // size/2], so this center puts the mask exactly over the region.
  return BrushDab(
    center: CanvasPoint(
      x: region.left - offsetX + square / 2,
      y: region.top - offsetY + square / 2,
    ),
    color: color,
    size: square.toDouble(),
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 0,
    tipMask: BrushTipMask(
      id: 'fill-${DateTime.now().microsecondsSinceEpoch}',
      size: square,
      alpha: alpha,
    ),
  );
}
