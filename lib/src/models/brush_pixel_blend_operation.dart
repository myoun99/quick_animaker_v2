import 'rgba_color.dart';

class BrushPixelBlendOperation {
  BrushPixelBlendOperation({
    required this.x,
    required this.y,
    required this.before,
    required this.after,
  }) {
    _validateNonNegative(x, 'x');
    _validateNonNegative(y, 'y');
    _validateColorChange(before: before, after: after);
  }

  final int x;
  final int y;
  final RgbaColor before;
  final RgbaColor after;

  BrushPixelBlendOperation copyWith({
    int? x,
    int? y,
    RgbaColor? before,
    RgbaColor? after,
  }) {
    return BrushPixelBlendOperation(
      x: x ?? this.x,
      y: y ?? this.y,
      before: before ?? this.before,
      after: after ?? this.after,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'before': before.toJson(),
    'after': after.toJson(),
  };

  factory BrushPixelBlendOperation.fromJson(Map<String, dynamic> json) {
    return BrushPixelBlendOperation(
      x: json['x'] as int,
      y: json['y'] as int,
      before: RgbaColor.fromJson(json['before'] as Map<String, dynamic>),
      after: RgbaColor.fromJson(json['after'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushPixelBlendOperation &&
          other.x == x &&
          other.y == y &&
          other.before == before &&
          other.after == after;

  @override
  int get hashCode => Object.hash(x, y, before, after);

  @override
  String toString() =>
      'BrushPixelBlendOperation(x: $x, y: $y, before: $before, after: $after)';
}

void _validateNonNegative(int value, String fieldName) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'BrushPixelBlendOperation.$fieldName must be greater than or equal to 0.',
    );
  }
}

void _validateColorChange({required RgbaColor before, required RgbaColor after}) {
  if (before == after) {
    throw ArgumentError.value(
      after,
      'after',
      'BrushPixelBlendOperation.after must differ from before.',
    );
  }
}
