# Phase 202 Codex Task

## Title

Delete temporary BrushCanvasPanel debug controls

## Overall roadmap

The Brush integration roadmap is:

```txt
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView exists and remains the reusable drawing canvas.

2. Temporary BrushWorkspaceScreen route
   - Done and retired.
   - BrushWorkspaceScreen was removed.
   - The separate Brush Workspace route/button was removed.

3. Main canvas absorption preparation
   - Done.
   - MainCanvasBrushHost exists.
   - BrushCanvasFixture remains as a temporary fallback/test helper.

4. Main editor canvas preview embedding
   - Done.
   - HomePage can show MainCanvasBrushHost through Brush Host Preview.
   - Existing CanvasView remains the default.

5. Active editor selection bridge
   - Done.
   - MainCanvasBrushHost can receive active editor selection / BrushFrameKey.
   - HomePage passes active editor selection when available.

6. Canvas panel naming cleanup
   - Done.
   - BrushWorkspaceView was renamed to BrushCanvasPanel.
   - MainCanvasBrushHost now renders BrushCanvasPanel.

7. Main canvas temporary control hiding
   - Done.
   - BrushCanvasPanel has embedded/default mode.
   - Temporary debug controls are hidden from the main canvas path.

8. Delete temporary debug controls
   - This phase.
   - Remove Frame 1 / Frame 2 / Frame 3 debug buttons, Debug Reset Session, Undo/Redo debug buttons, temporary color buttons, status text, help text, and showDebugControls.

9. Fixture fallback reduction
   - Later.
   - Remove BrushCanvasFixture or move it to a test-only helper location after active editor selection path is stable.

10. Brush Host Preview promotion / production integration
   - Later.
   - Replace debug preview toggle with final canvas mode integration when ready.

11. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

12. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 202 should remove the temporary debug controls from `BrushCanvasPanel` entirely.

Detailed steps:

```txt
1. Remove showDebugControls from BrushCanvasPanel.
2. Remove Frame 1 / Frame 2 / Frame 3 debug buttons.
3. Remove Undo / Redo debug buttons.
4. Remove Debug Reset Session button and help text.
5. Remove Black / Red temporary color buttons.
6. Remove active-frame debug label and command-count status text.
7. Remove the private _ColorButton widget if it becomes unused.
8. Keep InteractiveBrushEditCanvasView as the actual drawing canvas.
9. Keep MainCanvasBrushHost rendering BrushCanvasPanel.
10. Move any remaining test coverage away from temporary UI buttons into coordinator / host / panel tests.
11. Keep CanvasView as the default HomePage path.
12. Keep Brush Host Preview opt-in.
```

## Product decision

Temporary debug UI must not remain, even for test/development use.

Previous phase hid the controls from the main canvas path.
This phase deletes the controls from the reusable panel itself.

Target structure:

```txt
HomePage / MainEditor
  -> main canvas area
  -> MainCanvasBrushHost
  -> BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

`BrushCanvasPanel` should behave like a canvas panel, not like a debug workspace.

## Required work

### 1. Update BrushCanvasPanel

Update:

```txt
lib/src/ui/brush/brush_canvas_panel.dart
```

Remove:

```txt
- showDebugControls property
- showDebugControls constructor argument
- all conditional debug-control UI
- Frame 1 / Frame 2 / Frame 3 buttons
- Undo / Redo debug buttons
- Debug Reset Session button
- Debug Reset Session help text
- Black / Red temporary color buttons
- active-frame debug label
- command count status text
- _ColorButton class if unused
```

After this phase, `BrushCanvasPanel` should primarily render:

```txt
InteractiveBrushEditCanvasView
```

It may keep layout wrappers such as padding, border, and sizing.

Do not remove the actual brush canvas.

### 2. Update MainCanvasBrushHost

Update:

```txt
lib/src/ui/brush/main_canvas_brush_host.dart
```

Remove the `showDebugControls: false` argument because it should no longer exist.

MainCanvasBrushHost must continue to support:

```txt
- activeFrameKey
- selection
- availableFrameKeys
- fixture fallback when no editor selection exists
- cache invalidation sink
```

MainCanvasBrushHost must still render:

```txt
BrushCanvasPanel
```

### 3. Update tests

Update:

```txt
test/ui/brush_canvas_panel_test.dart
test/ui/main_canvas_brush_host_test.dart
test/ui/main_canvas_brush_embedding_test.dart
```

Remove tests that depend on deleted debug UI.

Do not simply delete all coverage. Move important coverage to better layers.

#### Replace frame switching UI coverage

Old coverage:

```txt
tap Frame 1 / Frame 2 / Frame 3 buttons
```

New coverage should use direct host/coordinator state:

```txt
- MainCanvasBrushHost receives activeFrameKey A.
- Rebuild MainCanvasBrushHost with activeFrameKey B.
- BrushCanvasPanel / InteractiveBrushEditCanvasView updates to frame B.
- Rebuild back to activeFrameKey A.
- Frame A key is restored.
```

Use the existing `brush-canvas-<frameId>` key if useful.

#### Replace Debug Reset Session UI coverage

Old coverage:

```txt
tap Debug Reset Session button
```

New coverage should live in service/coordinator tests if not already covered:

```txt
- BrushFrameEditSessionStore.reset(activeKey) resets only the interactive session.
- It does not clear BrushFrameStore commands.
- It does not clear UnifiedUndoHistory.
```

If this is already covered elsewhere, do not duplicate excessively.

#### Replace color button UI coverage

Old coverage:

```txt
tap Black / Red buttons
```

New coverage:

```txt
- BrushCanvasPanel accepts initialInputSettings.
- InteractiveBrushEditCanvasView receives those input settings.
```

If direct widget inspection is difficult, keep a minimal smoke test that the panel renders with a custom `initialInputSettings`.

#### Keep embedded canvas coverage

Required test coverage after this phase:

```txt
- BrushCanvasPanel renders InteractiveBrushEditCanvasView.
- BrushCanvasPanel no longer renders Frame 1 / Frame 2 / Frame 3.
- BrushCanvasPanel no longer renders Debug Reset Session.
- BrushCanvasPanel no longer renders Black / Red temporary color buttons.
- MainCanvasBrushHost renders BrushCanvasPanel.
- MainCanvasBrushHost renders InteractiveBrushEditCanvasView.
- HomePage defaults to CanvasView.
- Brush Host Preview remains opt-in.
- Brush Host Preview renders MainCanvasBrushHost and BrushCanvasPanel.
- Brush Workspace button remains absent.
```

### 4. Keep BrushCanvasFixture for now

Do not delete:

```txt
lib/src/ui/brush/brush_canvas_fixture.dart
```

It may still be used for:

```txt
- MainCanvasBrushHost.fixture()
- tests
- fallback when active editor selection is unavailable
```

Fixture fallback removal is a later phase.

### 5. Documentation update

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt
## Phase 202 temporary brush debug controls deletion

Implemented:
- Removed showDebugControls from BrushCanvasPanel.
- Removed Frame 1 / Frame 2 / Frame 3 debug buttons.
- Removed Undo / Redo debug buttons.
- Removed Debug Reset Session from BrushCanvasPanel.
- Removed temporary Black / Red color buttons.
- Removed debug status/help text from BrushCanvasPanel.
- BrushCanvasPanel now behaves as an embedded canvas panel.
- MainCanvasBrushHost still renders BrushCanvasPanel.
- Existing CanvasView remains the default.
- Brush Host Preview remains opt-in.

Still out of scope:
- deleting BrushCanvasFixture
- deleting fixture fallback
- replacing Brush Host Preview with production canvas mode
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
```

Add:

```txt
Future cleanup:
Move remaining fixture fallback and preview-mode behavior toward real editor selection and production canvas integration.
```

## Not allowed

Do not implement:

```txt
- second canvas implementation
- deleting CanvasView
- making Brush Host Preview default
- full HomePage rewrite
- timeline rewrite
- layer panel rewrite
- storyboard drawing
- save/load
- renderer cache
- playback cache
- actual deferred bitmap baking
- production Clear Frame
- onion skin
- pressure
- smoothing
- eraser
- selection tools
- Provider/Riverpod/Bloc/ChangeNotifier
- global singleton app state
```

Do not reintroduce:

```txt
- BrushWorkspaceScreen
- Brush Workspace button
- brush-workspace-entry route
- BrushWorkspaceView class name
```

Do not remove:

```txt
- InteractiveBrushEditCanvasView
- BrushCanvasPanel
- MainCanvasBrushHost
- BrushWorkspaceCoordinator
- BrushFrameEditSessionStore
- BrushFrameStore
- UnifiedUndoHistory
- BrushFrameKey
- CanvasView
```

## Required checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash
git add lib test docs
git commit -m "Format phase 202 brush debug controls deletion"
git push
```

Then rerun:

```bash
flutter analyze
flutter test
git status
```

## Android Studio manual confirmation

After the PR is merged and local checks pass, run the app from Android Studio or with:

```bash
flutter run
```

Confirm:

```txt
1. HomePage still opens normally.
2. Default canvas is still CanvasView.
3. Brush Host Preview toggle still exists.
4. Brush Host Preview ON shows the brush canvas.
5. Frame 1 / Frame 2 / Frame 3 buttons are gone.
6. Debug Reset Session is gone.
7. Black / Red temporary buttons are gone.
8. Brush Workspace button is still absent.
9. Preview OFF returns to CanvasView.
10. Storyboard / Timeline basic behavior is not broken.
```

## Report back

Report:

```txt
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- whether showDebugControls was removed
- which debug controls were deleted
- which tests were removed or migrated
- whether BrushCanvasPanel still renders InteractiveBrushEditCanvasView
- whether MainCanvasBrushHost still works
- whether CanvasView remains default
- what remains before fixture fallback can be deleted
- checks run and results
- git status summary
```
