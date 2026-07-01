# Phase 213A Codex Task

## Title

Eradicate TileDelta-based brush commit and undo remnants

## 1. Goal

The current brush architecture documentation now defines `BrushFrameStore`, `BrushPaintCommand`, `UnifiedUndoHistory`, and Deferred Bake Hybrid Brush History as the production-facing brush direction.

However, the current runtime still contains a Brush V1 style path where brush commit, undo, redo, cache invalidation, and edit history are based on `TileDelta` / `TileDeltaCommand`.

This phase must remove that old TileDelta-based brush commit/undo/history system from brush runtime.

The user's goal is explicit:

```txt id="teb0ek"
Root out the remnants of the TileDelta / tile-data command system from the brush system.
```

Important distinction:

```txt id="gsqvhx"
Do remove:
- TileDelta / TileDeltaCommand as brush commit results.
- TileDelta / TileDeltaCommand as undo/redo payload.
- TileDelta / TileDeltaCommand as brush edit history source.
- TileDelta / TileDeltaCommand as cache invalidation input.

Do not remove merely because of the word "tile":
- BitmapSurface
- BitmapTile
- TileCoord
- DirtyRegion
- DirtyTileSet
- sparse tile bitmap storage
```

Sparse tiled bitmap storage is still a valid lightweight storage direction. The thing being removed is the old delta-command history system, not tile-based bitmap storage.

## 2. Required reading

Read these files directly before editing:

```txt id="vmjbcb"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Current_Docs_Index.md
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Project_Architecture.md
```

Also inspect all brush-related runtime and tests before editing:

```txt id="khnw3u"
lib/src/models/brush_*.dart
lib/src/services/brush_*.dart
lib/src/services/bitmap_surface_brush_commit.dart
lib/src/services/bitmap_tile_operation_delta.dart
lib/src/services/brush_commit_result_apply.dart
lib/src/services/brush_commit_result_revert.dart
lib/src/services/canvas_surface_state_brush_commit.dart
lib/src/services/canvas_surface_state_edit.dart
lib/src/ui/brush/*.dart
lib/src/ui/canvas/*brush*.dart
lib/src/ui/canvas/bitmap_surface_painter.dart
test/models/*brush*.dart
test/models/*tile_delta*.dart
test/services/*brush*.dart
test/ui/*brush*.dart
test/architecture/*brush*.dart
```

Use repository search to find every remaining usage of:

```txt id="qvyyiv"
TileDelta
TileDeltaCommand
tileDelta
tile_delta
BrushCommitResult.command
BrushEditHistoryEntry.command
applyBefore
applyAfter
fromTileDeltaCommand
tileDeltaCommandFor
bitmap_tile_operation_delta
```

## 3. Hard rules

```txt id="uekuhh"
- Do not modify handoff sections 0 through 4.
- Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, or app-wide state management.
- Do not implement save/load.
- Do not implement playback cache generation.
- Do not implement real deferred bake rendering.
- Do not implement a full brush UI overhaul.
- Do not remove sparse tile storage.
- Do not make Frame own heavy bitmap data.
- Do not make cache images source of truth.
```

## 4. Target architecture after this phase

After this phase, the brush runtime should have this direction:

```txt id="c8h35b"
Brush input
  -> stroke-like / brush paint payload
  -> BrushPaintCommand
  -> BrushFrameStore
  -> UnifiedUndoHistory entry references BrushPaintCommand
```

Bitmap materialization may still use `BitmapSurface` internally:

```txt id="sgk92o"
BrushPaintCommand / brush payload
  -> internal bitmap materialization
  -> BitmapSurface / BitmapTile mutation
```

But it must not expose or depend on `TileDeltaCommand` as the commit/undo/history unit.

## 5. Required code changes

### 5.1 Replace TileDeltaCommand-based commit result

Current problem:

```txt id="zco38g"
BrushCommitResult.changed({
  required TileDeltaCommand command,
  ...
})
```

Replace this with a brush-domain result that does not expose `TileDeltaCommand`.

Acceptable direction:

```txt id="vsg73x"
BrushCommitResult {
  BrushPaintCommand or BrushPaintCommandId / paint payload ref
  beforeSurface or surface snapshot ref if needed temporarily
  afterSurface or materialized surface if needed temporarily
  CacheInvalidationPlan
}
```

Prefer a structure that makes `BrushPaintCommand` the production-facing command and keeps bitmap mutation internal.

Do not keep a public `command` getter that returns `TileDeltaCommand`.

### 5.2 Replace BrushEditHistoryEntry.command

Current problem:

```txt id="bketgo"
BrushEditHistoryEntry.command -> TileDeltaCommand
```

Remove this getter.

Brush edit history entries must not expose TileDeltaCommand.

If a temporary bitmap session history is still needed, rename and scope it clearly so it does not look like production-facing brush undo. For example:

```txt id="h92vj8"
BrushBitmapEditSnapshot
BrushBitmapMaterializationEdit
BrushSurfaceMaterializationEntry
```

But prefer eliminating the separate TileDelta-based history if possible.

### 5.3 Replace applyBefore/applyAfter undo path

Current problem:

```txt id="dt03le"
undo -> TileDeltaCommand.applyBefore(surface)
redo -> TileDeltaCommand.applyAfter(surface)
```

Replace undo/redo so they operate through brush command state and/or surface snapshots, not tile deltas.

Allowed temporary approach for this phase:

```txt id="cnapgi"
For committed brush edits, keep beforeSurface / afterSurface snapshots inside a brush-domain edit result.
Undo restores beforeSurface.
Redo restores afterSurface.
```

This is acceptable as an intermediate architecture because it removes TileDeltaCommand as the undo source.

Do not optimize this yet with deferred bake or delta compression. That belongs to future phases.

### 5.4 Replace cache invalidation dependency

Current problem:

```txt id="to4yy4"
CacheInvalidationPlan.fromTileDeltaCommand(...)
cacheInvalidationPlanForTileDeltaCommand(...)
```

Replace with dirty-region or dirty-tile based APIs that do not depend on TileDeltaCommand.

Preferred shape:

```txt id="7cxo6e"
CacheInvalidationPlan.fromDirtyTiles({
  required LayerId layerId,
  required FrameId frameId,
  required DirtyTileSet dirtyTiles,
})
```

Then brush commit can compute dirty tiles from brush input, dirty regions, affected bounds, or changed materialization result without producing a TileDeltaCommand.

### 5.5 Replace bitmap operation delta builder

Current problem files include:

```txt id="wwl6er"
lib/src/services/bitmap_tile_operation_delta.dart
lib/src/services/bitmap_surface_brush_commit.dart
```

These currently build TileDeltaCommand from brush operations.

Refactor them so they directly produce:

```txt id="x7wyhn"
- updated BitmapSurface
- DirtyTileSet
- CacheInvalidationPlan input
```

without creating `TileDelta` or `TileDeltaCommand`.

Possible replacement model:

```txt id="2yxzzv"
class BrushBitmapMaterializationResult {
  final BitmapSurface beforeSurface;
  final BitmapSurface afterSurface;
  final DirtyTileSet dirtyTiles;
  bool get hasChanges;
}
```

This model should not contain TileDelta or TileDeltaCommand.

### 5.6 Delete TileDelta files if no longer used

After replacing all production/test references, delete obsolete files if possible:

```txt id="8b67za"
lib/src/models/tile_delta.dart
lib/src/models/tile_delta_command.dart
lib/src/services/bitmap_tile_operation_delta.dart
```

Delete corresponding tests if they only test the old delta system:

```txt id="p2khz7"
test/models/tile_delta_command_test.dart
```

If `tile_delta.dart` or `tile_delta_command.dart` still has references, remove the references rather than preserving the old system.

The desired final state is:

```txt id="5hlezy"
No production brush runtime depends on TileDelta or TileDeltaCommand.
Ideally no lib/ file contains TileDelta or TileDeltaCommand at all.
```

### 5.7 Keep BitmapSurface / BitmapTile

Do not delete or rewrite these merely because they use tiles:

```txt id="oho75h"
BitmapSurface
BitmapTile
TileCoord
DirtyTileSet
DirtyRegion
```

They are sparse bitmap storage primitives, not the old undo system.

## 6. BrushFrameStore / UnifiedUndoHistory alignment

Ensure the production-facing brush flow is centered on:

```txt id="x9jm5s"
BrushFrameEditingCoordinator
BrushFrameStore
BrushFrameDrawingState
BrushPaintCommand
BrushPaintCommandId
BrushPaintCommandState
BrushHistoryPolicy
UnifiedUndoHistory
UndoPayloadRef.paintCommand
```

Required behavior to preserve or strengthen:

```txt id="ywbr1p"
- A brush commit creates a BrushPaintCommand.
- The command is added to BrushFrameStore as live.
- UnifiedUndoHistory stores a paint-command payload ref.
- Undo moves a live command to hiddenByUndo.
- Redo restores hiddenByUndo to live.
- userUndoLimit trimming moves old paint commands to deferredBake.
- No-op brush commits do not create paint commands or undo entries.
```

If bitmap surface materialization still needs local state, it must be clearly internal and subordinate to BrushFrameStore / BrushPaintCommand, not the other way around.

## 7. UI constraints

Update UI only as needed to keep the brush preview functional.

Current brush preview path:

```txt id="e14kec"
HomePage
  -> MainCanvasBrushHost
  -> BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
  -> BrushEditCanvasView / BitmapSurfacePainter
```

Preserve this path if practical.

Do not add a large new UI.

Do not fully integrate HomePage global Undo/Redo in this phase unless it is required to remove TileDelta. If not fully integrated, document and test that brush coordinator undo/redo is the brush undo boundary for now.

## 8. Documentation updates

Update current docs to reflect the stricter policy.

In `docs/Current_Brush_Architecture.md`, change the legacy wording from:

```txt id="es1m8e"
Tile delta may remain as legacy/internal/low-level implementation detail.
```

to the stricter current policy:

```txt id="0t58nm"
TileDelta / TileDeltaCommand must not remain in brush commit, brush undo, brush redo, brush history, or brush cache invalidation.
Sparse tile bitmap storage may remain.
```

Also update `docs/Current_Canvas_Cache_Storage_Architecture.md` so it distinguishes:

```txt id="0fqg3x"
Allowed:
- sparse bitmap tile storage

Forbidden:
- TileDelta / TileDeltaCommand as brush undo/commit/history/cache-invalidation architecture
```

Do not re-expand handoff. If a continuation note is needed, edit only handoff section 5 or later and keep it short.

## 9. Tests

Update or add tests so the new boundary is protected.

Required test coverage:

```txt id="d4rxps"
- Brush commit does not expose TileDeltaCommand.
- Brush edit history entry does not expose TileDeltaCommand.
- Brush undo/redo does not call TileDeltaCommand applyBefore/applyAfter.
- Cache invalidation can be built from DirtyTileSet or equivalent non-TileDelta input.
- BrushFrameEditingCoordinator still records live BrushPaintCommand in BrushFrameStore.
- UnifiedUndoHistory still stores paint command refs.
- userUndoLimit trim still moves old commands to deferredBake.
- No-op brush commits still create no paint command and no undo entry.
- MainCanvasBrushHost / BrushCanvasPanel preview path still builds.
```

Add architecture guard tests:

```txt id="6f6dvm"
- No lib/src/models/brush_*.dart imports tile_delta_command.dart.
- No lib/src/services/brush_*.dart imports tile_delta_command.dart.
- No lib/src/ui/brush/*.dart imports TileDeltaCommand.
- No brush production file contains TileDeltaCommand.
- Current brush docs say TileDeltaCommand is forbidden in brush commit/undo/history.
```

If all TileDelta files are deleted, tests should verify they do not exist.

If any non-brush tile storage files remain, tests must not fail merely because of `BitmapTile`, `TileCoord`, or `DirtyTileSet`.

## 10. Out of scope

Do not implement these in this phase:

```txt id="gjotw8"
- Real bakedBaseSurface rendering
- Real deferred bake execution
- Playback preview cache generation
- Save/load of brush payloads
- Full global HomePage Undo/Redo integration
- Brush preset UI
- Brush engine performance optimization
- GPU rendering
```

This phase is about removing TileDelta-based brush architecture remnants and aligning runtime boundaries.

## 11. Required checks

Run:

```bash id="n27i0s"
dart format lib test
flutter analyze
flutter test
git diff --check
git status
```

If the environment lacks Dart/Flutter, report that clearly.

## 12. Report format

In the PR body or final Codex report, include:

```txt id="6lq7hz"
- TileDelta / TileDeltaCommand production brush references removed
- Whether tile_delta.dart / tile_delta_command.dart were deleted
- New replacement model/API names
- Brush commit result no longer exposes TileDeltaCommand
- Brush undo/redo no longer uses applyBefore/applyAfter on TileDeltaCommand
- Cache invalidation no longer depends on TileDeltaCommand
- BrushFrameStore / UnifiedUndoHistory behavior preserved
- Sparse BitmapSurface / BitmapTile storage preserved
- Runtime UI path status
- Docs updated
- Tests updated
- Check results
```
