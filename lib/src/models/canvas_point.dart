class CanvasPoint {
  CanvasPoint({required this.x, required this.y}) {
    _validateFiniteCoordinate(x, 'x');
    _validateFiniteCoordinate(y, 'y');
  }

  final double x;
  final double y;

  CanvasPoint copyWith({double? x, double? y}) {
    return CanvasPoint(x: x ?? this.x, y: y ?? this.y);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory CanvasPoint.fromJson(Map<String, dynamic> json) {
    return CanvasPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CanvasPoint(x: $x, y: $y)';
}

void _validateFiniteCoordinate(double value, String fieldName) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      fieldName,
      'CanvasPoint.$fieldName must be finite.',
    );
  }
}
