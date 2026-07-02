import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/services/brush_dab_interpolator.dart';

void main() {
  BrushDab dab(double x, double y, {double size = 8, int sequence = 0}) {
    return BrushDab(
      center: CanvasPoint(x: x, y: y),
      color: 0xFF000000,
      size: size,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.round,
      pressure: 1,
      sequence: sequence,
    );
  }

  test('fast movement inserts intermediate dabs using brush-size spacing', () {
    const interpolator = BrushDabInterpolator();
    final first = interpolator
        .interpolate(previous: null, nextRaw: dab(0, 0), firstSequence: 0)
        .single;

    final sampled = interpolator.interpolate(
      previous: first,
      nextRaw: dab(10, 0),
      firstSequence: 1,
    );

    expect(sampled.length, greaterThan(1));
    expect(sampled.last.center.x, 10);
    expect(sampled.last.center.y, 0);
  });

  test(
    'movement just beyond spacing inserts an intermediate dab and endpoint',
    () {
      const interpolator = BrushDabInterpolator();
      final sampled = interpolator.interpolate(
        previous: dab(0, 0, size: 8, sequence: 0),
        nextRaw: dab(2.1, 0, size: 8),
        firstSequence: 1,
      );

      final sequences = sampled.map((item) => item.sequence).toList();
      expect(sampled, isNotEmpty);
      expect(sampled.last.center.x, 2.1);
      expect(sampled.last.center.y, 0);
      expect(sequences, everyElement(greaterThanOrEqualTo(0)));
      expect(_isStrictlyIncreasing(sequences), isTrue);
    },
  );

  test('tiny movement below spacing does not generate duplicate dabs', () {
    const interpolator = BrushDabInterpolator();
    final first = dab(0, 0, sequence: 0);

    final sampled = interpolator.interpolate(
      previous: first,
      nextRaw: dab(0.5, 0, size: 8),
      firstSequence: 1,
    );

    expect(sampled, isEmpty);
  });

  test('generated dabs keep increasing sequence numbers', () {
    const interpolator = BrushDabInterpolator();
    final sampled = interpolator.interpolate(
      previous: dab(0, 0, sequence: 7),
      nextRaw: dab(10, 0),
      firstSequence: 8,
    );

    final sequences = sampled.map((item) => item.sequence).toList();
    expect(sequences, everyElement(greaterThanOrEqualTo(0)));
    expect(_isStrictlyIncreasing(sequences), isTrue);
  });

  test('never emits negative sequence numbers', () {
    const interpolator = BrushDabInterpolator();
    final first = interpolator.interpolate(
      previous: null,
      nextRaw: dab(0, 0),
      firstSequence: 0,
    );
    final sampled = interpolator.interpolate(
      previous: first.single,
      nextRaw: dab(10, 0),
      firstSequence: first.length,
    );

    expect(
      [...first, ...sampled].map((item) => item.sequence),
      everyElement(greaterThanOrEqualTo(0)),
    );
  });
}

bool _isStrictlyIncreasing(Iterable<int> values) {
  int? previous;
  for (final value in values) {
    if (previous != null && value <= previous) {
      return false;
    }
    previous = value;
  }
  return true;
}
