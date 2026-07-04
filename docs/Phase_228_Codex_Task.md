# Phase 228 Codex Task — Canvas Viewport Completion and Default Project Entry Cleanup

## Context

Phase 226 introduced the canvas viewport foundation.

Phase 227 introduced canvas boundary clipping, outside/re-entry stroke session behavior, and a compact canvas editor panel shell.

The user manually merged and locally verified Phase 227. After testing, the user found additional issues and clarified long-term product rules.

This phase must improve the canvas viewport foundation and clean up the production app entry state.

## Core principles

The project must prefer long-term, production-facing structure.

Do not add temporary demo/sample-only logic to production entry points.

Do not invent display names for materials.

Display names must come from the actual source objects that the user is editing.

## Current problems to solve

### 1. Fast boundary crossing creates visible gaps near the canvas edge

When drawing quickly from inside the canvas to outside, or outside to inside, the current behavior can leave a visible gap near the Cut canvas boundary.

The reason is that the current implementation accepts only raw pointer points that are inside the canvas and discards outside points.

That is not sufficient for fast strokes.

Desired behavior:

```txt id="rx81mp"
inside -> outside:
  draw up to the canvas boundary intersection point
  do not draw outside the canvas

outside -> inside:
  start drawing from the canvas boundary entry point
  do not connect across the outside gap

outside -> outside while crossing through the canvas:
  draw only the clipped segment inside the canvas

outside -> outside without crossing the canvas:
  draw nothing
```

Implement segment clipping between consecutive raw pointer positions and the active `Cut.canvasSize` rectangle.

This must preserve the Phase 227 rule:

```txt id="vopczv"
Leaving the canvas does not cancel the stroke session.
Re-entering continues the same pointer session.
Outside gaps must not be connected.
Pointer up is the normal stroke end.
```

### 2. Canvas editor scrollbars are currently only a shell/placeholder

The right vertical strip and bottom bar exist, but they are not yet actual viewport scroll/pan controls.

Add real lightweight canvas viewport scrollbars/panbars.

They should be local canvas editor UI only.

They must drive `CanvasViewport.panX` and `CanvasViewport.panY`.

They must not mutate:

```txt id="b6p7qd"
- Project
- Cut
- Frame
- Brush source dabs
- save/load data
- playback data
- camera data
```

Expected behavior:

```txt id="u0yec6"
horizontal scrollbar:
  represents and controls horizontal pan of the inner Cut.canvasSize drawing canvas

vertical scrollbar:
  represents and controls vertical pan of the inner Cut.canvasSize drawing canvas

zoom/fit/reset:
  scrollbars update visually after these actions

scrollbar drag:
  updates CanvasViewport pan
```

Keep the first implementation simple and reliable.

Do not force Flutter `ScrollView` if it conflicts with the current `CanvasViewport` transform model.

A custom lightweight viewport scrollbar/thumb is acceptable.

### 3. Canvas viewport resets when changing cut/frame

The current zoom/pan can reset when switching cuts or frames.

The user wants the editor viewport to remain synchronized and stable across selection changes.

Desired behavior:

```txt id="orc8xv"
- Change frame:
  keep current zoom/pan

- Change layer:
  keep current zoom/pan

- Change cut:
  keep current zoom/pan if the new cut can reasonably use it

- If the new cut has a different canvas size:
  keep zoom if safe
  clamp pan to a valid/usable range if needed
```

Important:

```txt id="un81ir"
CanvasViewport is editor session UI state.
It must not become source data.
It must not be stored in Project/Cut/Frame.
It must not affect save/load or playback.
```

Move viewport ownership out of any widget that is rebuilt/rekeyed on frame selection if that rebuild causes zoom/pan reset.

A likely safe direction:

```txt id="e0pior"
HomePage or MainCanvasBrushHost:
  owns current CanvasViewport editor-session state

BrushCanvasPanel:
  receives viewport and onViewportChanged

CanvasViewport:
  remains pure UI/view state
```

Do not introduce Provider, Riverpod, ChangeNotifier, Bloc, or broad app-wide state management.

### 4. Remove sample project / sample cut production entry logic

Production `HomePage` must not create fake sample-only project/cut/layer/frame data.

The user does not want `sample-project`, `sample-cut`, `sample-frame`, or other sample-only objects in the actual app startup flow.

Instead, startup should use the same default creation flow that a real “New Project” / “New Cut” action will use later.

Required direction:

```txt id="f1wqw3"
createDefaultProject()
  creates a real default project

createDefaultTrack()
  creates a real default track

createDefaultCut()
  creates a real default cut

createDefaultLayer()
  creates a real default layer
```

Use existing default helpers where available.

There is already a default cut helper and default cut canvas size. Do not duplicate `2340 x 1654` literals in `HomePage`.

HomePage fallback should become conceptually:

```txt id="u6povy"
final project = widget.initialProject ?? createDefaultProject();
```

not:

```txt id="omqbxi"
_createSampleProject()
```

Remove sample-specific naming from production startup.

Acceptable default names:

```txt id="nw9tg4"
Project:
  Untitled Project

Track:
  Track 1

Cut:
  Cut 1

Layer:
  Layer1 or the current existing default layer naming convention

Frame:
  use the actual source frame display label/name resolver
```

Do not change broad naming policy more than needed.

Do not invent a new material naming system in this phase.

### 5. Canvas title/status must display actual source names

The canvas panel title/status must not display IDs as names unless the source object itself exposes that as the display label.

The user’s rule:

```txt id="x6moj1"
Names shown in the canvas panel must be material/source names.

Layer display:
  read the actual Layer.name.
  Example: "Layer: Layer1" if that is the current layer name.

Frame display:
  read the actual frame name/display label from source.
  If the frame is unnamed and the timeline currently displays a middle-dot / default frame display label, show that same source-derived label.
  Do not invent a fake frame name from FrameId unless that is the existing source display policy.

Cut display:
  read the actual Cut.name.

Project display:
  read the actual Project.name.
```

Implement a small resolver/helper if necessary.

Recommended direction:

```txt id="kd8sc8"
CanvasSelectionDisplayLabels
  projectLabel
  cutLabel
  layerLabel
  frameLabel
```

It should read from the actual current `Project`, active `Cut`, active `Layer`, and selected/resolved `Frame` / timeline display policy.

Do not hardcode:

```txt id="uwh762"
- sample names
- frame IDs as frame names
- layer IDs as layer names
- cut IDs as cut names
```

The title/status bar should become conceptually:

```txt id="ffkyo6"
Project: <project.name>
Cut: <cut.name>
Layer: <layer.name>
Frame: <frame display label from source/timeline policy>
```

If some source object is unavailable, show a compact safe placeholder such as `-`, but do not fabricate IDs as names.

## Scope

Allowed runtime scope:

```txt id="cmpm6w"
- Canvas boundary segment clipping
- Lightweight CanvasViewport scrollbar/panbar controls
- CanvasViewport editor-session ownership stabilization
- Default project/track/cut startup helper cleanup
- Canvas title/status source-name resolver
```

Allowed docs:

```txt id="d0gvum"
docs/Current_Project_Architecture.md
docs/Current_UI_Product_Policy.md
docs/Current_Implementation_Roadmap.md
docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only
```

Do not edit Handoff sections 0 through 4.

## Non-goals

Do not implement:

```txt id="voqr9h"
- Cut canvas size editing UI
- Camera T1
- editable camera layer
- camera position/scale/rotation
- camera keyframes
- camera playback crop
- save/load
- playback/cache implementation
- onion skin
- layer groups
- masks
- blend modes
- Provider / Riverpod / ChangeNotifier / Bloc
```

## Implementation guidance

### Boundary segment clipping

Prefer a small pure helper/service.

Possible helper:

```txt id="lm2y5t"
CanvasSegmentClipper
```

or similar.

It should be testable without widgets.

Input:

```txt id="i4r2l8"
previous raw canvas point
current raw canvas point
canvas rect
```

Output:

```txt id="m8c8zg"
zero or one clipped visible segment:
  start point
  end point
  startsNewVisibleSegment flag
```

The brush input layer can then generate dabs only for the clipped visible segment.

Important cases:

```txt id="h7cgng"
inside -> inside:
  normal interpolation

inside -> outside:
  interpolate from previous inside point to exit intersection

outside -> inside:
  interpolate from entry intersection to current inside point with previous=null for visible continuity rules

outside -> outside crossing canvas:
  interpolate only entry -> exit as a new visible segment

outside -> outside not crossing canvas:
  no dabs
```

Keep source dabs canvas-space.

Do not record outside dabs as source dabs.

### Viewport scrollbars

Prefer a small local UI component.

Possible components:

```txt id="siv3r0"
CanvasViewportHorizontalScrollbar
CanvasViewportVerticalScrollbar
CanvasViewportScrollbars
```

It should receive:

```txt id="9y32ek"
CanvasViewport viewport
Size editorViewportSize
CanvasSize canvasSize
ValueChanged<CanvasViewport> onViewportChanged
```

The scrollbars should compute thumb size/position from:

```txt id="pk2oti"
scaled canvas size = Cut.canvasSize * viewport.zoom
visible editor viewport size
viewport pan
```

Clamp pan to a reasonable range.

Do not make scrollbars source of truth.

### Viewport persistence across selection changes

Keep one editor viewport state for the current editor session.

The simplest acceptable rule:

```txt id="so06r1"
Same HomePage/editor session:
  keep CanvasViewport across cut/layer/frame changes

App restart:
  viewport resets because this phase does not persist viewport to disk
```

If selection changes to a cut with a different canvas size, clamp pan if needed but keep zoom if within min/max.

### Default project entry cleanup

Add or use helpers so production startup no longer creates sample-named objects.

Likely files:

```txt id="zjpsq9"
lib/src/controllers/default_project_helpers.dart
lib/src/controllers/default_track_helpers.dart
lib/src/controllers/default_cut_helpers.dart
lib/src/controllers/default_layer_helpers.dart
lib/src/ui/home_page.dart
```

Use existing helpers where possible.

Remove or rename `_createSampleProject()`.

The HomePage initial fallback must use the production default factory.

### Source-name title/status resolver

Do not rely on `BrushFrameKey` IDs for display names.

`BrushFrameKey` identifies the drawing payload, but it is not a user-facing name source.

Use project/cut/layer/frame source objects.

If `BrushCanvasPanel` does not currently have enough source metadata, add a lightweight display-label object passed from `HomePage` or `MainCanvasBrushHost`.

Possible object:

```txt id="e6p1f5"
CanvasEditorSelectionLabels(
  projectName,
  cutName,
  layerName,
  frameLabel,
)
```

Keep this as display data only.

Do not add new persistence.

## Tests

Add or update tests.

Required tests:

```txt id="xbe9b5"
Boundary clipping:
- inside -> outside fast movement emits dabs up to the canvas edge so there is no visible edge gap.
- outside -> inside fast movement starts at the canvas edge and does not connect to the previous inside segment.
- outside -> outside crossing through the canvas produces only the clipped in-canvas segment.
- outside -> outside not crossing produces no dabs.

Viewport scrollbars:
- horizontal scrollbar renders and updates viewport.panX when dragged.
- vertical scrollbar renders and updates viewport.panY when dragged.
- zoom/fit/reset updates scrollbar thumb state or at least keeps scrollbar controls accessible and consistent.

Viewport session state:
- switching frame keeps current zoom/pan.
- switching layer keeps current zoom/pan.
- switching cut keeps current zoom/pan or clamps pan without resetting zoom to 100%.

Default startup:
- HomePage fallback creates a default project through production default helpers, not sample-only helpers.
- No production startup object uses `sample-project`, `sample-cut`, `sample-frame`, or similar sample-only naming.
- Default cut uses defaultCutCanvasSize / createDefaultCut source-of-truth.

Canvas title/status labels:
- title/status bar uses Project.name, Cut.name, Layer.name, and source-derived Frame display label.
- Layer label should show actual layer.name, not layerId.
- Frame label should show existing source/timeline display label, not a fabricated frameId.
```

Avoid brittle tests that check private method names.

Narrow forbidden-string tests for sample startup names are acceptable if scoped to production startup files.

## Documentation updates

Update current docs to record:

```txt id="ny2hd4"
- canvas boundary behavior now uses clipped pointer segments to avoid edge gaps
- canvas viewport scrollbars/panbars are local UI controls over CanvasViewport
- CanvasViewport may be kept as editor-session UI state across selection changes
- startup uses production default project/cut helpers, not sample-only data
- canvas title/status labels must read source object names/display labels, not IDs
```

Do not edit Handoff sections 0 through 4.

## Validation

Run:

```bash id="n3galn"
dart format lib test docs
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If Dart or Flutter are unavailable, state that clearly and do not claim validation passed.

Manual checks:

```txt id="beoaw3"
1. Fast draw across canvas edge: no visible gap at the boundary.
2. Draw inside -> outside -> inside: no connecting stroke across outside gap.
3. Start outside -> enter canvas: stroke appears from boundary/inside as expected.
4. Real horizontal and vertical scrollbar controls are visible and affect pan.
5. Zoom/fit/reset still work.
6. Switch frame/layer/cut: zoom/pan remains stable, not reset to 100%.
7. App startup no longer shows sample project/cut/frame naming.
8. Canvas title/status shows actual Project/Cut/Layer/Frame source names/display labels.
9. Undo/redo still works.
```

## PR requirements

Create a PR from `master`.

PR title:

```txt id="g0pgmz"
Phase 228: Canvas viewport completion and default project entry cleanup
```

PR description must mention:

```txt id="l6yp1q"
- fixes fast boundary crossing gaps with clipped pointer segments
- adds lightweight real viewport scrollbars/panbars
- keeps CanvasViewport stable across selection changes as editor-session UI state
- removes sample-only startup project/cut/frame creation from production HomePage
- uses production default project/cut helpers
- makes canvas title/status labels read source object names/display labels
- does not implement Cut canvas size editing or Camera T1
```
