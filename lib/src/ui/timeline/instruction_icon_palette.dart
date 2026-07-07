import 'package:flutter/material.dart';

/// The curated icon palette instruction definitions pick from. The model
/// stores symbolic keys ([instructionIconFor] resolves them) so project
/// files stay open-able even when a key is unknown — it falls back to the
/// generic label glyph instead of failing.
const Map<String, IconData> instructionIconPalette = {
  // Camera work.
  'fix': Icons.crop_free,
  'pan': Icons.arrow_right_alt,
  'pan-up': Icons.arrow_upward,
  'pan-down': Icons.arrow_downward,
  'slide': Icons.swap_horiz,
  'follow': Icons.directions_run,
  'track-up': Icons.zoom_in,
  'track-back': Icons.zoom_out,
  // Transitions.
  'fade-in': Icons.visibility,
  'fade-out': Icons.visibility_off,
  'white-in': Icons.wb_sunny_outlined,
  'white-out': Icons.wb_sunny,
  'overlap': Icons.compare,
  'wipe': Icons.swipe,
  // Filter effects.
  'super-impose': Icons.layers,
  'diffusion': Icons.blur_on,
  'fog': Icons.cloud,
  // Extras for custom instructions.
  'shake': Icons.vibration,
  'light': Icons.flare,
  'flash': Icons.flash_on,
  'focus': Icons.center_focus_strong,
  'rotate': Icons.rotate_right,
  'speed': Icons.speed,
  'star': Icons.star_outline,
  'note': Icons.sticky_note_2_outlined,
};

const IconData instructionFallbackIcon = Icons.label_outline;

IconData instructionIconFor(String iconKey) {
  return instructionIconPalette[iconKey] ?? instructionFallbackIcon;
}
