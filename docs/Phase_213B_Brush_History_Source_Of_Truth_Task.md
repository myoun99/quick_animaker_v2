# Phase 213B Codex Task

## Title

Brush history source-of-truth boundary cleanup

## 1. Goal

Phase 213A removed `TileDelta` / `TileDeltaCommand` from brush commit, undo, redo, edit history, and cache invalidation boundaries.

This phase must finish the next layer of brush cleanup:

```txt
Remove the remaining old brush-history/source-of-truth assumptions that could replace TileDeltaCommand with another temporary user-facing history system.
```

The goal is not to add new brush features. The goal is to make the runtime boundaries match the current brush architecture direction:

```txt
UnifiedUndoHistory = user-facing global undo/redo order
BrushFrameStore = frame-local brush drawing payload owner
BrushPaintCommand = brush command identity / payload boundary
BitmapSurface / BitmapTile = internal sparse bitmap materialization storage
BrushCommitResult snapshot bridge = temporary/internal materialization result, not long-term source of truth
```

Important distinction:

```txt
Do remove or demote:
- BrushEditHistoryState if it still acts like a user-facing brush undo history.
- BrushEditHistoryEntry if it still looks like the authoritative brush history truth
```

Important distinction:

```txt
Do remove or demote:
- BrushEditHistoryState if it still acts like unit.
- BrushCommitResult if it looks like the long-term brush command source of truth.
- beforeSurface / afterSurface snapshot apply/revert if it is exposed as production user-facing undo policy.
- tests or names that imply the old session-local history is the real user-facing undo model.

Do not remove merely because of the word "tile":
- BitmapSurface
- BitmapTile
- TileCoord
- DirtyRegion
- DirtyTileSet
- sparse bitmap storage
```

Sparse tile bitmap storage remains valid. The cleanup target is the old brush edit-history model and any replacement of `TileDeltaCommand` with another duplicate user-facing history path.

## 2. Required reading

Read these files directly before editing:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Current_Docs_Index.md
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Project_Architecture.md
```

Also inspect all current brush runtime files before editing:

```txt
lib/src/models/brush_*.dart
lib/src/models/unified_undo_history.dart
lib/src/models/undo_history_entry.dart
lib/src/models/undo_payload_ref.dart
lib/src/services/brush_*.dart
lib/src/services/bitmap_surface_brush_commit.dart
lib/src/services/bitmap_tile_operation_materialization.dart
lib/src/ui/brush/*.dart
lib/src/ui/canvas/*brush*.dart
lib/src/ui/canvas/bitmap_surface_painter.dart
test/architecture/*brush*.dart
test/models/*brush*.dart
test/services/*brush*.dart
test/ui/*brush*.dart
```

Use repository search to inspect every remaining usage of:

```txt
BrushEditHistoryState
BrushEditHistoryEntry
BrushEditUndoResult
BrushEditRedoResult
BrushEditHistoryStack
undoLatestBrushEdit
redoLatestBrushEdit
BrushCommitResult
beforeSurface
afterSurface
applyBrushCommitResultToBitmapSurface
revertBrushCommitResultOnBitmapSurface
BrushPaintCommand
BrushFrameStore
UnifiedUndoHistory
UndoPayloadRef.paintCommand
```

Also confirm that these do not exist in production brush runtime:

```txt
TileDelta
TileDeltaCommand
tile_delta
applyBefore
applyAfter
fromTileDeltaCommand
```

## 3. Hard rules

```txt
- Do not modify handoff sections 0 through 4.
- Do not reintroduce TileDelta or TileDeltaCommand.
- Do not remove sparse bitmap storage.
- Do not make Frame own heavy brush bitmap payloads.
- Do not make cache images source of truth.
- Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, or app-wide state management.
- Do not implement save/load.
- Do not implement playback cache generation.
- Do not implement real deferred bake rendering.
- Do not implement GPU rendering.
- Do not do a large brush UI rewrite.
```

If you update `docs/Handoff_QuickAnimaker_v2_Current.md`, edit only section 5 or later and keep it concise.

Documentation tests must not depend on exact long-term memo wording. They may protect stable rules such as file existence, current-doc links, lightweight handoff shape, and forbidden runtime architecture reintroduction.

## 4. Target architecture after this phase

After this phase, the brush runtime should communicate these boundaries clearly:

```txt
Brush input
  -> BrushPaintCommand / brush command payload reference
  -> BrushFrameStore live command state
  -> UnifiedUndoHistory paint-command entry
```

Bitmap materialization may still exist internally:

```txt
BrushPaintCommand / dab sequence / stroke-like payload
  -> internal bitmap materialization
  -> BitmapSurface / BitmapTile update
  -> DirtyTileSet
  -> CacheInvalidationPlan
```

But user-facing undo must not be represented as:

```txt
BrushEditHistoryState as the real brush undo source
BrushEditHistoryEntry as the real brush command source
BrushCommitResult snapshots as the long-term user-facing undo model
BitmapSurface before/after snapshots as the final brush history architecture
```

Snapshot-based `BrushCommitResult` may remain only as a short-term bitmap materialization bridge if fully internal and clearly named/documented/tested as such.

## 5. Required code changes

### 5.1 Audit BrushEditHistoryState and related classes

Inspect:

```txt
lib/src/models/brush_edit_history_state.dart
lib/src/models/brush_edit_history_entry.dart
lib/src/models/brush_edit_undo_result.dart
lib/src/models/brush_edit_redo_result.dart
lib/src/services/brush_edit_history_stack.dart
lib/src/services/brush_edit_undo_service.dart
lib/src/services/brush_edit_redo_service.dart
lib/src/services/brush_edit_history_entry_builder.dart
```

Decide whether each class is still needed.

Preferred outcome:

```txt
- User-facing brush undo/redo must be owned by UnifiedUndoHistory.
- BrushFrameStore must own frame-local command visibility movement.
- Any remaining session-local edit history must be renamed or documented as internal bitmap materialization history only.
```

If `BrushEditHistoryState` is no longer required for production brush runtime, remove it and update all references.

If it is still required temporarily, rename or document it so it cannot be mistaken for user-facing brush history. Acceptable names include:

```txt
BrushBitmapMaterializationHistoryState
BrushSurfaceMaterializationHistoryState
BrushEditSessionMaterializationState
```

Do not leave a production-facing class named `BrushEditHistoryState` if it still behaves like an independent undo stack.

### 5.2 Make UnifiedUndoHistory the user-facing brush undo boundary

Ensure the production-facing brush undo path is centered on:

```txt
UnifiedUndoHistory
UndoHistoryEntry
UndoPayloadRef.paintCommand
BrushFrameStore
BrushPaintCommand
```

Required behavior:

```txt
- A brush commit creates or references a BrushPaintCommand.
- A BrushPaintCommand is added to BrushFrameStore as live.
- UnifiedUndoHistory stores a paint-command undo payload reference.
- Undo through the production brush coordinator hides or moves the live command through BrushFrameStore.
- Redo restores a hidden command through BrushFrameStore.
- userUndoLimit trimming moves old command refs toward deferredBake state.
```

If existing code still uses `BrushEditHistoryState` to perform production user-facing undo, change that boundary.

### 5.3 Clarify BrushCommitResult as internal materialization

`BrushCommitResult` currently carries `beforeSurface`, `afterSurface`, `DirtyTileSet`, and `CacheInvalidationPlan`.

That is acceptable only as an internal materialization bridge.

Make this explicit in code and tests.

Preferred direction:

```txt
BrushCommitResult / equivalent:
- internal bitmap materialization result
- not a user-facing undo entry
- not the final brush command source of truth
- may be used to update BitmapSurface and derive DirtyTileSet
```

If needed, rename to a clearer internal name, for example:

```txt
BrushBitmapMaterializationResult
BrushSurfaceMaterializationResult
BrushBitmapCommitMaterialization
```

Only rename if it can be done safely and without broad churn. A clear doc comment and tests are acceptable if renaming would be too risky for this phase.

### 5.4 Strengthen BrushPaintCommand boundary

Inspect `BrushPaintCommand`.

If it is still only a metadata shell, add the minimum safe payload/ref boundary needed for current runtime.

Acceptable minimal shape:

```txt
BrushPaintCommand {
  id
  frameKey or command target ref
  kind
  state
  materializationRef or sourcePayloadRef
  debugLabel/debugSource
}
```

Do not implement full save/load payload serialization in this phase.

Do not implement a full brush engine rewrite.

The point is to prevent the actual brush source from being hidden only inside `BrushCommitResult` / bitmap snapshots.

### 5.5 Keep sparse bitmap storage internal

Keep these as allowed low-level storage/materialization concepts:

```txt
BitmapSurface
BitmapTile
TileCoord
DirtyRegion
DirtyTileSet
CacheInvalidationPlan.fromDirtyTiles
```

Architecture guard tests must allow these terms.

They must not allow `TileDelta` / `TileDeltaCommand` production brush runtime reintroduction.

### 5.6 Update UI only if needed

Current brush preview/UI path may remain:

```txt
HomePage
  -> MainCanvasBrushHost
  -> BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
  -> BrushEditCanvasView / BitmapSurfacePainter
```

Do not do a large UI change.

Do not fully integrate HomePage global Undo/Redo in this phase unless it is required to prevent a duplicate brush history path.

If full UI global undo integration is not done, document that it belongs to the next phase.

## 6. Documentation updates

Update `docs/Current_Brush_Architecture.md` if needed to distinguish:

```txt
Production-facing:
- UnifiedUndoHistory
- BrushFrameStore
- BrushPaintCommand

Internal / temporary materialization bridge:
- BitmapSurface snapshots
- BrushCommitResult or renamed equivalent
- DirtyTileSet
- CacheInvalidationPlan
```

Do not re-expand handoff.

If updating `docs/Handoff_QuickAnimaker_v2_Current.md`, edit only section 5 or later and keep it short.

Add or preserve a concise note equivalent to:

```txt
Documentation and handoff tests should protect stable project rules, not exact long-term memo wording. Prefer tests for file existence, Current-doc links, lightweight handoff shape, and forbidden runtime architecture reintroduction.
```

## 7. Tests

Update or add tests so the new boundary is protected.

Required test coverage:

```txt
- Production brush undo does not depend on BrushEditHistoryState as the user-facing source of truth.
- UnifiedUndoHistory remains the user-facing paint-command undo order.
- BrushFrameStore owns frame-local live / hiddenByUndo / deferredBake command movement.
- BrushPaintCommand is the brush command boundary used by production brush coordinator.
- BrushCommitResult or its renamed equivalent is internal materialization only.
- No production brush runtime file contains TileDeltaCommand.
- No production brush runtime file imports deleted tile_delta files.
- Sparse bitmap storage remains allowed.
```

If `BrushEditHistoryState` remains temporarily, add tests that make the limitation explicit:

```txt
- BrushEditHistoryState is not used by production user-facing undo coordinator.
- BrushEditHistoryState is internal/session-local/materialization-only.
- UnifiedUndoHistory is still the only user-facing global undo order.
```

If `BrushEditHistoryState` is removed, add tests proving production brush flows still build and that the removed files do not exist.

Avoid exact wording tests for handoff/current docs. Test stable concepts only.

## 8. Architecture guard tests

Update or add architecture guard tests for:

```txt
- No `TileDeltaCommand` in production brush runtime.
- No `TileDelta` in production brush runtime.
- No `BrushEditHistoryState` as production-facing undo source.
- No class or service named like `BrushEditHistoryStack` remains if it is not internal.
- `UnifiedUndoHistory` appears in production brush coordinator path.
- `BrushFrameStore` appears in production brush coordinator path.
- Documentation tests do not require exact long-term memo sentences.
```

The guard must not fail on allowed terms:

```txt
BitmapSurface
BitmapTile
TileCoord
DirtyRegion
DirtyTileSet
CacheInvalidationPlan
```

## 9. Out of scope

Do not implement these in this phase:

```txt
- Real bakedBaseSurface rendering
- Actual deferred bake compaction
- Playback preview cache generation
- Save/load for brush payloads
- Full HomePage global undo integration
- Brush preset UI
- GPU rendering
- Performance optimization beyond necessary cleanup
```

## 10. Required checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git diff --check
git status
```

If Dart/Flutter is unavailable, report that clearly.

## 11. Report format

In the PR body or final Codex report, include:

```txt
- Whether BrushEditHistoryState remains, was renamed, or was removed
- Whether BrushEditHistoryEntry remains, was renamed, or was removed
- How user-facing brush undo is now routed
- How UnifiedUndoHistory is protected as the production-facing undo order
- How BrushFrameStore is protected as the frame-local payload owner
- How BrushPaintCommand is used as the brush command boundary
- How BrushCommitResult or its replacement is scoped as internal materialization
- Confirmation that TileDelta / TileDeltaCommand were not reintroduced
- Confirmation that sparse bitmap storage remains
- Docs updated
- Tests updated
- Check results
```
