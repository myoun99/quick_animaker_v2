# Phase 130 Codex Task

## Title

Extract timeline horizontal scrollbar rail widget

## Goal

Extract the bottom horizontal scrollbar rail from `LayerTimelineGrid` into a dedicated widget file.

This is a refactor/stabilization phase after PR183 and PR184.

No visual behavior or scroll behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="vq1cvo"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and stabilized timeline scrollbar/boundary responsibilities:

* PR179: `TimelineRulerCutEndBoundary`
* PR180: `TimelineBodyCutEndBoundary`
* PR181: cut-end boundary widget tests
* PR183: `TimelineVerticalScrollbarSlot` / `TimelineVerticalScrollbarRail`
* PR184: vertical scrollbar rail tests

`LayerTimelineGrid` still owns the bottom horizontal scrollbar rail implementation.

This phase extracts the bottom horizontal scrollbar rail into a dedicated widget while preserving existing horizontal scroll behavior.

## New file

Create:

```txt id="xuy801"
lib/src/ui/timeline/timeline_horizontal_scrollbar_rail.dart
```

## Widget to create

Create:

```dart id="t8m4fq"
class TimelineHorizontalScrollbarRail extends StatelessWidget
```

Use the current implementation in `LayerTimelineGrid` as the source of truth.

If the current private widget is named something like:

```txt id="m2ry63"
_BottomHorizontalScrollbarRail
```

move that implementation into the new public widget.

## What to extract

Move only the existing bottom horizontal scrollbar rail rendering from:

```txt id="0hnt9f"
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new widget.

Stable key to preserve:

```txt id="iax355"
timeline-horizontal-scrollbar
```

Also preserve any existing internal stable keys if they already exist.

Do not invent new public keys unless required by existing tests.

## Scope

This phase is only for extracting the bottom horizontal scrollbar rail widget.

Do not extract:

* vertical scrollbar rail
* vertical scrollbar slot
* frame grid viewport
* frame scroll content
* layer controls rows
* frame cells rows
* frame header row
* ruler
* cut-end boundary widgets
* selected exposure outline

Those are separate concerns.

## Required behavior to preserve

Preserve exactly:

* `timeline-horizontal-scrollbar` key
* current width behavior
* current height behavior
* current placement under the frame grid only
* current relationship with frame grid horizontal scroll
* current relationship with ruler/header horizontal scroll
* current scroll controller usage
* current scrollbar thumb visibility behavior
* current track tap behavior, if any
* current thumb drag behavior, if any
* current scroll physics, if any
* current behavior when the visible frame range changes
* current behavior when the viewport width changes
* current behavior after resize clamp from earlier phases

## Important semantic rule

The horizontal scrollbar rail is a layout/control widget only.

It must not affect:

* `Cut.duration`
* authored/data extent
* visible frame range semantics
* playback frame range semantics
* selected exposure display range
* editability after `Cut.duration`
* frame selection
* layer selection

Do not introduce any timeline range logic into the new widget.

Do not use `authoredTimelineExtentFrameCount` in the new widget.

## Responsibility split

`LayerTimelineGrid` should remain responsible for:

* owning horizontal scroll controller / horizontal offset state if it currently does
* horizontal scroll synchronization
* vertical scroll synchronization
* viewport size calculation
* virtualization plan creation
* frame range calculation
* layer row iteration
* grid/body composition
* passing existing controller, offset, viewport width, content width, or callbacks to the new rail widget

`TimelineHorizontalScrollbarRail` should be responsible only for:

* rendering the bottom horizontal scrollbar rail
* preserving stable keys
* composing the existing track/thumb structure
* receiving already-created controllers/callbacks/values from `LayerTimelineGrid`

## API guideline

Prefer a minimal API that preserves the current implementation.

Possible shape:

```dart id="kyf5dc"
class TimelineHorizontalScrollbarRail extends StatelessWidget {
  const TimelineHorizontalScrollbarRail({
    super.key,
    required this.controller,
    required this.viewportWidth,
    required this.contentWidth,
    required this.height,
  });

  final ScrollController controller;
  final double viewportWidth;
  final double contentWidth;
  final double height;
}
```

Do not force this exact API if the existing code needs different values.

Use the minimal parameters required by the current implementation.

Do not create scroll controllers inside the new widget if they are currently owned by `LayerTimelineGrid`.

Do not move horizontal scroll synchronization logic into the new widget.

Do not move `TimelineHorizontalOffsetPolicy` responsibilities into the new widget.

## Update LayerTimelineGrid

Update:

```txt id="q392bq"
lib/src/ui/timeline/layer_timeline_grid.dart
```

so it imports:

```dart id="z5eztk"
import 'timeline_horizontal_scrollbar_rail.dart';
```

Then replace the old inline/private bottom horizontal scrollbar rail code with:

```dart id="d6v0vu"
TimelineHorizontalScrollbarRail(...)
```

Pass existing values through unchanged.

After extraction, remove only the old inline/private horizontal scrollbar rail code from `layer_timeline_grid.dart`.

## Do not change

Do not change runtime behavior.

Do not change:

* `TimelineVerticalScrollbarSlot`
* `TimelineVerticalScrollbarRail`
* `TimelineLayerControlsHeader`
* `TimelineLayerControlsRow`
* `TimelineFrameHeaderRow`
* `TimelineRulerCutEndBoundary`
* `TimelineBodyCutEndBoundary`
* `TimelineFrameRuler`
* `TimelineFrameCell`
* `TimelineFrameCellsRow`
* `TimelineSelectedExposureOutline`
* `TimelineFrameCoordinatePolicy`
* `TimelineHorizontalOffsetPolicy`
* `SelectedExposureDisplayRangePolicy`
* `Cut.duration`
* `playbackFrameCount`
* `TimelineController.authoredTimelineExtentFrameCount`

Do not change:

* horizontal scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* bottom horizontal scrollbar behavior
* vertical scrollbar behavior
* frame ruler click/drag/scrub behavior
* layer row behavior
* frame cell behavior
* selected exposure outline behavior
* cut-end boundary behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="trhp7f"
TimelinePanel
LayerTimelineGrid
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
TimelineLayerControlsHeader
TimelineLayerControlsRow
TimelineVerticalScrollbarRail
TimelineHorizontalScrollbarRail
```

Do not use `CustomPainter`.

## Tests

No new tests are required if this is a pure extraction.

Existing tests must continue to pass.

Do not remove or weaken existing tests:

* PR165 resize tests
* PR166/PR167 selected exposure display-range tests
* PR168 horizontal offset policy tests
* PR169 frame coordinate policy tests
* PR172 selected exposure outline widget tests
* PR178 frame header row tests
* PR181 cut-end boundary widget tests
* PR182 layer controls widget tests
* PR184 vertical scrollbar rail tests
* ruler/body alignment tests
* horizontal scrollbar tests, if any

If adding a focused smoke test is simple, add:

```txt id="y0rxlh"
test/ui/timeline_horizontal_scrollbar_rail_test.dart
```

Suggested optional checks:

* `timeline-horizontal-scrollbar` exists exactly once
* provided controller/value is passed through
* provided child/track/thumb renders if applicable

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="j9g42a"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="rt3z91"
1. Bottom horizontal scrollbar appears under the frame grid only.
2. Horizontal scrollbar does not appear under the layer controls rail.
3. Dragging the horizontal scrollbar thumb scrolls frame cells horizontally.
4. Horizontal scrolling moves ruler/header/frame rows together.
5. Vertical scrolling still moves layer rows and frame rows together.
6. Sticky frame ruler/header does not vertically scroll.
7. Sticky + Layer header does not vertically scroll.
8. Layer controls rail and frame grid row alignment is unchanged.
9. Selected exposure outline still aligns with frame cells after horizontal scrolling.
10. Cut-end boundaries still align after horizontal and vertical scrolling.
11. Resizing the timeline viewport still clamps horizontal offset correctly.
```

## Report back

Report:

* changed files
* new horizontal scrollbar rail widget file
* whether optional test file was added
* how `LayerTimelineGrid` now delegates horizontal scrollbar rail rendering
* confirmation that `timeline-horizontal-scrollbar` key did not change
* confirmation that horizontal scroll controller ownership did not change
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
