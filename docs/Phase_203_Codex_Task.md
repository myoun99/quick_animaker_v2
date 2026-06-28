# Phase 203 Codex Task

## Title

Separate MainCanvasBrushHost production path from fixture fallback

## Overall roadmap

The Brush integration roadmap is:

```txt id="mn68qo"
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView exists and remains the reusable drawing canvas.

2. Temporary BrushWorkspaceScreen route
   - Done and retired.
   - BrushWorkspaceScreen was removed.
   - The separate Brush Workspace route/button was removed.

3. Canvas panel naming cleanup
   - Done.
   - BrushWorkspaceView was renamed to BrushCanvasPanel.

4. Main canvas temporary controls cleanup
   - Done.
   - Debug controls were hidden first, then deleted completely.
   - BrushCanvasPanel now behaves as an embedded canvas panel.

5. Main canvas active editor selection bridge
   - Partially done.
   - MainCanvasBrushHost can receive activeFrameKey or BrushEditorSelection.
   - HomePage passes active editor selection when available.

6. Fixture fallback separation
   - This phase.
   - Production MainCanvasBrushHost must not silently fall back to BrushCanvasFixture.
   - Fixture behavior must be limited to explicit fixture/test helper paths.

7. Fixture removal / rename
   - Later.
   - Remove BrushCanvasFixture or move it to a test-only helper location after all production paths are selection-driven.

8. Brush Host Preview promotion / production integration
   - Later.
   - Replace debug preview toggle with final canvas mode integration when ready.

9. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

10. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 203 should separate the production/editor path from the fixture/test fallback path.

Detailed steps:

```txt id="xxswx3"
1. Keep BrushCanvasPanel simple.
2. Keep MainCanvasBrushHost as the main brush host.
3. Stop the default MainCanvasBrushHost constructor from silently using BrushCanvasFixture.
4. Keep MainCanvasBrushHost.fixture() as an explicit test/dev helper if still needed.
5. If activeFrameKey / selection is unavailable in the production constructor, show a safe empty placeholder instead of fixture frame-1.
6. Ensure HomePage Brush Host Preview still passes real active editor selection when available.
7. Add tests proving production path does not fall back to fixture frame-1.
8. Keep CanvasView as the default.
9. Keep Brush Host Preview opt-in.
10. Document that fixture fallback is no longer part of the production path.
```

## Product decision

Production brush canvas must be driven by real editor selection.

Correct production path:

```txt id="dkyciz"
HomePage / MainEditor
  -> active Project / Track / Cut / Layer / Frame selection
  -> MainCanvasBrushHost(selection or activeFrameKey)
  -> BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

Incorrect production path:

```txt id="f34k1q"
HomePage / MainEditor
  -> missing selection
  -> MainCanvasBrushHost silently creates fixture frame-1 / frame-2 / frame-3
```

That silent fixture fallback must stop.

Fixture use is allowed only when explicit:

```txt id="a6shpg"
MainCanvasBrushHost.fixture()
```

or direct test helper setup.

## Required work

### 1. Update MainCanvasBrushHost production behavior

Update:

```txt id="o5knp7"
lib/src/ui/brush/main_canvas_brush_host.dart
```

Current behavior likely falls back to:

```txt id="q8x9kk"
BrushCanvasFixture.createFrameKeys()
```

when `activeFrameKey` / `selection` is unavailable.

Change this so the default production constructor does not do that.

Preferred direction:

```dart id="x6r2vf"
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    this.activeFrameKey,
    this.selection,
    this.availableFrameKeys,
  }) : useFixtureFallback = false;

  MainCanvasBrushHost.fixture({super.key})
      : activeFrameKey = null,
        selection = null,
        availableFrameKeys = BrushCanvasFixture.createFrameKeys(),
        useFixtureFallback = true;

  final bool useFixtureFallback;
}
```

Exact naming can differ, but the behavior must be clear:

```txt id="twk6hl"
default constructor = production/editor path, no silent fixture fallback
fixture constructor = explicit fixture/test helper path
```

### 2. Add safe placeholder for missing production selection

When the default constructor has no resolved active frame key:

```txt id="z7oapt"
activeFrameKey == null
selection == null
```

and fixture fallback is not explicitly enabled, render a safe placeholder instead of `BrushCanvasPanel`.

Suggested stable key:

```txt id="vdcooj"
main-canvas-brush-host-empty-selection
```

Suggested text:

```txt id="nkiu44"
Select a layer and frame to edit with Brush Preview.
```

Keep it simple. This is not a production toolbar or final UX phase.

Do not crash.

Do not create fixture frame data.

### 3. Keep fixture helper explicit

`MainCanvasBrushHost.fixture()` may continue to use `BrushCanvasFixture`.

Allowed:

```txt id="c81mnz"
MainCanvasBrushHost.fixture()
  -> BrushCanvasFixture.createFrameKeys()
```

Not allowed:

```txt id="ytm3yp"
MainCanvasBrushHost()
  -> BrushCanvasFixture.createFrameKeys()
```

### 4. Keep BrushCanvasPanel unchanged except as needed

Do not reintroduce debug controls.

Do not add frame switching buttons.

Do not add reset buttons.

`BrushCanvasPanel` should remain:

```txt id="tec4vu"
BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

### 5. Update HomePage behavior

Update only if needed:

```txt id="ualsda"
lib/src/ui/home_page.dart
```

HomePage Brush Host Preview should continue to pass the active editor selection.

Expected behavior:

```txt id="q7x2v0"
- If active layer and selected frame exist:
  MainCanvasBrushHost(selection: _activeBrushEditorSelection)
  renders the real editor frame.

- If selection is unavailable:
  MainCanvasBrushHost renders the empty-selection placeholder.
  It must not silently render fixture frame-1.
```

Do not make Brush Host Preview the default.

Keep:

```txt id="ixro2v"
main-canvas-mode-toggle
main-canvas-legacy-host
main-canvas-brush-host-container
```

### 6. Tests

Update or add tests.

#### MainCanvasBrushHost production missing selection

Add test:

```txt id="g1pm61"
- pump MainCanvasBrushHost() with no activeFrameKey / selection
- expect main-canvas-brush-host-empty-selection exists
- expect BrushCanvasPanel findsNothing
- expect InteractiveBrushEditCanvasView findsNothing
- expect brush-canvas-frame-1 findsNothing
```

#### MainCanvasBrushHost fixture path

Keep explicit fixture test:

```txt id="ra8q26"
- pump MainCanvasBrushHost.fixture()
- expect BrushCanvasPanel exists
- expect InteractiveBrushEditCanvasView exists
- expect brush-canvas-frame-1 exists
```

This proves fixture behavior exists only when explicitly requested.

#### MainCanvasBrushHost production active frame

Keep or add:

```txt id="bh2x7r"
- pump MainCanvasBrushHost(activeFrameKey: frameReal)
- expect brush-canvas-frame-real exists
- expect brush-canvas-frame-1 findsNothing
```

#### Active frame rebuild

Keep existing behavior:

```txt id="wzhgxx"
- active frame A renders brush-canvas-frame-a
- rebuild with active frame B renders brush-canvas-frame-b
- frame A disappears
```

#### HomePage brush preview

Update:

```txt id="ra9j26"
test/ui/main_canvas_brush_embedding_test.dart
```

Required coverage:

```txt id="lmxs4m"
- HomePage defaults to CanvasView.
- Brush Host Preview remains opt-in.
- Brush Host Preview with real active editor selection renders real editor frame.
- Brush Host Preview does not silently render fixture frame-1.
- Brush Workspace button remains absent.
```

Only add missing-selection HomePage test if the test setup can naturally produce no active layer/frame without over-rewriting HomePage.

### 7. Documentation update

Update:

```txt id="hw95we"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="hdb4ea"
## Phase 203 MainCanvasBrushHost fixture fallback separation

Implemented:
- The production MainCanvasBrushHost constructor no longer silently falls back to BrushCanvasFixture.
- Missing production selection now renders a safe empty-selection placeholder.
- MainCanvasBrushHost.fixture() remains the explicit fixture/test helper path.
- HomePage Brush Host Preview continues to prefer real active editor selection.
- BrushCanvasPanel remains an embedded canvas panel without debug controls.
- Existing CanvasView remains the default.
- Brush Host Preview remains opt-in.

Still out of scope:
- deleting BrushCanvasFixture
- deleting MainCanvasBrushHost.fixture()
- replacing Brush Host Preview with production canvas mode
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
```

Add:

```txt id="shwncx"
Future cleanup:
After production selection is stable, remove BrushCanvasFixture or move it to a test-only helper location, and remove the explicit fixture helper path if no longer needed.
```

## Not allowed

Do not implement:

```txt id="axjkal"
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

```txt id="i60arg"
- BrushWorkspaceScreen
- Brush Workspace button
- brush-workspace-entry route
- BrushWorkspaceView class name
- Frame 1 / Frame 2 / Frame 3 debug buttons
- Debug Reset Session
- temporary Black / Red color buttons
```

Do not remove:

```txt id="muf0co"
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

```bash id="j7d1lu"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="lfqg0d"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="fbqw88"
git add lib test docs
git commit -m "Format phase 203 brush fixture fallback separation"
git push
```

Then rerun:

```bash id="gl27qn"
flutter analyze
flutter test
git status
```

## Android Studio manual confirmation

After the PR is merged and local checks pass, run the app from Android Studio or with:

```bash id="qqq66r"
flutter run
```

Confirm:

```txt id="e0fgs5"
1. HomePage still opens normally.
2. Default canvas is still CanvasView.
3. Brush Host Preview toggle still exists.
4. Brush Host Preview ON shows the brush canvas when active editor selection exists.
5. Brush Host Preview does not show fixture frame-1 when production selection is unavailable.
6. Frame 1 / Frame 2 / Frame 3 debug buttons are still gone.
7. Debug Reset Session is still gone.
8. Brush Workspace button is still absent.
9. Preview OFF returns to CanvasView.
10. Storyboard / Timeline basic behavior is not broken.
```

## Report back

Report:

```txt id="w1k81k"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- how production MainCanvasBrushHost now behaves without selection
- whether fixture fallback is limited to MainCanvasBrushHost.fixture()
- whether HomePage Brush Host Preview still uses real active editor selection
- whether BrushCanvasPanel still renders InteractiveBrushEditCanvasView
- whether CanvasView remains default
- what remains before BrushCanvasFixture can be deleted or moved to a test-only helper location
- checks run and results
- git status summary
```
