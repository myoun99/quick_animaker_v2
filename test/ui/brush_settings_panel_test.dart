import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_settings_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_dock.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_frame.dart';

void main() {
  testWidgets('EditorPanelFrame renders header and body at small sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 80,
          child: EditorPanelFrame(title: 'Test Panel', child: Text('Body')),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('editor-panel-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('editor-panel-body')),
      findsOneWidget,
    );
    expect(find.text('Test Panel'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right dock can host BrushSettingsPanel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPanelDock(
            children: [
              BrushSettingsPanel(
                state: BrushToolState.defaults,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('editor-panel-dock-right')),
      findsOneWidget,
    );
    expect(find.text('Brush Settings'), findsOneWidget);
  });

  testWidgets('BrushSettingsPanel updates size opacity color and spacing', (
    tester,
  ) async {
    var state = BrushToolState.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BrushSettingsPanel(
              state: state,
              onChanged: (next) => setState(() => state = next),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-size-slider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(state.size, greaterThan(BrushToolState.defaultSize));

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-opacity-slider')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(state.opacity, lessThan(BrushToolState.defaultOpacity));

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-spacing-slider')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();
    expect(state.spacing, greaterThan(BrushToolState.defaultSpacing));

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-tool-color-swatch-Blue')),
    );
    await tester.pumpAndSettle();
    expect(state.color, 0xFF1E88E5);
  });
}
