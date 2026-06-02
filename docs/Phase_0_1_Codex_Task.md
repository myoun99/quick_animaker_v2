# Phase 0-1 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 0 and Phase 1 only.

---

## Context

This repository is the new Flutter/Dart project for QuickAnimaker v2.1.

QuickAnimaker v2.1 is a bitmap-based 2D animation tool inspired by TVPaint, Clip Studio Paint, and Photoshop.

The long-term architecture is documented in:

```text
docs/Architecture.md
```

The phased implementation plan is documented in:

```text
docs/ImplementationPlan.md
```

Read both documents before making changes.

---

## Scope

Implement only:

```text
Phase 0: Project Initialization
Phase 1: Core Domain Models
```

Do not implement Phase 2 or later.

This task is only about preparing the Flutter project structure and implementing pure Dart domain models.

---

## Very Important Restrictions

Do not implement any of the following:

* UI beyond a minimal `MaterialApp`
* Canvas drawing
* Bitmap drawing
* Brush engine behavior
* Renderer
* Timeline
* Playback
* Undo / redo
* Command system
* Project repository
* State management
* Provider
* Riverpod
* ChangeNotifier
* Persistence service
* File save / load
* Layer compositor
* Cache system
* Infinite canvas
* Tile system

If any of these are already present from the default Flutter template, do not expand them.

---

## Required Result

After this task, the repository should contain:

```text
lib/
  main.dart
  src/
    models/

test/
  models/
```

The main implementation should be under:

```text
lib/src/models/
```

The tests should be under:

```text
test/models/
```

---

## Phase 0 Requirements

### Folder Structure

Create this folder if it does not already exist:

```text
lib/src/models/
```

Keep `lib/main.dart` minimal.

`lib/main.dart` should only define a basic Flutter app with an empty page or placeholder.

Do not build the real application UI yet.

---

## Phase 1 Requirements

Implement the following model files:

```text
lib/src/models/
  project_id.dart
  track_id.dart
  cut_id.dart
  layer_id.dart
  frame_id.dart
  stroke_id.dart

  canvas_size.dart
  brush_settings.dart
  stroke_point.dart

  project.dart
  track.dart
  cut.dart
  layer.dart
  frame.dart
  stroke.dart
```

---

## Typed ID Requirements

Implement these typed ID classes:

```text
ProjectId
TrackId
CutId
LayerId
FrameId
StrokeId
```

Each typed ID class must:

* Wrap a `String value`
* Be immutable
* Have a `const` constructor
* Have `toJson()`
* Have `fromJson()`
* Override `==`
* Override `hashCode`
* Override `toString()`

Example expected style:

```dart
class ProjectId {
  const ProjectId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory ProjectId.fromJson(Map<String, dynamic> json) {
    return ProjectId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
```

You may reduce duplication if appropriate, but do not over-engineer this phase.

---

## Value Object Requirements

### CanvasSize

File:

```text
lib/src/models/canvas_size.dart
```

Fields:

```dart
final int width;
final int height;
```

Requirements:

* Immutable
* `const` constructor
* `copyWith`
* `toJson`
* `fromJson`
* Equality support

### BrushSettings

File:

```text
lib/src/models/brush_settings.dart
```

MVP fields:

```dart
final int color;
final double size;
final double opacity;
```

Suggested defaults:

```text
color = 0xFF000000
size = 4.0
opacity = 1.0
```

Requirements:

* Immutable
* `const` constructor
* `copyWith`
* `toJson`
* `fromJson`
* Equality support

### StrokePoint

File:

```text
lib/src/models/stroke_point.dart
```

Fields:

```dart
final double x;
final double y;
```

Requirements:

* Immutable
* `const` constructor
* `copyWith`
* `toJson`
* `fromJson`
* Equality support

Important:

Do not use Flutter `Offset` in the model layer.
The model layer should remain pure Dart and JSON-friendly.

---

## Core Model Requirements

### Stroke

File:

```text
lib/src/models/stroke.dart
```

Fields:

```dart
final StrokeId id;
final List<StrokePoint> points;
final BrushSettings brushSettings;
```

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`
* Equality support
* Defensive copy / unmodifiable list for `points`

---

### Frame

File:

```text
lib/src/models/frame.dart
```

Fields:

```dart
final FrameId id;
final int duration;
final List<Stroke> strokes;
```

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`
* Equality support
* Defensive copy / unmodifiable list for `strokes`

---

### Layer

File:

```text
lib/src/models/layer.dart
```

Fields:

```dart
final LayerId id;
final String name;
final List<Frame> frames;
final bool isVisible;
final double opacity;
```

Defaults:

```text
isVisible = true
opacity = 1.0
```

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`
* Equality support
* Defensive copy / unmodifiable list for `frames`

---

### Cut

File:

```text
lib/src/models/cut.dart
```

Fields:

```dart
final CutId id;
final String name;
final List<Layer> layers;
final int duration;
final CanvasSize canvasSize;
```

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`
* Equality support
* Defensive copy / unmodifiable list for `layers`

---

### Track

File:

```text
lib/src/models/track.dart
```

Fields:

```dart
final TrackId id;
final String name;
final List<Cut> cuts;
final TrackType type;
```

Also define:

```dart
enum TrackType {
  video,
  audio,
}
```

For this phase, only `TrackType.video` needs to be used.

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`
* Equality support
* Defensive copy / unmodifiable list for `cuts`

---

### Project

File:

```text
lib/src/models/project.dart
```

Fields:

```dart
final ProjectId id;
final String name;
final List<Track> tracks;
final DateTime createdAt;
final int fps;
```

Default:

```text
fps = 24
```

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`
* Equality support
* Defensive copy / unmodifiable list for `tracks`

---

## Immutability Rules

All models must be immutable.

Do not expose mutable lists directly.

Use defensive copies.

Example:

```dart
Project({
  required this.id,
  required this.name,
  required List<Track> tracks,
  required this.createdAt,
  this.fps = 24,
}) : tracks = List.unmodifiable(tracks);
```

When implementing `copyWith`, preserve existing values when arguments are not provided.

---

## JSON Rules

Every model must support JSON round-trip:

```dart
final json = model.toJson();
final restored = Model.fromJson(json);
expect(restored, model);
```

Use simple manual JSON serialization for this phase.

Do not use `json_serializable` code generation unless absolutely necessary.

Reason:

This first phase should stay simple and beginner-friendly.

---

## Equality Rules

Each model should support meaningful equality.

You may implement `==` and `hashCode` manually.

Do not add heavy dependencies unless necessary.

---

## Test Requirements

Create tests under:

```text
test/models/
```

Required test files:

```text
test/models/id_test.dart
test/models/value_objects_test.dart
test/models/project_hierarchy_test.dart
test/models/json_serialization_test.dart
test/models/copy_with_test.dart
```

---

## Required Test Cases

### 1. Typed ID test

Verify:

* Two IDs with the same value are equal
* Two IDs with different values are not equal
* `toJson` and `fromJson` preserve the value

Apply this to all typed IDs.

---

### 2. Value object test

Verify:

* `CanvasSize` can be created
* `BrushSettings` can be created
* `StrokePoint` can be created
* `copyWith` works
* JSON round-trip works

---

### 3. Project hierarchy test

Create this full hierarchy:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

Verify:

* Project contains one Track
* Track contains one Cut
* Cut contains one Layer
* Layer contains one Frame
* Frame contains one Stroke

---

### 4. JSON serialization test

Create a full project hierarchy.

Then:

1. Convert the Project to JSON
2. Restore the Project from JSON
3. Verify that the restored project equals the original project

---

### 5. copyWith test

Verify:

* `copyWith` changes only specified fields
* Original object remains unchanged
* Nested lists are preserved unless replaced

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

* `lib/src/models/` exists
* All required model files exist
* All required test files exist
* Models are immutable
* Typed IDs are implemented
* `copyWith` exists where required
* `toJson` / `fromJson` exists for all models
* Full hierarchy test passes
* JSON round-trip test passes
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 2 or later.

This first task is intentionally small.

The goal is to create a safe and correct foundation before adding state management, undo/redo, persistence, drawing, canvas, timeline, or playback.
