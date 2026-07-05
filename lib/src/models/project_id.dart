import 'string_id.dart';

final class ProjectId extends StringId {
  const ProjectId(super.value);

  factory ProjectId.fromJson(Map<String, dynamic> json) =>
      ProjectId(json['value'] as String);
}
