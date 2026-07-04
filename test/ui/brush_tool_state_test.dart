import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';

void main() {
  group('BrushToolState', () {
    test('default brush tool state maps to production brush input settings', () {
      const state = BrushToolState();

      expect(
        state.toInputSettings(),
        const BrushEditCanvasInputSettings(size: 10),
      );
    });

    test('size is clamped to a safe finite range', () {
      expect(BrushToolState.clamped(size: -10).size, BrushToolState.minSize);
      expect(BrushToolState.clamped(size: 10000).size, BrushToolState.maxSize);
      expect(
        BrushToolState.clamped(size: double.nan).size,
        BrushToolState.defaultSize,
      );
      expect(
        BrushToolState.clamped(size: double.infinity).size,
        BrushToolState.defaultSize,
      );
    });

    test('opacity is clamped to 0.0 through 1.0', () {
      expect(BrushToolState.clamped(opacity: -1).opacity, 0);
      expect(BrushToolState.clamped(opacity: 2).opacity, 1);
      expect(
        BrushToolState.clamped(opacity: double.nan).opacity,
        BrushToolState.defaultOpacity,
      );
    });

    test('color updates remain stable', () {
      const color = 0xFF123456;
      final state = BrushToolState.clamped(color: color);

      expect(state.color, color);
      expect(state.toInputSettings().color, color);
    });
  });
}
