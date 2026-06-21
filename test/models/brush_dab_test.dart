import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_input_sample.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';

void main() {
  group('BrushDab', () {
    BrushDab dab({
      CanvasPoint? center,
      double size = 4,
      double opacity = 1,
      double flow = 1,
      double hardness = 1,
      BrushTipShape tipShape = BrushTipShape.round,
      double pressure = 1,
      int sequence = 0,
    }) {
      return BrushDab(
        center: center ?? CanvasPoint(x: 1, y: 2),
        size: size,
        opacity: opacity,
        flow: flow,
        hardness: hardness,
        tipShape: tipShape,
        pressure: pressure,
        sequence: sequence,
      );
    }

    test('creates with valid values', () {
      expect(dab().center, CanvasPoint(x: 1, y: 2));
    });

    test('rejects negative size', () {
      expect(() => dab(size: -0.1), throwsArgumentError);
    });

    test('allows zero size', () {
      expect(dab(size: 0).size, 0);
    });

    test('rejects opacity below 0', () {
      expect(() => dab(opacity: -0.1), throwsArgumentError);
    });

    test('rejects opacity above 1', () {
      expect(() => dab(opacity: 1.1), throwsArgumentError);
    });

    test('rejects flow below 0', () {
      expect(() => dab(flow: -0.1), throwsArgumentError);
    });

    test('rejects flow above 1', () {
      expect(() => dab(flow: 1.1), throwsArgumentError);
    });

    test('rejects hardness below 0', () {
      expect(() => dab(hardness: -0.1), throwsArgumentError);
    });

    test('rejects hardness above 1', () {
      expect(() => dab(hardness: 1.1), throwsArgumentError);
    });

    test('rejects pressure below 0', () {
      expect(() => dab(pressure: -0.1), throwsArgumentError);
    });

    test('rejects pressure above 1', () {
      expect(() => dab(pressure: 1.1), throwsArgumentError);
    });

    test('rejects negative sequence', () {
      expect(() => dab(sequence: -1), throwsArgumentError);
    });

    test('rejects non-finite size', () {
      expect(() => dab(size: double.nan), throwsArgumentError);
      expect(() => dab(size: double.infinity), throwsArgumentError);
    });

    test('rejects non-finite opacity', () {
      expect(() => dab(opacity: double.nan), throwsArgumentError);
      expect(() => dab(opacity: double.infinity), throwsArgumentError);
    });

    test('copyWith updates center', () {
      expect(
        dab().copyWith(center: CanvasPoint(x: 3, y: 4)).center,
        CanvasPoint(x: 3, y: 4),
      );
    });

    test('copyWith updates size', () {
      expect(dab().copyWith(size: 5).size, 5);
    });

    test('copyWith updates opacity', () {
      expect(dab().copyWith(opacity: 0.5).opacity, 0.5);
    });

    test('copyWith updates flow', () {
      expect(dab().copyWith(flow: 0.5).flow, 0.5);
    });

    test('copyWith updates hardness', () {
      expect(dab().copyWith(hardness: 0.5).hardness, 0.5);
    });

    test('copyWith updates tipShape', () {
      expect(
        dab().copyWith(tipShape: BrushTipShape.square).tipShape,
        BrushTipShape.square,
      );
    });

    test('copyWith updates pressure', () {
      expect(dab().copyWith(pressure: 0.5).pressure, 0.5);
    });

    test('copyWith updates sequence', () {
      expect(dab().copyWith(sequence: 5).sequence, 5);
    });

    test('equality includes all fields', () {
      final base = dab(
        size: 5,
        opacity: 0.6,
        flow: 0.7,
        hardness: 0.8,
        pressure: 0.9,
        sequence: 1,
      );
      expect(
        base,
        dab(
          size: 5,
          opacity: 0.6,
          flow: 0.7,
          hardness: 0.8,
          pressure: 0.9,
          sequence: 1,
        ),
      );
      expect(base.copyWith(center: CanvasPoint(x: 9, y: 2)), isNot(base));
      expect(base.copyWith(size: 9), isNot(base));
      expect(base.copyWith(opacity: 0.9), isNot(base));
      expect(base.copyWith(flow: 0.9), isNot(base));
      expect(base.copyWith(hardness: 0.9), isNot(base));
      expect(base.copyWith(tipShape: BrushTipShape.square), isNot(base));
      expect(base.copyWith(pressure: 0.1), isNot(base));
      expect(base.copyWith(sequence: 2), isNot(base));
    });

    test('hashCode is value-based', () {
      expect(dab().hashCode, dab().hashCode);
    });

    test('toJson/fromJson round-trips', () {
      final value = dab(
        tipShape: BrushTipShape.square,
        pressure: 0.4,
        sequence: 2,
      );
      expect(BrushDab.fromJson(value.toJson()), value);
    });

    test('fromInputSample uses sample position as CanvasPoint', () {
      final value = BrushDab.fromInputSample(
        sample: BrushInputSample(x: 3, y: 4),
        settings: BrushSettings(),
        sequence: 0,
      );
      expect(value.center, CanvasPoint(x: 3, y: 4));
    });

    test('fromInputSample applies pressureSize', () {
      final value = BrushDab.fromInputSample(
        sample: BrushInputSample(x: 0, y: 0, pressure: 0.25),
        settings: BrushSettings(size: 20, pressureSize: true),
        sequence: 0,
      );
      expect(value.size, 5);
    });

    test('fromInputSample applies pressureOpacity', () {
      final value = BrushDab.fromInputSample(
        sample: BrushInputSample(x: 0, y: 0, pressure: 0.25),
        settings: BrushSettings(opacity: 0.8, pressureOpacity: true),
        sequence: 0,
      );
      expect(value.opacity, 0.2);
    });

    test('fromInputSample preserves flow/hardness/tipShape', () {
      final value = BrushDab.fromInputSample(
        sample: BrushInputSample(x: 0, y: 0),
        settings: BrushSettings(
          flow: 0.3,
          hardness: 0.4,
          tipShape: BrushTipShape.square,
        ),
        sequence: 0,
      );
      expect(value.flow, 0.3);
      expect(value.hardness, 0.4);
      expect(value.tipShape, BrushTipShape.square);
    });
  });
}
