# Phase 184 Codex Task

## Title

Create display-only BitmapSurface Canvas UI

## Current position

```txt id="ka7wqt"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-14. BitmapSurface display-only Canvas UI
```

## Brush work detailed roadmap

```txt id="oc36mp"
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
1-14. BitmapSurface display-only Canvas UI - current
1-15. Canvas pointer input -> brush commit
1-16. Brush work v1 complete
```

## Goal

Create the first real Canvas UI bridge for bitmap drawing data.

This phase should render the current `BitmapSurface` from `BrushEditSessionState` into a Flutter widget.

This is display-only.

Do not implement pointer input yet.

Do not implement brush dragging yet.

Do not execute brush commits from UI yet.

Do not add Provider, Riverpod, Bloc, or ChangeNotifier.

Do not change timeline or storyboard.

## Required files

Create these files, using the existing UI folder convention if one already exists.

If there is no existing canvas UI folder, create:

```txt id="y2rrws"
lib/src/ui/canvas/bitmap_surface_painter.dart
lib/src/ui/canvas/brush_edit_canvas_view.dart
test/ui/bitmap_surface_painter_test.dart
test/ui/brush_edit_canvas_view_test.dart
```

If the project already has a better matching UI directory, use that existing convention, but keep the same class names.

## Required painter

Create:

```dart id="iwdeuh"
class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
  });

  final BitmapSurface surface;
  final bool showTransparentBackground;

  @override
  void paint(Canvas canvas, Size size);

  @override
  bool shouldRepaint(covariant BitmapSurfacePainter oldDelegate);
}
```

Rendering behavior:

```txt id="en5qmf"
- Draw the BitmapSurface tile pixels onto the Flutter canvas.
- Use the existing BitmapTile pixel data.
- Use RGBA byte order.
- Skip fully transparent pixels.
- Respect tile coordinate:
  globalX = tile.coord.x * tile.size + localX
  globalY = tile.coord.y * tile.size + localY
- Draw each visible pixel as a 1x1 logical pixel rectangle.
```

Use the existing helper if useful:

```txt id="gf586x"
readRgbaColorFromBitmapTile
```

This painter is allowed to be simple and not optimized.

This is the first UI bridge, not the final renderer.

Do not implement:

```txt id="g682mm"
ui.Image tile atlas
GPU cache
tile cache
frame composite cache
playback cache
async image decoding
```

Transparent background:

```txt id="voduzg"
If showTransparentBackground is true:
- draw a simple neutral background behind the surface.
- It can be plain light gray or a simple checkerboard.
- Keep it deterministic and easy to test.
```

## Required widget

Create:

```dart id="fatmpg"
class BrushEditCanvasView extends StatelessWidget {
  const BrushEditCanvasView({
    super.key,
    required this.sessionState,
    this.showTransparentBackground = true,
  });

  final BrushEditSessionState sessionState;
  final bool showTransparentBackground;

  @override
  Widget build(BuildContext context);
}
```

Behavior:

```txt id="i5r47d"
- Read surface from sessionState.canvasState.currentSurface.
- Use CustomPaint with BitmapSurfacePainter.
- Wrap with RepaintBoundary.
- Give stable keys:
  RepaintBoundary key: brush-edit-canvas-view-boundary
  CustomPaint key: brush-edit-canvas-view-custom-paint
```

Sizing behavior:

```txt id="b6mt6g"
- The widget should have a finite size based on surface.canvasSize.
- Use SizedBox(width: surface.canvasSize.width.toDouble(), height: surface.canvasSize.height.toDouble()).
- Do not introduce scrolling, zooming, panning, or transform in this phase.
```

## Important constraints

This phase is display-only.

Do not add:

```txt id="ed6l1f"
Pointer input
GestureDetector brush drawing
MouseRegion brush drawing
Stylus pressure handling
BrushDabSequence creation from pointer events
Brush commit execution from UI
Undo button
Redo button
Toolbar
Provider / Riverpod / Bloc / ChangeNotifier
Real cache storage
Cache recomputation
Save / load
Timeline changes
Storyboard changes
```

Do not mutate:

```txt id="a12pnr"
BrushEditSessionState
CanvasSurfaceState
BrushEditHistoryState
BitmapSurface
BitmapTile
```

Do not call:

```txt id="kallc2"
commitBrushDabSequenceToBrushEditSession...
undoLatestBrushEdit...
redoLatestBrushEdit...
executeCacheInvalidationPlan...
```

## Required tests

Painter tests:

```txt id="yl01cv"
- BitmapSurfacePainter stores surface
- BitmapSurfacePainter stores showTransparentBackground
- shouldRepaint false for same surface and same background flag
- shouldRepaint true when surface changes
- shouldRepaint true when showTransparentBackground changes
- painting an empty surface does not throw
- painting a surface with one tile does not throw
```

Widget tests:

```txt id="pdr60d"
- BrushEditCanvasView builds
- finds RepaintBoundary by key brush-edit-canvas-view-boundary
- finds CustomPaint by key brush-edit-canvas-view-custom-paint
- CustomPaint uses BitmapSurfacePainter
- widget size matches surface.canvasSize
- empty surface renders without throwing
- surface with one non-transparent tile renders without throwing
- does not mutate input BrushEditSessionState
- does not mutate input CanvasSurfaceState
- does not mutate input BrushEditHistoryState
- does not execute commit / undo / redo
- does not execute cache invalidation
- does not affect StoryboardPanel
- does not affect TimelinePanel
```

Use small surfaces in tests, for example:

```txt id="z0l8v6"
CanvasSize(width: 4, height: 4)
tileSize: 2
```

Important:

```txt id="usw0v0"
Do not use const CanvasSize unless CanvasSize has a const constructor.
```

## Required references

Read before editing:

```txt id="p36dy5"
docs/Phase_152_Codex_Task.md
docs/Phase_163_Codex_Task.md
docs/Phase_182_Codex_Task.md
docs/Phase_183_Codex_Task.md
lib/src/models/bitmap_surface.dart
lib/src/models/bitmap_tile.dart
lib/src/models/canvas_size.dart
lib/src/models/tile_coord.dart
lib/src/models/brush_edit_session_state.dart
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_edit_history_state.dart
lib/src/services/bitmap_tile_rgba.dart
```

Also inspect existing UI/test folder conventions before adding files.

## Out of scope

Do not add:

```txt id="hvpwxx"
Canvas pointer input
Brush input controller
Brush cursor
Onion skin
Layer compositing
Frame compositing
Playback preview
Timeline integration
Storyboard integration
Undo / redo UI
Toolbar UI
Save / load
Provider / Riverpod / Bloc / ChangeNotifier
```

## Required checks

Run:

```bash id="kvib6c"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase introduces a display-only canvas widget.

Manual check, if app can be run:

```txt id="imhsy4"
- The app still launches.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
- If BrushEditCanvasView is not wired into the main app yet, confirm no visible UI change is expected.
- If a dev/smoke route or test host displays BrushEditCanvasView, confirm an empty canvas area appears without crashing.
```

## Report back

Report:

```txt id="r60ihn"
- changed files
- BitmapSurfacePainter behavior
- BrushEditCanvasView behavior
- rendering behavior
- size behavior
- key behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
