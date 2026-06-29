# Phase 210 Codex Task

## Title

Consolidate brush architecture documentation around the latest deferred-bake hybrid policy

## 1. Goal

Consolidate the brush-related architecture documentation so the repository has one clear, current brush architecture source of truth.

The latest policy is:

```txt
Deferred Bake Hybrid Brush History
```

This is the current source-of-truth direction:

```txt
Frame drawing payload:
  bakedBaseSurface
  + deferredBakePaintCommands
  + livePaintCommands
  + hiddenByUndoPaintCommands, if needed
  + inactivePreviewCache / playback preview cache
  + dirty flags
```

User-facing undo is based on recent live paint commands / stroke-like brush commands, not tile deltas.

Old paint commands may be compacted into `bakedBaseSurface`.

A custom user undo limit exists.

A deferred bake buffer exists separately from user undo. The default conceptual buffer is about 10 percent of the user undo limit.

Example:

```txt
userUndoLimit = 250
deferredBakeRatio = 10%
deferredBakeLimit = 25
```

The deferred bake buffer is not user-facing undo. It exists to avoid baking immediately during active drawing.

## 2. Why this phase is necessary

Current docs contain conflicting brush architecture statements.

Some docs describe the latest hybrid brush policy:

```txt
bakedBaseSurface
deferredBakePaintCommands
livePaintCommands
hiddenByUndoPaintCommands
inactivePreviewCache
dirty flags
```

Other older docs still describe tile-delta undo as if it were the main future direction:

```txt
Undo source = tile delta data
TileDeltaCommand
BeforeTileSnapshot
AfterTileSnapshot
Undo restores before tile data
```

That conflicts with the latest policy.

Phase 210 must remove that ambiguity.

## 3. Current latest policy to preserve

The latest brush policy is:

```txt
1. Brush input creates stroke-like / paint-command information.
2. Recent paint commands remain available for user-facing undo.
3. User-facing undo operates on recent live paint commands.
4. Undo moves/reverts recent paint commands according to UnifiedUndoHistory and BrushFrameStore rules.
5. Older commands beyond the custom undo limit move into a deferred bake buffer.
6. The deferred bake buffer is around 10 percent of the user undo limit by default.
7. Deferred bake buffer commands are not user-undoable.
8. Old deferred commands may eventually be baked into bakedBaseSurface.
9. bakedBaseSurface is bitmap/tile data containing compacted old artwork.
10. Active frame display is built from bakedBaseSurface + deferredBakePaintCommands + livePaintCommands + active stroke overlay.
11. Inactive frame / playback caches are derived images.
12. Cache images are not the source of truth.
13. Playback must use prepared preview/composite bitmap cache images.
14. Playback must not replay live paint commands.
15. Playback must not run live brush rasterization.
```

Important wording:

```txt
Stroke-like / paint-command information is kept for user-facing undo.
Bitmap baked base exists for compacted old artwork.
Preview/playback cache is derived from brush frame state.
Tile delta is not the current user-facing undo policy.
```

## 4. Documents to inspect

Inspect all brush-related docs, including at least:

```txt
docs/Brush_App_Integration_Decisions.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Brush_V1_Complete.md
docs/Brush_V1_Integration_Review.md
docs/Architecture.md
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Phase_*.md files that mention brush, Brush, BitmapSurface, Stroke, Undo, TileDelta, PlaybackPreviewCache, or deferred bake
```

Also inspect architecture tests that reference these docs.

Do not blindly delete files before checking whether tests reference them.

## 5. Required documentation outcome

Create one clear canonical current document:

```txt
docs/Brush_Architecture_Current.md
```

This document must be easy to read and should become the single current reference for brush architecture.

It must contain these sections:

```txt
# Brush Architecture Current

## Status

## Latest policy summary

## Core concepts

## Brush frame drawing state

## Active editing display

## User-facing undo / redo

## User undo limit and deferred bake buffer

## Baking policy

## Cache image generation

## Playback policy

## Frame / BrushFrameStore ownership

## What is current vs legacy

## Explicitly not the current policy

## Future implementation phases
```

The canonical document must clearly define:

```txt
bakedBaseSurface
deferredBakePaintCommands
livePaintCommands
hiddenByUndoPaintCommands
activeStrokeOverlay
inactivePreviewCache
playbackPreviewCache
dirty flags
userUndoLimit
deferredBakeRatio
deferredBakeLimit
UnifiedUndoHistory
BrushFrameStore
```

## 6. Required current architecture content

The canonical document must say:

```txt
The current brush architecture uses Deferred Bake Hybrid Brush History.
```

It must define the active frame display formula:

```txt
activeFrameDisplay =
  bakedBaseSurface
  + deferredBakePaintCommands
  + livePaintCommands
  + activeStrokeOverlay
```

It must define cache image generation:

```txt
inactivePreviewCache / playbackPreviewCache are derived images.

They are produced from the brush frame drawing state, such as:
  bakedBaseSurface
  + deferredBakePaintCommands
  + livePaintCommands

They are used for inactive frame display and playback.

They are not the source of truth.
```

It must define undo:

```txt
User-facing undo is based on recent live paint commands through UnifiedUndoHistory.

Undo should affect livePaintCommands / hiddenByUndoPaintCommands while the command is still within the user undo limit.

Deferred bake buffer commands are not user-undoable.

Baked commands are not user-undoable as individual commands.
```

It must define the undo limit and buffer:

```txt
userUndoLimit = user-configurable number of undoable brush commands
deferredBakeRatio = default approximately 10%
deferredBakeLimit = max(minimumBuffer, round(userUndoLimit * deferredBakeRatio))
```

It must explicitly say:

```txt
The deferred bake buffer is not buffer undo.
The deferred bake buffer is not user-facing undo.
It exists only to delay baking and keep active drawing responsive.
```

It must define playback:

```txt
Playback uses preview/composite bitmap cache images.

Playback must not replay live paint commands.
Playback must not replay old strokes.
Playback must not run brush rasterization.
Playback must not composite all layers from scratch every frame if a valid preview/composite cache exists.
```

## 7. Stale policy cleanup

The following policy must not remain as the current brush architecture:

```txt
Undo source = tile delta data
User-facing undo is TileDeltaCommand
Tile delta is the primary brush undo model
Brush display is based on replaying every old stroke
Playback replays strokes
Playback runs brush rasterization
```

Tile delta may be mentioned only as:

```txt
- legacy Brush V1 implementation detail; or
- possible future low-level optimization; or
- internal bitmap implementation detail;
```

but it must not be described as the latest user-facing undo policy.

## 8. What to do with existing docs

### docs/Brush_App_Integration_Decisions.md

Keep this file only if useful, but make it clearly defer to:

```txt
docs/Brush_Architecture_Current.md
```

At the top, add a clear notice:

```txt
Current brush architecture source of truth:
docs/Brush_Architecture_Current.md
```

This file may keep phase history if needed for existing tests, but the current-policy section must not conflict with the new canonical document.

If preserving phase history, label it as historical notes.

### docs/Bitmap_Canvas_Brush_Architecture.md

This file currently contains stale/conflicting tile-delta undo policy.

Choose one:

```txt
Option A:
Delete this file if no tests or current docs require it.

Option B:
Replace it with a short superseded notice pointing to docs/Brush_Architecture_Current.md.

Option C:
Move only non-conflicting bitmap/tile notes into docs/Brush_Architecture_Current.md and remove the stale file.
```

Do not leave it as an independent current architecture source if it still says tile delta is the undo source.

### docs/Brush_V1_Complete.md

This file may remain only as a legacy implementation snapshot.

If kept, add a clear notice:

```txt
Legacy Brush V1 smoke/dev/test stack document.
Not the current app-complete brush architecture source of truth.
Current source: docs/Brush_Architecture_Current.md
```

### docs/Brush_V1_Integration_Review.md

This file may remain only as a legacy review snapshot.

If kept, add a clear notice:

```txt
Legacy Brush V1 review document.
Not the current app-complete brush architecture source of truth.
Current source: docs/Brush_Architecture_Current.md
```

### docs/Phase_*.md

Phase task docs are historical task records.

Do not delete all phase task docs.

But if any architecture tests or indexes treat old Phase docs as current brush policy, update those tests/indexes so only `docs/Brush_Architecture_Current.md` is current.

## 9. Tests to add or update

Add or update architecture tests.

Suggested new test file:

```txt
test/architecture/brush_architecture_current_documentation_test.dart
```

The test should verify:

```txt
1. docs/Brush_Architecture_Current.md exists.
2. It contains "Deferred Bake Hybrid Brush History".
3. It contains bakedBaseSurface.
4. It contains deferredBakePaintCommands.
5. It contains livePaintCommands.
6. It contains hiddenByUndoPaintCommands.
7. It contains inactivePreviewCache.
8. It contains playbackPreviewCache.
9. It contains userUndoLimit.
10. It contains deferredBakeRatio.
11. It documents the default conceptual 10% deferred bake buffer.
12. It says user-facing undo is based on recent live paint commands.
13. It says deferred bake buffer is not user-facing undo.
14. It says cache images are derived images and not the source of truth.
15. It says playback must not replay live paint commands.
16. It says playback must not run live brush rasterization.
17. It says tile delta is not the current user-facing undo policy.
```

Add another test or extend the same test to verify stale docs are not treated as current:

```txt
- docs/Bitmap_Canvas_Brush_Architecture.md either does not exist, or contains a superseded notice pointing to docs/Brush_Architecture_Current.md.
- docs/Brush_V1_Complete.md, if it exists, contains a legacy/superseded notice.
- docs/Brush_V1_Integration_Review.md, if it exists, contains a legacy/superseded notice.
```

Also update any existing tests that assumed:

```txt
Undo source = tile delta data
TileDeltaCommand is the latest user-facing undo model
```

Those assumptions are stale.

## 10. Out of scope

This is a documentation and architecture-test consolidation phase.

Do not implement runtime behavior.

Do not change runtime brush code.

Do not change:

```txt
BrushFrameEditingCoordinator
BrushFrameStore runtime behavior
UnifiedUndoHistory runtime behavior
BrushCanvasPanel
MainCanvasBrushHost
BrushEditCacheInvalidationSink
CanvasView
HomePage
```

Do not implement:

```txt
actual deferred bitmap baking
actual playback cache implementation
actual save/load
renderer cache implementation
disk cache implementation
actual drawing changes
tablet pressure
eraser
selection
onion skin
Provider / Riverpod / Bloc / ChangeNotifier / global singleton state
```

Do not reintroduce:

```txt
BrushWorkspaceScreen
BrushWorkspaceView
Brush Workspace button
MainCanvasBrushHost.fixture()
BrushCanvasFixture under lib
debug controls
Frame 1 / Frame 2 / Frame 3 buttons
Debug Reset Session
Black / Red temporary buttons
```

## 11. Handoff rule

If updating:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
```

only update section 6 or later.

Do not edit sections 0 through 4.

This phase does not require handoff edits unless absolutely necessary.

## 12. Required search commands

Run repository searches and report the results:

```bash
rg "Deferred Bake Hybrid|deferredBake|bakedBaseSurface|livePaintCommands|hiddenByUndoPaintCommands|inactivePreviewCache|playbackPreviewCache" docs test lib

rg "Undo source = tile delta data|TileDeltaCommand|BeforeTileSnapshot|AfterTileSnapshot|CompressedTileDelta|tile delta" docs test lib

rg "Brush_Architecture_Current|Brush_App_Integration_Decisions|Bitmap_Canvas_Brush_Architecture|Brush_V1_Complete|Brush_V1_Integration_Review" docs test
```

Expected:

```txt
- The latest policy appears in docs/Brush_Architecture_Current.md.
- Stale tile-delta-as-current-undo wording is removed or explicitly marked as legacy/non-current.
- Old brush docs either point to the current document, are deleted, or are clearly marked legacy/superseded.
```

## 13. Checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## 14. Acceptance criteria

```txt
1. docs/Brush_Architecture_Current.md exists.
2. It clearly documents Deferred Bake Hybrid Brush History as the latest policy.
3. It clearly documents stroke-like / paint-command-based user-facing undo.
4. It clearly documents the custom user undo limit.
5. It clearly documents the 10% deferred bake buffer concept.
6. It clearly says deferred bake buffer is not user-facing undo.
7. It clearly documents cache image generation from bakedBaseSurface + deferredBakePaintCommands + livePaintCommands.
8. It clearly says cache images are derived images, not source of truth.
9. It clearly says playback must use preview/composite bitmap cache.
10. It clearly says playback must not replay live paint commands.
11. It clearly says playback must not run brush rasterization.
12. docs/Bitmap_Canvas_Brush_Architecture.md is deleted, integrated, or clearly superseded.
13. docs/Brush_V1_Complete.md is deleted, integrated, or clearly marked legacy.
14. docs/Brush_V1_Integration_Review.md is deleted, integrated, or clearly marked legacy.
15. Existing architecture tests are updated.
16. New architecture test protects the latest policy.
17. Runtime code is unchanged.
18. No deleted workspace UI/debug controls are reintroduced.
19. flutter analyze passes.
20. flutter test passes.
```

## 15. Report back

Report:

```txt
- all brush-related docs inspected
- which docs were kept
- which docs were deleted
- which docs were rewritten as legacy/superseded
- new canonical doc path
- latest brush policy summary
- how stale tile-delta undo wording was handled
- whether user-facing undo is now documented as paint-command/stroke-command based
- whether 10% deferred bake buffer is documented
- whether cache image generation is documented
- tests added/updated
- runtime code changed or not
- checks run and results
- rg search summary
- git status summary
```
