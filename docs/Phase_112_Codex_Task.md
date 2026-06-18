# Phase 112 Codex Task

## Title

Extract selected exposure display-range policy

## Goal

Separate selected exposure outline range calculation from `LayerTimelineGrid` so display-range visual semantics are explicit, tested, and protected from future regressions.

This is a stabilization/refactor phase after PR165 and PR166.

## Current behavior to preserve

* PR165 horizontal resize offset clamp must remain unchanged.
* PR166 selected exposure outline must use display/visible range semantics.
* The selected exposure outline may continue beyond `Cut.duration` / `playbackFrameCount`.
* The selected exposure outline must not be bounded by `authoredTimelineExtentFrameCount`.
* The selected exposure outline must remain clamped only for rendering to the visible frame range.
* Internal frame dividers inside the selected exposure range must remain normal.
* Do not use `CustomPainter`.

## Problem

`LayerTimelineGrid` currently mixes several concepts:

* `playbackFrameCount`
* visible frame range
* `frameStartIndex` / `frameEndIndexExclusive`
* selected exposure range resolution
* overlay clamp
* horizontal virtualization/layout

This has caused repeated confusion between:

* authored/data extent
* playback / `Cut.duration`
* display/visible range
* selected outline visual range

## Correct design

Selected exposure outline is a display-range visual highlight.

Its resolution should be based on the display resolve window, not `Cut.duration`, `playbackFrameCount`, or authored extent.

## New file

Create:

```txt
lib/src/ui/timeline/selected_exposure_display_range_policy.dart
```

## Suggested API

```dart
import 'dart:math' as math;

import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_range_resolver.dart';

class SelectedExposureDisplayRange {
  const SelectedExposureDisplayRange({
    required this.resolvedRange,
    required this.visibleStartFrameIndex,
    required this.visibleEndFrameIndexExclusive,
  });

  final TimelineExposureRange resolvedRange;
  final int visibleStartFrameIndex;
  final int visibleEndFrameIndexExclusive;

  bool get hasVisibleIntersection =>
      visibleStartFrameIndex < visibleEndFrameIndexExclusive;
}

SelectedExposureDisplayRange resolveSelectedExposureDisplayRange({
  required bool active,
  required int currentFrameIndex,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
}) {
  if (!active) {
    return const SelectedExposureDisplayRange(
      resolvedRange: TimelineExposureRange.none,
      visibleStartFrameIndex: 0,
      visibleEndFrameIndexExclusive: 0,
    );
  }

  final resolvedRange = resolveTimelineExposureRange(
    selectedFrameIndex: currentFrameIndex,
    minFrameIndex: 0,
    maxFrameIndexExclusive: math.max(
      frameEndIndexExclusive,
      currentFrameIndex + 1,
    ),
    exposureStateAt: exposureStateAt,
  );

  if (!resolvedRange.isBlock) {
    return SelectedExposureDisplayRange(
      resolvedRange: resolvedRange,
      visibleStartFrameIndex: 0,
      visibleEndFrameIndexExclusive: 0,
    );
  }

  final visibleStartFrameIndex = math.max(
    resolvedRange.startFrameIndex,
    frameStartIndex,
  );

  final visibleEndFrameIndexExclusive = math.min(
    resolvedRange.endFrameIndexExclusive,
    frameEndIndexExclusive,
  );

  return SelectedExposureDisplayRange(
    resolvedRange: resolvedRange,
    visibleStartFrameIndex: visibleStartFrameIndex,
    visibleEndFrameIndexExclusive: visibleEndFrameIndexExclusive,
  );
}
```

Adjust names/imports if the current project uses slightly different type names.

## Behavior

The helper must:

* Return no visible intersection when `active == false`.
* Resolve selected exposure range with:

```dart
minFrameIndex: 0
maxFrameIndexExclusive: math.max(frameEndIndexExclusive, currentFrameIndex + 1)
```

* Not accept `authoredTimelineExtentFrameCount`.
* Not accept `playbackFrameCount`.
* Not use `Cut.duration`.
* Clamp only the returned visible intersection:

```dart
visibleStartFrameIndex = max(resolvedRange.startFrameIndex, frameStartIndex)
visibleEndFrameIndexExclusive = min(resolvedRange.endFrameIndexExclusive, frameEndIndexExclusive)
```

## Update LayerTimelineGrid

In `_FrameCellsRow`, replace the inline selected exposure range and clamp logic with the new helper.

Keep the existing overlay rendering style unchanged:

* row-level `IgnorePointer`
* `DecoratedBox`
* transparent fill
* red outline
* no `CustomPainter`
* normal internal frame dividers

Do not change the PR165 horizontal offset clamp.

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
* timeline virtualization behavior
* selected exposure outline visual style
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel` or `LayerTimelineGrid`.

## Tests

Add pure unit tests for the new policy file.

Create:

```txt
test/ui/selected_exposure_display_range_policy_test.dart
```

Test cases:

### 1. inactive returns no visible intersection

* `active: false`
* any current frame
* any exposure states
* expect `resolvedRange` is none
* expect `hasVisibleIntersection == false`

### 2. drawing start resolves forward through visible display range

* `currentFrameIndex = 10`
* `frameStartIndex = 0`
* `frameEndIndexExclusive = 48`
* exposure:

    * `10 => drawingStart`
    * `11..47 => heldExposure`
* expect resolved range `10..48`
* expect visible intersection `10..48`

### 3. held exposure resolves backward and forward through visible display range

* `currentFrameIndex = 26`
* `frameStartIndex = 0`
* `frameEndIndexExclusive = 48`
* exposure:

    * `2 => blankStart`
    * `3..47 => blankHeld`
* expect resolved range `2..48`
* expect visible intersection `2..48`

This protects the case where selecting frame 26 must not stop the outline at frame 26.

### 4. selected range may continue beyond playback duration

Do not pass `playbackFrameCount` to this helper.

* `frameEndIndexExclusive = 48`
* `currentFrameIndex = 26`
* exposure continues through 47
* expect the range can continue to 48

### 5. visible intersection clamps to current virtualized frame window

* resolved range would be `2..48`
* `frameStartIndex = 20`
* `frameEndIndexExclusive = 36`
* expect visible intersection `20..36`

### 6. no visible intersection when resolved range is offscreen

* resolved range would be `2..10`
* `frameStartIndex = 20`
* `frameEndIndexExclusive = 36`
* expect no visible intersection

### 7. resolver upper bound uses display frameEndIndexExclusive

* `currentFrameIndex = 26`
* `frameEndIndexExclusive = 48`
* exposure continues through 47
* expect it reaches 48, not `currentFrameIndex + 1`

## Existing widget tests

Update existing `LayerTimelineGrid` widget tests only as needed.

They should continue to pass.

Keep:

* PR165 resize tests
* PR166 display-range outline tests

Do not add source-file string inspection tests.

Do not import `dart:io` in widget tests.

## Required checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

## Report back

Report:

* changed files
* new helper/policy file
* how `LayerTimelineGrid` now delegates selected exposure display-range resolution
* confirmation that `authoredTimelineExtentFrameCount` is not used by selected outline display-range policy
* confirmation that `playbackFrameCount` / `Cut.duration` are not used by selected outline display-range policy
* confirmation that PR165 horizontal resize clamp remains unchanged
* confirmation that selected outline still continues through visible display range
* confirmation that no `CustomPainter` was introduced
* analyze result
* full test result
* git status summary
