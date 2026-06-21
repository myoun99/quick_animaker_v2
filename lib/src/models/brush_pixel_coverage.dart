class BrushPixelCoverage {
  BrushPixelCoverage({
    required this.x,
    required this.y,
    required this.coverage,
  }) {
    _validateNonNegative(x, 'x');
    _validateNonNegative(y, 'y');
    _validateCoverage(coverage);
  }

  final int x;
  final int y;
  final double coverage;

  BrushPixelCoverage copyWith({int? x, int? y, double? coverage}) {
    return BrushPixelCoverage(
      x: x ?? this.x,
      y: y ?? this.y,
      coverage: coverage ?? this.coverage,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'coverage': coverage};

  factory BrushPixelCoverage.fromJson(Map<String, dynamic> json) {
    return BrushPixelCoverage(
      x: json['x'] as int,
      y: json['y'] as int,
      coverage: (json['coverage'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushPixelCoverage &&
          other.x == x &&
          other.y == y &&
          other.coverage == coverage;

  @override
  int get hashCode => Object.hash(x, y, coverage);

  @override
  String toString() => 'BrushPixelCoverage(x: $x, y: $y, coverage: $coverage)';
}

void _validateNonNegative(int value, String fieldName) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushPixelCoverage.$fieldName must be greater than or equal to 0.',
    );
  }
}

void _validateCoverage(double value) {
  if (!value.isFinite || value < 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      'coverage',
      'BrushPixelCoverage.coverage must be finite and between 0.0 and 1.0 inclusive.',
    );
  }
}
