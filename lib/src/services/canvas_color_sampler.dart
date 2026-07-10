import '../models/bitmap_surface.dart';
import '../models/canvas_point.dart';
import '../models/cut.dart';
import '../models/layer_id.dart';
import '../models/tile_coord.dart';
import 'cut_frame_composite_plan.dart';

/// The paper color the editing canvas paints (canvas_layer_stack_view) —
/// what an eyedropper pick over blank canvas returns.
const int canvasPaperColor = 0xFFEDEDED;

/// The straight-alpha RGBA of [surface] at integer canvas coords, or null
/// outside/empty (missing tiles are fully transparent).
int? surfacePixelRgba(BitmapSurface surface, int x, int y) {
  if (x < 0 ||
      y < 0 ||
      x >= surface.canvasSize.width ||
      y >= surface.canvasSize.height) {
    return null;
  }
  final tileSize = surface.tileSize;
  final tile = surface.tiles[TileCoord(x: x ~/ tileSize, y: y ~/ tileSize)];
  if (tile == null) {
    return 0;
  }
  final index = ((y % tileSize) * tileSize + (x % tileSize)) * 4;
  final pixels = tile.pixels;
  return (pixels[index] << 24) |
      (pixels[index + 1] << 16) |
      (pixels[index + 2] << 8) |
      pixels[index + 3];
}

/// Samples the VISIBLE composite color at [point] (P5 eyedropper): the
/// shared composite visit's entries blend bottom-up over the paper, with
/// each entry's effective opacity. Layers showing a transform pose are
/// skipped (v1 — sampling them would need the inverse pose mapping);
/// returns opaque ARGB.
int sampleCompositeColor({
  required Cut cut,
  required int frameIndex,
  required LayerFrameSurfaceResolver surfaceResolver,
  required CanvasPoint point,
  Set<LayerId> fxBypassedLayerIds = const {},
}) {
  final x = point.x.floor();
  final y = point.y.floor();

  var r = ((canvasPaperColor >> 16) & 0xFF).toDouble();
  var g = ((canvasPaperColor >> 8) & 0xFF).toDouble();
  var b = (canvasPaperColor & 0xFF).toDouble();

  for (final entry in resolveCutFrameCompositeEntries(
    cut: cut,
    frameIndex: frameIndex,
    fxBypassedLayerIds: fxBypassedLayerIds,
  )) {
    if (entry.pose != null) {
      continue;
    }
    final surface = surfaceResolver(entry.layer, entry.frame);
    if (surface == null) {
      continue;
    }
    final rgba = surfacePixelRgba(surface, x, y);
    if (rgba == null || rgba == 0) {
      continue;
    }
    final alpha = (rgba & 0xFF) / 255.0 * entry.opacity;
    if (alpha <= 0) {
      continue;
    }
    r = ((rgba >> 24) & 0xFF) * alpha + r * (1 - alpha);
    g = ((rgba >> 16) & 0xFF) * alpha + g * (1 - alpha);
    b = ((rgba >> 8) & 0xFF) * alpha + b * (1 - alpha);
  }
  return 0xFF000000 |
      (r.round().clamp(0, 255) << 16) |
      (g.round().clamp(0, 255) << 8) |
      b.round().clamp(0, 255);
}
