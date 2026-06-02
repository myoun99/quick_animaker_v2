class ProjectId {
  const ProjectId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory ProjectId.fromJson(Map<String, dynamic> json) {
    return ProjectId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProjectId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
