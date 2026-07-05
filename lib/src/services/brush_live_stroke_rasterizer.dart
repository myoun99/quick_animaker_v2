import 'dart:math' as math;
import 'dart:typed_data';

import '../models/brush_dab.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_size.dart';
import '../models/dirty_region.dart';
import 'brush_dab_dirty_region.dart';

/// Rasterizes the in-progress stroke incrementally into a canvas-sized
/// straight-alpha RGBA buffer.
///
/// This runs the exact blend math of the commit rasterizer
/// (`materializeBrushDabSequenceOnBitmapSurface`) — same coverage sampling of
/// pixel centers against the true fractional dab center, same floating-point
/// grouping, same rounding — so the pixels painted while drawing are
/// byte-identical to the committed result. The live display and the commit
/// fast-path both consume this buffer, which is what unifies the on-screen
/// stroke with the committed artwork. Equivalence with the commit rasterizer
/// is locked by `active_stroke_overlay_parity_test.dart` (byte-exact).
class BrushLiveStrokeRasterizer {
  BrushLiveStrokeRasterizer({required this.canvasSize})
    : pixels = Uint8List(canvasSize.width * canvasSize.height * 4);

  final CanvasSize canvasSize;

  /// Straight-alpha RGBA bytes of the stroke blended over transparency.
  final Uint8List pixels;

  DirtyRegion? _strokeBounds;
  int _blendedDabCount = 0;

  /// Union of every blended dab's dirty region, or `null` when nothing has
  /// been painted yet.
  DirtyRegion? get strokeBounds => _strokeBounds;

  /// Number of dabs blended so far.
  int get blendedDabCount => _blendedDabCount;

  /// Zeroes the previously painted region so the buffer can host the next
  /// stroke without reallocating.
  void clear() {
    final bounds = _strokeBounds;
    if (bounds != null) {
      final width = canvasSize.width;
      final top = math.max(0, bounds.top);
      final bottomExclusive = math.min(
        bounds.bottomExclusive,
        canvasSize.height,
      );
      final left = math.max(0, bounds.left);
      final rightExclusive = math.min(bounds.rightExclusive, width);
      for (var y = top; y < bottomExclusive; y += 1) {
        final rowStart = (y * width + left) * 4;
        pixels.fillRange(rowStart, rowStart + (rightExclusive - left) * 4, 0);
      }
    }
    _strokeBounds = null;
    _blendedDabCount = 0;
  }

  /// Blends `dabs[from..]` into [pixels] and returns the union of the newly
  /// touched region (clamped to the canvas), or `null` if nothing changed.
  DirtyRegion? blendFrom(List<BrushDab> dabs, {int? from}) {
    final start = from ?? _blendedDabCount;
    DirtyRegion? touched;

    for (var index = start; index < dabs.length; index += 1) {
      final region = _blendDab(dabs[index]);
      if (region != null) {
        touched = touched == null ? region : touched.union(region);
      }
    }
    _blendedDabCount = math.max(_blendedDabCount, dabs.length);
    if (touched != null) {
      _strokeBounds = _strokeBounds == null
          ? touched
          : _strokeBounds!.union(touched);
    }
    return touched;
  }

  DirtyRegion? _blendDab(BrushDab dab) {
    final region = dirtyRegionForBrushDab(dab);
    if (region == null) {
      return null;
    }

    final sourceArgb = dab.color;
    final sourceA = (sourceArgb >> 24) & 0xFF;
    if (sourceA == 0 || dab.opacity == 0.0 || dab.flow == 0.0) {
      return null;
    }
    final sourceR = (sourceArgb >> 16) & 0xFF;
    final sourceG = (sourceArgb >> 8) & 0xFF;
    final sourceB = sourceArgb & 0xFF;
    final sourceAlphaNorm = sourceA / 255.0;

    final radius = dab.size / 2.0;
    final hardRadius = radius * dab.hardness;
    final edgeSpan = radius - hardRadius;
    final isRound = dab.tipShape == BrushTipShape.round;
    final centerX = dab.center.x;
    final centerY = dab.center.y;
    final dabOpacity = dab.opacity;
    final dabFlow = dab.flow;
    final width = canvasSize.width;

    final top = region.top;
    final bottomExclusive = math.min(region.bottomExclusive, canvasSize.height);
    final left = region.left;
    final rightExclusive = math.min(region.rightExclusive, width);
    if (rightExclusive <= left || bottomExclusive <= top) {
      return null;
    }

    for (var y = top; y < bottomExclusive; y += 1) {
      final dy = y + 0.5 - centerY;
      final dySquared = dy * dy;
      final rowOffset = y * width;

      for (var x = left; x < rightExclusive; x += 1) {
        double coverage;
        if (isRound) {
          final dx = x + 0.5 - centerX;
          final distance = math.sqrt(dx * dx + dySquared);
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
          coverage = 1.0;
        }

        // Same grouping as the commit rasterizer:
        // effectiveOpacity = dab.opacity * coverage,
        // sourceAlpha = ((a/255) * effectiveOpacity) * flow.
        final effectiveOpacity = dabOpacity * coverage;
        if (effectiveOpacity == 0.0) {
          continue;
        }
        final sourceAlpha = sourceAlphaNorm * effectiveOpacity * dabFlow;

        final offset = (rowOffset + x) * 4;
        final destR = pixels[offset];
        final destG = pixels[offset + 1];
        final destB = pixels[offset + 2];
        final destA = pixels[offset + 3];

        final destinationAlpha = destA / 255.0;
        final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);
        if (outAlpha == 0.0) {
          pixels[offset] = 0;
          pixels[offset + 1] = 0;
          pixels[offset + 2] = 0;
          pixels[offset + 3] = 0;
          continue;
        }

        final inverseSourceAlpha = 1.0 - sourceAlpha;
        pixels[offset] =
            ((sourceR * sourceAlpha +
                        destR * destinationAlpha * inverseSourceAlpha) /
                    outAlpha)
                .round()
                .clamp(0, 255);
        pixels[offset + 1] =
            ((sourceG * sourceAlpha +
                        destG * destinationAlpha * inverseSourceAlpha) /
                    outAlpha)
                .round()
                .clamp(0, 255);
        pixels[offset + 2] =
            ((sourceB * sourceAlpha +
                        destB * destinationAlpha * inverseSourceAlpha) /
                    outAlpha)
                .round()
                .clamp(0, 255);
        pixels[offset + 3] = (outAlpha * 255.0).round().clamp(0, 255);
      }
    }

    return DirtyRegion(
      left: left,
      top: top,
      rightExclusive: rightExclusive,
      bottomExclusive: bottomExclusive,
    );
  }
}
