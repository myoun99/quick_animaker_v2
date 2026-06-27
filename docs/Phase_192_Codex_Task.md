# Phase 192 Codex Task

## Title

Brush app integration architecture foundation

## Current goal

The Brush work is not considered complete until it is connected to the real app-level Project / Cut / Layer / Frame flow.

The current Brush V1 smoke/dev/test stack is complete internally, but it is not yet app-complete.

This phase starts the app-complete Brush integration path.

## High-level target

The final target of the next brush work area is:

```txt
App runs
→ user can enter a real brush workspace
→ drawing is associated with a specific Project / Track / Cut / Layer / Frame
→ switching frames preserves independent drawing state
→ undo / redo operates in correct global order
→ active editing stays fast
→ inactive frames use preview/cache images
→ playback does not replay live stroke commands
```

This phase should not implement the full target yet.

This phase should establish the architecture foundation and document the decisions.

## Required decisions to encode

Create documentation and lightweight model/test foundations for the following decisions.

### 1. Frame metadata and drawing payload are separated

A `Frame` should remain lightweight.

Do not put heavy bitmap surfaces, brush command lists, preview caches, or history payloads directly inside `Frame`.

Instead, drawing payload should be stored outside the frame model and addressed by a stable key.

Concept:

```txt
Frame = metadata / identity / timing information
BrushFrameStore = drawing payload storage
```

### 2. BrushFrameKey identifies drawing payload

Introduce or document a key equivalent to:

```txt
BrushFrameKey:
  ProjectId
  TrackId
  CutId
  LayerId
  FrameId
```

If some IDs are already globally unique, still prefer the full path key for now because it is easier to debug and safer for integration.

### 3. Active frame display uses method A

For the currently edited frame, display should be:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
+ active in-progress stroke overlay
```

During active editing:

```txt
- Do not bake preview cache on undo.
- Do not bake preview cache on redo.
- Do not rebuild inactive preview cache during undo/redo.
- Prioritize editing responsiveness.
```

### 4. Deferred Bake Hybrid Brush History

Adopt the following long-term brush history policy:

```txt
old confirmed artwork = baked bitmap tile base
recent undoable paint operations = live paint commands
older non-undoable but not-yet-baked paint operations = deferred bake paint commands
inactive frame display/playback = preview/composite cache
```

The policy name should be:

```txt
Deferred Bake Hybrid Brush History
```

### 5. User undo limit and deferred bake buffer

Define the conceptual policy:

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

Important:

```txt
The deferred bake buffer is not undoable.
It exists only to avoid baking immediately during active drawing.
```

Prefer the name:

```txt
deferredBakeBuffer
```

Do not name it `bufferUndo` internally, because it is not user-undoable.

### 6. UnifiedUndoHistory owns the only global undo order

Even if payloads are stored in different stores, the undo order must be owned by one unified history.

Concept:

```txt
UnifiedUndoHistory
  undoStack: List<UndoHistoryEntry>
  redoStack: List<UndoHistoryEntry>
```

Rules:

```txt
- UnifiedUndoHistory is the only source of undo/redo ordering.
- BrushFrameStore must not decide global undo order.
- Project/Timeline/Layer stores must not decide global undo order.
- Stores are payload owners/executors only.
```

### 7. Unified entries may reference store payloads

A unified undo entry may be:

```txt
PaintCommandRef(frameKey, paintCommandId)
ProjectCommandRef(projectCommandId)
TimelineCommandRef(timelineCommandId)
LayerCommandRef(layerCommandId)
```

User-facing undo is one stack.

Internal payload handling is separated.

### 8. Paint command storage is frame-local

Paint-affecting commands belong to `BrushFrameStore`.

Examples:

```txt
paint stroke
erase stroke
clear current frame drawing
fill current frame
```

Only frame-local paint commands may enter:

```txt
livePaintCommands
deferredBakePaintCommands
bakedBaseSurface compaction
```

### 9. Project/timeline/layer structural commands are not baked

Commands such as these must not enter deferred bitmap baking:

```txt
create frame
delete frame
move frame
create layer
delete layer
rename layer
reorder layer
change cut duration
create cut
delete cut
```

These commands should be represented as document/project/timeline/layer history payloads referenced by `UnifiedUndoHistory`.

### 10. Flush barrier before destructive structure changes

Before deleting or moving a frame/layer/cut in a way that can invalidate brush drawing payloads, the design should require a flush barrier.

Concept:

```txt
before delete frame:
  BrushFrameStore.flushFrame(frameKey)
  then apply project command

before delete layer:
  BrushFrameStore.flushLayer(layerId)
  then apply project command
```

The purpose is to prevent deferred paint commands from being baked into missing or wrong targets.

### 11. Playback never replays live paint commands

Playback must use preview/composite bitmap cache.

Rules:

```txt
- Playback should not replay live paint commands.
- If preview cache is stale, it should be prepared before playback or marked dirty.
- Active frame command rendering is for editing, not playback.
```

## Required files

Create:

```txt
docs/Brush_App_Integration_Decisions.md
```

Likely create:

```txt
test/architecture/brush_app_integration_decisions_test.dart
```

Optional, only if lightweight and useful:

```txt
lib/src/models/brush_frame_key.dart
lib/src/models/brush_history_policy.dart
test/models/brush_frame_key_test.dart
test/models/brush_history_policy_test.dart
```

Do not create heavy implementation yet.

Do not wire UI yet.

## Brush_App_Integration_Decisions.md content

Create:

```txt
docs/Brush_App_Integration_Decisions.md
```

It must include these sections:

```txt
# Brush App Integration Decisions

## Status

Brush V1 internal smoke/dev/test stack is complete.
Brush is not app-complete yet.
App-complete means real Project / Track / Cut / Layer / Frame integration.

## Completion target

Describe the final app-complete target:
- enter brush workspace from app
- bind drawing to Project / Track / Cut / Layer / Frame
- frame switching preserves independent drawing state
- undo/redo follows one global user-facing order
- active frame editing stays fast
- inactive frames use preview caches
- playback does not replay live paint commands

## Frame metadata vs drawing payload

State that Frame remains lightweight.
Drawing payload is stored in BrushFrameStore, keyed by BrushFrameKey.

## BrushFrameKey

Document full path key:
ProjectId / TrackId / CutId / LayerId / FrameId.

## Deferred Bake Hybrid Brush History

Document:
- bakedBaseSurface
- deferredBakePaintCommands
- livePaintCommands
- hiddenByUndoPaintCommands if needed
- inactivePreviewCache
- dirty flags

## Active frame display method

Document method A:
bakedBaseSurface + deferredBakePaintCommands + livePaintCommands + active stroke overlay.

Explicitly state:
- no preview cache bake on undo/redo during active editing
- no inactive preview cache rebuild on undo/redo during active editing

## User undo limit and deferred bake buffer

Document:
- userUndoLimit
- deferredBakeRatio
- deferredBakeLimit
- deferred bake buffer is not user-undoable
- UI may later show undo limit, buffer percentage, and estimated memory usage

## UnifiedUndoHistory

Document:
- one global user-facing undo order
- stores only own payloads
- unified entries point to payload refs
- BrushFrameStore does not determine global undo order

## Paint command states

Document conceptual states:
- live
- hiddenByUndo
- deferredBake
- baked

## Structural command rule

Document that project/timeline/layer structural commands are not bitmap-baked.

## Flush barriers

Document flush before destructive frame/layer/cut operations.

## Playback rule

Playback uses preview/composite bitmap cache only.
Playback must not replay live paint commands.

## Out of scope for this phase

- main app wiring
- production brush workspace
- actual frame switching UI
- renderer cache implementation
- save/load
- app-wide state management
- timeline rewrite
- storyboard drawing
```

## Optional model skeletons

If adding lightweight model skeletons, keep them pure and simple.

Example conceptual classes:

```dart
class BrushFrameKey {
  const BrushFrameKey({
    required this.projectId,
    required this.trackId,
    required this.cutId,
    required this.layerId,
    required this.frameId,
  });

  final ProjectId projectId;
  final TrackId trackId;
  final CutId cutId;
  final LayerId layerId;
  final FrameId frameId;
}
```

Policy example:

```dart
class BrushHistoryPolicy {
  const BrushHistoryPolicy({
    required this.userUndoLimit,
    required this.deferredBakeRatio,
    this.minimumDeferredBakeBuffer = 16,
  });

  final int userUndoLimit;
  final double deferredBakeRatio;
  final int minimumDeferredBakeBuffer;

  int get deferredBakeLimit;
}
```

Rules:

```txt
- userUndoLimit must be positive.
- deferredBakeRatio must be non-negative.
- deferredBakeLimit should be max(minimumDeferredBakeBuffer, round(userUndoLimit * deferredBakeRatio)).
```

Do not introduce production behavior from these skeletons yet.

## Architecture guard test

Create or update architecture tests to assert documentation exists and important decision keywords are present.

Suggested test:

```txt
test/architecture/brush_app_integration_decisions_test.dart
```

Check:

```txt
- docs/Brush_App_Integration_Decisions.md exists
- contains "Deferred Bake Hybrid Brush History"
- contains "UnifiedUndoHistory"
- contains "BrushFrameStore"
- contains "BrushFrameKey"
- contains "Playback must not replay live paint commands"
- contains "Frame remains lightweight"
```

If model skeletons are added, add direct model tests too.

## Production code rules

Do not modify app UI.

Do not wire BrushCanvasSmokeScreen into main.dart.

Do not create app routes.

Do not change StoryboardPanel.

Do not change TimelinePanel.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or app-wide global singleton state.

Do not implement save/load.

Do not implement renderer cache.

Do not implement playback cache.

Do not implement actual deferred baking yet.

Do not implement full undo/redo execution yet.

This phase is architecture foundation only.

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
- whether production app behavior changed
- documentation summary
- model skeletons added, if any
- architecture guard summary
- check results
- git status summary
```
