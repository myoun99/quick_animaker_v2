import '../../models/brush_tip_shape.dart';
import '../canvas/brush_edit_canvas_input_settings.dart';

/// Editor-session state for the active brush tool options.
///
/// This is UI/tool state owned by the editor session. It is intentionally
/// separate from project, cut, layer, frame, stroke, cache, and save/load
/// data.
class BrushToolState {
  factory BrushToolState({
    double size = defaultSize,
    double opacity = defaultOpacity,
    int color = defaultColor,
    double spacing = defaultSpacing,
    double hardness = defaultHardness,
    double flow = defaultFlow,
    BrushTipShape tipShape = defaultTipShape,
    bool pressureSize = defaultPressureSize,
    bool pressureOpacity = defaultPressureOpacity,
  }) {
    return BrushToolState.clamped(
      size: size,
      opacity: opacity,
      color: color,
      spacing: spacing,
      hardness: hardness,
      flow: flow,
      tipShape: tipShape,
      pressureSize: pressureSize,
      pressureOpacity: pressureOpacity,
    );
  }

  const BrushToolState._raw({
    required this.size,
    required this.opacity,
    required this.color,
    required this.spacing,
    required this.hardness,
    required this.flow,
    required this.tipShape,
    required this.pressureSize,
    required this.pressureOpacity,
  });

  factory BrushToolState.clamped({
    double? size,
    double? opacity,
    int? color,
    double? spacing,
    double? hardness,
    double? flow,
    BrushTipShape? tipShape,
    bool? pressureSize,
    bool? pressureOpacity,
  }) {
    return BrushToolState._raw(
      size: clampSize(size ?? defaultSize),
      opacity: clampOpacity(opacity ?? defaultOpacity),
      color: color ?? defaultColor,
      spacing: clampSpacing(spacing ?? defaultSpacing),
      hardness: clampUnit(hardness ?? defaultHardness),
      flow: clampUnit(flow ?? defaultFlow),
      tipShape: tipShape ?? defaultTipShape,
      pressureSize: pressureSize ?? defaultPressureSize,
      pressureOpacity: pressureOpacity ?? defaultPressureOpacity,
    );
  }

  static const double minSize = 1.0;
  static const double maxSize = 128.0;
  static const double defaultSize = 10.0;
  static const double defaultOpacity = 1.0;
  static const int defaultColor = 0xFF000000;
  static const double minSpacing = 0.05;
  static const double maxSpacing = 4.0;
  static const double defaultSpacing = 0.25;
  static const double defaultHardness = 1.0;
  static const double defaultFlow = 1.0;
  static const BrushTipShape defaultTipShape = BrushTipShape.round;
  static const bool defaultPressureSize = false;
  static const bool defaultPressureOpacity = false;
  static const BrushToolState defaults = BrushToolState._raw(
    size: defaultSize,
    opacity: defaultOpacity,
    color: defaultColor,
    spacing: defaultSpacing,
    hardness: defaultHardness,
    flow: defaultFlow,
    tipShape: defaultTipShape,
    pressureSize: defaultPressureSize,
    pressureOpacity: defaultPressureOpacity,
  );

  final double size;
  final double opacity;
  final int color;
  final double spacing;

  /// Tip edge falloff: 1.0 paints a hard edge, lower values fade linearly
  /// from `radius * hardness` to the radius (same coverage model as the
  /// commit rasterizer).
  final double hardness;

  /// Per-dab paint strength; combined multiplicatively with [opacity] when a
  /// dab is sampled.
  final double flow;

  final BrushTipShape tipShape;

  /// When true, pen/tablet pressure scales each dab's size (linear response).
  final bool pressureSize;

  /// When true, pen/tablet pressure scales each dab's opacity (linear).
  final bool pressureOpacity;

  BrushEditCanvasInputSettings toInputSettings() {
    return BrushEditCanvasInputSettings(
      color: color,
      size: size,
      opacity: opacity,
      spacing: spacing,
      hardness: hardness,
      flow: flow,
      tipShape: tipShape,
      pressureSize: pressureSize,
      pressureOpacity: pressureOpacity,
    );
  }

  BrushToolState copyWith({
    double? size,
    double? opacity,
    int? color,
    double? spacing,
    double? hardness,
    double? flow,
    BrushTipShape? tipShape,
    bool? pressureSize,
    bool? pressureOpacity,
  }) {
    return BrushToolState.clamped(
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      spacing: spacing ?? this.spacing,
      hardness: hardness ?? this.hardness,
      flow: flow ?? this.flow,
      tipShape: tipShape ?? this.tipShape,
      pressureSize: pressureSize ?? this.pressureSize,
      pressureOpacity: pressureOpacity ?? this.pressureOpacity,
    );
  }

  static double clampSize(double value) {
    if (!value.isFinite) {
      return defaultSize;
    }
    return value.clamp(minSize, maxSize).toDouble();
  }

  static double clampOpacity(double value) {
    if (!value.isFinite) {
      return defaultOpacity;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  static double clampSpacing(double value) {
    if (!value.isFinite) {
      return defaultSpacing;
    }
    return value.clamp(minSpacing, maxSpacing).toDouble();
  }

  /// Clamps unit-interval settings (hardness, flow) to [0, 1].
  static double clampUnit(double value) {
    if (!value.isFinite) {
      return 1.0;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushToolState &&
          other.size == size &&
          other.opacity == opacity &&
          other.color == color &&
          other.spacing == spacing &&
          other.hardness == hardness &&
          other.flow == flow &&
          other.tipShape == tipShape &&
          other.pressureSize == pressureSize &&
          other.pressureOpacity == pressureOpacity;

  @override
  int get hashCode => Object.hash(
    size,
    opacity,
    color,
    spacing,
    hardness,
    flow,
    tipShape,
    pressureSize,
    pressureOpacity,
  );
}
