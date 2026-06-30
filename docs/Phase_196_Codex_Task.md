# Phase 196 Codex Task

## Title

Prepare Brush workspace absorption into the main canvas

## Overall roadmap

The current Brush work is moving through these stages:

```txt
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView and related bitmap/session operations exist.

2. App-level Brush workspace shell
   - Done in Phase 194.
   - BrushWorkspaceScreen, BrushWorkspaceCoordinator, BrushFrameEditSessionStore, frame switching, and app entry exist.

3. Brush workspace stabilization
   - Done in Phase 195.
   - Debug reset semantics, cross-frame undo/redo tests, no-op commit safety tests, and better status text exist.

4. Main canvas absorption preparation
   - This phase.
   - Extract reusable brush editing UI/state bridge from BrushWorkspaceScreen.
   - Prepare the brush canvas to be embedded into the real main editor canvas area.

5. Real timeline/layer/frame selection integration
   - Next phase or later.
   - Replace temporary Frame 1 / Frame 2 / Frame 3 fixture selection with real editor selection.

6. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color UI, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

7. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 196 should not delete `BrushWorkspaceScreen` yet.

Instead, it should make it clear that `BrushWorkspaceScreen` is only a temporary/debug wrapper and move the reusable brush editing body into a component that can later be mounted in the main canvas area.

Detailed steps:

```txt
1. Extract reusable brush editing component from BrushWorkspaceScreen.
2. Keep BrushWorkspaceScreen as a debug/manual wrapper around that component.
3. Add a main-canvas-oriented integration point or host component.
4. Avoid duplicating canvas implementations.
5. Preserve all Phase 194/195 tests.
6. Add tests proving the reusable component can be used outside BrushWorkspaceScreen.
7. Document that BrushWorkspaceScreen is temporary and will be absorbed into the main editor canvas.
```

## Current important clarification

`BrushWorkspaceScreen` is not the final product screen.

It is an intermediate app-level integration shell.

Final direction:

```txt
HomePage / MainEditor
  -> real timeline/layer/frame selection
  -> main canvas area
  -> reusable brush editing component
  -> InteractiveBrushEditCanvasView
```

The final app should not require users to open a separate `BrushWorkspaceScreen` just to draw.

## Core rule

Do not create a second canvas implementation.

The reusable drawing component must continue to use the existing:

```txt
InteractiveBrushEditCanvasView
```

Do not replace it with a new CustomPainter or unrelated canvas widget.

## Required work

### 1. Extract reusable brush editing component

Create a reusable widget that contains the brush editing UI/body currently inside `BrushWorkspaceScreen`.

Suggested file:

```txt
lib/src/ui/brush/brush_workspace_view.dart
```

Possible name alternatives are acceptable if clearer:

```txt
BrushWorkspaceView
BrushEditorWorkspaceView
BrushEditingSurface
BrushMainCanvasBridge
```

The component should own or receive:

```txt
BrushWorkspaceCoordinator
List<BrushFrameKey> availableFrameKeys for the temporary fixture mode
BrushEditCanvasInputSettings
CacheInvalidationSink
```

The goal is to separate:

```txt
BrushWorkspaceScreen:
  route/scaffold/debug wrapper

BrushWorkspaceView:
  reusable editor body that can later be mounted in HomePage's main canvas area
```

### 2. Keep BrushWorkspaceScreen as debug/manual wrapper

`BrushWorkspaceScreen` should remain available for now.

But its role should be clearly debug/manual.

It should mostly wrap the reusable view.

Expected structure:

```txt
BrushWorkspaceScreen
  Scaffold
    AppBar(title: Brush Workspace)
    BrushWorkspaceView(...)
```

Do not delete current tests.

Update tests if needed, but do not weaken them.

### 3. Add a main-canvas-oriented integration point

Add a small integration point that prepares for mounting brush editing inside the main editor canvas area.

Choose the safest option based on current code structure.

Preferred approach:

```txt
Create a reusable widget such as:

lib/src/ui/brush/main_canvas_brush_host.dart

MainCanvasBrushHost:
  - receives or creates the same temporary fixture coordinator for now
  - displays the reusable BrushWorkspaceView or a canvas-only subset
  - is designed to be embedded into HomePage's canvas area later
```

If HomePage has a safe canvas area abstraction, you may add a conservative debug entry/toggle that shows the brush host in or near the main canvas area.

If HomePage integration is risky, do not force it. Instead, create the host component and test it independently.

Do not rewrite HomePage.

Do not remove existing CanvasView yet.

### 4. Make temporary fixture explicit

Any temporary Project / Track / Cut / Layer / Frame IDs should be moved into a clearly named fixture/helper.

Suggested file:

```txt
lib/src/ui/brush/brush_workspace_fixture.dart
```

The fixture should be clearly marked as temporary.

It may include:

```txt
ProjectId
TrackId
CutId
LayerId
FrameId frame-1
FrameId frame-2
FrameId frame-3
CanvasSize
List<BrushFrameKey>
```

Do not confuse this fixture with real project state.

Do not store drawing payload inside Frame.

### 5. Preserve coordinator/session architecture

Keep these rules:

```txt
- BrushWorkspaceCoordinator coordinates app-level brush state.
- BrushFrameEditSessionStore maps BrushFrameKey -> BrushEditSessionState.
- BrushFrameStore stores paint command metadata/state.
- UnifiedUndoHistory owns global undo/redo order.
- BrushFrameStore does not decide undo/redo order.
- Frame model remains lightweight.
```

### 6. Add tests

Add or update tests for:

#### Reusable view works outside BrushWorkspaceScreen

```txt
- Pump BrushWorkspaceView directly.
- Draw on Frame 1.
- Switch to Frame 2.
- Frame 2 starts empty.
- Switch back to Frame 1.
- Frame 1 state remains.
```

#### BrushWorkspaceScreen wraps reusable view

```txt
- Pump BrushWorkspaceScreen.
- Confirm it shows brush-workspace-screen key.
- Confirm it contains the reusable view key.
```

#### Main canvas host exists

If you add `MainCanvasBrushHost`, test:

```txt
- Pump MainCanvasBrushHost.
- It contains InteractiveBrushEditCanvasView through the reusable brush view.
- It does not depend on BrushWorkspaceScreen.
```

#### Fixture is explicit

Test if practical:

```txt
- fixture creates three BrushFrameKeys.
- all keys share same project/track/cut/layer IDs.
- frame IDs are frame-1/frame-2/frame-3.
```

#### Existing tests remain valid

Keep existing tests passing:

```txt
test/services/brush_workspace_coordinator_test.dart
test/ui/brush_workspace_screen_test.dart
existing brush smoke/dev canvas tests
StoryboardPanel tests
TimelinePanel tests
```

Do not weaken protected tests.

## Documentation update

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add a section:

```txt
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
```

## Not allowed

Do not implement:

```txt
- a second canvas implementation
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
- selection
- Provider/Riverpod/Bloc/ChangeNotifier
- global singleton app state
```

Do not remove:

```txt
- InteractiveBrushEditCanvasView
- BrushCanvasSmokeScreen tests
- BrushWorkspaceScreen tests
- StoryboardPanel tests
- TimelinePanel tests
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

## Important post-check rule for local workflow

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
git commit -m "Format phase 196 brush main canvas preparation"
git push
```

## Report back

Report:

```txt
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- whether BrushWorkspaceScreen is now only a wrapper/debug screen
- reusable brush view summary
- fixture/helper summary
- main-canvas host/integration point summary
- tests added/updated
- checks run and results
- git status summary
```
