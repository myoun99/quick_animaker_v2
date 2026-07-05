import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_preset.dart';
import 'package:quick_animaker_v2/src/models/brush_preset_id.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
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

  testWidgets('BrushSettingsPanel applies, saves, and deletes presets', (
    tester,
  ) async {
    final calligraphy = BrushPreset(
      id: const BrushPresetId('preset-calligraphy'),
      name: 'Calligraphy',
      settings: BrushSettings(
        size: 14,
        hardness: 0.9,
        roundness: 0.3,
        angleDegrees: 45,
        pressureSize: true,
      ),
    );
    final marker = BrushPreset(
      id: const BrushPresetId('preset-marker'),
      name: 'Marker',
      settings: BrushSettings(size: 16, opacity: 0.7),
    );

    final applied = <BrushPreset>[];
    final deleted = <BrushPresetId>[];
    var saveRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BrushSettingsPanel(
              state: BrushToolState.defaults,
              onChanged: (_) {},
              presets: [calligraphy, marker],
              onPresetApplied: applied.add,
              onPresetSaveRequested: () => saveRequests += 1,
              onPresetDeleted: deleted.add,
            ),
          ),
        ),
      ),
    );

    // One chip per preset.
    expect(
      find.byKey(const ValueKey<String>('brush-preset-chip-preset-calligraphy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-chip-preset-marker')),
      findsOneWidget,
    );

    // Tapping a chip applies its preset.
    await tester.tap(find.text('Calligraphy'));
    await tester.pumpAndSettle();
    expect(applied.single, calligraphy);

    // The save affordance requests a preset save.
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-save-button')),
    );
    await tester.pumpAndSettle();
    expect(saveRequests, 1);

    // The chip's delete affordance reports the preset id.
    final markerChip = find.byKey(
      const ValueKey<String>('brush-preset-chip-preset-marker'),
    );
    await tester.tap(
      find.descendant(
        of: markerChip,
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(deleted.single, const BrushPresetId('preset-marker'));
  });

  testWidgets('BrushSettingsPanel hides the preset section when unused', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BrushSettingsPanel(
              state: BrushToolState.defaults,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Presets'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('brush-preset-save-button')),
      findsNothing,
    );
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
    expect(
      state.roundness,
      greaterThanOrEqualTo(BrushToolState.minRoundness),
    );

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
