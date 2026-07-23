import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'layer_timeline_display_adapter.dart';
import 'property_lane_model.dart';
import 'timeline_row_filter.dart';
import 'timeline_section_policy.dart';

/// The DISPLAYED-layer step target for the ↑/↓ layer nav (UI-R20 #14,
/// TVP-style): walks the rows exactly as the timeline stacks them — the
/// horizontal display order (camera section on top, drawing cels at the
/// bottom), with hidden sections, the row filter and folded attach
/// groups dropping layers here exactly like they drop rows there (an
/// open attach group walks, a folded one skips — #14's attach clause). A
/// filtered view navigates only what's on screen; on the X-sheet the
/// same walk reads right-to-left (its columns are the row stack
/// rotated).
///
/// [direction] -1 = the row visually ABOVE (screen-up = earlier in
/// horizontal display order, the moveSelectionToFilteredLayer rule).
/// Steps clamp at the ends. When the active layer itself isn't displayed
/// (its whole section is folded), the step enters the visible rows from
/// the matching end: ↓ lands on the top displayed row, ↑ on the bottom.
/// Null = no move.
LayerId? adjacentDisplayedLayerId({
  required List<Layer> layers,
  required LayerId? activeLayerId,
  required int direction,
  Set<TimelineSection> hiddenSections = const {},
  TimelineRowFilter rowFilter = TimelineRowFilter.none,
  Set<LayerId> collapsedAttachBaseIds = const {},
  bool Function(LayerId layerId)? fxEnabledOf,
}) {
  // Layer rows only — property lanes aren't selectable layers, so the nav
  // skips them no matter what's twirled open. R27 #27: a collapsed
  // folder's members are not on screen, so the walk must not stop on them
  // ("접혀져있으면 표시된거만 선택하는 룰") — the row builder already
  // drops them. FOLDER rows themselves are ordinary stops now: they are
  // layers, so the old "step OVER the header, it only carries a
  // representative member" special case is gone.
  final rows = buildTimelineDisplayRows(
    layers: horizontalLayerDisplayOrder(layers),
    expandedLayerIds: const {},
    lanesForLayer: (_) => const [],
    hiddenSections: hiddenSections,
    rowFilter: rowFilter,
    collapsedAttachBaseIds: collapsedAttachBaseIds,
    activeLayerId: activeLayerId,
    fxEnabledOf: fxEnabledOf,
    stack: layers,
  );
  if (rows.isEmpty || direction == 0) {
    return null;
  }
  var activeIndex = -1;
  for (var index = 0; index < rows.length; index += 1) {
    if (!rows[index].isLane && rows[index].layer.id == activeLayerId) {
      activeIndex = index;
      break;
    }
  }
  final layerRowIndexes = [
    for (var index = 0; index < rows.length; index += 1)
      if (!rows[index].isLane) index,
  ];
  if (layerRowIndexes.isEmpty) {
    return null;
  }
  final activeSlot = layerRowIndexes.indexOf(activeIndex);
  final int targetIndex;
  if (activeSlot == -1) {
    targetIndex = direction > 0
        ? layerRowIndexes.first
        : layerRowIndexes.last;
  } else {
    final slot = (activeSlot + direction).clamp(0, layerRowIndexes.length - 1);
    if (slot == activeSlot) {
      return null;
    }
    targetIndex = layerRowIndexes[slot];
  }
  final target = rows[targetIndex].layer.id;
  return target == activeLayerId ? null : target;
}

/// The imperative layer-nav channel (UI-R20 #14): the app-level ↑/↓
/// shortcuts call in from the dispatch; the workspace binds the handler
/// (it owns the row filter / hidden-section view state the walk needs).
/// Unbound calls are no-ops — the CanvasSelectionCommands idiom.
class TimelineLayerNavCommands {
  void Function(int direction)? _step;

  void bind(void Function(int direction) step) {
    _step = step;
  }

  void unbind() {
    _step = null;
  }

  /// Moves the active layer [direction] displayed rows (-1 = up).
  void step(int direction) => _step?.call(direction);
}
