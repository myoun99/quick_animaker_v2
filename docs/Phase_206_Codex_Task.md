# Phase 206 Codex Task

## Title

Document and prepare BrushWorkspaceCoordinator naming cleanup

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
   - This phase.
   - Document what BrushWorkspaceCoordinator currently does.
   - Decide whether it is a production brush editing service or only a deleted workspace route artifact.
   - Choose the future rename target.
   - Add architecture tests/docs that lock the decision.
   - Do not rename runtime classes/files yet.

4. Brush coordinator runtime rename
   - Later.
   - Rename BrushWorkspaceCoordinator to the chosen production name.
   - Rename file and tests together.
   - Keep behavior unchanged.

5. BrushWorkspaceCacheInvalidationSink naming decision
   - Later.
   - Decide whether to rename it or keep it.
   - Do not include it in this phase.

6. Brush Host Preview production-mode promotion
   - Later.
   - Replace preview toggle with final canvas-mode integration when ready.

7. Bitmap canvas storage foundation
   - Later.
   - Start BitmapSurface / BitmapTile / TileCoord only after brush host naming cleanup is stable.
```

Required long-term direction:

```txt
temporary workspace UI names
-> production brush host/panel naming
-> production brush editing coordinator naming
-> bitmap storage foundation
-> dirty tile tracking
-> tile delta undo
-> cache policy
-> brush rasterizer
-> canvas UI integration
```

## 2. This phase detailed roadmap

Phase 206 is a documentation and architecture-prep phase.

Implement:

```txt
1. Document the current responsibility of BrushWorkspaceCoordinator.
2. Clarify that BrushWorkspaceCoordinator is no longer tied to BrushWorkspaceScreen.
3. Decide and document the future rename target.
4. Preferred future name: BrushFrameEditingCoordinator.
5. Add a lightweight architecture test that protects this decision.
6. Do not rename BrushWorkspaceCoordinator yet.
7. Do not rename BrushWorkspaceCacheInvalidationSink yet.
8. Do not change runtime behavior.
9. Do not touch canvas UI behavior.
10. Update docs so Phase 207 can perform a safe mechanical rename.
```

Preferred future rename:

```txt
BrushWorkspaceCoordinator
-> BrushFrameEditingCoordinator
```

Reason:

```txt
- It is not a widget.
- It is not a renderer.
- It is not a deleted workspace screen.
- It coordinates brush frame editing state.
- It connects active frame editing sessions, brush frame store operations, and unified undo history.
- The name remains valid after Brush Host Preview becomes production canvas mode.
```

Alternative names considered:

```txt
BrushEditCoordinator
BrushCanvasCoordinator
BrushFrameEditCoordinator
```

Decision:

```txt
Use BrushFrameEditingCoordinator as the future rename target.
```

## 3. This phase scope

### In scope

Expected files to modify or add:

```txt
docs/Brush_App_Integration_Decisions.md
docs/Phase_206_Codex_Task.md
test/architecture/brush_coordinator_naming_decisions_test.dart
```

Optional, only if a suitable architecture test file already exists:

```txt
test/architecture/brush_v1_scope_guard_test.dart
```

In scope work:

```txt
- Add Phase 206 section to docs/Brush_App_Integration_Decisions.md.
- Document BrushWorkspaceCoordinator current responsibility.
- Document that BrushWorkspaceCoordinator is a production brush editing coordinator despite its current name.
- Document future rename target: BrushFrameEditingCoordinator.
- Add architecture test to verify the decision is documented.
- Add guard that deleted workspace UI names are not reintroduced.
```

### Out of scope

Do not rename:

```txt
BrushWorkspaceCoordinator
BrushWorkspaceCacheInvalidationSink
```

Do not modify runtime behavior in:

```txt
lib/src/services/brush_workspace_coordinator.dart
lib/src/ui/brush/main_canvas_brush_host.dart
lib/src/ui/brush/brush_canvas_panel.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/ui/home_page.dart
```

Do not reintroduce:

```txt
BrushWorkspaceScreen
BrushWorkspaceView
Brush Workspace button
MainCanvasBrushHost.fixture()
BrushCanvasFixture in lib
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

### 4-1. Update Brush_App_Integration_Decisions.md

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add this section:

```txt
## Phase 206 BrushWorkspaceCoordinator naming cleanup preparation

Decision:
- BrushWorkspaceCoordinator is no longer tied to the deleted BrushWorkspaceScreen route.
- BrushWorkspaceCoordinator is currently a production brush editing coordination service.
- Its current responsibilities include coordinating active brush frame editing state, BrushFrameStore operations, BrushFrameEditSessionStore sessions, and UnifiedUndoHistory.
- The current name still contains retired "Workspace" wording, but the runtime behavior should not be changed in this phase.

Preferred future rename:
- BrushWorkspaceCoordinator -> BrushFrameEditingCoordinator

Why BrushFrameEditingCoordinator:
- It is not a widget.
- It is not a canvas renderer.
- It is not a workspace screen.
- It coordinates brush frame editing behavior.
- It remains valid after Brush Host Preview becomes production canvas mode.

Alternatives considered:
- BrushEditCoordinator: too broad.
- BrushCanvasCoordinator: sounds too close to canvas rendering/widget orchestration.
- BrushFrameEditCoordinator: acceptable, but BrushFrameEditingCoordinator reads more clearly as a service role.

Implemented in Phase 206:
- Documented BrushWorkspaceCoordinator responsibility and future rename target.
- Added architecture coverage for the naming decision.
- Left runtime behavior unchanged.
- Did not rename BrushWorkspaceCoordinator yet.
- Did not rename BrushWorkspaceCacheInvalidationSink.
- Did not reintroduce deleted workspace UI or debug controls.

Still out of scope:
- renaming BrushWorkspaceCoordinator
- renaming BrushWorkspaceCacheInvalidationSink
- changing brush host behavior
- changing canvas UI behavior
- actual drawing
- bitmap storage foundation
- dirty tile tracking
- tile delta undo
- renderer/cache/save/load

Future cleanup:
- Phase 207 should rename BrushWorkspaceCoordinator to BrushFrameEditingCoordinator if no new responsibility conflict is found.
- BrushWorkspaceCacheInvalidationSink should be considered separately after the coordinator rename is stable.
```

### 4-2. Add architecture test

Create:

```txt
test/architecture/brush_coordinator_naming_decisions_test.dart
```

Suggested behavior:

```txt
- Read docs/Brush_App_Integration_Decisions.md.
- Verify that the Phase 206 section exists.
- Verify that BrushWorkspaceCoordinator is documented as no longer tied to BrushWorkspaceScreen.
- Verify that BrushFrameEditingCoordinator is documented as the future rename target.
- Verify that BrushWorkspaceCacheInvalidationSink is explicitly out of scope for this phase.
```

Suggested test style:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('documents BrushWorkspaceCoordinator naming cleanup decision', () {
    final doc = File('docs/Brush_App_Integration_Decisions.md').readAsStringSync();

    expect(
      doc,
      contains('## Phase 206 BrushWorkspaceCoordinator naming cleanup preparation'),
    );
    expect(
      doc,
      contains('BrushWorkspaceCoordinator is no longer tied to the deleted BrushWorkspaceScreen route.'),
    );
    expect(
      doc,
      contains('BrushWorkspaceCoordinator -> BrushFrameEditingCoordinator'),
    );
    expect(
      doc,
      contains('BrushWorkspaceCacheInvalidationSink should be considered separately'),
    );
  });
}
```

You may adjust exact strings if necessary, but keep the test meaningful and not overly fragile.

### 4-3. Add scope guard if appropriate

In the same test file, add a second test that checks:

```txt
- docs do not say to reintroduce BrushWorkspaceScreen
- docs do not say to reintroduce BrushWorkspaceView
- docs do not say to reintroduce MainCanvasBrushHost.fixture()
```

Suggested test:

```dart
test('does not reintroduce deleted brush workspace UI', () {
  final doc = File('docs/Brush_App_Integration_Decisions.md').readAsStringSync();

  expect(doc, isNot(contains('reintroduce BrushWorkspaceScreen')));
  expect(doc, isNot(contains('reintroduce BrushWorkspaceView')));
  expect(doc, isNot(contains('reintroduce MainCanvasBrushHost.fixture()')));
});
```

If this is too broad, replace it with a clearer positive assertion that Phase 206 says runtime behavior remains unchanged and deleted UI remains out of scope.

### 4-4. Do not rename runtime code yet

Do not rename:

```txt
lib/src/services/brush_workspace_coordinator.dart
class BrushWorkspaceCoordinator
test/services/brush_workspace_coordinator_test.dart
```

Do not create:

```txt
lib/src/services/brush_frame_editing_coordinator.dart
class BrushFrameEditingCoordinator
test/services/brush_frame_editing_coordinator_test.dart
```

Those are for the next phase.

### 4-5. Do not update Handoff sections 0 through 4

If docs/Handoff_QuickAnimaker_v2_Current.md is updated, only update section 6 or later.

But this phase does not require handoff edits unless absolutely necessary.

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
rg "BrushWorkspaceCoordinator|BrushFrameEditingCoordinator|BrushWorkspaceCacheInvalidationSink" docs test lib
```

Expected:

```txt
- BrushWorkspaceCoordinator still exists in runtime code.
- BrushFrameEditingCoordinator appears only in docs/tests as future rename target.
- BrushWorkspaceCacheInvalidationSink is not renamed.
- No BrushWorkspaceScreen or BrushWorkspaceView is reintroduced.
- No MainCanvasBrushHost.fixture() is reintroduced.
- No BrushCanvasFixture is reintroduced under lib.
```

If Dart/Flutter are unavailable, report that clearly.

## Acceptance criteria

```txt
1. docs/Brush_App_Integration_Decisions.md has Phase 206 section.
2. The current responsibility of BrushWorkspaceCoordinator is documented.
3. Future rename target BrushFrameEditingCoordinator is documented.
4. Architecture test exists and passes.
5. BrushWorkspaceCoordinator is not renamed yet.
6. BrushWorkspaceCacheInvalidationSink is not renamed.
7. Runtime behavior is unchanged.
8. MainCanvasBrushHost.fixture() is not reintroduced.
9. BrushCanvasFixture is not reintroduced under lib.
10. Debug controls are not reintroduced.
11. BrushWorkspaceScreen / BrushWorkspaceView are not reintroduced.
12. flutter analyze passes.
13. flutter test passes.
```

## Android Studio manual confirmation

This phase should not require meaningful manual UI validation because it is docs/test only.

Still, after merge and local checks, confirm briefly:

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
- whether Phase 206 docs were added
- whether architecture test was added
- whether BrushFrameEditingCoordinator is documented as future rename target
- whether BrushWorkspaceCoordinator runtime code was intentionally not renamed
- whether BrushWorkspaceCacheInvalidationSink was intentionally not renamed
- whether runtime behavior stayed unchanged
- whether deleted UI/debug controls were not reintroduced
- checks run and results
- rg search summary
- git status summary
```
