import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';

void main() {
  group('BrushToolState', () {
    test(
      'default brush tool state maps to production brush input settings',
      () {
        const state = BrushToolState.defaults;

        expect(
          state.toInputSettings(),
          const BrushEditCanvasInputSettings(size: 10, spacing: 0.25),
        );
      },
    );

    test('public constructor always stores a clamped size', () {
      expect(BrushToolState(size: -10).size, BrushToolState.minSize);
      expect(BrushToolState(size: 10000).size, BrushToolState.maxSize);
      expect(BrushToolState(size: double.nan).size, BrushToolState.defaultSize);
      expect(
        BrushToolState(size: double.infinity).size,
        BrushToolState.defaultSize,
      );
    });

    test('public constructor always stores clamped opacity', () {
      expect(BrushToolState(opacity: -1).opacity, 0);
      expect(BrushToolState(opacity: 2).opacity, 1);
      expect(
        BrushToolState(opacity: double.nan).opacity,
        BrushToolState.defaultOpacity,
      );
    });

    test('clamped factory keeps size opacity and spacing in safe ranges', () {
      expect(BrushToolState.clamped(size: -10).size, BrushToolState.minSize);
      expect(BrushToolState.clamped(opacity: 2).opacity, 1);
      expect(
        BrushToolState.clamped(spacing: -1).spacing,
        BrushToolState.minSpacing,
      );
      expect(
        BrushToolState.clamped(spacing: 100).spacing,
        BrushToolState.maxSpacing,
      );
    });

    test('public constructor and copyWith clamp spacing', () {
      expect(BrushToolState().spacing, BrushToolState.defaultSpacing);
      expect(BrushToolState(spacing: -1).spacing, BrushToolState.minSpacing);
      expect(BrushToolState(spacing: 100).spacing, BrushToolState.maxSpacing);
      expect(
        BrushToolState(spacing: double.nan).spacing,
        BrushToolState.defaultSpacing,
      );
      expect(
        BrushToolState(spacing: double.infinity).spacing,
        BrushToolState.defaultSpacing,
      );

      expect(
        BrushToolState.defaults.copyWith(spacing: 100).spacing,
        BrushToolState.maxSpacing,
      );
      expect(
        BrushToolState.defaults.copyWith(spacing: double.nan).spacing,
        BrushToolState.defaultSpacing,
      );
      expect(BrushToolState(spacing: 0.75).toInputSettings().spacing, 0.75);
    });

    test('color updates remain stable', () {
      const color = 0xFF123456;
      final state = BrushToolState(color: color);

      expect(state.color, color);
      expect(state.toInputSettings().color, color);
    });

    test('pressure toggles default off and preserve prior behavior', () {
      const state = BrushToolState.defaults;
      expect(state.pressureSize, isFalse);
      expect(state.pressureOpacity, isFalse);
      expect(state.toInputSettings().pressureSize, isFalse);
      expect(state.toInputSettings().pressureOpacity, isFalse);
    });

    test('pressure toggles round-trip through copyWith and input settings', () {
      final state = BrushToolState.defaults.copyWith(
        pressureSize: true,
        pressureOpacity: true,
      );
      expect(state.pressureSize, isTrue);
      expect(state.pressureOpacity, isTrue);

      final settings = state.toInputSettings();
      expect(settings.pressureSize, isTrue);
      expect(settings.pressureOpacity, isTrue);

      // Omitted copyWith args keep the existing toggle values.
      expect(state.copyWith(size: 5).pressureSize, isTrue);
      expect(state.copyWith(size: 5).pressureOpacity, isTrue);
    });

    test('pressure toggles participate in equality', () {
      final a = BrushToolState.defaults.copyWith(pressureSize: true);
      final b = BrushToolState.defaults.copyWith(pressureSize: true);
      const c = BrushToolState.defaults;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('roundness and angle default to the classic full-round tip', () {
      const state = BrushToolState.defaults;
      expect(state.roundness, 1.0);
      expect(state.angleDegrees, 0.0);
      expect(state.toInputSettings().roundness, 1.0);
      expect(state.toInputSettings().angleDegrees, 0.0);
    });

    test('roundness and angle are clamped and round-trip', () {
      expect(
        BrushToolState(roundness: 0.0).roundness,
        BrushToolState.minRoundness,
      );
      expect(BrushToolState(roundness: 2.0).roundness, 1.0);
      expect(
        BrushToolState(roundness: double.nan).roundness,
        BrushToolState.defaultRoundness,
      );
      expect(BrushToolState(angleDegrees: -10).angleDegrees, 0.0);
      expect(BrushToolState(angleDegrees: 361).angleDegrees, 180.0);
      expect(
        BrushToolState(angleDegrees: double.nan).angleDegrees,
        BrushToolState.defaultAngleDegrees,
      );

      final state = BrushToolState.defaults.copyWith(
        roundness: 0.4,
        angleDegrees: 45,
      );
      expect(state.roundness, 0.4);
      expect(state.angleDegrees, 45.0);
      final settings = state.toInputSettings();
      expect(settings.roundness, 0.4);
      expect(settings.angleDegrees, 45.0);
      // Omitted copyWith args keep the existing values.
      expect(state.copyWith(size: 5).roundness, 0.4);
      expect(state.copyWith(size: 5).angleDegrees, 45.0);
    });
  });
}
