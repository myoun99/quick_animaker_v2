class StrokeId {
  const StrokeId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory StrokeId.fromJson(Map<String, dynamic> json) {
    return StrokeId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StrokeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
