# Phase 225 Codex Task — Brush T2 Stabilization and Documentation Cleanup

## Context

Phase 224 / PR #294 stabilized the production brush editing route after PR #293 failed manual testing.

PR #293 must be treated only as a failed reference. It must not be used as the current architecture direction.

The current accepted direction after Phase 224 is:

```txt
- active brush drawing is pixel-grid / bitmap-like
- active drawing does not use display preview cache as the active edit display
- active drawing does not use drawPath-based smooth vector rendering
- active drawing uses sampled BrushDab stamp-style display
- brush strokes participate in app-level global undo/redo
- undo/redo keeps the selected timeline frame stable
```

This phase must not introduce major new features. It is a stabilization and documentation phase before moving on to the canvas viewport / canvas UI / pan-zoom work.

## Goal

Stabilize Brush T2 by updating current documentation and guard tests so that the Phase 224 brush route becomes the clear current baseline.

After this phase, future work should be able to move safely into canvas viewport and canvas UI phases without reopening PR #293-style brush display mistakes.

## Scope

Allowed files:

```txt
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Implementation_Roadmap.md
docs/Current_Test_Architecture.md
docs/Current_Docs_Index.md
docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only
test/architecture/
test/ui/
test/services/
```

Runtime code changes are allowed only if needed to fix incorrect comments, stale names, or tests that still refer to removed legacy behavior.

Do not add new brush features.

Do not add canvas pan/zoom yet.

Do not add cut canvas size editing yet.

Do not add save/load yet.

Do not add playback/cache playback implementation yet.

## Required documentation updates

Update the current documents to reflect the actual Phase 224 baseline.

Document that Brush T2 currently uses:

```txt
source:
  BrushFrameDrawing.commands + hiddenCommandIds

active display:
  visible BrushPaintCommand source dabs
  + active sampled BrushDab overlay

undo/redo:
  app-level HistoryManager
  + BrushStrokeHistoryCommand
  + BrushFrameEditingCoordinator / BrushFrameStore hiddenCommandIds
```

Document that the active edit display must not use inactive preview cache or playback preview cache.

Document that active editing does not use:

```txt
- displayPreviewSurface as active editor base
- drawPath-based smooth brush display
- per-pixel accumulated BitmapSurface repaint during pointer movement
- source-destroying bake on pointer release
- TileDelta / TileDeltaCommand
```

Document that preview/cache images remain derived data and are not the source of truth.

## PR #293 failure note

Add a concise note, in the appropriate current docs or handoff continuation section, that PR #293 failed manual testing because:

```txt
- active drawing became unusably slow
- app-level undo did not undo brush strokes correctly
- active edit display risked mixing preview cache into the active editing path
```

Do not over-document old implementation details. The note should exist only to prevent future agents from repeating the same architectural mistake.

## PR #294 baseline note

Add a concise note that PR #294 superseded PR #293 and established the current Brush T2 baseline:

```txt
- sampled dab stamp active overlay
- no active drawPath route
- no active displayPreviewSurface route
- app-level brush undo/redo integration
- timeline frame selection preserved after undo/redo
```

## Guard test updates

Review existing tests and architecture guards.

Keep tests focused on stable behavior and forbidden legacy boundaries.

Good tests:

```txt
- active brush display does not use drawPath
- active brush editing route does not pass displayPreviewSurface into BrushEditCanvasView / InteractiveBrushEditCanvasView
- active brush route does not use TileDelta or TileDeltaCommand
- brush strokes participate in app-level undo/redo
- undo/redo hides/restores brush commands through source command visibility
- timeline frame selection remains stable after undo/redo
```

Avoid brittle tests that check:

```txt
- exact documentation prose
- exact markdown headings
- private helper method names
- temporary implementation details that may be refactored safely
```

Architecture guard tests may use narrow forbidden-string checks only for legacy paths that must not return.

## Explicit non-goals

Do not implement:

```txt
- canvas pan/zoom
- viewport state
- cut canvas size editing UI
- save/load
- playback
- tile image cache rendering
- full deferred baking
- layer groups / masks / blend modes
- Provider / Riverpod / ChangeNotifier / Bloc
```

These are future phases.

## Next phase preparation

At the end of the documentation updates, make the roadmap clearly point to the next canvas phase:

```txt
Phase 226:
  Canvas viewport foundation

Likely scope:
  - pan
  - zoom
  - fit to view
  - reset view
  - separate viewport transform from drawing coordinates
  - keep Cut.canvasSize as drawing bounds
  - keep viewport state out of drawing source data
```

Cut canvas size editing should come after viewport foundation, likely Phase 227.

## Validation

Run locally if available:

```bash
dart format docs test lib
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If Flutter/Dart are unavailable, state that clearly and do not claim validation passed.

## PR requirements

Create a PR from `master`.

The PR title should be:

```txt
Phase 225: Brush T2 stabilization and documentation cleanup
```

The PR description must mention:

```txt
- documents PR #294 as the current Brush T2 baseline
- records PR #293 as superseded / failed reference
- reinforces active edit display boundaries
- reinforces global brush undo/redo boundaries
- prepares roadmap for canvas viewport work
```
