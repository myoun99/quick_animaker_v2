# Phase 186 Codex Task

## Title

Create interactive brush canvas smoke host

## Current position

```txt id="ll2mbg"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-16. Interactive brush canvas smoke host
```

## Brush work detailed roadmap

```txt id="za42za"
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
1-16. Interactive brush canvas smoke host - current
1-17. Brush work v1 complete
```

## Goal

Create a small smoke host widget for the interactive brush canvas.

Phase 185 created `InteractiveBrushEditCanvasView`, which emits `BrushEditSessionCacheOperationResult` through a callback.

This phase should create a parent widget that:

```txt id="yc79a9"
1. Owns a local BrushEditSessionState.
2. Passes it into InteractiveBrushEditCanvasView.
3. Receives onOperationResult.
4. Updates its local sessionState from result.sessionState.
5. Rebuilds the canvas so a committed brush stroke becomes visible.
```

This is still a smoke/dev host.

Do not wire this into the main app yet.

Do not add global state management.

Do not add toolbar UI.

Do not add undo / redo UI.

## Required files

Create:

```txt id="g5j59z"
lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart
test/ui/interactive_brush_canvas_smoke_host_test.dart
```

Do not remove or rewrite:

```txt id="mj63vy"
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
lib/src/ui/canvas/brush_edit_canvas_input_settings.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
```

## Required widget

Create:

```dart id="m1lr4j"
class InteractiveBrushCanvasSmokeHost extends StatefulWidget {
  const InteractiveBrushCanvasSmokeHost({
    super.key,
    required this.initialSessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.cacheInvalidationSink,
    this.showTransparentBackground = true,
    this.onOperationResult,
  });

  final BrushEditSessionState initialSessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CacheInvalidationSink cacheInvalidationSink;
  final bool showTransparentBackground;
  final ValueChanged<BrushEditSessionCacheOperationResult>? onOperationResult;

  @override
  State<InteractiveBrushCanvasSmokeHost> createState();
}
```

State behavior:

```txt id="ljypvr"
- Store a private BrushEditSessionState field.
- Initialize it from widget.initialSessionState in initState.
- On operation result:
  - setState(() { sessionState = result.sessionState; })
  - then call widget.onOperationResult?.call(result)
```

Build behavior:

```txt id="dgnpzy"
- Return InteractiveBrushEditCanvasView.
- Pass the current local sessionState.
- Pass layerId, frameId, inputSettings, cacheInvalidationSink, showTransparentBackground.
- Use a stable key on the InteractiveBrushEditCanvasView:
  interactive-brush-canvas-smoke-host-view
```

Important:

```txt id="hwvr36"
- This widget may use StatefulWidget + setState.
- Do not use Provider/Riverpod/Bloc/ChangeNotifier.
- Do not introduce global app state.
- Do not wire into main.dart or existing app shell.
```

## Optional convenience constructor

If useful, add a named constructor for a tiny blank smoke canvas:

```dart id="o8z7ea"
factory InteractiveBrushCanvasSmokeHost.blank({
  Key? key,
  required LayerId layerId,
  required FrameId frameId,
  required BrushEditCanvasInputSettings inputSettings,
  required CacheInvalidationSink cacheInvalidationSink,
  CanvasSize canvasSize,
  int tileSize,
  bool showTransparentBackground,
  ValueChanged<BrushEditSessionCacheOperationResult>? onOperationResult,
})
```

If implemented:

```txt id="jw2lx0"
- Default canvasSize should be CanvasSize(width: 64, height: 64).
- Default tileSize should be 16.
- It should create:
  BrushEditSessionState(
    canvasState: CanvasSurfaceState(
      currentSurface: BitmapSurface(
        canvasSize: canvasSize,
        tileSize: tileSize,
      ),
    ),
    historyState: BrushEditHistoryState(),
  )
```

Important:

```txt id="g8k3ah"
Do not use const CanvasSize unless CanvasSize has a const constructor.
```

If this constructor creates too much friction with existing model APIs, skip it and only implement the main constructor.

## Important constraints

Do not add:

```txt id="q3158i"
Provider
Riverpod
Bloc
ChangeNotifier
InheritedWidget state model
Global singleton state
Main app wiring
Toolbar UI
Undo button
Redo button
Save/load
Timeline changes
Storyboard changes
Layer panel changes
```

Do not call directly:

```txt id="ibmrmk"
commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation
undoLatestBrushEdit...
redoLatestBrushEdit...
```

The smoke host must not call commit directly.

Only `InteractiveBrushEditCanvasView` should call the commit facade.

The smoke host only receives the result and stores `result.sessionState`.

Do not implement:

```txt id="gqs3p9"
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

Do not mutate:

```txt id="deajf6"
BrushEditSessionState
CanvasSurfaceState
BrushEditHistoryState
BitmapSurface
BitmapTile
```

## Required tests

Create tests for `InteractiveBrushCanvasSmokeHost`.

Required test coverage:

```txt id="m1ml0a"
- builds
- contains InteractiveBrushEditCanvasView
- passes initialSessionState to InteractiveBrushEditCanvasView before interaction
- passes layerId
- passes frameId
- passes inputSettings
- passes cacheInvalidationSink
- passes showTransparentBackground
- uses stable key interactive-brush-canvas-smoke-host-view
- pointer down/up inside surface emits operation result
- onOperationResult callback is called
- after operation result, hosted InteractiveBrushEditCanvasView receives updated sessionState
- updated sessionState is not identical to initialSessionState for a changed stroke
- cache sink receives invalidation for changed stroke
- initialSessionState object is not mutated
- does not add GestureDetector outside InteractiveBrushEditCanvasView
- does not add Provider/Riverpod/Bloc/ChangeNotifier
- does not affect StoryboardPanel
- does not affect TimelinePanel
```

Use small test surfaces:

```txt id="swqf7m"
BitmapSurface(
  canvasSize: CanvasSize(width: 8, height: 8),
  tileSize: 2,
)
```

Use visible dab coordinates:

```txt id="hge4j5"
Offset(1.5, 1.5)
```

Do not use integer coordinates like `Offset(1, 1)` for changed commit tests with default round size-1 brush.

Pointer test caution:

Use `tester.startGesture`, not `createGesture + addPointer`.

Correct pattern:

```dart id="mot63h"
final gesture = await tester.startGesture(
  const Offset(1.5, 1.5),
  pointer: 1,
);
await tester.pump();
await gesture.up();
await tester.pump();
```

Finder caution:

When asserting no `GestureDetector`, scope the finder to the widget under test.

Correct pattern:

```dart id="od6i7b"
final hostFinder = find.byType(InteractiveBrushCanvasSmokeHost);

expect(
  find.descendant(
    of: hostFinder,
    matching: find.byType(GestureDetector),
  ),
  findsNothing,
);
```

Do not assert globally against the entire MaterialApp.

## Fake cache sink for tests

Use a fake sink:

```dart id="gsujqt"
class FakeCacheInvalidationSink implements CacheInvalidationSink {
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

## Required references

Read before editing:

```txt id="x8ddwh"
docs/Phase_184_Codex_Task.md
docs/Phase_185_Codex_Task.md
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
lib/src/ui/canvas/brush_edit_canvas_input_settings.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/models/brush_edit_session_cache_operation_result.dart
lib/src/models/brush_edit_session_state.dart
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_edit_history_state.dart
lib/src/models/bitmap_surface.dart
lib/src/models/canvas_size.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/services/cache_invalidation_executor.dart
test/ui/interactive_brush_edit_canvas_view_test.dart
```

## Out of scope

Do not add:

```txt id="lmy10y"
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

```bash id="lajf8c"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase adds a smoke host widget but should not wire it into the main app yet.

Manual check, if app can be run:

```txt id="mxfyf4"
- The app still launches.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
- If InteractiveBrushCanvasSmokeHost is not wired into the main app yet, visible UI change is not expected.
- If a dev/test host displays InteractiveBrushCanvasSmokeHost, pointer tap/drag on the canvas should update the displayed canvas without crashing.
```

## Report back

Report:

```txt id="qqh26e"
- changed files
- smoke host behavior
- local session state update behavior
- operation result callback behavior
- cache sink behavior
- visible stroke update behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
