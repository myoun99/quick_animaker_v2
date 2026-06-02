import 'dart:io';

import '../models/project.dart';
import 'project_json_serializer.dart';
import 'project_repository.dart';

class ProjectFileService {
  const ProjectFileService({
    this.serializer = const ProjectJsonSerializer(),
  });

  final ProjectJsonSerializer serializer;

  Future<void> saveProject({
    required Project project,
    required String filePath,
  }) async {
    final jsonString = serializer.encode(project);
    final file = File(filePath);
    await file.writeAsString(jsonString);
  }

  Future<Project> loadProject({
    required String filePath,
  }) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    return serializer.decode(jsonString);
  }

  Future<void> saveCurrentProject({
    required ProjectRepository repository,
    required String filePath,
  }) async {
    await saveProject(
      project: repository.requireProject(),
      filePath: filePath,
    );
  }

  Future<Project> loadIntoRepository({
    required ProjectRepository repository,
    required String filePath,
  }) async {
    final project = await loadProject(filePath: filePath);
    repository.replaceProject(project);
    return project;
  }
}
