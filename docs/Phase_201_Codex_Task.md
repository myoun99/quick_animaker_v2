# Phase 201 Codex Task

## Title

Hide temporary brush panel controls from the main canvas path

## Overall roadmap

The Brush integration roadmap is:

```txt id="dfb61e"
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
   - Done.
   - BrushWorkspaceView was renamed to BrushCanvasPanel.
   - MainCanvasBrushHost now renders BrushCanvasPanel.

7. Main canvas temporary control cleanup
   - This phase.
   - Hide temporary panel controls from the main canvas brush preview path.
   - Keep debug/test controls available only through explicit test/dev configuration.

8. Fixture fallback removal
   - Later.
   - Remove or reduce BrushWorkspaceFixture fallback after active editor selection path is stable.

9. Brush Host Preview promotion / production integration
   - Later.
   - Replace debug preview toggle with final canvas mode integration when ready.

10. Production brush UI and tool controls
   - Later.
   - Toolbar, brush size/color controls, clear-frame semantics, eraser, pressure, smoothing, onion skin, etc.

11. Renderer/cache/save/playback integration
   - Later.
   - Deferred bitmap baking, preview cache, playback cache, persistence.
```

## This phase detailed roadmap

Phase 201 should make the main canvas brush preview look like a real canvas panel, not a temporary debug workspace.

Detailed steps:

```txt id="viejg0"
1. Keep BrushCanvasPanel as the reusable brush panel.
2. Add an explicit configuration for temporary/debug controls.
3. MainCanvasBrushHost should render BrushCanvasPanel without temporary controls by default.
4. Tests may still enable temporary controls explicitly.
5. Do not delete the underlying brush state, undo/redo, session reset behavior, or fixture helper yet.
6. Add tests proving main canvas preview does not expose Frame 1/2/3 or Debug Reset Session.
7. Keep existing CanvasView as the default.
8. Keep Brush Host Preview opt-in.
9. Document that temporary controls are now hidden from the app-level main canvas path.
```

## Product decision

The main canvas brush path must stop looking like a standalone debug workspace.

Main canvas target:

```txt id="wyf4he"
HomePage / MainEditor
  -> main canvas area
  -> MainCanvasBrushHost
  -> BrushCanvasPanel
  -> InteractiveBrushEditCanvasView
```

Main canvas should not show temporary fixture controls such as:

```txt id="m9uwv6"
Frame 1
Frame 2
Frame 3
Debug Reset Session
temporary Black / Red color buttons
temporary debug help text
```

Those controls may remain only behind an explicit debug/test option.

## Required work

### 1. Add explicit debug controls configuration to BrushCanvasPanel

Update:

```txt id="lg9ro3"
lib/src/ui/brush/brush_canvas_panel.dart
```

Add a clear option such as:

```dart id="lfydlx"
final bool showDebugControls;
```

or a small enum:

```dart id="mxlglr"
enum BrushCanvasPanelMode {
  embedded,
  debug,
}
```

Preferred simple direction:

```dart id="tc7isr"
class BrushCanvasPanel extends StatefulWidget {
  const BrushCanvasPanel({
    super.key,
    required this.coordinator,
    required this.availableFrameKeys,
    required this.cacheInvalidationSink,
    this.initialInputSettings = const BrushEditCanvasInputSettings(),
    this.showDebugControls = false,
  });

  final bool showDebugControls;
}
```

Default must be:

```txt id="hzez3f"
showDebugControls = false
```

So production/main-canvas embedding does not accidentally expose temporary controls.

### 2. Hide temporary controls when showDebugControls is false

When `showDebugControls == false`, hide the temporary UI:

```txt id="ybhr3c"
- Frame 1 / Frame 2 / Frame 3 buttons
- Debug Reset Session button
- temporary reset explanation text
- temporary color buttons such as Black / Red
- temporary development-only help text
```

The actual drawing canvas must remain visible:

```txt id="c76uac"
InteractiveBrushEditCanvasView
```

The panel may still show a minimal active-frame label if needed for tests, but prefer keeping the embedded/main-canvas mode visually clean.

Do not remove the underlying behavior yet. Only hide the temporary controls from the embedded path.

### 3. Keep debug controls available for tests/dev

Existing tests that depend on frame switching or Debug Reset Session should explicitly pass:

```dart id="xib2sa"
showDebugControls: true
```

or:

```dart id="uovri9"
mode: BrushCanvasPanelMode.debug
```

Do not leave tests relying on debug controls being shown by default.

### 4. Update MainCanvasBrushHost

Update:

```txt id="e47cgx"
lib/src/ui/brush/main_canvas_brush_host.dart
```

MainCanvasBrushHost should render embedded mode:

```dart id="p5zyit"
BrushCanvasPanel(
  showDebugControls: false,
  ...
)
```

Because default should already be false, passing it explicitly is optional, but explicit is preferred for readability.

MainCanvasBrushHost must continue to support:

```txt id="sp0iuj"
- activeFrameKey
- selection
- availableFrameKeys
- fixture fallback when no editor selection exists
- cache invalidation sink
```

### 5. Keep Brush Host Preview opt-in

Do not remove:

```txt id="n3lcth"
main-canvas-mode-toggle
main-canvas-legacy-host
main-canvas-brush-host-container
```

Do not make brush host the default yet.

Default HomePage behavior remains:

```txt id="vw0dad"
CanvasView
```

Preview ON behavior remains:

```txt id="j5yrng"
MainCanvasBrushHost
  -> BrushCanvasPanel embedded mode
  -> InteractiveBrushEditCanvasView
```

### 6. Tests

Update or add tests.

#### BrushCanvasPanel default embedded mode

Add a test proving default mode hides temporary controls:

```txt id="s22d7w"
- pump BrushCanvasPanel without showDebugControls
- expect brush-canvas-panel exists
- expect InteractiveBrushEditCanvasView exists
- expect brush-frame-1-button findsNothing
- expect brush-frame-2-button findsNothing
- expect brush-frame-3-button findsNothing
- expect brush-workspace-reset-button findsNothing
- expect text 'Debug Reset Session' findsNothing
```

#### BrushCanvasPanel debug mode

Keep or update existing tests by explicitly enabling debug controls:

```txt id="v0tc7g"
- pump BrushCanvasPanel(showDebugControls: true)
- existing frame switching test still works
- existing Debug Reset Session test still works
```

#### MainCanvasBrushHost embedded behavior

Add or update test:

```txt id="zch0c1"
- pump MainCanvasBrushHost
- expect BrushCanvasPanel exists
- expect InteractiveBrushEditCanvasView exists
- expect Frame 1 / Frame 2 / Frame 3 temporary controls are not visible
- expect Debug Reset Session is not visible
```

#### HomePage brush preview embedded behavior

Update:

```txt id="qpd6rt"
test/ui/main_canvas_brush_embedding_test.dart
```

Expected coverage:

```txt id="plkzbk"
- HomePage defaults to CanvasView
- Brush Host Preview ON shows MainCanvasBrushHost
- BrushCanvasPanel is visible
- InteractiveBrushEditCanvasView is visible
- temporary debug controls are not visible in the main canvas path
- Brush Workspace button remains absent
```

### 7. Documentation update

Update:

```txt id="qyhqik"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="b8rynp"
## Phase 201 main canvas temporary control cleanup

Implemented:
- BrushCanvasPanel now has an explicit embedded/default mode without temporary debug controls.
- MainCanvasBrushHost renders BrushCanvasPanel in embedded mode.
- Frame 1 / Frame 2 / Frame 3 fixture controls are no longer exposed in the main canvas brush preview path.
- Debug Reset Session is no longer exposed in the main canvas brush preview path.
- Existing CanvasView remains the default.
- Brush Host Preview remains opt-in.
- Debug/test coverage can still explicitly enable temporary controls.

Still out of scope:
- deleting BrushWorkspaceFixture
- deleting fixture fallback
- deleting debug controls completely
- replacing debug controls with production brush toolbar
- making Brush Host Preview the default
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
```

Also add:

```txt id="eu42fu"
Future cleanup:
Once production brush controls exist, remove the debug controls path entirely.
```

## Not allowed

Do not implement:

```txt id="yig8wl"
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

```txt id="njjio3"
- BrushWorkspaceScreen
- Brush Workspace button
- brush-workspace-entry route
- BrushWorkspaceView class name
```

Do not remove:

```txt id="xlhwjm"
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

```bash id="h5tzad"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Important post-merge local workflow

After this PR is merged on GitHub and pulled into `master`, run:

```bash id="jk74l4"
git pull
dart format lib test
flutter analyze
flutter test
git status
```

If `dart format` changes files, commit and push the formatting changes:

```bash id="ypcv7s"
git add lib test docs
git commit -m "Format phase 201 brush canvas embedded controls"
git push
```

Then rerun:

```bash id="hx9lqe"
flutter analyze
flutter test
git status
```

## Report back

Report:

```txt id="hy81bz"
- changed files
- overall roadmap impact
- this phase detailed roadmap completed
- how BrushCanvasPanel embedded/debug mode is configured
- whether MainCanvasBrushHost hides temporary controls
- whether HomePage Brush Host Preview hides temporary controls
- whether debug controls still work when explicitly enabled in tests
- whether CanvasView remains default
- what remains before fixture fallback/debug controls can be deleted completely
- checks run and results
- git status summary
```
