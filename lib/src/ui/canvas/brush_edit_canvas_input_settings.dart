import '../../models/brush_tip_mask.dart';
import '../../models/brush_tip_rotation_mode.dart';
import '../../models/brush_tip_shape.dart';

class BrushEditCanvasInputSettings {
  const BrushEditCanvasInputSettings({
    this.color = 0xFF000000,
    this.size = 1.0,
    this.opacity = 1.0,
    this.flow = 1.0,
    this.hardness = 1.0,
    this.tipShape = BrushTipShape.round,
    this.spacing = 0.25,
    this.pressureSize = false,
    this.pressureOpacity = false,
    this.roundness = 1.0,
    this.angleDegrees = 0.0,
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
  }) : assert(size > 0.0, 'BrushEditCanvasInputSettings.size must be > 0.'),
       assert(
         dualMaskScale > 0.0,
         'BrushEditCanvasInputSettings.dualMaskScale must be > 0.',
       ),
       assert(
         minimumSizeRatio >= 0.0 && minimumSizeRatio <= 1.0,
         'BrushEditCanvasInputSettings.minimumSizeRatio must be in [0, 1].',
       ),
       assert(
         scatterRadiusRatio >= 0.0,
         'BrushEditCanvasInputSettings.scatterRadiusRatio must be >= 0.',
       ),
       assert(
         scatterCount >= 1,
         'BrushEditCanvasInputSettings.scatterCount must be at least 1.',
       ),
       assert(
         roundness > 0.0 && roundness <= 1.0,
         'BrushEditCanvasInputSettings.roundness must be in (0, 1].',
       ),
       assert(
         opacity >= 0.0 && opacity <= 1.0,
         'BrushEditCanvasInputSettings.opacity must be between 0 and 1.',
       ),
       assert(
         flow >= 0.0 && flow <= 1.0,
         'BrushEditCanvasInputSettings.flow must be between 0 and 1.',
       ),
       assert(
         hardness >= 0.0 && hardness <= 1.0,
         'BrushEditCanvasInputSettings.hardness must be between 0 and 1.',
       ),
       assert(
         spacing > 0.0,
         'BrushEditCanvasInputSettings.spacing must be > 0.',
       );

  final int color;
  final double size;
  final double opacity;
  final double flow;
  final double hardness;
  final BrushTipShape tipShape;
  final double spacing;

  /// When true, each dab's size is scaled by the input pressure (linear).
  final bool pressureSize;

  /// When true, each dab's opacity is scaled by the input pressure (linear).
  final bool pressureOpacity;

  /// Minor-to-major axis ratio of the tip in (0, 1]; 1.0 is the classic
  /// circle/square.
  final double roundness;

  /// Visual counterclockwise rotation of the tip's major axis from the
  /// horizontal, in degrees.
  final double angleDegrees;

  /// Sampled (bitmap) tip; when set it overrides [tipShape] and [hardness].
  final BrushTipMask? tipMask;

  /// How dab angles are chosen at placement time.
  final BrushTipRotationMode rotationMode;

  /// Size floor for pressure scaling, as a ratio of [size].
  final double minimumSizeRatio;

  /// Random per-dab size reduction, 0..1.
  final double sizeJitter;

  /// Random per-dab opacity reduction, 0..1.
  final double opacityJitter;

  /// Random per-dab tip rotation, 0..1 of a half turn in each direction.
  final double angleJitter;

  /// Scatter radius as a ratio of the dab size; 0 disables scattering.
  final double scatterRadiusRatio;

  /// Dabs stamped per placement step when scattering.
  final int scatterCount;

  /// Whether scatter spreads on both axes or only across the stroke.
  final bool scatterBothAxes;

  /// Dual-brush mask multiplying every dab's coverage; tiled at
  /// [dualMaskScale] times the dab size with a random per-dab phase.
  final BrushTipMask? dualMask;
  final double dualMaskScale;

  BrushEditCanvasInputSettings copyWith({
    int? color,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    BrushTipShape? tipShape,
    double? spacing,
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
  }) {
    return BrushEditCanvasInputSettings(
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      flow: flow ?? this.flow,
      hardness: hardness ?? this.hardness,
      tipShape: tipShape ?? this.tipShape,
      spacing: spacing ?? this.spacing,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditCanvasInputSettings &&
          other.color == color &&
          other.size == size &&
          other.opacity == opacity &&
          other.flow == flow &&
          other.hardness == hardness &&
          other.tipShape == tipShape &&
          other.spacing == spacing &&
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
          other.dualMaskScale == dualMaskScale;

  @override
  int get hashCode => Object.hashAll([
    color,
    size,
    opacity,
    flow,
    hardness,
    tipShape,
    spacing,
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
  ]);

  @override
  String toString() =>
      'BrushEditCanvasInputSettings(color: $color, size: $size, '
      'opacity: $opacity, flow: $flow, hardness: $hardness, '
      'tipShape: $tipShape, spacing: $spacing, '
      'pressureSize: $pressureSize, pressureOpacity: $pressureOpacity, '
      'roundness: $roundness, angleDegrees: $angleDegrees, '
      'tipMask: $tipMask, rotationMode: $rotationMode, '
      'minimumSizeRatio: $minimumSizeRatio, sizeJitter: $sizeJitter, '
      'opacityJitter: $opacityJitter, angleJitter: $angleJitter, '
      'scatterRadiusRatio: $scatterRadiusRatio, '
      'scatterCount: $scatterCount, scatterBothAxes: $scatterBothAxes)';
}
