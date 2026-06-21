import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_pixel_coverage.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/services/brush_dab_coverage.dart';

void main() {
  BrushDab dab({
    double x = 10,
    double y = 10,
    double size = 4,
    double opacity = 1,
    double flow = 1,
    double hardness = 1,
    BrushTipShape tipShape = BrushTipShape.round,
    int sequence = 0,
  }) {
    return BrushDab(
      center: CanvasPoint(x: x, y: y),
      color: 0xFF000000,
      size: size,
      opacity: opacity,
      flow: flow,
      hardness: hardness,
      tipShape: tipShape,
      pressure: 1,
      sequence: sequence,
    );
  }

  group('brushPixelCoveragesForDab', () {
    test('returns empty list for zero-size dab', () {
      expect(brushPixelCoveragesForDab(dab(size: 0)), isEmpty);
    });

    test('returns empty list for zero-opacity dab', () {
      expect(brushPixelCoveragesForDab(dab(opacity: 0)), isEmpty);
    });

    test('returns empty list for zero-flow dab', () {
      expect(brushPixelCoveragesForDab(dab(flow: 0)), isEmpty);
    });

    test('square tip covers all pixels in dirty region with coverage 1', () {
      expect(
        brushPixelCoveragesForDab(
          dab(x: 1, y: 1, size: 2, tipShape: BrushTipShape.square),
        ),
        [
          BrushPixelCoverage(x: 0, y: 0, coverage: 1),
          BrushPixelCoverage(x: 1, y: 0, coverage: 1),
          BrushPixelCoverage(x: 0, y: 1, coverage: 1),
          BrushPixelCoverage(x: 1, y: 1, coverage: 1),
        ],
      );
    });

    test('square tip returns pixels in row-major order', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 1, y: 1, size: 2, tipShape: BrushTipShape.square),
      );
      expect(values.map((value) => (value.x, value.y)), [
        (0, 0),
        (1, 0),
        (0, 1),
        (1, 1),
      ]);
    });

    test('round hard tip skips pixels outside radius', () {
      expect(
        brushPixelCoveragesForDab(dab(x: 1, y: 1, size: 1, hardness: 1)),
        isEmpty,
      );
    });

    test('round hard tip gives coverage 1 inside radius', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 1, y: 1, size: 2, hardness: 1),
      );
      expect(values, hasLength(4));
      expect(values.every((value) => value.coverage == 1), isTrue);
    });

    test('round soft tip gives lower coverage near edge', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 10, y: 10, size: 4, hardness: 0.5),
      );
      final nearCenter = values.firstWhere((value) => value.x == 9 && value.y == 9);
      final nearEdge = values.firstWhere((value) => value.x == 8 && value.y == 9);
      expect(nearCenter.coverage, 1);
      expect(nearEdge.coverage, allOf(greaterThan(0), lessThan(1)));
    });

    test('round hardness 1 produces hard coverage', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 10, y: 10, size: 4, hardness: 1),
      );
      expect(values, isNotEmpty);
      expect(values.every((value) => value.coverage == 1), isTrue);
    });

    test('round hardness 0 produces radial falloff', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 10, y: 10, size: 4, hardness: 0),
      );
      final nearCenter = values.firstWhere((value) => value.x == 9 && value.y == 9);
      final nearEdge = values.firstWhere((value) => value.x == 8 && value.y == 9);
      expect(nearCenter.coverage, closeTo(1 - (0.70710678 / 2), 0.000001));
      expect(nearEdge.coverage, lessThan(nearCenter.coverage));
    });

    test('fractional center uses pixel center convention', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 10.5, y: 10.5, size: 2, hardness: 1),
      );
      expect(values.map((value) => (value.x, value.y)), [
        (10, 10),
      ]);
    });

    test('coverage values are clamped to 0..1', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 10, y: 10, size: 4, hardness: 0),
      );
      expect(values, isNotEmpty);
      expect(
        values.every((value) => value.coverage >= 0 && value.coverage <= 1),
        isTrue,
      );
    });

    test('returns unmodifiable list if practical', () {
      final values = brushPixelCoveragesForDab(
        dab(x: 1, y: 1, size: 2, tipShape: BrushTipShape.square),
      );
      expect(
        () => values.add(BrushPixelCoverage(x: 9, y: 9, coverage: 1)),
        throwsUnsupportedError,
      );
    });

    test('does not mutate BrushDab', () {
      final value = dab(x: 10, y: 10, size: 4, hardness: 0.5);
      final before = value.copyWith();
      brushPixelCoveragesForDab(value);
      expect(value, before);
    });

    test('does not access BitmapTile or BitmapSurface', () {
      final values = brushPixelCoveragesForDab(dab());
      expect(values, isA<List<BrushPixelCoverage>>());
    });
  });
}
