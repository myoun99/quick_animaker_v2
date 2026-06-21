class BrushPresetId {
  const BrushPresetId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory BrushPresetId.fromJson(Map<String, dynamic> json) {
    return BrushPresetId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BrushPresetId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
