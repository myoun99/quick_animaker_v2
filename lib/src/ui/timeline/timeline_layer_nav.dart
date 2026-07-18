import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'layer_timeline_display_adapter.dart';
import 'property_lane_model.dart';
import 'timeline_row_filter.dart';
import 'timeline_section_policy.dart';

/// The DISPLAYED-layer step target for the ↑/↓ layer nav (UI-R20 #14,
/// TVP-style): walks the rows exactly as the timeline stacks them — the
/// horizontal display order (camera section on top, drawing cels at the
/// bottom), with hidden sections and the row filter dropping layers here
/// exactly like they drop rows there. A filtered view navigates only
/// what's on screen; on the X-sheet the same walk reads right-to-left
/// (its columns are the row stack rotated).
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
  bool Function(LayerId layerId)? fxEnabledOf,
}) {
  // Layer rows only — property lanes aren't selectable layers, so the nav
  // skips them no matter what's twirled open.
  final rows = buildTimelineDisplayRows(
    layers: horizontalLayerDisplayOrder(layers),
    expandedLayerIds: const {},
    lanesForLayer: (_) => const [],
    hiddenSections: hiddenSections,
    rowFilter: rowFilter,
    activeLayerId: activeLayerId,
    fxEnabledOf: fxEnabledOf,
  );
  if (rows.isEmpty || direction == 0) {
    return null;
  }
  var activeIndex = -1;
  for (var index = 0; index < rows.length; index += 1) {
    if (rows[index].layer.id == activeLayerId) {
      activeIndex = index;
      break;
    }
  }
  final int targetIndex;
  if (activeIndex == -1) {
    targetIndex = direction > 0 ? 0 : rows.length - 1;
  } else {
    targetIndex = (activeIndex + direction).clamp(0, rows.length - 1);
    if (targetIndex == activeIndex) {
      return null;
    }
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
