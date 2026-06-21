import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';

void main() {
  group('BrushSettings', () {
    test('default values are stable', () {
      final brush = BrushSettings();

      expect(brush.color, 0xFF000000);
      expect(brush.size, 4.0);
      expect(brush.opacity, 1.0);
      expect(brush.flow, 1.0);
      expect(brush.hardness, 1.0);
      expect(brush.spacing, 0.1);
      expect(brush.tipShape, BrushTipShape.round);
      expect(brush.pressureSize, isFalse);
      expect(brush.pressureOpacity, isFalse);
    });

    test('copyWith updates each field independently', () {
      final brush = BrushSettings();

      expect(brush.copyWith(color: 0xFFFFFFFF).color, 0xFFFFFFFF);
      expect(brush.copyWith(size: 8).size, 8);
      expect(brush.copyWith(opacity: 0.5).opacity, 0.5);
      expect(brush.copyWith(flow: 0.25).flow, 0.25);
      expect(brush.copyWith(hardness: 0.75).hardness, 0.75);
      expect(brush.copyWith(spacing: 0.2).spacing, 0.2);
      expect(
        brush.copyWith(tipShape: BrushTipShape.square).tipShape,
        BrushTipShape.square,
      );
      expect(brush.copyWith(pressureSize: true).pressureSize, isTrue);
      expect(brush.copyWith(pressureOpacity: true).pressureOpacity, isTrue);
      expect(brush, BrushSettings());
    });

    test('equality includes new fields', () {
      final brush = BrushSettings();

      expect(brush.copyWith(flow: 0.5), isNot(brush));
      expect(brush.copyWith(hardness: 0.5), isNot(brush));
      expect(brush.copyWith(spacing: 0.2), isNot(brush));
      expect(brush.copyWith(tipShape: BrushTipShape.square), isNot(brush));
      expect(brush.copyWith(pressureSize: true), isNot(brush));
      expect(brush.copyWith(pressureOpacity: true), isNot(brush));
    });

    test('toJson includes new fields', () {
      final json = BrushSettings().toJson();

      expect(
        json.keys,
        containsAll(<String>[
          'color',
          'size',
          'opacity',
          'flow',
          'hardness',
          'spacing',
          'tipShape',
          'pressureSize',
          'pressureOpacity',
        ]),
      );
    });

    test('fromJson round-trips new fields', () {
      final brush = BrushSettings(
        color: 0xFF123456,
        size: 12,
        opacity: 0.6,
        flow: 0.4,
        hardness: 0.8,
        spacing: 0.15,
        tipShape: BrushTipShape.square,
        pressureSize: true,
        pressureOpacity: true,
      );

      expect(BrushSettings.fromJson(brush.toJson()), brush);
    });

    test('fromJson supports legacy color/size/opacity JSON', () {
      final brush = BrushSettings.fromJson({
        'color': 0xFFFFFFFF,
        'size': 6,
        'opacity': 0.5,
      });

      expect(brush, BrushSettings(color: 0xFFFFFFFF, size: 6, opacity: 0.5));
      expect(brush.flow, 1.0);
      expect(brush.hardness, 1.0);
      expect(brush.spacing, 0.1);
      expect(brush.tipShape, BrushTipShape.round);
      expect(brush.pressureSize, isFalse);
      expect(brush.pressureOpacity, isFalse);
    });

    test('invalid size throws', () {
      expect(() => BrushSettings(size: 0), throwsArgumentError);
    });

    test('invalid opacity throws', () {
      expect(() => BrushSettings(opacity: -0.1), throwsArgumentError);
      expect(() => BrushSettings(opacity: 1.1), throwsArgumentError);
    });

    test('invalid flow throws', () {
      expect(() => BrushSettings(flow: -0.1), throwsArgumentError);
      expect(() => BrushSettings(flow: 1.1), throwsArgumentError);
    });

    test('invalid hardness throws', () {
      expect(() => BrushSettings(hardness: -0.1), throwsArgumentError);
      expect(() => BrushSettings(hardness: 1.1), throwsArgumentError);
    });

    test('invalid spacing throws', () {
      expect(() => BrushSettings(spacing: 0), throwsArgumentError);
    });
  });
}
