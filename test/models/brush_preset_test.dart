import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_preset.dart';
import 'package:quick_animaker_v2/src/models/brush_preset_id.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';

void main() {
  group('BrushPreset', () {
    final preset = BrushPreset(
      id: const BrushPresetId('preset-1'),
      name: 'Pencil',
      settings: BrushSettings(size: 4),
    );

    test('copyWith preserves unspecified fields', () {
      final renamed = preset.copyWith(name: 'Ink');

      expect(renamed.id, preset.id);
      expect(renamed.settings, preset.settings);
    });

    test('copyWith updates name', () {
      expect(preset.copyWith(name: 'Ink').name, 'Ink');
    });

    test('copyWith updates settings', () {
      final settings = BrushSettings(size: 12);

      expect(preset.copyWith(settings: settings).settings, settings);
    });

    test('toJson/fromJson round-trips', () {
      expect(BrushPreset.fromJson(preset.toJson()), preset);
    });

    test('equality includes id, name, and settings', () {
      expect(
        preset.copyWith(id: const BrushPresetId('preset-2')),
        isNot(preset),
      );
      expect(preset.copyWith(name: 'Ink'), isNot(preset));
      expect(preset.copyWith(settings: BrushSettings(size: 6)), isNot(preset));
    });

    test('duplicate preset names are allowed because BrushPresetId is identity', () {
      final duplicateName = BrushPreset(
        id: const BrushPresetId('preset-2'),
        name: preset.name,
        settings: preset.settings,
      );

      expect(duplicateName.name, preset.name);
      expect(duplicateName.id, isNot(preset.id));
      expect(duplicateName, isNot(preset));
    });
  });
}
