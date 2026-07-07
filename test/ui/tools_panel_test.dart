import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/brush/tools_panel.dart';

Widget _panel({
  CanvasTool tool = CanvasTool.brush,
  ValueChanged<CanvasTool>? onToolChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ToolsPanel(tool: tool, onToolChanged: onToolChanged ?? (_) {}),
    ),
  );
}

void main() {
  group('ToolsPanel', () {
    testWidgets('exposes brush and eraser buttons with tooltips', (
      tester,
    ) async {
      await tester.pumpWidget(_panel());

      expect(
        find.byKey(const ValueKey<String>('tool-brush-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tool-eraser-button')),
        findsOneWidget,
      );
      expect(find.byTooltip('Brush Tool'), findsOneWidget);
      expect(find.byTooltip('Eraser Tool'), findsOneWidget);
    });

    testWidgets('tapping the eraser reports the tool change', (tester) async {
      CanvasTool? selected;
      await tester.pumpWidget(_panel(onToolChanged: (tool) => selected = tool));

      await tester.tap(
        find.byKey(const ValueKey<String>('tool-eraser-button')),
      );

      expect(selected, CanvasTool.eraser);
    });

    testWidgets('tapping the brush reports the tool change', (tester) async {
      CanvasTool? selected;
      await tester.pumpWidget(
        _panel(
          tool: CanvasTool.eraser,
          onToolChanged: (tool) => selected = tool,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('tool-brush-button')));

      expect(selected, CanvasTool.brush);
    });

    testWidgets('marks the active tool as selected', (tester) async {
      await tester.pumpWidget(_panel(tool: CanvasTool.eraser));

      final eraser = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('tool-eraser-button')),
      );
      final brush = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('tool-brush-button')),
      );
      expect(eraser.isSelected, isTrue);
      expect(brush.isSelected, isFalse);
    });
  });
}
