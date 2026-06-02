class CutId {
  const CutId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory CutId.fromJson(Map<String, dynamic> json) {
    return CutId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CutId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
