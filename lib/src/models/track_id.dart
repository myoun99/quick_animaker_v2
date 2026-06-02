class TrackId {
  const TrackId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory TrackId.fromJson(Map<String, dynamic> json) {
    return TrackId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TrackId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
