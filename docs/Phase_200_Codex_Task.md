# Phase 200 Codex Task

## Title

Rename BrushWorkspaceView into BrushCanvasPanel and clean up workspace naming

## Overall roadmap

The Brush integration roadmap is:

```txt id="mgwey6"
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView exists and remains the reusable drawing canvas.

2. Temporary BrushWorkspaceScreen route
   - Done and retired.
   - BrushWorkspaceScreen was removed in Phase 199.
   - The separate Brush Workspace route/button was removed.

3. Main canvas absorption preparation
   - Done.
   - BrushWorkspaceView was extracted from the old route-level screen.
   - MainCanvasBrushHost was created.
   - BrushWorkspaceFixture remains as a temporary fallback/test helper.

4. Main editor canvas preview embedding
   - Done.
   - HomePage can show MainCanvasBrushHost through Brush Host Preview.
   - Existing CanvasView remains the default.

5. Active editor selection bridge
   - Done.
   - MainCanvasBrushHost can receive active editor selection / BrushFrameKey.
   - HomePage passes active editor selection when available.

6. Canvas panel naming cleanup
   - This phase.
   - Rename BrushWorkspaceView to a canvas-panel-oriented component.
   - Remove route/workspace naming from the reusable brush UI layer.
   - Prepare for removing temporary frame-switch/debug controls later.

7. Temporary fixture/debug UI removal
   - Later.
   - Remove fixture-only Frame 1 / Frame 2 / Frame 3 UI from the main canvas path.
   - Remove or replace Debug Reset Session.
   - Replace temporary controls with production brush/editor controls.

8. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

9. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 200 should cleanly move the reusable brush view away from “workspace” naming and toward “canvas panel” naming.

Detailed steps:

```txt id="nkguth"
1. Rename BrushWorkspaceView to BrushCanvasPanel.
2. Rename the source file and tests accordingly.
3. Update MainCanvasBrushHost to render BrushCanvasPanel.
4. Keep the existing behavior unchanged.
5. Keep Brush Host Preview opt-in.
6. Keep existing CanvasView as the default.
7. Keep BrushWorkspaceFixture for now, but document it as temporary.
8. Add or update tests so no app-level route/view depends on BrushWorkspaceView.
9. Update docs to record that workspace route naming has been retired.
```

## Product decision

The standalone Brush workspace concept is retired.

Do not reintroduce:

```txt id="xvjkn8"
- BrushWorkspaceScreen
- Brush Workspace button
- standalone Brush Workspace route
```

The reusable brush UI should now be treated as part of the main canvas panel path.

Target direction:

```txt id="eh8g8w"
HomePage / MainEditor
  -> main canvas area
  -> MainCanvasBrushHost or successor
  -> BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

`BrushCanvasPanel` is not necessarily the final production name forever, but it is much closer to the target than `BrushWorkspaceView`.

## Required work

### 1. Rename BrushWorkspaceView

Rename:

```txt id="sivx9l"
lib/src/ui/brush/brush_workspace_view.dart
```

to:

```txt id="egucw0"
lib/src/ui/brush/brush_canvas_panel.dart
```

Rename class:

```txt id="f8f8lv"
BrushWorkspaceView
```

to:

```txt id="b445bx"
BrushCanvasPanel
```

Use a stable root key:

```txt id="lamx6y"
brush-canvas-panel
```

Do not keep the old `brush-workspace-view` key unless a compatibility test requires it. Prefer updating tests to the new key.

### 2. Update MainCanvasBrushHost

Update:

```txt id="ag9xfl"
lib/src/ui/brush/main_canvas_brush_host.dart
```

So it imports and renders:

```dart id="wkz1se"
BrushCanvasPanel
```

instead of:

```dart id="lfslr2"
BrushWorkspaceView
```

Behavior should remain the same:

```txt id="js4df8"
- activeFrameKey / selection support remains
- availableFrameKeys support remains
- fixture fallback remains
- cache invalidation sink remains
- InteractiveBrushEditCanvasView remains the actual drawing canvas
```

### 3. Rename tests

Rename or replace:

```txt id="jji57q"
test/ui/brush_workspace_view_test.dart
```

with:

```txt id="xi0mhv"
test/ui/brush_canvas_panel_test.dart
```

Update all references:

```txt id="gm1t7x"
BrushWorkspaceView -> BrushCanvasPanel
brush-workspace-view -> brush-canvas-panel
```

Keep existing coverage:

```txt id="ng65dk"
- direct pump of reusable brush panel
- Frame 1 / Frame 2 temporary state isolation
- Debug Reset Session behavior remains session-only
```

Do not weaken tests.

### 4. Update main canvas embedding tests

Update tests such as:

```txt id="pxo8se"
test/ui/main_canvas_brush_embedding_test.dart
test/ui/main_canvas_brush_host_test.dart
```

Expected updates:

```txt id="hfs86q"
- find.byType(BrushCanvasPanel)
- no references to BrushWorkspaceView
- no references to BrushWorkspaceScreen
- main canvas preview still renders InteractiveBrushEditCanvasView
- HomePage still defaults to CanvasView
- Brush Host Preview remains opt-in
```

### 5. Remove route/workspace naming from reusable UI comments

Update comments/docs in the brush UI files.

Allowed:

```txt id="mpmcp9"
BrushWorkspaceFixture
```

because it is explicitly temporary and still used as fixture/fallback.

Avoid new references to:

```txt id="k9jmhr"
BrushWorkspaceScreen
Brush Workspace route
BrushWorkspaceView
```

except in historical documentation notes.

### 6. Keep temporary controls for now

Do not remove these yet:

```txt id="q8xrn5"
- Frame 1 / Frame 2 / Frame 3 temporary buttons
- Debug Reset Session
- Black / Red color buttons
```

They may still exist inside `BrushCanvasPanel`.

However, add or keep comments making clear that these are temporary panel controls and not final production toolbar design.

Actual removal/replacement belongs to a later phase.

### 7. Documentation update

Update:

```txt id="ms1fck"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="u81s1u"
## Phase 200 Brush canvas panel naming cleanup

Implemented:
- Renamed BrushWorkspaceView to BrushCanvasPanel.
- Removed workspace naming from the reusable brush UI component.
- MainCanvasBrushHost now renders BrushCanvasPanel.
- BrushWorkspaceScreen and the separate Brush Workspace route remain deleted.
- Existing CanvasView remains the default.
- Brush Host Preview remains opt-in.

Still out of scope:
- removing BrushWorkspaceFixture
- removing fixture fallback
- removing Frame 1 / Frame 2 / Frame 3 temporary controls
- removing Debug Reset Session
- making Brush Host Preview the default
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
```

Also add:

```txt id="r2j8cf"
Future cleanup:
Remove or replace temporary panel controls after the main canvas brush path is stable.
```

## Not allowed

Do not implement:

```txt id="j7601k"
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

```txt id="w9sqba"
- BrushWorkspaceScreen
- Brush Workspace button
- brush-workspace-entry route
```

Do not remove:

```txt id="u4gv5n"
- InteractiveBrushEditCanvasView
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

```bash id="enqj3h"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="nwfkc6"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="p00748"
git add lib test docs
git commit -m "Format phase 200 brush canvas panel rename"
git push
```

Then rerun:

```bash id="c8wxje"
flutter analyze
flutter test
git status
```

## Report back

Report:

```txt id="onpl89"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- whether BrushWorkspaceView was fully renamed
- whether BrushCanvasPanel is now used by MainCanvasBrushHost
- whether BrushWorkspaceScreen/button remain deleted
- which tests were renamed/updated
- whether CanvasView remains default
- what temporary panel controls still remain
- checks run and results
- git status summary
```
