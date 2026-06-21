class TileCoord {
  TileCoord({required this.x, required this.y}) {
    _validateNonNegative(x, 'x');
    _validateNonNegative(y, 'y');
  }

  factory TileCoord.fromPixel({
    required int pixelX,
    required int pixelY,
    required int tileSize,
  }) {
    _validateNonNegative(pixelX, 'pixelX');
    _validateNonNegative(pixelY, 'pixelY');
    _validatePositive(tileSize, 'tileSize');
    return TileCoord(x: pixelX ~/ tileSize, y: pixelY ~/ tileSize);
  }

  final int x;
  final int y;

  TileCoord copyWith({int? x, int? y}) {
    return TileCoord(x: x ?? this.x, y: y ?? this.y);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory TileCoord.fromJson(Map<String, dynamic> json) {
    return TileCoord(x: json['x'] as int, y: json['y'] as int);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoord && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TileCoord(x: $x, y: $y)';
}

void _validateNonNegative(int value, String fieldName) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'TileCoord.$fieldName must be greater than or equal to 0.',
    );
  }
}

void _validatePositive(int value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'TileCoord.$fieldName must be greater than 0.',
    );
  }
}
