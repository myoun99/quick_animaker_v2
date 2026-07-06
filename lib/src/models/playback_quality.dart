import 'dart:math' as math;

import 'canvas_size.dart';

/// Playback preview resolution presets, like the Premiere/AE monitor
/// quality selector. The scale applies to the cached raster size; the view
/// upscales back to canvas size on screen.
enum PlaybackQuality {
  full(1.0),
  half(0.5),
  quarter(0.25);

  const PlaybackQuality(this.scale);

  final double scale;
}

/// The raster size cached for [quality]; never collapses below 1×1.
CanvasSize scaledCanvasSize(CanvasSize size, PlaybackQuality quality) {
  return CanvasSize(
    width: math.max(1, (size.width * quality.scale).round()),
    height: math.max(1, (size.height * quality.scale).round()),
  );
}
