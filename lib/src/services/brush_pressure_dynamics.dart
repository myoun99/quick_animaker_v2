import '../models/brush_dab.dart';
import '../models/brush_pressure_curve.dart';

/// Scales a dab's size/opacity/flow/hardness by its input pressure through
/// the per-setting response curves (BB-3, R26 #11).
///
/// The dab is expected to still carry the base tool values in its
/// [BrushDab.size]/[BrushDab.opacity]/[BrushDab.flow]/[BrushDab.hardness]
/// fields, with the normalized input pressure in [BrushDab.pressure]. Each
/// non-null curve multiplies its base value by `curve.evaluate(pressure)`
/// — the same formula `BrushDab.fromInputSample` applies in the offline
/// placement path — applied here as a post-interpolation step so each
/// inserted dab is scaled by its own interpolated pressure.
///
/// Returns the dab unchanged when every curve is null, so the no-pressure
/// path allocates nothing.
BrushDab applyBrushPressureDynamics(
  BrushDab dab, {
  BrushPressureCurve? sizeCurve,
  BrushPressureCurve? opacityCurve,
  BrushPressureCurve? flowCurve,
  BrushPressureCurve? hardnessCurve,
}) {
  if (sizeCurve == null &&
      opacityCurve == null &&
      flowCurve == null &&
      hardnessCurve == null) {
    return dab;
  }
  final pressure = dab.pressure;
  return dab.copyWith(
    size: sizeCurve == null ? dab.size : dab.size * sizeCurve.evaluate(pressure),
    opacity: opacityCurve == null
        ? dab.opacity
        : (dab.opacity * opacityCurve.evaluate(pressure)).clamp(0.0, 1.0),
    flow: flowCurve == null
        ? dab.flow
        : (dab.flow * flowCurve.evaluate(pressure)).clamp(0.0, 1.0),
    hardness: hardnessCurve == null
        ? dab.hardness
        : (dab.hardness * hardnessCurve.evaluate(pressure)).clamp(0.0, 1.0),
  );
}
