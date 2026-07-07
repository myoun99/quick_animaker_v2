import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_mask.dart';
import 'package:quick_animaker_v2/src/services/brush_tip_mask_defaults.dart';
import 'package:quick_animaker_v2/src/services/brush_tip_mask_sampling.dart';

void main() {
  group('BrushTipMask', () {
    test('validates id, size, and byte count', () {
      expect(
        () => BrushTipMask(id: '', size: 2, alpha: Uint8List(4)),
        throwsArgumentError,
      );
      expect(
        () => BrushTipMask(id: 'tip', size: 0, alpha: Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => BrushTipMask(id: 'tip', size: 2, alpha: Uint8List(3)),
        throwsArgumentError,
      );
    });

    test('json round-trips content', () {
      final mask = BrushTipMask(
        id: 'tip',
        size: 2,
        alpha: Uint8List.fromList([0, 64, 128, 255]),
      );
      expect(BrushTipMask.fromJson(mask.toJson()), mask);
    });

    test('equality compares content, not identity', () {
      final a = BrushTipMask(
        id: 'tip',
        size: 2,
        alpha: Uint8List.fromList([0, 64, 128, 255]),
      );
      final b = BrushTipMask(
        id: 'tip',
        size: 2,
        alpha: Uint8List.fromList([0, 64, 128, 255]),
      );
      final c = BrushTipMask(
        id: 'tip',
        size: 2,
        alpha: Uint8List.fromList([0, 64, 128, 254]),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('stores a defensive copy of the alpha bytes', () {
      final source = Uint8List.fromList([1, 2, 3, 4]);
      final mask = BrushTipMask(id: 'tip', size: 2, alpha: source);
      source[0] = 99;
      expect(mask.alpha[0], 1);
    });
  });

  group('sampleBrushTipMaskCoverage', () {
    // 2x2 mask over radius 1: mask pixel centers land exactly on tip-space
    // offsets (-0.5, -0.5), (0.5, -0.5), etc., so samples are hand-checkable.
    final mask = BrushTipMask(
      id: 'test',
      size: 2,
      alpha: Uint8List.fromList([255, 0, 0, 255]),
    );

    double sample(double tipU, double tipV) => sampleBrushTipMaskCoverage(
      mask: mask,
      tipU: tipU,
      tipV: tipV,
      radius: 1.0,
    );

    test('samples texel centers exactly', () {
      expect(sample(-0.5, -0.5), 1.0); // top-left texel = 255
      expect(sample(0.5, -0.5), 0.0); // top-right texel = 0
      expect(sample(-0.5, 0.5), 0.0);
      expect(sample(0.5, 0.5), 1.0);
    });

    test('bilinear blends between texels', () {
      // Tip center: equal blend of 255, 0, 0, 255 -> 0.5.
      expect(sample(0.0, 0.0), closeTo(0.5, 1e-9));
      // Halfway between the top texels: blend of 255 and 0 -> 0.5.
      expect(sample(0.0, -0.5), closeTo(0.5, 1e-9));
    });

    test('fades toward the mask border where neighbors read as zero', () {
      // Past the outermost texel centers the missing neighbor reads as
      // zero, so coverage ramps down toward the mask border.
      expect(sample(-0.9, -0.5), closeTo(0.6, 1e-9));
      expect(sample(-1.0, -0.5), closeTo(0.5, 1e-9));
    });
  });

  group('sampleBrushTipMaskTiledCoverage', () {
    final checker = BrushTipMask(
      id: 'checker',
      size: 2,
      alpha: Uint8List.fromList([255, 0, 0, 255]),
    );

    double sample(double dx, double dy) => sampleBrushTipMaskTiledCoverage(
      mask: checker,
      dx: dx,
      dy: dy,
      period: 4.0,
      offsetU: 0.0,
      offsetV: 0.0,
    );

    test('repeats with the tile period', () {
      for (final dx in [-8.0, -4.0, 0.0, 4.0, 8.0]) {
        expect(sample(dx + 0.5, 0.5), closeTo(sample(0.5, 0.5), 1e-12));
      }
    });

    test('uniform mask yields full coverage everywhere', () {
      final solid = BrushTipMask(
        id: 'solid',
        size: 2,
        alpha: Uint8List.fromList([200, 200, 200, 200]),
      );
      for (final dx in [0.0, 1.3, -2.7, 5.5]) {
        expect(
          sampleBrushTipMaskTiledCoverage(
            mask: solid,
            dx: dx,
            dy: dx * 0.5,
            period: 3.0,
            offsetU: 0.4,
            offsetV: 0.9,
          ),
          closeTo(200 / 255, 1e-9),
        );
      }
    });

    test('offset shifts the sampled phase', () {
      // A half-period shift of the checker samples the complementary
      // blend: the two values differ and sum to full coverage.
      final base = sample(0.5, 0.5);
      final shifted = sampleBrushTipMaskTiledCoverage(
        mask: checker,
        dx: 0.5,
        dy: 0.5,
        period: 4.0,
        offsetU: 0.5,
        offsetV: 0.0,
      );
      expect(base, isNot(closeTo(shifted, 1e-9)));
      expect(base + shifted, closeTo(1.0, 1e-9));
    });
  });

  group('built-in sampled tips', () {
    test('are deterministic, non-empty, and square', () {
      expect(chalkBrushTipMask.id, 'builtin-chalk');
      expect(splatterBrushTipMask.id, 'builtin-splatter');
      for (final mask in [chalkBrushTipMask, splatterBrushTipMask]) {
        expect(mask.size, 64);
        expect(mask.alpha.length, 64 * 64);
        expect(mask.alpha.any((value) => value > 0), isTrue);
        expect(mask.alpha.any((value) => value == 0), isTrue);
      }
    });

    test('regenerate identically (fixed seed)', () {
      // Two reads of the lazily-initialized top-level values are identical
      // by construction; verify a stable fingerprint so a seed change or
      // algorithm drift is caught explicitly.
      var chalkSum = 0;
      for (final value in chalkBrushTipMask.alpha) {
        chalkSum += value;
      }
      var splatterSum = 0;
      for (final value in splatterBrushTipMask.alpha) {
        splatterSum += value;
      }
      expect(chalkSum, greaterThan(0));
      expect(splatterSum, greaterThan(0));
      // Fingerprints locked at first generation; a change means every
      // existing stroke drawn with these tips would re-render differently.
      expect(chalkSum, 224521);
      expect(splatterSum, 115796);
    });
  });

  group('axis lattices', () {
    test(
      'tip lattice sampling is EXACTLY the scalar sampler (unrotated tips)',
      () {
        final mask = chalkBrushTipMask;
        for (final config in [
          (radius: 13.7, centerX: 100.31, centerY: 57.9, roundness: 1.0),
          (radius: 100.0, centerX: 640.5, centerY: 360.5, roundness: 1.0),
          (radius: 31.25, centerX: 40.0, centerY: 40.01, roundness: 0.4),
        ]) {
          final radius = config.radius;
          final inverseRoundness = 1.0 / config.roundness;
          final left = (config.centerX - radius).floor() - 1;
          final top = (config.centerY - radius).floor() - 1;
          final count = (radius * 2).ceil() + 3;
          final uAxis = BrushTipMaskAxisLattice.compute(
            mask: mask,
            radius: radius,
            start: left,
            count: count,
            center: config.centerX,
          );
          final vAxis = BrushTipMaskAxisLattice.compute(
            mask: mask,
            radius: radius,
            start: top,
            count: count,
            center: config.centerY,
            inverseRoundness: inverseRoundness,
          );
          for (var yIndex = 0; yIndex < count; yIndex += 1) {
            final tipV =
                ((top + yIndex) + 0.5 - config.centerY) * inverseRoundness;
            for (var xIndex = 0; xIndex < count; xIndex += 1) {
              final tipU = (left + xIndex) + 0.5 - config.centerX;
              final culled = tipU.abs() > radius || tipV.abs() > radius;
              expect(
                uAxis.inRange[xIndex] == 0 || vAxis.inRange[yIndex] == 0,
                culled,
                reason: 'cull parity at ($xIndex, $yIndex) in $config',
              );
              if (culled) {
                continue;
              }
              final scalar = sampleBrushTipMaskCoverage(
                mask: mask,
                tipU: tipU,
                tipV: tipV,
                radius: radius,
              );
              final lattice = sampleBrushTipMaskCoverageLattice(
                mask: mask,
                uAxis: uAxis,
                uIndex: xIndex,
                vAxis: vAxis,
                vIndex: yIndex,
              );
              expect(
                lattice,
                scalar,
                reason: 'sample parity at ($xIndex, $yIndex) in $config',
              );
            }
          }
        }
      },
    );

    test('tiled lattice sampling is EXACTLY the scalar sampler', () {
      final mask = splatterBrushTipMask;
      for (final config in [
        (origin: -100.31, period: 27.5, offset: 0.37),
        (origin: 0.0, period: 64.0, offset: 0.0),
        (origin: -3.125, period: 200.0, offset: 0.91),
      ]) {
        const left = -5;
        const top = 11;
        const count = 300;
        final uAxis = TiledMaskAxisLattice.compute(
          mask: mask,
          start: left,
          count: count,
          originOffset: config.origin,
          period: config.period,
          offset: config.offset,
        );
        final vAxis = TiledMaskAxisLattice.compute(
          mask: mask,
          start: top,
          count: count,
          originOffset: config.origin,
          period: config.period,
          offset: config.offset,
        );
        for (var yIndex = 0; yIndex < count; yIndex += 7) {
          for (var xIndex = 0; xIndex < count; xIndex += 1) {
            final scalar = sampleBrushTipMaskTiledCoverage(
              mask: mask,
              dx: (left + xIndex) + 0.5 + config.origin,
              dy: (top + yIndex) + 0.5 + config.origin,
              period: config.period,
              offsetU: config.offset,
              offsetV: config.offset,
            );
            final lattice = sampleBrushTipMaskTiledCoverageLattice(
              mask: mask,
              uAxis: uAxis,
              uIndex: xIndex,
              vAxis: vAxis,
              vIndex: yIndex,
            );
            expect(
              lattice,
              scalar,
              reason: 'tiled parity at ($xIndex, $yIndex) in $config',
            );
          }
        }
      }
    });
  });
}
