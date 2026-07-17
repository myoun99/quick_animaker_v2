import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'timeline_cell_exposure_state.dart';

class TimelineCellStyleColors {
  const TimelineCellStyleColors({
    required this.background,
    required this.border,
  });

  final Color background;
  final Color border;
}

/// Drawing exposure blocks read like paper timesheet cells: near-white on
/// the dark grid so held runs are unmistakable at a glance.
const Color timelineDrawingHeldColor = Color(0xFFE9E7E2);
const Color timelineDrawingStartColor = timelineDrawingHeldColor;
const Color timelineDrawingStartBorderColor = AppColors.hairlineStrong;
const Color timelineSelectedFrameBorderColor = AppColors.accent;

/// Ink for glyphs (frame names, marks) sitting on the near-white drawing
/// blocks; the usual light on-surface text would vanish there.
const Color timelineDrawingInkColor = Color(0xFF26282B);

/// The PLAIN (non-block) frame grid's border alpha (UI-R14 #4): ONE
/// faint value for every surface — the painterized drawing rows, the
/// sparse widget rows (SE/camera/instruction), the frame ruler cells and
/// the storyboard's frame lines — so the 6f/24f beat lines alone carry
/// the rhythm.
const double timelineBaseGridAlpha = 0.25;

/// How much of the plain grid survives at the current zoom (UI-R11 #7):
/// 1 at comfortable cell widths, 0 at/below ~7px where the hairlines
/// would smear into noise.
double timelineBaseGridFade(double frameCellExtent) =>
    ((frameCellExtent - 7) / 9).clamp(0.0, 1.0).toDouble();

/// The plain grid's border ink at [frameCellExtent] — faint and fading;
/// fully transparent lines are skipped by their painters.
Color timelineBaseGridInk(
  ColorScheme colorScheme, {
  required double frameCellExtent,
}) => colorScheme.outlineVariant.withValues(
  alpha: timelineBaseGridAlpha * timelineBaseGridFade(frameCellExtent),
);

/// Whether [exposureState] renders on the light drawing-block background
/// (and therefore needs [timelineDrawingInkColor] text).
bool timelineCellUsesDrawingInk(TimelineCellExposureState exposureState) {
  return exposureState.isCovered;
}

TimelineCellStyleColors timelineCellStyleColors({
  required ColorScheme colorScheme,
  required TimelineCellExposureState exposureState,
  required bool active,
  required bool selected,
}) {
  final emptyBaseColor = active
      ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
      : colorScheme.surface;
  final exposureColor = switch (exposureState) {
    TimelineCellExposureState.uncovered ||
    TimelineCellExposureState.markUncovered => emptyBaseColor,
    TimelineCellExposureState.drawingStart => timelineDrawingStartColor,
    TimelineCellExposureState.held ||
    TimelineCellExposureState.markHeld => timelineDrawingHeldColor,
  };
  final exposureBorderColor = switch (exposureState) {
    TimelineCellExposureState.uncovered ||
    TimelineCellExposureState.markUncovered => colorScheme.outlineVariant,
    TimelineCellExposureState.drawingStart => timelineDrawingStartBorderColor,
    TimelineCellExposureState.held || TimelineCellExposureState.markHeld =>
      colorScheme.outlineVariant.withValues(alpha: 0.65),
  };

  if (!selected) {
    return TimelineCellStyleColors(
      background: exposureColor,
      border: exposureBorderColor,
    );
  }

  return TimelineCellStyleColors(
    background: Color.alphaBlend(
      timelineSelectedFrameBorderColor.withValues(alpha: 0.12),
      exposureColor,
    ),
    border: timelineSelectedFrameBorderColor,
  );
}
