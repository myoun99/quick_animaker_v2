import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_settings.dart';
import '../../models/canvas_point.dart';
import '../../services/brush_dab_coverage.dart';
import '../../services/brush_tip_stamp_cache.dart';

/// A small S-curve stroke sample rendered with the preset's settings.
///
/// Dab pixel coverage comes from the shared [brushPixelCoveragesForDab]
/// oracle, so sampled tips, roundness/angle, hardness, dual masks, and
/// paper texture all show up honestly. The brush size is normalized to the
/// row height (a preview, not a 1:1 rendering), a synthetic 0-1-0 pressure
/// arc tapers the stroke when the pressure toggles are on, and placement
/// dynamics (scatter/jitter) are intentionally skipped to keep the preview
/// deterministic.
///
/// Rasterization is synchronous and cached per (settings, size); rows only
/// re-rasterize when the preset or the layout width changes.
class BrushStrokePreview extends StatefulWidget {
  const BrushStrokePreview({super.key, required this.settings});

  final BrushSettings settings;

  @override
  State<BrushStrokePreview> createState() => _BrushStrokePreviewState();
}

class _BrushStrokePreviewState extends State<BrushStrokePreview> {
  Uint8List? _alpha;
  int _width = 0;
  int _height = 0;

  @override
  void didUpdateWidget(covariant BrushStrokePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _alpha = null;
    }
  }

  void _ensureBuffer(int width, int height) {
    if (_alpha != null && _width == width && _height == height) {
      return;
    }
    _alpha = _rasterizeStrokeSample(widget.settings, width, height);
    _width = width;
    _height = height;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth.floor()
              : 160;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight.floor()
              : 28;
          if (width <= 0 || height <= 0) {
            return const SizedBox.shrink();
          }
          _ensureBuffer(width, height);
          return CustomPaint(
            size: Size(width.toDouble(), height.toDouble()),
            painter: _StrokeBufferPainter(
              alpha: _alpha!,
              bufferWidth: width,
              bufferHeight: height,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );
        },
      ),
    );
  }
}

Uint8List _rasterizeStrokeSample(
  BrushSettings settings,
  int width,
  int height,
) {
  final accumulated = Float64List(width * height);
  final baseSize = height * 0.62;
  final spacing = math.max(1.0, baseSize * settings.spacing.clamp(0.02, 4.0));
  final margin = baseSize * 0.5 + 1;

  const curveSteps = 512;
  double? previousX;
  double? previousY;
  var pendingDistance = double.infinity;
  var sequence = 0;
  for (var step = 0; step <= curveSteps; step += 1) {
    final t = step / curveSteps;
    final x = margin + t * (width - margin * 2);
    final y = height / 2 + math.sin(t * math.pi * 2) * height * 0.18;
    if (previousX != null && previousY != null) {
      final dx = x - previousX;
      final dy = y - previousY;
      pendingDistance += math.sqrt(dx * dx + dy * dy);
    }
    previousX = x;
    previousY = y;
    if (pendingDistance < spacing) {
      continue;
    }
    pendingDistance = 0;

    final pressure = math.sin(t * math.pi).clamp(0.08, 1.0);
    final sizeRatio = settings.pressureSize
        ? settings.minimumSizeRatio + (1 - settings.minimumSizeRatio) * pressure
        : 1.0;
    final opacity = settings.pressureOpacity
        ? settings.opacity * pressure
        : settings.opacity;
    // R20-B: the preview resolves through the tip-stamp cache like the
    // canvas does — what the list shows is the quantized reality.
    final dab = BrushTipStampCache.instance.resolveDab(
      BrushDab(
        center: CanvasPoint(x: x, y: y),
        color: 0xFF000000,
        size: math.max(1.0, baseSize * sizeRatio),
        opacity: opacity.clamp(0.05, 1.0),
        flow: settings.flow.clamp(0.05, 1.0),
        hardness: settings.hardness,
        tipShape: settings.tipShape,
        pressure: pressure,
        sequence: sequence,
        roundness: settings.roundness,
        angleDegrees: settings.angleDegrees,
        tipMask: settings.tipMask,
        dualMask: settings.dualMask,
        dualMaskScale: settings.dualMaskScale,
        textureMask: settings.textureMask,
        textureScale: settings.textureScale,
        textureDensity: settings.textureDensity,
      ),
    );
    sequence += 1;

    for (final pixel in brushPixelCoveragesForDab(dab)) {
      if (pixel.x >= width || pixel.y >= height) {
        continue;
      }
      final index = pixel.y * width + pixel.x;
      final dabAlpha = pixel.coverage * dab.flow * dab.opacity;
      accumulated[index] += dabAlpha * (1 - accumulated[index]);
    }
  }

  final bytes = Uint8List(width * height);
  for (var index = 0; index < bytes.length; index += 1) {
    bytes[index] = (accumulated[index].clamp(0.0, 1.0) * 255).round();
  }
  return bytes;
}

class _StrokeBufferPainter extends CustomPainter {
  const _StrokeBufferPainter({
    required this.alpha,
    required this.bufferWidth,
    required this.bufferHeight,
    required this.color,
  });

  final Uint8List alpha;
  final int bufferWidth;
  final int bufferHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 0; y < bufferHeight; y += 1) {
      final rowStart = y * bufferWidth;
      var x = 0;
      while (x < bufferWidth) {
        final value = alpha[rowStart + x];
        if (value == 0) {
          x += 1;
          continue;
        }
        // Merge equal-alpha horizontal runs into one rect.
        var runEnd = x + 1;
        while (runEnd < bufferWidth && alpha[rowStart + runEnd] == value) {
          runEnd += 1;
        }
        paint.color = color.withValues(alpha: value / 255);
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), (runEnd - x).toDouble(), 1),
          paint,
        );
        x = runEnd;
      }
    }
  }

  @override
  bool shouldRepaint(_StrokeBufferPainter oldDelegate) {
    return oldDelegate.alpha != alpha || oldDelegate.color != color;
  }
}
