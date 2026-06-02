# QuickAnimaker v2.1 Architecture

## 1. Project Vision

QuickAnimaker v2.1 is a bitmap-based 2D animation production tool inspired by TVPaint, Clip Studio Paint, and Photoshop.

The goal is not to create a simple drawing app. The long-term goal is to build a professional frame-by-frame animation tool with:

* TVPaint-style timeline
* Clip Studio-level drawing experience
* Photoshop/PSD-level layer system
* Bitmap-based animation workflow
* Non-destructive editing
* Cut-based production structure
* Per-cut canvas size
* Future infinite canvas support
* Future persistent history and delta-based saving

However, the first implementation must focus on a small working vertical slice instead of trying to build the full application immediately.

---

## 2. Core Data Hierarchy

The core hierarchy of QuickAnimaker v2.1 is:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

This hierarchy must be preserved throughout the project.

### Project

A `Project` represents the entire animation project.

Responsibilities:

* Project metadata
* Project name
* FPS
* Created date
* List of tracks
* Global project settings

A project should not directly handle rendering, UI, saving, undo, or brush logic.

### Track

A `Track` represents a sequence lane in the project timeline.

Responsibilities:

* Hold a list of cuts
* Represent video or future audio tracks
* Manage track-level ordering

In the MVP, only video tracks are required.

### Cut

A `Cut` represents one shot or sequence inside a track.

Responsibilities:

* Own its own canvas size
* Hold layers
* Define cut duration
* Later support placement on the global timeline

Each cut can have an independent canvas size.

### Layer

A `Layer` represents a drawing layer inside a cut.

Responsibilities:

* Hold frames
* Store visibility
* Store opacity
* Later support groups, masks, clipping, adjustment layers, and blend modes

In the MVP, only simple visible/invisible layers and basic opacity are required.

### Frame

A `Frame` represents one animation frame or exposure unit.

Responsibilities:

* Hold strokes
* Store duration or exposure length
* Later reference bitmap or tile data

In the MVP, a frame can simply hold a list of strokes.

### Stroke

A `Stroke` represents one user drawing action.

Responsibilities:

* Store stroke points
* Store brush settings
* Later support pressure, tilt, speed, texture, and brush dynamics

In the MVP, a stroke can store basic points and simple brush settings only.

---

## 3. Main Design Principles

### 3.1 Bitmap-first, not vector-first

QuickAnimaker is a bitmap animation tool.

The system should not be designed as a vector drawing program first.

Vector paths, 3D camera data, or procedural layers may be added in the future, but the core drawing and animation workflow should be bitmap-oriented.

### 3.2 Non-destructive direction

The long-term architecture should preserve user edits as much as possible.

Future versions should support:

* Stroke history
* Delta-based storage
* Snapshot-based recovery
* Persistent undo/redo
* Archiveable history

However, the MVP may use a simpler stack-based undo system.

### 3.3 Avoid God Objects

No single class should manage the whole application.

The following classes must not become giant managers:

* ProjectManager
* ProjectController
* HistoryService
* PersistenceService
* Renderer
* CanvasEngine
* CacheManager

Responsibilities must be split into smaller modules.

### 3.4 UI and domain logic must be separated

UI widgets must not own core business logic.

The domain model should be usable without Flutter UI.

The first implementation should start with pure Dart models before adding UI, canvas, renderer, timeline, or state management.

### 3.5 Immutable data models

Core models should be immutable.

Instead of mutating existing objects directly, changes should create new instances through `copyWith`.

This makes undo, redo, saving, testing, and future multi-threaded processing safer.

---

## 4. Target Module Structure

The long-term structure is:

```text
lib/
  main.dart
  src/
    models/
    core/
    services/
    controllers/
    ui/
    utils/
```

For the first implementation, only the following is required:

```text
lib/
  main.dart
  src/
    models/
test/
```

Other folders may be added later.

---

## 5. Models Layer

The `models/` folder contains pure data structures.

Expected files:

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

### Typed IDs

All IDs should be typed wrappers around `String`.

Examples:

```text
ProjectId
TrackId
CutId
LayerId
FrameId
StrokeId
```

Do not pass raw `String` IDs everywhere.

Typed IDs reduce mistakes such as passing a `FrameId` where a `LayerId` is expected.

### JSON Support

Each model should support:

```text
toJson()
fromJson()
```

This is needed for future persistence and testing.

### copyWith Support

Each model should support:

```text
copyWith()
```

This is needed for immutable updates.

### No Circular References

Parent objects can contain child objects.

Allowed:

```text
Project contains List<Track>
Track contains List<Cut>
Cut contains List<Layer>
Layer contains List<Frame>
Frame contains List<Stroke>
```

Avoid child objects directly referencing parent objects.

Not allowed in the MVP:

```text
Stroke directly references Frame
Frame directly references Layer
Layer directly references Cut
```

---

## 6. Core Engine Layer

The long-term `core/` layer will contain low-level drawing, bitmap, canvas, compositing, and rendering modules.

Future modules may include:

```text
lib/src/core/
  bitmap.dart
  brush_engine.dart
  layer_compositor.dart
  tile_manager.dart
  coordinate_system.dart
  canvas_navigator.dart
  canvas_renderer.dart
  preview_renderer.dart
  composition_renderer.dart
  render_scheduler.dart
```

### Bitmap

Responsible for low-level pixel storage and manipulation.

MVP version may be simple.

Future version may support:

* RGBA pixel storage
* Tile-based storage
* Alpha blending
* Color space handling

### BrushEngine

Responsible for applying brush strokes to bitmap data.

MVP version:

* Simple round brush
* Basic color
* Basic size

Future version:

* Pressure
* Tilt
* Speed
* Stabilization
* Texture
* Brush dynamics
* Watercolor-like blending

### LayerCompositor

Responsible for combining multiple layers into one visible result.

MVP version:

* Simple alpha compositing
* Visibility toggle
* Opacity

Future version:

* Blend modes
* Layer groups
* Masks
* Clipping
* Adjustment layers
* PSD compatibility

### Infinite Canvas System

Long-term infinite canvas support should be split into:

```text
TileManager
CoordinateSystem
CanvasNavigator
TileCache
DiskCache
```

No single `InfiniteCanvasEngine` should own all responsibilities.

MVP does not need full infinite canvas support.

---

## 7. Services Layer

The `services/` layer manages persistence, history, caching, and other non-UI application services.

Future modules may include:

```text
lib/src/services/
  project_repository.dart
  history_manager.dart
  command.dart
  persistence_coordinator.dart
  metadata_serializer.dart
  tile_store.dart
  delta_service.dart
  snapshot_service.dart
  history_compressor.dart
  history_archiver.dart
  frame_display_cache_service.dart
  playback_cache_service.dart
  disk_cache_service.dart
```

### History

Long-term goal:

* Persistent undo/redo
* Snapshot + delta history
* Branching history
* Compression
* Archive support

MVP goal:

* Simple linear undo/redo stack
* Command-based operations
* No branching
* No delta compression
* No history UI

### Persistence

Long-term goal:

* Snapshot + delta format
* Tile-based storage
* Metadata schema
* Format versioning
* Archive support
* Future vector/audio/3D extensibility

MVP goal:

* Save and load project as JSON
* No delta storage
* No tile store
* No cloud save

### Cache

Long-term cache types:

```text
MemoryCache
TileCache
FrameDisplayCache
PlaybackCache
DiskCache
```

MVP cache:

* Optional simple frame display cache only
* No disk cache
* No tile cache
* No playback cache until playback phase

---

## 8. Controllers Layer

The `controllers/` layer exposes higher-level operations to UI or command systems.

Future modules may include:

```text
lib/src/controllers/
  project_controller.dart
  track_controller.dart
  cut_controller.dart
  layer_controller.dart
  frame_controller.dart
  timeline_controller.dart
  playback_controller.dart
```

Controllers should coordinate use cases, but should not become God Objects.

Examples:

### ProjectController

Allowed:

* Create project
* Rename project
* Coordinate high-level project actions

Not allowed:

* Direct rendering
* Direct canvas drawing
* Direct file I/O
* Direct timeline drawing

### LayerController

Allowed:

* Add layer
* Delete layer
* Select layer
* Toggle visibility

Not allowed:

* Render final image directly
* Save project files directly

### FrameController

Allowed:

* Add frame
* Apply stroke to current frame
* Request command execution

Not allowed:

* Own entire project state
* Manage UI widgets directly

---

## 9. UI Layer

The `ui/` layer is responsible only for presentation and user interaction.

Future modules may include:

```text
lib/src/ui/
  home_page.dart
  canvas_view.dart
  timeline_view.dart
  layer_panel.dart
  playback_controls.dart
  menu_bar.dart
```

UI should:

* Display current project state
* Send user actions to controllers
* Listen to state changes
* Avoid owning business logic

UI should not:

* Directly mutate deep model objects
* Implement undo/redo logic
* Implement persistence logic
* Implement rendering engine logic

---

## 10. MVP Scope

The first working version should not try to implement the full vision.

The MVP vertical slice should support:

1. Create a new project
2. Create track
3. Create cut
4. Create layer
5. Create frame
6. Draw basic stroke on one frame
7. Undo / redo
8. Save / load
9. Show basic timeline
10. Basic playback

---

## 11. Explicitly Excluded from MVP

The following are excluded from the MVP:

* Full PSD compatibility
* Advanced layer groups
* Masks
* Clipping layers
* Adjustment layers
* Full Photoshop-level brush engine
* Full infinite canvas
* Full tile-based storage
* Persistent infinite history UI
* 100k frame optimization
* Timeline virtualization
* Audio editing
* 3D camera system
* Vector layer system
* Cloud saving
* Collaboration

These features belong to post-MVP milestones.

---

## 12. Development Phases

The implementation should proceed in phases.

### Phase 0: Project Initialization

Goal:

* Create Flutter project
* Create basic folder structure
* Keep main app minimal

Do not implement real UI yet.

### Phase 1: Core Domain Models

Goal:

* Implement immutable models
* Implement typed IDs
* Implement `copyWith`
* Implement `toJson` / `fromJson`
* Implement model tests

No UI, renderer, persistence, undo, or state management.

### Phase 2: Project State / Repository

Goal:

* Add project repository
* Add basic state handling
* Add controlled project mutation APIs

### Phase 3: Command-based Undo / Redo MVP

Goal:

* Add command interface
* Add basic undo/redo stack
* Add commands for creating tracks, cuts, layers, frames, and strokes

### Phase 4: Basic Save / Load

Goal:

* Save project as JSON
* Load project from JSON

### Phase 5: Canvas Viewport and Basic Drawing

Goal:

* Add simple bitmap
* Add simple round brush
* Draw on a frame

### Phase 6: Layer MVP

Goal:

* Add multiple layers
* Add visibility and opacity
* Add simple compositing

### Phase 7: Timeline MVP

Goal:

* Show frames
* Select frame
* Add frame
* Adjust simple exposure length

### Phase 8: Cut / Track Editing

Goal:

* Multiple tracks
* Multiple cuts
* Basic cut movement and duration adjustment

### Phase 9: Cache MVP

Goal:

* Add simple frame display cache

### Phase 10: Playback MVP

Goal:

* Play frames at project FPS

### Phase 11: Integration and Stabilization

Goal:

* Make the full MVP vertical slice stable

### Phase 12: Post-MVP Advanced Features

Goal:

* Infinite canvas
* Tile system
* Advanced brush engine
* Advanced layer system
* Persistent history
* Large timeline optimization
* Audio
* Vector/3D extension
* Cloud/collaboration

---

## 13. First Codex Implementation Rule

The first Codex task must implement only Phase 0 and Phase 1.

Codex must not implement:

* Drawing
* Canvas
* Timeline
* Undo / redo
* Persistence
* State management
* Renderer
* Brush engine behavior
* Layer compositing
* Playback

The first code task should only produce:

```text
lib/src/models/*
test/model tests
minimal lib/main.dart
```

The first implementation is considered complete only when:

```text
flutter analyze
flutter test
```

both pass successfully.

---

## 14. Guiding Rule

Build the project in small safe steps.

Do not ask Codex to implement the entire architecture at once.

Every phase should have:

* Clear scope
* Clear forbidden work
* Clear file list
* Clear tests
* Clear completion condition

The project should always remain runnable and testable after each phase.
