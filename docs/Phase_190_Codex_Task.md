# Phase 190 Codex Task

## Title

Brush V1 integration review bundle

## Current position

```txt id="j7dbf2"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-20. Brush V1 integration review bundle
```

## Brush work detailed roadmap

```txt id="xwefrw"
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
1-20. Brush V1 integration review bundle - current
1-21. Brush work v1 complete - planned
```

## Goal

Perform a final Brush V1 integration review before declaring the brush work v1 complete.

This phase should not add new user-facing brush features.

The purpose is to:

```txt id="vv7d1q"
1. Confirm the brush stack is internally consistent.
2. Reduce duplicated brush test helpers if practical.
3. Add scope guard tests for the completed Brush V1 boundary.
4. Document the current Brush V1 architecture and remaining out-of-scope items.
5. Make sure StoryboardPanel and TimelinePanel remain untouched.
6. Make sure no main app wiring is introduced yet.
```

This is a cleanup / review / guard phase.

Do not turn it into a new feature phase.

## Required files

Likely modify:

```txt id="de6d90"
test/ui/brush_canvas_test_helpers.dart
test/ui/interactive_brush_edit_canvas_view_test.dart
test/ui/interactive_brush_canvas_smoke_host_test.dart
test/ui/brush_canvas_smoke_screen_test.dart
```

Create:

```txt id="ktob47"
docs/Brush_V1_Integration_Review.md
```

Create if useful:

```txt id="lja9ze"
test/architecture/brush_v1_scope_guard_test.dart
```

Do not create more files than necessary.

Expected PR size:

```txt id="wkx3d3"
3 to 6 changed files is acceptable.
Production code changes should be avoided unless a real issue is found.
```

## Important principle

Prefer:

```txt id="pm9skr"
- documentation
- test helper cleanup
- source boundary guard tests
- small test stability improvements
```

Avoid:

```txt id="uad674"
- new brush behavior
- new UI controls
- new production toolbar
- app route wiring
- main.dart wiring
- state management package
- renderer/cache/persistence changes
```

## Brush V1 architecture document

Create:

```txt id="hwc21x"
docs/Brush_V1_Integration_Review.md
```

The document should summarize the current Brush V1 stack.

Include these sections:

```txt id="zyt5q1"
# Brush V1 Integration Review

## Status
Brush V1 is internally implemented as a testable smoke/dev stack, not yet wired into the main app.

## Core data flow
Pointer input -> BrushDabSequence -> commit facade -> BrushEditSessionState -> BitmapSurface tile changes -> cache invalidation result -> UI rebuild.

## Bitmap principle
Final visible artwork is BitmapSurface tile data.
BrushDabSequence is transient input/commit data.
Stroke is not the permanent display source of truth.

## Session state
BrushEditSessionState owns CanvasSurfaceState and BrushEditHistoryState.
InteractiveBrushEditCanvasView performs commit.
InteractiveBrushCanvasSmokeHost can own local session state or accept explicit session replacement via sessionResetToken.
BrushCanvasSmokeScreen owns canonical smoke/dev session state for undo/redo/reset controls.

## Undo / Redo
Undo/redo are based on existing BrushEditHistoryState and cache-aware session facades.
Do not replay strokes for display.

## Cache invalidation
Commit/undo/redo use cache invalidation plans/results.
Smoke screen uses a recording sink only.
No renderer cache or disk cache is implemented here.

## UI status
BitmapSurfacePainter is display-only.
BrushEditCanvasView displays a BitmapSurface.
InteractiveBrushEditCanvasView handles pointer input and commits.
InteractiveBrushCanvasSmokeHost is a local/stateful smoke host.
BrushCanvasSmokeScreen is a dev/manual harness with undo/redo/reset/color presets.

## Explicitly out of scope
Main app wiring.
Production toolbar.
Layer panel integration.
Timeline integration.
Storyboard integration.
Save/load.
Renderer cache.
Disk cache.
Onion skin.
Playback preview.
Stylus pressure.
Smoothing.
Eraser.
Selection.

## Regression coverage
Summarize the important test coverage:
- tap commit
- drag commit
- repeated strokes
- pointer cancel
- multi-pointer handling
- out-of-bounds movement
- undo/redo/reset
- color presets
- canvas-relative gesture helpers
- host sessionResetToken behavior
```

Keep this document factual.

Do not describe features that do not exist yet as completed.

## Test helper cleanup

Review:

```txt id="wqqg7j"
test/ui/brush_canvas_test_helpers.dart
test/ui/interactive_brush_edit_canvas_view_test.dart
test/ui/interactive_brush_canvas_smoke_host_test.dart
test/ui/brush_canvas_smoke_screen_test.dart
```

If there are repeated helpers that can be safely consolidated, move them into `brush_canvas_test_helpers.dart`.

Good candidates:

```txt id="p9y1na"
- canvas-relative tap/drag helpers
- common small CanvasSize / tileSize helper
- FakeCacheInvalidationSink if duplicated across brush tests
```

Do not over-abstract.

Do not make tests harder to read.

Do not import test helpers into production code.

## Scope guard test

If practical, add:

```txt id="mobgpe"
test/architecture/brush_v1_scope_guard_test.dart
```

This test may use `dart:io` to inspect source files.

It should guard against accidental scope expansion.

Suggested assertions:

```txt id="wcxx5j"
- lib/main.dart does not import BrushCanvasSmokeScreen.
- production app route files do not import BrushCanvasSmokeScreen if such route files exist.
- BrushCanvasSmokeScreen source does not contain Provider, Riverpod, Bloc, ChangeNotifier, or InheritedWidget.
- BrushCanvasSmokeScreen source does not contain commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation.
- StoryboardPanel source does not import brush canvas smoke screen files.
- TimelinePanel source does not import brush canvas smoke screen files.
```

Make the guard robust.

If a referenced file path does not exist, do not fail just because the optional file is absent.

Do not write fragile tests that depend on exact formatting.

## Production code rules

Do not modify production code unless absolutely necessary.

Do not add:

```txt id="zwqtpv"
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

```txt id="f2otfa"
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

Do not call the commit facade directly from `BrushCanvasSmokeScreen`.

Commit should remain inside `InteractiveBrushEditCanvasView`.

Undo/redo controls may keep using the existing cache-aware undo/redo facades.

## Required checks

Run if available:

```bash id="s99o8g"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Report back

Report:

```txt id="w7akco"
- changed files
- whether production code was changed
- Brush V1 review document summary
- test helper cleanup summary
- scope guard summary
- remaining out-of-scope confirmations
- check results
- git status summary
```
