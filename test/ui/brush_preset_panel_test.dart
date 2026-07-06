import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_preset.dart';
import 'package:quick_animaker_v2/src/models/brush_preset_id.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_mask.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_stroke_preview.dart';

BrushPreset _calligraphy() {
  return BrushPreset(
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
}

BrushPreset _marker() {
  return BrushPreset(
    id: const BrushPresetId('preset-marker'),
    name: 'Marker',
    settings: BrushSettings(size: 16, opacity: 0.7),
  );
}

BrushPreset _sampled() {
  return BrushPreset(
    id: const BrushPresetId('preset-sampled'),
    name: 'Sampled',
    settings: BrushSettings(
      size: 20,
      tipMask: BrushTipMask(
        id: 'test-mask',
        size: 4,
        alpha: Uint8List.fromList(List<int>.filled(16, 200)),
      ),
    ),
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<BrushPreset> presets,
  BrushPresetId? selectedPresetId,
  ValueChanged<BrushPreset>? onPresetApplied,
  VoidCallback? onPresetSaveRequested,
  ValueChanged<BrushPresetId>? onPresetDeleted,
  VoidCallback? onPresetImportRequested,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          child: SingleChildScrollView(
            child: BrushPresetPanel(
              presets: presets,
              selectedPresetId: selectedPresetId,
              onPresetApplied: onPresetApplied,
              onPresetSaveRequested: onPresetSaveRequested,
              onPresetDeleted: onPresetDeleted,
              onPresetImportRequested: onPresetImportRequested,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders one row per preset with a stroke preview', (
    tester,
  ) async {
    await _pumpPanel(tester, presets: [_calligraphy(), _marker(), _sampled()]);

    expect(find.text('Brushes'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('brush-preset-chip-preset-calligraphy'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-chip-preset-marker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-chip-preset-sampled')),
      findsOneWidget,
    );
    expect(find.byType(BrushStrokePreview), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies, saves, and imports presets', (tester) async {
    final calligraphy = _calligraphy();
    final applied = <BrushPreset>[];
    var saveRequests = 0;
    var importRequests = 0;

    await _pumpPanel(
      tester,
      presets: [calligraphy, _marker()],
      onPresetApplied: applied.add,
      onPresetSaveRequested: () => saveRequests += 1,
      onPresetDeleted: (_) {},
      onPresetImportRequested: () => importRequests += 1,
    );

    // Tapping a row applies its preset.
    await tester.tap(find.text('Calligraphy'));
    await tester.pumpAndSettle();
    expect(applied.single, calligraphy);

    // The header save affordance requests a preset save.
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-save-button')),
    );
    await tester.pumpAndSettle();
    expect(saveRequests, 1);

    // The header import affordance requests a brush-file import.
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-import-button')),
    );
    await tester.pumpAndSettle();
    expect(importRequests, 1);
  });

  testWidgets('options menu deletes the selected preset', (tester) async {
    final deleted = <BrushPresetId>[];

    await _pumpPanel(
      tester,
      presets: [_calligraphy(), _marker()],
      selectedPresetId: const BrushPresetId('preset-marker'),
      onPresetDeleted: deleted.add,
    );

    // No per-row delete affordance (stray clicks cannot delete).
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete selected brush'));
    await tester.pumpAndSettle();

    expect(deleted.single, const BrushPresetId('preset-marker'));
  });

  testWidgets('options menu delete is disabled without a selection', (
    tester,
  ) async {
    final deleted = <BrushPresetId>[];

    await _pumpPanel(
      tester,
      presets: [_marker()],
      onPresetDeleted: deleted.add,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
    );
    await tester.pumpAndSettle();

    final item = tester.widget<PopupMenuItem<String>>(
      find.byKey(const ValueKey<String>('brush-preset-menu-delete')),
    );
    expect(item.enabled, isFalse);

    await tester.tap(find.text('Delete selected brush'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
  });

  testWidgets('highlights only the selected preset row', (tester) async {
    await _pumpPanel(
      tester,
      presets: [_calligraphy(), _marker()],
      selectedPresetId: const BrushPresetId('preset-marker'),
    );

    final selectedRow = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('brush-preset-chip-preset-marker'),
            ),
            matching: find.byType(Material),
          )
          .first,
    );
    final unselectedRow = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('brush-preset-chip-preset-calligraphy'),
            ),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(selectedRow.color, isNot(Colors.transparent));
    expect(unselectedRow.color, Colors.transparent);
  });

  testWidgets('shows a compact empty state without header actions', (
    tester,
  ) async {
    await _pumpPanel(tester, presets: const []);

    expect(find.text('Brushes'), findsOneWidget);
    expect(find.byType(BrushStrokePreview), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('brush-preset-save-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-import-button')),
      findsNothing,
    );
    expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
  });

  testWidgets('hides the options menu when deletion is not wired', (
    tester,
  ) async {
    await _pumpPanel(tester, presets: [_marker()]);

    expect(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
      findsNothing,
    );
  });
}
