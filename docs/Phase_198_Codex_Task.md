# Phase 198 Codex Task

## Title

Connect main canvas brush host to active editor selection

## Overall roadmap

The Brush integration roadmap is:

```txt id="obmq53"
1. Internal brush canvas smoke/dev stack
   - Done.
   - InteractiveBrushEditCanvasView exists and remains the reusable drawing canvas.

2. App-level Brush workspace shell
   - Done.
   - BrushWorkspaceScreen was introduced as a temporary integration route.

3. Brush workspace stabilization
   - Done.
   - Debug reset semantics, cross-frame undo/redo tests, no-op commit safety tests, and improved status text exist.

4. Main canvas absorption preparation
   - Done.
   - BrushWorkspaceView was extracted.
   - BrushWorkspaceFixture was isolated.
   - MainCanvasBrushHost was created.

5. Main editor canvas preview embedding
   - Done.
   - HomePage can show MainCanvasBrushHost through a debug Brush Host Preview toggle.
   - Existing CanvasView remains the default.

6. Active editor selection integration
   - This phase.
   - Start replacing BrushWorkspaceFixture usage in the main canvas path with the actual active Project / Track / Cut / Layer / Frame selection from the editor.

7. BrushWorkspaceScreen removal
   - Later.
   - Once main canvas brush integration is stable, remove BrushWorkspaceScreen, the Brush Workspace route/button, and temporary fixture-only UI.

8. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

9. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 198 should make the main canvas brush path depend on the editor's real active selection instead of only using `BrushWorkspaceFixture`.

Detailed steps:

```txt id="lbodw8"
1. Identify the current active editor state in HomePage.
2. Build a BrushFrameKey from the active Project / Track / Cut / Layer / Frame selection.
3. Create a main-canvas brush host path that can receive this active BrushFrameKey.
4. Keep the existing Brush Host Preview toggle.
5. Keep existing CanvasView as the default.
6. Keep BrushWorkspaceScreen for now, but document it as scheduled for deletion.
7. Add tests proving the main canvas brush host uses active editor selection rather than only fixture keys.
8. Do not implement production brush toolbar, save/load, renderer cache, deferred baking, or timeline/layer rewrites.
```

## Important product decision

`BrushWorkspaceScreen` is temporary.

It should not remain as a permanent debug route in the final app.

Long-term target:

```txt id="m34af0"
Delete:
- BrushWorkspaceScreen
- Brush Workspace entry button
- BrushWorkspaceFixture
- temporary Frame 1 / Frame 2 / Frame 3 fixture selection UI
- Debug Reset Session temporary UI

Keep/evolve:
- InteractiveBrushEditCanvasView
- BrushWorkspaceView or successor reusable brush view
- MainCanvasBrushHost or successor main canvas brush host
- BrushWorkspaceCoordinator or successor controller
- BrushFrameEditSessionStore
- BrushFrameStore
- UnifiedUndoHistory
- BrushFrameKey
```

Do not delete `BrushWorkspaceScreen` in this phase unless all tests and app paths can be safely migrated. Prefer documenting the deletion target and moving the main canvas path off the fixture first.

## Core rules

Do not create a second canvas implementation.

The brush drawing path must still use:

```txt id="mllnn3"
InteractiveBrushEditCanvasView
```

Do not replace it with a new CustomPainter or unrelated canvas widget.

Do not rewrite HomePage.

Do not delete existing `CanvasView`.

Do not delete `BrushWorkspaceScreen` yet unless the existing debug/manual functionality is fully covered by the main canvas path and tests.

## Required work

### 1. Create a brush editor selection adapter

Add a small adapter/helper that converts the current editor active selection into a `BrushFrameKey`.

Suggested file:

```txt id="m4j6tt"
lib/src/ui/brush/brush_editor_selection.dart
```

Possible model:

```dart id="fdglxq"
class BrushEditorSelection {
  const BrushEditorSelection({
    required this.projectId,
    required this.trackId,
    required this.cutId,
    required this.layerId,
    required this.frameId,
  });

  final ProjectId projectId;
  final TrackId trackId;
  final CutId cutId;
  final LayerId layerId;
  final FrameId frameId;

  BrushFrameKey toBrushFrameKey() => BrushFrameKey(...);
}
```

If an existing selection model already exists, use that instead of creating duplicate concepts.

The point is not to invent new app state.
The point is to create a small bridge from existing editor selection to `BrushFrameKey`.

### 2. Update MainCanvasBrushHost to support real active selection

`MainCanvasBrushHost` currently uses `BrushWorkspaceFixture`.

Change it so it can receive an active brush key or active editor selection.

Suggested direction:

```dart id="u2rafb"
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    required this.activeFrameKey,
    required this.availableFrameKeys,
  });

  final BrushFrameKey activeFrameKey;
  final List<BrushFrameKey> availableFrameKeys;
}
```

Or, if better for the current architecture:

```dart id="tgkh6l"
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    required this.selection,
  });

  final BrushEditorSelection selection;
}
```

The main point:

```txt id="s9midv"
MainCanvasBrushHost in the HomePage path should no longer be hardcoded to BrushWorkspaceFixture only.
```

It is acceptable to keep a factory or constructor for temporary fixture use in tests.

For example:

```dart id="uo4cgi"
MainCanvasBrushHost.fixture()
```

or:

```dart id="suob47"
BrushWorkspaceFixture.createMainCanvasBrushHostForTests()
```

But the HomePage brush preview path should use the active editor selection when practical.

### 3. Preserve state per BrushFrameKey

When the active editor frame changes, brush state should be isolated by `BrushFrameKey`.

Expected behavior:

```txt id="r2u2li"
- Draw on active frame A.
- Change active frame to B.
- Brush host displays state for frame B.
- Return to frame A.
- Frame A brush session/state is still available.
```

If the existing HomePage does not yet have a clear active frame selection UI, use the closest current active cut/frame/layer selection available and document the limitation.

Do not fake full timeline integration if it does not exist yet.

### 4. Keep Brush Host Preview toggle

The existing `Brush Host Preview` toggle should remain.

Behavior:

```txt id="pyncgc"
Default:
  existing CanvasView is shown.

Preview enabled:
  MainCanvasBrushHost is shown using active editor selection if available.
```

Do not make brush preview the default yet.

### 5. Keep BrushWorkspaceScreen available for now

Do not remove the `Brush Workspace` button yet in this phase unless all tests are migrated and the main canvas path fully covers it.

But add comments/docs making clear:

```txt id="cm1w0m"
BrushWorkspaceScreen is scheduled for deletion after main canvas integration is stable.
```

### 6. Reduce fixture dependence

`BrushWorkspaceFixture` may remain for:

```txt id="lk6dkh"
- tests
- BrushWorkspaceScreen temporary route
- fallback when editor selection is unavailable
```

But it should not be the only path inside `MainCanvasBrushHost`.

Add comments where appropriate:

```txt id="r7w17e"
TODO Phase 199:
Remove BrushWorkspaceScreen and fixture-only route after main canvas brush selection is stable.
```

### 7. Tests

Add or update tests.

#### Selection adapter test

```txt id="xqjwgb"
- BrushEditorSelection converts to BrushFrameKey correctly.
- It preserves project/track/cut/layer/frame IDs.
```

#### MainCanvasBrushHost accepts active selection/key

```txt id="agpfy5"
- Pump MainCanvasBrushHost with a supplied active BrushFrameKey.
- Confirm it renders BrushWorkspaceView.
- Confirm it renders InteractiveBrushEditCanvasView.
- Confirm status text includes the supplied frameId, not only frame-1 from BrushWorkspaceFixture.
```

#### HomePage brush preview uses active editor selection path

Use the safest available assertion based on current HomePage state.

Possible assertions:

```txt id="jfhrah"
- Enable Brush Host Preview.
- Confirm MainCanvasBrushHost is visible.
- Confirm BrushWorkspaceView is visible.
- Confirm status text reflects current active editor frame/cut/layer selection when available.
```

If active frame selection is not fully exposed yet, test the current bridge/fallback and document what remains for the next phase.

#### Existing default behavior remains

```txt id="vk4dg6"
- HomePage still defaults to existing CanvasView.
- Brush Host Preview can still be toggled off.
- BrushWorkspaceScreen route still exists for now.
```

#### Protected tests remain passing

Do not weaken:

```txt id="u567mr"
StoryboardPanel tests
TimelinePanel tests
Layer ordering tests
Cut.duration tests
BrushWorkspaceScreen tests
BrushWorkspaceView tests
MainCanvasBrushHost tests
brush smoke/dev canvas tests
```

## Suggested files

Likely changed files:

```txt id="l29ej4"
lib/src/ui/home_page.dart
lib/src/ui/brush/main_canvas_brush_host.dart
lib/src/ui/brush/brush_editor_selection.dart
test/ui/main_canvas_brush_embedding_test.dart
test/ui/main_canvas_brush_host_test.dart
test/ui/brush_editor_selection_test.dart
docs/Brush_App_Integration_Decisions.md
```

Only modify files actually needed.

## Documentation update

Update:

```txt id="gx5ask"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="ihbsi1"
## Phase 198 active editor selection bridge

Implemented:
- Main canvas brush preview path can receive active editor selection / BrushFrameKey.
- BrushWorkspaceFixture is no longer the only path for MainCanvasBrushHost.
- BrushWorkspaceScreen is explicitly marked as temporary and scheduled for deletion after main canvas brush integration stabilizes.

Still out of scope:
- deleting BrushWorkspaceScreen
- deleting Brush Workspace button
- deleting BrushWorkspaceFixture
- making Brush Host Preview the default
- production brush toolbar
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
- full timeline/layer/frame production selection replacement
```

Also add a future deletion note:

```txt id="oa4n58"
Future deletion target:
After the main canvas brush path is stable and tested, remove BrushWorkspaceScreen, the Brush Workspace route/button, and fixture-only frame switching UI.
```

## Not allowed

Do not implement:

```txt id="zs6r0p"
- second canvas implementation
- HomePage rewrite
- deleting CanvasView
- deleting BrushWorkspaceScreen unless fully safe
- deleting BrushWorkspaceFixture unless all tests/fallbacks are migrated
- making Brush Host Preview default
- full timeline rewrite
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

## Required checks

Run:

```bash id="nyo03a"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="sfd5wp"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="tgtj19"
git add lib test docs
git commit -m "Format phase 198 active brush selection bridge"
git push
```

Then rerun:

```bash id="gyc36l"
flutter analyze
flutter test
git status
```

## Report back

Report:

```txt id="hgky0c"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- how active editor selection is converted to BrushFrameKey
- whether MainCanvasBrushHost can now receive non-fixture keys
- whether HomePage brush preview uses active editor selection or still falls back to fixture
- what remains before BrushWorkspaceScreen can be deleted
- tests added/updated
- checks run and results
- git status summary
```
