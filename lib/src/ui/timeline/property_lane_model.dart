import 'dart:ui' show Offset;

import '../../models/folder_id.dart';
import '../../models/layer.dart';
import '../../models/layer_folder.dart';
import '../../models/layer_id.dart';
import 'timeline_row_filter.dart';
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
    this.groupExpanded = false,
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

  /// Group headers only: whether the group's member lanes are twirled open
  /// (AE-style header collapse — drives the header's chevron; default
  /// collapsed).
  final bool groupExpanded;
}

/// One display row of the timeline grids: a layer row or one of its
/// expanded property lanes. Both orientations build their rows from this
/// shared policy (Axis rule: never fork per orientation).
class TimelineDisplayRow {
  const TimelineDisplayRow.layer(
    this.layer, {
    required this.layerIndex,
    this.depth = 0,
  }) : lane = null,
       folder = null,
       aggregateRuns = const [];

  const TimelineDisplayRow.lane(
    this.layer,
    PropertyLaneRow this.lane, {
    required this.layerIndex,
  }) : folder = null,
       depth = 0,
       aggregateRuns = const [];

  /// A folder HEADER row (L5): sits above its first member; its frame band
  /// renders the aggregate block (member exposure union — pure display).
  /// [layer] carries the first member as a representative so every
  /// row consumer (virtualization, memo keys) keeps a real layer.
  const TimelineDisplayRow.folder(
    this.layer,
    LayerFolder this.folder, {
    required this.layerIndex,
    this.depth = 0,
    this.aggregateRuns = const [],
  }) : lane = null;

  /// The owning layer (lane and folder rows carry a layer too — for
  /// folder rows it is the first member, a representative only).
  final Layer layer;

  /// The layer's index in the DISPLAY layer list — section dividers keep
  /// keying off layer positions, not row positions.
  final int layerIndex;

  final PropertyLaneRow? lane;

  /// Set on folder header rows only.
  final LayerFolder? folder;

  /// Folder header rows only: the SUBTREE members' exposure union as
  /// merged display runs (the TVP-latest aggregate block — nameless,
  /// no comma edits, no moves; holds included through exposure lengths).
  final List<({int start, int endExclusive})> aggregateRuns;

  /// Folder nesting depth (0 = top level) — drives the rail indent for
  /// both folder headers and member layer rows.
  final int depth;

  bool get isLane => lane != null;

  bool get isFolder => folder != null;
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
///
/// [rowFilter] additionally hides individual layer rows failing its
/// predicate (R2 row filter, a VIEW state); [activeLayerId] is exempt so a
/// filter can never hide the layer you're editing. [fxEnabledOf] resolves
/// the session-level fx state the filter's fx-only facet reads.
///
/// The folder header row's aggregate band (L5, the TVP-latest display):
/// the UNION of the subtree members' exposure intervals merged into runs.
/// Pure display — nameless, no comma edits, no moves.
List<({int start, int endExclusive})> folderAggregateRuns(
  Iterable<Layer> members,
) {
  final intervals = <({int start, int endExclusive})>[
    for (final member in members)
      for (final entry in member.timeline.entries)
        if (entry.value.length != null)
          (start: entry.key, endExclusive: entry.key + entry.value.length!),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final runs = <({int start, int endExclusive})>[];
  for (final interval in intervals) {
    if (runs.isNotEmpty && interval.start <= runs.last.endExclusive) {
      if (interval.endExclusive > runs.last.endExclusive) {
        runs[runs.length - 1] = (
          start: runs.last.start,
          endExclusive: interval.endExclusive,
        );
      }
    } else {
      runs.add(interval);
    }
  }
  return runs;
}

/// [collapsedAttachBaseIds] folds ATTACH GROUPS (UI-R20 #9): attach rows
/// whose base is listed contribute no rows — same VIEW-state contract as
/// the hidden sections, and the active layer is exempt here too (folding
/// the group never hides the attach row you're working on).
List<TimelineDisplayRow> buildTimelineDisplayRows({
  required List<Layer> layers,
  required Set<LayerId> expandedLayerIds,
  required List<PropertyLaneRow> Function(Layer layer) lanesForLayer,
  List<LayerFolder> folders = const [],
  Set<FolderId> expandedFolderLaneIds = const {},
  List<PropertyLaneRow> Function(LayerFolder folder)? lanesForFolder,
  Set<TimelineSection> hiddenSections = const {},
  TimelineRowFilter rowFilter = TimelineRowFilter.none,
  Set<LayerId> collapsedAttachBaseIds = const {},
  LayerId? activeLayerId,
  bool Function(LayerId layerId)? fxEnabledOf,
}) {
  final rows = <TimelineDisplayRow>[];
  // R26 #36: the attach group is unsplittable — a base's transform lanes
  // WAIT here until the group's trailing attach rows have been laid, so
  // the order reads base → attach rows → lanes in every orientation
  // (attach rows preceding the base in display order are unaffected: the
  // group already ends at the base there).
  final pendingLanes = <TimelineDisplayRow>[];
  LayerId? pendingLaneBaseId;
  void flushPendingLanes() {
    rows.addAll(pendingLanes);
    pendingLanes.clear();
    pendingLaneBaseId = null;
  }

  // Folder HEADER rows (L5) go above their first displayed member —
  // outermost first for nesting. Collapsed folders keep their header (its
  // band shows the aggregate block) and swallow member rows (the active
  // layer stays visible, like the attach fold).
  final emittedFolderIds = <FolderId>{};
  for (var index = 0; index < layers.length; index += 1) {
    final layer = layers[index];
    // The attach run ends at the first layer that is NOT an attach of the
    // pending base (row-emission skips below never end it: a folded
    // attach row still belongs to the group).
    if (pendingLaneBaseId != null &&
        layer.attachedToLayerId != pendingLaneBaseId) {
      flushPendingLanes();
    }
    if (hiddenSections.contains(timelineSectionForLayerKind(layer.kind))) {
      continue;
    }
    final attachBaseId = layer.attachedToLayerId;
    if (attachBaseId != null &&
        layer.id != activeLayerId &&
        collapsedAttachBaseIds.contains(attachBaseId)) {
      continue;
    }
    if (rowFilter.isActive &&
        layer.id != activeLayerId &&
        !rowFilter.allows(
          layer,
          fxEnabled: fxEnabledOf?.call(layer.id) ?? true,
        )) {
      continue;
    }
    final ancestry = folders.ancestryOf(layer.folderId);
    for (var depth = 0; depth < ancestry.length; depth += 1) {
      // ancestry is nearest-first; emit outermost-first.
      final folder = ancestry[ancestry.length - 1 - depth];
      if (emittedFolderIds.add(folder.id)) {
        rows.add(
          TimelineDisplayRow.folder(
            layer,
            folder,
            layerIndex: index,
            depth: depth,
            aggregateRuns: folderAggregateRuns([
              for (final member in layers)
                if (folders
                    .ancestryOf(member.folderId)
                    .any((ancestor) => ancestor.id == folder.id))
                  member,
            ]),
          ),
        );
        // Folder FX lanes (L5c) twirl under the header — independent of
        // the member collapse (a collapsed folder still places as one).
        if (lanesForFolder != null &&
            expandedFolderLaneIds.contains(folder.id)) {
          for (final lane in lanesForFolder(folder)) {
            rows.add(TimelineDisplayRow.lane(layer, lane, layerIndex: index));
          }
        }
      }
    }
    if (folders.subtreeCollapsed(layer.folderId) &&
        layer.id != activeLayerId) {
      continue;
    }
    rows.add(
      TimelineDisplayRow.layer(
        layer,
        layerIndex: index,
        depth: ancestry.length,
      ),
    );
    if (!expandedLayerIds.contains(layer.id)) {
      continue;
    }
    // R26 #36: with trailing attach rows ahead, the lanes go PENDING and
    // land after the group; otherwise they follow the layer row exactly
    // as before. An attach layer's own lanes always emit in place (it
    // has no attach children of its own).
    final defer =
        layer.attachedToLayerId == null &&
        index + 1 < layers.length &&
        layers[index + 1].attachedToLayerId == layer.id;
    for (final lane in lanesForLayer(layer)) {
      final laneRow = TimelineDisplayRow.lane(layer, lane, layerIndex: index);
      if (defer) {
        pendingLanes.add(laneRow);
        pendingLaneBaseId = layer.id;
      } else {
        rows.add(laneRow);
      }
    }
  }
  flushPendingLanes();
  return List.unmodifiable(rows);
}
