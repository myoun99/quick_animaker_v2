# Phase 187 Codex Task

## Title

Create brush canvas smoke screen / manual harness

## Current position

```txt id="qoa8d5"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-17. Brush canvas smoke screen / manual harness
```

## Brush work detailed roadmap

```txt id="vbe44e"
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
1-17. Brush canvas smoke screen / manual harness - current
1-18. Smoke screen undo / redo controls - planned
1-19. Brush input/settings smoke controls - planned
1-20. Brush UI end-to-end regression cleanup - planned
1-21. Brush work v1 complete - planned
```

## Goal

Create a small self-contained smoke screen / manual harness for the interactive brush canvas.

Phase 186 created `InteractiveBrushCanvasSmokeHost`, which owns local `BrushEditSessionState` and updates it from `BrushEditSessionCacheOperationResult`.

This phase should create a small screen widget that:

```txt id="uejuka"
1. Creates a blank interactive brush canvas host.
2. Provides a concrete local cache invalidation sink.
3. Displays the interactive brush canvas in a minimal screen layout.
4. Optionally shows tiny debug/status text for the latest operation and cache invalidation count.
5. Allows manual tap/drag testing of brush drawing without wiring into the main app.
```

This is a dev/smoke harness only.

Do not wire it into `main.dart`.

Do not add app routes.

Do not introduce global state management.

## Required files

Create:

```txt id="fb5fxi"
lib/src/ui/canvas/brush_canvas_smoke_screen.dart
test/ui/brush_canvas_smoke_screen_test.dart
```

Do not remove or rewrite:

```txt id="l9p3qd"
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
lib/src/ui/canvas/brush_edit_canvas_input_settings.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart
```

## Required widget

Create:

```dart id="fusvfm"
class BrushCanvasSmokeScreen extends StatefulWidget {
  const BrushCanvasSmokeScreen({
    super.key,
    this.layerId = const LayerId('smoke-layer'),
    this.frameId = const FrameId('smoke-frame'),
    this.inputSettings = const BrushEditCanvasInputSettings(),
    this.canvasSize,
    this.tileSize = 16,
    this.showTransparentBackground = true,
    this.showDebugStatus = true,
  });

  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CanvasSize? canvasSize;
  final int tileSize;
  final bool showTransparentBackground;
  final bool showDebugStatus;

  @override
  State<BrushCanvasSmokeScreen> createState();
}
```

Important:

```txt id="j937mg"
Do not use const CanvasSize unless CanvasSize has a const constructor.
```

The default canvas size should be resolved inside state/build:

```dart id="iz1d0k"
final resolvedCanvasSize =
    widget.canvasSize ?? CanvasSize(width: 64, height: 64);
```

## Local cache invalidation sink

Add a small local recording sink inside the same file.

It may be private:

```dart id="yg69zv"
class _RecordingCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  int get totalCalls =>
      layerTiles.length + frameComposites.length + playbackPreviews.length;

  @override
  void invalidateLayerTile(LayerTileCacheKey key) {
    layerTiles.add(key);
  }

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) {
    frameComposites.add(key);
  }

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) {
    playbackPreviews.add(key);
  }
}
```

This is not a real cache.

It is only a smoke/dev recording sink.

Do not add renderer cache.

Do not add disk cache.

Do not add playback cache implementation.

## State behavior

The smoke screen should own:

```txt id="edij4t"
- one _RecordingCacheInvalidationSink
- latest BrushEditSessionCacheOperationResult?
```

When the host emits an operation result:

```txt id="s9fq3n"
- store latest result with setState
- do not manually mutate session state
- do not call commit services directly
```

`InteractiveBrushCanvasSmokeHost` already updates its own local session state.

The smoke screen should only observe the result for debug/status display.

## Build behavior

The screen should return a minimal layout.

Recommended structure:

```txt id="cqki7c"
- RepaintBoundary or simple container root
- Column
  - InteractiveBrushCanvasSmokeHost.blank
  - optional debug/status Text
```

Stable keys:

```txt id="mjhl1n"
brush-canvas-smoke-screen
brush-canvas-smoke-screen-host
brush-canvas-smoke-screen-debug-status
```

`InteractiveBrushCanvasSmokeHost.blank` should receive:

```txt id="okq6ug"
- key: ValueKey('brush-canvas-smoke-screen-host')
- layerId
- frameId
- inputSettings
- cacheInvalidationSink
- resolved canvasSize
- tileSize
- showTransparentBackground
- onOperationResult
```

If `showDebugStatus` is true, show a small text like:

```txt id="o3t22h"
operation: none, cacheInvalidations: 0
```

After a changed commit, this can become something like:

```txt id="i5f4kw"
operation: commit, cacheInvalidations: 1
```

Do not depend on exact English punctuation unless tests make it stable.

Keep the status simple and deterministic.

## Important constraints

Do not add:

```txt id="mg0e9y"
Provider
Riverpod
Bloc
ChangeNotifier
InheritedWidget state model
Global singleton state
Main app wiring
App route wiring
Toolbar UI
Undo button
Redo button
Save/load
Timeline changes
Storyboard changes
Layer panel changes
```

Do not call directly:

```txt id="v4s3rs"
commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation
undoLatestBrushEdit...
redoLatestBrushEdit...
```

The smoke screen must not call commit directly.

Only `InteractiveBrushEditCanvasView` should call the commit facade.

The smoke host owns session state.

The smoke screen only owns the recording sink and latest result for debug display.

Do not implement:

```txt id="gbi1jw"
onion skin
layer compositing
frame compositing
playback preview
cache storage
cache recomputation
brush cursor
brush preview overlay
stroke smoothing
interpolation
stylus pressure
eraser
selection
```

## Required tests

Create tests for `BrushCanvasSmokeScreen`.

Required coverage:

```txt id="un5qe5"
- builds
- has stable root key brush-canvas-smoke-screen
- contains InteractiveBrushCanvasSmokeHost
- host has key brush-canvas-smoke-screen-host
- passes default layerId
- passes default frameId
- passes inputSettings
- passes showTransparentBackground
- resolves default CanvasSize without using const CanvasSize
- accepts custom CanvasSize
- accepts custom tileSize
- debug status is shown by default
- debug status can be hidden
- pointer down/up inside surface updates debug status
- pointer down/up inside surface causes host to commit and update visible state
- uses visible dab coordinates such as Offset(1.5, 1.5)
- uses tester.startGesture, not createGesture + addPointer
- does not add GestureDetector outside existing interactive canvas path
- does not include forbidden state management or direct commit calls
- does not affect StoryboardPanel
- does not affect TimelinePanel
```

Use small test surfaces:

```txt id="f4eyh3"
CanvasSize(width: 8, height: 8)
tileSize: 2
```

Do not use:

```txt id="wqgrfn"
const CanvasSize(width: 8, height: 8)
```

Pointer test pattern:

```dart id="iln57t"
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

```dart id="rponu4"
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

```txt id="wnca4e"
docs/Phase_185_Codex_Task.md
docs/Phase_186_Codex_Task.md
lib/src/ui/canvas/brush_edit_canvas_input_settings.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart
lib/src/models/brush_edit_session_cache_operation_result.dart
lib/src/models/brush_edit_session_operation_kind.dart
lib/src/models/canvas_size.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/models/layer_tile_cache_key.dart
lib/src/models/frame_composite_cache_key.dart
lib/src/models/playback_preview_cache_key.dart
lib/src/services/cache_invalidation_executor.dart
test/ui/interactive_brush_edit_canvas_view_test.dart
test/ui/interactive_brush_canvas_smoke_host_test.dart
```

## Out of scope

Do not add:

```txt id="xm6ago"
Main app integration
Dev route integration
Canvas toolbar
Brush settings UI
Undo / redo UI
Onion skin
Layer compositing
Renderer cache
Save / load
Timeline changes
Storyboard changes
State management package
```

## Required checks

Run:

```bash id="bnz5zv"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase adds a smoke screen widget but should not wire it into the main app yet.

Manual check, if app can be run:

```txt id="ghjfbk"
- The app still launches.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
- If BrushCanvasSmokeScreen is not wired into the main app yet, visible UI change is not expected.
- If a dev/test host displays BrushCanvasSmokeScreen, pointer tap/drag on the canvas should update the displayed canvas without crashing.
- Debug status should update after a changed brush commit if showDebugStatus is true.
```

## Report back

Report:

```txt id="wg2j37"
- changed files
- smoke screen behavior
- host wiring behavior
- local recording cache sink behavior
- debug status behavior
- visible stroke update behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
