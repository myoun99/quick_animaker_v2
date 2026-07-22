import '../../models/brush_blend_mode.dart';
import '../../models/brush_pressure_curve.dart';
import '../../models/brush_settings.dart';
import '../../models/brush_tip_mask.dart';
import '../../models/brush_tip_rotation_mode.dart';
import '../../models/brush_tip_shape.dart';
import '../canvas/brush_edit_canvas_input_settings.dart';

/// Which canvas tool the pointer drives. The eraser reuses every brush
/// option (size, hardness, tip) but its dabs remove alpha instead of
/// painting color; the eyedropper samples the composite (P5), the fill
/// commits one region-mask dab (P6), the selection tools (P9: rect
/// marquee / freehand lasso) drag out a region, and the MOVE tool
/// (R11-⑧: selection ≠ move) drags the selected content — none of them
/// start strokes.
enum CanvasTool { brush, eraser, eyedropper, fill, selectRect, lasso, move }

/// Whether [tool] paints strokes through the interactive canvas (the
/// non-painting tools mount a tool overlay instead).
bool canvasToolPaints(CanvasTool tool) =>
    tool == CanvasTool.brush || tool == CanvasTool.eraser;

/// Whether [tool] mounts the selection interaction layer (the P9
/// marquee/lasso tools and the move tool that drags their region).
bool canvasToolSelects(CanvasTool tool) =>
    tool == CanvasTool.selectRect ||
    tool == CanvasTool.lasso ||
    tool == CanvasTool.move;

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
    BrushPressureCurve? sizePressureCurve,
    BrushPressureCurve? opacityPressureCurve,
    BrushPressureCurve? flowPressureCurve,
    BrushPressureCurve? hardnessPressureCurve,
    double roundness = defaultRoundness,
    double angleDegrees = defaultAngleDegrees,
    BrushTipMask? tipMask,
    BrushTipRotationMode rotationMode = BrushTipRotationMode.fixed,
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
    BrushBlendMode brushBlendMode = BrushBlendMode.color,
  }) {
    return BrushToolState.clamped(
      size: size,
      opacity: opacity,
      color: color,
      spacing: spacing,
      hardness: hardness,
      flow: flow,
      tipShape: tipShape,
      sizePressureCurve: sizePressureCurve,
      opacityPressureCurve: opacityPressureCurve,
      flowPressureCurve: flowPressureCurve,
      hardnessPressureCurve: hardnessPressureCurve,
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
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
      brushBlendMode: brushBlendMode,
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
    this.sizePressureCurve,
    this.opacityPressureCurve,
    this.flowPressureCurve,
    this.hardnessPressureCurve,
    required this.roundness,
    required this.angleDegrees,
    this.tipMask,
    this.rotationMode = BrushTipRotationMode.fixed,
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
    this.brushBlendMode = BrushBlendMode.color,
  });

  factory BrushToolState.clamped({
    double? size,
    double? opacity,
    int? color,
    double? spacing,
    double? hardness,
    double? flow,
    BrushTipShape? tipShape,
    BrushPressureCurve? sizePressureCurve,
    BrushPressureCurve? opacityPressureCurve,
    BrushPressureCurve? flowPressureCurve,
    BrushPressureCurve? hardnessPressureCurve,
    double? roundness,
    double? angleDegrees,
    BrushTipMask? tipMask,
    BrushTipRotationMode? rotationMode,
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
    BrushBlendMode? brushBlendMode,
  }) {
    return BrushToolState._raw(
      size: clampSize(size ?? defaultSize),
      opacity: clampOpacity(opacity ?? defaultOpacity),
      color: color ?? defaultColor,
      spacing: clampSpacing(spacing ?? defaultSpacing),
      hardness: clampUnit(hardness ?? defaultHardness),
      flow: clampUnit(flow ?? defaultFlow),
      tipShape: tipShape ?? defaultTipShape,
      sizePressureCurve: sizePressureCurve,
      opacityPressureCurve: opacityPressureCurve,
      flowPressureCurve: flowPressureCurve,
      hardnessPressureCurve: hardnessPressureCurve,
      roundness: clampRoundness(roundness ?? defaultRoundness),
      angleDegrees: clampAngleDegrees(angleDegrees ?? defaultAngleDegrees),
      tipMask: tipMask,
      rotationMode: rotationMode ?? BrushTipRotationMode.fixed,
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
      brushBlendMode: brushBlendMode ?? BrushBlendMode.color,
    );
  }

  static const double minSize = 1.0;
  // CSP-parity ceiling; the settings slider maps this range exponentially so
  // the small sizes keep their precision.
  static const double maxSize = 2000.0;
  static const double defaultSize = 10.0;
  static const double defaultOpacity = 1.0;
  static const int defaultColor = 0xFF000000;
  static const double minSpacing = 0.05;
  static const double maxSpacing = 4.0;
  static const double defaultSpacing = 0.25;
  static const double defaultHardness = 1.0;
  static const double defaultFlow = 1.0;
  static const BrushTipShape defaultTipShape = BrushTipShape.round;
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

  /// BB-3 (R26 #11): per-setting pen-pressure response curves; `null` =
  /// the setting ignores pressure. Part of brush presets (they travel
  /// through [toBrushSettings]/[fromBrushSettings] like the sliders).
  /// [copyWith] PRESERVES them (same contract as [tipMask]); clearing one
  /// goes through [withPressureCurve].
  final BrushPressureCurve? sizePressureCurve;
  final BrushPressureCurve? opacityPressureCurve;
  final BrushPressureCurve? flowPressureCurve;
  final BrushPressureCurve? hardnessPressureCurve;

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

  /// The BRUSH's own composite mode (BB-1, R26 #9). Like the stabilizer
  /// — and like [size] since R26 #10 — a HAND setting outside brush
  /// presets: picking another brush never flips it.
  final BrushBlendMode brushBlendMode;

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
      sizePressureCurve: settings.sizePressureCurve,
      opacityPressureCurve: settings.opacityPressureCurve,
      flowPressureCurve: settings.flowPressureCurve,
      hardnessPressureCurve: settings.hardnessPressureCurve,
      roundness: settings.roundness,
      angleDegrees: settings.angleDegrees,
      tipMask: settings.tipMask,
      rotationMode: settings.rotationMode,
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
      sizePressureCurve: sizePressureCurve,
      opacityPressureCurve: opacityPressureCurve,
      flowPressureCurve: flowPressureCurve,
      hardnessPressureCurve: hardnessPressureCurve,
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
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
      sizePressureCurve: sizePressureCurve,
      opacityPressureCurve: opacityPressureCurve,
      flowPressureCurve: flowPressureCurve,
      hardnessPressureCurve: hardnessPressureCurve,
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
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
      // The eraser tool IS the erase blend (locked); a brush whose blend
      // is erase rides the SAME dab flag and kernels.
      erase:
          tool == CanvasTool.eraser ||
          brushBlendMode == BrushBlendMode.erase,
      blendMode: tool == CanvasTool.eraser
          ? BrushBlendMode.erase
          : brushBlendMode,
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
    BrushPressureCurve? sizePressureCurve,
    BrushPressureCurve? opacityPressureCurve,
    BrushPressureCurve? flowPressureCurve,
    BrushPressureCurve? hardnessPressureCurve,
    double? roundness,
    double? angleDegrees,
    BrushTipMask? tipMask,
    BrushTipRotationMode? rotationMode,
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
    BrushBlendMode? brushBlendMode,
  }) {
    return BrushToolState.clamped(
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      spacing: spacing ?? this.spacing,
      hardness: hardness ?? this.hardness,
      flow: flow ?? this.flow,
      tipShape: tipShape ?? this.tipShape,
      sizePressureCurve: sizePressureCurve ?? this.sizePressureCurve,
      opacityPressureCurve: opacityPressureCurve ?? this.opacityPressureCurve,
      flowPressureCurve: flowPressureCurve ?? this.flowPressureCurve,
      hardnessPressureCurve:
          hardnessPressureCurve ?? this.hardnessPressureCurve,
      roundness: roundness ?? this.roundness,
      angleDegrees: angleDegrees ?? this.angleDegrees,
      tipMask: tipMask ?? this.tipMask,
      rotationMode: rotationMode ?? this.rotationMode,
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
      brushBlendMode: brushBlendMode ?? this.brushBlendMode,
    );
  }

  /// The pressure curve driving [target], if any.
  BrushPressureCurve? pressureCurveFor(BrushPressureTarget target) {
    return switch (target) {
      BrushPressureTarget.size => sizePressureCurve,
      BrushPressureTarget.opacity => opacityPressureCurve,
      BrushPressureTarget.flow => flowPressureCurve,
      BrushPressureTarget.hardness => hardnessPressureCurve,
    };
  }

  /// Replaces (or CLEARS, with null) one setting's pressure curve —
  /// [copyWith] deliberately preserves curves, so disabling pressure on a
  /// setting comes through here.
  BrushToolState withPressureCurve(
    BrushPressureTarget target,
    BrushPressureCurve? curve,
  ) {
    return BrushToolState.clamped(
      size: size,
      opacity: opacity,
      color: color,
      spacing: spacing,
      hardness: hardness,
      flow: flow,
      tipShape: tipShape,
      sizePressureCurve: target == BrushPressureTarget.size
          ? curve
          : sizePressureCurve,
      opacityPressureCurve: target == BrushPressureTarget.opacity
          ? curve
          : opacityPressureCurve,
      flowPressureCurve: target == BrushPressureTarget.flow
          ? curve
          : flowPressureCurve,
      hardnessPressureCurve: target == BrushPressureTarget.hardness
          ? curve
          : hardnessPressureCurve,
      roundness: roundness,
      angleDegrees: angleDegrees,
      tipMask: tipMask,
      rotationMode: rotationMode,
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
      brushBlendMode: brushBlendMode,
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
          other.sizePressureCurve == sizePressureCurve &&
          other.opacityPressureCurve == opacityPressureCurve &&
          other.flowPressureCurve == flowPressureCurve &&
          other.hardnessPressureCurve == hardnessPressureCurve &&
          other.roundness == roundness &&
          other.angleDegrees == angleDegrees &&
          other.tipMask == tipMask &&
          other.rotationMode == rotationMode &&
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
          // BB-3 audit fix: brushBlendMode was MISSING from ==/hashCode
          // since BB-1 — two states differing only in blend compared
          // equal, so listeners could skip rebuilding on a blend change.
          other.brushBlendMode == brushBlendMode;

  @override
  int get hashCode => Object.hashAll([
    size,
    opacity,
    color,
    spacing,
    hardness,
    flow,
    tipShape,
    sizePressureCurve,
    opacityPressureCurve,
    flowPressureCurve,
    hardnessPressureCurve,
    roundness,
    angleDegrees,
    tipMask,
    rotationMode,
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
    brushBlendMode,
  ]);
}
