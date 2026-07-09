import 'dart:ui' show Offset;

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'timeline_section_policy.dart';

/// One property lane under a layer: a NAMED keyed property rendered as its
/// own timeline row. Deliberately generic — transform lanes (Position/
/// Scale/Rotation…) today, layer-FX property lanes on the same base soon.
class PropertyLaneRow {
  const PropertyLaneRow({
    required this.laneId,
    required this.label,
    required this.keyedFrames,
    this.holdOutFrames = const {},
    this.valueLabel,
    this.scrubValue,
    this.showsKeyNavigator = true,
    this.isGroupHeader = false,
  });

  /// Stable id within the owning layer (e.g. 'position', an FX param id).
  final String laneId;

  /// Display name (AE naming for transform lanes).
  final String label;

  /// Frames carrying a key on this property.
  final Set<int> keyedFrames;

  /// Keys whose OUT interpolation is HOLD (drawn as squares, AE-style).
  final Set<int> holdOutFrames;

  /// The property's display value at a frame (AE's blue value column —
  /// already unit-formatted); null hides the value.
  final String Function(int frameIndex)? valueLabel;

  /// AE-style value scrubbing: maps the drag's total delta onto
  /// [currentLabel] and returns the scrubbed value in the SAME text form
  /// the value editor parses (the release commits it through onSetValue).
  /// Generic like [valueLabel] — each lane provider decides which drag axis
  /// drives which component. Null (or a null return) disables scrubbing.
  final String? Function(String currentLabel, Offset dragDelta)? scrubValue;

  /// Whether the label cell shows the keyframe navigator (◀ ◆ ▶). Lanes
  /// without key semantics (the SE audio lane) hide it.
  final bool showsKeyNavigator;

  /// AE-style GROUP HEADER row ('Transform', later 'Effects'): a structural
  /// label leading its member lanes — no keys, no value, no navigator; the
  /// frame band stays a quiet strip.
  final bool isGroupHeader;
}

/// One display row of the timeline grids: a layer row or one of its
/// expanded property lanes. Both orientations build their rows from this
/// shared policy (Axis rule: never fork per orientation).
class TimelineDisplayRow {
  const TimelineDisplayRow.layer(this.layer, {required this.layerIndex})
    : lane = null;

  const TimelineDisplayRow.lane(
    this.layer,
    PropertyLaneRow this.lane, {
    required this.layerIndex,
  });

  /// The owning layer (lane rows carry their layer too).
  final Layer layer;

  /// The layer's index in the DISPLAY layer list — section dividers keep
  /// keying off layer positions, not row positions.
  final int layerIndex;

  final PropertyLaneRow? lane;

  bool get isLane => lane != null;
}

/// Lane key edit hooks — layer-generic on purpose: the camera routes them
/// into its transform track today, and every layer (and FX property) plugs
/// into the same signatures with the layer-transform work.
class PropertyLaneEditCallbacks {
  const PropertyLaneEditCallbacks({
    required this.onToggleKeyAt,
    required this.onMoveKey,
    required this.onRemoveKey,
    required this.onToggleHold,
    this.onSetValue,
  });

  /// Adds a key (freezing the property's current value, AE-style) or
  /// removes the existing one — the keyframe navigator's diamond.
  final void Function(Layer layer, PropertyLaneRow lane, int frameIndex)
  onToggleKeyAt;

  /// A key marker dragged to another frame.
  final void Function(
    Layer layer,
    PropertyLaneRow lane,
    int fromFrame,
    int toFrame,
  )
  onMoveKey;

  final void Function(Layer layer, PropertyLaneRow lane, int frameIndex)
  onRemoveKey;

  /// AE's Toggle Hold Keyframe.
  final void Function(Layer layer, PropertyLaneRow lane, int frameIndex)
  onToggleHold;

  /// A value typed into the lane's value editor: sets/updates a key at the
  /// frame (AE: changing an animated value keys it at the playhead). The
  /// raw input is parsed by the property's own policy; invalid input is
  /// ignored. Null hides the editor.
  final void Function(
    Layer layer,
    PropertyLaneRow lane,
    int frameIndex,
    String input,
  )?
  onSetValue;
}

/// Builds the grid's display rows: every layer row, plus the property lane
/// rows of layers whose twirl-down is expanded. Sections listed in
/// [hiddenSections] contribute NO rows at all (the toolbar's SE/CAMERA
/// visibility toggles — the layers themselves are untouched); both
/// orientations consume the same policy (Axis rule).
List<TimelineDisplayRow> buildTimelineDisplayRows({
  required List<Layer> layers,
  required Set<LayerId> expandedLayerIds,
  required List<PropertyLaneRow> Function(Layer layer) lanesForLayer,
  Set<TimelineSection> hiddenSections = const {},
}) {
  final rows = <TimelineDisplayRow>[];
  for (var index = 0; index < layers.length; index += 1) {
    final layer = layers[index];
    if (hiddenSections.contains(timelineSectionForLayerKind(layer.kind))) {
      continue;
    }
    rows.add(TimelineDisplayRow.layer(layer, layerIndex: index));
    if (!expandedLayerIds.contains(layer.id)) {
      continue;
    }
    for (final lane in lanesForLayer(layer)) {
      rows.add(TimelineDisplayRow.lane(layer, lane, layerIndex: index));
    }
  }
  return List.unmodifiable(rows);
}
