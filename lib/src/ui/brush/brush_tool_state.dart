import '../../models/brush_settings.dart';
import '../../models/brush_tip_mask.dart';
import '../../models/brush_tip_rotation_mode.dart';
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
    double roundness = defaultRoundness,
    double angleDegrees = defaultAngleDegrees,
    BrushTipMask? tipMask,
    BrushTipRotationMode rotationMode = BrushTipRotationMode.fixed,
    double minimumSizeRatio = 0.0,
    double sizeJitter = 0.0,
    double opacityJitter = 0.0,
    double angleJitter = 0.0,
    double scatterRadiusRatio = 0.0,
    int scatterCount = 1,
    bool scatterBothAxes = true,
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
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
      minimumSizeRatio: minimumSizeRatio,
      sizeJitter: sizeJitter,
      opacityJitter: opacityJitter,
      angleJitter: angleJitter,
      scatterRadiusRatio: scatterRadiusRatio,
      scatterCount: scatterCount,
      scatterBothAxes: scatterBothAxes,
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
    required this.roundness,
    required this.angleDegrees,
    this.tipMask,
    this.rotationMode = BrushTipRotationMode.fixed,
    this.minimumSizeRatio = 0.0,
    this.sizeJitter = 0.0,
    this.opacityJitter = 0.0,
    this.angleJitter = 0.0,
    this.scatterRadiusRatio = 0.0,
    this.scatterCount = 1,
    this.scatterBothAxes = true,
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
    double? roundness,
    double? angleDegrees,
    BrushTipMask? tipMask,
    BrushTipRotationMode? rotationMode,
    double? minimumSizeRatio,
    double? sizeJitter,
    double? opacityJitter,
    double? angleJitter,
    double? scatterRadiusRatio,
    int? scatterCount,
    bool? scatterBothAxes,
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
      roundness: clampRoundness(roundness ?? defaultRoundness),
      angleDegrees: clampAngleDegrees(angleDegrees ?? defaultAngleDegrees),
      tipMask: tipMask,
      rotationMode: rotationMode ?? BrushTipRotationMode.fixed,
      minimumSizeRatio: clampZeroToOne(minimumSizeRatio ?? 0.0),
      sizeJitter: clampZeroToOne(sizeJitter ?? 0.0),
      opacityJitter: clampZeroToOne(opacityJitter ?? 0.0),
      angleJitter: clampZeroToOne(angleJitter ?? 0.0),
      scatterRadiusRatio: clampScatterRadius(scatterRadiusRatio ?? 0.0),
      scatterCount: clampScatterCount(scatterCount ?? 1),
      scatterBothAxes: scatterBothAxes ?? true,
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
  static const double minRoundness = 0.05;
  static const double defaultRoundness = 1.0;
  static const double minAngleDegrees = 0.0;
  static const double maxAngleDegrees = 180.0;
  static const double defaultAngleDegrees = 0.0;
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
    roundness: defaultRoundness,
    angleDegrees: defaultAngleDegrees,
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

  /// Minor-to-major axis ratio of the tip; 1.0 keeps the classic
  /// circle/square, smaller values flatten it into an ellipse/rectangle.
  final double roundness;

  /// Visual counterclockwise rotation of the tip's major axis from the
  /// horizontal, in degrees (0-180; an ellipse repeats every 180).
  final double angleDegrees;

  /// Sampled (bitmap) tip applied by a preset; `null` uses the parametric
  /// [tipShape]. The panel has no direct mask picker yet — masks arrive via
  /// presets (and later ABR import). Cleared only by applying a preset
  /// without one ([BrushToolState.fromBrushSettings]); [copyWith] preserves
  /// it so slider tweaks keep the textured tip.
  final BrushTipMask? tipMask;

  /// Placement dynamics carried from presets/imports (no panel controls
  /// yet, pending the unified UI pass): see the same-named fields on
  /// `BrushSettings`.
  final BrushTipRotationMode rotationMode;
  final double minimumSizeRatio;
  final double sizeJitter;
  final double opacityJitter;
  final double angleJitter;
  final double scatterRadiusRatio;
  final int scatterCount;
  final bool scatterBothAxes;

  /// Builds tool state from a preset's model-layer [BrushSettings], clamping
  /// every value into the panel's ranges.
  factory BrushToolState.fromBrushSettings(BrushSettings settings) {
    return BrushToolState.clamped(
      size: settings.size,
      opacity: settings.opacity,
      color: settings.color,
      spacing: settings.spacing,
      hardness: settings.hardness,
      flow: settings.flow,
      tipShape: settings.tipShape,
      pressureSize: settings.pressureSize,
      pressureOpacity: settings.pressureOpacity,
      roundness: settings.roundness,
      angleDegrees: settings.angleDegrees,
      tipMask: settings.tipMask,
      rotationMode: settings.rotationMode,
      minimumSizeRatio: settings.minimumSizeRatio,
      sizeJitter: settings.sizeJitter,
      opacityJitter: settings.opacityJitter,
      angleJitter: settings.angleJitter,
      scatterRadiusRatio: settings.scatterRadiusRatio,
      scatterCount: settings.scatterCount,
      scatterBothAxes: settings.scatterBothAxes,
    );
  }

  /// Snapshot of this tool state as the model-layer [BrushSettings] — the
  /// payload brush presets store.
  BrushSettings toBrushSettings() {
    return BrushSettings(
      color: color,
      size: size,
      opacity: opacity,
      flow: flow,
      hardness: hardness,
      spacing: spacing,
      tipShape: tipShape,
      pressureSize: pressureSize,
      pressureOpacity: pressureOpacity,
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
      minimumSizeRatio: minimumSizeRatio,
      sizeJitter: sizeJitter,
      opacityJitter: opacityJitter,
      angleJitter: angleJitter,
      scatterRadiusRatio: scatterRadiusRatio,
      scatterCount: scatterCount,
      scatterBothAxes: scatterBothAxes,
    );
  }

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
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
      minimumSizeRatio: minimumSizeRatio,
      sizeJitter: sizeJitter,
      opacityJitter: opacityJitter,
      angleJitter: angleJitter,
      scatterRadiusRatio: scatterRadiusRatio,
      scatterCount: scatterCount,
      scatterBothAxes: scatterBothAxes,
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
    double? roundness,
    double? angleDegrees,
    BrushTipMask? tipMask,
    BrushTipRotationMode? rotationMode,
    double? minimumSizeRatio,
    double? sizeJitter,
    double? opacityJitter,
    double? angleJitter,
    double? scatterRadiusRatio,
    int? scatterCount,
    bool? scatterBothAxes,
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
      roundness: roundness ?? this.roundness,
      angleDegrees: angleDegrees ?? this.angleDegrees,
      tipMask: tipMask ?? this.tipMask,
      rotationMode: rotationMode ?? this.rotationMode,
      minimumSizeRatio: minimumSizeRatio ?? this.minimumSizeRatio,
      sizeJitter: sizeJitter ?? this.sizeJitter,
      opacityJitter: opacityJitter ?? this.opacityJitter,
      angleJitter: angleJitter ?? this.angleJitter,
      scatterRadiusRatio: scatterRadiusRatio ?? this.scatterRadiusRatio,
      scatterCount: scatterCount ?? this.scatterCount,
      scatterBothAxes: scatterBothAxes ?? this.scatterBothAxes,
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

  /// Clamps roundness to [minRoundness, 1] so the tip never degenerates to
  /// zero width.
  static double clampRoundness(double value) {
    if (!value.isFinite) {
      return defaultRoundness;
    }
    return value.clamp(minRoundness, 1.0).toDouble();
  }

  /// Clamps the tip angle to [0, 180] degrees (an ellipse repeats every 180).
  static double clampAngleDegrees(double value) {
    if (!value.isFinite) {
      return defaultAngleDegrees;
    }
    return value.clamp(minAngleDegrees, maxAngleDegrees).toDouble();
  }

  /// Clamps dynamics ratios (jitters, minimum size) to [0, 1].
  static double clampZeroToOne(double value) {
    if (!value.isFinite) {
      return 0.0;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  /// Clamps the scatter radius ratio to a sane non-negative range.
  static double clampScatterRadius(double value) {
    if (!value.isFinite) {
      return 0.0;
    }
    return value.clamp(0.0, 10.0).toDouble();
  }

  /// Clamps the per-step scatter dab count.
  static int clampScatterCount(int value) => value.clamp(1, 16);

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
          other.pressureOpacity == pressureOpacity &&
          other.roundness == roundness &&
          other.angleDegrees == angleDegrees &&
          other.tipMask == tipMask &&
          other.rotationMode == rotationMode &&
          other.minimumSizeRatio == minimumSizeRatio &&
          other.sizeJitter == sizeJitter &&
          other.opacityJitter == opacityJitter &&
          other.angleJitter == angleJitter &&
          other.scatterRadiusRatio == scatterRadiusRatio &&
          other.scatterCount == scatterCount &&
          other.scatterBothAxes == scatterBothAxes;

  @override
  int get hashCode => Object.hashAll([
    size,
    opacity,
    color,
    spacing,
    hardness,
    flow,
    tipShape,
    pressureSize,
    pressureOpacity,
    roundness,
    angleDegrees,
    tipMask,
    rotationMode,
    minimumSizeRatio,
    sizeJitter,
    opacityJitter,
    angleJitter,
    scatterRadiusRatio,
    scatterCount,
    scatterBothAxes,
  ]);
}
