# Phase 185 Codex Task

## Title

Connect canvas pointer input to brush commit facade

## Current position

```txt id="g2ixb8"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-15. Canvas pointer input -> brush commit
```

## Brush work detailed roadmap

```txt id="ztsrt9"
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
1-15. Canvas pointer input -> brush commit - current
1-16. Brush canvas dev/smoke host integration
1-17. Brush work v1 complete
```

## Goal

Create the first interactive canvas bridge.

This phase should introduce a small widget that:

```txt id="me93hz"
1. Displays the existing BrushEditCanvasView.
2. Collects pointer positions as BrushDab samples.
3. Builds a BrushDabSequence when the pointer stroke ends.
4. Calls the existing cache-aware commit facade.
5. Emits the result through a callback.
```

Important:

This phase should not wire the widget into the main app yet.

This phase should not add global state management.

This phase should not add toolbar UI.

This phase should not add undo / redo UI.

## Required files

Create:

```txt id="i3jx24"
lib/src/ui/canvas/brush_edit_canvas_input_settings.dart
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
test/ui/brush_edit_canvas_input_settings_test.dart
test/ui/interactive_brush_edit_canvas_view_test.dart
```

Do not remove or rewrite:

```txt id="f5r84h"
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
```

The existing display-only `BrushEditCanvasView` must keep working.

## Required input settings model

Create:

```dart id="q7g7cf"
class BrushEditCanvasInputSettings {
  const BrushEditCanvasInputSettings({
    this.color = 0xFF000000,
    this.size = 1.0,
    this.opacity = 1.0,
    this.flow = 1.0,
    this.hardness = 1.0,
    this.tipShape = BrushTipShape.round,
  });

  final int color;
  final double size;
  final double opacity;
  final double flow;
  final double hardness;
  final BrushTipShape tipShape;

  BrushEditCanvasInputSettings copyWith({
    int? color,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    BrushTipShape? tipShape,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Validation:

```txt id="syb36l"
- size must be > 0
- opacity must be >= 0 and <= 1
- flow must be >= 0 and <= 1
- hardness must be >= 0 and <= 1
```

Do not add JSON.

## Required interactive widget

Create:

```dart id="q2vkgi"
class InteractiveBrushEditCanvasView extends StatefulWidget {
  const InteractiveBrushEditCanvasView({
    super.key,
    required this.sessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.cacheInvalidationSink,
    required this.onOperationResult,
    this.showTransparentBackground = true,
  });

  final BrushEditSessionState sessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CacheInvalidationSink cacheInvalidationSink;
  final ValueChanged<BrushEditSessionCacheOperationResult> onOperationResult;
  final bool showTransparentBackground;

  @override
  State<InteractiveBrushEditCanvasView> createState();
}
```

Build behavior:

```txt id="e15wrf"
- Return a Listener.
- Listener key must be:
  interactive-brush-edit-canvas-view-listener
- Listener child must be BrushEditCanvasView.
- Pass sessionState and showTransparentBackground to BrushEditCanvasView.
```

Do not use `GestureDetector` in this phase.

Use `Listener` so future stylus/pointer handling is easier.

## Pointer behavior

Use pointer events from the `Listener`.

Stroke lifecycle:

```txt id="ge6w17"
onPointerDown:
- If the pointer position is inside the current surface bounds:
  - start a stroke
  - remember the pointer id
  - add the first BrushDab
- If outside bounds:
  - do nothing

onPointerMove:
- If no active stroke, ignore.
- If pointer id does not match the active pointer, ignore.
- If the position is inside the current surface bounds:
  - add a BrushDab
- If outside bounds:
  - ignore that sample, but keep the stroke active

onPointerUp:
- If pointer id matches the active pointer:
  - commit the collected BrushDabSequence if it has at least one dab
  - call onOperationResult with the cache-aware commit result
  - clear the active stroke

onPointerCancel:
- If pointer id matches the active pointer:
  - discard the stroke
  - do not commit
  - do not call onOperationResult
  - clear the active stroke
```

Multi-pointer behavior:

```txt id="rt9i2w"
- Only one active pointer is supported in this phase.
- While one pointer is active, ignore other pointer ids.
```

Coordinate behavior:

```txt id="jb29ps"
- Use event.localPosition.
- No zoom.
- No pan.
- No transform.
- Bounds:
  x >= 0
  y >= 0
  x < surface.canvasSize.width
  y < surface.canvasSize.height
```

Dab creation:

For each accepted pointer sample, create:

```dart id="f8t50q"
BrushDab(
  center: CanvasPoint(x: localPosition.dx, y: localPosition.dy),
  color: inputSettings.color,
  size: inputSettings.size,
  opacity: inputSettings.opacity,
  flow: inputSettings.flow,
  hardness: inputSettings.hardness,
  tipShape: inputSettings.tipShape,
  pressure: 1.0,
  sequence: nextSequence,
)
```

Important:

```txt id="zdxdg8"
- Do not implement stylus pressure yet.
- Always use pressure: 1.0.
- Increment sequence for each accepted dab.
```

Commit behavior:

On pointer up, call:

```dart id="w62k15"
commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
  sessionState: widget.sessionState,
  sequence: BrushDabSequence(collectedDabs),
  layerId: widget.layerId,
  frameId: widget.frameId,
  cacheInvalidationSink: widget.cacheInvalidationSink,
)
```

Then call:

```dart id="n0jyu5"
widget.onOperationResult(result);
```

Important:

```txt id="q1lrjq"
- The widget must not mutate widget.sessionState.
- Parent code will decide how to store the returned sessionState in a future phase.
- This phase only emits the result.
```

## Important constraints

Do not add:

```txt id="z3y4se"
Provider
Riverpod
Bloc
ChangeNotifier
InheritedWidget state model
Global singleton state
Toolbar UI
Undo button
Redo button
Save/load
Timeline changes
Storyboard changes
Layer panel changes
Main app wiring
```

Do not call:

```txt id="p1dtwg"
undoLatestBrushEdit...
redoLatestBrushEdit...
```

Do not implement:

```txt id="hunh1i"
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

```txt id="j4n143"
BrushEditSessionState
CanvasSurfaceState
BrushEditHistoryState
BitmapSurface
BitmapTile
```

## Required tests

Input settings model tests:

```txt id="xg1co5"
- default values
- stores custom values
- rejects size <= 0
- rejects opacity < 0
- rejects opacity > 1
- rejects flow < 0
- rejects flow > 1
- rejects hardness < 0
- rejects hardness > 1
- copyWith preserves omitted values
- copyWith updates each field
- equality / hashCode / toString
```

Interactive widget tests:

```txt id="bdqtiv"
- builds
- finds Listener by key interactive-brush-edit-canvas-view-listener
- contains BrushEditCanvasView
- passes sessionState to BrushEditCanvasView
- passes showTransparentBackground to BrushEditCanvasView
- does not add GestureDetector
- pointer down/up inside surface emits one operation result
- emitted result kind is commit
- emitted result didAffectHistory is true for a visible dab
- cache sink is called for a changed commit
- emitted result sessionState is not the same object as input sessionState when changed
- pointer outside surface does not emit a result
- pointer cancel does not emit a result
- pointer move without pointer down does not emit a result
- second pointer is ignored while first pointer is active
- callback is called at most once per stroke
- does not mutate input BrushEditSessionState
- does not mutate input CanvasSurfaceState
- does not mutate input BrushEditHistoryState
- does not execute undo
- does not execute redo
- does not add Provider/Riverpod/Bloc/ChangeNotifier
- does not affect StoryboardPanel
- does not affect TimelinePanel
```

Use small test surfaces:

```txt id="e50l9f"
BitmapSurface(
  canvasSize: CanvasSize(width: 8, height: 8),
  tileSize: 2,
)
```

Important:

```txt id="jaq99z"
Do not use const CanvasSize unless CanvasSize has a const constructor.
```

Fake cache sink:

Use a fake sink like Phase 183 tests:

```dart id="kzh3xn"
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

Test caution:

When asserting no `Listener` or no `GestureDetector`, scope the finder to the widget under test.

Do not assert globally that the whole `MaterialApp` contains no `Listener`, because Flutter internally adds `Listener` widgets.

Correct pattern:

```dart id="u65hp3"
final viewFinder = find.byType(InteractiveBrushEditCanvasView);

expect(
  find.descendant(
    of: viewFinder,
    matching: find.byType(GestureDetector),
  ),
  findsNothing,
);
```

## Required references

Read before editing:

```txt id="fygmbp"
docs/Phase_183_Codex_Task.md
docs/Phase_184_Codex_Task.md
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
lib/src/models/brush_edit_session_state.dart
lib/src/models/brush_edit_session_cache_operation_result.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/brush_tip_shape.dart
lib/src/models/canvas_point.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/services/brush_edit_session_cache_operations.dart
lib/src/services/cache_invalidation_executor.dart
test/ui/brush_edit_canvas_view_test.dart
test/services/brush_edit_session_cache_operations_test.dart
```

## Out of scope

Do not add:

```txt id="hd8wk7"
Main app integration
Dev host integration
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

```bash id="gpma3b"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase adds an interactive canvas widget but should not wire it into the main app yet.

Manual check, if app can be run:

```txt id="rs35gf"
- The app still launches.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
- If InteractiveBrushEditCanvasView is not wired into the main app yet, visible UI change is not expected.
- If a dev/test host displays InteractiveBrushEditCanvasView, pointer tap/drag on the canvas should not crash.
```

## Report back

Report:

```txt id="du33qz"
- changed files
- BrushEditCanvasInputSettings behavior
- InteractiveBrushEditCanvasView behavior
- pointer down behavior
- pointer move behavior
- pointer up behavior
- pointer cancel behavior
- commit callback behavior
- cache sink behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
