# Phase 224 Codex Task — Brush Display Performance and App-Level Brush Undo

## Context

This task supersedes PR #293.

PR #293 must remain open only as a failed reference and must not be merged.

Create a new PR from `master`.

Do not branch from PR #293.

Do not assume PR #293 will be merged.

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool. The goal remains a TVPaint-style bitmap animation workflow.

The current brush direction is still valid:

```txt
source:
  BrushPaintCommand / BrushDab source data

visible display:
  pixel-grid / bitmap-like output
```

However, manual testing of PR #293 found release-blocking regressions:

```txt
1. Active drawing is unusably slow, especially with long fast strokes.
2. Normal app-level Undo does not undo brush strokes.
3. Normal app-level Redo does not restore brush strokes.
```

PR #293 did partially fix visual consistency:

```txt
- strokes look bitmap-like
- starting a second stroke does not change the previous stroke appearance
```

But the performance and undo regressions make it unusable.

## Goal

Implement Phase 224:

```txt
Brush display performance and app-level brush undo integration.
```

This phase must produce a usable brush editing path:

```txt
- active strokes remain pixel-grid / bitmap-like
- committed strokes remain visually stable
- long fast strokes are responsive enough for real drawing
- normal app-level Undo removes the latest brush stroke
- normal app-level Redo restores the latest brush stroke
- frame/project/timeline undo behavior does not regress
```

## Scope

This phase may modify:

```txt
lib/src/ui/canvas/
lib/src/ui/brush/
lib/src/services/
lib/src/models/
test/ui/
test/services/
test/architecture/
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Docs_Index.md
docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only, if needed
```

Do not edit sections 0 through 4 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

## Important failure from PR #293

PR #293 introduced a bitmap display path, but active drawing became too slow.

The likely reason is that `BitmapSurfacePainter` paints bitmap data by iterating over pixels and calling `canvas.drawRect` for each non-transparent pixel.

That is not acceptable in the active drawing hot path.

## Required performance fix

Active stroke pointer movement must not use a full accumulated `BitmapSurfacePainter` repaint that loops through every active stroke pixel.

During pointer movement:

```txt
Do not repaint the accumulated active stroke by iterating all pixels.
Do not call canvas.drawRect once per stored bitmap pixel for the whole active stroke.
Do not use a smooth vector drawPath brush display.
```

Acceptable direction for this phase:

```txt
- Keep BrushPaintCommand / BrushDab as source data.
- During active pointer movement, display sampled dabs/stamps through a fast pixel-grid painter.
- Use Paint.isAntiAlias = false.
- Snap active display to the pixel grid where appropriate.
- Use drawRect / drawCircle / drawPoints / stamp-like drawing only if it stays pixel-grid and fast.
- Avoid drawPath-based smooth vector rendering.
- On pointer up, commit the source command and update the derived edit composite.
```

Long-term tile-image rendering may be deferred, but the current per-pixel active hot path must not remain.

Future direction may include:

```txt
BitmapTile -> ui.Image tile cache
canvas.drawImage / drawImageRect
dirty-tile retained rendering
```

But this phase should choose the smallest safe implementation that makes drawing usable again.

## Required visual behavior

Manual behavior must remain:

```txt
1. Draw the first stroke.
2. Start drawing a second stroke.
3. The first stroke must not change appearance.
4. The active stroke must look pixel-grid / bitmap-like, not smooth vector-like.
5. Releasing the pointer must not visibly change the stroke shape/style.
```

## Required app-level undo behavior

Brush stroke undo must work from the normal app Undo command, not only from an internal brush-specific route.

Required behavior:

```txt
1. Create a frame or use an existing editable frame.
2. Draw a brush stroke.
3. Trigger the normal app-level Undo command.
4. The latest brush stroke disappears.
5. Trigger the normal app-level Redo command.
6. The brush stroke returns.
7. Frame creation / timeline / project undo behavior must still work.
```

Choose the safer long-term integration based on the current code.

Possible approaches:

```txt
A. Route app-level undo/redo to the active BrushFrameEditingCoordinator when the latest undoable action is a brush stroke.

or

B. Integrate brush stroke entries into the app-level global undo stack so brush strokes participate in the same undo order as frame/project/timeline operations.
```

Do not create a separate user-facing brush undo UI.

User-facing undo remains global.

## Forbidden architecture

Do not reintroduce:

```txt
- TileDelta
- TileDeltaCommand
- brush stroke undo based on tile deltas
- TileDelta/TileDeltaCommand as source data
- TileDelta/TileDeltaCommand as commit result
- TileDelta/TileDeltaCommand as undo/redo payload
- TileDelta/TileDeltaCommand as brush history entry
- TileDelta/TileDeltaCommand as cache invalidation API
- source-destroying bake on pointer release
- inactive preview cache as active edit display
- smooth drawPath-based vector brush display
- Provider / Riverpod / ChangeNotifier / Bloc
```

`DirtyTileSet` is allowed only as display/cache invalidation metadata.

It must not become source of truth.

It must not become a user-facing undo payload.

It must not replace `BrushPaintCommand` as brush source data.

## Source of truth policy

Brush source remains lightweight command/source data:

```txt
BrushFrameDrawing
- commands: List<BrushPaintCommand>
- hiddenCommandIds: Set<BrushPaintCommandId>
```

Undo should hide/unhide source commands through the brush frame store or equivalent source boundary.

Derived bitmap surfaces, active previews, edit composites, inactive previews, playback previews, tile images, and caches are not source of truth.

## Tests

Add or update tests for the following:

```txt
1. Active stroke display does not use BitmapSurfacePainter's full per-pixel bitmap surface painting hot path.
2. Active stroke display still receives sampled dab/stamp data during pointer movement.
3. Active stroke display remains pixel-grid / bitmap-like.
4. Starting a second stroke does not change previous committed stroke appearance route.
5. Normal app-level Undo removes the latest brush stroke.
6. Normal app-level Redo restores the latest brush stroke.
7. Existing frame/project/timeline undo behavior does not regress.
8. TileDelta and TileDeltaCommand are not reintroduced into brush runtime/source/undo/cache-invalidation boundaries.
```

Avoid brittle tests that only check documentation prose, exact UI text, or private implementation names.

It is acceptable to add narrow architecture guard tests for forbidden legacy boundaries.

## Manual validation required

After automated tests pass, manual testing must confirm:

```txt
1. Fast long strokes are responsive enough for real drawing.
2. Short connected strokes are responsive.
3. The active stroke looks pixel-grid / bitmap-like.
4. Pointer release does not change the stroke appearance.
5. Starting a second stroke does not change the first stroke appearance.
6. Undo removes the latest brush stroke.
7. Redo restores the brush stroke.
8. Existing frame creation undo still works.
```

## Validation commands

Run:

```bash
dart format lib test
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If Flutter/Dart are unavailable in the environment, state that clearly and do not claim validation passed.

## PR requirements

The PR must be created from `master`.

The PR must not branch from PR #293.

The PR description must mention:

```txt
- supersedes PR #293
- fixes active brush drawing performance
- fixes app-level brush undo/redo
- preserves pixel-grid / bitmap-like brush display
- does not reintroduce TileDelta / TileDeltaCommand
```
