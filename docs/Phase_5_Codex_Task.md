# Phase 5 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 5: Canvas Viewport and Basic Drawing.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0, Phase 1, Phase 2, Phase 3, and Phase 4 are already complete.

Current completed foundation:

```text
lib/main.dart
lib/src/models/
lib/src/services/project_repository.dart
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/
lib/src/services/project_json_serializer.dart
lib/src/services/project_file_service.dart
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
* JSON save/load services
* Passing `flutter analyze`
* Passing `flutter test`

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
docs/Phase_2_Codex_Task.md
docs/Phase_3_Codex_Task.md
docs/Phase_4_Codex_Task.md
```

This task implements only Phase 5.

---

## Scope

Implement only:

```text
Phase 5: Canvas Viewport and Basic Drawing
```

The goal is to add a minimal Flutter canvas screen that can display and create basic strokes.

This phase should allow:

1. Open the app
2. See a simple canvas area
3. Drag on the canvas
4. Convert pointer positions into `StrokePoint` values
5. Create a `Stroke`
6. Add that `Stroke` to the current `Frame` using the existing repository/command system where reasonable
7. Display existing strokes on the canvas using `CustomPainter`

This is a minimal drawing MVP.

---

## Very Important Restrictions

Do not implement any of the following:

* Advanced brush engine
* Bitmap raster engine
* Real pixel painting
* Layer compositor
* Timeline UI
* Playback
* Audio
* File picker UI
* Advanced save/load UI
* Provider
* Riverpod
* Bloc
* Complex app-wide state management
* Infinite canvas
* Tile system
* Disk cache
* Playback cache
* PSD compatibility
* Layer masks
* Layer groups
* Blend modes
* Vector editing
* Pressure/tilt/speed brush dynamics
* Stabilization
* Undo/redo UI beyond very small optional debug buttons
* Full production UI

Do not implement Phase 6 or later.

This phase must stay focused on one basic drawable canvas.

---

## Important Design Direction

QuickAnimaker is bitmap-oriented long-term, but this Phase 5 MVP may display model `Stroke` data directly with `CustomPainter`.

That is acceptable for now.

Do not build a full bitmap engine yet.

Do not build a full brush engine yet.

For this phase:

```text
Stroke model data → CustomPainter preview
```

is enough.

Future phases can replace or extend this with bitmap rendering.

---

## Required Folder Structure

Create these folders if needed:

```text
lib/src/ui/
lib/src/ui/canvas/
lib/src/controllers/
```

Expected relevant structure after this phase:

```text
lib/
  main.dart
  src/
    models/
    services/
    controllers/
      canvas_controller.dart
    ui/
      home_page.dart
      canvas/
        canvas_view.dart
        stroke_painter.dart

test/
  controllers/
    canvas_controller_test.dart
  ui/
    canvas_view_test.dart
```

You may adjust exact file names if there is a strong reason, but keep responsibilities separated.

---

## Required Files to Create

Create:

```text
lib/src/controllers/canvas_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/canvas_view.dart
lib/src/ui/canvas/stroke_painter.dart
test/controllers/canvas_controller_test.dart
test/ui/canvas_view_test.dart
```

You may modify:

```text
lib/main.dart
```

only to show the new minimal `HomePage`.

Do not modify model files unless absolutely necessary.

Do not modify persistence, command, history, or repository files unless absolutely necessary.

---

## App Entry Point

Update `lib/main.dart` only enough to show the new `HomePage`.

Expected direction:

```dart
import 'package:flutter/material.dart';

import 'src/ui/home_page.dart';

void main() {
  runApp(const QuickAnimakerApp());
}

class QuickAnimakerApp extends StatelessWidget {
  const QuickAnimakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'QuickAnimaker v2.1',
      home: HomePage(),
    );
  }
}
```

Do not build the final app UI.

Do not add navigation, menus, file pickers, or timeline UI.

---

## Minimal HomePage

Create:

```text
lib/src/ui/home_page.dart
```

Responsibilities:

* Create a small sample project in memory
* Create a `ProjectRepository`
* Create a `HistoryManager`
* Create a `CanvasController`
* Display a simple `CanvasView`
* Optionally display very small debug text showing stroke count

This is allowed to be stateful for Phase 5.

Avoid Provider/Riverpod/Bloc.

A simple `StatefulWidget` with local fields is acceptable.

The sample project should contain:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
```

The user will draw strokes into that single frame.

---

## CanvasController

Create:

```text
lib/src/controllers/canvas_controller.dart
```

Responsibilities:

* Own drawing interaction logic, not UI rendering
* Collect pointer positions during a stroke
* Convert pointer positions to `StrokePoint`
* Create a `Stroke`
* Add the stroke to the target frame
* Use `AddStrokeCommand` and `HistoryManager` if possible
* Expose the current list of strokes for painting
* Provide simple undo/redo methods through `HistoryManager`

Suggested API:

```dart
class CanvasController {
  CanvasController({
    required ProjectRepository repository,
    required HistoryManager historyManager,
    required FrameId frameId,
    BrushSettings brushSettings = const BrushSettings(),
  });

  List<Stroke> get strokes;

  bool get canUndo;
  bool get canRedo;

  void beginStroke(Offset position);

  void updateStroke(Offset position);

  void endStroke();

  void cancelStroke();

  void undo();

  void redo();
}
```

Implementation notes:

* This controller may import Flutter's `Offset`.
* Do not put `Offset` into the model.
* Convert `Offset` to `StrokePoint`.
* Ignore strokes with fewer than 2 points, or handle them consistently.
* Use a simple generated `StrokeId`, such as a timestamp or incrementing counter.
* Keep ID generation simple for now.
* Do not implement pressure, tilt, or advanced brush behavior.
* Do not implement coordinate transforms beyond local canvas coordinates.
* Do not implement zoom/pan unless very simple and non-invasive.
* For this phase, assume canvas coordinates are local widget coordinates.

---

## Stroke Access

`CanvasController.strokes` should find the target frame inside the repository's current project and return its strokes.

It is acceptable to implement a small private helper that searches:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
```

If the frame is not found, return an empty list or throw a clear error.

Prefer throwing in controller methods that mutate.

For read-only painting, returning an empty list is acceptable if it keeps the UI stable.

---

## Drawing Flow

Expected flow:

```text
Pointer down  → beginStroke(localPosition)
Pointer move  → updateStroke(localPosition)
Pointer up    → endStroke()
```

When `endStroke()` is called:

1. Convert collected points to a `Stroke`
2. Execute `AddStrokeCommand` through `HistoryManager`
3. Clear active stroke points
4. Notify UI to repaint

Since this task does not introduce a state management package, the UI can call `setState()` after controller actions.

---

## CanvasView

Create:

```text
lib/src/ui/canvas/canvas_view.dart
```

Responsibilities:

* Display a drawable area
* Handle pointer or gesture events
* Call `CanvasController`
* Repaint when strokes change
* Use `CustomPaint`
* Include current active stroke preview if practical

Suggested constructor:

```dart
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.controller,
  });

  final CanvasController controller;
}
```

Implementation notes:

* Use `Listener`, `GestureDetector`, or similar Flutter pointer handling.
* Use local coordinates.
* Keep it simple.
* Do not implement full pan/zoom yet.
* Do not implement a real timeline.
* Do not implement a layer panel.

---

## StrokePainter

Create:

```text
lib/src/ui/canvas/stroke_painter.dart
```

Responsibilities:

* Paint a white or light background
* Paint existing strokes
* Paint active stroke preview if provided
* Convert `StrokePoint` to Flutter `Offset`
* Use `Canvas.drawLine` or `Path`

Suggested constructor:

```dart
class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.strokes,
    this.activePoints = const [],
  });

  final List<Stroke> strokes;
  final List<StrokePoint> activePoints;

  @override
  void paint(Canvas canvas, Size size) {
    // draw background
    // draw strokes
    // draw active stroke
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activePoints != activePoints;
  }
}
```

Brush rendering:

* Use `BrushSettings.color`
* Use `BrushSettings.size`
* Use `BrushSettings.opacity`
* Draw simple continuous paths
* No pressure/tilt/dynamics

Color handling:

* `BrushSettings.color` is an ARGB int.
* Convert it to Flutter `Color(brushSettings.color)`.
* Apply opacity in a simple way if possible.

---

## Optional Debug Controls

It is acceptable to add simple debug buttons in `HomePage`:

```text
Undo
Redo
Clear is NOT required
```

If implemented:

* Use existing `HistoryManager`
* Keep UI minimal
* Do not create a full toolbar
* Do not create final production UI

---

## Tests

Create tests under:

```text
test/controllers/
test/ui/
```

---

## canvas_controller_test.dart

Required test cases:

### 1. Starts with no strokes

* Create a sample project with one frame
* Create `CanvasController`
* Verify `strokes` is empty

### 2. Draw stroke

* Call `beginStroke`
* Call `updateStroke`
* Call `endStroke`
* Verify the target frame has one stroke
* Verify stroke points match the supplied positions

### 3. Ignore or handle short stroke

* Call `beginStroke`
* Call `endStroke`
* Verify behavior is consistent
* Prefer verifying no stroke is added if fewer than 2 points exist

### 4. Undo stroke

* Draw one stroke
* Call `undo`
* Verify the target frame has no strokes

### 5. Redo stroke

* Draw one stroke
* Undo
* Redo
* Verify the stroke is restored

### 6. Cancel stroke

* Begin and update a stroke
* Cancel it
* End should not add it, or active points should be cleared
* Verify no stroke is added

---

## canvas_view_test.dart

Required test cases:

### 1. CanvasView renders

* Pump a `CanvasView` with a valid controller
* Verify it renders without throwing

### 2. Drag gesture creates stroke

* Pump a simple widget containing `CanvasView`
* Simulate drag gesture
* Verify repository frame has a stroke afterward

Keep widget tests simple.

Do not require golden tests.

Do not add image snapshot tests.

---

## Test Helper Guidance

It is okay to create helper functions inside test files.

Suggested helpers:

```dart
Project createSampleProject()
ProjectRepository createRepositoryWithSampleProject()
CanvasController createCanvasController()
```

Keep helpers inside test files for now.

Do not create shared test helper packages unless necessary.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/controllers lib/src/ui test/controllers test/ui lib/main.dart
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
3. Whether `dart format` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes

---

## Completion Criteria

This task is complete only when:

* `CanvasController` exists
* `CanvasView` exists
* `StrokePainter` exists
* Minimal `HomePage` exists
* `main.dart` shows `HomePage`
* User can draw a simple stroke on the canvas
* Stroke is stored in the current frame
* Existing strokes are painted
* Active stroke preview is painted or drawing remains visually responsive
* Undo/redo works for strokes if debug buttons are implemented
* Controller tests pass
* Canvas widget tests pass
* No advanced brush engine is added
* No bitmap engine is added
* No timeline UI is added
* No layer panel is added
* No playback is added
* No file picker UI is added
* No state management package is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 6.

Do not implement a full drawing engine yet.

Do not implement layer compositing, timeline, playback, file picker UI, infinite canvas, tile system, or state management packages.

This phase is only the first visible canvas and basic stroke drawing MVP.
