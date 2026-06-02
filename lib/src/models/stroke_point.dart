class StrokePoint {
  const StrokePoint({required this.x, required this.y});

  final double x;
  final double y;

  StrokePoint copyWith({double? x, double? y}) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StrokePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'StrokePoint(x: $x, y: $y)';
}
