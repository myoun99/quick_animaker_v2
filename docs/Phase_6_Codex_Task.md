# Phase 6 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 6: Layer MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 5 are already complete.

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
lib/src/controllers/canvas_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/
test/models/
test/services/
test/controllers/
test/ui/
docs/
```

The project already has:

* Immutable domain models
* Typed IDs
* JSON support
* `copyWith` support
* `ProjectRepository`
* Command-based undo/redo MVP
* JSON save/load services
* Basic visible canvas
* Basic stroke drawing
* Stroke rendering through `CustomPainter`
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
docs/Phase_5_Codex_Task.md
```

This task implements only Phase 6.

---

## Scope

Implement only:

```text
Phase 6: Layer MVP
```

The goal is to introduce a minimal layer workflow on top of the current canvas drawing MVP.

This phase should allow:

1. A project/cut to contain multiple layers
2. The UI to show a simple layer list
3. The user to select the active layer
4. Drawing to add strokes only to the selected layer's frame
5. Hidden layers to not render
6. Layer opacity to affect rendered strokes
7. The user to add a new layer
8. The user to toggle layer visibility
9. The user to adjust layer opacity in a simple debug/MVP way if practical

This is a minimal layer MVP.

---

## Very Important Restrictions

Do not implement any of the following:

* Timeline UI
* Playback
* Audio
* Onion skin
* Layer groups
* Layer masks
* Blend modes
* Clipping masks
* Adjustment layers
* Vector layers
* Bitmap raster engine
* Advanced brush engine
* Pressure/tilt/speed dynamics
* File picker UI
* Save/load UI
* Provider
* Riverpod
* Bloc
* Complex app-wide state management
* Infinite canvas
* Tile system
* Disk cache
* Playback cache
* Production layer panel UI

Do not implement Phase 7 or later.

This phase must stay focused on a simple layer MVP.

---

## Important Design Direction

The current Phase 5 canvas draws strokes from a single target `FrameId`.

Phase 6 should evolve this to support multiple layers.

For now, each layer can contain a frame with the same logical frame index/sample frame id pattern.

Because the app does not yet have a Timeline MVP, this phase may assume there is one active frame per layer.

Do not build a real timeline yet.

Do not build frame exposure editing yet.

Do not build animation playback yet.

---

## Required Folder Structure

Use existing folders:

```text
lib/src/controllers/
lib/src/ui/
lib/src/ui/canvas/
```

Create a layer UI folder if useful:

```text
lib/src/ui/layers/
```

Expected relevant structure after this phase:

```text
lib/
  src/
    controllers/
      canvas_controller.dart
      layer_controller.dart
    ui/
      home_page.dart
      canvas/
        canvas_view.dart
        stroke_painter.dart
      layers/
        layer_panel.dart

test/
  controllers/
    canvas_controller_test.dart
    layer_controller_test.dart
  ui/
    canvas_view_test.dart
    layer_panel_test.dart
```

You may adjust exact file names if there is a strong reason, but keep responsibilities separated.

---

## Required Files to Create or Modify

You may create:

```text
lib/src/controllers/layer_controller.dart
lib/src/ui/layers/layer_panel.dart
test/controllers/layer_controller_test.dart
test/ui/layer_panel_test.dart
```

You may modify:

```text
lib/src/controllers/canvas_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/stroke_painter.dart
test/controllers/canvas_controller_test.dart
test/ui/canvas_view_test.dart
```

You may modify `lib/main.dart` only if absolutely necessary, but it should probably remain as it is after Phase 5.

Do not modify model files unless absolutely necessary.

Do not modify persistence files unless absolutely necessary.

Do not modify command/history files unless absolutely necessary.

---

## LayerController

Create:

```text
lib/src/controllers/layer_controller.dart
```

Responsibilities:

* Hold or resolve the current active `LayerId`
* Expose layers for the current cut
* Select active layer
* Add a new layer to the current cut
* Toggle layer visibility
* Update layer opacity if practical
* Provide access to the current active layer
* Provide the current target frame for the active layer

Suggested constructor:

```dart
class LayerController {
  LayerController({
    required ProjectRepository repository,
    required HistoryManager historyManager,
    required CutId cutId,
    required FrameId frameId,
    LayerId? initialActiveLayerId,
  });
}
```

Suggested API:

```dart
List<Layer> get layers;

LayerId? get activeLayerId;

Layer? get activeLayer;

bool get hasActiveLayer;

void selectLayer(LayerId layerId);

void addLayer({
  required Layer layer,
});

void addLayerWithDefaults({
  required LayerId layerId,
  required String name,
});

void toggleLayerVisibility(LayerId layerId);

void setLayerOpacity({
  required LayerId layerId,
  required double opacity,
});

FrameId get frameId;
```

Implementation notes:

* This should be a plain Dart controller.
* No Provider/Riverpod/Bloc.
* It may use `ProjectRepository`.
* It may use `HistoryManager` if commands are created.
* It may directly call repository replacement/update methods if no commands exist yet for layer property changes.
* Keep logic simple and testable.
* If the active layer is deleted or missing, choose a stable behavior:

    * Prefer selecting the first available layer.
    * If no layers exist, `activeLayer` may be null.
* Do not add layer deletion yet unless necessary.
* Do not add drag reorder yet.

---

## Repository Support

If `ProjectRepository` does not currently support layer property updates, add minimal methods there only if necessary.

Allowed minimal additions:

```dart
void replaceLayer({
  required Layer layer,
});

void updateLayer({
  required LayerId layerId,
  required Layer Function(Layer layer) update,
});
```

Rules:

* Preserve immutability.
* Rebuild the parent chain.
* Throw clear errors if the target layer is missing.
* Do not implement broad unrelated repository features.
* Do not modify existing behavior unnecessarily.

If these methods are added, add tests to `project_repository_test.dart` only for these new methods.

Do not implement layer deletion or reorder in this phase unless absolutely needed.

---

## Commands

Prefer simple direct repository updates for Phase 6 if that keeps the scope smaller.

However, if new commands are introduced, keep them minimal.

Allowed optional commands:

```text
AddLayerCommand
UpdateLayerCommand
```

But note:

* `AddLayerCommand` already exists from Phase 3 if previously implemented.
* Do not duplicate an existing command.
* If using commands, ensure undo/redo works.
* If adding `UpdateLayerCommand`, test it.

It is acceptable for Phase 6 MVP to use direct repository updates for visibility and opacity and leave full undo/redo for layer property editing to a later phase.

Drawing strokes should continue to use the existing command/history path.

---

## CanvasController Changes

Currently `CanvasController` targets a fixed `FrameId`.

Update it so drawing can target the active layer's frame.

Possible approaches:

### Preferred approach

Let `CanvasController` receive a callback/provider for the current target `FrameId` or active layer frame.

Example:

```dart
FrameId Function() getCurrentFrameId
```

or:

```dart
LayerController layerController
```

Then, when `endStroke()` is called, add the stroke to the active layer's current frame.

### Acceptable simpler approach

Keep one shared `FrameId`, but ensure the active layer contains a frame with that id, and `AddStrokeCommand` targets that frame.

Important:

The existing `AddStrokeCommand` adds to the first matching `FrameId` found across the whole project.

If multiple layers have frames with the same `FrameId`, this may add the stroke to the wrong layer.

Therefore, for Phase 6, make frame ids unique per layer, or update the add-stroke path to target layer + frame more precisely.

Preferred long-term direction:

```text
LayerId + FrameId target
```

For this phase, implement the smallest safe solution.

Do not let drawing accidentally add strokes to the wrong layer.

---

## Add Stroke to Active Layer

This is the most important requirement.

When the user selects Layer A and draws:

```text
Stroke must be added to Layer A's current frame.
```

When the user selects Layer B and draws:

```text
Stroke must be added to Layer B's current frame.
```

A test must verify this.

Do not only test that “some frame” got a stroke.

---

## StrokePainter Changes

Currently `StrokePainter` paints a flat list of strokes.

Update it so it can paint layer-aware strokes.

Suggested direction:

```dart
class PaintableLayer {
  const PaintableLayer({
    required this.layer,
    required this.frame,
  });

  final Layer layer;
  final Frame frame;
}
```

or use another simple internal view model.

`StrokePainter` should:

* Paint only visible layers
* Apply each layer's opacity to that layer's strokes
* Preserve the existing active stroke preview
* Paint layers in list order
* Keep implementation simple

Do not implement blend modes.

Do not implement layer compositing.

Do not implement bitmap rendering.

---

## CanvasView Changes

`CanvasView` should still:

* Display the canvas
* Handle pointer events
* Call `CanvasController`
* Repaint with `setState`

It may now receive:

```dart
LayerController layerController
```

or the controller may expose paintable layers.

Keep the widget simple.

---

## LayerPanel

Create:

```text
lib/src/ui/layers/layer_panel.dart
```

Responsibilities:

* Display a simple list of layers
* Show selected layer
* Allow selecting a layer
* Allow adding a new layer
* Allow toggling visibility
* Optionally show opacity slider

Suggested constructor:

```dart
class LayerPanel extends StatelessWidget {
  const LayerPanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onToggleVisibility,
    required this.onOpacityChanged,
  });
}
```

Keep it simple.

A basic `ListView` with buttons is enough.

Do not build a production layer panel.

---

## HomePage Changes

Update `HomePage` to:

* Create a sample project with at least two layers
* Create `LayerController`
* Connect `CanvasController` to the active layer
* Show `CanvasView`
* Show `LayerPanel`
* Keep Undo/Redo debug buttons
* Show stroke count for the active layer or total visible strokes

Simple layout is fine:

```text
Top: debug controls
Center: canvas
Right or bottom: layer panel
```

For small screens, bottom panel is acceptable.

No final production UI required.

---

## Tests

Create and update tests under:

```text
test/controllers/
test/ui/
```

---

## layer_controller_test.dart

Required test cases:

### 1. Exposes layers

* Create a sample project with two layers
* Verify `layers.length == 2`

### 2. Select active layer

* Select second layer
* Verify `activeLayerId`
* Verify `activeLayer`

### 3. Add layer

* Add a new layer
* Verify layer count increases
* Verify new layer can be selected

### 4. Toggle visibility

* Toggle a visible layer
* Verify it becomes invisible
* Toggle again
* Verify it becomes visible

### 5. Set opacity

* Set opacity to a value like `0.5`
* Verify layer opacity changes

### 6. Missing layer errors

* Selecting a missing layer should throw or behave consistently
* Updating a missing layer should throw

---

## canvas_controller_test.dart Updates

Add or update tests to verify:

### 1. Drawing targets active layer

* Create project with two layers
* Select layer 1
* Draw stroke
* Verify layer 1 frame has one stroke
* Verify layer 2 frame has zero strokes
* Select layer 2
* Draw stroke
* Verify layer 1 frame still has one stroke
* Verify layer 2 frame has one stroke

### 2. Undo active layer stroke

* Draw into active layer
* Undo
* Verify only that layer's stroke is removed

### 3. Redo active layer stroke

* Draw into active layer
* Undo
* Redo
* Verify stroke returns to the correct layer

---

## layer_panel_test.dart

Required test cases:

### 1. Renders layer names

* Pump `LayerPanel`
* Verify layer names are visible

### 2. Select layer callback

* Tap a layer row
* Verify callback receives correct `LayerId`

### 3. Add layer callback

* Tap Add Layer button
* Verify callback is called

### 4. Visibility callback

* Tap visibility toggle
* Verify callback receives correct `LayerId`

Keep widget tests simple.

No golden tests.

---

## canvas_view_test.dart Updates

If `CanvasView` API changes, update tests.

Required behavior still:

* CanvasView renders
* Drag gesture creates a stroke in the active layer

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

* `LayerController` exists
* `LayerPanel` exists
* UI can show multiple layers
* User can select active layer
* User can add a layer
* User can toggle layer visibility
* Layer opacity is supported or clearly stubbed with tests if implemented
* Drawing adds strokes to the active layer, not a random matching frame
* Hidden layers are not painted
* Layer opacity affects rendered strokes
* Existing Phase 5 drawing still works
* Undo/redo for drawing still works
* Controller tests pass
* Widget tests pass
* No timeline UI is added
* No playback is added
* No advanced brush engine is added
* No bitmap engine is added
* No file picker UI is added
* No state management package is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 7.

Do not implement timeline, playback, onion skin, layer masks, blend modes, layer groups, advanced brush engine, bitmap engine, or state management packages.

This phase is only the minimal layer MVP.
