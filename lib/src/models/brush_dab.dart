import 'brush_input_sample.dart';
import 'brush_settings.dart';
import 'brush_tip_shape.dart';
import 'canvas_point.dart';

class BrushDab {
  BrushDab({
    required this.center,
    required this.size,
    required this.opacity,
    required this.flow,
    required this.hardness,
    required this.tipShape,
    required this.pressure,
    required this.sequence,
  }) {
    _validateNonNegativeFinite(size, 'size');
    _validateUnitIntervalFinite(opacity, 'opacity');
    _validateUnitIntervalFinite(flow, 'flow');
    _validateUnitIntervalFinite(hardness, 'hardness');
    _validateUnitIntervalFinite(pressure, 'pressure');
    _validateSequence(sequence);
  }

  factory BrushDab.fromInputSample({
    required BrushInputSample sample,
    required BrushSettings settings,
    required int sequence,
  }) {
    return BrushDab(
      center: CanvasPoint(x: sample.x, y: sample.y),
      size: settings.pressureSize
          ? settings.size * sample.pressure
          : settings.size,
      opacity: settings.pressureOpacity
          ? settings.opacity * sample.pressure
          : settings.opacity,
      flow: settings.flow,
      hardness: settings.hardness,
      tipShape: settings.tipShape,
      pressure: sample.pressure,
      sequence: sequence,
    );
  }

  final CanvasPoint center;
  final double size;
  final double opacity;
  final double flow;
  final double hardness;
  final BrushTipShape tipShape;
  final double pressure;
  final int sequence;

  BrushDab copyWith({
    CanvasPoint? center,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    BrushTipShape? tipShape,
    double? pressure,
    int? sequence,
  }) {
    return BrushDab(
      center: center ?? this.center,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      flow: flow ?? this.flow,
      hardness: hardness ?? this.hardness,
      tipShape: tipShape ?? this.tipShape,
      pressure: pressure ?? this.pressure,
      sequence: sequence ?? this.sequence,
    );
  }

  Map<String, dynamic> toJson() => {
    'center': center.toJson(),
    'size': size,
    'opacity': opacity,
    'flow': flow,
    'hardness': hardness,
    'tipShape': tipShape.toJson(),
    'pressure': pressure,
    'sequence': sequence,
  };

  factory BrushDab.fromJson(Map<String, dynamic> json) {
    return BrushDab(
      center: CanvasPoint.fromJson(json['center'] as Map<String, dynamic>),
      size: (json['size'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      flow: (json['flow'] as num).toDouble(),
      hardness: (json['hardness'] as num).toDouble(),
      tipShape: BrushTipShape.fromJson(json['tipShape']),
      pressure: (json['pressure'] as num).toDouble(),
      sequence: json['sequence'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushDab &&
          other.center == center &&
          other.size == size &&
          other.opacity == opacity &&
          other.flow == flow &&
          other.hardness == hardness &&
          other.tipShape == tipShape &&
          other.pressure == pressure &&
          other.sequence == sequence;

  @override
  int get hashCode => Object.hash(
    center,
    size,
    opacity,
    flow,
    hardness,
    tipShape,
    pressure,
    sequence,
  );

  @override
  String toString() =>
      'BrushDab(center: $center, size: $size, opacity: $opacity, '
      'flow: $flow, hardness: $hardness, tipShape: $tipShape, '
      'pressure: $pressure, sequence: $sequence)';
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

void _validateSequence(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'sequence',
      'BrushDab.sequence must be greater than or equal to 0.',
    );
  }
}
