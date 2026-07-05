import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/brush_tip_shape.dart';

/// Cache of brush tip alpha-mask images keyed by quantized
/// (size, hardness, tipShape, subpixel phase).
///
/// A tip mask carries the same per-pixel coverage the stroke-commit
/// rasterizer computes (`materializeBrushDabSequenceOnBitmapSurface`): fully
/// opaque inside `radius * hardness`, linear falloff to the radius, hard
/// square for the square tip. Stamping the mask tinted with the dab color
/// therefore previews the committed result instead of a hard square.
///
/// The rasterizer samples pixel centers against the dab's true fractional
/// center, so a single grid-centered mask cannot reproduce its edges: each
/// dab's boundary pixels would be off by up to half a pixel, which reads as
/// fizzing/stair-stepping along the live stroke. Masks are therefore baked
/// per subpixel phase (the dab anchor's fractional part, quantized to 1/4
/// pixel) and drawn at the floored anchor, making live edges match the
/// committed rasterization to within 1/8 px.
///
/// Masks are rendered synchronously with `Picture.toImageSync`, so the first
/// stamp of a new brush setting never falls back or flashes. This cache is
/// the substrate for future custom/ABR tip shapes: an imported tip becomes
/// just another alpha mask.
class BrushTipMaskCache {
  BrushTipMaskCache({this.capacity = 128});

  /// Shared instance used by the active stroke overlay painter.
  static final BrushTipMaskCache instance = BrushTipMaskCache();

  /// Subpixel phase steps per axis (1/4 px quantization).
  static const int phaseSteps = 4;

  /// Maximum retained masks; least-recently-used entries are disposed. One
  /// brush setting uses at most [phaseSteps]^2 masks, so the default keeps
  /// several recent settings warm.
  final int capacity;

  final LinkedHashMap<int, ui.Image> _masks = LinkedHashMap<int, ui.Image>();

  /// The mask for a dab of the given tip parameters whose top-left anchor
  /// (center - dimension/2) has fractional part ([phaseX], [phaseY]).
  ///
  /// The returned image is sized `dimension x dimension` (see
  /// [dimensionFor]) and must be drawn at the floored anchor.
  ui.Image maskFor({
    required double size,
    required double hardness,
    required BrushTipShape tipShape,
    double phaseX = 0.0,
    double phaseY = 0.0,
  }) {
    // Quantize to keep the key space small: size to 1/4 px, hardness to 1%,
    // phase to 1/phaseSteps px.
    final sizeQuarterPx = (size * 4.0).round().clamp(1, 4 * 4096);
    final hardnessPercent = (hardness * 100.0).round().clamp(0, 100);
    final phaseXStep = _quantizePhase(phaseX);
    final phaseYStep = _quantizePhase(phaseY);
    final key =
        (sizeQuarterPx << 15) |
        (hardnessPercent << 6) |
        (phaseXStep << 4) |
        (phaseYStep << 2) |
        tipShape.index;

    final cached = _masks.remove(key);
    if (cached != null) {
      _masks[key] = cached; // move to most-recently-used
      return cached;
    }

    final mask = _renderMask(
      size: sizeQuarterPx / 4.0,
      hardness: hardnessPercent / 100.0,
      tipShape: tipShape,
      phaseX: phaseXStep / phaseSteps,
      phaseY: phaseYStep / phaseSteps,
    );
    _masks[key] = mask;
    if (_masks.length > capacity) {
      _masks.remove(_masks.keys.first)?.dispose();
    }
    return mask;
  }

  /// Mask image dimension for a brush [size]: one texel of margin so any
  /// subpixel phase keeps the full tip inside the image.
  static int dimensionFor(double size) => math.max(1, size.ceil() + 1);

  static int _quantizePhase(double phase) {
    final wrapped = phase - phase.floorToDouble();
    return (wrapped * phaseSteps).round() % phaseSteps;
  }

  static ui.Image _renderMask({
    required double size,
    required double hardness,
    required BrushTipShape tipShape,
    required double phaseX,
    required double phaseY,
  }) {
    final dimension = dimensionFor(size);
    final radius = size / 2.0;
    // The dab anchor (center - dimension/2) sits at (phaseX, phaseY) within
    // the floored texel, so the tip center inside the mask is at
    // dimension/2 + phase.
    final centerX = dimension / 2.0 + phaseX;
    final centerY = dimension / 2.0 + phaseY;
    final hardRadius = radius * hardness;
    final edgeSpan = radius - hardRadius;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final pixelPaint = Paint()..isAntiAlias = false;

    if (tipShape == BrushTipShape.square) {
      // The rasterizer covers every pixel of the dab's dirty region for a
      // square tip; the region spans floor(center - r) .. ceil(center + r).
      pixelPaint.color = const Color(0xFFFFFFFF);
      final left = (centerX - radius).floorToDouble();
      final top = (centerY - radius).floorToDouble();
      canvas.drawRect(
        Rect.fromLTRB(
          left.clamp(0.0, dimension.toDouble()),
          top.clamp(0.0, dimension.toDouble()),
          (centerX + radius).ceilToDouble().clamp(0.0, dimension.toDouble()),
          (centerY + radius).ceilToDouble().clamp(0.0, dimension.toDouble()),
        ),
        pixelPaint,
      );
    } else {
      for (var y = 0; y < dimension; y += 1) {
        final dy = y + 0.5 - centerY;
        for (var x = 0; x < dimension; x += 1) {
          final dx = x + 0.5 - centerX;
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
