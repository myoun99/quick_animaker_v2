import '../../models/layer_id.dart';
import 'property_lane_model.dart';

/// The layer whose row sits [rowDelta] display rows away from
/// [sourceLayerId]'s cells row — the block-move drop target. Lane rows
/// resolve to their owning layer; out-of-range deltas clamp to the ends.
LayerId? resolveBlockMoveTargetLayer({
  required List<TimelineDisplayRow> rows,
  required LayerId sourceLayerId,
  required int rowDelta,
}) {
  if (rows.isEmpty) {
    return null;
  }
  var sourceIndex = -1;
  for (var index = 0; index < rows.length; index += 1) {
    if (!rows[index].isLane && rows[index].layer.id == sourceLayerId) {
      sourceIndex = index;
      break;
    }
  }
  if (sourceIndex < 0) {
    return null;
  }
  final targetIndex = (sourceIndex + rowDelta).clamp(0, rows.length - 1);
  return rows[targetIndex].layer.id;
}

/// The display row a cell SELECT drag has reached: its layer, plus the
/// lane id when the pointer is over a property-lane row (R27 #14 —
/// "A셀부터 오파시티까지만").
///
/// [resolveBlockMoveTargetLayer] answers the same question for MOVES,
/// where a lane row can only mean its owning layer (keys do not accept
/// dropped blocks). Selection is the other half: a lane row IS a
/// selectable row, so the drag has to be able to stop on it. Same row
/// walk, different verb — hence two functions over one row list rather
/// than one function with a mode flag.
({LayerId layerId, String? laneId})? resolveSelectionSpanHead({
  required List<TimelineDisplayRow> rows,
  required LayerId sourceLayerId,
  required int rowDelta,
}) {
  if (rows.isEmpty) {
    return null;
  }
  var sourceIndex = -1;
  for (var index = 0; index < rows.length; index += 1) {
    if (!rows[index].isLane && rows[index].layer.id == sourceLayerId) {
      sourceIndex = index;
      break;
    }
  }
  if (sourceIndex < 0) {
    return null;
  }
  final target = rows[(sourceIndex + rowDelta).clamp(0, rows.length - 1)];
  return (layerId: target.layer.id, laneId: target.lane?.laneId);
}
