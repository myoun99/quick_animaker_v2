# QuickAnimaker v2.1 Implementation Plan

## 1. Purpose

This document defines the implementation plan for QuickAnimaker v2.1.

The goal is not to build a full TVPaint-level application immediately.

The first goal is to build a small, stable, working vertical slice:

1. Create a new project
2. Create a track
3. Create a cut
4. Create a layer
5. Create a frame
6. Add a simple stroke to a frame
7. Support undo / redo
8. Save and load the project
9. Display a basic timeline
10. Play frames at the project FPS

The project must be implemented in small safe phases.

Each phase must keep the app runnable and testable.

---

## 2. MVP Scope

The MVP should include only the minimum features required to prove the core architecture.

### Included in MVP

* Flutter project structure
* Core immutable domain models
* Typed IDs
* Basic project state management
* Command-based undo / redo
* Basic JSON save / load
* Limited-size canvas
* Simple bitmap drawing
* Simple round brush
* Basic layer support
* Basic timeline view
* Basic cut / track management
* Basic frame display cache
* Basic playback
* Integration and stabilization

### Excluded from MVP

The following features must not be implemented during the MVP unless explicitly assigned in a later phase:

* Full PSD compatibility
* Advanced layer groups
* Layer masks
* Clipping layers
* Adjustment layers
* Full Photoshop-level brush engine
* Texture brushes
* Pressure / tilt / speed dynamics
* Full infinite canvas
* Tile-based storage
* Persistent infinite history UI
* Snapshot + delta storage
* History branching
* 100k frame optimization
* Timeline virtualization
* Audio editing
* 3D camera system
* Vector layer system
* Cloud saving
* Collaboration

---

## 3. Development Rules

### 3.1 Do not implement future phases early

Codex must only implement the phase currently assigned.

For example:

* Phase 1 must not implement undo / redo
* Phase 1 must not implement drawing
* Phase 1 must not implement persistence
* Phase 1 must not implement UI
* Phase 1 must not implement state management

### 3.2 Keep each phase testable

Every phase should include tests when possible.

Before completing a phase, run:

```bash
flutter analyze
flutter test
```

Both should pass.

### 3.3 Prefer simple working code over over-engineering

The architecture is large, but the MVP should be small.

Do not build advanced systems before the vertical slice works.

### 3.4 Preserve the core hierarchy

The data hierarchy must remain:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

### 3.5 Avoid God Objects

Do not create a single manager that owns everything.

Avoid large classes such as:

* ProjectManager
* AppManager
* EngineManager
* CanvasManager
* HistoryService with too many responsibilities
* Renderer with too many responsibilities

Split responsibilities into models, services, controllers, and UI.

---

# Phase 0: Project Initialization

## Goal

Initialize the Flutter project and prepare the basic folder structure.

This phase should not implement real application features.

## Files / Folders

```text
lib/
  main.dart
  src/
    models/

test/
docs/
```

## Tasks

* Create Flutter project
* Create `docs/` folder
* Create `lib/src/models/` folder
* Keep `lib/main.dart` minimal
* Ensure the project runs
* Ensure the default test/analyze setup works

## Main Requirements

`lib/main.dart` should contain only a minimal Flutter app.

No real UI should be implemented yet.

## Completion Criteria

* Flutter project exists
* `docs/` folder exists
* `lib/src/models/` folder exists
* `flutter analyze` passes
* `flutter test` passes

## Do Not Do

* Do not implement canvas
* Do not implement drawing
* Do not implement timeline
* Do not implement undo / redo
* Do not implement persistence
* Do not implement state management
* Do not implement controllers
* Do not implement services

---

# Phase 1: Core Domain Models

## Goal

Implement the core immutable domain models.

This phase defines the data foundation for the project.

## Required Model Files

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

  project.dart
  track.dart
  cut.dart
  layer.dart
  frame.dart
  stroke.dart
```

## Required Models

### ProjectId / TrackId / CutId / LayerId / FrameId / StrokeId

Typed ID classes.

Each class should:

* Wrap a `String value`
* Be immutable
* Provide `toJson`
* Provide `fromJson`
* Override `==`
* Override `hashCode`
* Override `toString`

Do not use raw string IDs throughout the models.

### CanvasSize

Fields:

* `int width`
* `int height`

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

### BrushSettings

MVP fields may be simple.

Suggested fields:

* `int color`
* `double size`
* `double opacity`

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

No advanced brush dynamics in Phase 1.

### Stroke

Fields:

* `StrokeId id`
* `List<StrokePoint> points`
* `BrushSettings brushSettings`

Because Flutter `Offset` is not ideal for pure JSON domain models, prefer a custom value object:

```text
StrokePoint
  double x
  double y
```

`StrokePoint` should support:

* `copyWith`
* `toJson`
* `fromJson`

### Frame

Fields:

* `FrameId id`
* `int duration`
* `List<Stroke> strokes`

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

### Layer

Fields:

* `LayerId id`
* `String name`
* `List<Frame> frames`
* `bool isVisible`
* `double opacity`

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

Default values:

* `isVisible = true`
* `opacity = 1.0`

### Cut

Fields:

* `CutId id`
* `String name`
* `List<Layer> layers`
* `int duration`
* `CanvasSize canvasSize`

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

### Track

Fields:

* `TrackId id`
* `String name`
* `List<Cut> cuts`
* `TrackType type`

Suggested enum:

```dart
enum TrackType {
  video,
  audio,
}
```

For MVP, only `video` is required.

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

### Project

Fields:

* `ProjectId id`
* `String name`
* `List<Track> tracks`
* `DateTime createdAt`
* `int fps`

Requirements:

* Immutable
* `copyWith`
* `toJson`
* `fromJson`

Suggested default:

* `fps = 24`

---

## Phase 1 Design Rules

### Immutable data only

Do not mutate lists directly.

Use defensive copies where needed.

Example:

```dart
List.unmodifiable(tracks)
```

### No circular references

Allowed:

```text
Project contains List<Track>
Track contains List<Cut>
Cut contains List<Layer>
Layer contains List<Frame>
Frame contains List<Stroke>
```

Not allowed:

```text
Stroke references Frame
Frame references Layer
Layer references Cut
Cut references Track
Track references Project
```

### No Flutter UI dependency in models

The domain models should not depend on Flutter widgets.

Avoid importing Flutter UI libraries in models.

If point data is needed, use a custom `StrokePoint` model instead of `Offset`.

### No state management

Do not use:

* Provider
* Riverpod
* ChangeNotifier
* ValueNotifier
* Bloc

These belong to later phases.

### No persistence service

`toJson` and `fromJson` are allowed.

File saving and loading are not allowed in Phase 1.

### No undo / redo

History and command systems belong to later phases.

Do not implement them in Phase 1.

---

## Phase 1 Tests

Create tests under:

```text
test/models/
```

Suggested test files:

```text
test/models/id_test.dart
test/models/value_objects_test.dart
test/models/project_hierarchy_test.dart
test/models/json_serialization_test.dart
test/models/copy_with_test.dart
```

## Required Test Cases

### Typed ID tests

Verify:

* IDs with same value are equal
* IDs with different values are not equal
* `toJson` and `fromJson` preserve the value

### Value object tests

Verify:

* `CanvasSize` creates correctly
* `BrushSettings` creates correctly
* `StrokePoint` creates correctly
* JSON round trip works

### Project hierarchy test

Create a full hierarchy:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

Verify each object contains the correct child object.

### JSON serialization test

Create a full project hierarchy.

Then:

1. Convert to JSON
2. Convert back from JSON
3. Verify the restored project has the same values

### copyWith test

Verify:

* `copyWith` changes only the specified field
* Original object remains unchanged
* Nested lists are preserved unless replaced

---

## Phase 1 Completion Criteria

Phase 1 is complete only when:

* All required model files exist
* All models are immutable
* Typed IDs are implemented
* `copyWith` exists for each model
* `toJson` / `fromJson` exist for each model
* Tests exist under `test/models/`
* Full hierarchy creation test passes
* JSON round-trip test passes
* `flutter analyze` passes
* `flutter test` passes

---

# Phase 2: Project State / Repository

## Goal

Add controlled project state management.

This phase introduces a repository or state holder that owns the current project.

## Future Files

```text
lib/src/services/project_repository.dart
```

## Responsibilities

* Hold current project
* Replace project with updated immutable copy
* Provide project mutation APIs
* Notify UI or listeners later

## Do Not Do Yet

* Do not implement drawing
* Do not implement persistence
* Do not implement timeline UI
* Do not implement playback

---

# Phase 3: Command-based Undo / Redo MVP

## Goal

Add a simple command-based undo / redo system.

## Future Files

```text
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/add_track_command.dart
lib/src/services/commands/add_cut_command.dart
lib/src/services/commands/add_layer_command.dart
lib/src/services/commands/add_frame_command.dart
lib/src/services/commands/draw_stroke_command.dart
```

## Responsibilities

* Define `Command`
* Execute commands
* Undo commands
* Redo commands
* Keep linear undo / redo stacks

## MVP Only

No branching history.

No snapshot / delta history.

No persistent history UI.

---

# Phase 4: Basic Save / Load

## Goal

Save and load projects as JSON.

## Future Files

```text
lib/src/services/persistence_coordinator.dart
```

## Responsibilities

* Save current project as JSON
* Load project from JSON
* Restore project data

## MVP Only

No delta storage.

No tile storage.

No cloud saving.

---

# Phase 5: Canvas Viewport and Basic Drawing

## Goal

Allow the user to draw on a limited-size canvas.

## Future Files

```text
lib/src/core/bitmap.dart
lib/src/core/brush_engine.dart
lib/src/controllers/frame_controller.dart
lib/src/ui/canvas_view.dart
```

## Responsibilities

* Display a limited-size canvas
* Draw simple strokes
* Apply a simple round brush
* Support basic pan and zoom

## MVP Only

No infinite canvas.

No tile-based rendering.

No advanced brush dynamics.

---

# Phase 6: Layer MVP

## Goal

Support multiple drawing layers.

## Future Files

```text
lib/src/controllers/layer_controller.dart
lib/src/ui/layer_panel.dart
lib/src/core/layer_compositor.dart
```

## Responsibilities

* Add layer
* Delete layer
* Select layer
* Toggle visibility
* Composite visible layers with simple alpha blending

## MVP Only

No masks.

No groups.

No clipping.

No adjustment layers.

No advanced blend modes.

---

# Phase 7: Timeline MVP

## Goal

Display and select frames in a simple timeline.

## Future Files

```text
lib/src/ui/timeline_view.dart
lib/src/controllers/timeline_controller.dart
```

## Responsibilities

* Show frame cells
* Select current frame
* Add frame
* Adjust simple exposure duration

## MVP Only

No audio.

No advanced virtualization.

No complex ripple editing.

---

# Phase 8: Cut / Track Editing

## Goal

Support multiple tracks and cuts.

## Future Files

```text
lib/src/controllers/track_controller.dart
lib/src/controllers/cut_controller.dart
lib/src/ui/track_view.dart
```

## Responsibilities

* Add track
* Delete track
* Add cut
* Move cut
* Change cut duration

## MVP Only

No advanced NLE editing.

No audio track editing.

No complex ripple modes.

---

# Phase 9: Cache MVP

## Goal

Add simple memory cache for rendered frames.

## Future Files

```text
lib/src/services/frame_display_cache_service.dart
```

## Responsibilities

* Cache recently displayed frames
* Use simple LRU or fixed-size map
* Invalidate cache when frame/layer changes

## MVP Only

No disk cache.

No tile cache.

No playback cache unless required by Phase 10.

---

# Phase 10: Playback MVP

## Goal

Play frames at the project FPS.

## Future Files

```text
lib/src/controllers/playback_controller.dart
lib/src/services/playback_cache_service.dart
lib/src/ui/playback_controls.dart
```

## Responsibilities

* Start playback
* Pause playback
* Stop playback
* Advance frames based on FPS
* Display current frame

## MVP Only

No audio playback.

No advanced loop modes.

No real-time render optimization beyond simple caching.

---

# Phase 11: Integration and Stabilization

## Goal

Make the full MVP vertical slice stable.

## Required User Flow

The user should be able to:

1. Open the app
2. Create a project
3. Create a track
4. Create a cut
5. Create a layer
6. Create a frame
7. Draw a simple stroke
8. Undo / redo
9. Save the project
10. Close and reopen
11. Load the project
12. See the drawing restored
13. Play the frames

## Focus

* Bug fixes
* Small UX improvements
* Test coverage
* Refactoring
* Integration tests

Do not add major new features in this phase.

---

# Phase 12: Post-MVP Advanced Features

## Goal

Implement advanced architecture features after the MVP is stable.

## Possible Milestones

### Infinite Canvas and Tile System

Future modules:

```text
TileManager
CoordinateSystem
CanvasNavigator
TileCache
DiskCache
```

### Advanced Brush Engine

Future features:

* Pressure
* Tilt
* Speed dynamics
* Texture brushes
* Stabilization
* Watercolor-style blending
* Brush preset import/export

### Persistent History

Future modules:

```text
SnapshotService
DeltaService
HistoryCompressor
HistoryArchiver
```

Future features:

* Persistent undo / redo
* Branching history
* Snapshot + delta storage
* History archive

### Advanced Layer System

Future features:

* Layer groups
* Masks
* Clipping
* Adjustment layers
* Advanced blend modes
* PSD compatibility

### Large Timeline Optimization

Future features:

* Timeline virtualization
* Lazy loading
* 100k frame stress testing
* Partial project loading

### Audio / Vector / 3D Extensions

Future features:

* Audio tracks
* Audio waveform display
* Vector layers
* 3D camera keyframes

### Cloud and Collaboration

Future features:

* Cloud save
* Version sync
* Multi-user collaboration

---

## 4. Current Next Step

The next actual coding task is:

```text
Implement only Phase 0 and Phase 1.
```

Do not implement Phase 2 or later until Phase 0 and Phase 1 are reviewed and committed.

After Phase 0 and Phase 1 are complete, review:

```bash
flutter analyze
flutter test
```

Then commit the result before moving to Phase 2.
