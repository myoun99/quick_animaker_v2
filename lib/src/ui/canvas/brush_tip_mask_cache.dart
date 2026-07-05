import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/brush_tip_shape.dart';

/// Cache of brush tip alpha-mask images keyed by quantized
/// (size, hardness, tipShape).
///
/// A tip mask carries the same per-pixel coverage the stroke-commit
/// rasterizer computes (`materializeBrushDabSequenceOnBitmapSurface`): fully
/// opaque inside `radius * hardness`, linear falloff to the radius, hard
/// square for the square tip. Stamping the mask tinted with the dab color
/// therefore previews the committed result instead of a hard square.
///
/// Masks are rendered synchronously with `Picture.toImageSync`, so the first
/// stamp of a new brush setting never falls back or flashes. This cache is
/// the substrate for future custom/ABR tip shapes: an imported tip becomes
/// just another alpha mask.
class BrushTipMaskCache {
  BrushTipMaskCache({this.capacity = 64});

  /// Shared instance used by the active stroke overlay painter.
  static final BrushTipMaskCache instance = BrushTipMaskCache();

  /// Maximum retained masks; least-recently-used entries are disposed.
  final int capacity;

  final LinkedHashMap<int, ui.Image> _masks = LinkedHashMap<int, ui.Image>();

  /// Returns the alpha mask for the given tip parameters, rendering it on
  /// first use. The mask dimension is `size.ceil() + 1` and the tip center is
  /// at exactly (dimension / 2, dimension / 2).
  ui.Image maskFor({
    required double size,
    required double hardness,
    required BrushTipShape tipShape,
  }) {
    // Quantize to keep the key space small: size to 1/4 px, hardness to 1%.
    final sizeQuarterPx = (size * 4.0).round().clamp(1, 4 * 4096);
    final hardnessPercent = (hardness * 100.0).round().clamp(0, 100);
    final key = (sizeQuarterPx << 9) | (hardnessPercent << 2) | tipShape.index;

    final cached = _masks.remove(key);
    if (cached != null) {
      _masks[key] = cached; // move to most-recently-used
      return cached;
    }

    final mask = _renderMask(
      size: sizeQuarterPx / 4.0,
      hardness: hardnessPercent / 100.0,
      tipShape: tipShape,
    );
    _masks[key] = mask;
    if (_masks.length > capacity) {
      _masks.remove(_masks.keys.first)?.dispose();
    }
    return mask;
  }

  static ui.Image _renderMask({
    required double size,
    required double hardness,
    required BrushTipShape tipShape,
  }) {
    // Odd dimension so the central texel center lands exactly on the tip
    // center — matching the rasterizer's pixel-center sampling when a dab
    // sits on a pixel center (critical for 1px brushes). The reduced odd
    // dimension still contains every texel center within the tip radius.
    var dimension = math.max(1, size.ceil() + 1);
    if (dimension.isEven) {
      dimension -= 1;
    }
    final center = dimension / 2.0;
    final radius = size / 2.0;
    final hardRadius = radius * hardness;
    final edgeSpan = radius - hardRadius;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final pixelPaint = Paint()..isAntiAlias = false;

    if (tipShape == BrushTipShape.square) {
      pixelPaint.color = const Color(0xFFFFFFFF);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, dimension.toDouble(), dimension.toDouble()),
        pixelPaint,
      );
    } else {
      for (var y = 0; y < dimension; y += 1) {
        final dy = y + 0.5 - center;
        for (var x = 0; x < dimension; x += 1) {
          final dx = x + 0.5 - center;
          final distance = math.sqrt(dx * dx + dy * dy);
          if (distance > radius) {
            continue;
          }
          final double coverage;
          if (distance <= hardRadius || edgeSpan <= 0.0) {
            coverage = 1.0;
          } else {
            coverage = (1.0 - ((distance - hardRadius) / edgeSpan)).clamp(
              0.0,
              1.0,
            );
          }
          final alpha = (coverage * 255.0).round();
          if (alpha <= 0) {
            continue;
          }
          pixelPaint.color = Color.fromARGB(alpha, 255, 255, 255);
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            pixelPaint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(dimension, dimension);
    picture.dispose();
    return image;
  }
}
