# Phase 223 Codex Task — Pixel-Grid Brush Display Architecture

## Goal

Fix the Phase 222 active editing display regression by introducing a future-safe pixel-grid brush display architecture.

The core requirement is:

```txt id="f6jk72"
Brush source data may remain stroke-like / vector-like.
Brush display must look like bitmap pixels.
```

Do not treat this as a small visual tweak. This phase must correct the architecture so active editing, committed undoable strokes, inactive previews, and future playback can evolve without mixing incompatible display paths.

## Required documents to read first

Read these documents before editing code:

```txt id="0kk30s"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Current_Docs_Index.md
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Test_Architecture.md
```

Respect these existing rules:

* `Frame` must remain lightweight.
* Source drawing payloads belong in `BrushFrameStore` or an equivalent brush/canvas storage boundary.
* Source drawing data is `BrushFrameDrawing.commands + hiddenCommandIds`.
* Cache/display bitmap images are derived data, not source of truth.
* Brush-specific undo/redo controls must not be added.
* User-facing brush undo/redo stays global and command-id based.
* Do not reintroduce `TileDelta` / `TileDeltaCommand` as brush runtime architecture.
* Do not add Provider, Riverpod, Bloc, ChangeNotifier, or a new global state framework.

## Problem to fix

The current merged Phase 222 display behavior is wrong.

Observed behavior:

```txt id="t1fahm"
1. While drawing, strokes look vector-like / smooth.
2. After pointer release, strokes switch to bitmap-like.
3. During a second stroke, previously committed strokes can visually switch back to vector-like.
4. After the second stroke ends, they switch back to bitmap-like.
5. As strokes accumulate, lag becomes severe.
```

This indicates that active stroke display, committed stroke display, and preview/cache display are being rendered through inconsistent paths.

The architecture must not switch the visual representation of already committed strokes while the user is drawing.

## Correct architecture

Use this model:

```txt id="m55erq"
Source data:
  BrushFrameDrawing.commands
  BrushFrameDrawing.hiddenCommandIds

Derived display data:
  BrushCommandRasterCache
  BrushFrameEditComposite
  BrushFramePreviewCache
  ActiveStrokeRasterOverlay
```

### 1. Source data

Brush source data remains stroke-like:

```txt id="a35vhv"
BrushPaintCommand
- id
- sourceDabs / sampled brush input
- brush settings
- color / opacity / size / pressure data
- state
```

This source data may be vector-like. That is acceptable.

It exists for:

```txt id="wxsyks"
- undo / redo
- save/load source persistence later
- cache rebuild
- raster cache rebuild
```

Do not flatten source data into a bitmap as the only source of truth.

### 2. Pixel-grid rasterization

All visible brush display must go through a pixel-grid bitmap rasterizer.

Do not display brush commands or active strokes with smooth vector/path rendering.

The brush rasterizer must produce bitmap-like results:

```txt id="tjdypc"
- no smooth vector stroke display
- no subpixel-looking display
- no anti-aliased path display for brush strokes
- no direct visible drawPath-based brush display
- pixel-grid aligned output
- nearest-neighbor style visual result when zoomed
```

A source dab may have floating-point coordinates internally, but the displayed result must be rasterized into pixels/tiles so it looks like bitmap paint.

### 3. Command raster cache

Introduce or refactor toward a command raster cache:

```txt id="zya2w3"
BrushCommandRasterCache
- BrushPaintCommandId -> rasterized command tiles / rasterized command surface data
```

This cache is derived from source commands.

It is not source of truth.

It is used so the app does not repeatedly replay source commands through a painter/path renderer for display.

### 4. Active edit composite

Introduce or refactor toward an active frame edit composite:

```txt id="tdwlg4"
BrushFrameEditComposite
- frameKey
- compositeSurface
- dirtyTiles
- sourceRevision
```

The active edit composite represents:

```txt id="0sj4u4"
activeEditCompositeSurface =
  bakedBaseSurface, if present
  + visible undoable command raster cache tiles
```

If `bakedBaseSurface` does not physically exist yet, keep the structure future-safe and use the current available base/empty surface equivalent.

The active frame display must use:

```txt id="bsr8wl"
active frame display =
  activeEditCompositeSurface
  + activeStrokeTempSurface
```

Do not swap the active frame display to `inactivePreviewSurface` during active editing.

Do not make `inactivePreviewSurface` the active edit display path.

### 5. Active stroke raster overlay

Replace vector/path-like active stroke display with a bitmap-like active stroke raster overlay.

```txt id="x1mf1r"
ActiveStrokeRasterOverlay
- tempSurface
- dirtyTiles
```

Pointer movement should update only the active stroke temporary surface or its dirty region.

Pointer movement must not rebuild the full frame composite.

Pointer movement must not replay all committed source commands.

While drawing:

```txt id="752yrc"
show:
  activeEditCompositeSurface
  + activeStrokeTempSurface
```

The active stroke should look visually consistent with committed bitmap strokes.

### 6. Pointer release

On pointer release:

```txt id="pm1nv5"
1. Create and store the BrushPaintCommand source data.
2. Add the command to global undo history as before.
3. Rasterize the command through the same pixel-grid rasterizer.
4. Store or update the command raster cache.
5. Update only the affected tiles/region of activeEditCompositeSurface.
6. Clear activeStrokeTempSurface.
7. Mark inactivePreviewCache / playbackPreviewCache dirty.
```

This is not source baking.

Do not discard the source command.

Do not make pointer release fully bake the stroke into `bakedBaseSurface`.

Do not replace the active frame display with an inactive preview cache after pointer release.

### 7. Undo / redo

Undo:

```txt id="8uh4ma"
1. Add command id to hiddenCommandIds.
2. Keep the source command available for redo while redo is valid.
3. Mark the affected command raster/composite tiles dirty.
4. Recompose the affected activeEditCompositeSurface tiles from:
   bakedBaseSurface + visible command raster caches.
```

Redo:

```txt id="74th2f"
1. Remove command id from hiddenCommandIds.
2. Mark affected tiles dirty.
3. Recompose affected activeEditCompositeSurface tiles.
```

The active edit composite is derived. It must be rebuildable from source commands and raster caches.

### 8. Inactive preview cache

Inactive previews are still valid, but only for inactive display paths:

```txt id="nj5jcw"
Allowed:
- inactive frame display
- inactive layer/frame display
- timeline thumbnails / ruler preview
- future playback preview
- frame switch preparation
- idle preparation

Forbidden:
- active frame display while the user is drawing
- replacing active edit display immediately after every pointer release
- causing active committed strokes to switch visual representation during a new stroke
```

### 9. Remove the Phase 222 active display mistake

Remove or disable any production path where:

```txt id="94fql3"
- BrushCanvasPanel prepares an inactive-style preview immediately after pointer release
- active frame display prefers validPreviewSurface and then hides committedSourceDabStrokes
- active drawing causes previously committed strokes to be displayed through a different renderer
- active frame display alternates between source replay and preview bitmap depending on cache state
```

The Phase 222 cache model may remain if useful, but its active-edit usage must be corrected.

## Documentation updates

Update documents as part of this phase.

Do not merely append vague notes.

Actively clean up or replace outdated wording.

### Update `docs/Current_Brush_Architecture.md`

Required changes:

1. Clarify that source commands may be stroke-like/vector-like, but visible brush display must be pixel-grid bitmap rasterized.
2. Replace or rewrite wording that says active stroke display uses `stroke/path/point data` if it can be interpreted as visible smooth vector/path drawing.
3. Add these concepts:

    * `BrushCommandRasterCache`
    * `BrushFrameEditComposite`
    * `ActiveStrokeRasterOverlay`
    * `BrushFramePreviewCache`
4. Clarify:

    * active frame uses `activeEditCompositeSurface + activeStrokeTempSurface`
    * inactive frames use preview/cache surfaces
    * cache/display surfaces are derived and not source of truth
5. Keep global undo rules unchanged.
6. Keep no-baking-on-pointer-release policy unchanged.
7. Remove or rewrite stale wording that implies Phase 222 active display behavior is correct.

### Update `docs/Current_Canvas_Cache_Storage_Architecture.md`

Required changes:

1. Replace the Phase 222 note if it currently suggests active display can prefer preview cache during editing.
2. Clarify the distinction between:

    * source data
    * command raster cache
    * active edit composite
    * inactive preview cache
    * playback preview cache
3. State that active editing display must not switch between preview cache and source replay while drawing.
4. State that display/composite surfaces may be cache images, but they are derived and not source of truth.
5. Keep `Frame` lightweight.

### Update `docs/Current_Docs_Index.md`

If needed, update the index to point to the revised brush/cache architecture files and Phase 223 task.

### Update `docs/Handoff_QuickAnimaker_v2_Current.md`

Only update section 5 or later.

Do not edit sections 0 through 4.

Add a concise Phase 223 note explaining the new active editing display direction.

## Implementation requirements

Implement the architecture in the production brush route.

Prefer adding small focused classes instead of expanding one large file.

Possible names:

```txt id="x0nrxj"
BrushCommandRasterCache
BrushFrameEditComposite
BrushFrameEditCompositeService
ActiveStrokeRasterOverlay
BrushPixelGridRasterizer
```

The exact names may differ, but the responsibilities must remain separated.

### Required behavior

The app must satisfy:

```txt id="83g1yv"
1. Active stroke looks bitmap-like while drawing.
2. Already committed strokes do not change visual style while drawing the next stroke.
3. Pointer movement updates only the active stroke overlay/surface, not the full frame.
4. Pointer release commits source data and updates the active edit composite, but does not source-bake.
5. Undo/redo changes visible commands and updates the derived composite.
6. Inactive preview cache is not used as the active editing display path.
7. Heavy bitmap/cache data stays outside Frame.
```

## Tests

Add or update behavior tests.

Tests should verify behavior and architecture boundaries, not exact prose.

Required tests:

```txt id="om29xd"
1. Active stroke display uses pixel-grid raster overlay, not path/vector painter display.
2. Committed strokes and active stroke use the same rasterizer path or produce the same bitmap-like display model.
3. Pointer move does not rebuild inactive preview cache.
4. Pointer move does not replay all committed source commands.
5. Pointer release stores source command and updates active edit composite.
6. Pointer release does not replace active display with inactive preview cache.
7. Undo hides command id and invalidates/recomposes active edit composite.
8. Redo restores command id and invalidates/recomposes active edit composite.
9. Inactive preview cache remains derived and is not source of truth.
10. Frame model still does not own command lists, bitmap surfaces, preview caches, or dirty state.
11. No `TileDelta` / `TileDeltaCommand` usage is introduced in brush runtime architecture.
```

Avoid brittle tests that assert exact documentation wording.

## Validation commands

If Dart/Flutter are available, run:

```bash id="42xf01"
dart format lib test
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If Dart/Flutter are not available, explicitly state that they were unavailable.

Do not claim validation succeeded unless the commands actually ran.

## PR title

```txt id="dm5igg"
Phase 223 — Pixel-grid active brush display architecture
```

## PR summary must include

The PR summary must explain:

```txt id="lfhd0u"
- source commands remain the undoable source of truth
- visible brush display is pixel-grid bitmap rasterized
- active editing display uses active edit composite + active stroke raster overlay
- inactive preview cache is not used as the active editing display path
- pointer release does not source-bake or flatten undoable strokes
- documentation was updated by replacing stale Phase 222 wording, not only appending notes
```
