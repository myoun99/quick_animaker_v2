import 'dart:convert';

import '../models/project.dart';

class ProjectJsonSerializer {
  const ProjectJsonSerializer();

  String encode(Project project) {
    return jsonEncode(project.toJson());
  }

  Project decode(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Project JSON must be an object.');
    }

    return Project.fromJson(decoded);
  }
}
