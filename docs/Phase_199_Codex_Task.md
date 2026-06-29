# Phase 199 Codex Task

## Title

Retire BrushWorkspaceScreen route and migrate coverage to main canvas brush preview

## Overall roadmap

The Brush integration roadmap is:

```txt id="rz8w0t"
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView exists and remains the reusable drawing canvas.

2. Temporary BrushWorkspaceScreen route
   - Done earlier.
   - BrushWorkspaceScreen was useful as an app-level integration shell.
   - It is not a final product screen.

3. Brush workspace stabilization
   - Done.
   - Debug reset, cross-frame undo/redo, no-op commit safety, and status tests exist.

4. Main canvas absorption preparation
   - Done.
   - BrushWorkspaceView was extracted.
   - MainCanvasBrushHost was created.
   - BrushWorkspaceFixture was isolated.

5. Main editor canvas preview embedding
   - Done.
   - HomePage can show MainCanvasBrushHost through the Brush Host Preview toggle.
   - Existing CanvasView remains the default.

6. Active editor selection bridge
   - Done.
   - MainCanvasBrushHost can receive active editor selection / BrushFrameKey.
   - HomePage passes active editor selection when available.

7. Retire temporary BrushWorkspaceScreen route
   - This phase.
   - Remove the separate BrushWorkspaceScreen route/button.
   - Move tests and manual coverage to the main canvas brush preview path.

8. Main canvas brush UI cleanup / naming cleanup
   - Later.
   - Rename BrushWorkspaceView or split it into a less temporary component.
   - Remove fixture-only frame switching UI from the main canvas path.
   - Remove Debug Reset Session from production-facing preview.

9. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

10. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 199 should remove the separate BrushWorkspaceScreen route/button while preserving the main canvas brush preview path.

Detailed steps:

```txt id="bjwdxj"
1. Remove the Brush Workspace toolbar/button entry from HomePage.
2. Remove BrushWorkspaceScreen if it is no longer referenced.
3. Delete or migrate BrushWorkspaceScreen-specific tests.
4. Keep MainCanvasBrushHost and BrushWorkspaceView tests.
5. Keep Brush Host Preview toggle.
6. Keep existing CanvasView as the default.
7. Ensure main canvas brush preview still uses active editor selection when available.
8. Document that BrushWorkspaceScreen has been retired, but BrushWorkspaceView remains as an internal reusable component for now.
```

## Important product decision

BrushWorkspaceScreen must not remain as a permanent debug route.

Final product direction:

```txt id="xkn493"
HomePage / MainEditor
  -> main canvas area
  -> MainCanvasBrushHost or successor
  -> BrushWorkspaceView or renamed successor
  -> InteractiveBrushEditCanvasView
```

Separate route direction:

```txt id="x9j8pm"
BrushWorkspaceScreen
Brush Workspace button
temporary standalone brush route

=> remove
```

Do not confuse this with removing the reusable brush components.

## Required work

### 1. Remove Brush Workspace route/button

In HomePage, remove the toolbar/button entry that opens `BrushWorkspaceScreen`.

Likely item:

```txt id="nnl7cq"
Brush Workspace
brush-workspace-entry
```

Remove its import if unused.

Expected result:

```txt id="sw761l"
HomePage no longer has a separate Brush Workspace button.
Users can access brush preview only through the main canvas Brush Host Preview toggle.
```

### 2. Remove BrushWorkspaceScreen if unused

If `lib/src/ui/brush/brush_workspace_screen.dart` becomes unused after removing the route/button, delete it.

If there is still a legitimate reference, keep it only if required, but document why. Prefer deletion.

Do not delete:

```txt id="uppk5l"
lib/src/ui/brush/brush_workspace_view.dart
lib/src/ui/brush/main_canvas_brush_host.dart
lib/src/ui/brush/brush_workspace_fixture.dart
lib/src/ui/brush/brush_editor_selection.dart
```

### 3. Migrate tests away from BrushWorkspaceScreen

Delete or rewrite tests that directly depend on `BrushWorkspaceScreen`.

Likely test:

```txt id="l7zlmc"
test/ui/brush_workspace_screen_test.dart
```

If its coverage is still needed, move the assertions into:

```txt id="dr5iaq"
test/ui/main_canvas_brush_embedding_test.dart
test/ui/main_canvas_brush_host_test.dart
test/ui/brush_workspace_view_test.dart
```

Required coverage after migration:

```txt id="r9wv9v"
- HomePage still defaults to legacy CanvasView.
- Brush Host Preview toggle still shows MainCanvasBrushHost.
- MainCanvasBrushHost still renders BrushWorkspaceView.
- InteractiveBrushEditCanvasView is still present in brush preview.
- Active editor selection still reaches the brush host when available.
- There is no Brush Workspace route/button anymore.
```

### 4. Keep Brush Host Preview toggle

Do not remove the existing debug/preview toggle yet.

Keep:

```txt id="f3selu"
main-canvas-mode-toggle
main-canvas-legacy-host
main-canvas-brush-host-container
```

The default must remain legacy CanvasView.

Brush preview must remain opt-in.

### 5. Add negative test for removed route/button

Add or update a HomePage test proving:

```txt id="jmil82"
- find.byKey(ValueKey('brush-workspace-entry')) findsNothing
- find.text('Brush Workspace') findsNothing
```

Only do this if the text/key are not used elsewhere.

### 6. Keep fixture only as internal fallback/test helper

Do not delete `BrushWorkspaceFixture` in this phase.

It may still be used for:

```txt id="hsfnss"
- explicit MainCanvasBrushHost fixture helper (removed in Phase 205)
- tests
- fallback when active editor selection is unavailable
```

But the main HomePage brush preview path should continue to prefer active editor selection.

### 7. Documentation update

Update:

```txt id="jzugxn"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="k6hpia"
## Phase 199 BrushWorkspaceScreen route retirement

Implemented:
- Removed the separate BrushWorkspaceScreen route/button from HomePage.
- Retired or migrated BrushWorkspaceScreen-specific tests.
- Main canvas Brush Host Preview remains the only app-level brush preview path.
- Existing CanvasView remains the default.
- BrushWorkspaceView remains as an internal reusable brush editing component for now.

Still out of scope:
- renaming BrushWorkspaceView
- removing BrushWorkspaceFixture
- removing fixture fallback
- making Brush Host Preview the default
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
- full timeline/layer/frame production selection replacement
```

Also add:

```txt id="u6ux81"
Future cleanup:
Rename BrushWorkspaceView to a less temporary name or split it into a canvas-only brush editor body after the main canvas path is stable.
```

## Not allowed

Do not implement:

```txt id="y9yx02"
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

Do not remove:

```txt id="nuz79o"
- InteractiveBrushEditCanvasView
- BrushWorkspaceView
- MainCanvasBrushHost
- BrushWorkspaceCoordinator
- BrushFrameEditSessionStore
- BrushFrameStore
- UnifiedUndoHistory
- CanvasView
```

## Required checks

Run:

```bash id="c5g00o"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="rbt47p"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="ki4juv"
git add lib test docs
git commit -m "Format phase 199 brush workspace route retirement"
git push
```

Then rerun:

```bash id="egmdbe"
flutter analyze
flutter test
git status
```

## Report back

Report:

```txt id="lykdct"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- whether BrushWorkspaceScreen was deleted
- whether Brush Workspace button/route was removed
- which tests were deleted/migrated
- whether MainCanvasBrushHost preview still works
- whether CanvasView remains default
- what remains before BrushWorkspaceView/fixture cleanup
- checks run and results
- git status summary
```
