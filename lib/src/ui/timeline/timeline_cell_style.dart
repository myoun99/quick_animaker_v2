import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_grid_metrics.dart';

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

/// LIVE accent read (UI-R22 #5): the selection ink follows accent 1.
Color get timelineSelectedFrameBorderColor => AppColors.accent;

/// Ink for glyphs (frame names, marks) sitting on the near-white drawing
/// blocks; the usual light on-surface text would vanish there.
const Color timelineDrawingInkColor = Color(0xFF26282B);

/// R26 #44: ACTION-section blocks whose cel holds NO picture yet paint a
/// slightly grayed paper, so unworked cels read at a glance. The whole
/// covered run (start + held cells) takes it; other sections never do.
const Color timelineEmptyCelBlockColor = Color(0xFFD7D5D0);

/// The PLAIN (non-block) frame grid's border alpha (UI-R14 #4): ONE
/// faint value for every surface — the painterized drawing rows, the
/// sparse widget rows (SE/camera/instruction), the frame ruler cells and
/// the storyboard's frame lines — so the 6f/24f beat lines alone carry
/// the rhythm.
const double timelineBaseGridAlpha = 0.25;

/// The base grid's line CADENCE at [frameCellExtent] (UI-R18 #8/#12, the
/// storyboard recipe adopted everywhere): instead of alpha-fading away at
/// small zooms, the per-cell lines THIN to every Nth frame (the label
/// cadence) and never disappear — "the grid is always there".
int timelineGridLineEveryFrames(double frameCellExtent) => frameCellExtent >= 16
    ? 1
    : TimelineGridMetrics(
        frameCellWidth: frameCellExtent,
      ).frameLabelEveryFrames;

/// The glyph size that FITS a cell of [frameCellExtent] (R26 #38/#4).
///
/// Text used to blank out below ~14px cells; the user's rule is "엄청
/// 작아지는 한이 있어도 절대 안 사라지도록" — so the type shrinks with the
/// cell instead, down to a hard floor that still reads as a mark.
double timelineFittedGlyphFontSize(double baseFontSize, double frameCellExtent) {
  if (frameCellExtent >= 14) {
    return baseFontSize;
  }
  const floor = 4.0;
  final fitted = frameCellExtent * 0.78;
  return fitted.clamp(floor, baseFontSize);
}

/// The plain grid's border ink — FLAT faint (UI-R18 #8: the zoom fade is
/// gone; density is handled by [timelineGridLineEveryFrames]).
Color timelineBaseGridInk(
  ColorScheme colorScheme, {
  required double frameCellExtent,
}) => colorScheme.outlineVariant.withValues(alpha: timelineBaseGridAlpha);

/// Whether [exposureState] renders on the light drawing-block background
/// (and therefore needs [timelineDrawingInkColor] text).
bool timelineCellUsesDrawingInk(TimelineCellExposureState exposureState) {
  return exposureState.isCovered;
}

/// The active-row WASH — painted once per row as an underlay (UI-R21 #2),
/// never per cell: cell rasters are active-independent now, so switching
/// the active layer re-rasters nothing.
Color timelineActiveRowWashColor(ColorScheme colorScheme) =>
    colorScheme.secondaryContainer.withValues(alpha: 0.35);

TimelineCellStyleColors timelineCellStyleColors({
  required ColorScheme colorScheme,
  required TimelineCellExposureState exposureState,
  required bool selected,
}) {
  // UI-R21 #2: empty cells paint NOTHING — the row-level underlay owns
  // the paper (a surface base plus the active-row wash), so the cell
  // substrate carries no per-row state at all.
  const emptyBaseColor = Colors.transparent;
  final exposureColor = switch (exposureState) {
    TimelineCellExposureState.uncovered ||
    TimelineCellExposureState.markUncovered => emptyBaseColor,
    TimelineCellExposureState.drawingStart => timelineDrawingStartColor,
    TimelineCellExposureState.held ||
    TimelineCellExposureState.markHeld => timelineDrawingHeldColor,
  };
  // UI-R18 #8: the GRID OVERLAY owns every plain per-cell line now —
  // uncovered cells draw no border of their own, and the paper blocks'
  // seams (block START included, UI-R20 #7: the dark head silhouette is
  // gone) all sit on the shared faint alpha.
  final exposureBorderColor = switch (exposureState) {
    TimelineCellExposureState.uncovered ||
    TimelineCellExposureState.markUncovered => Colors.transparent,
    TimelineCellExposureState.drawingStart ||
    TimelineCellExposureState.held ||
    TimelineCellExposureState.markHeld => colorScheme.outlineVariant.withValues(
      alpha: timelineBaseGridAlpha,
    ),
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
