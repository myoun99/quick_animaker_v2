import '../models/brush_dab.dart';

/// Scales a dab's size and/or opacity by its input pressure (linear response).
///
/// The dab is expected to still carry the base tool size and opacity in its
/// [BrushDab.size] and [BrushDab.opacity] fields, with the normalized input
/// pressure in [BrushDab.pressure]. When a channel's toggle is enabled the
/// value becomes `base * pressure`; otherwise it is left untouched. This is
/// the same linear formula `BrushDab.fromInputSample` applies in the offline
/// placement path — applied here as a post-interpolation step so each
/// inserted dab is scaled by its own interpolated pressure.
///
/// Returns the dab unchanged when neither toggle is on, so the no-pressure
/// path allocates nothing.
BrushDab applyBrushPressureDynamics(
  BrushDab dab, {
  required bool pressureSize,
  required bool pressureOpacity,
}) {
  if (!pressureSize && !pressureOpacity) {
    return dab;
  }
  return dab.copyWith(
    size: pressureSize ? dab.size * dab.pressure : dab.size,
    opacity: pressureOpacity
        ? (dab.opacity * dab.pressure).clamp(0.0, 1.0)
        : dab.opacity,
  );
}
