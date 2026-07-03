# Phase 227 Codex Task — Canvas Boundary Behavior and Editor Panel Shell

## Context

Phase 226 introduced the first canvas viewport foundation:

```txt id="a2z9ct"
- pan
- zoom
- fit to view
- reset view
- CanvasViewport coordinate conversion
- visible editor viewport separated from the inner Cut.canvasSize drawing canvas
```

The user manually confirmed Phase 226 after follow-up fixes.

Before moving to Cut canvas size editing, this phase must stabilize canvas boundary behavior and introduce a simple canvas editor panel shell.

Current architecture rules:

```txt id="q4vd0x"
Project.cameraSize:
  project-wide camera/output frame size

Cut.canvasSize:
  drawing/storage canvas bounds for the active Cut

CanvasViewport:
  UI-only pan/zoom/fit/reset view state

Drawing bounds:
  equal active Cut.canvasSize
```

Do not mix Project.cameraSize, Cut.canvasSize, and CanvasViewport.

## User-reported issues and desired behavior

The user observed:

```txt id="pi7k10"
1. Brush marks visually leak outside the blue Cut canvas bounds.
2. When drawing leaves the canvas and re-enters, the last inside point and the new inside point are connected by an unwanted line/stroke segment.
3. The user wants a simpler canvas panel UI like a compact editor sub-window:
   - title/status bar at the top
   - canvas content in the middle
   - vertical scroll/pan control on the right
   - bottom bar with zoom percentage, horizontal scroll/pan control, zoom in/out, fit/reset, and other canvas-local buttons
```

Desired brush boundary behavior:

```txt id="xt0zz3"
- Canvas drawing display must be clipped to Cut.canvasSize.
- Pen down outside the canvas should still start a stroke session.
- A stroke session should remain alive while the pointer is down.
- Leaving the canvas should not cancel the stroke.
- Re-entering the canvas should continue the stroke, but must not connect across the outside gap.
- Only pen up / pointer up ends the stroke session.
- If no visible in-canvas dabs were collected, nothing should be committed.
```

## Goal

Implement stable canvas boundary behavior and introduce a small reusable canvas editor panel shell.

This phase should improve the production editing feel without implementing cut canvas size editing, Camera T1, save/load, playback, or new app-wide state management.

## Scope

### 1. Clip canvas display to Cut.canvasSize

The visible brush display must not leak outside the active Cut canvas bounds.

The active editing display should clip all of the following to the inner drawing canvas:

```txt id="djz4sr"
- committed source dabs
- committed source dab strokes
- active stroke overlay
- canvas bounds overlay
- base bitmap surface display
```

Implementation guidance:

```txt id="j5l2kc"
- Clip at the inner BrushEditCanvasView / drawing canvas boundary.
- Do not clip the whole editor viewport in a way that prevents panning/scrolling.
- The inner drawing canvas should remain Cut.canvasSize.
- The outer visible editor viewport should remain UI/layout space.
```

It is acceptable to use `ClipRect` at the `BrushEditCanvasView` level if that cleanly clips all drawing layers to the Cut canvas bounds.

### 2. Fix stroke behavior when leaving and re-entering the canvas

The current stroke session should be independent from whether the pointer is currently inside the canvas.

Required behavior:

```txt id="o5jbji"
Pointer down outside canvas:
  start a stroke session
  collect no visible dabs yet

Pointer moves into canvas:
  collect visible dabs from the first in-canvas point

Pointer moves outside canvas:
  collect no visible dabs
  mark the visible segment as broken

Pointer re-enters canvas:
  start a new visible segment
  do not interpolate/connect from the previous in-canvas dab across the outside gap

Pointer up:
  commit all collected visible in-canvas dabs if any exist
  otherwise commit nothing
```

Important:

```txt id="e84vug"
Leaving the canvas must not call onSourceStrokeCommitted.
Leaving the canvas must not clear the stroke.
Leaving the canvas must not cancel the stroke session.
Re-entering must not create a line across the outside area.
```

A safe implementation approach:

```txt id="d31vhq"
- Keep `_activeDrawingPointer` active from primary pointer down until pointer up/cancel.
- Track whether the previous accepted dab was inside a continuous in-canvas segment.
- When the pointer is outside, set a flag such as `_breakCurrentVisibleSegment = true`.
- When the pointer re-enters, call the dab interpolator with `previous: null` for the first re-entry dab.
- Continue using canvas-space coordinates for committed BrushDab centers.
```

Do not introduce a separate user-facing stroke object yet unless needed. Keep the implementation minimal and modular.

### 3. Support pointer-down outside canvas

Currently drawing may only begin if pointer down starts inside the surface.

Change this so primary pointer down outside the canvas still begins a drawing stroke session.

The first in-canvas move should produce the first visible dab.

If the whole pointer session stayed outside the canvas, pointer up should commit nothing.

### 4. Add a simple canvas editor panel shell

Introduce a compact canvas panel shell inspired by the user's sketch.

The goal is not a full UI redesign. It should be a lightweight reusable shell around the current brush canvas editor.

Suggested structure:

```txt id="1qtxqp"
CanvasEditorPanelShell
  top title/status bar
  center content viewport
  right vertical scroll/pan strip
  bottom control/status bar
```

Top bar should show compact status text if the data is available:

```txt id="z4djxs"
- project name if available
- cut name if available
- layer name if available
- frame name or frame id if available
```

If not all names are available yet, use stable placeholders without forcing large architecture changes.

Bottom bar should contain or host current viewport controls:

```txt id="jbj69i"
- zoom percentage
- zoom out
- zoom in
- fit
- reset
- horizontal scroll/pan area placeholder or lightweight control
```

Right side may initially be a visual vertical scroll/pan strip or a simple `Scrollbar`/placeholder if real scrollbars are not yet wired.

Keep this simple.

Do not redesign the whole app.

Do not move timeline/storyboard logic.

Do not introduce new app-wide state management.

### 5. Keep viewport and source data boundaries intact

Preserve all Phase 226 rules:

```txt id="cb8yrk"
- CanvasViewport is UI-only.
- Viewport pan/zoom does not mutate Cut.canvasSize.
- Viewport pan/zoom does not mutate Project.cameraSize.
- Brush source dabs remain canvas-space.
- Brush source payload architecture stays unchanged.
```

### 6. Update docs

Update relevant current docs if behavior changes current policy.

Likely files:

```txt id="agcmfj"
docs/Current_Project_Architecture.md
docs/Current_UI_Product_Policy.md
docs/Current_Implementation_Roadmap.md
docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only
```

Do not edit Handoff sections 0 through 4.

Document:

```txt id="nn32vg"
- Canvas drawing display is clipped to Cut.canvasSize.
- Pointer leaving Cut.canvasSize does not cancel the stroke session.
- Re-entering Cut.canvasSize starts a new visible stroke segment and must not connect across the outside gap.
- Pointer down outside canvas may start a stroke session that commits only if in-canvas dabs are collected.
- The canvas editor shell is local UI, not source data.
```

## Tests

Add or update tests for stable behavior.

Required tests:

```txt id="hw29qe"
Brush boundary behavior:
- BrushEditCanvasView clips drawing to Cut.canvasSize.
- A stroke that leaves and re-enters the canvas does not connect across the outside gap.
- Pointer down outside canvas then entering canvas can commit visible in-canvas dabs.
- Pointer down outside canvas and never entering commits nothing.
- Pointer leaving canvas does not commit or clear the active stroke before pointer up.

Viewport/source behavior:
- Dabs committed after pan/zoom remain canvas-space.
- Boundary behavior still works after pan/zoom if feasible.

Panel shell behavior:
- Canvas editor panel shell renders top bar, center viewport, right strip, and bottom controls.
- Existing zoom/fit/reset controls remain accessible.
```

Avoid brittle tests that depend on exact text prose unless no better stable key exists.

Use stable ValueKeys for new shell regions, such as:

```txt id="ydj7xn"
canvas-editor-panel-shell
canvas-editor-panel-title-bar
canvas-editor-panel-content
canvas-editor-panel-right-strip
canvas-editor-panel-bottom-bar
```

## Non-goals

Do not implement:

```txt id="co1vul"
- Cut canvas size editing
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

Cut canvas size editing is intended for a later phase after canvas boundary behavior and panel shell are stable.

## Validation

Run if available:

```bash id="ngks6m"
dart format lib test docs
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If Dart or Flutter are unavailable, state that clearly and do not claim validation passed.

Manual checks:

```txt id="eooqsg"
1. Draw near the canvas edge. Marks should not visibly leak outside the canvas bounds.
2. Draw from inside to outside and back inside without lifting the pen. There should be no connecting stroke across the outside gap.
3. Start drawing outside the canvas, move into the canvas, then lift. The in-canvas part should commit.
4. Start and stay outside the canvas, then lift. Nothing should commit.
5. Pan/zoom should still work.
6. Drawing after pan/zoom should still land at the intended canvas coordinate.
7. Zoom/fit/reset controls should still work from the new shell.
8. Undo/redo should still work.
```

## PR requirements

Create a PR from `master`.

PR title:

```txt id="m4mq81"
Phase 227: Canvas boundary behavior and editor panel shell
```

PR description must mention:

```txt id="f5pf0i"
- clips active canvas display to Cut.canvasSize
- fixes outside/re-entry stroke segment behavior
- allows pointer-down outside canvas to begin a stroke session
- introduces a compact canvas editor panel shell
- keeps CanvasViewport UI-only and source dabs canvas-space
- does not implement Cut canvas size editing or Camera T1
```
