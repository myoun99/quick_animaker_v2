# Phase 205 Codex Task

## Title

Move brush canvas fixture out of production code

## 1. 전체 로드맵

The Brush integration roadmap is:

```txt
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

7. Fixture helper rename/isolation
   - Done.
   - BrushWorkspaceFixture was renamed to BrushCanvasFixture.
   - Workspace naming was removed from the fixture helper.

8. Move fixture out of production code
   - This phase.
   - Remove BrushCanvasFixture from lib.
   - Move BrushCanvasFixture to test helper space.
   - Delete MainCanvasBrushHost.fixture().
   - Production code must no longer import or depend on BrushCanvasFixture.

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

## 2. 이번 Phase 세부 로드맵

Phase 205 should remove production dependency on the brush canvas fixture helper.

Detailed steps:

```txt
1. Add a production brush canvas default policy.
2. Move BrushCanvasFixture out of lib into test helper space.
3. Delete lib/src/ui/brush/brush_canvas_fixture.dart.
4. Delete MainCanvasBrushHost.fixture().
5. Update tests to create fixture frame keys directly from the test helper.
6. Keep production MainCanvasBrushHost selection-driven.
7. Keep missing production selection placeholder behavior.
8. Keep BrushCanvasPanel simple.
9. Do not rename BrushWorkspaceCoordinator in this phase.
10. Do not rename BrushWorkspaceCacheInvalidationSink in this phase.
11. Update docs with Phase 205.
12. Verify there are no production imports of BrushCanvasFixture.
```

## 3. 이번 Phase 작업 범위

### In scope

```txt
- Add production brush canvas default size/policy.
- Move BrushCanvasFixture to test helper location.
- Remove lib/src/ui/brush/brush_canvas_fixture.dart.
- Remove MainCanvasBrushHost.fixture().
- Update tests that used MainCanvasBrushHost.fixture().
- Update tests that imported lib/src/ui/brush/brush_canvas_fixture.dart.
- Update docs/Brush_App_Integration_Decisions.md.
```

### Out of scope

```txt
- Renaming BrushWorkspaceCoordinator.
- Renaming BrushWorkspaceCacheInvalidationSink.
- Replacing Brush Host Preview with production canvas mode.
- Making Brush Host Preview default.
- Production brush toolbar.
- Production Clear Frame command.
- Save/load.
- Renderer/playback cache.
- Actual deferred bitmap baking.
- Timeline rewrite.
- Layer panel rewrite.
- Storyboard drawing.
- Onion skin.
- Pressure.
- Smoothing.
- Eraser.
- Selection tools.
- Provider/Riverpod/Bloc/ChangeNotifier/global singleton state.
```

## 4. 구현 지시

### 4-1. Add production brush canvas defaults

Create:

```txt
lib/src/ui/brush/brush_canvas_defaults.dart
```

Suggested content:

```dart
import '../../models/canvas_size.dart';

class BrushCanvasDefaults {
  const BrushCanvasDefaults._();

  static const canvasSize = CanvasSize(width: 1280, height: 720);
}
```

This file is production code and must not contain fixture/test language.

It represents a temporary production default size policy for embedded brush canvas preview paths.

### 4-2. Update BrushCanvasPanel to use production defaults

Update:

```txt
lib/src/ui/brush/brush_canvas_panel.dart
```

Replace:

```dart
import 'brush_canvas_fixture.dart';
```

with:

```dart
import 'brush_canvas_defaults.dart';
```

Replace default canvas size:

```dart
this.canvasSize = BrushCanvasFixture.canvasSize,
```

with:

```dart
this.canvasSize = BrushCanvasDefaults.canvasSize,
```

Do not change BrushCanvasPanel behavior.

It must remain:

```txt
BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

Do not reintroduce:

```txt
- showDebugControls
- Frame 1 / Frame 2 / Frame 3 buttons
- Undo / Redo debug buttons
- Debug Reset Session
- temporary Black / Red color buttons
- debug status text
- debug help text
```

### 4-3. Update MainCanvasBrushHost to remove fixture constructor

Update:

```txt
lib/src/ui/brush/main_canvas_brush_host.dart
```

Remove import:

```dart
import 'brush_canvas_fixture.dart';
```

Add if needed:

```dart
import 'brush_canvas_defaults.dart';
```

Delete:

```dart
MainCanvasBrushHost.fixture(...)
```

Delete:

```dart
useFixtureFallback
```

or any production bool that exists only to support the old fixture constructor.

Production behavior must be:

```txt
MainCanvasBrushHost()
  activeFrameKey == null
  selection == null
  availableFrameKeys == null or empty
  -> render empty-selection placeholder
  -> no BrushCanvasPanel
  -> no InteractiveBrushEditCanvasView
  -> no brush-canvas-frame-1
```

If `availableFrameKeys` is passed without `activeFrameKey` or `selection`, do not silently pick the first frame for production unless the current code already clearly treats that as an explicit active frame. Preferred safe behavior:

```txt
no activeFrameKey / selection
-> empty-selection placeholder
```

Production code should only render a brush canvas when a real active key can be resolved from:

```txt
activeFrameKey
or
selection.toBrushFrameKey()
```

Keep placeholder key:

```txt
main-canvas-brush-host-empty-selection
```

Keep placeholder text:

```txt
Select a layer and frame to edit with Brush Preview.
```

### 4-4. Move BrushCanvasFixture to test helper

Move fixture helper from:

```txt
lib/src/ui/brush/brush_canvas_fixture.dart
```

to:

```txt
test/helpers/brush_canvas_fixture.dart
```

The test helper may keep the same class name:

```dart
class BrushCanvasFixture
```

It may keep static members such as:

```txt
projectId
trackId
cutId
layerId
canvasSize
createFrameKeys()
createCoordinator(...)
```

Update imports in tests.

For tests under `test/ui/`, use:

```dart
import '../helpers/brush_canvas_fixture.dart';
```

For tests under `test/services/`, use:

```dart
import '../helpers/brush_canvas_fixture.dart';
```

If a test file is in a deeper folder, adjust the relative path correctly.

Do not import test helper files from production `lib` code.

### 4-5. Update tests that used MainCanvasBrushHost.fixture()

Replace usage of:

```dart
MainCanvasBrushHost.fixture()
```

with explicit fixture data injection.

Suggested pattern:

```dart
final frameKeys = BrushCanvasFixture.createFrameKeys();

await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: MainCanvasBrushHost(
        activeFrameKey: frameKeys.first,
        availableFrameKeys: frameKeys,
      ),
    ),
  ),
);
```

This keeps fixture usage test-only and removes the production widget fixture constructor.

### 4-6. Required tests

Update or add coverage for:

```txt
1. MainCanvasBrushHost() with no selection renders empty-selection placeholder.
2. MainCanvasBrushHost() with no selection does not render BrushCanvasPanel.
3. MainCanvasBrushHost() with no selection does not render InteractiveBrushEditCanvasView.
4. MainCanvasBrushHost() with no selection does not render brush-canvas-frame-1.
5. MainCanvasBrushHost(activeFrameKey: fixtureFrame1, availableFrameKeys: fixtureKeys) renders fixture frame-1 through explicit test data injection.
6. MainCanvasBrushHost(activeFrameKey: frameReal) renders brush-canvas-frame-real and not fixture frame-1.
7. Active frame rebuild still works.
8. BrushCanvasPanel renders InteractiveBrushEditCanvasView.
9. BrushCanvasPanel uses BrushCanvasDefaults canvas size when no explicit canvasSize is passed.
10. HomePage defaults to CanvasView.
11. Brush Host Preview remains opt-in.
12. Brush Workspace button remains absent.
13. Deleted debug controls remain absent.
```

Also add a test or architecture check if appropriate:

```txt
- production lib code must not import test/helpers/brush_canvas_fixture.dart
- production lib code must not import brush_canvas_fixture.dart
- MainCanvasBrushHost.fixture() no longer exists
```

A simple architecture test can scan `lib/src/ui/brush/main_canvas_brush_host.dart` and ensure it does not contain:

```txt
MainCanvasBrushHost.fixture
BrushCanvasFixture
```

Only add this if the existing test style supports file scanning without making the test fragile.

### 4-7. Delete old production fixture file

Delete:

```txt
lib/src/ui/brush/brush_canvas_fixture.dart
```

After deletion, search:

```txt
BrushCanvasFixture
brush_canvas_fixture.dart
MainCanvasBrushHost.fixture
```

Expected:

```txt
BrushCanvasFixture
  only in test helper and test files

brush_canvas_fixture.dart
  only imported by test files

MainCanvasBrushHost.fixture
  no matches
```

### 4-8. Documentation update

Update:

```txt
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt
## Phase 205 brush canvas fixture moved out of production code

Implemented:
- Added production BrushCanvasDefaults for embedded brush canvas default size policy.
- Moved BrushCanvasFixture out of lib into test helper space.
- Deleted lib/src/ui/brush/brush_canvas_fixture.dart.
- Removed MainCanvasBrushHost.fixture().
- Tests now inject fixture frame keys explicitly instead of using a production fixture constructor.
- Production lib code no longer imports BrushCanvasFixture.
- The production MainCanvasBrushHost constructor still does not silently use fixture fallback.
- Missing production selection still renders the empty-selection placeholder.
- BrushCanvasPanel remains an embedded canvas panel without debug controls.
- Existing CanvasView remains the default.
- Brush Host Preview remains opt-in.

Still out of scope:
- deleting the test helper fixture if tests still need it
- renaming BrushWorkspaceCoordinator
- renaming BrushWorkspaceCacheInvalidationSink
- replacing Brush Host Preview with production canvas mode
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking

Future cleanup:
After tests no longer need shared brush canvas fixture setup, delete the test helper fixture. Consider BrushWorkspaceCoordinator naming cleanup only after production brush integration stabilizes further.
```

Also update stale references from Phase 204 if needed:

```txt
- deleting BrushCanvasFixture
```

should now become:

```txt
- deleting the test helper BrushCanvasFixture
```

or:

```txt
- deleting the test helper fixture if tests still need it
```

## 5. 체크 / 포맷 / 커밋 안내

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

Before reporting, also search:

```bash
rg "MainCanvasBrushHost\.fixture|BrushCanvasFixture|brush_canvas_fixture" lib test docs
```

Expected:

* No `MainCanvasBrushHost.fixture` matches.
* No `BrushCanvasFixture` / `brush_canvas_fixture` matches in `lib`.
* Test/helper/doc matches are OK.

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
git commit -m "Format phase 205 brush fixture test helper move"
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
4. Brush Host Preview ON still shows brush canvas when active editor selection exists.
5. Brush Host Preview does not silently render fixture frame-1 in production missing-selection path.
6. Empty production selection still shows the empty-selection placeholder.
7. Frame 1 / Frame 2 / Frame 3 debug buttons are still gone.
8. Debug Reset Session is still gone.
9. Brush Workspace button is still absent.
10. Preview OFF returns to CanvasView.
11. Storyboard / Timeline basic behavior is not broken.
```

## Report back

Report:

```txt
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- whether BrushCanvasDefaults was added
- whether BrushCanvasFixture was moved out of lib
- whether lib/src/ui/brush/brush_canvas_fixture.dart was deleted
- whether MainCanvasBrushHost.fixture() was deleted
- whether production lib code has no BrushCanvasFixture imports
- whether tests now inject fixture data explicitly
- whether missing production selection still renders placeholder
- whether BrushCanvasPanel still renders InteractiveBrushEditCanvasView
- whether CanvasView remains default
- what remains before BrushWorkspaceCoordinator naming cleanup
- checks run and results
- rg search summary
- git status summary
```
