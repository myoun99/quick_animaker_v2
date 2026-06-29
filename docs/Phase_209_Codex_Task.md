# Phase 209 Codex Task

## Title

Rename BrushWorkspaceCacheInvalidationSink to BrushEditCacheInvalidationSink

## 1. Overall roadmap

Current brush integration roadmap:

```txt
1. Brush preview / UI cleanup
   - Done enough for now.
   - BrushWorkspaceScreen was removed.
   - BrushWorkspaceView was renamed to BrushCanvasPanel.
   - Temporary debug controls were removed.
   - Production fixture fallback was removed.
   - BrushCanvasFixture was moved out of production code into test helpers.

2. Production brush host separation
   - Done enough for now.
   - MainCanvasBrushHost is selection-driven.
   - Missing selection renders an empty-selection placeholder.
   - MainCanvasBrushHost.fixture() was removed.
   - Production lib code no longer imports BrushCanvasFixture.

3. Brush coordinator naming cleanup
   - Phase 206 documented the coordinator rename decision.
   - Phase 207 renamed BrushWorkspaceCoordinator to BrushFrameEditingCoordinator.

4. Brush cache invalidation sink naming cleanup
   - Phase 208 documented the sink naming decision.
   - This phase performs the runtime mechanical rename.

5. Brush Host Preview production-mode promotion
   - Later.

6. Bitmap canvas storage foundation
   - Later.

7. Dirty tile tracking / tile delta undo / cache policy
   - Later.
```

Required long-term direction:

```txt
temporary workspace UI names
-> production brush host/panel naming
-> production brush editing coordinator naming
-> brush edit cache invalidation sink naming
-> brush host production mode preparation
-> bitmap storage foundation
-> dirty tile tracking
-> tile delta undo
-> cache policy
-> brush rasterizer
-> canvas UI integration
```

## 2. This phase detailed roadmap

Phase 209 performs the runtime mechanical rename decided in Phase 208.

Implement:

```txt
1. Rename BrushWorkspaceCacheInvalidationSink class to BrushEditCacheInvalidationSink.
2. Rename brush_workspace_cache_invalidation_sink.dart to brush_edit_cache_invalidation_sink.dart.
3. Update all production imports.
4. Update all test imports.
5. Update architecture tests to reflect that Phase 209 implemented the rename.
6. Update docs/Brush_App_Integration_Decisions.md with a Phase 209 section.
7. Keep behavior identical.
8. Do not change cache invalidation semantics.
9. Do not modify BrushFrameEditingCoordinator behavior.
10. Do not touch canvas UI behavior.
```

Rename target:

```txt
BrushWorkspaceCacheInvalidationSink
-> BrushEditCacheInvalidationSink
```

File rename target:

```txt
lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart
-> lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart
```

## 3. This phase scope

### In scope

Expected production changes:

```txt
lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart
lib/src/ui/brush/main_canvas_brush_host.dart
lib/src/ui/brush/brush_canvas_panel.dart
```

Expected deleted/renamed file:

```txt
lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart
```

Expected test updates:

```txt
test/**/*.dart
```

Expected docs updates:

```txt
docs/Brush_App_Integration_Decisions.md
docs/Phase_209_Codex_Task.md
```

Optional handoff update:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
```

Important handoff rule:

```txt
If docs/Handoff_QuickAnimaker_v2_Current.md is updated, only update section 6 or later.
Do not edit sections 0 through 4.
```

### Out of scope

Do not modify behavior in:

```txt
BrushFrameEditingCoordinator
MainCanvasBrushHost
BrushCanvasPanel
InteractiveBrushEditCanvasView
CanvasView
HomePage
BrushFrameStore
BrushFrameEditSessionStore
UnifiedUndoHistory
```

Do not change:

```txt
cache invalidation execution behavior
cache invalidation request semantics
brush edit session behavior
frame switching behavior
undo / redo behavior
empty selection behavior
Brush Host Preview toggle behavior
```

Do not reintroduce:

```txt
BrushWorkspaceScreen
BrushWorkspaceView
Brush Workspace button
MainCanvasBrushHost.fixture()
BrushCanvasFixture under lib
Frame 1 / Frame 2 / Frame 3 debug buttons
Debug Reset Session
temporary Black / Red buttons
showDebugControls
```

Do not implement:

```txt
actual drawing
pointer input
tablet input
bitmap brush rasterizer
BitmapSurface / BitmapTile / TileCoord
DirtyTileSet / DirtyRegion
TileDeltaCommand
renderer cache
playback cache
save/load
onion skin
Photoshop / ABR brush import
Provider / Riverpod / Bloc / ChangeNotifier / global singleton state
```

## 4. Implementation instructions

### 4-1. Rename sink file and class

Rename:

```txt
lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart
```

to:

```txt
lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart
```

Rename class:

```dart
BrushWorkspaceCacheInvalidationSink
```

to:

```dart
BrushEditCacheInvalidationSink
```

Keep behavior unchanged.

Do not change:

```txt
constructor behavior
stored dependencies
cache invalidation dispatch behavior
method names unless required by the class rename
return values
null/empty behavior
error behavior
```

Only rename the symbol and import path.

### 4-2. Update all imports and references

Search and update:

```txt
BrushWorkspaceCacheInvalidationSink
brush_workspace_cache_invalidation_sink.dart
```

Expected after rename:

```txt
BrushEditCacheInvalidationSink
brush_edit_cache_invalidation_sink.dart
```

Allowed remaining `BrushWorkspaceCacheInvalidationSink` references:

```txt
docs historical notes
docs Phase 208 / Phase 209 explanation
architecture tests that intentionally verify the rename decision/history
```

Not allowed in production runtime code after this phase:

```txt
class BrushWorkspaceCacheInvalidationSink
import ...brush_workspace_cache_invalidation_sink.dart
```

### 4-3. Update MainCanvasBrushHost / BrushCanvasPanel imports only if needed

If these files import the sink directly, update imports only:

```txt
lib/src/ui/brush/main_canvas_brush_host.dart
lib/src/ui/brush/brush_canvas_panel.dart
```

Do not change UI behavior.

Expected type after rename:

```txt
BrushEditCacheInvalidationSink
```

### 4-4. Update tests

Update all test imports and references.

Likely affected files include:

```txt
test/architecture/brush_cache_invalidation_sink_naming_decisions_test.dart
test/**/*.dart
```

If the Phase 208 test currently checks that the old runtime file still exists, update it for Phase 209.

New architecture coverage should verify:

```txt
- lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart exists
- lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart does not exist
- production lib files do not import brush_workspace_cache_invalidation_sink.dart
- BrushWorkspaceCacheInvalidationSink does not exist in lib runtime code
- BrushEditCacheInvalidationSink exists in lib runtime code
```

Do not make the test brittle against historical docs containing `BrushWorkspaceCacheInvalidationSink`.

### 4-5. Update architecture docs

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt
## Phase 209 BrushEditCacheInvalidationSink runtime rename

Implemented:
- Renamed BrushWorkspaceCacheInvalidationSink to BrushEditCacheInvalidationSink.
- Renamed brush_workspace_cache_invalidation_sink.dart to brush_edit_cache_invalidation_sink.dart.
- Updated production imports to use BrushEditCacheInvalidationSink.
- Updated tests to use BrushEditCacheInvalidationSink.
- Kept runtime behavior unchanged.
- Kept cache invalidation semantics unchanged.
- Deleted workspace UI and debug controls were not reintroduced.

Still out of scope:
- changing BrushFrameEditingCoordinator behavior
- changing brush host behavior
- changing canvas UI behavior
- changing cache invalidation behavior
- actual drawing
- bitmap storage foundation
- dirty tile tracking
- tile delta undo
- renderer/cache/save/load

Future cleanup:
- Continue toward Brush Host Preview production-mode preparation.
- Keep actual cache implementation separate from naming cleanup.
```

### 4-6. Do not update Handoff sections 0 through 4

If updating:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
```

only update section 6 or later.

Do not edit:

```txt
section 0
section 1
section 2
section 3
section 4
```

This phase does not require handoff edits unless absolutely necessary.

## 5. Checks / format / commit guidance

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

Also run:

```bash
rg "BrushWorkspaceCacheInvalidationSink|BrushEditCacheInvalidationSink|brush_workspace_cache_invalidation_sink|brush_edit_cache_invalidation_sink|BrushFrameEditingCoordinator" docs test lib
```

Expected:

```txt
- BrushEditCacheInvalidationSink exists in lib runtime code.
- brush_edit_cache_invalidation_sink.dart exists.
- BrushWorkspaceCacheInvalidationSink does not exist in lib runtime code.
- brush_workspace_cache_invalidation_sink.dart is not imported by lib runtime code.
- BrushWorkspaceCacheInvalidationSink may remain in docs as historical/Phase 208 text.
- BrushFrameEditingCoordinator remains unchanged.
- No deleted workspace UI/debug controls are reintroduced.
```

If Dart/Flutter are unavailable, report that clearly.

## Acceptance criteria

```txt
1. BrushWorkspaceCacheInvalidationSink class is renamed to BrushEditCacheInvalidationSink.
2. brush_workspace_cache_invalidation_sink.dart is renamed to brush_edit_cache_invalidation_sink.dart.
3. Production imports are updated.
4. Tests are updated.
5. Runtime behavior is unchanged.
6. Cache invalidation semantics are unchanged.
7. BrushFrameEditingCoordinator behavior is unchanged.
8. MainCanvasBrushHost behavior is unchanged.
9. BrushCanvasPanel behavior is unchanged.
10. MainCanvasBrushHost.fixture() is not reintroduced.
11. BrushCanvasFixture is not reintroduced under lib.
12. Debug controls are not reintroduced.
13. BrushWorkspaceScreen / BrushWorkspaceView are not reintroduced.
14. docs/Brush_App_Integration_Decisions.md has Phase 209 section.
15. flutter analyze passes.
16. flutter test passes.
```

## Android Studio manual confirmation

After merge and local checks, run the app.

Confirm:

```txt
1. App launches normally.
2. Default CanvasView still appears.
3. Brush Host Preview toggle still exists.
4. Brush Host Preview behavior is unchanged.
5. Empty selection still shows placeholder.
6. No Frame 1 / Frame 2 / Frame 3 debug buttons.
7. No Debug Reset Session.
8. No Brush Workspace button.
```

## Report back

Report:

```txt
- changed files
- whether BrushWorkspaceCacheInvalidationSink was renamed
- whether brush_workspace_cache_invalidation_sink.dart was renamed
- whether production imports were updated
- whether tests were updated
- whether BrushFrameEditingCoordinator was intentionally not changed
- whether cache invalidation behavior stayed unchanged
- whether runtime behavior stayed unchanged
- whether deleted UI/debug controls were not reintroduced
- docs updated
- checks run and results
- rg search summary
- git status summary
```
