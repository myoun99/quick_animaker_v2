import 'dart:math' as math;
import 'dart:typed_data';

import '../models/brush_tip_mask.dart';

/// Built-in sampled brush tips, generated deterministically (fixed-seed
/// LCG) so the same bytes are produced on every run and platform — the
/// masks are engine data, and reproducibility keeps strokes and tests
/// stable. Real artist tips arrive later through ABR import.
final BrushTipMask chalkBrushTipMask = _generateChalkMask();
final BrushTipMask splatterBrushTipMask = _generateSplatterMask();

const int _maskSize = 64;

/// Grainy disc: a soft round footprint whose interior is modulated by
/// noise, leaving chalk-like speckle and ragged edges.
BrushTipMask _generateChalkMask() {
  final alpha = Uint8List(_maskSize * _maskSize);
  var seed = 0x9E3779B9;
  const center = _maskSize / 2.0;
  const radius = _maskSize / 2.0 - 1.0;
  for (var y = 0; y < _maskSize; y += 1) {
    for (var x = 0; x < _maskSize; x += 1) {
      final dx = x + 0.5 - center;
      final dy = y + 0.5 - center;
      final distance = math.sqrt(dx * dx + dy * dy);
      seed = _nextSeed(seed);
      if (distance > radius) {
        continue;
      }
      final falloff = 1.0 - (distance / radius) * 0.6;
      final noise = (seed >> 8) & 0xFF;
      // Drop ~30% of pixels entirely for grain; scale the rest by noise.
      if (noise < 77) {
        continue;
      }
      final value = (falloff * (96 + (noise - 77) * 159 / 178)).round();
      alpha[y * _maskSize + x] = value.clamp(0, 255);
    }
  }
  return BrushTipMask(id: 'builtin-chalk', size: _maskSize, alpha: alpha);
}

/// Scattered droplets: a dense core blob surrounded by satellite dots.
BrushTipMask _generateSplatterMask() {
  final alpha = Uint8List(_maskSize * _maskSize);
  var seed = 0x2545F491;

  void stampDot(double centerX, double centerY, double radius, int strength) {
    final left = math.max(0, (centerX - radius).floor());
    final top = math.max(0, (centerY - radius).floor());
    final right = math.min(_maskSize - 1, (centerX + radius).ceil());
    final bottom = math.min(_maskSize - 1, (centerY + radius).ceil());
    for (var y = top; y <= bottom; y += 1) {
      for (var x = left; x <= right; x += 1) {
        final dx = x + 0.5 - centerX;
        final dy = y + 0.5 - centerY;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance > radius) {
          continue;
        }
        final value = (strength * (1.0 - distance / radius)).round();
        final offset = y * _maskSize + x;
        alpha[offset] = math.max(alpha[offset], value.clamp(0, 255));
      }
    }
  }

  // Dense core.
  stampDot(_maskSize / 2.0, _maskSize / 2.0, 14, 255);
  // Satellites scattered around it.
  for (var dot = 0; dot < 26; dot += 1) {
    seed = _nextSeed(seed);
    final angle = ((seed >> 4) & 0x3FF) / 1024.0 * 2.0 * math.pi;
    seed = _nextSeed(seed);
    final distance = 10.0 + ((seed >> 4) & 0xFF) / 255.0 * 18.0;
    seed = _nextSeed(seed);
    final radius = 1.5 + ((seed >> 4) & 0xFF) / 255.0 * 4.0;
    seed = _nextSeed(seed);
    final strength = 140 + ((seed >> 4) & 0x7F);
    stampDot(
      _maskSize / 2.0 + math.cos(angle) * distance,
      _maskSize / 2.0 + math.sin(angle) * distance,
      radius,
      strength,
    );
  }
  return BrushTipMask(id: 'builtin-splatter', size: _maskSize, alpha: alpha);
}

/// Deterministic 31-bit LCG so the masks are identical everywhere.
int _nextSeed(int seed) => (seed * 1103515245 + 12345) & 0x7FFFFFFF;
