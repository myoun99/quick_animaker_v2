class BrushSettings {
  const BrushSettings({
    this.color = 0xFF000000,
    this.size = 4.0,
    this.opacity = 1.0,
  });

  final int color;
  final double size;
  final double opacity;

  BrushSettings copyWith({int? color, double? size, double? opacity}) {
    return BrushSettings(
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
    'color': color,
    'size': size,
    'opacity': opacity,
  };

  factory BrushSettings.fromJson(Map<String, dynamic> json) {
    return BrushSettings(
      color: json['color'] as int,
      size: (json['size'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushSettings &&
          other.color == color &&
          other.size == size &&
          other.opacity == opacity;

  @override
  int get hashCode => Object.hash(color, size, opacity);

  @override
  String toString() =>
      'BrushSettings(color: $color, size: $size, opacity: $opacity)';
}
