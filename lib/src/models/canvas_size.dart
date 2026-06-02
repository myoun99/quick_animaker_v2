class CanvasSize {
  const CanvasSize({required this.width, required this.height});

  final int width;
  final int height;

  CanvasSize copyWith({int? width, int? height}) {
    return CanvasSize(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
      };

  factory CanvasSize.fromJson(Map<String, dynamic> json) {
    return CanvasSize(
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'CanvasSize(width: $width, height: $height)';
}
