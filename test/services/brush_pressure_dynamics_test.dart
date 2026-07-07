import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/services/brush_pressure_dynamics.dart';

BrushDab _dab({double size = 10, double opacity = 0.8, double pressure = 0.5}) {
  return BrushDab(
    center: CanvasPoint(x: 1, y: 1),
    color: 0xFF000000,
    size: size,
    opacity: opacity,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: pressure,
    sequence: 0,
  );
}

void main() {
  group('applyBrushPressureDynamics', () {
    test('returns the same instance when neither toggle is on', () {
      final dab = _dab();
      final result = applyBrushPressureDynamics(
        dab,
        pressureSize: false,
        pressureOpacity: false,
      );
      expect(identical(result, dab), isTrue);
    });

    test('scales size only when pressureSize is on', () {
      final result = applyBrushPressureDynamics(
        _dab(size: 10, opacity: 0.8, pressure: 0.5),
        pressureSize: true,
        pressureOpacity: false,
      );
      expect(result.size, 5.0);
      expect(result.opacity, 0.8);
    });

    test('scales opacity only when pressureOpacity is on', () {
      final result = applyBrushPressureDynamics(
        _dab(size: 10, opacity: 0.8, pressure: 0.5),
        pressureSize: false,
        pressureOpacity: true,
      );
      expect(result.size, 10.0);
      expect(result.opacity, closeTo(0.4, 1e-9));
    });

    test('scales both channels when both toggles are on', () {
      final result = applyBrushPressureDynamics(
        _dab(size: 20, opacity: 0.6, pressure: 0.25),
        pressureSize: true,
        pressureOpacity: true,
      );
      expect(result.size, 5.0);
      expect(result.opacity, closeTo(0.15, 1e-9));
    });

    test('full pressure is a no-op on values', () {
      final result = applyBrushPressureDynamics(
        _dab(size: 12, opacity: 1.0, pressure: 1.0),
        pressureSize: true,
        pressureOpacity: true,
      );
      expect(result.size, 12.0);
      expect(result.opacity, 1.0);
    });

    test('preserves the pressure field so downstream interpolation works', () {
      final result = applyBrushPressureDynamics(
        _dab(pressure: 0.3),
        pressureSize: true,
        pressureOpacity: true,
      );
      expect(result.pressure, 0.3);
    });
  });
}
