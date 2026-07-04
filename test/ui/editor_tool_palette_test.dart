import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/tools/editor_tool_mode.dart';
import 'package:quick_animaker_v2/src/ui/tools/editor_tool_palette.dart';

void main() {
  testWidgets('left tool palette renders Brush and Eraser buttons', (
    tester,
  ) async {
    var selected = EditorToolMode.brush;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => EditorToolPalette(
            selectedToolMode: selected,
            onToolModeSelected: (mode) => setState(() => selected = mode),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('editor-tool-palette')),
      findsOneWidget,
    );
    expect(find.byTooltip('Brush'), findsOneWidget);
    expect(find.byTooltip('Eraser'), findsOneWidget);
    expect(find.textContaining('tutorial', findRichText: true), findsNothing);
    expect(find.textContaining('debug', findRichText: true), findsNothing);

    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    expect(selected, EditorToolMode.eraser);

    await tester.tap(find.byTooltip('Brush'));
    await tester.pump();
    expect(selected, EditorToolMode.brush);
  });
}
