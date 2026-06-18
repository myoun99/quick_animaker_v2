# Phase 113 Codex Task

## Title

Extract timeline horizontal offset clamp policy

## Goal

Separate the horizontal timeline offset clamp calculation from `LayerTimelineGrid` so the resize-tearing fix from PR165 is explicit, testable, and protected from future regressions.

This is a stabilization/refactor phase after PR165, PR166, and PR167.

## Current behavior to preserve

* PR165 horizontal resize offset clamp must remain unchanged.
* Widening the app window after horizontal scrolling must not tear the frame body.
* Frame cells, ruler/header cells, selected exposure outline, and hit testing must continue to use the same effective horizontal offset.
* PR166/PR167 selected exposure display-range outline behavior must remain unchanged.
* The selected exposure outline may continue beyond `Cut.duration` / `playbackFrameCount`.
* No `CustomPainter`.
* No UI behavior changes.

## Problem

`LayerTimelineGrid` currently owns both:

* horizontal scroll state
* effective offset calculation
* max offset calculation
* scroll controller correction scheduling
* virtualization plan input
* ruler translation
* ruler hit testing offset

This makes the resize fix harder to protect.

The pure calculation should be separated from the widget/controller side effects.

## New file

Create:

```txt
lib/src/ui/timeline/timeline_horizontal_offset_policy.dart
```

## Suggested API

```dart
import 'dart:math' as math;

class TimelineHorizontalOffsetResolution {
  const TimelineHorizontalOffsetResolution({
    required this.requestedOffset,
    required this.effectiveOffset,
    required this.maxOffset,
  });

  final double requestedOffset;
  final double effectiveOffset;
  final double maxOffset;

  bool get needsCorrection => requestedOffset != effectiveOffset;
}

TimelineHorizontalOffsetResolution resolveTimelineHorizontalOffset({
  required double requestedOffset,
  required double totalContentWidth,
  required double viewportWidth,
}) {
  final normalizedTotalContentWidth = math.max(0.0, totalContentWidth);
  final normalizedViewportWidth = math.max(0.0, viewportWidth);

  final maxOffset = math.max(
    0.0,
    normalizedTotalContentWidth - normalizedViewportWidth,
  );

  final effectiveOffset = requestedOffset.clamp(0.0, maxOffset).toDouble();

  return TimelineHorizontalOffsetResolution(
    requestedOffset: requestedOffset,
    effectiveOffset: effectiveOffset,
    maxOffset: maxOffset,
  );
}
```

Adjust names only if needed.

## Update LayerTimelineGrid

Update `_LayerTimelineGridState` so `_effectiveHorizontalScrollOffset(...)` delegates to the new policy.

Current behavior must remain the same.

Example:

```dart
double _effectiveHorizontalScrollOffset({
  required double requestedOffset,
  required double viewportWidth,
}) {
  final totalFrameContentWidth =
      _visibleFrameCount * LayerTimelineGrid._metrics.frameCellWidth;

  return resolveTimelineHorizontalOffset(
    requestedOffset: requestedOffset,
    totalContentWidth: totalFrameContentWidth,
    viewportWidth: viewportWidth,
  ).effectiveOffset;
}
```

Keep `_synchronizeHorizontalScrollController(...)` in `LayerTimelineGrid`.

Reason:

* The policy should be pure.
* Controller `jumpTo` scheduling is a widget side effect and should stay in the widget.

Do not change:

* ScrollController ownership
* `_horizontalScrollOffset`
* `_lastEffectiveHorizontalScrollOffset`
* `_scheduledHorizontalOffsetCorrection`
* ruler/body virtualization behavior
* selected exposure display range policy
* selected exposure outline rendering

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
* selected exposure display-range policy
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

```txt
test/ui/timeline_horizontal_offset_policy_test.dart
```

Test cases:

### 1. offset remains unchanged when within bounds

* `requestedOffset = 120`
* `totalContentWidth = 1000`
* `viewportWidth = 400`
* max offset is `600`
* effective offset is `120`
* `needsCorrection == false`

### 2. offset clamps to zero when negative

* `requestedOffset = -50`
* `totalContentWidth = 1000`
* `viewportWidth = 400`
* effective offset is `0`
* `needsCorrection == true`

### 3. offset clamps to max when requested is too large

* `requestedOffset = 900`
* `totalContentWidth = 1000`
* `viewportWidth = 400`
* max offset is `600`
* effective offset is `600`
* `needsCorrection == true`

### 4. offset clamps to zero when viewport is wider than content

* `requestedOffset = 300`
* `totalContentWidth = 1000`
* `viewportWidth = 2000`
* max offset is `0`
* effective offset is `0`
* `needsCorrection == true`

This protects the actual window-widening tearing bug.

### 5. zero content width always resolves to zero

* `requestedOffset = 100`
* `totalContentWidth = 0`
* `viewportWidth = 400`
* max offset is `0`
* effective offset is `0`

### 6. negative content or viewport values are normalized safely

* negative total content width should behave as `0`
* negative viewport width should behave as `0`
* no exception should be thrown

### 7. fractional offsets are preserved when valid

* `requestedOffset = 12.5`
* valid range
* effective offset remains `12.5`

## Existing widget tests

Existing `LayerTimelineGrid` widget tests should continue to pass.

Do not remove:

* PR165 resize tests
* PR166/PR167 display-range outline tests
* selected exposure outline tests
* ruler/body alignment tests

Update only import paths or helper expectations if needed.

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
* new horizontal offset policy file
* how `LayerTimelineGrid` now delegates pure offset clamp calculation
* confirmation that `_synchronizeHorizontalScrollController` remains widget-side
* confirmation that PR165 resize tearing fix remains unchanged
* confirmation that PR167 selected exposure display-range policy remains unchanged
* confirmation that `Cut.duration`, `playbackFrameCount`, and `authoredTimelineExtentFrameCount` semantics were not changed
* confirmation that no `CustomPainter` was introduced
* analyze result
* full test result
* git status summary
