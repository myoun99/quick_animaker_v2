/// Comma-drag pixel policy, shared across frame-axis orientations.
///
/// "Comma-drag" grabs a drawing block's edge grip and drags along the frame
/// axis to adjust exposure one frame (comma) at a time, TVPaint-style. The
/// math here is main-axis scalars only, so the horizontal timeline and the
/// transposed X-sheet reuse it unchanged (Axis policy: no per-orientation
/// forks).
///
/// The conversion is CUMULATIVE: callers keep the summed pixel delta since
/// drag start and pass it whole. The data layer recomputes the shifted
/// timeline from the drag-start snapshot each time, so previews are
/// idempotent and no per-step accounting exists anywhere.
library;

import 'package:flutter/widgets.dart';

import '../../models/layer_id.dart';
import '../../models/timeline_coverage.dart';

/// Whole-frame delta for an accumulated main-axis drag distance; steps
/// trigger when the dragged edge crosses a cell midpoint.
int commaDragFrameDelta({
  required double accumulatedDelta,
  required double frameCellExtent,
}) {
  assert(frameCellExtent > 0, 'Frame cell extent must be positive.');
  return (accumulatedDelta / frameCellExtent).round();
}

/// The drag hooks a grip needs, bundled so rows/grids thread one optional
/// object instead of four callbacks. Wired to the editor session's
/// begin/update/end/cancel exposure-edge-drag methods (single undo entry
/// per drag).
class TimelineCommaDragCallbacks {
  const TimelineCommaDragCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Returns whether the drag may start (e.g. the block still exists).
  final bool Function(
    LayerId layerId,
    int blockStartIndex,
    TimelineBlockEdge edge,
  )
  onBegin;

  /// Reports the cumulative whole-frame delta since drag start.
  final ValueChanged<int> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}
