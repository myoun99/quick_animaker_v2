# Phase 221 — Brush T2 Visible Stroke Rendering Refinement

## Goal

Refine Brush T2 visible stroke rendering so the current production brush path feels stable during real drawing.

The brush should remain lightweight and source-driven.

Current display direction:

```txt
active frame display =
  visible BrushPaintCommands
  + activeStrokeOverlay
```

## In scope

* Inspect current brush input, active overlay, commit, undo, redo, and repaint paths.
* Make tap strokes visibly appear.
* Make drag strokes show live feedback while drawing.
* Make committed source strokes remain visible after pointer up.
* Make undo hide committed commands through `hiddenCommandIds`.
* Make redo restore hidden commands.
* Keep fast strokes visually continuous without locking tests to exact dab counts.
* Keep tiny movement from creating excessive duplicate dabs.
* Keep active stroke overlay temporary.
* Keep source brush drawing data owned by `BrushFrameStore`.

## Out of scope

* Save/load
* Playback cache
* Inactive preview cache
* Full renderer
* Deferred bake implementation
* Bitmap compaction
* Timeline expansion
* Onion skin
* Layer compositing overhaul
* Brush preset system
* Advanced brush settings UI
* Provider / Riverpod / Bloc / ChangeNotifier
* Brush-specific undo/redo controls
* Separate drawable-area model
* Export system

## Architecture constraints

* Do not store brush source payloads inside `Frame`.
* Do not add `visibleCommandCount`.
* Do not generate cache images during live drawing.
* Do not bake bitmap data during live drawing.
* Do not bake merely because pointer up happened.
* Do not reintroduce `TileDelta` / `TileDeltaCommand` into brush commit, history, undo/redo, or cache-invalidation APIs.
* Do not reintroduce the old 320 x 240 production brush canvas default.
* Drawing bounds remain active `Cut.canvasSize`.

## Tests

Tests should verify behavior and stable boundaries.

Preferred coverage:

* tap stroke becomes visible
* drag stroke gives live feedback
* committed stroke remains visible after pointer up
* undo hides source command through `hiddenCommandIds`
* redo restores source command
* active overlay clears after commit
* fast drag creates non-broken visible stroke without exact count locking
* tiny movement avoids excessive duplicate dabs without exact count locking
* live editing does not generate cache images or bake bitmap data
* production UI still uses global undo/redo path only

Do not add tests that assert exact documentation prose.

Do not add positive source-string checks for private implementation names.

## Validation

Run:

```bash
dart format lib test
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
git status
```

GitHub Actions CI must pass:

* Check formatting
* Analyze
* Test
