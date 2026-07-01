# Phase 213C Codex Task

## Title

Brush UI / global undo route safety cleanup

## 1. Goal

Phase 213A removed `TileDelta` / `TileDeltaCommand`.

Phase 213B separated production-facing brush undo from internal bitmap materialization:

```txt id="qfpmgy"
UnifiedUndoHistory = production-facing global user undo/redo order
UndoPayloadRef.paintCommand = user undo reference to brush paint commands
BrushFrameStore = frame-local brush payload owner
BrushPaintCommand = brush command identity / payload boundary
BrushBitmapMaterializationHistoryState = internal session-local bitmap materialization helper
BrushCommitResult = internal BitmapSurface materialization bridge
```

Phase 213C must finish the next safety step:

```txt id="kdmhsf"
Prevent UI, canvas host, smoke screen, or public-facing brush routes from directly using internal bitmap materialization undo/redo as user-facing undo.
```

This phase is a boundary cleanup and safety guard phase. It is not a feature expansion phase.

## 2. Required reading

Read these files directly before editing:

```txt id="y7sym0"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Current_Docs_Index.md
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_UI_Product_Policy.md
docs/Current_Project_Architecture.md
```

Do not edit `docs/Handoff_QuickAnimaker_v2_Current.md` sections 0 through 4.

Inspect all current UI/canvas/brush integration files before editing:

```txt id="vx7byx"
lib/src/services/brush_frame_editing_coordinator.dart
lib/src/services/brush_frame_store.dart
lib/src/services/brush_frame_edit_session_store.dart
lib/src/services/brush_edit_session_cache_operations.dart
lib/src/services/brush_edit_session_state_operations.dart
lib/src/services/brush_bitmap_materialization_undo_service.dart
lib/src/services/brush_bitmap_materialization_redo_service.dart
lib/src/ui/brush/**/*.dart
lib/src/ui/canvas/**/*.dart
lib/src/ui/home/**/*.dart
test/ui/**/*.dart
test/services/brush_frame_editing_coordinator_test.dart
test/architecture/brush_tile_delta_eradication_test.dart
```

Search the repository for:

```txt id="karotj"
BrushBitmapMaterializationHistoryState
BrushBitmapMaterializationHistoryEntry
undoLatestBrushBitmapMaterialization
redoLatestBrushBitmapMaterialization
undoLatestBrushBitmapMaterializationInSessionState
redoLatestBrushBitmapMaterializationInSessionState
materializationHistoryState
BrushCommitResult
applyBrushCommitResultToBitmapSurface
revertBrushCommitResultOnBitmapSurface
BrushFrameEditingCoordinator.undo
BrushFrameEditingCoordinator.redo
UnifiedUndoHistory
UndoPayloadRef.paintCommand
```

## 3. Hard rules

```txt id="i0qqbr"
- Do not reintroduce TileDelta or TileDeltaCommand.
- Do not remove BitmapSurface / BitmapTile / TileCoord / DirtyRegion / DirtyTileSet sparse storage.
- Do not remove BrushBitmapMaterialization* internal bridge classes if they are still needed by session-local bitmap materialization.
- Do not let UI/public-facing routes directly call materialization undo/redo as user undo.
- Do not make cache images source of truth.
- Do not make Frame own heavy brush bitmap payloads.
- Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, or app-wide state management.
- Do not implement save/load.
- Do not implement playback cache generation.
- Do not implement real deferred bake rendering.
- Do not do a large UI rewrite.
```

## 4. Target boundary after this phase

Production bake rendering.

* Do not do a large UI rewrite.

````

## 4. Target boundary-facing UI / canvas routes should use:

```txt id="z6q6tz"
UI / host / shortcut / smoke control
  -> BrushFrameEditingCoordinator.undo()
  -> UnifiedUndoHistory.takeUndo()
  -> BrushFrameStore.markPaintCommandHiddenByUndo()
  -> internal materialization bridge only if needed to update temporary BitmapSurface display
````

Redo should use:

```txt id="eyta5d"
UI / host / shortcut / smoke control
  -> BrushFrameEditingCoordinator.redo()
  -> UnifiedUndoHistory.takeRedo()
  -> BrushFrameStore.restorePaintCommandFromUndo()
  -> internal materialization bridge only if needed to update temporary BitmapSurface display
```

The UI must not do this:

```txt id="ehmbs2"
UI / canvas host / smoke screen
  -> undoLatestBrushBitmapMaterialization...
```

or this:

```txt id="es4cm1"
UI / canvas host / smoke screen
  -> materializationHistoryState.canUndo
  -> materializationHistoryState.undoEntries
```

except in explicitly internal tests or internal session-store setup code.

## 5. Required code changes

### 5.1 Audit UI and canvas public routes

Inspect:

```txt id="sh9u8u"
lib/src/ui/canvas/brush_canvas_smoke_screen.dart
lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/brush/
```

If any UI-facing file imports or calls these directly, remove that dependency or route it through `BrushFrameEditingCoordinator`:

```txt id="emxmzo"
BrushBitmapMaterializationHistoryState
BrushBitmapMaterializationHistoryEntry
undoLatestBrushBitmapMaterialization*
redoLatestBrushBitmapMaterialization*
materializationHistoryState.undoEntries
materializationHistoryState.redoEntries
```

UI may read high-level coordinator state or session state only when necessary for display, but user-facing undo/redo must be routed through `BrushFrameEditingCoordinator`.

### 5.2 Add coordinator-level UI-safe methods if needed

If current UI needs a simple public API, add small methods to `BrushFrameEditingCoordinator`, for example:

```dart id="8dik0p"
bool get canUndo => undoHistory.canUndo;
bool get canRedo => undoHistory.canRedo;
```

or:

```dart id="niryui"
BrushUndoRouteStatus get undoRouteStatus;
```

Keep it minimal.

Do not introduce state management frameworks.

Do not build a full app-wide undo controller in this phase.

### 5.3 Keep materialization bridge internal

The materialization services may remain:

```txt id="j01xiw"
brush_bitmap_materialization_undo_service.dart
brush_bitmap_materialization_redo_service.dart
brush_bitmap_materialization_history_stack.dart
```

But they must be treated as internal implementation details used below the coordinator boundary.

Add comments if needed:

```txt id="3lkv2r"
This service is internal to session-local BitmapSurface materialization. UI-facing undo/redo should call BrushFrameEditingCoordinator.undo/redo instead.
```

### 5.4 Strengthen architecture guard tests

Add or update architecture tests so they fail if UI/public-facing brush files directly depend on internal materialization undo.

Required guard:

```txt id="m1an2t"
- lib/src/ui/**/*.dart must not import brush_bitmap_materialization_undo_service.dart
- lib/src/ui/**/*.dart must not import brush_bitmap_materialization_redo_service.dart
- lib/src/ui/**/*.dart must not import brush_bitmap_materialization_history_state.dart
- lib/src/ui/**/*.dart must not call undoLatestBrushBitmapMaterialization*
- lib/src/ui/**/*.dart must not call redoLatestBrushBitmapMaterialization*
```

Allowed:

```txt id="polad2"
- tests may import internal materialization classes when testing the internal bridge
- services may import internal materialization classes
- UI may use BrushFrameEditingCoordinator
- UI may use BrushFrameEditSessionStore only if it is not acting as user-facing undo
```

### 5.5 Update tests

Update tests so UI behavior uses the coordinator boundary.

Required test coverage:

```txt id="l3q9ok"
- UI/smoke host brush undo path calls or depends on BrushFrameEditingCoordinator.undo/redo, not materialization undo/redo directly.
- A brush commit still creates BrushPaintCommand in BrushFrameStore.
- UndoPayloadRef.paintCommand still points to a command retrievable from BrushFrameStore.
- Undo through coordinator hides a paint command in BrushFrameStore.
- Redo through coordinator restores a paint command in BrushFrameStore.
- Internal materialization undo/redo tests remain, but are clearly named as internal/session-local tests.
- No UI-facing file directly imports internal materialization history state or undo/redo services.
```

### 5.6 Documentation update

Update `docs/Current_Brush_Architecture.md` with a concise Phase 213C note:

```txt id="1vpe1q"
Phase 213C keeps UI/public-facing brush undo routed through BrushFrameEditingCoordinator and UnifiedUndoHistory. UI/canvas routes must not directly call internal BrushBitmapMaterialization undo/redo services as user-facing undo. Materialization undo/redo remains an internal temporary BitmapSurface display bridge below the coordinator boundary.
```

Do not over-expand the handoff.

If updating `docs/Handoff_QuickAnimaker_v2_Current.md`, edit only section 5 or later and keep it short.

## 6. Out of scope

Do not implement:

```txt id="eg1gpo"
- Full HomePage toolbar undo/redo UI
- Keyboard shortcuts
- Menu actions
- App-wide command bus
- Save/load
- Playback cache
- Real deferred bake rendering
- Real bakedBaseSurface compaction
- Timeline undo
- Layer undo
- Provider/Riverpod/Bloc/ChangeNotifier
```

This phase only protects the route boundary.

## 7. Required checks

Run:

```bash id="bqz5pk"
dart format lib test
flutter analyze
flutter test
git diff --check
git status
```

If Dart/Flutter is unavailable, report that clearly.

## 8. Report format

In the PR body or final Codex report, include:

```txt id="x8ipqg"
- Whether any UI-facing file previously used internal materialization undo/redo directly
- What UI/canvas routes were changed
- Whether BrushFrameEditingCoordinator gained any UI-safe canUndo/canRedo or route helpers
- How UI-facing undo/redo is now routed
- Which internal materialization services remain and why
- Architecture guard tests added/updated
- Confirmation that TileDelta / TileDeltaCommand were not reintroduced
- Confirmation that sparse bitmap storage remains
- Check results
```
