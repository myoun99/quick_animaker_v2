# Phase 4 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 4: Basic Save / Load.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0, Phase 1, Phase 2, and Phase 3 are already complete.

Current completed foundation:

```text
lib/main.dart
lib/src/models/
lib/src/services/project_repository.dart
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/
test/models/
test/services/
docs/
```

The project already has:

* Immutable domain models
* Typed IDs
* JSON support on models
* `copyWith` support
* `ProjectRepository`
* Command-based undo/redo MVP
* Passing `flutter analyze`
* Passing `flutter test`

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
docs/Phase_2_Codex_Task.md
docs/Phase_3_Codex_Task.md
```

This task implements only Phase 4.

---

## Scope

Implement only:

```text
Phase 4: Basic Save / Load
```

The goal is to add a simple JSON-based project serialization and persistence layer.

This phase should allow:

1. Convert a `Project` to a JSON string
2. Restore a `Project` from a JSON string
3. Save a `Project` JSON string to a file path
4. Load a `Project` JSON string from a file path
5. Optionally connect loaded projects to `ProjectRepository`

This is a simple MVP persistence layer.

---

## Very Important Restrictions

Do not implement any of the following:

* Canvas UI
* Drawing UI
* Bitmap engine
* Brush engine behavior
* Renderer
* Timeline UI
* Playback
* Provider
* Riverpod
* Bloc
* Layer compositor
* Cache system
* Infinite canvas
* Tile system
* Persistent history
* Branching history
* Snapshot/delta history
* Binary project format
* Zip/archive project format
* Cloud saving
* Database storage
* Autosave
* Recent files UI

Do not implement Phase 5 or later.

This phase must stay focused on basic JSON save/load.

---

## Required Folder Structure

Use the existing services folder:

```text
lib/src/services/
```

Expected relevant structure after this phase:

```text
lib/
  src/
    services/
      project_json_serializer.dart
      project_file_service.dart
      project_repository.dart
      command.dart
      history_manager.dart
      commands/

test/
  services/
    project_json_serializer_test.dart
    project_file_service_test.dart
```

---

## Required Files to Create

Create:

```text
lib/src/services/project_json_serializer.dart
lib/src/services/project_file_service.dart
test/services/project_json_serializer_test.dart
test/services/project_file_service_test.dart
```

Do not modify model files unless absolutely necessary.

Do not modify UI files.

Do not modify command/history files unless absolutely necessary.

---

## ProjectJsonSerializer

Create:

```text
lib/src/services/project_json_serializer.dart
```

Responsibilities:

* Convert `Project` to JSON string
* Convert JSON string to `Project`
* Use existing `Project.toJson()`
* Use existing `Project.fromJson()`
* Use Dart's built-in `dart:convert`

Suggested API:

```dart
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
```

Implementation notes:

* `encode` should return a valid JSON string.
* `decode` should throw a clear error for invalid JSON.
* `decode` should throw a clear error if the root JSON value is not an object.
* Do not silently return an empty project.
* Do not catch every error and hide the original problem.
* Manual schema migration is not required in Phase 4.

---

## ProjectFileService

Create:

```text
lib/src/services/project_file_service.dart
```

Responsibilities:

* Save project JSON to a file path
* Load project JSON from a file path
* Use `ProjectJsonSerializer`
* Use Dart `dart:io`

Suggested API:

```dart
import 'dart:io';

import '../models/project.dart';
import 'project_json_serializer.dart';

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
}
```

Implementation notes:

* This service may use `dart:io`.
* This service should not use Flutter UI APIs.
* This service should not use file picker UI.
* This service should not use `path_provider`.
* This service should not save binary data.
* This service should not manage recent files.
* This service should not implement autosave.
* This service should not use a database.
* Missing file errors may be allowed to surface naturally.
* Invalid JSON errors may be allowed to surface naturally.

---

## Optional Repository Integration

It is acceptable to add small convenience methods if useful:

```dart
Future<void> saveCurrentProject({
  required ProjectRepository repository,
  required String filePath,
})

Future<Project> loadIntoRepository({
  required ProjectRepository repository,
  required String filePath,
})
```

But this is optional.

If implemented:

* `saveCurrentProject` should call `repository.requireProject()`
* `loadIntoRepository` should load a project and call `repository.replaceProject(project)`
* Keep these methods in `ProjectFileService`
* Do not add UI
* Do not add file picker
* Do not add state management

---

## Tests

Create tests under:

```text
test/services/
```

---

## project_json_serializer_test.dart

Required test cases:

### 1. Encode project

Create a full hierarchy:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

Then:

* Encode the project to JSON string
* Verify the result is not empty
* Verify the JSON string can be decoded by `jsonDecode`
* Verify known fields exist, such as project name and fps

### 2. Decode project

Create a full project.

Then:

* Encode it
* Decode it
* Verify restored project equals original project

### 3. Invalid JSON throws

Call:

```dart
serializer.decode('not json');
```

Verify it throws a `FormatException`.

### 4. Non-object JSON throws

Call:

```dart
serializer.decode('[1, 2, 3]');
```

Verify it throws a `FormatException`.

---

## project_file_service_test.dart

Required test cases:

Use a temporary directory.

In Dart tests, this can be done with:

```dart
final tempDir = Directory.systemTemp.createTempSync();
```

Remember to clean up:

```dart
addTearDown(() {
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
});
```

### 1. Save project to file

* Create a sample project
* Save it to a temporary file path
* Verify the file exists
* Verify the file content is not empty

### 2. Load project from file

* Create a sample project
* Save it to a temporary file path
* Load it
* Verify loaded project equals original project

### 3. Missing file throws

* Attempt to load from a path that does not exist
* Verify an exception is thrown

### 4. Invalid file content throws

* Write invalid JSON manually to a temporary file
* Attempt to load it
* Verify a `FormatException` is thrown

### 5. Optional repository integration test

If `loadIntoRepository` is implemented:

* Create a repository
* Save a project to file
* Load it into the repository
* Verify `repository.currentProject` equals the saved project

If `saveCurrentProject` is implemented:

* Create a repository with a project
* Save current project
* Verify file exists and can be loaded

---

## Test Helper Guidance

It is okay to create helper functions inside test files.

Suggested helpers:

```dart
Project createSampleProject()
Track createSampleTrack()
Cut createSampleCut()
Layer createSampleLayer()
Frame createSampleFrame()
Stroke createSampleStroke()
```

Keep helpers inside test files for now.

Do not create shared test helper packages unless necessary.

---

## Error Handling Rules

For this phase:

* Invalid JSON should throw `FormatException`
* Non-object JSON should throw `FormatException`
* Missing files may throw `FileSystemException`
* Repository with no project should throw `StateError` if saving current project
* Do not swallow errors
* Do not return null when loading fails
* Do not create a blank project on load failure

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/services test/services
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

Do not run `dart format lib test` unless necessary, because that may reformat unrelated files.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `dart format lib/src/services test/services` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes

---

## Completion Criteria

This task is complete only when:

* `ProjectJsonSerializer` exists
* `ProjectFileService` exists
* Project can be encoded to JSON string
* Project can be decoded from JSON string
* Project can be saved to a file path
* Project can be loaded from a file path
* Invalid JSON is tested
* Non-object JSON is tested
* Missing file behavior is tested
* Invalid file content is tested
* No UI feature is added
* No file picker is added
* No canvas/drawing engine is added
* No state management package is added
* No persistent history is added
* No advanced project format is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 5.

Do not implement canvas, drawing, renderer, playback, timeline UI, file picker UI, or state management.

This phase is only the basic JSON save/load MVP.
