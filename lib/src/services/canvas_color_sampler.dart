import '../core/floor_math.dart';
import '../models/bitmap_surface.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/layer_id.dart';
import '../models/pasteboard_bounds.dart';
import '../models/tile_coord.dart';
import '../ui/canvas/layer_pose_paint.dart' show layerPoseMatrix;
import 'cut_frame_composite_plan.dart';

/// The classic paper color — the default blend base when the caller does
/// not thread the project background (R10-⑥: production passes the
/// project's paper; a transparent background blends over its opaque
/// export-fallback color).
const int canvasPaperColor = 0xFFEDEDED;

/// The straight-alpha RGBA of [surface] at integer canvas coords, or null
/// beyond the PASTEBOARD wall (missing tiles are fully transparent).
/// Off-canvas coordinates are real pixels — the eyedropper picks them
/// like Flash does; floorDiv keeps negative coords on the right tile.
int? surfacePixelRgba(BitmapSurface surface, int x, int y) {
  if (!surface.canvasSize.containsPasteboardPixel(x: x, y: y)) {
    return null;
  }
  final tileSize = surface.tileSize;
  final tile = surface.tiles[TileCoord(
    x: floorDiv(x, tileSize),
    y: floorDiv(y, tileSize),
  )];
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

/// Where the eyedropper reads its color from (R28 #6, the PS/CSP setting).
enum CanvasColorSampleSource {
  /// Every visible layer, blended bottom-up over the paper — "pick what
  /// you SEE". The user's default.
  display,

  /// The ACTIVE layer's own pixels only. Transparent artwork reads as the
  /// paper beneath it, which is what Photoshop's "current layer" does once
  /// there is nothing to pick.
  layer,
}

/// The canvas point mapped into [entry]'s ARTWORK space — the inverse of
/// the pose [applyLayerPoseTransform] paints with. Null when the pose is
/// singular (a zero zoom collapses the layer to nothing, so there is no
/// pixel under the pointer).
///
/// R28 #7: posed layers used to be SKIPPED here, which meant any layer
/// carrying a transform — or merely sitting inside a folder that did —
/// contributed nothing and the pick fell through to the paper. That is the
/// "그림이 있는 레이어인데도 뭐든 #EDEDED" report, and it came and went with
/// whether a transform key happened to exist at the time.
CanvasPoint? _artworkPointFor(
  CutFrameCompositeEntry entry,
  CanvasSize canvasSize,
  CanvasPoint point,
) {
  final pose = entry.pose;
  if (pose == null) {
    return point;
  }
  final matrix = layerPoseMatrix(
    pose,
    canvasSize,
    anchorPoint: entry.anchorPoint,
  );
  if (matrix.invert() == 0) {
    return null;
  }
  final mapped = matrix.storage;
  return CanvasPoint(
    x: mapped[0] * point.x + mapped[4] * point.y + mapped[12],
    y: mapped[1] * point.x + mapped[5] * point.y + mapped[13],
  );
}

/// Samples the color at [point] (P5 eyedropper); returns opaque ARGB.
///
/// [source] picks the reference (R28 #6): `display` blends the shared
/// composite visit's entries bottom-up over the paper with each entry's
/// effective opacity, `layer` reads [activeLayerId]'s pixels alone. Either
/// way a POSED layer samples through the inverse of its pose, so the pick
/// matches what the screen shows.
///
/// Works in every section and on every layer kind by construction: a row
/// with no artwork simply contributes nothing and the paper shows through
/// (an SE row picks the canvas color, which is the behaviour the user
/// described).
int sampleCompositeColor({
  required Cut cut,
  required int frameIndex,
  required LayerFrameSurfaceResolver surfaceResolver,
  required CanvasPoint point,
  Set<LayerId> fxBypassedLayerIds = const {},
  int paperColor = canvasPaperColor,
  CanvasColorSampleSource source = CanvasColorSampleSource.display,
  LayerId? activeLayerId,
}) {
  var r = ((paperColor >> 16) & 0xFF).toDouble();
  var g = ((paperColor >> 8) & 0xFF).toDouble();
  var b = (paperColor & 0xFF).toDouble();

  for (final entry in resolveCutFrameCompositeEntries(
    cut: cut,
    frameIndex: frameIndex,
    fxBypassedLayerIds: fxBypassedLayerIds,
  )) {
    if (source == CanvasColorSampleSource.layer &&
        entry.layer.id != activeLayerId) {
      continue;
    }
    final surface = surfaceResolver(entry.layer, entry.frame);
    if (surface == null) {
      continue;
    }
    final artworkPoint = _artworkPointFor(entry, cut.canvasSize, point);
    if (artworkPoint == null) {
      continue;
    }
    final rgba = surfacePixelRgba(
      surface,
      artworkPoint.x.floor(),
      artworkPoint.y.floor(),
    );
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
