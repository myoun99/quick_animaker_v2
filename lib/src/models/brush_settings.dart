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
  }) {
    if (!dualMaskScale.isFinite || dualMaskScale <= 0.0) {
      throw ArgumentError.value(
        dualMaskScale,
        'dualMaskScale',
        'BrushSettings.dualMaskScale must be finite and greater than 0.',
      );
    }
    _validatePositive(size, 'size');
    _validateUnitInterval(opacity, 'opacity');
    _validateUnitInterval(flow, 'flow');
    _validateUnitInterval(hardness, 'hardness');
    _validatePositive(spacing, 'spacing');
    _validateRoundness(roundness);
    _validateFinite(angleDegrees, 'angleDegrees');
    _validateUnitInterval(minimumSizeRatio, 'minimumSizeRatio');
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
  final bool pressureSize;
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

  /// Size floor for pressure scaling, as a ratio of [size]: with pressure
  /// enabled, effective size = size * (min + (1 - min) * pressure).
  final double minimumSizeRatio;

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

  BrushSettings copyWith({
    int? color,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    double? spacing,
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
  }) {
    return BrushSettings(
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      flow: flow ?? this.flow,
      hardness: hardness ?? this.hardness,
      spacing: spacing ?? this.spacing,
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
    'pressureSize': pressureSize,
    'pressureOpacity': pressureOpacity,
    'roundness': roundness,
    'angleDegrees': angleDegrees,
    if (tipMask != null) 'tipMask': tipMask!.toJson(),
    'rotationMode': rotationMode.toJson(),
    'minimumSizeRatio': minimumSizeRatio,
    'sizeJitter': sizeJitter,
    'opacityJitter': opacityJitter,
    'angleJitter': angleJitter,
    'scatterRadiusRatio': scatterRadiusRatio,
    'scatterCount': scatterCount,
    'scatterBothAxes': scatterBothAxes,
    if (dualMask != null) 'dualMask': dualMask!.toJson(),
    'dualMaskScale': dualMaskScale,
  };

  factory BrushSettings.fromJson(Map<String, dynamic> json) {
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
      pressureSize: json['pressureSize'] as bool? ?? false,
      pressureOpacity: json['pressureOpacity'] as bool? ?? false,
      roundness: (json['roundness'] as num?)?.toDouble() ?? 1.0,
      angleDegrees: (json['angleDegrees'] as num?)?.toDouble() ?? 0.0,
      tipMask: json['tipMask'] == null
          ? null
          : BrushTipMask.fromJson(json['tipMask'] as Map<String, dynamic>),
      rotationMode: BrushTipRotationMode.fromJson(json['rotationMode']),
      minimumSizeRatio:
          (json['minimumSizeRatio'] as num?)?.toDouble() ?? 0.0,
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
    spacing,
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
  ]);

  @override
  String toString() =>
      'BrushSettings(color: $color, size: $size, opacity: $opacity, '
      'flow: $flow, hardness: $hardness, spacing: $spacing, '
      'tipShape: $tipShape, pressureSize: $pressureSize, '
      'pressureOpacity: $pressureOpacity, roundness: $roundness, '
      'angleDegrees: $angleDegrees, tipMask: $tipMask, '
      'rotationMode: $rotationMode, minimumSizeRatio: $minimumSizeRatio, '
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
