class FrameId {
  const FrameId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory FrameId.fromJson(Map<String, dynamic> json) {
    return FrameId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FrameId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
