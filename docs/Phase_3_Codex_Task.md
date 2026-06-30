# Phase 3 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 3: Command-based Undo / Redo MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0, Phase 1, and Phase 2 are already complete.

Current completed foundation:

```text
lib/main.dart
lib/src/models/
lib/src/services/project_repository.dart
test/models/
test/services/project_repository_test.dart
docs/
```

The project already has:

* Immutable domain models
* Typed IDs
* JSON support
* `copyWith` support
* `ProjectRepository`
* Repository methods for adding Track, Cut, Layer, Frame, and Stroke
* Passing `flutter analyze`
* Passing `flutter test`

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
docs/Phase_2_Codex_Task.md
```

This task implements only Phase 3.

---

## Scope

Implement only:

```text
Phase 3: Command-based Undo / Redo MVP
```

The goal is to introduce a simple command system and linear undo/redo manager.

This phase should allow project mutations to be performed through command objects that can be undone and redone.

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
* File save / load
* Persistence service
* Provider
* Riverpod
* Bloc
* Flutter UI beyond the existing minimal `MaterialApp`
* Layer compositor
* Cache system
* Infinite canvas
* Tile system
* Persistent history
* Branching history
* Snapshot/delta history

Do not implement Phase 4 or later.

This phase must stay focused on a simple command-based undo/redo system.

---

## Required Folder Structure

Create this folder if it does not already exist:

```text
lib/src/services/commands/
```

Add tests under:

```text
test/services/
```

Expected relevant structure after this phase:

```text
lib/
  src/
    services/
      project_repository.dart
      command.dart
      history_manager.dart
      commands/
        add_track_command.dart
        add_cut_command.dart
        add_layer_command.dart
        add_frame_command.dart
        add_stroke_command.dart

test/
  services/
    project_repository_test.dart
    history_manager_test.dart
    commands_test.dart
```

---

## Required Files to Create

Create:

```text
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/add_track_command.dart
lib/src/services/commands/add_cut_command.dart
lib/src/services/commands/add_layer_command.dart
lib/src/services/commands/add_frame_command.dart
lib/src/services/commands/add_stroke_command.dart
test/services/history_manager_test.dart
test/services/commands_test.dart
```

You may adjust test file organization if needed, but equivalent coverage is required.

---

## Command Interface

Create:

```text
lib/src/services/command.dart
```

Define a simple abstract command interface.

Suggested API:

```dart
abstract class Command {
  String get description;

  void execute();

  void undo();
}
```

Rules:

* `execute()` applies the change.
* `undo()` reverts the change.
* Commands should be small and focused.
* Commands should not know about UI.
* Commands should not perform file I/O.
* Commands should not implement redo separately. Redo can call `execute()` again.

---

## HistoryManager

Create:

```text
lib/src/services/history_manager.dart
```

`HistoryManager` should manage two stacks:

```text
undoStack
redoStack
```

Suggested API:

```dart
class HistoryManager {
  bool get canUndo;
  bool get canRedo;

  int get undoCount;
  int get redoCount;

  void execute(Command command);

  void undo();

  void redo();

  void clear();
}
```

Behavior:

### execute(command)

* Calls `command.execute()`
* Pushes command to undo stack
* Clears redo stack

### undo()

* If undo stack is empty, throw `StateError`
* Pop latest command from undo stack
* Call `command.undo()`
* Push command to redo stack

### redo()

* If redo stack is empty, throw `StateError`
* Pop latest command from redo stack
* Call `command.execute()`
* Push command back to undo stack

### clear()

* Clears both stacks

---

## Command Implementation Strategy

Commands should use `ProjectRepository`.

Each command should store enough information to undo itself.

Important:

For this MVP, commands may store the previous `Project` snapshot before executing.

This is acceptable for Phase 3.

Example pattern:

```dart
class SomeCommand implements Command {
  SomeCommand(this.repository);

  final ProjectRepository repository;

  Project? _previousProject;

  @override
  void execute() {
    _previousProject = repository.requireProject();
    // perform mutation through repository
  }

  @override
  void undo() {
    final previousProject = _previousProject;
    if (previousProject == null) {
      throw StateError('Command has not been executed.');
    }
    repository.replaceProject(previousProject);
  }
}
```

This simple snapshot approach is allowed for the MVP.

Do not implement delta-based undo.

Do not implement persistent history.

Do not implement history compression.

---

## Required Commands

### AddTrackCommand

File:

```text
lib/src/services/commands/add_track_command.dart
```

Responsibilities:

* Add a `Track` to the current project
* Undo restores the previous project

Suggested constructor:

```dart
AddTrackCommand({
  required ProjectRepository repository,
  required Track track,
});
```

---

### AddCutCommand

File:

```text
lib/src/services/commands/add_cut_command.dart
```

Responsibilities:

* Add a `Cut` to a target `Track`
* Undo restores the previous project

Suggested constructor:

```dart
AddCutCommand({
  required ProjectRepository repository,
  required TrackId trackId,
  required Cut cut,
});
```

---

### AddLayerCommand

File:

```text
lib/src/services/commands/add_layer_command.dart
```

Responsibilities:

* Add a `Layer` to a target `Cut`
* Undo restores the previous project

Suggested constructor:

```dart
AddLayerCommand({
  required ProjectRepository repository,
  required CutId cutId,
  required Layer layer,
});
```

---

### AddFrameCommand

File:

```text
lib/src/services/commands/add_frame_command.dart
```

Responsibilities:

* Add a `Frame` to a target `Layer`
* Undo restores the previous project

Suggested constructor:

```dart
AddFrameCommand({
  required ProjectRepository repository,
  required LayerId layerId,
  required Frame frame,
});
```

---

### AddStrokeCommand

File:

```text
lib/src/services/commands/add_stroke_command.dart
```

Responsibilities:

* Add a `Stroke` to a target `Frame`
* Undo restores the previous project

Suggested constructor:

```dart
AddStrokeCommand({
  required ProjectRepository repository,
  required FrameId frameId,
  required Stroke stroke,
});
```

---

## Error Handling

If a command is undone before it has been executed, throw:

```dart
StateError('Command has not been executed.')
```

If repository operations fail because the target is missing, allow the repository exception to surface.

Do not silently fail.

---

## Tests

Create tests for `HistoryManager` and commands.

### history_manager_test.dart

Required test cases:

1. Starts empty

Verify:

* `canUndo` is false
* `canRedo` is false
* `undoCount` is 0
* `redoCount` is 0

2. Execute command

Use a simple fake command.

Verify:

* `execute()` is called
* `canUndo` becomes true
* `canRedo` remains false
* `undoCount` is 1
* `redoCount` is 0

3. Undo command

Verify:

* `undo()` is called
* `canUndo` becomes false
* `canRedo` becomes true
* `undoCount` is 0
* `redoCount` is 1

4. Redo command

Verify:

* `execute()` is called again
* `canUndo` becomes true
* `canRedo` becomes false

5. Execute clears redo stack

Steps:

* Execute command A
* Undo command A
* Execute command B
* Verify redo stack is cleared

6. Undo with empty stack throws

7. Redo with empty stack throws

8. Clear empties both stacks

---

### commands_test.dart

Required test cases:

1. AddTrackCommand

* Execute adds track
* Undo removes track by restoring previous project
* Redo through `HistoryManager.redo()` adds it again

2. AddCutCommand

* Execute adds cut to target track
* Undo restores previous project
* Redo adds cut again

3. AddLayerCommand

* Execute adds layer to target cut
* Undo restores previous project
* Redo adds layer again

4. AddFrameCommand

* Execute adds frame to target layer
* Undo restores previous project
* Redo adds frame again

5. AddStrokeCommand

* Execute adds stroke to target frame
* Undo restores previous project
* Redo adds stroke again

6. Undo before execute throws

Test at least one command directly by calling `undo()` before `execute()`.

7. Missing target propagates error

Example:

* AddCutCommand with missing TrackId should throw when executed.

---

## Test Helper Guidance

It is okay to create small helper functions inside the test file.

Examples:

```dart
Project createProject()
Track createTrack()
Cut createCut()
Layer createLayer()
Frame createFrame()
Stroke createStroke()
```

Keep helpers inside test files for now.

Do not create shared test helper packages unless necessary.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib test
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `dart format` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes

---

## Completion Criteria

This task is complete only when:

* `Command` interface exists
* `HistoryManager` exists
* AddTrackCommand exists
* AddCutCommand exists
* AddLayerCommand exists
* AddFrameCommand exists
* AddStrokeCommand exists
* Commands use `ProjectRepository`
* Commands support execute and undo
* HistoryManager supports execute, undo, redo, clear
* Redo stack is cleared after new command execution
* Undo/redo error cases are tested
* Command tests cover Track, Cut, Layer, Frame, and Stroke
* No UI feature is added
* No persistence is added
* No canvas/drawing engine is added
* No state management package is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 4.

Do not implement save/load.

Do not implement canvas, drawing, renderer, playback, timeline UI, or state management.

This phase is only the simple command-based undo/redo MVP.
