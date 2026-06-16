import 'package:flutter/material.dart';

import 'timeline_cell_exposure_state.dart';

class TimelineCellStyleColors {
  const TimelineCellStyleColors({
    required this.background,
    required this.border,
  });

  final Color background;
  final Color border;
}

const Color timelineDrawingHeldColor = Colors.white;
const Color timelineDrawingStartColor = timelineDrawingHeldColor;
const Color timelineDrawingStartBorderColor = Color(0xFFBDBDBD);
const Color timelineBlankStartColor = Color(0xFFD0D0D0);
const Color timelineBlankHeldColor = timelineBlankStartColor;

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
    TimelineCellExposureState.empty => emptyBaseColor,
    TimelineCellExposureState.drawingStart => timelineDrawingStartColor,
    TimelineCellExposureState.heldExposure => timelineDrawingHeldColor,
    TimelineCellExposureState.blankStart => timelineBlankStartColor,
    TimelineCellExposureState.blankHeld => timelineBlankHeldColor,
  };
  final exposureBorderColor = switch (exposureState) {
    TimelineCellExposureState.empty => colorScheme.outlineVariant,
    TimelineCellExposureState.drawingStart => timelineDrawingStartBorderColor,
    TimelineCellExposureState.heldExposure =>
      colorScheme.outlineVariant.withValues(alpha: 0.65),
    TimelineCellExposureState.blankStart => colorScheme.outlineVariant,
    TimelineCellExposureState.blankHeld =>
      colorScheme.outlineVariant.withValues(alpha: 0.55),
  };

  if (!selected) {
    return TimelineCellStyleColors(
      background: exposureColor,
      border: exposureBorderColor,
    );
  }

  return TimelineCellStyleColors(
    background: Color.alphaBlend(
      Colors.red.withValues(alpha: 0.12),
      exposureColor,
    ),
    border: Colors.red,
  );
}
