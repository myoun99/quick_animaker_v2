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
  }) {
    _validatePositive(size, 'size');
    _validateUnitInterval(opacity, 'opacity');
    _validateUnitInterval(flow, 'flow');
    _validateUnitInterval(hardness, 'hardness');
    _validatePositive(spacing, 'spacing');
    _validateRoundness(roundness);
    _validateFinite(angleDegrees, 'angleDegrees');
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
          other.angleDegrees == angleDegrees;

  @override
  int get hashCode => Object.hash(
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
  );

  @override
  String toString() =>
      'BrushSettings(color: $color, size: $size, opacity: $opacity, '
      'flow: $flow, hardness: $hardness, spacing: $spacing, '
      'tipShape: $tipShape, pressureSize: $pressureSize, '
      'pressureOpacity: $pressureOpacity, roundness: $roundness, '
      'angleDegrees: $angleDegrees)';
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
