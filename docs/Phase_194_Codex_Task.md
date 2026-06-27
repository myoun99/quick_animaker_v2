# Phase 194 Codex Task

## Title

Brush workspace app integration bundle

## Current goal

Brush work is moving from internal smoke/dev/test stack into real app-level integration.

The final Brush completion target is:

```txt
App runs
→ user can enter a real brush workspace
→ drawing is associated with Project / Track / Cut / Layer / Frame
→ switching frames preserves independent drawing state
→ undo / redo follows the unified user-facing order
→ active frame editing stays fast
→ inactive frames can later use preview caches
```

Phase 194 should implement the first real app workspace integration.

This phase should be larger than a tiny model-only PR.

## Important context

Already implemented:

```txt
BrushFrameKey
BrushHistoryPolicy
UnifiedUndoHistory
UndoHistoryEntry / UndoPayloadRef
BrushPaintCommand
BrushFrameDrawingState
BrushFrameStore
InteractiveBrushEditCanvasView
BrushEditSessionState
cache-aware brush commit / undo / redo facades
BrushCanvasSmokeScreen dev/manual harness
```

Phase 194 should connect the existing interactive brush canvas path to the new app-integration foundation.

## Core principle

Do not treat `BrushCanvasSmokeScreen` as the final app workspace.

Create a real app brush workspace path.

It may still be simple and dev-oriented, but it should be part of the app flow rather than only an isolated smoke screen.

## Required high-level behavior

Implement a brush workspace that can:

```txt
1. Open from the running app.
2. Use real ProjectId / TrackId / CutId / LayerId / FrameId values.
3. Build a BrushFrameKey from the active Project / Track / Cut / Layer / Frame.
4. Display an interactive brush canvas for the active frame.
5. Switch between at least three frames.
6. Preserve independent drawing/session state per frame.
7. Record paint commits into BrushFrameStore.
8. Record paint commits into UnifiedUndoHistory.
9. Keep Frame model lightweight.
10. Avoid storing heavy brush drawing payload directly inside Frame.
```

## Scope: allowed production changes

This phase may modify production app UI enough to expose the new brush workspace.

Allowed:

```txt
- add BrushWorkspaceScreen
- add BrushWorkspaceCoordinator or equivalent
- add BrushFrameEditSessionStore or equivalent
- add a simple app entry button/tab/menu to open BrushWorkspaceScreen
- add focused tests
- update existing tests if the new app entry changes expected widget tree
```

Do not weaken protected tests.

## Scope: still not allowed

Do not implement:

```txt
- save/load
- renderer cache
- playback cache
- actual deferred bitmap baking
- full production toolbar
- layer panel rewrite
- timeline rewrite
- storyboard drawing
- onion skin
- eraser
- pressure
- smoothing
- selection
- app-wide state management package
```

Do not add:

```txt
Provider
Riverpod
Bloc
ChangeNotifier
global singleton app state
```

Use local StatefulWidget / pure coordinator objects for now.

## Existing protected semantics

Do not break:

```txt
StoryboardPanel semantics
TimelinePanel semantics
Layer ordering semantics
Cut.duration semantics
Brush smoke/dev canvas tests
```

Protected Storyboard keys remain protected:

```txt
storyboard-panel
storyboard-track-row-<trackId>
storyboard-track-timeline-area-<trackId>
storyboard-cut-block-<cutId>
storyboard-cut-positioned-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
storyboard-timeline-horizontal-viewport
```

## Required implementation pieces

### 1. BrushFrameEditSessionStore

Create a store that maps `BrushFrameKey` to the current `BrushEditSessionState`.

Suggested file:

```txt
lib/src/services/brush_frame_edit_session_store.dart
```

Required behavior:

```txt
- get or create BrushEditSessionState for BrushFrameKey
- update session state for BrushFrameKey after brush commit / undo / redo / reset
- keep frame sessions independent
- no heavy payload inside Frame model
```

This store is separate from `BrushFrameStore`.

Conceptually:

```txt
BrushFrameStore:
  paint command metadata/state for app-integration history

BrushFrameEditSessionStore:
  actual current BrushEditSessionState used by the interactive canvas
```

Do not merge these prematurely unless there is a strong reason.

### 2. BrushWorkspaceCoordinator

Create a pure coordinator or controller object.

Suggested file:

```txt
lib/src/services/brush_workspace_coordinator.dart
```

It should coordinate:

```txt
BrushFrameKey active key
BrushFrameStore
BrushFrameEditSessionStore
UnifiedUndoHistory
BrushHistoryPolicy
```

Required behavior:

```txt
- expose activeFrameKey
- expose activeSessionState
- selectFrame(BrushFrameKey key)
- applyBrushOperationResult(...)
- record a BrushPaintCommand for brush commit
- push a matching UndoHistoryEntry into UnifiedUndoHistory
- handle trimmed paint entries by moving them to deferredBake in BrushFrameStore
- do not bake preview cache during active editing undo/redo
```

If existing brush operation result types are named differently, adapt to current code.

The coordinator should not decide rendering details.

The coordinator should not use Provider/Riverpod/Bloc/ChangeNotifier.

### 3. Undo/redo coordination

Implement app-level undo/redo enough for paint commands.

Expected behavior:

```txt
Undo:
  - UnifiedUndoHistory.takeUndo decides the latest global entry.
  - If the entry is a paint command, use its BrushFrameKey / BrushPaintCommandId.
  - Update BrushFrameStore command state to hiddenByUndo.
  - Apply the existing brush session undo operation to that frame's BrushEditSessionState when possible.
  - Do not bake preview cache.

Redo:
  - UnifiedUndoHistory.takeRedo decides the latest redo entry.
  - If the entry is a paint command, restore command state to live.
  - Apply the existing brush session redo operation to that frame's BrushEditSessionState when possible.
  - Do not bake preview cache.
```

Important:

```txt
UnifiedUndoHistory owns order.
BrushFrameStore does not choose what to undo.
```

If cross-frame undo execution is too large for this phase, implement paint undo/redo for the active frame and document the remaining cross-frame undo limitation clearly in docs and tests. However, prefer cross-frame paint undo if it can be done safely.

### 4. BrushWorkspaceScreen

Create a real app workspace screen.

Suggested file:

```txt
lib/src/ui/brush/brush_workspace_screen.dart
```

It should include:

```txt
- stable root key: brush-workspace-screen
- frame selector buttons for at least Frame 1 / Frame 2 / Frame 3
- active frame label
- interactive brush canvas for active frame
- undo button
- redo button
- reset or clear button if existing reset path is easy
- color preset controls if existing brush input settings support it
- debug/status text for active frame, command counts, undo count, redo count
```

Use lower-level brush UI components such as `InteractiveBrushEditCanvasView`.

Do not use `BrushCanvasSmokeScreen` as the workspace implementation.

Reusing small helper concepts from smoke screen is allowed, but the new screen should be its own app workspace.

### 5. App entry

Add a simple way to open `BrushWorkspaceScreen` from the running app.

Use the existing app structure.

If the app already has a home/navigation shell, add a conservative entry such as:

```txt
Brush Workspace
```

If there is no route system, add the smallest clear app-level button or tab that opens the screen.

Rules:

```txt
- Do not remove StoryboardPanel.
- Do not remove TimelinePanel.
- Do not change their existing semantics.
- Do not make BrushCanvasSmokeScreen the app entry.
```

### 6. In-memory project/frame fixture

If the app does not yet have a global active project state, create a local in-memory brush workspace fixture using real model IDs.

This fixture should include:

```txt
ProjectId
TrackId
CutId
LayerId
FrameId frame-1
FrameId frame-2
FrameId frame-3
```

It should not persist to disk.

It should not add heavy drawing payload to Frame.

This is acceptable as a first app integration step.

## Required tests

Add tests for the new app integration.

Suggested files:

```txt
test/services/brush_frame_edit_session_store_test.dart
test/services/brush_workspace_coordinator_test.dart
test/ui/brush_workspace_screen_test.dart
```

Update existing app smoke tests if an app entry is added.

### Required test cases

#### Session store frame isolation

```txt
- create frame key A and frame key B
- update session for A
- B remains independent
- switching back to A returns A session
```

#### Coordinator records brush commit

```txt
- active frame key is A
- apply a fake/small brush operation result or equivalent
- BrushFrameStore receives a live paint command
- UnifiedUndoHistory receives a paint undo entry
- active session state updates
```

If creating a real brush operation result is difficult, test via a focused coordinator method that accepts the minimal data needed.

#### userUndoLimit trim moves paint to deferredBake

```txt
- use small userUndoLimit such as 2
- commit 3 paint commands
- oldest paint command leaves UnifiedUndoHistory undoStack
- BrushFrameStore marks oldest command as deferredBake
- deferred command remains visible
```

#### Frame switching preserves independent drawing state

```txt
- open BrushWorkspaceScreen
- draw/tap on frame 1
- switch to frame 2
- frame 2 starts empty
- draw/tap on frame 2
- switch back to frame 1
- frame 1 still has its previous state
```

Use existing canvas-relative test helpers if practical.

#### Undo/redo does not bake during active editing

```txt
- commit paint command
- undo
- command becomes hiddenByUndo
- no deferred/baked state is created by undo
- redo restores live command
```

#### App entry exists

```txt
- app starts
- a Brush Workspace entry is visible or reachable
- opening it shows key brush-workspace-screen
```

#### Protected panels still work

Existing StoryboardPanel and TimelinePanel tests must remain passing.

Do not weaken them.

## Documentation update

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt
## Phase 194 app workspace integration

Implemented:
- BrushWorkspaceScreen app entry.
- BrushFrameEditSessionStore.
- BrushWorkspaceCoordinator.
- frame switching with independent BrushEditSessionState per BrushFrameKey.
- paint commits recorded in BrushFrameStore and UnifiedUndoHistory.

Still out of scope:
- save/load
- renderer/playback cache
- actual deferred bitmap baking
- production toolbar
- full timeline/layer panel integration
```

Do not overstate final Brush completion yet.

## Existing tests and structure changes

It is acceptable to update older tests or lightly adjust existing structures if this phase requires it.

However:

```txt
- explain why the change was needed in the PR summary
- do not weaken protected Storyboard/Timeline behavior
- do not delete the existing smoke/dev brush tests
- keep BrushCanvasSmokeScreen tests passing unless the new app workspace deliberately replaces only test helpers, not the smoke screen itself
```

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
- app entry summary
- BrushWorkspaceScreen summary
- BrushWorkspaceCoordinator summary
- BrushFrameEditSessionStore summary
- frame switching behavior
- undo/redo behavior
- whether existing tests were updated
- checks run and results
- git status summary
```
