import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';

import '../../models/bitmap_surface.dart';
import '../../models/camera_pose.dart';
import '../../models/canvas_size.dart';
import '../../services/cut_frame_composite_plan.dart';
import '../canvas/bitmap_tile_image_cache.dart';
import '../canvas/layer_pose_paint.dart';
import '../canvas/tiled_surface_compose.dart';

/// File name for one exported frame: `frame_0001.png` (1-based).
String cameraSequenceFileName(int frameIndex, {int digits = 4}) {
  return 'frame_${(frameIndex + 1).toString().padLeft(digits, '0')}.png';
}

/// Surfaces with at least this many pixels assemble their upload buffer in
/// a background isolate; smaller ones stay synchronous (the spawn/copy
/// overhead would dominate, and fake-async widget tests never pump real
/// isolates — production canvases are far above, test fixtures far below).
const int _uploadOffloadPixelThreshold = 512 * 512;

/// Test override for the isolate cutoff; null = [_uploadOffloadPixelThreshold].
@visibleForTesting
int? debugUploadOffloadPixelThreshold;

/// Converts a tiled [BitmapSurface] into one [ui.Image].
///
/// Tile bytes are straight (unpremultiplied) alpha but raw rgba8888 uploads
/// are interpreted as premultiplied, so the copy premultiplies with the same
/// mul-div-255 rounding the tile image cache uses. On canvas-sized surfaces
/// that per-pixel pass is the largest post-stroke chunk left on the UI
/// thread (debug builds especially), so it runs in a background isolate.
Future<ui.Image> bitmapSurfaceToImage(BitmapSurface surface) async {
  final width = surface.canvasSize.width;
  final height = surface.canvasSize.height;
  // Sendable snapshot: tile pixel buffers are copies already (the tile
  // getter clones), so the isolate borrows plain records.
  final tiles = [
    for (final tile in surface.tiles.values)
      (
        originX: tile.coord.x * tile.size,
        originY: tile.coord.y * tile.size,
        size: tile.size,
        pixels: tile.pixels,
      ),
  ];
  final threshold =
      debugUploadOffloadPixelThreshold ?? _uploadOffloadPixelThreshold;
  final buffer = width * height >= threshold
      ? await Isolate.run(
          () => _assemblePremultipliedRgba(tiles, width, height),
        )
      : _assemblePremultipliedRgba(tiles, width, height);

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    buffer,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// The full-canvas premultiplied upload buffer, assembled from straight-
/// alpha tile snapshots. Pure bytes → bytes so it runs identically on the
/// UI thread and in the offload isolate.
Uint8List _assemblePremultipliedRgba(
  List<({int originX, int originY, int size, Uint8List pixels})> tiles,
  int width,
  int height,
) {
  final buffer = Uint8List(width * height * 4);
  for (final tile in tiles) {
    final pixels = tile.pixels;
    final copyWidth = math.min(tile.size, width - tile.originX);
    final copyHeight = math.min(tile.size, height - tile.originY);
    for (var localY = 0; localY < copyHeight; localY += 1) {
      var source = localY * tile.size * 4;
      var target = ((tile.originY + localY) * width + tile.originX) * 4;
      for (var localX = 0; localX < copyWidth; localX += 1) {
        final alpha = pixels[source + 3];
        if (alpha == 255) {
          buffer[target] = pixels[source];
          buffer[target + 1] = pixels[source + 1];
          buffer[target + 2] = pixels[source + 2];
        } else if (alpha != 0) {
          buffer[target] = _mul255Round(pixels[source], alpha);
          buffer[target + 1] = _mul255Round(pixels[source + 1], alpha);
          buffer[target + 2] = _mul255Round(pixels[source + 2], alpha);
        }
        buffer[target + 3] = alpha;
        source += 4;
        target += 4;
      }
    }
  }
  return buffer;
}

/// Skia's `SkMulDiv255Round`: round(value * alpha / 255) for bytes.
int _mul255Round(int value, int alpha) {
  final product = value * alpha + 128;
  return (product + (product >> 8)) >> 8;
}

/// Renders a composited cut frame as seen through the camera.
///
/// The output shows the camera view rect (the camera frame silhouette from
/// the canvas overlay): output center = pose center, one output pixel covers
/// `1 / (pose.zoom * outputSize/cameraFrameSize)` canvas pixels, and the
/// canvas appears rotated opposite to the camera's clockwise rotation.
class CameraFrameRenderService {
  const CameraFrameRenderService({
    this.background = const Color(0xFFFFFFFF),
    this.filterQuality = FilterQuality.low,
  });

  /// Fills the whole output, including any area beyond the canvas edges.
  final Color background;

  final FilterQuality filterQuality;

  /// [outputSize] defaults to [cameraFrameSize]; a smaller value renders a
  /// scaled-down preview of the exact same view.
  Future<ui.Image> renderThroughCamera({
    required List<CutFrameCompositeLayer> layers,
    required CameraPose pose,
    required CanvasSize cameraFrameSize,
    CanvasSize? outputSize,
  }) async {
    final resolvedOutput = outputSize ?? cameraFrameSize;
    final layerImages = <ui.Image>[];
    for (final layer in layers) {
      // Per-tile GPU compose (already-decoded tiles draw without any new
      // upload — the storyboard thumbnail after a stroke reuses the editing
      // canvas's tiles); the camera transform then samples the composed
      // full-res image exactly as before.
      layerImages.add(
        await composeTiledSurfaceImage(
          layer.surface,
          reuse: BitmapTileImageCache.instance,
        ),
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        resolvedOutput.width.toDouble(),
        resolvedOutput.height.toDouble(),
      ),
      Paint()..color = background,
    );

    final previewScale = resolvedOutput.width / cameraFrameSize.width;
    canvas.translate(resolvedOutput.width / 2, resolvedOutput.height / 2);
    canvas.scale(previewScale * pose.zoom);
    // The camera is rotated clockwise over the canvas, so the world appears
    // rotated the opposite way through it.
    canvas.rotate(-pose.rotationDegrees * math.pi / 180);
    canvas.translate(-pose.center.x, -pose.center.y);

    for (var index = 0; index < layerImages.length; index += 1) {
      // Layer transforms apply at composite time (never baked); identity
      // layers skip the save/restore.
      final layerPose = layers[index].pose;
      if (layerPose != null) {
        canvas.save();
        applyLayerPoseTransform(
          canvas,
          layerPose,
          layers[index].surface.canvasSize,
          anchorPoint: layers[index].anchorPoint,
        );
      }
      canvas.drawImage(
        layerImages[index],
        Offset.zero,
        Paint()
          ..filterQuality = filterQuality
          ..color = Color.fromRGBO(0, 0, 0, layers[index].opacity),
      );
      if (layerPose != null) {
        canvas.restore();
      }
    }

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(resolvedOutput.width, resolvedOutput.height);
    } finally {
      picture.dispose();
      for (final image in layerImages) {
        image.dispose();
      }
    }
  }
}
