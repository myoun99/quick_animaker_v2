# Phase 226 Codex Task — Canvas Viewport Foundation

## Context

QuickAnimaker v2 is moving from Brush T2 stabilization into the canvas viewport phase.

Phase 225 stabilized the Brush T2 baseline. Do not reopen brush architecture work in this phase.

The current roadmap defines Phase 226 as Canvas viewport foundation:

```txt
- pan
- zoom
- fit to view
- reset view
- separate viewport transforms from drawing coordinates
- keep Cut.canvasSize as drawing/storage bounds
- keep viewport state out of drawing source data
```

This phase should improve the canvas editing experience without changing drawing source payloads, brush source commands, save/load, playback, or the camera output model.

## Important architecture context

Current project architecture separates:

```txt
Project.cameraSize:
  project-wide camera/output frame size

Cut.canvasSize:
  drawing/storage canvas bounds for each Cut

Canvas viewport:
  temporary UI/view transform used by the editor
```

These concepts must not be mixed.

Drawing source coordinates must remain canvas-space coordinates.

Viewport pan/zoom must affect only how the canvas is displayed and how pointer positions are converted between viewport/widget space and canvas space.

Viewport state must not be stored as brush source data.

## User camera idea to preserve for future phases

The user wants a future Camera T1 concept:

```txt
- a camera layer or camera-like track exists
- camera view shows a camera rectangle while editing
- outside of the camera frame is darkened while editing
- playback can show only inside the camera frame
- camera position, size, and rotation can be edited
```

This is a valid future direction, but do not implement editable Camera T1 in this phase.

For Phase 226, only a non-editable camera frame guide may be added if it fits naturally into the viewport overlay work.

The camera guide should be based on `Project.cameraSize` and treated as a visual overlay only.

Do not add camera transform source data, camera keyframes, camera layer persistence, playback cropping, or camera animation in this phase.

## Goal

Implement the canvas viewport foundation for production brush editing.

The user should be able to:

```txt
- pan the canvas view
- zoom in and out
- fit the active Cut canvas into the available viewport
- reset the viewport
- draw correctly after pan/zoom
- see the active Cut canvas bounds
- optionally see a non-editable Project.cameraSize frame guide overlay
```

The implementation must remain lightweight and modular.

## Required behavior

### 1. Viewport state

Introduce or use a small, explicit viewport model for canvas editing.

It should represent:

```txt
- zoom scale
- pan / translation
- viewport size if needed
- conversion from viewport/widget-local coordinates to canvas coordinates
- conversion from canvas coordinates to viewport/widget-local coordinates if needed
```

Prefer a pure value/object or small service.

Do not make it depend on Flutter rendering classes if an existing pure `CanvasViewport` value object already exists.

`CanvasViewport` or equivalent must stay separate from `BrushFrameStore`, `ProjectRepository`, `TimelineController`, and drawing source payloads.

### 2. Pointer coordinate conversion

Brush input must still commit `BrushDab` / source drawing data in canvas coordinates.

After pan/zoom:

```txt
pointer event position
  -> viewport/widget-local point
  -> canvas-space point
  -> BrushDab source data
```

Drawing after zooming or panning must land at the correct canvas coordinate.

### 3. Pan

Add a simple pan interaction.

Acceptable options:

```txt
- middle mouse drag
- space + drag
- secondary mouse drag
- trackpad-style drag if already easy
```

Choose the smallest safe implementation that works on desktop.

Do not interfere with normal brush drawing.

### 4. Zoom

Add zoom in/out.

Acceptable options:

```txt
- mouse wheel / trackpad scroll with modifier
- toolbar buttons
- keyboard shortcuts
```

Choose a small and reliable implementation.

Zoom should keep the canvas usable and avoid invalid or extreme scale values.

Recommended scale bounds:

```txt
minZoom: around 0.05 or 0.1
maxZoom: around 16 or 32
```

Use constants rather than magic numbers scattered through UI code.

### 5. Fit to view

Add a fit-to-view action.

It should fit the active `Cut.canvasSize` into the available canvas viewport area while preserving aspect ratio.

It should not change `Cut.canvasSize`.

It should not change brush source data.

### 6. Reset view

Add a reset-view action.

Reset should return the viewport to a predictable default, such as:

```txt
zoom = 1.0
pan = centered or zero
```

Choose the behavior that fits current UI best and document it in code/tests.

### 7. Canvas bounds overlay

Show the active Cut canvas bounds clearly.

The bounds represent `Cut.canvasSize`.

This overlay must be view-only and must not change drawing data.

### 8. Optional non-editable camera frame guide

If small and safe, add a visual camera frame guide based on `Project.cameraSize`.

The guide should:

```txt
- be drawn as a rectangle overlay
- be non-editable
- not add a Camera layer
- not add camera transform data
- not affect brush input
- not affect playback
- not affect export
- not affect save/load
```

If the current UI does not easily expose `Project.cameraSize` to the canvas view, skip the camera guide for this phase and document that it is deferred.

Do not force large architecture changes just to add the guide.

## UI requirements

Keep the UI compact and production-tool-oriented.

A simple toolbar or small canvas control row is acceptable.

Useful visible controls:

```txt
- zoom percentage text
- zoom in
- zoom out
- fit
- reset
- optional camera guide toggle if implemented
```

Do not redesign the entire application UI.

Do not add broad app-wide state management.

## Non-goals

Do not implement:

```txt
- editable camera layer
- camera keyframes
- camera position/scale/rotation source data
- camera playback crop
- cut canvas size editing
- save/load
- playback/cache implementation
- onion skin
- layer groups
- masks
- blend modes
- Provider / Riverpod / ChangeNotifier / Bloc
```

Cut canvas size editing is likely Phase 227.

Camera T1 should be a later dedicated phase after viewport and cut canvas size editing are stable.

## Tests

Add or update tests for stable behavior.

Recommended tests:

```txt
- viewport coordinate conversion maps viewport points to canvas points correctly
- zoom changes display transform but does not alter canvas-space brush source dabs
- pan changes display transform but does not alter canvas-space brush source dabs
- fit-to-view computes a scale that fits Cut.canvasSize inside the viewport
- reset view restores the expected viewport state
- active Cut canvas bounds are based on Cut.canvasSize
- optional camera guide, if implemented, is based on Project.cameraSize and is non-editable
```

Avoid brittle tests that assert exact UI prose unless a stable key or public behavior is unavailable.

Use stable keys for UI controls where needed.

## Documentation updates

Update relevant current docs only if the implementation changes current policy.

Likely docs:

```txt
docs/Current_Project_Architecture.md
docs/Current_UI_Product_Policy.md
docs/Current_Implementation_Roadmap.md
docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only
```

Do not edit Handoff sections 0 through 4.

Document:

```txt
- viewport pan/zoom is UI state, not drawing source data
- Cut.canvasSize remains drawing/storage bounds
- Project.cameraSize remains camera/output frame size
- Camera T1 is a future candidate, not implemented as editable camera layer in Phase 226
```

## Validation

Run if available:

```bash
dart format lib test docs
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If Dart or Flutter are unavailable, state that clearly and do not claim validation passed.

## PR requirements

Create a PR from `master`.

PR title:

```txt
Phase 226: Canvas viewport foundation
```

PR description must mention:

```txt
- adds pan/zoom/fit/reset viewport behavior
- keeps viewport transforms separate from drawing coordinates
- keeps Cut.canvasSize as drawing/storage bounds
- does not implement editable Camera T1
- optionally adds a non-editable Project.cameraSize guide if implemented
```
