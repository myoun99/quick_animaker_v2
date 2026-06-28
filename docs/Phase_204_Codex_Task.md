# Phase 204 Codex Task

## Title

Rename and isolate brush canvas fixture helper

## Overall roadmap

The Brush integration roadmap is:

```txt id="gipawb"
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
   - Done enough for preview.
   - MainCanvasBrushHost can receive activeFrameKey or BrushEditorSelection.
   - HomePage passes active editor selection when available.

6. Fixture fallback separation
   - Done.
   - Production MainCanvasBrushHost no longer silently falls back to fixture frame-1.
   - Missing production selection renders an empty-selection placeholder.
   - MainCanvasBrushHost.fixture() remains explicit fixture/test helper path.

7. Fixture helper rename/isolation
   - This phase.
   - Rename BrushWorkspaceFixture to BrushCanvasFixture.
   - Make it clear this helper belongs to brush canvas fixture/test setup, not a retired workspace route.

8. Fixture helper removal
   - Later.
   - Remove MainCanvasBrushHost.fixture() if tests no longer need it.
   - Delete or move BrushCanvasFixture if production selection and test setup no longer depend on it.

9. BrushWorkspaceCoordinator naming cleanup
   - Later.
   - Consider renaming BrushWorkspaceCoordinator only after fixture cleanup is stable.
   - Do not include this rename in this phase.

10. Brush Host Preview promotion / production integration
   - Later.
   - Replace preview toggle with final canvas mode integration when ready.

11. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

12. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 204 should rename and isolate the remaining brush fixture helper.

Detailed steps:

```txt id="snv9dd"
1. Rename BrushWorkspaceFixture to BrushCanvasFixture.
2. Rename the file brush_workspace_fixture.dart to brush_canvas_fixture.dart.
3. Update all imports and references.
4. Keep MainCanvasBrushHost.fixture() for now.
5. Ensure MainCanvasBrushHost.fixture() is clearly documented as explicit fixture/test helper path.
6. Ensure production MainCanvasBrushHost constructor still does not use fixture fallback.
7. Keep missing production selection placeholder behavior.
8. Keep BrushCanvasPanel unchanged except import update if needed.
9. Do not rename BrushWorkspaceCoordinator in this phase.
10. Do not rename BrushWorkspaceCacheInvalidationSink in this phase unless absolutely required by imports.
11. Update tests to use BrushCanvasFixture.
12. Update docs with Phase 204.
```

## Product decision

The old "workspace" route is gone.

Therefore, the fixture helper should not continue to carry the old workspace naming.

Correct naming direction:

```txt id="rzhklx"
BrushWorkspaceFixture
→ BrushCanvasFixture
```

Reason:

```txt id="7igsxp"
- BrushWorkspaceScreen is gone.
- BrushWorkspaceView is gone.
- BrushCanvasPanel is the current reusable panel.
- MainCanvasBrushHost is the current host.
- The helper now exists only to provide brush canvas fixture data for tests and explicit fixture helper paths.
```

## Required work

### 1. Rename fixture file and class

Rename:

```txt id="dt8qjq"
lib/src/ui/brush/brush_workspace_fixture.dart
```

to:

```txt id="vl130i"
lib/src/ui/brush/brush_canvas_fixture.dart
```

Rename class:

```txt id="awxn9d"
BrushWorkspaceFixture
```

to:

```txt id="joh1w1"
BrushCanvasFixture
```

The class may keep the same static members for now, such as:

```txt id="xq8f6u"
projectId
trackId
cutId
layerId
canvasSize
createFrameKeys()
createCoordinator(...)
```

Do not change fixture values unless necessary.

### 2. Update imports and references

Update all references in:

```txt id="c5glw1"
lib/src/ui/brush/main_canvas_brush_host.dart
lib/src/ui/brush/brush_canvas_panel.dart
test/ui/brush_canvas_panel_test.dart
test/ui/main_canvas_brush_host_test.dart
test/ui/main_canvas_brush_embedding_test.dart
test/services/brush_workspace_coordinator_test.dart
any other file importing brush_workspace_fixture.dart
```

Search for:

```txt id="np0as3"
BrushWorkspaceFixture
brush_workspace_fixture.dart
```

Replace with:

```txt id="crqbqx"
BrushCanvasFixture
brush_canvas_fixture.dart
```

### 3. Keep MainCanvasBrushHost.fixture()

Do not delete:

```dart id="mi86ek"
MainCanvasBrushHost.fixture()
```

It should remain for this phase.

But make its meaning clear in comments:

```txt id="yofy23"
MainCanvasBrushHost.fixture() is an explicit fixture/test helper path.
It is not a production fallback.
```

Production constructor must still behave as Phase 203 established:

```txt id="9j2r7v"
MainCanvasBrushHost()
  with no activeFrameKey/selection
  -> empty-selection placeholder
  -> no BrushCanvasPanel
  -> no InteractiveBrushEditCanvasView
  -> no fixture frame-1
```

### 4. Keep BrushCanvasPanel simple

Update import only if needed.

Do not add:

```txt id="wba61v"
- Frame 1 / Frame 2 / Frame 3 debug buttons
- Undo / Redo debug buttons
- Debug Reset Session
- temporary Black / Red color buttons
- debug status text
- debug help text
- showDebugControls
```

`BrushCanvasPanel` must remain:

```txt id="kq55jr"
BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

### 5. Do not rename larger services yet

Do not rename these in this phase:

```txt id="bicb0t"
BrushWorkspaceCoordinator
BrushWorkspaceCacheInvalidationSink
```

Reason:

```txt id="ugbz72"
Those names touch larger service/test surfaces.
This phase should remain a fixture-helper rename/isolation PR.
```

Those can be considered in a later phase.

### 6. Tests

Update tests to compile with the new class/file name.

Required coverage must still pass:

```txt id="qp8iui"
- MainCanvasBrushHost() with no selection renders empty-selection placeholder.
- MainCanvasBrushHost() with no selection does not render fixture frame-1.
- MainCanvasBrushHost.fixture() explicitly renders fixture frame-1.
- MainCanvasBrushHost(activeFrameKey: frameReal) renders real frame and not fixture frame-1.
- Active frame rebuild still works.
- BrushCanvasPanel renders InteractiveBrushEditCanvasView.
- HomePage defaults to CanvasView.
- Brush Host Preview remains opt-in.
- HomePage Brush Host Preview uses real active editor selection when available.
- Brush Workspace button remains absent.
- Deleted debug controls remain absent.
```

If any tests refer to `BrushWorkspaceFixture`, update them to `BrushCanvasFixture`.

If any test name says "workspace fixture", rename it to "brush canvas fixture" or equivalent.

### 7. Documentation update

Update:

```txt id="rs6sxi"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="hut7zg"
## Phase 204 brush canvas fixture helper rename

Implemented:
- Renamed BrushWorkspaceFixture to BrushCanvasFixture.
- Renamed brush_workspace_fixture.dart to brush_canvas_fixture.dart.
- Updated imports and tests to use BrushCanvasFixture.
- MainCanvasBrushHost.fixture() remains the explicit fixture/test helper path.
- The production MainCanvasBrushHost constructor still does not silently use fixture fallback.
- Missing production selection still renders the empty-selection placeholder.
- BrushCanvasPanel remains an embedded canvas panel without debug controls.
- Existing CanvasView remains the default.
- Brush Host Preview remains opt-in.

Still out of scope:
- deleting BrushCanvasFixture
- deleting MainCanvasBrushHost.fixture()
- renaming BrushWorkspaceCoordinator
- renaming BrushWorkspaceCacheInvalidationSink
- replacing Brush Host Preview with production canvas mode
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
```

Add:

```txt id="l586ug"
Future cleanup:
After fixture usage is reduced further, remove MainCanvasBrushHost.fixture() and either delete BrushCanvasFixture or move it to a test-only helper location.
```

## Not allowed

Do not implement:

```txt id="du32j7"
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

```txt id="vx774p"
- BrushWorkspaceScreen
- Brush Workspace button
- brush-workspace-entry route
- BrushWorkspaceView class name
- Frame 1 / Frame 2 / Frame 3 debug buttons
- Debug Reset Session
- temporary Black / Red color buttons
- showDebugControls
```

Do not remove:

```txt id="kdlc1a"
- InteractiveBrushEditCanvasView
- BrushCanvasPanel
- MainCanvasBrushHost
- MainCanvasBrushHost.fixture()
- BrushWorkspaceCoordinator
- BrushWorkspaceCacheInvalidationSink
- BrushFrameEditSessionStore
- BrushFrameStore
- UnifiedUndoHistory
- BrushFrameKey
- CanvasView
```

## Required checks

Run:

```bash id="o7vmbc"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="b0xlnz"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="tn7bds"
git add lib test docs
git commit -m "Format phase 204 brush canvas fixture rename"
git push
```

Then rerun:

```bash id="jjy1wr"
flutter analyze
flutter test
git status
```

## Android Studio manual confirmation

After the PR is merged and local checks pass, run the app from Android Studio or with:

```bash id="nk9sqy"
flutter run
```

Confirm:

```txt id="mt1s27"
1. HomePage still opens normally.
2. Default canvas is still CanvasView.
3. Brush Host Preview toggle still exists.
4. Brush Host Preview ON still shows brush canvas when active editor selection exists.
5. Brush Host Preview does not silently render fixture frame-1 in production missing-selection path.
6. Frame 1 / Frame 2 / Frame 3 debug buttons are still gone.
7. Debug Reset Session is still gone.
8. Brush Workspace button is still absent.
9. Preview OFF returns to CanvasView.
10. Storyboard / Timeline basic behavior is not broken.
```

## Report back

Report:

```txt id="wk3dee"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- whether BrushWorkspaceFixture was renamed to BrushCanvasFixture
- whether the file was renamed to brush_canvas_fixture.dart
- whether all imports were updated
- whether MainCanvasBrushHost.fixture() remains explicit fixture/test helper path
- whether production MainCanvasBrushHost still avoids fixture fallback
- whether missing production selection still renders placeholder
- whether BrushCanvasPanel still renders InteractiveBrushEditCanvasView
- whether CanvasView remains default
- what remains before BrushCanvasFixture can be deleted or moved to test-only location
- checks run and results
- git status summary
```
