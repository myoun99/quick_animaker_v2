# Phase 197 Codex Task

## Title

Embed Brush host into the main editor canvas area

## Overall roadmap

The Brush integration roadmap is:

```txt id="mty4a6"
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView exists and remains the reusable drawing canvas.

2. App-level Brush workspace shell
   - Done.
   - BrushWorkspaceScreen, BrushWorkspaceCoordinator, BrushFrameEditSessionStore, BrushFrameStore, and UnifiedUndoHistory are connected.

3. Brush workspace stabilization
   - Done.
   - Debug reset semantics, cross-frame undo/redo tests, no-op commit safety tests, and improved status text exist.

4. Main canvas absorption preparation
   - Done.
   - BrushWorkspaceView was extracted.
   - BrushWorkspaceFixture was isolated.
   - MainCanvasBrushHost was added as a future HomePage integration point.

5. Main editor canvas embedding
   - This phase.
   - Add a safe debug/preview path for showing MainCanvasBrushHost inside the main editor canvas area.
   - Keep existing CanvasView available and default.

6. Real timeline/layer/frame selection integration
   - Later.
   - Replace temporary BrushWorkspaceFixture with real active Project / Track / Cut / Layer / Frame selection.

7. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

8. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 197 should connect the reusable brush host to the main editor surface conservatively.

Detailed steps:

```txt id="q2hvd5"
1. Find the existing HomePage / main editor canvas area where CanvasView is displayed.
2. Add a debug/preview toggle or mode switch that can show MainCanvasBrushHost in that area.
3. Keep the existing CanvasView as the default.
4. Do not delete CanvasView.
5. Do not remove BrushWorkspaceScreen yet.
6. Add tests proving the app can switch between existing CanvasView and MainCanvasBrushHost.
7. Document that this is a temporary bridge before real timeline/layer/frame selection integration.
```

## Current important clarification

`BrushWorkspaceScreen` is temporary.

The long-term direction is:

```txt id="knfmw8"
HomePage / MainEditor
  -> real timeline/layer/frame selection
  -> main canvas area
  -> brush editing host/view
  -> InteractiveBrushEditCanvasView
```

Users should eventually draw in the main editor canvas, not in a separate BrushWorkspaceScreen.

However, in this phase:

```txt id="l5au5g"
- Keep BrushWorkspaceScreen available as a debug/manual route.
- Keep MainCanvasBrushHost fixture-based for now.
- Do not wire real timeline/layer/frame selection yet.
```

## Core rules

Do not create a second canvas implementation.

The brush drawing path must still use:

```txt id="alxl7f"
InteractiveBrushEditCanvasView
```

Do not replace it with a new CustomPainter or unrelated canvas widget.

Do not rewrite HomePage.

Do not delete existing `CanvasView`.

## Required work

### 1. Add a main canvas debug brush mode

In the existing HomePage / main editor UI, add a conservative debug/preview control.

Possible UI labels:

```txt id="bnmlde"
Brush Host Preview
Show Brush Host
Canvas Mode: Legacy / Brush Host
```

Choose the option that fits the current UI best.

Behavior:

```txt id="spgw1v"
Default:
  existing CanvasView is shown.

When debug brush mode is enabled:
  MainCanvasBrushHost is shown in the main canvas area.

When disabled again:
  existing CanvasView returns.
```

The toggle must be clearly debug/preview, not a final production mode.

Suggested stable keys:

```txt id="v4tr6z"
main-canvas-mode-toggle
main-canvas-legacy-host
main-canvas-brush-host-container
```

If current HomePage structure makes these exact keys awkward, use equivalent stable keys and document them.

### 2. Keep existing Brush Workspace entry

Do not remove the existing `Brush Workspace` route/button yet.

It remains useful as a debug/manual route while the main canvas absorption is incomplete.

### 3. Do not connect real timeline/layer/frame selection yet

`MainCanvasBrushHost` may still use `BrushWorkspaceFixture`.

That is acceptable in this phase.

Do not pretend it is using real project selection yet.

Add clear comments if needed:

```txt id="c52wcu"
TODO Phase 198:
Replace BrushWorkspaceFixture with active editor Project / Track / Cut / Layer / Frame selection.
```

### 4. Preserve current editor behavior

The default app behavior should remain unchanged.

Existing HomePage / Storyboard / Timeline behavior must not regress.

Protected semantics remain:

```txt id="jy8j8v"
- StoryboardPanel semantics
- TimelinePanel semantics
- Layer ordering semantics
- Cut.duration semantics
- existing CanvasView default path
- BrushWorkspaceScreen debug path
- Brush smoke/dev canvas tests
```

### 5. Tests

Add or update tests.

Suggested tests:

#### HomePage defaults to legacy canvas

```txt id="l6mx9o"
- Pump QuickAnimakerApp or HomePage as existing tests do.
- Confirm existing CanvasView path is visible by default.
- Confirm MainCanvasBrushHost is not visible by default.
```

Use the most stable existing key/type available for `CanvasView`.

#### Toggle shows brush host

```txt id="apqx4p"
- Pump app/HomePage.
- Tap main canvas debug brush toggle.
- Confirm MainCanvasBrushHost is visible.
- Confirm BrushWorkspaceView is visible.
- Confirm InteractiveBrushEditCanvasView is present.
```

#### Toggle returns to legacy canvas

```txt id="m2fh08"
- Enable brush host mode.
- Disable it again.
- Confirm legacy CanvasView is visible again.
- Confirm MainCanvasBrushHost is no longer visible.
```

#### Brush Workspace route still exists

```txt id="u4lxl9"
- Existing Brush Workspace entry test should still pass.
- Opening it still shows BrushWorkspaceScreen and BrushWorkspaceView.
```

#### Protected panels still pass

Do not weaken existing tests.

Keep existing protected tests passing:

```txt id="k3r80q"
StoryboardPanel tests
TimelinePanel tests
BrushWorkspaceScreen tests
BrushWorkspaceView tests
MainCanvasBrushHost tests
brush smoke/dev canvas tests
```

## Suggested files

Likely changed files:

```txt id="eqwul2"
lib/src/ui/home_page.dart
test/ui/home_page_test.dart or equivalent existing HomePage/App test
test/ui/brush_workspace_screen_test.dart if needed
docs/Brush_App_Integration_Decisions.md
```

Only modify files actually needed.

## Documentation update

Update:

```txt id="iqdt2m"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="z20xjn"
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
```

## Not allowed

Do not implement:

```txt id="mzbb93"
- second canvas implementation
- HomePage rewrite
- deleting CanvasView
- deleting BrushWorkspaceScreen
- real timeline/layer/frame selection integration
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
- selection
- Provider/Riverpod/Bloc/ChangeNotifier
- global singleton app state
```

## Required checks

Run:

```bash id="u4ekry"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="eug2uo"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="a0g8yn"
git add lib test docs
git commit -m "Format phase 197 main canvas brush host embedding"
git push
```

Then rerun:

```bash id="lb7v1j"
flutter analyze
flutter test
git status
```

## Report back

Report:

```txt id="b8vmbf"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- how MainCanvasBrushHost is embedded
- whether existing CanvasView remains default
- whether BrushWorkspaceScreen remains available
- tests added/updated
- checks run and results
- git status summary
```
