# Phase 188 Codex Task

## Title

Brush canvas dev controls bundle

## Current position

```txt id="f7tk7p"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-18. Brush canvas dev controls bundle
```

## Brush work detailed roadmap

```txt id="y5u742"
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - done
1-9. Redo execution service - done
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit - done
1-11. Cache invalidation execution service - done
1-12. BrushEditSessionState + session operation facade - done
1-13. Cache-aware commit / undo / redo facade - done
1-14. BitmapSurface display-only Canvas UI - done
1-15. Canvas pointer input -> brush commit - done
1-16. Interactive brush canvas smoke host - done
1-17. Brush canvas smoke screen / manual harness - done
1-18. Brush canvas dev controls bundle - current
1-19. Brush input polish / repeated stroke regression bundle - planned
1-20. Brush V1 integration review bundle - planned
1-21. Brush work v1 complete - planned
```

## Goal

Expand the brush smoke/manual harness into a useful dev controls bundle.

This phase should make the smoke screen capable of:

```txt id="ynlpob"
1. Drawing by pointer input.
2. Updating and displaying local session state.
3. Undoing the latest brush edit.
4. Redoing the latest undone brush edit.
5. Resetting the smoke canvas to a blank state.
6. Switching between a few simple brush color presets.
7. Showing deterministic debug/status text.
```

This is still a dev/smoke harness.

Do not wire it into the main app.

Do not create the final production toolbar.

Do not add Provider/Riverpod/Bloc/ChangeNotifier.

## Important design adjustment

Phase 186 made `InteractiveBrushCanvasSmokeHost` own local `BrushEditSessionState`.

Phase 187 made `BrushCanvasSmokeScreen` observe operation results, but it did not own the canonical session state.

For undo/redo/reset controls, the smoke screen now needs a canonical current session state.

Therefore this phase should do both:

```txt id="egql75"
1. Keep InteractiveBrushCanvasSmokeHost usable as a self-contained host.
2. Allow BrushCanvasSmokeScreen to pass a new session state into the host after undo/redo/reset.
```

Recommended minimal approach:

```txt id="wshnhl"
- Add didUpdateWidget to InteractiveBrushCanvasSmokeHost.
- If widget.initialSessionState changes by identity, update the private _sessionState to the new widget.initialSessionState.
- Do not update _sessionState if the same object is passed again.
- Do not mutate the old session state.
```

Example:

```dart id="hdulix"
@override
void didUpdateWidget(covariant InteractiveBrushCanvasSmokeHost oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (!identical(widget.initialSessionState, oldWidget.initialSessionState)) {
    _sessionState = widget.initialSessionState;
  }
}
```

Only add this if it fits the existing widget structure.

Do not introduce a controller class yet.

Do not introduce global state.

## Required files

Modify existing:

```txt id="i27tk2"
lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart
lib/src/ui/canvas/brush_canvas_smoke_screen.dart
test/ui/interactive_brush_canvas_smoke_host_test.dart
test/ui/brush_canvas_smoke_screen_test.dart
```

Create if useful:

```txt id="kn4ylw"
lib/src/ui/canvas/brush_canvas_dev_controls.dart
test/ui/brush_canvas_dev_controls_test.dart
```

Do not create more than necessary.

Expected PR size:

```txt id="r7w6xv"
4 to 6 changed files is acceptable.
This phase is intentionally larger than the previous micro phases.
```

## Required behavior: BrushCanvasSmokeScreen

Update `BrushCanvasSmokeScreen` so it owns:

```txt id="qw4wy2"
- BrushEditSessionState _sessionState
- BrushEditCanvasInputSettings _inputSettings
- _RecordingCacheInvalidationSink _cacheInvalidationSink
- BrushEditSessionCacheOperationResult? _latestOperationResult
- int _resetCount or another simple stable way to force a blank reset if needed
```

Initialize `_sessionState` in `initState`, not directly in every build.

Use a helper:

```dart id="knxdfd"
BrushEditSessionState _createBlankSessionState(CanvasSize canvasSize, int tileSize)
```

The helper should create:

```txt id="msb1gl"
BrushEditSessionState
CanvasSurfaceState
BitmapSurface
BrushEditHistoryState
```

Do not use `const CanvasSize`.

Resolve default canvas size with:

```dart id="uo8ie7"
widget.canvasSize ?? CanvasSize(width: 64, height: 64)
```

## Required behavior: drawing result

When `InteractiveBrushCanvasSmokeHost` emits `onOperationResult`:

```txt id="yryzlz"
- setState
- _sessionState = result.sessionState
- _latestOperationResult = result
```

This keeps the screen's canonical session state synchronized with the host.

## Required behavior: undo

Add an Undo control.

Stable key:

```txt id="olv9h3"
brush-canvas-smoke-screen-undo
```

Behavior:

```txt id="d5aqn5"
- Use the existing cache-aware undo service/facade from the brush edit session layer.
- Pass the current _sessionState.
- Pass the current layerId, frameId, and _cacheInvalidationSink if required by the existing service.
- If undo returns a result that changes session state, set:
  _sessionState = result.sessionState
  _latestOperationResult = result
- Do not invent a new undo/history implementation.
- Do not replay strokes.
- Do not mutate the old session state.
```

Important:

```txt id="i4d88f"
Search the existing service layer for the current undo function names.
Use the existing Phase 183 cache-aware undo facade.
Do not create a second undo model.
```

## Required behavior: redo

Add a Redo control.

Stable key:

```txt id="i0d8vi"
brush-canvas-smoke-screen-redo
```

Behavior:

```txt id="vtzmam"
- Use the existing cache-aware redo service/facade from the brush edit session layer.
- Pass the current _sessionState.
- Pass the current layerId, frameId, and _cacheInvalidationSink if required by the existing service.
- If redo returns a result that changes session state, set:
  _sessionState = result.sessionState
  _latestOperationResult = result
- Do not invent a new redo/history implementation.
- Do not replay strokes.
- Do not mutate the old session state.
```

## Required behavior: reset

Add a Reset control.

Stable key:

```txt id="v75qjb"
brush-canvas-smoke-screen-reset
```

Behavior:

```txt id="s1dy47"
- Reset creates a new blank BrushEditSessionState using the current canvas size and tile size.
- Reset clears the latest operation result or sets debug status to reset.
- Reset may clear the recording cache sink, or replace it with a new recording sink.
- Reset should make the canvas visually blank again.
- Reset is dev/smoke only.
```

Do not implement reset as undo replay.

Do not persist anything.

## Required behavior: color presets

Add simple color preset controls.

Stable keys:

```txt id="f5frkp"
brush-canvas-smoke-screen-color-red
brush-canvas-smoke-screen-color-blue
brush-canvas-smoke-screen-color-black
```

Behavior:

```txt id="iqp5zl"
- Red sets BrushEditCanvasInputSettings color to 0xFFFF0000.
- Blue sets BrushEditCanvasInputSettings color to 0xFF0000FF.
- Black sets BrushEditCanvasInputSettings color to 0xFF000000.
- The updated input settings must be passed to InteractiveBrushCanvasSmokeHost.
- Future strokes should use the selected color.
```

Use the existing `BrushEditCanvasInputSettings` API.

Do not add new input setting fields unless they already exist.

If `BrushEditCanvasInputSettings` has copyWith, use it.

If it does not have copyWith, construct a new `BrushEditCanvasInputSettings` with the available fields.

Do not add size/opacity controls in this phase unless they already exist and are trivial to preserve.

## Optional behavior: debug status

Keep deterministic debug/status text.

Stable key:

```txt id="wk1tfj"
brush-canvas-smoke-screen-debug-status
```

Recommended content should include:

```txt id="gi9uzi"
- operation kind or none/reset
- cacheInvalidations count
- current color as hex
```

Example:

```txt id="nmfo39"
operation: commit, cacheInvalidations: 1, color: 0xFFFF0000
```

Do not make tests depend on a highly fragile full sentence unless necessary.

Prefer `find.textContaining`.

## Layout

Keep the layout simple.

Recommended:

```txt id="pu0pwa"
RepaintBoundary
Column
  Row or Wrap for dev controls
  InteractiveBrushCanvasSmokeHost
  optional debug status Text
```

Stable keys:

```txt id="amq9cb"
brush-canvas-smoke-screen
brush-canvas-smoke-screen-controls
brush-canvas-smoke-screen-host
brush-canvas-smoke-screen-debug-status
brush-canvas-smoke-screen-undo
brush-canvas-smoke-screen-redo
brush-canvas-smoke-screen-reset
brush-canvas-smoke-screen-color-red
brush-canvas-smoke-screen-color-blue
brush-canvas-smoke-screen-color-black
```

The exact visual design does not matter.

This is not the final production toolbar.

## Important constraints

Do not add:

```txt id="p1kn8m"
Provider
Riverpod
Bloc
ChangeNotifier
InheritedWidget state model
Global singleton state
Main app wiring
App route wiring
Production toolbar
Save/load
Timeline changes
Storyboard changes
Layer panel changes
```

Do not call directly from the smoke screen:

```txt id="qsv8x3"
commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation
```

Commit should still happen only inside `InteractiveBrushEditCanvasView`.

Undo/redo may be invoked by the dev controls, but must use the existing cache-aware undo/redo facades.

Do not implement:

```txt id="f7jdji"
onion skin
layer compositing
frame compositing
playback preview
cache storage
cache recomputation
brush cursor
brush preview overlay
stroke smoothing
stylus pressure
eraser
selection
```

## Required tests

Update / add tests for `InteractiveBrushCanvasSmokeHost`.

Required coverage:

```txt id="vpgd60"
- changing initialSessionState by identity updates the child InteractiveBrushEditCanvasView sessionState
- rebuilding with the same initialSessionState object does not reset after a local stroke
- no mutation of previous session state
```

Update / add tests for `BrushCanvasSmokeScreen`.

Required coverage:

```txt id="il3ypo"
- builds
- stable root key exists
- controls row/wrap key exists
- host key exists
- debug status key exists by default
- debug status can still be hidden if showDebugStatus is false
- default color is passed to host
- tapping red/blue/black color presets updates host inputSettings
- future stroke after color change uses the selected inputSettings
- pointer down/up inside surface commits and updates visible state
- undo after one stroke makes the surface blank or removes the changed tiles according to existing model behavior
- redo after undo restores visible tiles according to existing model behavior
- reset after a stroke makes the surface blank
- reset clears or resets debug status deterministically
- uses visible dab coordinates such as Offset(1.5, 1.5)
- uses tester.startGesture, not createGesture + addPointer
- does not add GestureDetector outside existing interactive canvas path
- does not include forbidden state management
- does not call commit facade directly from smoke screen
- does not affect StoryboardPanel
- does not affect TimelinePanel
```

Use small test surfaces:

```txt id="mfbotb"
CanvasSize(width: 8, height: 8)
tileSize: 2
```

Do not use:

```txt id="m0v9gg"
const CanvasSize(width: 8, height: 8)
```

Pointer test pattern:

```dart id="zsnvof"
final gesture = await tester.startGesture(
  const Offset(1.5, 1.5),
  pointer: 1,
);
await tester.pump();
await gesture.up();
await tester.pump();
```

Finder caution:

When asserting no `GestureDetector`, scope the finder to `BrushCanvasSmokeScreen`.

Do not assert globally against the entire `MaterialApp`.

Correct pattern:

```dart id="uxgdu4"
final screenFinder = find.byType(BrushCanvasSmokeScreen);

expect(
  find.descendant(
    of: screenFinder,
    matching: find.byType(GestureDetector),
  ),
  findsNothing,
);
```

## Required references

Read before editing:

```txt id="tlmffo"
docs/Phase_186_Codex_Task.md
docs/Phase_187_Codex_Task.md
lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart
lib/src/ui/canvas/brush_canvas_smoke_screen.dart
lib/src/ui/canvas/brush_edit_canvas_input_settings.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/models/brush_edit_session_cache_operation_result.dart
lib/src/models/brush_edit_session_operation_kind.dart
lib/src/models/brush_edit_session_state.dart
lib/src/models/canvas_size.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/services/
test/ui/interactive_brush_canvas_smoke_host_test.dart
test/ui/brush_canvas_smoke_screen_test.dart
```

Also search for existing undo/redo facade names in:

```txt id="z2un4s"
lib/src/services/
test/
```

Do not guess function names if existing functions are already available.

## Out of scope

Do not add:

```txt id="ylqzhj"
Main app integration
Dev route integration
Production canvas toolbar
Layer UI
Timeline integration
Storyboard integration
Save / load
Renderer cache
State management package
```

## Required checks

Run:

```bash id="w0n4nh"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase still should not wire into the main app.

Manual check, if app can be run:

```txt id="yv82ko"
- The app still launches.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
- If BrushCanvasSmokeScreen is not wired into the main app yet, visible UI change is not expected.
- If a dev/test host displays BrushCanvasSmokeScreen:
  - tap/drag draws on the canvas
  - undo removes the latest stroke
  - redo restores the latest undone stroke
  - reset clears the smoke canvas
  - color preset changes future stroke color
  - debug status updates after operations
```

## Report back

Report:

```txt id="g78nvz"
- changed files
- dev controls behavior
- host state sync behavior
- undo behavior
- redo behavior
- reset behavior
- color preset behavior
- debug status behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
