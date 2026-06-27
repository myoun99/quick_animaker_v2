class BrushPaintCommandId {
  const BrushPaintCommandId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushPaintCommandId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
