import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_settings_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_dock.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_frame.dart';

void main() {
  testWidgets('EditorPanelFrame renders toolbar and body at small sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 80,
          child: EditorPanelFrame(
            title: 'Test Panel',
            trailing: Icon(Icons.tune, size: 16),
            child: Text('Body'),
          ),
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
    // The tab names the panel — the frame renders no title of its own.
    expect(find.text('Test Panel'), findsNothing);
    expect(find.text('Body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EditorPanelFrame without trailing controls skips the toolbar', (
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
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('editor-panel-body')),
      findsOneWidget,
    );
    expect(find.text('Body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right dock hosts the preset and settings panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPanelDock(
            children: [
              const BrushPresetPanel(presets: []),
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
    expect(
      find.byKey(const ValueKey<String>('editor-panel-frame-Brushes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('editor-panel-frame-Brush Settings')),
      findsOneWidget,
    );
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

    final blueSwatch = find.byKey(
      const ValueKey<String>('brush-tool-color-swatch-Blue'),
    );
    await tester.ensureVisible(blueSwatch);
    await tester.tap(blueSwatch);
    await tester.pumpAndSettle();
    expect(state.color, 0xFF1E88E5);
  });

  testWidgets('BrushSettingsPanel updates hardness flow and tip shape', (
    tester,
  ) async {
    var state = BrushToolState.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => BrushSettingsPanel(
                state: state,
                onChanged: (next) => setState(() => state = next),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-hardness-slider')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(state.hardness, lessThan(BrushToolState.defaultHardness));

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-flow-slider')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(state.flow, lessThan(BrushToolState.defaultFlow));

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('brush-tool-tip-shape-toggle')),
    );
    await tester.tap(find.text('Square'));
    await tester.pumpAndSettle();
    expect(state.tipShape, BrushTipShape.square);

    // The sampled input settings carry every tool option to the canvas.
    final inputSettings = state.toInputSettings();
    expect(inputSettings.hardness, state.hardness);
    expect(inputSettings.flow, state.flow);
    expect(inputSettings.tipShape, BrushTipShape.square);
  });

  testWidgets('BrushSettingsPanel updates tip roundness and angle', (
    tester,
  ) async {
    var state = BrushToolState.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => BrushSettingsPanel(
                state: state,
                onChanged: (next) => setState(() => state = next),
              ),
            ),
          ),
        ),
      ),
    );

    final roundnessSlider = find.byKey(
      const ValueKey<String>('brush-tool-roundness-slider'),
    );
    await tester.ensureVisible(roundnessSlider);
    await tester.drag(roundnessSlider, const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(state.roundness, lessThan(BrushToolState.defaultRoundness));
    expect(state.roundness, greaterThanOrEqualTo(BrushToolState.minRoundness));

    final angleSlider = find.byKey(
      const ValueKey<String>('brush-tool-angle-slider'),
    );
    await tester.ensureVisible(angleSlider);
    await tester.drag(angleSlider, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(state.angleDegrees, greaterThan(BrushToolState.defaultAngleDegrees));
    expect(state.angleDegrees, lessThanOrEqualTo(180.0));

    // Both reach the sampled canvas input settings.
    final inputSettings = state.toInputSettings();
    expect(inputSettings.roundness, state.roundness);
    expect(inputSettings.angleDegrees, state.angleDegrees);
  });

  testWidgets('BrushSettingsPanel toggles pen-pressure size and opacity', (
    tester,
  ) async {
    var state = BrushToolState.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => BrushSettingsPanel(
                state: state,
                onChanged: (next) => setState(() => state = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(state.pressureSize, isFalse);
    expect(state.pressureOpacity, isFalse);

    final sizeToggle = find.byKey(
      const ValueKey<String>('brush-tool-pressure-size-toggle'),
    );
    await tester.ensureVisible(sizeToggle);
    await tester.tap(sizeToggle);
    await tester.pumpAndSettle();
    expect(state.pressureSize, isTrue);
    expect(state.pressureOpacity, isFalse);

    final opacityToggle = find.byKey(
      const ValueKey<String>('brush-tool-pressure-opacity-toggle'),
    );
    await tester.ensureVisible(opacityToggle);
    await tester.tap(opacityToggle);
    await tester.pumpAndSettle();
    expect(state.pressureOpacity, isTrue);

    // Both toggles reach the sampled canvas input settings.
    final inputSettings = state.toInputSettings();
    expect(inputSettings.pressureSize, isTrue);
    expect(inputSettings.pressureOpacity, isTrue);
  });
}
