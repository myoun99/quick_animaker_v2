# Brush App Integration Decisions

## Status

Brush V1 internal smoke/dev/test stack is complete.
Brush is not app-complete yet.
App-complete means real Project / Track / Cut / Layer / Frame integration.

This document records the architecture foundation for the real app-complete Brush integration path. It is intentionally decision-only and does not wire the UI or introduce production rendering behavior.

## Completion target

The final app-complete target is:

- users can enter a real brush workspace from the app;
- drawing is bound to a specific Project / Track / Cut / Layer / Frame;
- switching frames preserves independent drawing state;
- undo/redo follows one global user-facing order;
- active frame editing stays fast;
- inactive frames use preview caches; and
- playback does not replay live paint commands.

## Frame metadata vs drawing payload

Frame remains lightweight. A `Frame` owns metadata, identity, and timing information only.

Drawing payload is stored outside `Frame` in `BrushFrameStore`, keyed by `BrushFrameKey`. Heavy bitmap surfaces, brush command lists, preview caches, and brush history payloads must not be embedded directly in the frame model.

Conceptually:

```txt
Frame = metadata / identity / timing information
BrushFrameStore = drawing payload storage
```

## BrushFrameKey

`BrushFrameKey` uses the full path key:

```txt
ProjectId / TrackId / CutId / LayerId / FrameId
```

Even if some identifiers become globally unique, the full path key remains the preferred integration key for now because it is easier to debug and safer while Project / Track / Cut / Layer / Frame ownership is being connected.

## Deferred Bake Hybrid Brush History

The long-term policy is **Deferred Bake Hybrid Brush History**.

The conceptual state for a brush frame is:

- `bakedBaseSurface`: old confirmed artwork compacted into bitmap/tile data;
- `deferredBakePaintCommands`: older non-user-undoable paint commands that are intentionally not baked immediately;
- `livePaintCommands`: recent user-undoable paint commands;
- `hiddenByUndoPaintCommands`, if needed: commands hidden by undo and available for redo while they remain in the active edit history;
- `inactivePreviewCache`: preview/composite cache used for inactive frames and playback; and
- dirty flags that identify which previews or composites need to be refreshed later.

Only frame-local paint operations may move between live, hidden-by-undo, deferred-bake, and baked states.

## Active frame display method

Active frame display uses method A:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
+ active stroke overlay
```

During active editing:

- no preview cache bake on undo/redo;
- no inactive preview cache rebuild on undo/redo;
- undo/redo must not bake the preview cache; and
- editing responsiveness is prioritized over cache freshness.

The active stroke overlay is an editing concern. It is not a playback mechanism.

## User undo limit and deferred bake buffer

The policy separates the user-visible undo limit from the deferred baking buffer:

```txt
userUndoLimit = number of user-undoable commands
deferredBakeRatio = percentage buffer for delayed baking
deferredBakeLimit = max(minimumBuffer, round(userUndoLimit * deferredBakeRatio))
```

Example:

```txt
userUndoLimit = 250
deferredBakeRatio = 10%
deferredBakeLimit = 25
```

The deferred bake buffer is not user-undoable. It exists only to avoid baking immediately during active drawing. Prefer the name `deferredBakeBuffer`; do not name it `bufferUndo` because it is not part of user-facing undo.

A future UI may show undo limit, buffer percentage, and estimated memory usage, but this phase does not add such UI.

## UnifiedUndoHistory

`UnifiedUndoHistory` owns the only global user-facing undo/redo order.

Conceptually:

```txt
UnifiedUndoHistory
  undoStack: List<UndoHistoryEntry>
  redoStack: List<UndoHistoryEntry>
```

Rules:

- one global user-facing undo order exists for brush, project, timeline, and layer changes;
- stores only own payloads and execute or expose payload operations;
- unified entries point to payload refs;
- `BrushFrameStore` does not determine global undo order;
- project/timeline/layer stores do not determine global undo order; and
- store payloads may be separated, but user-facing undo order is unified.

A unified undo entry may reference payloads such as:

```txt
PaintCommandRef(frameKey, paintCommandId)
ProjectCommandRef(projectCommandId)
TimelineCommandRef(timelineCommandId)
LayerCommandRef(layerCommandId)
```

## Paint command states

Paint-affecting commands belong to `BrushFrameStore` and are frame-local.

Examples include:

- paint stroke;
- erase stroke;
- clear current frame drawing; and
- fill current frame.

Conceptual paint command states are:

- `live`: recent user-undoable commands;
- `hiddenByUndo`: undone commands that may be redone;
- `deferredBake`: older non-user-undoable commands waiting for delayed baking; and
- `baked`: commands compacted into `bakedBaseSurface`.

Only frame-local paint commands may enter `livePaintCommands`, `deferredBakePaintCommands`, or `bakedBaseSurface` compaction.

## Structural command rule

Project/timeline/layer structural commands are not bitmap-baked and must not enter deferred bitmap baking.

Examples include:

- create frame;
- delete frame;
- move frame;
- create layer;
- delete layer;
- rename layer;
- reorder layer;
- change cut duration;
- create cut; and
- delete cut.

These commands should be represented as document/project/timeline/layer history payloads referenced by `UnifiedUndoHistory`.

## Flush barriers

Destructive structure changes require flush barriers before frame, layer, or cut operations can invalidate brush drawing payloads.

Conceptually:

```txt
before delete frame:
  BrushFrameStore.flushFrame(frameKey)
  then apply project command

before delete layer:
  BrushFrameStore.flushLayer(layerId)
  then apply project command
```

The same policy applies before moving or deleting a cut/layer/frame in a way that can invalidate drawing payloads. The purpose is to prevent deferred paint commands from being baked into missing or wrong targets.

## Playback rule

Playback uses preview/composite bitmap cache only. Playback must not replay live paint commands.

Rules:

- playback should not replay live paint commands;
- if preview cache is stale, it should be prepared before playback or marked dirty; and
- active frame command rendering is for editing, not playback.

## Out of scope for this phase

- main app wiring;
- production brush workspace;
- actual frame switching UI;
- renderer cache implementation;
- save/load;
- app-wide state management;
- timeline rewrite;
- storyboard drawing;
- actual deferred baking;
- playback cache implementation; and
- full undo/redo execution.

## Phase 193 foundation

Implemented foundation:
- UnifiedUndoHistory owns global order.
- BrushFrameStore owns frame-local paint state.
- Paint commands can move live -> hiddenByUndo -> live, or live -> deferredBake.
- Deferred bake remains non-user-undoable.
- Actual bitmap baking and UI wiring remain out of scope.

## Phase 194 app workspace integration

Implemented:
- BrushWorkspaceScreen app entry.
- BrushFrameEditSessionStore.
- BrushWorkspaceCoordinator.
- Frame switching with independent BrushEditSessionState per BrushFrameKey.
- Paint commits recorded in BrushFrameStore and UnifiedUndoHistory.

Still out of scope:
- Save/load.
- Renderer/playback cache.
- Actual deferred bitmap baking.
- Production toolbar.
- Full timeline/layer panel integration.

## Phase 195 workspace stabilization

Implemented:
- Debug reset behavior clarified.
- Cross-frame undo/redo behavior covered by tests.
- No-op commit safety covered by tests.
- BrushWorkspace status/debug text improved.

Still out of scope:
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
- full timeline/layer panel integration

## Phase 196 main canvas absorption preparation

Implemented:
- BrushWorkspaceScreen clarified as a temporary/debug wrapper.
- Reusable brush editing view extracted from the route-level screen.
- Temporary brush workspace fixture isolated.
- Main-canvas-oriented host/component prepared for future HomePage integration.

Still out of scope:
- deleting BrushWorkspaceScreen
- fully replacing HomePage CanvasView
- real timeline/layer/frame selection integration
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking

## Phase 197 main editor canvas embedding

Implemented:
- MainCanvasBrushHost can be shown inside the main editor canvas area through a debug/preview mode.
- Existing CanvasView remains the default path.
- BrushWorkspaceScreen remains available as a debug/manual route.
- This is a temporary bridge before real timeline/layer/frame selection integration.

Still out of scope:
- deleting BrushWorkspaceScreen
- deleting/replacing CanvasView
- real timeline/layer/frame selection integration
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking

## Phase 198 active editor selection bridge

Implemented:
- Main canvas brush preview path can receive active editor selection / BrushFrameKey.
- BrushWorkspaceFixture is no longer the only path for MainCanvasBrushHost.
- BrushWorkspaceScreen is explicitly marked as temporary and scheduled for deletion after main canvas brush integration stabilizes.

Still out of scope:
- deleting BrushWorkspaceScreen
- deleting Brush Workspace button
- deleting BrushWorkspaceFixture
- making Brush Host Preview the default
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
- full timeline/layer/frame production selection replacement

Future deletion target:
After the main canvas brush path is stable and tested, remove BrushWorkspaceScreen, the Brush Workspace route/button, and fixture-only frame switching UI.
