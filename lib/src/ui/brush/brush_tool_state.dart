import '../../models/brush_settings.dart';
import '../../models/brush_tip_mask.dart';
import '../../models/brush_tip_rotation_mode.dart';
import '../../models/brush_tip_shape.dart';
import '../canvas/brush_edit_canvas_input_settings.dart';

/// Which canvas tool the pointer drives. The eraser reuses every brush
/// option (size, hardness, tip) but its dabs remove alpha instead of
/// painting color; the eyedropper samples the composite (P5) and the fill
/// commits one region-mask dab (P6) — neither starts strokes.
enum CanvasTool { brush, eraser, eyedropper, fill }

/// Whether [tool] paints strokes through the interactive canvas (the
/// non-painting tools mount a tap overlay instead).
bool canvasToolPaints(CanvasTool tool) =>
    tool == CanvasTool.brush || tool == CanvasTool.eraser;

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
    BrushTipMask? dualMask,
    double dualMaskScale = 1.0,
    BrushTipMask? textureMask,
    double textureScale = 1.0,
    double textureDensity = 1.0,
    CanvasTool tool = CanvasTool.brush,
    double stabilizerStrength = 0.0,
    CanvasTool eyedropperReturnTool = CanvasTool.brush,
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
      dualMask: dualMask,
      dualMaskScale: dualMaskScale,
      textureMask: textureMask,
      textureScale: textureScale,
      textureDensity: textureDensity,
      tool: tool,
      stabilizerStrength: stabilizerStrength,
      eyedropperReturnTool: eyedropperReturnTool,
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
    this.dualMask,
    this.dualMaskScale = 1.0,
    this.textureMask,
    this.textureScale = 1.0,
    this.textureDensity = 1.0,
    this.tool = CanvasTool.brush,
    this.stabilizerStrength = 0.0,
    this.eyedropperReturnTool = CanvasTool.brush,
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
    BrushTipMask? dualMask,
    double? dualMaskScale,
    BrushTipMask? textureMask,
    double? textureScale,
    double? textureDensity,
    CanvasTool? tool,
    double? stabilizerStrength,
    CanvasTool? eyedropperReturnTool,
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
      dualMask: dualMask,
      dualMaskScale: clampDualMaskScale(dualMaskScale ?? 1.0),
      textureMask: textureMask,
      textureScale: clampDualMaskScale(textureScale ?? 1.0),
      textureDensity: clampZeroToOne(textureDensity ?? 1.0),
      tool: tool ?? CanvasTool.brush,
      stabilizerStrength: clampStabilizerStrength(stabilizerStrength ?? 0.0),
      eyedropperReturnTool: eyedropperReturnTool ?? CanvasTool.brush,
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
  final BrushTipMask? dualMask;
  final double dualMaskScale;
  final BrushTipMask? textureMask;
  final double textureScale;
  final double textureDensity;

  /// The active canvas tool. Not part of presets ([toBrushSettings] omits
  /// it); applying a preset returns to the brush, CSP-style.
  final CanvasTool tool;

  /// Pull-string stabilization strength (P7), 0..100 screen px of rope.
  /// A HAND-FEEL setting, deliberately outside brush presets — preset
  /// application carries it over unchanged.
  final double stabilizerStrength;

  /// The PAINTING tool to return to after an eyedropper pick (P5, the
  /// CSP behavior); recorded when the eyedropper is entered.
  final CanvasTool eyedropperReturnTool;

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
      dualMask: settings.dualMask,
      dualMaskScale: settings.dualMaskScale,
      textureMask: settings.textureMask,
      textureScale: settings.textureScale,
      textureDensity: settings.textureDensity,
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
      dualMask: dualMask,
      dualMaskScale: dualMaskScale,
      textureMask: textureMask,
      textureScale: textureScale,
      textureDensity: textureDensity,
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
      dualMask: dualMask,
      dualMaskScale: dualMaskScale,
      textureMask: textureMask,
      textureScale: textureScale,
      textureDensity: textureDensity,
      erase: tool == CanvasTool.eraser,
      stabilizerStrength: stabilizerStrength,
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
    BrushTipMask? dualMask,
    double? dualMaskScale,
    BrushTipMask? textureMask,
    double? textureScale,
    double? textureDensity,
    CanvasTool? tool,
    double? stabilizerStrength,
    CanvasTool? eyedropperReturnTool,
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
      dualMask: dualMask ?? this.dualMask,
      dualMaskScale: dualMaskScale ?? this.dualMaskScale,
      textureMask: textureMask ?? this.textureMask,
      textureScale: textureScale ?? this.textureScale,
      textureDensity: textureDensity ?? this.textureDensity,
      tool: tool ?? this.tool,
      stabilizerStrength: stabilizerStrength ?? this.stabilizerStrength,
      eyedropperReturnTool: eyedropperReturnTool ?? this.eyedropperReturnTool,
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

  /// Clamps the dual-mask tile scale to a sane positive range.
  static double clampDualMaskScale(double value) {
    if (!value.isFinite || value <= 0.0) {
      return 1.0;
    }
    return value.clamp(0.05, 10.0).toDouble();
  }

  /// Clamps the stabilizer rope to [0, 100] screen pixels.
  static double clampStabilizerStrength(double value) {
    if (!value.isFinite) {
      return 0.0;
    }
    return value.clamp(0.0, 100.0).toDouble();
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
          other.scatterBothAxes == scatterBothAxes &&
          other.dualMask == dualMask &&
          other.dualMaskScale == dualMaskScale &&
          other.textureMask == textureMask &&
          other.textureScale == textureScale &&
          other.textureDensity == textureDensity &&
          other.tool == tool &&
          other.stabilizerStrength == stabilizerStrength &&
          other.eyedropperReturnTool == eyedropperReturnTool;

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
    dualMask,
    dualMaskScale,
    textureMask,
    textureScale,
    textureDensity,
    tool,
    stabilizerStrength,
    eyedropperReturnTool,
  ]);
}
