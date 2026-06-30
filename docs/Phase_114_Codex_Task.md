# Phase 114 Codex Task

## Title

Extract timeline frame coordinate policy

## Goal

Separate timeline frame coordinate conversion from `LayerTimelineGrid` so frame index / x-position calculations are explicit, reusable, and protected from future off-by-one or scroll-offset regressions.

This is a stabilization/refactor phase after PR165, PR166, PR167, and PR168.

## Current behavior to preserve

* PR165 horizontal resize offset clamp must remain unchanged.
* PR168 horizontal offset policy must remain unchanged.
* PR167 selected exposure display-range policy must remain unchanged.
* Ruler scrub behavior must remain unchanged.
* Frame body / ruler / selected outline alignment must remain unchanged.
* No UI behavior change.
* No `CustomPainter`.

## Problem

Timeline frame coordinate calculations are still scattered across `LayerTimelineGrid`.

Examples of concepts that should be centralized:

* local x position to frame index
* frame index to local x position inside the visible row
* frame index to content x position
* clamping frame index to visible frame count
* using the same horizontal offset for coordinate conversion as layout/rendering

If these remain inline, future timeline changes can easily reintroduce bugs where:

* ruler click selects the wrong frame
* resize changes hit testing behavior
* body and ruler use different coordinate assumptions
* selected outline visually aligns but hit testing uses stale offsets

## New file

Create:

```txt id="xassgq"
lib/src/ui/timeline/timeline_frame_coordinate_policy.dart
```

## Suggested API

```dart id="otd7tv"
import 'dart:math' as math;

int? frameIndexFromLocalX({
  required double localX,
  required double horizontalScrollOffset,
  required double frameCellWidth,
  required int visibleFrameCount,
}) {
  if (visibleFrameCount <= 0 || frameCellWidth <= 0) {
    return null;
  }

  final frameIndex =
      ((localX + horizontalScrollOffset) / frameCellWidth).floor();

  return clampFrameIndex(
    frameIndex: frameIndex,
    visibleFrameCount: visibleFrameCount,
  );
}

int? clampFrameIndex({
  required int frameIndex,
  required int visibleFrameCount,
}) {
  if (visibleFrameCount <= 0) {
    return null;
  }

  return frameIndex.clamp(0, visibleFrameCount - 1).toInt();
}

double frameContentX({
  required int frameIndex,
  required double frameCellWidth,
}) {
  return frameIndex * frameCellWidth;
}

double frameVisibleX({
  required int frameIndex,
  required int frameStartIndex,
  required double frameCellWidth,
  required double leadingFrameSpacerWidth,
}) {
  return leadingFrameSpacerWidth +
      (frameIndex - frameStartIndex) * frameCellWidth;
}

double frameRangeVisibleWidth({
  required int startFrameIndex,
  required int endFrameIndexExclusive,
  required double frameCellWidth,
}) {
  return math.max(0, endFrameIndexExclusive - startFrameIndex) *
      frameCellWidth;
}
```

Adjust names if needed, but keep the concepts separated and pure.

## Update LayerTimelineGrid

Use the new policy in `LayerTimelineGrid` for existing coordinate conversion.

At minimum:

1. Replace `_clampedRulerFrameIndex(...)` with `clampFrameIndex(...)` or remove the wrapper if no longer needed.

2. Replace `_frameIndexForRulerLocalX(...)` logic with `frameIndexFromLocalX(...)`.

Current behavior must remain:

* It must use `_lastEffectiveHorizontalScrollOffset`, not raw `_horizontalScrollOffset`.
* It must use `LayerTimelineGrid._metrics.frameCellWidth`.
* It must clamp to `_visibleFrameCount`.

3. Use `frameVisibleX(...)` and `frameRangeVisibleWidth(...)` for selected exposure outline positioning if appropriate.

Do not change the visual result.

Current selected outline positioning is conceptually:

```dart id="18m58e"
left = leadingFrameSpacerWidth +
    (visibleStartFrameIndex - frameStartIndex) * frameCellWidth;

width = (visibleEndFrameIndexExclusive - visibleStartFrameIndex) *
    frameCellWidth;
```

Move that math into the coordinate policy if possible.

## Do not change

* `Project`
* `Track`
* `Cut`
* `Layer`
* `Frame`
* `Stroke`
* `Cut.duration`
* `playbackFrameCount`
* `TimelineController.authoredTimelineExtentFrameCount`
* `TimelineFrameRange`
* `TimelineHorizontalOffsetPolicy`
* `SelectedExposureDisplayRangePolicy`
* timeline virtualization behavior
* timeline visual style
* selected exposure outline semantics
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel` or `LayerTimelineGrid`.

Do not use `CustomPainter`.

## Tests

Add pure unit tests for the new policy file.

Create:

```txt id="7pz51g"
test/ui/timeline_frame_coordinate_policy_test.dart
```

Test cases:

### 1. local x converts to frame index without scroll

* `localX = 0`, `offset = 0`, `cellWidth = 48`, `visibleFrameCount = 10`
* expect frame `0`
* `localX = 47.9`
* expect frame `0`
* `localX = 48`
* expect frame `1`

### 2. local x converts to frame index with horizontal scroll

* `localX = 0`
* `horizontalScrollOffset = 96`
* `cellWidth = 48`
* expect frame `2`

### 3. frame index clamps below zero

* `localX = -100`
* expect frame `0`

### 4. frame index clamps above visible count

* large localX
* `visibleFrameCount = 10`
* expect frame `9`

### 5. empty visible frame count returns null

* `visibleFrameCount = 0`
* expect null

### 6. invalid cell width returns null

* `frameCellWidth = 0`
* expect null

### 7. frameContentX returns content-space x

* frame 0 => 0
* frame 5 with width 48 => 240

### 8. frameVisibleX returns row-space x with leading spacer

* `frameIndex = 20`
* `frameStartIndex = 18`
* `frameCellWidth = 48`
* `leadingFrameSpacerWidth = 96`
* expect `96 + 2 * 48`

### 9. frameRangeVisibleWidth returns range width

* start 10, end 13, width 48
* expect 144

### 10. reversed or empty range width returns zero

* start 13, end 10
* expect 0
* start 10, end 10
* expect 0

## Existing widget tests

Existing widget tests should continue to pass.

Do not remove:

* PR165 resize tests
* PR166 / PR167 display-range outline tests
* PR168 horizontal offset policy tests
* ruler/body alignment tests
* selected exposure outline tests

Update only imports or helper expectations if necessary.

## Required checks

Run:

```bash id="goz4y8"
dart format lib test
flutter analyze
flutter test
git status
```

## Report back

Report:

* changed files
* new frame coordinate policy file
* how `LayerTimelineGrid` now delegates frame coordinate conversion
* confirmation that ruler scrub still uses effective horizontal offset
* confirmation that selected exposure outline position/width behavior is unchanged
* confirmation that PR165/PR168 resize clamp behavior is unchanged
* confirmation that PR167 selected exposure display-range policy is unchanged
* confirmation that no `CustomPainter` was introduced
* analyze result
* full test result
* git status summary
