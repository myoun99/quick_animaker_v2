import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';

/// Moves [movedId] to [targetGroup], inserting before [insertBeforeId]
/// (which must already sit in [targetGroup]) or appending after the group's
/// last member when no anchor is given. A `null` [targetGroup] is the
/// default (ungrouped) section.
///
/// Pure list computation shared by the panel's drag-reorder handler so the
/// group-membership rules stay testable without widget drags. Returns the
/// original list when [movedId] is absent.
List<BrushPreset> moveBrushPresetInLibrary({
  required List<BrushPreset> presets,
  required BrushPresetId movedId,
  required String? targetGroup,
  BrushPresetId? insertBeforeId,
}) {
  final movedIndex = presets.indexWhere((preset) => preset.id == movedId);
  if (movedIndex < 0) {
    return presets;
  }

  final moved = presets[movedIndex].copyWith(group: targetGroup);
  final remaining = [
    for (final preset in presets)
      if (preset.id != movedId) preset,
  ];

  int insertIndex;
  if (insertBeforeId != null) {
    insertIndex = remaining.indexWhere((preset) => preset.id == insertBeforeId);
    if (insertIndex < 0) {
      insertIndex = remaining.length;
    }
  } else {
    final lastInGroup = remaining.lastIndexWhere(
      (preset) => preset.group == targetGroup,
    );
    insertIndex = lastInGroup >= 0 ? lastInGroup + 1 : remaining.length;
  }

  return List<BrushPreset>.unmodifiable([
    ...remaining.take(insertIndex),
    moved,
    ...remaining.skip(insertIndex),
  ]);
}
