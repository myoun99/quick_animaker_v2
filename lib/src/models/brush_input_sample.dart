class BrushInputSample {
  BrushInputSample({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.sequence = 0,
  }) {
    _validateFiniteCoordinate(x, 'x');
    _validateFiniteCoordinate(y, 'y');
    _validatePressure(pressure);
    _validateSequence(sequence);
  }

  final double x;
  final double y;
  final double pressure;
  final int sequence;

  BrushInputSample copyWith({
    double? x,
    double? y,
    double? pressure,
    int? sequence,
  }) {
    return BrushInputSample(
      x: x ?? this.x,
      y: y ?? this.y,
      pressure: pressure ?? this.pressure,
      sequence: sequence ?? this.sequence,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'pressure': pressure,
    'sequence': sequence,
  };

  factory BrushInputSample.fromJson(Map<String, dynamic> json) {
    return BrushInputSample(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 1.0,
      sequence: json['sequence'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushInputSample &&
          other.x == x &&
          other.y == y &&
          other.pressure == pressure &&
          other.sequence == sequence;

  @override
  int get hashCode => Object.hash(x, y, pressure, sequence);

  @override
  String toString() =>
      'BrushInputSample(x: $x, y: $y, pressure: $pressure, '
      'sequence: $sequence)';
}

void _validateFiniteCoordinate(double value, String fieldName) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushInputSample.$fieldName must be finite.',
    );
  }
}

void _validatePressure(double value) {
  if (value < 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      'pressure',
      'BrushInputSample.pressure must be between 0.0 and 1.0 inclusive.',
    );
  }
}

void _validateSequence(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'sequence',
      'BrushInputSample.sequence must be greater than or equal to 0.',
    );
  }
}
