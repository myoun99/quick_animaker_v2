# Phase 193 Codex Task

## Title

UnifiedUndoHistory and BrushFrameStore foundation bundle

## Current goal

Brush work is moving toward app-complete integration.

The final target is not just a smoke/dev brush screen. The final target is real app-level integration:

```txt
Project / Track / Cut / Layer / Frame
→ BrushFrameKey
→ BrushFrameStore
→ UnifiedUndoHistory
→ active frame drawing
→ frame switching
→ deferred bake / preview cache policy
```

Phase 193 should implement the core domain foundation for this path.

This phase should be larger than a documentation-only phase.

It should introduce real model/service foundations and tests.

## Previous decisions

The following decisions are already established and must be respected:

```txt
1. Frame remains lightweight.
2. Heavy drawing payload is stored outside Frame.
3. BrushFrameKey identifies drawing payload using ProjectId / TrackId / CutId / LayerId / FrameId.
4. Active frame display uses method A:
   bakedBaseSurface + deferredBakePaintCommands + livePaintCommands + active stroke overlay.
5. Undo/redo during active editing must not bake preview cache.
6. Deferred Bake Hybrid Brush History is the long-term policy.
7. userUndoLimit and deferredBakeBuffer are separate.
8. deferredBakeBuffer is not user-undoable.
9. UnifiedUndoHistory owns the only global user-facing undo order.
10. BrushFrameStore owns paint payload/state but must not determine global undo order.
11. Project/timeline/layer structural commands are not bitmap-baked.
12. Destructive structure changes require flush barriers.
13. Playback must not replay live paint commands.
```

## Phase 193 goal

Implement the domain foundation for:

```txt
UnifiedUndoHistory
BrushFrameStore
BrushFrameDrawingState
Paint command state transitions
Undo payload references
Deferred bake buffer state movement
```

This phase should not wire UI.

This phase should not implement actual bitmap baking yet.

This phase should not implement playback cache yet.

But it should create enough structure that the next phase can connect a brush workspace to real frame/layer state.

## Important scope note

It is allowed to update older tests or adjust earlier brush-history structures if they conflict with the new architecture.

However:

```txt
- Do not break protected StoryboardPanel semantics.
- Do not break protected TimelinePanel semantics.
- Do not wire BrushCanvasSmokeScreen into main.dart.
- Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, or app-wide singleton state.
```

If existing `BrushEditHistoryState`, `BrushEditHistoryEntry`, or session facade classes overlap with the new `UnifiedUndoHistory` or `BrushFrameStore`, do not delete them blindly.

Instead:

```txt
1. Keep the existing smoke/dev brush stack working.
2. Add the new app-integration foundation beside it.
3. Add comments/tests that clarify the transition boundary if needed.
4. Only refactor existing code when tests prove it is necessary.
```

## Required model concepts

### 1. UnifiedUndoHistory

Create a pure model that owns the global user-facing undo/redo order.

Suggested files:

```txt
lib/src/models/unified_undo_history.dart
lib/src/models/undo_history_entry.dart
lib/src/models/undo_history_entry_id.dart
lib/src/models/undo_history_entry_kind.dart
lib/src/models/undo_payload_ref.dart
```

Exact file splitting may differ if the project style prefers fewer files.

Required behavior:

```txt
- undoStack stores entries in user action order.
- redoStack stores entries available for redo.
- pushNewEntry adds a new undo entry and clears redoStack.
- takeUndo returns/removes the latest undo entry and moves it to redoStack.
- takeRedo returns/removes the latest redo entry and moves it back to undoStack.
- userUndoLimit is enforced by oldest-entry trimming.
- trimming returns the removed entries to the caller.
- UnifiedUndoHistory does not know how to execute payloads.
- UnifiedUndoHistory only owns order and refs.
```

Important:

```txt
BrushFrameStore must not determine global undo order.
Project/timeline/layer stores must not determine global undo order.
```

### 2. UndoHistoryEntry

An undo entry should identify:

```txt
- entry id
- sequence number
- kind
- scope
- payload ref
```

Suggested concepts:

```txt
UndoHistoryEntryKind:
  paintStroke
  eraseStroke
  clearFrameDrawing
  fillFrameDrawing
  createFrame
  deleteFrame
  moveFrame
  createLayer
  deleteLayer
  renameLayer
  reorderLayer
  changeCutDuration
  createCut
  deleteCut

UndoHistoryScope:
  brushFrame
  project
  timeline
  layer
  cut
```

The exact enum names may be adjusted to match project style.

### 3. UndoPayloadRef

A unified entry may reference payloads stored elsewhere.

Examples:

```txt
PaintCommandRef(frameKey, paintCommandId)
ProjectCommandRef(projectCommandId)
TimelineCommandRef(timelineCommandId)
LayerCommandRef(layerCommandId)
```

The implementation may use a general `UndoPayloadRef` with:

```txt
storeName
payloadId
targetKey or targetPath
```

or typed subclasses/value objects if that fits the codebase better.

### 4. Brush paint command identity and state

Create lightweight paint command identity/state models.

Suggested files:

```txt
lib/src/models/brush_paint_command_id.dart
lib/src/models/brush_paint_command_state.dart
lib/src/models/brush_paint_command.dart
```

A paint command should be frame-local and lightweight for now.

It may include:

```txt
- id
- sequenceNumber
- kind
- optional label/debug description
- optional affected bounds placeholder
- optional metadata ref
```

Do not implement a full brush raster command payload yet unless it already exists and can be reused safely.

Paint command states:

```txt
live
hiddenByUndo
deferredBake
baked
```

Meaning:

```txt
live:
  visible and user-undoable if its entry remains in UnifiedUndoHistory.

hiddenByUndo:
  hidden from active display but redoable if its entry remains in UnifiedUndoHistory.redoStack.

deferredBake:
  visible, not user-undoable, waiting for delayed baking.

baked:
  already compacted into bakedBaseSurface.
```

### 5. BrushFrameDrawingState

Create a pure state object for one brush frame.

Suggested file:

```txt
lib/src/models/brush_frame_drawing_state.dart
```

It should conceptually hold:

```txt
BrushFrameKey key
livePaintCommands
hiddenByUndoPaintCommands
deferredBakePaintCommands
bakedPaintCommandIds or baked marker
inactivePreviewDirty flag
```

Do not store heavy preview cache or actual baked bitmap implementation yet unless existing classes can be reused safely.

The state should expose safe query helpers such as:

```txt
visibleActivePaintCommands
allPaintCommandsInDisplayOrder
hasDeferredBakeCommands
deferredBakeCount
```

Display order should be deterministic:

```txt
deferredBakePaintCommands by sequenceNumber
then livePaintCommands by sequenceNumber
excluding hiddenByUndo
```

### 6. BrushFrameStore

Create a service/store foundation.

Suggested file:

```txt
lib/src/services/brush_frame_store.dart
```

Required behavior:

```txt
- get or create BrushFrameDrawingState for BrushFrameKey.
- add live paint command to a frame.
- mark a paint command hidden by undo.
- restore a hidden paint command by redo.
- move a paint command from live to deferredBake when UnifiedUndoHistory trims its paint entry.
- mark deferred commands as baked or extract them for a future flush.
- flushFrame should expose/deal with deferred commands without doing real bitmap baking yet.
- flushLayer should identify affected frame states by LayerId and prepare them for future destructive operations.
```

Important:

```txt
BrushFrameStore stores paint payload/state.
BrushFrameStore does not decide undo/redo order.
BrushFrameStore only responds to explicit calls from a future coordinator.
```

### 7. Deferred bake buffer policy integration

Use the existing `BrushHistoryPolicy` from Phase 192.

Implement or test behavior equivalent to:

```txt
userUndoLimit = 250
deferredBakeRatio = 0.10
deferredBakeLimit = 25
```

When `UnifiedUndoHistory` trims old entries due to `userUndoLimit`, the caller should be able to inspect trimmed entries.

If a trimmed entry is a paint command ref:

```txt
BrushFrameStore moves that paint command from live to deferredBake.
```

If a trimmed entry is structural/project/timeline/layer command:

```txt
It must not enter deferred bitmap baking.
```

This phase does not need a full coordinator class, but tests should demonstrate the intended coordination.

## Required tests

Add focused tests.

Suggested files:

```txt
test/models/unified_undo_history_test.dart
test/models/undo_history_entry_test.dart
test/models/brush_frame_drawing_state_test.dart
test/services/brush_frame_store_test.dart
```

Exact file names may be adjusted.

### Required test cases

#### Unified undo order

Test that mixed entries undo in exact global reverse order:

```txt
1. paint stroke on frame A
2. project/layer command
3. paint stroke on frame B
4. timeline command

Undo order:
4. timeline command
3. paint stroke on frame B
2. project/layer command
1. paint stroke on frame A
```

#### Redo order

Test redo restores the same order after undo.

#### New entry clears redo

Test:

```txt
push A
push B
undo B
push C
redoStack is cleared
```

#### User undo limit trimming

Test:

```txt
userUndoLimit = 3
push 5 entries
oldest 2 entries are returned as trimmed
undoStack keeps latest 3 only
```

#### Trimmed paint entry moves to deferred bake

Using `BrushFrameStore`, test:

```txt
1. Add 4 paint commands to one frame.
2. UnifiedUndoHistory userUndoLimit = 3 trims command 1.
3. Explicitly pass trimmed paint ref to BrushFrameStore.
4. command 1 becomes deferredBake.
5. commands 2/3/4 remain live.
6. visibleActivePaintCommands includes command 1 before 2/3/4.
7. command 1 is not undoable because it is no longer in UnifiedUndoHistory.
```

#### Trimmed structural command is not deferred-baked

Test that a trimmed `deleteLayer`, `renameLayer`, or `changeCutDuration` entry does not enter BrushFrameStore deferred bake state.

#### Undo paint hides command without baking

Test:

```txt
paint command is live
UnifiedUndoHistory takeUndo returns paint ref
BrushFrameStore markPaintCommandHiddenByUndo
command becomes hiddenByUndo
visibleActivePaintCommands excludes it
no deferred bake or baked state change occurs
```

#### Redo paint restores command without baking

Test:

```txt
hiddenByUndo command
UnifiedUndoHistory takeRedo returns paint ref
BrushFrameStore restorePaintCommandFromUndo
command becomes live
visibleActivePaintCommands includes it
```

#### Deferred commands are not affected by undo

Test:

```txt
deferredBake command remains visible
undo latest live command
deferred command remains deferredBake and visible
```

#### Flush frame prepares deferred commands

Since actual bitmap baking is out of scope, test a lightweight flush behavior:

```txt
flushFrame returns or marks deferred commands for future baking
flushFrame does not delete live user-undoable commands
flushFrame does not change global undo order
```

#### Full-path key isolation

Test two frames with the same FrameId but different ProjectId/TrackId/CutId/LayerId do not share drawing state.

## Existing test updates

Existing tests may be updated if the new names or models require it.

However, keep these protected areas stable:

```txt
test/ui/storyboard_panel_smoke_test.dart
test/ui/storyboard_panel_interaction_test.dart
timeline semantics tests
brush smoke/dev canvas tests
```

Do not weaken protected tests to make this PR pass.

Only update tests when the new architecture legitimately changes model names or responsibilities.

## Documentation update

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add a short section:

```txt
## Phase 193 foundation

Implemented foundation:
- UnifiedUndoHistory owns global order.
- BrushFrameStore owns frame-local paint state.
- Paint commands can move live -> hiddenByUndo -> live, or live -> deferredBake.
- Deferred bake remains non-user-undoable.
- Actual bitmap baking and UI wiring remain out of scope.
```

Do not overstate app completion.

## Production code rules

Allowed:

```txt
- Pure model classes
- Pure service/store classes
- Tests
- Documentation
- Small refactors to clarify existing brush history boundaries if necessary
```

Not allowed:

```txt
- main.dart wiring
- app route wiring
- production brush workspace UI
- StoryboardPanel integration
- TimelinePanel integration
- save/load
- actual renderer cache
- actual playback cache
- actual bitmap deferred baking
- Provider/Riverpod/Bloc/ChangeNotifier
- global singleton app state
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
- production app behavior changed or not
- UnifiedUndoHistory summary
- BrushFrameStore summary
- deferred bake state transition summary
- existing tests updated, if any
- checks run and results
- git status summary
```
