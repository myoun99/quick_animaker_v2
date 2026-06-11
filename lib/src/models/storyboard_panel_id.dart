class StoryboardPanelId {
  const StoryboardPanelId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory StoryboardPanelId.fromJson(Map<String, dynamic> json) {
    return StoryboardPanelId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryboardPanelId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
