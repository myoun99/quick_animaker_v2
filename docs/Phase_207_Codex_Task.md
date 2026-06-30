# Phase 207 Codex Task

## Title

Rename BrushWorkspaceCoordinator to BrushFrameEditingCoordinator

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

3. Brush coordinator naming cleanup preparation
   - Done in Phase 206.
   - BrushWorkspaceCoordinator was documented as a production brush editing coordination service.
   - Future rename target was documented as BrushFrameEditingCoordinator.
   - BrushWorkspaceCacheInvalidationSink was explicitly deferred.

4. Brush coordinator runtime rename
   - This phase.
   - Rename BrushWorkspaceCoordinator to BrushFrameEditingCoordinator.
   - Rename the service file.
   - Update imports and tests.
   - Keep runtime behavior unchanged.

5. BrushWorkspaceCacheInvalidationSink naming decision
   - Later.
   - Decide separately whether to rename or keep it.

6. Brush Host Preview production-mode promotion
   - Later.

7. Bitmap canvas storage foundation
   - Later.
```

Required long-term direction:

```txt
temporary workspace UI names
-> production brush host/panel naming
-> production brush editing coordinator naming
-> cache invalidation naming decision
-> bitmap storage foundation
-> dirty tile tracking
-> tile delta undo
-> cache policy
-> brush rasterizer
-> canvas UI integration
```

## 2. This phase detailed roadmap

Phase 207 performs the runtime mechanical rename decided in Phase 206.

Implement:

```txt
1. Rename BrushWorkspaceCoordinator class to BrushFrameEditingCoordinator.
2. Rename brush_workspace_coordinator.dart to brush_frame_editing_coordinator.dart.
3. Update all production imports.
4. Update all test imports.
5. Rename coordinator-specific tests if they exist.
6. Keep behavior identical.
7. Keep constructor parameters, fields, methods, and semantics unchanged except names.
8. Update architecture decision docs with Phase 207.
9. Update Phase 206 architecture test or add Phase 207 architecture coverage.
10. Do not rename BrushWorkspaceCacheInvalidationSink in this phase.
```

The rename target is:

```txt
BrushWorkspaceCoordinator
-> BrushFrameEditingCoordinator
```

File rename target:

```txt
lib/src/services/brush_workspace_coordinator.dart
-> lib/src/services/brush_frame_editing_coordinator.dart
```

If a matching test file exists, rename it:

```txt
test/services/brush_workspace_coordinator_test.dart
-> test/services/brush_frame_editing_coordinator_test.dart
```

## 3. This phase scope

### In scope

Expected production changes:

```txt
lib/src/services/brush_frame_editing_coordinator.dart
```

Expected deleted/renamed file:

```txt
lib/src/services/brush_workspace_coordinator.dart
```

Expected test updates:

```txt
test/**/*.dart
```

Expected docs updates:

```txt
docs/Brush_App_Integration_Decisions.md
docs/Phase_207_Codex_Task.md
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

Do not rename:

```txt
BrushWorkspaceCacheInvalidationSink
brush_workspace_cache_invalidation_sink.dart
```

Do not change behavior in:

```txt
MainCanvasBrushHost
BrushCanvasPanel
InteractiveBrushEditCanvasView
CanvasView
HomePage
BrushFrameStore
BrushFrameEditSessionStore
UnifiedUndoHistory
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

### 4-1. Rename service file and class

Rename:

```txt
lib/src/services/brush_workspace_coordinator.dart
```

to:

```txt
lib/src/services/brush_frame_editing_coordinator.dart
```

Rename class:

```dart
BrushWorkspaceCoordinator
```

to:

```dart
BrushFrameEditingCoordinator
```

Keep behavior unchanged.

Do not change:

```txt
constructor behavior
initialFrameKey behavior
frame switching behavior
BrushFrameStore interaction
BrushFrameEditSessionStore interaction
UnifiedUndoHistory interaction
commit / undo / redo behavior
cache invalidation behavior
```

Only rename the symbol and import path.

### 4-2. Update all imports and references

Search and update:

```txt
BrushWorkspaceCoordinator
brush_workspace_coordinator.dart
```

Expected after rename:

```txt
BrushFrameEditingCoordinator
brush_frame_editing_coordinator.dart
```

Allowed remaining `BrushWorkspaceCoordinator` references:

```txt
docs historical notes
docs Phase 206 / Phase 207 explanation
architecture tests that intentionally verify the rename decision/history
```

Not allowed in production runtime code after this phase:

```txt
class BrushWorkspaceCoordinator
import ...brush_workspace_coordinator.dart
```

### 4-3. Rename tests if applicable

If this file exists:

```txt
test/services/brush_workspace_coordinator_test.dart
```

rename it to:

```txt
test/services/brush_frame_editing_coordinator_test.dart
```

Update test names and imports.

If tests use `BrushWorkspaceCoordinator`, update to `BrushFrameEditingCoordinator`.

Keep all expected behavior identical.

### 4-4. Update test helpers

Update:

```txt
test/helpers/brush_canvas_fixture.dart
```

If it imports or creates `BrushWorkspaceCoordinator`, update it to use:

```txt
BrushFrameEditingCoordinator
```

Do not move `BrushCanvasFixture` back into lib.

### 4-5. Update BrushCanvasPanel / MainCanvasBrushHost imports only if needed

If these files import the coordinator directly, update imports only:

```txt
lib/src/ui/brush/brush_canvas_panel.dart
lib/src/ui/brush/main_canvas_brush_host.dart
```

Do not change UI behavior.

### 4-6. Update architecture docs

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt
## Phase 207 BrushFrameEditingCoordinator runtime rename

Implemented:
- Renamed BrushWorkspaceCoordinator to BrushFrameEditingCoordinator.
- Renamed brush_workspace_coordinator.dart to brush_frame_editing_coordinator.dart.
- Updated production imports to use BrushFrameEditingCoordinator.
- Updated tests and test helpers to use BrushFrameEditingCoordinator.
- Kept runtime behavior unchanged.
- BrushWorkspaceCacheInvalidationSink was not renamed in this phase.
- Deleted workspace UI and debug controls were not reintroduced.

Still out of scope:
- renaming BrushWorkspaceCacheInvalidationSink
- changing brush host behavior
- changing canvas UI behavior
- actual drawing
- bitmap storage foundation
- dirty tile tracking
- tile delta undo
- renderer/cache/save/load

Future cleanup:
Decide separately whether BrushWorkspaceCacheInvalidationSink should be renamed or kept.
```

### 4-7. Update architecture tests

Update:

```txt
test/architecture/brush_coordinator_naming_decisions_test.dart
```

The Phase 206 test may still verify historical decision.

Add or update coverage for Phase 207:

```txt
- BrushFrameEditingCoordinator is documented as implemented.
- BrushWorkspaceCacheInvalidationSink is still deferred.
- Runtime behavior was kept unchanged.
```

If adding a source scan test, keep it focused.

Acceptable checks:

```txt
- lib/src/services/brush_frame_editing_coordinator.dart exists
- lib/src/services/brush_workspace_coordinator.dart does not exist
- production lib files do not import brush_workspace_coordinator.dart
```

Do not make the test brittle against historical docs containing `BrushWorkspaceCoordinator`.

### 4-8. Do not update Handoff sections 0 through 4

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
rg "BrushWorkspaceCoordinator|brush_workspace_coordinator|BrushFrameEditingCoordinator|brush_frame_editing_coordinator|BrushWorkspaceCacheInvalidationSink" lib test docs
```

Expected:

```txt
- BrushFrameEditingCoordinator exists in lib runtime code.
- brush_frame_editing_coordinator.dart exists.
- BrushWorkspaceCoordinator does not exist in lib runtime code.
- brush_workspace_coordinator.dart is not imported by lib runtime code.
- BrushWorkspaceCoordinator may remain in docs as historical/Phase 206 text.
- BrushWorkspaceCacheInvalidationSink remains unchanged.
- No deleted workspace UI/debug controls are reintroduced.
```

If Dart/Flutter are unavailable, report that clearly.

## Acceptance criteria

```txt
1. BrushWorkspaceCoordinator class is renamed to BrushFrameEditingCoordinator.
2. brush_workspace_coordinator.dart is renamed to brush_frame_editing_coordinator.dart.
3. Production imports are updated.
4. Tests and test helpers are updated.
5. Runtime behavior is unchanged.
6. BrushWorkspaceCacheInvalidationSink is not renamed.
7. MainCanvasBrushHost behavior is unchanged.
8. BrushCanvasPanel behavior is unchanged.
9. MainCanvasBrushHost.fixture() is not reintroduced.
10. BrushCanvasFixture is not reintroduced under lib.
11. Debug controls are not reintroduced.
12. BrushWorkspaceScreen / BrushWorkspaceView are not reintroduced.
13. docs/Brush_App_Integration_Decisions.md has Phase 207 section.
14. flutter analyze passes.
15. flutter test passes.
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
- whether BrushWorkspaceCoordinator was renamed
- whether brush_workspace_coordinator.dart was renamed
- whether production imports were updated
- whether tests and test helpers were updated
- whether BrushWorkspaceCacheInvalidationSink was intentionally not renamed
- whether runtime behavior stayed unchanged
- whether deleted UI/debug controls were not reintroduced
- docs updated
- checks run and results
- rg search summary
- git status summary
```
