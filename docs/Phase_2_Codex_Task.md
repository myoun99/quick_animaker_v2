# Phase 2 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 2: Project State and Repository.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 and Phase 1 are already complete.

The project currently has:

```text
lib/main.dart
lib/src/models/
test/models/
docs/
```

The core immutable domain models already exist:

```text
Project
Track
Cut
Layer
Frame
Stroke
CanvasSize
BrushSettings
StrokePoint

ProjectId
TrackId
CutId
LayerId
FrameId
StrokeId
```

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
```

This task implements only Phase 2.

---

## Scope

Implement only:

```text
Phase 2: Project State / Repository
```

The goal is to add a simple project state/repository layer that owns the current `Project` and provides safe immutable update APIs.

This phase should prepare the project for later command-based undo/redo, but must not implement undo/redo yet.

---

## Very Important Restrictions

Do not implement any of the following:

* Canvas drawing
* Bitmap drawing
* Brush engine behavior
* Renderer
* Timeline UI
* Playback
* Undo / redo
* Command system
* HistoryManager
* Persistence service
* File save / load
* Provider
* Riverpod
* Bloc
* Flutter UI beyond the existing minimal `MaterialApp`
* Layer compositor
* Cache system
* Infinite canvas
* Tile system

Do not implement Phase 3 or later.

This task must stay focused on a pure repository/state layer.

---

## Required Folder Structure

Create this folder:

```text
lib/src/services/
```

Add tests under:

```text
test/services/
```

Expected final relevant structure:

```text
lib/
  main.dart
  src/
    models/
    services/
      project_repository.dart

test/
  models/
  services/
    project_repository_test.dart
```

---

## Main File to Create

Create:

```text
lib/src/services/project_repository.dart
```

---

## ProjectRepository Responsibilities

`ProjectRepository` is responsible for holding the current project state.

It should:

* Store the current `Project?`
* Expose the current project through a getter
* Create a new project
* Replace the current project with a new immutable `Project`
* Clear the current project
* Add a `Track` to the current project
* Add a `Cut` to a specific `Track`
* Add a `Layer` to a specific `Cut`
* Add a `Frame` to a specific `Layer`
* Add a `Stroke` to a specific `Frame`

All updates must preserve immutability.

Do not mutate existing model lists directly.

Use `copyWith` and new lists.

---

## Required Public API

The exact implementation can vary, but the repository should provide APIs similar to the following:

```dart
class ProjectRepository {
  Project? get currentProject;

  bool get hasProject;

  Project createProject({
    required ProjectId id,
    required String name,
    DateTime? createdAt,
    int fps = 24,
  });

  void setProject(Project project);

  void clearProject();

  Project requireProject();

  void addTrack(Track track);

  void addCut({
    required TrackId trackId,
    required Cut cut,
  });

  void addLayer({
    required CutId cutId,
    required Layer layer,
  });

  void addFrame({
    required LayerId layerId,
    required Frame frame,
  });

  void addStroke({
    required FrameId frameId,
    required Stroke stroke,
  });
}
```

The method names may be adjusted if there is a better naming style, but the same functionality must exist.

---

## Error Handling

If an operation requires a project but no project exists, throw a clear exception.

Example:

```dart
StateError('No project is currently loaded.');
```

If a target object is not found, throw a clear exception.

Examples:

```dart
ArgumentError('Track not found: $trackId')
ArgumentError('Cut not found: $cutId')
ArgumentError('Layer not found: $layerId')
ArgumentError('Frame not found: $frameId')
```

Do not silently fail.

Do not create missing parent objects automatically.

---

## Immutability Rules

All updates must create new immutable model objects.

For example, when adding a `Track`:

* Do not mutate `project.tracks`
* Create a new list from `project.tracks`
* Add the new track to that list
* Replace the current project with `project.copyWith(tracks: updatedTracks)`

For nested updates, rebuild the necessary parent chain.

Example for adding a `Stroke`:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

When a Stroke is added to a Frame:

1. Create updated Frame
2. Create updated Layer containing updated Frame
3. Create updated Cut containing updated Layer
4. Create updated Track containing updated Cut
5. Create updated Project containing updated Track
6. Replace current project

Do not add parent references to child models.

Do not introduce circular references.

---

## No State Management Packages

Do not use:

```text
Provider
Riverpod
ChangeNotifier
ValueNotifier
Bloc
```

This repository should be a plain Dart class.

UI reactivity will be handled later.

---

## No Undo / Redo

Do not create:

```text
Command
HistoryManager
undoStack
redoStack
```

Phase 3 will introduce command-based undo/redo.

Phase 2 should only provide repository operations that Phase 3 can later call.

---

## No Persistence

Do not implement file save/load.

Do not use:

```text
dart:io
path_provider
shared_preferences
database
```

JSON support already exists in the models, but this phase must not save files.

---

## Tests

Create:

```text
test/services/project_repository_test.dart
```

---

## Required Test Cases

### 1. Initial State

Verify:

* A new `ProjectRepository` has no current project
* `hasProject` is false
* `requireProject()` throws a `StateError`

---

### 2. Create Project

Verify:

* `createProject` creates a project
* `currentProject` is set
* `hasProject` is true
* Project name, id, fps, and createdAt are correct

---

### 3. Set and Clear Project

Verify:

* `setProject` replaces the current project
* `clearProject` removes the current project
* `hasProject` becomes false after clearing

---

### 4. Add Track

Verify:

* Adding a track increases project track count
* The added track exists in the project
* The original project instance is not mutated

---

### 5. Add Cut to Track

Verify:

* Adding a cut to an existing track works
* The target track contains the new cut
* Other tracks remain unchanged
* Adding a cut to a missing track throws an error

---

### 6. Add Layer to Cut

Verify:

* Adding a layer to an existing cut works
* The target cut contains the new layer
* Other cuts remain unchanged
* Adding a layer to a missing cut throws an error

---

### 7. Add Frame to Layer

Verify:

* Adding a frame to an existing layer works
* The target layer contains the new frame
* Other layers remain unchanged
* Adding a frame to a missing layer throws an error

---

### 8. Add Stroke to Frame

Verify:

* Adding a stroke to an existing frame works
* The target frame contains the new stroke
* Other frames remain unchanged
* Adding a stroke to a missing frame throws an error

---

### 9. Nested Immutability

Create a full hierarchy.

Store references to the original:

```text
Project
Track
Cut
Layer
Frame
```

Then add a Stroke.

Verify:

* Repository current project changed
* Updated frame contains the new stroke
* Original project instance did not change
* Original frame instance did not change
* Existing unaffected branches remain logically equal

---

## Suggested Test Helper

It is okay to create small helper functions inside the test file to build sample objects.

Example:

```dart
Project createSampleProject()
Track createSampleTrack()
Cut createSampleCut()
Layer createSampleLayer()
Frame createSampleFrame()
Stroke createSampleStroke()
```

Keep helpers inside the test file unless there is a strong reason to share them.

---

## Analyze and Test

After implementation, run:

```bash
flutter analyze
flutter test
```

Both must pass.

If either fails, fix the code until both pass.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `flutter analyze` passed
4. Whether `flutter test` passed
5. Any important implementation notes

---

## Completion Criteria

This task is complete only when:

* `lib/src/services/project_repository.dart` exists
* `test/services/project_repository_test.dart` exists
* `ProjectRepository` is a plain Dart class
* Repository can create, set, clear, and return a project
* Repository can add Track, Cut, Layer, Frame, and Stroke
* Missing target errors are tested
* Nested immutable updates are tested
* No UI features are added
* No undo/redo is added
* No persistence is added
* No state management package is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 3.

Do not implement command-based undo/redo yet.

This task should only create a safe project state/repository layer on top of the immutable domain models.
