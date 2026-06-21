# Phase 158 Codex Task

## Title

BrushDab color snapshot / RGBA color foundation

## Repository

```txt id="suihao"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="k3m8u9"
master
```

## Project type

```txt id="gqap7m"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 157.

Recent bitmap canvas / brush foundation phases:

```txt id="rs0s3x"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
Phase 157: BrushDab dirty region / dirty tile derivation foundation
```

Current long-term direction:

```txt id="uqo3vx"
QuickAnimaker v2 is bitmap-first.
Brush input becomes BrushDabSequence.
BrushDabSequence should eventually be rasterized into BitmapTile RGBA8888 pixel data.
BrushDab must be a complete planned brush stamp snapshot.
Future rasterizer should be able to rasterize from BrushDab data without needing mutable BrushSettings.
```

Phase 158 fixes an important foundation gap:

```txt id="ij5cj7"
BrushDab currently stores size / opacity / flow / hardness / tip shape,
but it does not store brush color.
```

That is not enough for future rasterization.

This phase adds color snapshot support to `BrushDab` and adds a small pure RGBA color helper for future BitmapTile RGBA8888 work.

This phase must not add pixel rasterization, BitmapTile mutation, BitmapSurface mutation, DirtyRegion generation changes, TileDeltaCommand generation, cache generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future drawing should eventually flow like this:

```txt id="av16xw"
BrushSettings.color
-> BrushDab.fromInputSample(...)
-> BrushDab.color
-> future RgbaColor.fromArgbInt(...)
-> future BitmapBrushRasterizer
-> future BitmapTile RGBA8888 pixels
```

This phase only creates / updates model-level color data:

```txt id="0javom"
BrushDab.color
RgbaColor
```

Meaning:

```txt id="7ec6kr"
BrushDab.color
= immutable ARGB int color snapshot copied from BrushSettings.color

RgbaColor
= pure helper for converting ARGB int brush color into RGBA components for future BitmapTile writes
```

This is model-only.

## Required references

Before editing, read:

```txt id="srl0uy"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
docs/Phase_153_Codex_Task.md
docs/Phase_154_Codex_Task.md
docs/Phase_155_Codex_Task.md
docs/Phase_156_Codex_Task.md
docs/Phase_157_Codex_Task.md
```

Also inspect:

```txt id="pz4uvx"
lib/src/models/brush_settings.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/services/brush_dab_placement.dart
lib/src/services/brush_dab_dirty_region.dart
lib/src/models/bitmap_tile.dart
test/models/brush_settings_test.dart
test/models/brush_dab_test.dart
test/models/brush_dab_sequence_test.dart
test/services/brush_dab_placement_test.dart
test/services/brush_dab_dirty_region_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add brush color snapshot foundations:

```txt id="olf0x8"
BrushDab.color
RgbaColor
```

The goal is to prepare the project for future bitmap brush rasterization while keeping this phase model-only.

## Strong scope rule

Allowed:

```txt id="yt47ex"
pure Dart model changes
BrushDab color field
BrushDab.fromInputSample copying BrushSettings.color
RgbaColor value object
ARGB int <-> RGBA component conversion
copyWith / equality / hashCode / toJson / fromJson
focused model tests
updating existing BrushDab / BrushDabSequence / BrushDabPlacement tests to include color
```

Not allowed:

```txt id="n5oxg6"
BitmapBrushRasterizer
pixel rasterization
pixel blending
BitmapTile pixel mutation
BitmapSurface mutation
DirtyRegion logic changes
DirtyTileSet logic changes
TileDeltaCommand generation
CacheInvalidationPlan generation
actual cache implementation
canvas UI
pointer event handling
gesture handling
CustomPainter
renderer
playback
UndoService
undo stack
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Color convention

Existing `BrushSettings.color` is an ARGB integer.

Use the same convention for `BrushDab.color`.

```txt id="f1qz6o"
0xAARRGGBB
```

BitmapTile pixels are RGBA8888 byte data.

Future rasterizer will need RGBA components:

```txt id="0ulzq2"
R
G
B
A
```

This phase should add a pure helper model for that conversion, but must not write pixels yet.

## Required production changes

### 1. Update BrushDab

Modify:

```txt id="otzvn6"
lib/src/models/brush_dab.dart
```

Add required field:

```dart id="x6lhjh"
final int color;
```

Recommended constructor position:

```dart id="81bqvk"
BrushDab({
  required this.center,
  required this.color,
  required this.size,
  required this.opacity,
  required this.flow,
  required this.hardness,
  required this.tipShape,
  required this.pressure,
  required this.sequence,
})
```

Required validation:

```txt id="atefyp"
color >= 0
color <= 0xFFFFFFFF
invalid color throws ArgumentError
```

Required behavior updates:

```txt id="h6t0pr"
- copyWith supports color
- toJson includes color
- fromJson reads color
- equality includes color
- hashCode includes color
- toString includes color
- BrushDab.fromInputSample copies settings.color into color
```

Important compatibility:

```txt id="dji1ne"
BrushDab.fromJson should tolerate legacy JSON without color by using BrushSettings default color 0xFF000000.
```

Reason:

```txt id="fbttrc"
BrushDab JSON is not final persistence yet, but tests / temporary debug data from Phase 156 may exist.
A legacy fallback avoids unnecessary breakage.
```

Do not add rasterization behavior to BrushDab.

Do not add pixel mutation helpers.

### 2. Add RgbaColor

Create:

```txt id="a46jsk"
lib/src/models/rgba_color.dart
```

Required fields:

```dart id="uz4leo"
final int r;
final int g;
final int b;
final int a;
```

Required validation:

```txt id="rnvxfn"
0 <= r <= 255
0 <= g <= 255
0 <= b <= 255
0 <= a <= 255
invalid values throw ArgumentError
```

Required factories:

```dart id="pfq2b3"
RgbaColor({
  required this.r,
  required this.g,
  required this.b,
  required this.a,
})

RgbaColor.fromArgbInt(int color)
```

ARGB conversion rule:

```txt id="bcxq9x"
a = (color >> 24) & 0xFF
r = (color >> 16) & 0xFF
g = (color >> 8) & 0xFF
b = color & 0xFF
```

Required helpers:

```dart id="1g8ase"
int toArgbInt()

List<int> toRgbaBytes()
```

Rules:

```txt id="uav8db"
toArgbInt returns 0xAARRGGBB
toRgbaBytes returns [r, g, b, a]
```

Required behavior:

```txt id="cmxblc"
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Important:

```txt id="rh7iox"
RgbaColor is a color conversion helper only.
It must not know about BitmapTile.
It must not mutate pixels.
```

## Required tests

### 1. Update BrushDab tests

Modify:

```txt id="klffo3"
test/models/brush_dab_test.dart
```

Add / update tests:

```txt id="vlm114"
creates with valid color
rejects negative color
rejects color greater than 0xFFFFFFFF
copyWith updates color
equality includes color
hashCode includes color
toJson/fromJson round-trips color
fromJson without color uses default black 0xFF000000
fromInputSample copies BrushSettings.color
```

Also update existing helper constructors in tests to provide a default color.

Default test color:

```txt id="vsifm2"
0xFF000000
```

Example alternate test color:

```txt id="gnkgnx"
0x80FF3366
```

### 2. Update BrushDabSequence tests if needed

Modify:

```txt id="ngqkz2"
test/models/brush_dab_sequence_test.dart
```

If test helper constructs BrushDab directly, update it to pass `color`.

Also add one small test if useful:

```txt id="45n4qz"
sequence JSON round-trip preserves dab color
```

### 3. Update BrushDabPlacement tests if needed

Modify:

```txt id="qchovr"
test/services/brush_dab_placement_test.dart
```

Add test:

```txt id="dld805"
placement preserves BrushSettings.color into every emitted dab
```

Example:

```txt id="rlnik5"
settings.color = 0x80FF3366
samples = [(0,0), (12,0)]
all emitted dabs have color 0x80FF3366
```

### 4. Add RgbaColor tests

Create:

```txt id="tjrgjv"
test/models/rgba_color_test.dart
```

Required tests:

```txt id="ijn47c"
creates with valid RGBA components
rejects r below 0
rejects r above 255
rejects g below 0
rejects g above 255
rejects b below 0
rejects b above 255
rejects a below 0
rejects a above 255
fromArgbInt converts 0xAARRGGBB to RGBA components
fromArgbInt rejects negative color
fromArgbInt rejects color greater than 0xFFFFFFFF
toArgbInt returns 0xAARRGGBB
toRgbaBytes returns [r, g, b, a]
copyWith updates r
copyWith updates g
copyWith updates b
copyWith updates a
equality includes all components
hashCode is value-based
toJson/fromJson round-trips
toString includes useful component data
```

Example conversion test:

```txt id="sj2u6o"
color = 0x80FF3366

a = 0x80
r = 0xFF
g = 0x33
b = 0x66

toRgbaBytes = [255, 51, 102, 128]
toArgbInt = 0x80FF3366
```

## Architecture rules

Brush color rules:

```txt id="89qvvl"
BrushSettings.color is the editable brush setting.
BrushDab.color is the immutable color snapshot used by future rasterization.
RgbaColor converts ARGB int to RGBA components.
RgbaColor does not write pixels.
BrushDab does not write pixels.
```

Bitmap storage boundary:

```txt id="bw5jid"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
```

Timeline/storyboard boundary:

```txt id="l3mpic"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="fmpgoh"
BitmapBrushRasterizer
pixel rasterization
pixel blending
BitmapTile mutation helpers for drawing
BitmapSurface drawing helpers
DirtyRegion generation changes
DirtyTileSet generation changes
TileDeltaCommand generation from dabs
CacheInvalidationPlan generation from dabs
actual cache implementation
LayerTileCache
FrameCompositeCache
PlaybackPreviewCache
renderer
playback implementation
UndoService
UndoStack
RedoStack
HistoryService
actual canvas UI
drawing canvas
pointer event handling
tablet input
gesture detector
zoom/pan UI integration
save/load
persistence service
tile upload
CustomPainter changes
Provider
Riverpod
Bloc
ChangeNotifier
onion skin
export
Photoshop-style / ABR brush import
```

## Expected changed files

Likely:

```txt id="f2hs27"
lib/src/models/brush_dab.dart
lib/src/models/rgba_color.dart
test/models/brush_dab_test.dart
test/models/brush_dab_sequence_test.dart
test/services/brush_dab_placement_test.dart
test/models/rgba_color_test.dart
```

Maybe also:

```txt id="lqgshe"
test/services/brush_dab_dirty_region_test.dart
```

only if direct `BrushDab(...)` helpers need to pass `color`.

Avoid touching unrelated files.

## Required checks

Run:

```bash id="v23bir"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="w2scgr"
- changed files
- BrushDab color field and validation
- BrushDab.fromInputSample color snapshot behavior
- BrushDab JSON legacy fallback behavior
- RgbaColor fields and validation
- RgbaColor ARGB <-> RGBA conversion behavior
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BitmapTile pixel mutation was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no DirtyRegion logic changes were added
- confirmation that no TileDeltaCommand generation was added
- confirmation that no CacheInvalidationPlan generation was added
- confirmation that no cache implementation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 158 is complete when:

```txt id="z3hlkm"
- BrushDab has a validated color field.
- BrushDab.fromInputSample copies BrushSettings.color.
- BrushDab copyWith / equality / hashCode / JSON include color.
- BrushDab.fromJson tolerates missing color by using 0xFF000000.
- RgbaColor exists and is tested.
- RgbaColor converts 0xAARRGGBB to RGBA components correctly.
- RgbaColor converts RGBA components back to 0xAARRGGBB correctly.
- RgbaColor.toRgbaBytes returns [r, g, b, a].
- Existing Phase 156 BrushDab / BrushDabPlacement tests still pass.
- Existing Phase 157 BrushDab dirty region tests still pass.
- Existing bitmap / dirty region / tile delta / cache invalidation tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No pixel rasterization was added.
- No drawing canvas UI was added.
- No TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
```

## Manual check list

This phase is model-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="m5nkgx"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
