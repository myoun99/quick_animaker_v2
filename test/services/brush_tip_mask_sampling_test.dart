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
}
