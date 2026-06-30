# Phase 191 Codex Task

## Title

Brush V1 complete checkpoint / Storyboard transition prep

## Current position

```txt
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-21. Brush V1 complete checkpoint / Storyboard transition prep
```

## Goal

Close the Brush V1 work area as a stable internal milestone and prepare the project to move into Storyboard panel work.

This phase should not add new brush features.

This phase should not wire BrushCanvasSmokeScreen into the main app.

This phase should not modify production brush behavior unless a real inconsistency is found.

The goal is to:

```txt
1. Mark Brush V1 as complete at the smoke/dev/test level.
2. Summarize what is complete and what remains intentionally out of scope.
3. Preserve the Brush V1 architectural boundary.
4. Prepare a clear Storyboard work entry plan for the next phase.
5. Keep StoryboardPanel and TimelinePanel behavior unchanged.
```

## Brush work completed roadmap

```txt
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - done
1-9. Redo execution service - done
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit - done
1-11. Cache invalidation execution service - done
1-12. BrushEditSessionState + session operation facade - done
1-13. Cache-aware commit / undo / redo facade - done
1-14. BitmapSurface display-only Canvas UI - done
1-15. Canvas pointer input -> brush commit - done
1-16. Interactive brush canvas smoke host - done
1-17. Brush canvas smoke screen / manual harness - done
1-18. Brush canvas dev controls bundle - done
1-19. Brush input polish / repeated stroke regression bundle - done
1-20. Brush V1 integration review bundle - done
1-21. Brush V1 complete checkpoint / Storyboard transition prep - current
```

## Required files

Create:

```txt
docs/Brush_V1_Complete.md
docs/Storyboard_Work_Roadmap.md
```

Likely modify only if needed:

```txt
docs/Brush_V1_Integration_Review.md
test/architecture/brush_v1_scope_guard_test.dart
```

Do not modify production `lib/` files unless a real inconsistency is found.

Expected PR size:

```txt
2 to 4 changed files is expected.
Production code changes should normally be zero.
```

## Brush V1 complete document

Create:

```txt
docs/Brush_V1_Complete.md
```

This document should be factual and conservative.

Include these sections:

```txt
# Brush V1 Complete

## Status

Brush V1 is complete as an internal smoke/dev/test stack.

It is not yet wired into the main app.

## Completed capabilities

- BitmapSurface / BitmapTile storage foundation.
- BrushDab / BrushDabSequence transient input model.
- Brush pixel blending.
- BrushDabSequence commit to BitmapSurface.
- CanvasSurfaceState integration.
- Brush edit history entries.
- Brush edit history state.
- Undo service.
- Redo service.
- Cache invalidation execution.
- BrushEditSessionState.
- Cache-aware commit / undo / redo facades.
- Display-only BitmapSurfacePainter.
- BrushEditCanvasView.
- InteractiveBrushEditCanvasView pointer input.
- InteractiveBrushCanvasSmokeHost.
- BrushCanvasSmokeScreen dev/manual harness.
- Undo / redo / reset / color preset dev controls.
- Regression coverage for tap, drag, repeated strokes, pointer cancel, multi-pointer, out-of-bounds movement, undo, redo, reset, color presets, canvas-relative gestures, and sessionResetToken behavior.
- Scope guards preventing accidental main app wiring and direct smoke-screen commit calls.

## Source of truth

Final visible artwork is BitmapSurface tile data.

BrushDabSequence is transient input data.

Stroke or dab sequence replay is not the permanent display source of truth.

## Current UI boundary

Brush V1 exists as a smoke/dev/test stack.

The main app does not expose BrushCanvasSmokeScreen.

No production toolbar has been implemented.

No layer panel integration has been implemented.

No TimelinePanel integration has been implemented.

No StoryboardPanel integration has been implemented.

## Intentionally out of scope

- Main app route wiring.
- Production brush toolbar.
- Layer panel integration.
- Timeline integration.
- Storyboard integration.
- Save/load.
- Renderer cache.
- Disk cache.
- Onion skin.
- Playback preview.
- Stylus pressure.
- Smoothing.
- Eraser.
- Selection.
- Brush cursor.
- Brush preview overlay.

## Next area

The next major work area is Storyboard panel work.

Brush V1 should remain stable while Storyboard work proceeds.
```

Do not claim that user-facing brush drawing is complete.

Do not claim that app-level brush editing is complete.

Say clearly that Brush V1 is complete only as an internal smoke/dev/test stack.

## Storyboard roadmap document

Create:

```txt
docs/Storyboard_Work_Roadmap.md
```

This document should prepare the next major work area.

It should not implement Storyboard changes.

Include these sections:

```txt
# Storyboard Work Roadmap

## Status

StoryboardPanel already exists and has stable smoke/interaction tests.

The next work area should improve StoryboardPanel carefully without destabilizing TimelinePanel or Brush V1.

## Protected existing semantics

- Storyboard is represented as an ordinary Layer with kind storyboard.
- A Cut may have at most one storyboard layer.
- Storyboard layers are included in Cut.layers.
- StoryboardPanel is a project overview / cut planning surface, not the drawing canvas.
- Do not add a separate Cut.storyboardLayer.panels model.
- Do not treat storyboard as a separate non-layer system.

## Protected stable keys

List these protected keys exactly:

- storyboard-panel
- storyboard-track-row-<trackId>
- storyboard-track-timeline-area-<trackId>
- storyboard-cut-block-<cutId>
- storyboard-cut-positioned-<cutId>
- storyboard-layer-strip-<cutId>
- storyboard-layer-empty-<cutId>
- storyboard-cut-active-indicator-<cutId>
- storyboard-timeline-horizontal-viewport

## Protected tests

Mention that these tests must remain passing:

- test/ui/storyboard_panel_smoke_test.dart
- test/ui/storyboard_panel_interaction_test.dart
- timeline semantics tests
- brush canvas tests

## Storyboard work principles

- Do not refactor TimelinePanel unless a test-proven issue requires it.
- Do not change layer ordering semantics.
- Do not change Cut.duration semantics.
- Do not introduce brush drawing into StoryboardPanel yet.
- Do not wire BrushCanvasSmokeScreen into StoryboardPanel.
- Do not create a separate storyboard persistence model yet.
- Keep changes incremental and test-driven.

## Candidate next phases

Propose a conservative next sequence:

1. Storyboard current-state audit and guard tests.
2. Storyboard selection / active cut interaction polish.
3. Storyboard cut block layout stability.
4. Storyboard layer strip metadata display.
5. Storyboard empty-state and edge-case regression tests.
6. Storyboard-to-canvas handoff planning, without wiring brush UI yet.

## Out of scope for the next Storyboard phase

- Actual canvas drawing inside StoryboardPanel.
- Brush engine integration.
- Save/load.
- Renderer/cache integration.
- Timeline virtualization.
- Layer panel rewrite.
- App-wide state management package.
```

Keep this roadmap practical.

Do not over-promise.

Do not describe unimplemented features as complete.

## Scope guard update

Review:

```txt
test/architecture/brush_v1_scope_guard_test.dart
```

If it is already sufficient, do not change it.

Only update it if useful to guard the Brush V1 completion boundary.

Allowed small additions:

```txt
- assert docs/Brush_V1_Complete.md exists
- assert docs/Storyboard_Work_Roadmap.md exists
- assert BrushCanvasSmokeScreen remains absent from lib/main.dart
```

Do not make the guard brittle.

Do not fail on optional route files that do not exist.

## Production code rules

Do not add or modify production behavior.

Do not add:

```txt
Provider
Riverpod
Bloc
ChangeNotifier
Global singleton state
Main app wiring
App route wiring
Production toolbar
Layer UI
Timeline integration
Storyboard integration
Save/load
Renderer cache
Disk cache
```

Do not implement:

```txt
onion skin
layer compositing
frame compositing
playback preview
cache storage
cache recomputation
brush cursor
brush preview overlay
stroke smoothing
stylus pressure
eraser
selection
```

Do not call the commit facade directly from BrushCanvasSmokeScreen.

Do not wire BrushCanvasSmokeScreen into StoryboardPanel, TimelinePanel, or main.dart.

## Required checks

Run if available:

```bash
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Report back

Report:

```txt
- changed files
- whether production code changed
- Brush V1 completion summary
- Storyboard roadmap summary
- scope guard changes, if any
- out-of-scope confirmations
- check results
- git status summary
```
