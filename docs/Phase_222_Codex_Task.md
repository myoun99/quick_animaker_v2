# Phase 222 Codex Task — Brush Frame Display Cache Foundation

## Goal

Implement the first real brush frame display-cache foundation so heavy frames do not need to replay all source strokes whenever the frame is displayed, scrubbed, or revisited.

This phase addresses the observed performance problem:

* live pointer movement improved after PR #291
* but frames with many long committed strokes still become heavy
* frame ruler / timeline scrubbing becomes very slow when drawings accumulate
* starting a new stroke on a heavy frame can still stutter because the existing frame display is expensive

The goal is to make displayed brush frame content reuse a derived bitmap/preview cache instead of repeatedly repainting all committed source strokes.

## Current architecture rules to preserve

Read these files directly before implementing:

* `docs/Handoff_QuickAnimaker_v2_Current.md`
* `docs/Current_Docs_Index.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_Test_Architecture.md`

Preserve these rules:

* source drawing data remains `BrushFrameDrawing.commands + hiddenCommandIds`
* cache images are derived, not source of truth
* `Frame` must remain lightweight
* brush source payloads and derived cache-like payloads belong in `BrushFrameStore` or an equivalent brush/canvas storage boundary
* user-facing undo/redo remains global
* hidden brush commands are handled through `hiddenCommandIds`
* no brush-specific undo/redo controls
* no `visibleCommandCount`
* no `TileDelta` / `TileDeltaCommand`
* no Provider / Riverpod / Bloc / ChangeNotifier
* no save/load implementation
* no full renderer implementation
* no timeline architecture rewrite
* no playback engine implementation
* no onion skin
* no new user-facing animation layer

## Important live-editing rule

Do not generate cache images in the live stroke editing hot path.

Specifically:

* do not bake while the pointer is moving
* do not generate preview/cache images on every pointer move
* do not make pointer movement wait for cache generation
* do not fully bake merely because pointer up happened
* do not turn cache data into source of truth

Pointer up may mark the current brush frame cache as dirty, but it must not trigger an expensive full-frame synchronous rebuild in the pointer-up hot path.

## Required implementation direction

Introduce a derived display-cache boundary for brush frame display.

Suggested names are flexible, but the structure should be equivalent to:

```txt
BrushFrameDisplayCache
- frameKey: BrushFrameKey
- previewSurface: BitmapSurface
- dirty: bool
- dirtyRegion / dirtyBounds if practical
- sourceRevision or commandRevision
```

or:

```txt
BrushFramePreviewCache
- BrushFrameKey -> cached BitmapSurface preview
- dirty keys / dirty regions
```

The cache must be clearly derived data.

The cache must be rebuildable from source commands.

The cache must not be persisted as required source data.

## Display policy

When a brush frame has a valid preview/display cache:

```txt
display =
  cached preview surface
  + active stroke overlay, only while editing the active frame
```

When cache is missing or dirty:

* for active editing, keep the UI responsive
* fall back to the lightest existing source-backed display only when necessary
* mark / prepare cache outside pointer-move hot path
* do not block live pointer movement with full source replay

For inactive frame display, frame ruler dragging, and timeline scrubbing:

* prefer a valid preview/display cache
* do not replay all live paint commands during scrub if a valid cache exists
* do not run brush rasterization repeatedly in the scrub hot path

## BrushFrameStore ownership

Extend `BrushFrameStore` or an adjacent brush/canvas storage service so it owns both:

```txt
source:
- BrushFrameDrawing.commands
- BrushFrameDrawing.hiddenCommandIds

derived:
- display preview/cache surface
- dirty status
- revision metadata
```

Do not put the cache directly in `Frame`.

Do not put heavy brush source payloads in `Frame`.

## Dirty invalidation

When a source brush command is committed, undone, or redone:

* keep source command semantics unchanged
* mark the relevant frame display cache dirty
* if practical, mark only the affected dirty bounds/region
* otherwise mark the frame cache dirty as a first implementation

Do not use `TileDelta` or `TileDeltaCommand` for brush runtime/cache invalidation.

Dirty region / dirty tile concepts are allowed as cache invalidation boundaries.

## Rendering / rebuilding cache

Add a small rebuild path that can render the current visible brush commands into a derived `BitmapSurface` preview.

The first implementation may rebuild the full frame preview when dirty if dirty-region rebuild is too large for this phase.

However:

* keep the API shaped so dirty-region / dirty-tile rebuild can be added later
* keep source and derived cache separate
* do not make rebuilding happen during pointer move
* avoid making frame ruler drag replay source commands every frame

## UI integration

Wire the display cache into the current canvas/frame display route.

Expected behavior:

* while actively drawing, the current active stroke still appears immediately
* after commit, the source command is preserved
* the frame cache is marked dirty
* when the frame is displayed again or prepared outside live input, the cache can be used
* frame ruler / timeline scrubbing should prefer cached previews instead of repainting all source strokes

Do not create a new user-facing animation layer.

The active overlay must remain a temporary display pass for the currently edited frame/layer, not a durable layer.

## Long active stroke note

Do not solve long active stroke segmentation in this phase unless it is a tiny isolated helper.

This phase is primarily about committed frame display/cache.

Long active stroke optimization can be a later phase.

## Tests

Add behavior-focused tests.

Tests should verify:

* cache images are derived and not source of truth
* source commands remain preserved after cache generation
* `Frame` does not own brush payloads or cache payloads
* committing a brush source command marks the relevant frame display cache dirty
* undo/redo dirty the relevant frame display cache while preserving `hiddenCommandIds` semantics
* a valid cache can be used for display without replaying all source strokes
* active stroke overlay remains temporary and is not stored in the preview cache
* live pointer movement does not generate cache images
* preview/cache rebuild does not use `TileDelta` / `TileDeltaCommand`
* Provider / Riverpod / Bloc / ChangeNotifier are not introduced
* frame ruler / inactive frame display path prefers preview cache when available, if that path already exists

Do not add timing-based flaky performance tests.

Do not assert exact sampled dab counts unless the count is a public contract.

Do not add tests that verify exact documentation wording.

## Validation

Run:

```bash
dart format lib test
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
git status
```

## PR title

`Phase 222 — Brush frame display cache foundation`

## PR body must explain

* why source stroke replay became a performance bottleneck
* what derived display/preview cache was introduced
* how source-of-truth remains in brush source commands
* how dirty marking works
* why live pointer movement does not generate cache images
* how this helps frame ruler / timeline scrubbing
* what was intentionally deferred
* validation results
