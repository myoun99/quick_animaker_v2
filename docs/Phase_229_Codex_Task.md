# Phase 229 Codex Task — Canvas Panel Layout and Panbar Interaction Stabilization

## Context

Phase 228 added:

* robust clipped pointer segments for fast canvas boundary crossing
* production default project/cut/layer startup cleanup
* source-label canvas title/status
* editor-session `CanvasViewport` persistence across selection changes
* lightweight horizontal and vertical canvas viewport panbars

After merging Phase 228 and running local validation, automated `flutter analyze` and `flutter test` pass after small local test/format fixes.

Manual testing revealed that the canvas panel panbars are not production-ready yet.

Observed manual issues:

```txt
- The canvas panel panbars move the canvas only by very small amounts.
- Panbar interaction feels laggy.
- When the canvas panel becomes very small, Flutter reports a vertical RenderFlex overflow.
- The overflow occurred with panel constraints around width 1200 and height 80.
- Additional Invalid argument errors occurred around a 24.0 clamp value, likely from thumb minimum-size calculations when track size is smaller than the minimum thumb size.
```

This phase must solve these issues as a proper long-term layout and interaction design.

Do not disable panbars.

Do not hide panbars as a workaround.

Do not replace the canvas viewport model with a generic `ScrollView`.

Do not introduce Provider, Riverpod, ChangeNotifier, Bloc, or broad app-wide state management.

## Core principles

The project prioritizes long-term, production-facing structure.

The canvas editor panel should behave like a real animation tool panel:

```txt
- stable when resized
- no overflow exceptions
- no invalid thumb metrics
- responsive panbar dragging
- no excessive rebuilds during drag
- clear separation between source data and editor UI state
```

`CanvasViewport` remains editor-session UI state.

It must not be saved into:

```txt
- Project
- Cut
- Layer
- Frame
- Stroke
- playback/cache data
- camera/source data
```

## Current architecture constraints

The current `CanvasViewport` is a pure model with:

```txt
zoom
panX
panY
canvasToViewport()
viewportToCanvas()
fitToView()
zoomedAround()
```

Panbars were introduced in `BrushCanvasPanel`.

The canvas editor shell currently has:

```txt
- top title bar
- central canvas editor content
- right strip for vertical panbar
- bottom bar for toolbar and horizontal panbar
```

Keep this general shell structure, but make it robust.

## Problems to solve

### 1. Canvas panel shell overflows when height is too small

The panel shell is a vertical `Column`.

When height is constrained too small, fixed-height top and bottom bars can exceed available height.

Observed example:

```txt
constraints: BoxConstraints(w=1200.0, h=80.0)
top bar: 32
bottom bar: toolbar + panbar
total fixed height can exceed 80
```

Desired behavior:

```txt
- no RenderFlex overflow
- no yellow/black overflow stripe
- no crash
- panel remains usable or gracefully compact
```

Implement a real layout contract.

Recommended direction:

```txt
CanvasEditorPanelShell
  - computes available height
  - guarantees central content height is never negative
  - can compact or scroll the bottom controls when height is insufficient
  - clips non-critical decoration when necessary
  - keeps title/content/bottom/right regions structurally stable
```

The solution should be intentional and documented.

Do not simply wrap everything in a generic `SingleChildScrollView` if that breaks the panel model.

### 2. Panbar thumb metrics are unsafe for small tracks

The current thumb calculation can use something like:

```txt
thumbExtent = (...).clamp(24.0, trackExtent)
```

When `trackExtent < 24.0`, this can create invalid clamp bounds.

Desired behavior:

```txt
- no Invalid argument exceptions
- no NaN / Infinity values
- thumb metrics remain valid for any positive finite track size
- if the track is too small, the thumb should still paint safely
```

Implement a small pure metrics helper.

Recommended direction:

```txt
CanvasViewportPanMetrics
  axis
  viewport
  editorViewportSize
  canvasSize
  trackSize

outputs:
  scaledContentExtent
  visibleExtent
  maxScroll
  thumbExtent
  thumbTravel
  thumbStart
  canScroll
  panToThumb()
  thumbDeltaToPanDelta()
```

This helper should be testable without widgets.

Rules:

```txt
- if maxScroll <= 0, canScroll is false
- if canScroll is false, dragging the panbar is a no-op
- if trackExtent is small, thumbExtent must be within 0..trackExtent
- never call clamp with lower > upper
- never produce NaN or Infinity
```

### 3. Panbar drag sensitivity is poor

Manual testing showed that panbar drag moves the canvas only very slightly.

The panbar should feel like a normal scrollbar:

```txt
- dragging the thumb across the track should move from one pan edge to the other
- dragging a meaningful distance should visibly pan the canvas
- the direction should match standard scrollbar behavior
- horizontal panbar controls panX
- vertical panbar controls panY
```

Revisit the mapping:

```txt
thumbDelta / thumbTravel = scrollDelta / maxScroll
pan = -scroll
```

Use actual painted track size, not an unrelated viewport size, when calculating the drag ratio.

If the panbar widget has a 14-pixel height but a 1000-pixel width, horizontal drag must use the 1000-pixel width.

If the vertical strip is 18 pixels wide but 600 pixels tall, vertical drag must use the 600-pixel height.

Do not use the wrong axis size.

### 4. Panbar drag causes excessive rebuilds / lag

Manual testing suggests lag during panbar interaction.

The current code may call `setState` and parent `onViewportChanged` on every drag update.

Desired behavior:

```txt
- drag update should be responsive
- avoid rebuilding the entire HomePage on every pointer movement
- keep source data unchanged
- keep viewport session state synchronized correctly
```

Recommended direction:

Introduce a lightweight local editor-session viewport controller or draft-viewport flow without large state management.

Possible approach:

```txt
BrushCanvasPanel owns local live viewport during interaction.

During panbar drag:
  - update only local BrushCanvasPanel viewport
  - repaint canvas/panbar responsively

At drag end:
  - notify parent once with the final viewport

For non-drag actions:
  - zoom/fit/reset can still notify parent immediately
```

Alternative acceptable approach:

```txt
Introduce a tiny CanvasViewportController class:
  - no ChangeNotifier
  - no Provider
  - no Riverpod
  - plain object or local ValueNotifier only if carefully scoped
```

However, do not add broad app state management.

The final design must clearly document:

```txt
- which widget owns live viewport during drag
- when parent HomePage/editor-session viewport is synchronized
- how selection changes reuse the editor-session viewport
```

### 5. Fit/no-scroll behavior must remain stable

From the local hotfix discussion:

```txt
If there is no scroll range, dragging the panbar should not reset centered fit pan to zero.
```

Desired behavior:

```txt
- Fit can center the canvas with positive pan values
- when maxScroll is zero, panbar dragging is ignored
- centered fit pan is preserved
- no sudden jump to top-left
```

### 6. Keep Phase 228 behavior intact

Do not regress:

```txt
- clipped pointer segment drawing
- no outside canvas drawing
- no outside bridge when leaving/re-entering
- source-title labels from Project/Cut/Layer/Frame source names
- no sample project/cut/layer startup naming
- viewport persistence across selection changes
- undo/redo behavior
```

## Scope

Allowed code scope:

```txt
lib/src/ui/brush/brush_canvas_panel.dart
lib/src/models/canvas_viewport.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart only if needed
lib/src/ui/home_page.dart only if viewport sync boundary requires it
new small helper files under lib/src/ui/brush/ or lib/src/services/
tests under test/
docs
```

Recommended new files:

```txt
lib/src/ui/brush/canvas_viewport_pan_metrics.dart
test/ui/canvas_viewport_pan_metrics_test.dart
```

or another equivalent location if it better matches the current project structure.

## Non-goals

Do not implement:

```txt
- Cut canvas size editing UI
- Camera T1
- camera layer
- camera transform/keyframes
- save/load
- playback/cache
- onion skin
- layer groups
- masks
- blend modes
- Provider / Riverpod / ChangeNotifier / Bloc
- broad app architecture rewrite
```

Do not remove or hide panbars.

## Required tests

Add or update tests for:

### Pan metrics

```txt
- tiny track extent does not throw
- trackExtent < minThumbExtent still produces valid finite metrics
- no-scroll content returns canScroll false
- no-scroll drag maps to no viewport change
- horizontal drag maps thumb delta to panX meaningfully
- vertical drag maps thumb delta to panY meaningfully
- thumb extent and thumb start are always finite and within track bounds
```

### Panel layout

```txt
- canvas editor panel shell does not overflow at very small heights
- shell still renders title/content/right strip/bottom region safely
- bottom controls are compacted/clipped/laid out intentionally when height is too small
```

### Panbar interaction

```txt
- horizontal panbar drag visibly updates panX
- vertical panbar drag visibly updates panY
- large drag reaches clamped pan edge
- dragging when no scroll range preserves centered fit pan
- panbar drag does not call parent sync on every update if the chosen architecture supports drag-end sync
- parent receives final viewport after drag end
```

### Regression

```txt
- viewport survives frame/layer/cut selection changes
- zoom/fit/reset still update viewport and panbar state
- clipped brush boundary behavior tests still pass
- source label title tests still pass
- sample naming cleanup tests still pass
```

## Manual QA

After implementation, manually verify:

```txt
1. Run the app on Windows.
2. Shrink the app/window or panel so canvas area becomes very small.
   - No RenderFlex overflow.
   - No Invalid argument exceptions.
3. Zoom in until the canvas is larger than the visible viewport.
4. Drag horizontal panbar.
   - Canvas should visibly move horizontally.
   - Dragging across the bar should cover a meaningful pan range.
5. Drag vertical panbar.
   - Canvas should visibly move vertically.
6. Press Fit.
   - Canvas should center.
   - Dragging panbars when no scroll range exists should not snap canvas to top-left.
7. Switch frame/layer/cut.
   - Zoom/pan should remain stable.
8. Draw fast across canvas boundary.
   - No outside drawing.
   - No boundary gap.
   - No outside bridge.
9. Undo/redo a stroke.
   - Stroke undo/redo works.
   - Viewport does not unexpectedly reset.
```

## Documentation updates

Update:

```txt
docs/Current_Project_Architecture.md
docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only
```

Do not edit Handoff sections 0 through 4.

Document:

```txt
- canvas panel shell layout contract
- panbar metrics safety rules
- panbar drag mapping
- viewport parent sync timing
- fit/no-scroll panbar behavior
```

## Validation

Run:

```bash
dart format lib test docs
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If any command cannot run, state that clearly.

## PR requirements

Create a PR from `master`.

PR title:

```txt
Phase 229: Stabilize canvas panel layout and panbar interaction
```

PR description must mention:

```txt
- fixes small-height canvas panel overflow
- fixes unsafe panbar thumb metrics
- improves panbar drag sensitivity
- reduces panbar drag rebuild overhead
- preserves fit/no-scroll centered pan behavior
- keeps CanvasViewport as editor-session UI state
- does not disable or remove panbars
- does not introduce broad state management
```
