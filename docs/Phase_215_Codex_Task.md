# Phase 215 Codex Task: Brush Command Payload / Materialization Boundary Strengthening

## Goal

Continue the brush part only.

This phase strengthens the boundary between durable-ish brush command identity/payload and internal session-local bitmap materialization.

The main goal is to make the current brush command architecture safer before moving toward brush cache/storage preparation, save/load, playback cache, or real deferred bake.

## Required reading before implementation

Read these documents directly before editing code:

* `docs/Handoff_QuickAnimaker_v2_Current.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_UI_Product_Policy.md`

## Current boundary to preserve

`UnifiedUndoHistory` is the production-facing global user undo/redo order.

`UndoPayloadRef.paintCommand` points user undo entries at brush paint-command payloads.

`BrushFrameStore` owns frame-local brush payload movement for live, hidden-by-undo, deferred-bake, and baked paint commands.

`BrushPaintCommand` is the brush command identity / payload boundary.

`BrushPaintCommand.materializationRef` is only a minimal internal bridge to the current session-local bitmap materialization payload while full persistence/deferred bake payload design remains future work.

`BrushBitmapMaterializationHistoryState`, `BrushBitmapMaterializationHistoryEntry`, `BrushCommitResult`, and materialization undo/redo services remain internal session-local bitmap materialization helpers only.

They are not user-facing brush undo source of truth.

They are not durable brush command history.

They are not a replacement for:

```txt id="d4tawa"
UndoPayloadRef.paintCommand
-> BrushFrameStore
-> BrushPaintCommand
```

## Hard restrictions

Do not reintroduce `TileDelta` or `TileDeltaCommand`.

Do not treat internal materialization history as user-facing undo.

Do not make `BrushBitmapMaterializationHistoryState`, `BrushBitmapMaterializationHistoryEntry`, `BrushCommitResult`, or materialization undo/redo services into public undo history.

Do not put heavy bitmap payloads, command buffers, baked surfaces, cache images, or preview images into `Frame`.

Do not make cache images source of truth.

Do not implement save/load.

Do not implement playback cache.

Do not implement real deferred bake.

Do not perform a large UI rewrite.

Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, hidden globals, or broad app-wide state management.

## Implementation tasks

1. Inspect the current brush command payload path.

   Review:

    * `BrushPaintCommand`
    * `BrushFrameStore`
    * `BrushFrameDrawingState`
    * `UndoPayloadRef`
    * `UnifiedUndoHistory`
    * `BrushFrameEditingCoordinator`
    * `BrushBitmapMaterializationHistoryState`
    * `BrushBitmapMaterializationHistoryEntry`
    * `BrushCommitResult`
    * materialization undo/redo services

2. Strengthen command payload boundary naming, comments, or tests where needed.

   Keep changes narrow and modular.

   Prefer tests and small boundary comments over broad renames.

   Do not introduce a final save/load payload schema in this phase.

   Do not implement real deferred bake payload compaction in this phase.

3. Protect `BrushPaintCommand` as the command identity / payload boundary.

   Add or strengthen tests proving that:

    * user-facing undo entries reference brush commands through `UndoPayloadRef.paintCommand`
    * `BrushFrameStore` can resolve the referenced `BrushPaintCommand`
    * `BrushFrameStore` owns movement between live, hidden-by-undo, and deferred-bake command states
    * materialization refs remain minimal bridge data and are not treated as public user undo
    * internal materialization history is not exposed to UI-facing undo routes

4. Protect internal materialization helpers.

   Add or strengthen architecture tests so UI-facing code and production user undo boundaries do not import or directly depend on:

    * `brush_bitmap_materialization_undo_service.dart`
    * `brush_bitmap_materialization_redo_service.dart`
    * direct materialization undo/redo entry stacks
    * `BrushCommitResult` as durable brush command history

5. Keep active-frame display behavior intact.

   Do not break the Phase 214 behavior:

    * commit displays active-frame drawing
    * coordinator undo hides it
    * coordinator redo restores it

6. Documentation.

   Update `docs/Current_Brush_Architecture.md` only if this phase clarifies the command payload/materialization boundary.

   Do not modify sections 0 through 4 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   If the continuation note must be updated, update only section 8 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   Do not add brittle documentation tests based on exact prose length.

## Validation

Run:

```sh id="xzwldk"
dart format lib test
flutter analyze
flutter test
git status
```

## PR notes

The PR description must include:

* Summary
* Architecture boundary notes
* Tests run
* Whether visible UI behavior changed
* Explicit statement that `TileDelta` / `TileDeltaCommand` were not reintroduced
* Explicit statement that internal materialization history was not made user-facing undo
* Explicit statement that save/load, playback cache, real deferred bake, and broad UI rewrite were not implemented
