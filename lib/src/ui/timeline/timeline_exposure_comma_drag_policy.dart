/// Comma-drag exposure editing policy, shared across frame-axis orientations.
///
/// "Comma-drag" drags the trailing edge of the active layer's selected
/// exposure block along the frame axis to lengthen or shorten the exposure
/// one frame (comma) at a time — the timesheet gesture of extending a cel's
/// run. All math here is expressed in main-axis scalars only, so the
/// horizontal timeline and the transposed X-sheet reuse it unchanged; the
/// widgets supply the axis.
///
/// This policy performs no mutations itself: each whole-frame step is
/// attempted through a caller-supplied callback backed by the existing
/// increase/decrease exposure commands, keeping mutation and undo semantics
/// identical to the toolbar buttons.
library;

import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_range_resolver.dart';

/// Attempts one ±1-frame exposure step; returns whether it was applied.
typedef TimelineExposureCommaStepAttempt = bool Function();

/// Tracks one comma-drag from pointer-down to pointer-up, converting the
/// accumulated main-axis drag distance into whole-frame steps.
class TimelineExposureCommaDragSession {
  TimelineExposureCommaDragSession({required this.frameCellExtent})
    : assert(frameCellExtent > 0, 'Frame cell extent must be positive.');

  /// Main-axis extent of one frame cell (cell width in the horizontal
  /// timeline, frame row height in the X-sheet).
  final double frameCellExtent;

  double _accumulatedDelta = 0;
  int _appliedSteps = 0;

  /// Net ±1 steps already applied through the attempt callbacks.
  int get appliedSteps => _appliedSteps;

  /// Feeds one drag movement along the frame axis and attempts the whole-
  /// frame steps it uncovers. Steps trigger when the dragged edge crosses a
  /// cell midpoint. A rejected attempt is not counted as applied, so a later
  /// reversal replays from the actual data state rather than the requested
  /// one.
  void update({
    required double delta,
    required TimelineExposureCommaStepAttempt tryIncrease,
    required TimelineExposureCommaStepAttempt tryDecrease,
  }) {
    _accumulatedDelta += delta;
    final desiredSteps = (_accumulatedDelta / frameCellExtent).round();
    while (_appliedSteps < desiredSteps) {
      if (!tryIncrease()) {
        return;
      }
      _appliedSteps += 1;
    }
    while (_appliedSteps > desiredSteps) {
      if (!tryDecrease()) {
        return;
      }
      _appliedSteps -= 1;
    }
  }
}

/// Whether the comma-drag handle should render for [displayRange].
///
/// Only drawing blocks get a handle, and only when the block's true end is
/// inside the resolved window: a block truncated by the virtualization
/// window would otherwise pin the handle to the window edge instead of the
/// real exposure end.
bool timelineCommaDragHandleVisible({
  required SelectedExposureDisplayRange displayRange,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
}) {
  final range = displayRange.resolvedRange;
  if (range.kind != TimelineExposureRangeKind.drawing) {
    return false;
  }

  return exposureStateAt(range.endFrameIndexExclusive) !=
      TimelineCellExposureState.heldExposure;
}
