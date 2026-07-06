import 'brush_input_sample.dart';
import 'brush_settings.dart';
import 'brush_tip_mask.dart';
import 'brush_tip_shape.dart';
import 'canvas_point.dart';

class BrushDab {
  BrushDab({
    required this.center,
    required this.color,
    required this.size,
    required this.opacity,
    required this.flow,
    required this.hardness,
    required this.tipShape,
    required this.pressure,
    required this.sequence,
    this.roundness = 1.0,
    this.angleDegrees = 0.0,
    this.tipMask,
  }) {
    _validateColor(color);
    _validateNonNegativeFinite(size, 'size');
    _validateUnitIntervalFinite(opacity, 'opacity');
    _validateUnitIntervalFinite(flow, 'flow');
    _validateUnitIntervalFinite(hardness, 'hardness');
    _validateUnitIntervalFinite(pressure, 'pressure');
    _validateRoundness(roundness);
    _validateFinite(angleDegrees, 'angleDegrees');
    _validateSequence(sequence);
  }

  factory BrushDab.fromInputSample({
    required BrushInputSample sample,
    required BrushSettings settings,
    required int sequence,
  }) {
    return BrushDab(
      center: CanvasPoint(x: sample.x, y: sample.y),
      color: settings.color,
      // Pressure scales size down to the minimum-size floor (Photoshop's
      // "minimum diameter"), so light strokes never vanish entirely.
      size: settings.pressureSize
          ? settings.size *
                (settings.minimumSizeRatio +
                    (1.0 - settings.minimumSizeRatio) * sample.pressure)
          : settings.size,
      opacity: settings.pressureOpacity
          ? settings.opacity * sample.pressure
          : settings.opacity,
      flow: settings.flow,
      hardness: settings.hardness,
      tipShape: settings.tipShape,
      pressure: sample.pressure,
      sequence: sequence,
      roundness: settings.roundness,
      angleDegrees: settings.angleDegrees,
      tipMask: settings.tipMask,
    );
  }

  final CanvasPoint center;
  final int color;
  final double size;
  final double opacity;
  final double flow;
  final double hardness;
  final BrushTipShape tipShape;
  final double pressure;
  final int sequence;

  /// Minor-to-major axis ratio of the tip in (0, 1]: 1.0 keeps the classic
  /// circle/square, smaller values flatten it into an ellipse/rectangle.
  final double roundness;

  /// Visual counterclockwise rotation of the tip's major axis from the
  /// horizontal, in degrees. Meaningless for a full-round circle.
  final double angleDegrees;

  /// Sampled (bitmap) tip; when set it overrides [tipShape] and [hardness]
  /// and coverage comes from bilinear-sampling the mask in tip space.
  final BrushTipMask? tipMask;

  BrushDab copyWith({
    CanvasPoint? center,
    int? color,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    BrushTipShape? tipShape,
    double? pressure,
    int? sequence,
    double? roundness,
    double? angleDegrees,
    BrushTipMask? tipMask,
  }) {
    return BrushDab(
      center: center ?? this.center,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      flow: flow ?? this.flow,
      hardness: hardness ?? this.hardness,
      tipShape: tipShape ?? this.tipShape,
      pressure: pressure ?? this.pressure,
      sequence: sequence ?? this.sequence,
      roundness: roundness ?? this.roundness,
      angleDegrees: angleDegrees ?? this.angleDegrees,
      tipMask: tipMask ?? this.tipMask,
    );
  }

  Map<String, dynamic> toJson() => {
    'center': center.toJson(),
    'color': color,
    'size': size,
    'opacity': opacity,
    'flow': flow,
    'hardness': hardness,
    'tipShape': tipShape.toJson(),
    'pressure': pressure,
    'sequence': sequence,
    'roundness': roundness,
    'angleDegrees': angleDegrees,
    if (tipMask != null) 'tipMask': tipMask!.toJson(),
  };

  factory BrushDab.fromJson(Map<String, dynamic> json) {
    return BrushDab(
      center: CanvasPoint.fromJson(json['center'] as Map<String, dynamic>),
      color: json['color'] as int? ?? 0xFF000000,
      size: (json['size'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      flow: (json['flow'] as num).toDouble(),
      hardness: (json['hardness'] as num).toDouble(),
      tipShape: BrushTipShape.fromJson(json['tipShape']),
      pressure: (json['pressure'] as num).toDouble(),
      sequence: json['sequence'] as int,
      roundness: (json['roundness'] as num?)?.toDouble() ?? 1.0,
      angleDegrees: (json['angleDegrees'] as num?)?.toDouble() ?? 0.0,
      tipMask: json['tipMask'] == null
          ? null
          : BrushTipMask.fromJson(json['tipMask'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushDab &&
          other.center == center &&
          other.color == color &&
          other.size == size &&
          other.opacity == opacity &&
          other.flow == flow &&
          other.hardness == hardness &&
          other.tipShape == tipShape &&
          other.pressure == pressure &&
          other.sequence == sequence &&
          other.roundness == roundness &&
          other.angleDegrees == angleDegrees &&
          other.tipMask == tipMask;

  @override
  int get hashCode => Object.hash(
    center,
    color,
    size,
    opacity,
    flow,
    hardness,
    tipShape,
    pressure,
    sequence,
    roundness,
    angleDegrees,
    tipMask,
  );

  @override
  String toString() =>
      'BrushDab(center: $center, color: $color, size: $size, '
      'opacity: $opacity, flow: $flow, hardness: $hardness, '
      'tipShape: $tipShape, pressure: $pressure, sequence: $sequence, '
      'roundness: $roundness, angleDegrees: $angleDegrees, '
      'tipMask: $tipMask)';
}

void _validateColor(int value) {
  if (value < 0 || value > 0xFFFFFFFF) {
    throw ArgumentError.value(
      value,
      'color',
      'BrushDab.color must be between 0 and 0xFFFFFFFF inclusive.',
    );
  }
}

void _validateNonNegativeFinite(double value, String fieldName) {
  if (!value.isFinite || value < 0.0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushDab.$fieldName must be finite and greater than or equal to 0.0.',
    );
  }
}

void _validateUnitIntervalFinite(double value, String fieldName) {
  if (!value.isFinite || value < 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushDab.$fieldName must be finite and between 0.0 and 1.0 inclusive.',
    );
  }
}

void _validateRoundness(double value) {
  if (!value.isFinite || value <= 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      'roundness',
      'BrushDab.roundness must be finite and in (0.0, 1.0].',
    );
  }
}

void _validateFinite(double value, String fieldName) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushDab.$fieldName must be finite.',
    );
  }
}

void _validateSequence(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'sequence',
      'BrushDab.sequence must be greater than or equal to 0.',
    );
  }
}
