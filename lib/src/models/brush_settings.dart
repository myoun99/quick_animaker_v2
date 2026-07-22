import 'brush_pressure_curve.dart';
import 'brush_tip_mask.dart';
import 'brush_tip_rotation_mode.dart';
import 'brush_tip_shape.dart';

class BrushSettings {
  BrushSettings({
    this.color = 0xFF000000,
    this.size = 4.0,
    this.opacity = 1.0,
    this.flow = 1.0,
    this.hardness = 1.0,
    this.spacing = 0.1,
    this.tipShape = BrushTipShape.round,
    this.sizePressureCurve,
    this.opacityPressureCurve,
    this.flowPressureCurve,
    this.hardnessPressureCurve,
    this.roundness = 1.0,
    this.angleDegrees = 0.0,
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
  }) {
    if (!dualMaskScale.isFinite || dualMaskScale <= 0.0) {
      throw ArgumentError.value(
        dualMaskScale,
        'dualMaskScale',
        'BrushSettings.dualMaskScale must be finite and greater than 0.',
      );
    }
    if (!textureScale.isFinite || textureScale <= 0.0) {
      throw ArgumentError.value(
        textureScale,
        'textureScale',
        'BrushSettings.textureScale must be finite and greater than 0.',
      );
    }
    _validateUnitInterval(textureDensity, 'textureDensity');
    _validatePositive(size, 'size');
    _validateUnitInterval(opacity, 'opacity');
    _validateUnitInterval(flow, 'flow');
    _validateUnitInterval(hardness, 'hardness');
    _validatePositive(spacing, 'spacing');
    _validateRoundness(roundness);
    _validateFinite(angleDegrees, 'angleDegrees');
    _validateUnitInterval(sizeJitter, 'sizeJitter');
    _validateUnitInterval(opacityJitter, 'opacityJitter');
    _validateUnitInterval(angleJitter, 'angleJitter');
    _validateNonNegativeFinite(scatterRadiusRatio, 'scatterRadiusRatio');
    if (scatterCount < 1) {
      throw ArgumentError.value(
        scatterCount,
        'scatterCount',
        'BrushSettings.scatterCount must be at least 1.',
      );
    }
  }

  final int color;
  final double size;
  final double opacity;
  final double flow;
  final double hardness;
  final double spacing;
  final BrushTipShape tipShape;

  /// BB-3 (R26 #11): per-setting pen-pressure response — `null` means the
  /// setting ignores pressure. These replaced the pressureSize /
  /// pressureOpacity booleans and the minimumSizeRatio floor (the floor is
  /// now the size curve's left endpoint); [fromJson] migrates the legacy
  /// keys to the equivalent straight-line curves.
  final BrushPressureCurve? sizePressureCurve;
  final BrushPressureCurve? opacityPressureCurve;
  final BrushPressureCurve? flowPressureCurve;
  final BrushPressureCurve? hardnessPressureCurve;

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

  /// Random per-dab size reduction, 0..1 of the base size.
  final double sizeJitter;

  /// Random per-dab opacity reduction, 0..1 of the base opacity.
  final double opacityJitter;

  /// Random per-dab tip rotation, 0..1 of a half turn in each direction.
  final double angleJitter;

  /// Scatter radius as a ratio of the dab size; 0 disables scattering.
  final double scatterRadiusRatio;

  /// Dabs stamped per placement step when scattering.
  final int scatterCount;

  /// Whether scatter offsets spread along both axes or only perpendicular
  /// to the stroke direction.
  final bool scatterBothAxes;

  /// Dual-brush mask multiplying every dab's coverage; tiled at
  /// [dualMaskScale] times the dab size with a random per-dab phase.
  final BrushTipMask? dualMask;
  final double dualMaskScale;

  /// Paper texture tiled in canvas space; see the same fields on `BrushDab`.
  final BrushTipMask? textureMask;
  final double textureScale;
  final double textureDensity;

  /// The pressure curve driving [target], if any.
  BrushPressureCurve? pressureCurveFor(BrushPressureTarget target) {
    return switch (target) {
      BrushPressureTarget.size => sizePressureCurve,
      BrushPressureTarget.opacity => opacityPressureCurve,
      BrushPressureTarget.flow => flowPressureCurve,
      BrushPressureTarget.hardness => hardnessPressureCurve,
    };
  }

  BrushSettings copyWith({
    int? color,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    double? spacing,
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
  }) {
    return BrushSettings(
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      flow: flow ?? this.flow,
      hardness: hardness ?? this.hardness,
      spacing: spacing ?? this.spacing,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'color': color,
    'size': size,
    'opacity': opacity,
    'flow': flow,
    'hardness': hardness,
    'spacing': spacing,
    'tipShape': tipShape.toJson(),
    if (sizePressureCurve != null)
      'sizePressureCurve': sizePressureCurve!.toJson(),
    if (opacityPressureCurve != null)
      'opacityPressureCurve': opacityPressureCurve!.toJson(),
    if (flowPressureCurve != null)
      'flowPressureCurve': flowPressureCurve!.toJson(),
    if (hardnessPressureCurve != null)
      'hardnessPressureCurve': hardnessPressureCurve!.toJson(),
    'roundness': roundness,
    'angleDegrees': angleDegrees,
    if (tipMask != null) 'tipMask': tipMask!.toJson(),
    'rotationMode': rotationMode.toJson(),
    'sizeJitter': sizeJitter,
    'opacityJitter': opacityJitter,
    'angleJitter': angleJitter,
    'scatterRadiusRatio': scatterRadiusRatio,
    'scatterCount': scatterCount,
    'scatterBothAxes': scatterBothAxes,
    if (dualMask != null) 'dualMask': dualMask!.toJson(),
    'dualMaskScale': dualMaskScale,
    if (textureMask != null) 'textureMask': textureMask!.toJson(),
    'textureScale': textureScale,
    'textureDensity': textureDensity,
  };

  factory BrushSettings.fromJson(Map<String, dynamic> json) {
    // Legacy pressure toggles (pre-BB-3) migrate to their equivalent
    // straight-line curves: size ON was `min + (1 - min) * p` (the
    // minimumSizeRatio floor), opacity ON was plain `p`.
    BrushPressureCurve? curveOf(String key) => json[key] == null
        ? null
        : BrushPressureCurve.fromJson(json[key] as List<dynamic>);
    var sizeCurve = curveOf('sizePressureCurve');
    if (sizeCurve == null && json['pressureSize'] == true) {
      sizeCurve = BrushPressureCurve.linearFrom(
        (json['minimumSizeRatio'] as num?)?.toDouble() ?? 0.0,
      );
    }
    var opacityCurve = curveOf('opacityPressureCurve');
    if (opacityCurve == null && json['pressureOpacity'] == true) {
      opacityCurve = BrushPressureCurve.identity();
    }
    return BrushSettings(
      color: json['color'] as int,
      size: (json['size'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      flow: (json['flow'] as num?)?.toDouble() ?? 1.0,
      hardness: (json['hardness'] as num?)?.toDouble() ?? 1.0,
      spacing: (json['spacing'] as num?)?.toDouble() ?? 0.1,
      tipShape: json.containsKey('tipShape')
          ? BrushTipShape.fromJson(json['tipShape'])
          : BrushTipShape.round,
      sizePressureCurve: sizeCurve,
      opacityPressureCurve: opacityCurve,
      flowPressureCurve: curveOf('flowPressureCurve'),
      hardnessPressureCurve: curveOf('hardnessPressureCurve'),
      roundness: (json['roundness'] as num?)?.toDouble() ?? 1.0,
      angleDegrees: (json['angleDegrees'] as num?)?.toDouble() ?? 0.0,
      tipMask: json['tipMask'] == null
          ? null
          : BrushTipMask.fromJson(json['tipMask'] as Map<String, dynamic>),
      rotationMode: BrushTipRotationMode.fromJson(json['rotationMode']),
      sizeJitter: (json['sizeJitter'] as num?)?.toDouble() ?? 0.0,
      opacityJitter: (json['opacityJitter'] as num?)?.toDouble() ?? 0.0,
      angleJitter: (json['angleJitter'] as num?)?.toDouble() ?? 0.0,
      scatterRadiusRatio:
          (json['scatterRadiusRatio'] as num?)?.toDouble() ?? 0.0,
      scatterCount: json['scatterCount'] as int? ?? 1,
      scatterBothAxes: json['scatterBothAxes'] as bool? ?? true,
      dualMask: json['dualMask'] == null
          ? null
          : BrushTipMask.fromJson(json['dualMask'] as Map<String, dynamic>),
      dualMaskScale: (json['dualMaskScale'] as num?)?.toDouble() ?? 1.0,
      textureMask: json['textureMask'] == null
          ? null
          : BrushTipMask.fromJson(json['textureMask'] as Map<String, dynamic>),
      textureScale: (json['textureScale'] as num?)?.toDouble() ?? 1.0,
      textureDensity: (json['textureDensity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushSettings &&
          other.color == color &&
          other.size == size &&
          other.opacity == opacity &&
          other.flow == flow &&
          other.hardness == hardness &&
          other.spacing == spacing &&
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
          other.textureDensity == textureDensity;

  @override
  int get hashCode => Object.hashAll([
    color,
    size,
    opacity,
    flow,
    hardness,
    spacing,
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
  ]);

  @override
  String toString() =>
      'BrushSettings(color: $color, size: $size, opacity: $opacity, '
      'flow: $flow, hardness: $hardness, spacing: $spacing, '
      'tipShape: $tipShape, sizePressureCurve: $sizePressureCurve, '
      'opacityPressureCurve: $opacityPressureCurve, '
      'flowPressureCurve: $flowPressureCurve, '
      'hardnessPressureCurve: $hardnessPressureCurve, '
      'roundness: $roundness, '
      'angleDegrees: $angleDegrees, tipMask: $tipMask, '
      'rotationMode: $rotationMode, '
      'sizeJitter: $sizeJitter, opacityJitter: $opacityJitter, '
      'angleJitter: $angleJitter, scatterRadiusRatio: $scatterRadiusRatio, '
      'scatterCount: $scatterCount, scatterBothAxes: $scatterBothAxes)';
}

void _validatePositive(double value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushSettings.$fieldName must be greater than 0.',
    );
  }
}

void _validateUnitInterval(double value, String fieldName) {
  if (value < 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushSettings.$fieldName must be between 0.0 and 1.0 inclusive.',
    );
  }
}

void _validateRoundness(double value) {
  if (!value.isFinite || value <= 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      'roundness',
      'BrushSettings.roundness must be finite and in (0.0, 1.0].',
    );
  }
}

void _validateFinite(double value, String fieldName) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushSettings.$fieldName must be finite.',
    );
  }
}

void _validateNonNegativeFinite(double value, String fieldName) {
  if (!value.isFinite || value < 0.0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushSettings.$fieldName must be finite and non-negative.',
    );
  }
}
