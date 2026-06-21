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
  }) {
    _validatePositive(size, 'size');
    _validateUnitInterval(opacity, 'opacity');
    _validateUnitInterval(flow, 'flow');
    _validateUnitInterval(hardness, 'hardness');
    _validatePositive(spacing, 'spacing');
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
          other.pressureOpacity == pressureOpacity;

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
  );

  @override
  String toString() =>
      'BrushSettings(color: $color, size: $size, opacity: $opacity, '
      'flow: $flow, hardness: $hardness, spacing: $spacing, '
      'tipShape: $tipShape, pressureSize: $pressureSize, '
      'pressureOpacity: $pressureOpacity)';
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
