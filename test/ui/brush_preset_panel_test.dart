import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_preset.dart';
import 'package:quick_animaker_v2/src/models/brush_preset_id.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_mask.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_stroke_preview.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tip_preview.dart';

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
  void Function(BrushPresetId id, String name)? onPresetRenamed,
  ValueChanged<List<BrushPreset>>? onPresetsReordered,
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
              onPresetRenamed: onPresetRenamed,
              onPresetsReordered: onPresetsReordered,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders icon, stroke preview, and name for every preset', (
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
    expect(find.byType(BrushTipPreview), findsNWidgets(3));
    expect(find.byType(BrushStrokePreview), findsNWidgets(3));
    expect(find.text('Marker'), findsOneWidget);
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

    final item = tester.widget<PopupMenuItem<Object?>>(
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

  testWidgets('omits the delete item when deletion is not wired', (
    tester,
  ) async {
    await _pumpPanel(tester, presets: [_marker()]);

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('brush-preset-view-stroke-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-menu-delete')),
      findsNothing,
    );
  });

  testWidgets('view toggles hide the icon, stroke preview, and name', (
    tester,
  ) async {
    Future<void> toggle(String keyValue) async {
      await tester.tap(
        find.byKey(const ValueKey<String>('brush-preset-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey<String>(keyValue)));
      await tester.pumpAndSettle();
    }

    await _pumpPanel(tester, presets: [_marker()]);
    expect(find.byType(BrushTipPreview), findsOneWidget);
    expect(find.byType(BrushStrokePreview), findsOneWidget);
    expect(find.text('Marker'), findsOneWidget);

    await toggle('brush-preset-view-icon-toggle');
    expect(find.byType(BrushTipPreview), findsNothing);
    expect(find.byType(BrushStrokePreview), findsOneWidget);

    await toggle('brush-preset-view-stroke-toggle');
    expect(find.byType(BrushStrokePreview), findsNothing);
    // The name falls back to a plain row label when the stroke is hidden.
    expect(find.text('Marker'), findsOneWidget);

    await toggle('brush-preset-view-icon-toggle');
    await toggle('brush-preset-view-name-toggle');
    expect(find.text('Marker'), findsNothing);
    expect(find.byType(BrushTipPreview), findsOneWidget);
  });

  testWidgets('groups presets under collapsible source-file headers', (
    tester,
  ) async {
    final applied = <BrushPreset>[];
    final watercolor = _calligraphy().copyWith(
      id: const BrushPresetId('preset-wet'),
      name: 'Wet wash',
      group: '불투명 수채',
    );
    await _pumpPanel(
      tester,
      presets: [
        _marker(), // ungrouped -> Default
        watercolor,
        _sampled().copyWith(group: '불투명 수채'),
      ],
      onPresetApplied: applied.add,
    );

    // Headers appear in first-appearance order.
    expect(
      find.byKey(const ValueKey<String>('brush-preset-group-Default')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-group-불투명 수채')),
      findsOneWidget,
    );
    expect(find.byType(BrushStrokePreview), findsNWidgets(3));

    // Rows inside a collapsed group disappear; others stay.
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-group-불투명 수채')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('brush-preset-chip-preset-wet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-preset-chip-preset-marker')),
      findsOneWidget,
    );

    // Expanding restores the rows and they stay tappable.
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-group-불투명 수채')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wet wash'));
    await tester.pumpAndSettle();
    expect(applied.single, watercolor);
  });

  testWidgets('options menu renames the selected preset', (tester) async {
    final renames = <(BrushPresetId, String)>[];
    await _pumpPanel(
      tester,
      presets: [_calligraphy(), _marker()],
      selectedPresetId: const BrushPresetId('preset-marker'),
      onPresetRenamed: (id, name) => renames.add((id, name)),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename selected brush'));
    await tester.pumpAndSettle();

    final field = find.byKey(
      const ValueKey<String>('brush-preset-rename-text-field'),
    );
    expect(tester.widget<TextField>(field).controller!.text, 'Marker');

    // An empty name keeps the dialog open with an error.
    await tester.enterText(field, '   ');
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-rename-ok-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('brush-preset-rename-dialog')),
      findsOneWidget,
    );
    expect(renames, isEmpty);

    await tester.enterText(field, 'Wet wash');
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-rename-ok-button')),
    );
    await tester.pumpAndSettle();

    expect(renames.single, (const BrushPresetId('preset-marker'), 'Wet wash'));
    expect(
      find.byKey(const ValueKey<String>('brush-preset-rename-dialog')),
      findsNothing,
    );
  });

  testWidgets('rename is disabled without a selection', (tester) async {
    await _pumpPanel(tester, presets: [_marker()], onPresetRenamed: (_, _) {});

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
    );
    await tester.pumpAndSettle();

    final item = tester.widget<PopupMenuItem<Object?>>(
      find.byKey(const ValueKey<String>('brush-preset-menu-rename')),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('dragging a row reorders the library', (tester) async {
    final reordered = <List<BrushPreset>>[];
    final calligraphy = _calligraphy();
    final marker = _marker();
    final sampled = _sampled();
    await _pumpPanel(
      tester,
      presets: [calligraphy, marker, sampled],
      onPresetsReordered: reordered.add,
    );

    // Drag the first row down past the second (rows are 36px tall).
    await tester.drag(
      find.byKey(
        const ValueKey<String>('brush-preset-entry-preset-calligraphy'),
      ),
      const Offset(0, 44),
    );
    await tester.pumpAndSettle();

    expect(reordered, isNotEmpty);
    expect(reordered.last.map((preset) => preset.id.value), [
      'preset-marker',
      'preset-calligraphy',
      'preset-sampled',
    ]);
  });

  testWidgets('shows no group headers when every preset is ungrouped', (
    tester,
  ) async {
    await _pumpPanel(tester, presets: [_calligraphy(), _marker()]);

    expect(
      find.byKey(const ValueKey<String>('brush-preset-group-Default')),
      findsNothing,
    );
    expect(find.byType(BrushStrokePreview), findsNWidgets(2));
  });

  testWidgets('the last visible element cannot be hidden', (tester) async {
    Future<void> toggle(String keyValue) async {
      await tester.tap(
        find.byKey(const ValueKey<String>('brush-preset-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>(keyValue)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    await _pumpPanel(tester, presets: [_marker()]);
    await toggle('brush-preset-view-icon-toggle');
    await toggle('brush-preset-view-name-toggle');

    // Only the stroke preview is left; its toggle must be disabled.
    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-menu-button')),
    );
    await tester.pumpAndSettle();
    final strokeToggle = tester.widget<CheckedPopupMenuItem<Object?>>(
      find.byKey(const ValueKey<String>('brush-preset-view-stroke-toggle')),
    );
    expect(strokeToggle.enabled, isFalse);

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-preset-view-stroke-toggle')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BrushStrokePreview), findsOneWidget);
  });
}
