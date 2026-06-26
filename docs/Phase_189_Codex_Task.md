# Phase 189 Codex Task

## Title

Brush input polish / repeated stroke regression bundle

## Current position

```txt id="awxsb7"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-19. Brush input polish / repeated stroke regression bundle
```

## Brush work detailed roadmap

```txt id="f2ge7h"
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
1-18. Brush canvas dev controls bundle - done
1-19. Brush input polish / repeated stroke regression bundle - current
1-20. Brush V1 integration review bundle - planned
1-21. Brush work v1 complete - planned
```

## Goal

Stabilize and regression-test the brush input path now that the smoke screen has dev controls.

This phase should not add new production features.

Instead, it should harden the current brush interaction flow:

```txt id="drm0ti"
1. Repeated strokes work.
2. Drag strokes work.
3. Undo removes only the latest stroke.
4. Redo restores the latest undone stroke.
5. Reset clears canvas and redo state.
6. Color preset changes affect future strokes.
7. Pointer cancel does not commit.
8. Multiple pointers do not create duplicate or corrupted commits.
9. Out-of-bounds pointer movement does not crash.
10. Tests use canvas-relative coordinates, not global magic offsets.
```

This phase is intentionally larger than the old micro phases, but should remain limited to brush UI/smoke/test code.

## Required files

Likely modify:

```txt id="xpz7v3"
lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart
lib/src/ui/canvas/brush_canvas_smoke_screen.dart
test/ui/interactive_brush_edit_canvas_view_test.dart
test/ui/interactive_brush_canvas_smoke_host_test.dart
test/ui/brush_canvas_smoke_screen_test.dart
```

Create only if useful:

```txt id="v6tvlf"
test/ui/brush_canvas_test_helpers.dart
```

Creating a small test helper is allowed if it reduces repeated fragile coordinate code.

Expected PR size:

```txt id="gf5r1z"
4 to 6 changed files is acceptable.
Avoid broad architecture changes.
```

## Important principle

Prefer adding regression tests first.

Only change production code when a test exposes an actual issue.

Do not refactor the whole canvas input system.

Do not introduce a new brush engine.

Do not introduce a controller class yet.

Do not wire anything into the main app.

## Canvas-relative test helper

Tests should not use raw global coordinates like:

```dart id="aevd4m"
await tester.startGesture(const Offset(1.5, 1.5));
```

inside screens that have controls above the canvas.

Add or reuse helpers similar to:

```dart id="rpn3ki"
Future<void> tapCanvas(
  WidgetTester tester,
  Offset localOffset,
) async {
  final viewFinder = find.byType(InteractiveBrushEditCanvasView);
  final globalOffset = tester.getTopLeft(viewFinder) + localOffset;
  final gesture = await tester.startGesture(globalOffset, pointer: 1);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}
```

and:

```dart id="r61fnk"
Future<void> dragCanvas(
  WidgetTester tester,
  List<Offset> localOffsets,
) async {
  assert(localOffsets.isNotEmpty);

  final viewFinder = find.byType(InteractiveBrushEditCanvasView);
  final topLeft = tester.getTopLeft(viewFinder);
  final gesture = await tester.startGesture(topLeft + localOffsets.first, pointer: 1);
  await tester.pump();

  for (final localOffset in localOffsets.skip(1)) {
    await gesture.moveTo(topLeft + localOffset);
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
}
```

If a helper file is created, keep it test-only.

Do not import test helpers from production code.

## Required regression tests

### InteractiveBrushEditCanvasView tests

Add or update tests for:

```txt id="n2tssk"
- tap commit creates exactly one operation result
- drag commit creates exactly one operation result
- pointer cancel creates no commit result
- second pointer while first pointer is active does not create a duplicate commit
- repeated tap strokes produce repeated operation results
- out-of-bounds move during an active stroke does not crash
- coordinates are interpreted relative to the canvas/view
```

Use small surfaces:

```txt id="dkq4f2"
CanvasSize(width: 8, height: 8)
tileSize: 2
```

Use visible local coordinates:

```txt id="mc1ywz"
Offset(1.5, 1.5)
Offset(2.5, 1.5)
Offset(3.5, 2.5)
```

Avoid integer-only offsets such as:

```txt id="xk7ckf"
Offset(1, 1)
```

because they can produce empty/no-op commits with small round dabs.

### InteractiveBrushCanvasSmokeHost tests

Add or update tests for:

```txt id="fl6kli"
- repeated strokes keep accumulating in host local session state
- parent rebuild without sessionResetToken change preserves local strokes
- parent rebuild with sessionResetToken change replaces the session state
```

Do not remove the existing blank factory parent rebuild regression test.

### BrushCanvasSmokeScreen tests

Add or update tests for:

```txt id="erzns5"
- two strokes followed by undo removes only the latest stroke
- redo restores the latest undone stroke
- reset after stroke clears canvas
- reset after undo clears redo path or prevents stale redo from restoring pre-reset content
- undo on blank canvas does not crash and leaves canvas blank
- redo without prior undo does not crash and leaves visible state unchanged
- color preset affects future stroke
- color change does not erase existing strokes
- debug status remains deterministic after commit / undo / redo / reset / color change
```

Use canvas-relative helpers.

Do not use screen-global offsets for canvas strokes.

## Pixel / tile assertions

Prefer stable assertions.

Acceptable:

```txt id="wa84d5"
- surface.tiles isNotEmpty after a visible stroke
- surface.tiles isEmpty after undo/reset when the only stroke was undone/reset
- sessionState identity changes after commit/undo/redo/reset when expected
- operation result kind matches commit/undo/redo
```

For color tests, avoid weak object-identity-only checks like:

```dart id="v7c6xp"
expect(blackPixels, isNot(bluePixels));
```

because that can pass due to list identity rather than actual pixel content.

Instead, if practical, inspect actual pixel values using existing tile helpers or direct test-only reads.

If direct color assertion is awkward, at minimum assert:

```txt id="ifzrav"
- host.inputSettings.color changes
- debug status color changes
- a future commit occurs after the color change
```

Do not add expensive per-pixel loops in production painter code.

Test-only inspection is fine.

## Production behavior constraints

Do not add:

```txt id="lbhvp2"
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
Renderer cache
Disk cache
```

Do not call the commit facade directly from `BrushCanvasSmokeScreen`.

Commit should still happen only inside `InteractiveBrushEditCanvasView`.

Undo/redo controls may use the existing cache-aware undo/redo facades.

Do not implement:

```txt id="uww5lk"
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

## Scope confirmations

The PR should explicitly keep these unchanged:

```txt id="zt4h5l"
- main.dart
- app routes
- StoryboardPanel
- TimelinePanel
- project/layer/timeline models
- persistence/save/load
```

## Required checks

Run:

```bash id="j3prje"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

Manual check can be deferred until the smoke screen is wired into a dev route or the main app.

For now, if a dev/test host is manually run, expected behavior is:

```txt id="ugy112"
- tap/drag draws on the canvas
- multiple strokes accumulate
- undo removes only the latest stroke
- redo restores the undone stroke
- reset clears the canvas
- color preset changes future strokes
- cancel/multi-pointer paths do not crash
```

## Report back

Report:

```txt id="ch705z"
- changed files
- test helper changes, if any
- repeated stroke behavior
- drag stroke behavior
- undo/redo regression behavior
- reset regression behavior
- color preset regression behavior
- pointer cancel / multi-pointer behavior
- out-of-bounds behavior
- scope confirmations
- check results
- git status summary
```
