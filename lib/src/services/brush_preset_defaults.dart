import '../models/brush_preset.dart';
import '../models/brush_preset_id.dart';
import '../models/brush_settings.dart';
import 'brush_tip_mask_defaults.dart';

/// Built-in brush presets seeded when no user preset library exists yet.
///
/// These are starting points showcasing the engine's dynamics (pressure,
/// hardness, tip roundness/angle), not a curated professional set. Users can
/// delete or extend them; the library file then persists their choice.
final List<BrushPreset> defaultBrushPresets = List.unmodifiable(<BrushPreset>[
  BrushPreset(
    id: const BrushPresetId('builtin-pencil'),
    name: 'Pencil',
    settings: BrushSettings(
      size: 4,
      hardness: 1.0,
      spacing: 0.15,
      pressureSize: true,
    ),
  ),
  BrushPreset(
    id: const BrushPresetId('builtin-ink-pen'),
    name: 'Ink Pen',
    settings: BrushSettings(
      size: 8,
      hardness: 1.0,
      spacing: 0.1,
      pressureSize: true,
    ),
  ),
  BrushPreset(
    id: const BrushPresetId('builtin-soft-brush'),
    name: 'Soft Brush',
    settings: BrushSettings(
      size: 24,
      hardness: 0.25,
      flow: 0.7,
      spacing: 0.1,
      pressureOpacity: true,
    ),
  ),
  BrushPreset(
    id: const BrushPresetId('builtin-calligraphy'),
    name: 'Calligraphy',
    settings: BrushSettings(
      size: 14,
      hardness: 0.9,
      spacing: 0.1,
      roundness: 0.3,
      angleDegrees: 45,
      pressureSize: true,
    ),
  ),
  BrushPreset(
    id: const BrushPresetId('builtin-marker'),
    name: 'Marker',
    settings: BrushSettings(
      size: 16,
      hardness: 0.8,
      opacity: 0.7,
      flow: 0.6,
      spacing: 0.1,
    ),
  ),
  BrushPreset(
    id: const BrushPresetId('builtin-chalk-preset'),
    name: 'Chalk',
    settings: BrushSettings(
      size: 20,
      flow: 0.85,
      spacing: 0.2,
      tipMask: chalkBrushTipMask,
      pressureSize: true,
    ),
  ),
  BrushPreset(
    id: const BrushPresetId('builtin-splatter-preset'),
    name: 'Splatter',
    settings: BrushSettings(
      size: 28,
      spacing: 0.9,
      tipMask: splatterBrushTipMask,
    ),
  ),
]);
