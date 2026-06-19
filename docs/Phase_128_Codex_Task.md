# Phase 128 Codex Task

## Title

Extract timeline vertical scrollbar rail widget

## Goal

Extract the vertical scrollbar slot/rail from `LayerTimelineGrid` into a dedicated widget file.

This is a refactor/stabilization phase after PR175 through PR182.

No visual behavior or scroll behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="nxxo8g"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and stabilized several timeline UI pieces:

* `TimelineFrameCell`
* `TimelineFrameCellsRow`
* `TimelineLayerControlsRow`
* `TimelineLayerControlsHeader`
* `TimelineFrameHeaderRow`
* `TimelineRulerCutEndBoundary`
* `TimelineBodyCutEndBoundary`

`LayerTimelineGrid` still owns too much layout composition.

One remaining visual/layout responsibility is the vertical scrollbar slot between the layer controls rail and the frame grid.

This phase extracts that vertical scrollbar rail into a dedicated widget while preserving existing scroll behavior.

## New file

Create:

```txt id="s3x1gx"
lib/src/ui/timeline/timeline_vertical_scrollbar_rail.dart
```

## Widget to create

Create:

```dart id="i46dxz"
class TimelineVerticalScrollbarRail extends StatelessWidget
```

Use the current implementation in `LayerTimelineGrid` as the source of truth.

## What to extract

Move only the existing vertical scrollbar slot/rail rendering from:

```txt id="n7vyfd"
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new widget.

Likely stable keys involved:

```txt id="85fpal"
timeline-vertical-scrollbar-slot
timeline-vertical-scrollbar
```

Preserve those keys exactly.

## Scope

This phase is only for extracting the vertical scrollbar rail/slot widget.

Do not extract:

* horizontal scrollbar
* frame grid viewport
* layer controls rows
* frame cells rows
* frame header row
* ruler
* cut-end boundary widgets
* selected exposure outline

Those are separate concerns.

## Required behavior to preserve

Preserve exactly:

* `timeline-vertical-scrollbar-slot` key
* `timeline-vertical-scrollbar` key
* current width
* current height behavior
* current placement between layer controls rail and frame grid
* current body-only vertical scrolling behavior
* current scroll controller usage
* current scrollbar thumb visibility behavior
* current scrollbar notification behavior, if any
* current scroll physics, if any
* current relationship with horizontal scrolling
* current relationship with sticky header/ruler

## Important semantic rule

The vertical scrollbar rail is a layout/control widget only.

It must not affect:

* `Cut.duration`
* authored/data extent
* visible frame range
* playback frame range
* selected exposure display range
* editability after `Cut.duration`
* frame selection
* layer selection

Do not introduce any timeline range logic into the new widget.

Do not use `authoredTimelineExtentFrameCount` in the new widget.

## Responsibility split

`LayerTimelineGrid` should remain responsible for:

* owning scroll controllers
* synchronization between body scroll and scrollbar
* virtualization plan creation
* frame range calculation
* layer row iteration
* grid/body composition
* passing the existing controller and child/widget values to the new rail widget

`TimelineVerticalScrollbarRail` should be responsible only for:

* rendering the vertical scrollbar slot/rail
* preserving stable keys
* composing the existing `Scrollbar` / scrollbar child structure
* receiving already-created controllers or child widgets from `LayerTimelineGrid`

## API guideline

Prefer a minimal API that preserves current behavior.

Possible shape:

```dart id="7arfr4"
class TimelineVerticalScrollbarRail extends StatelessWidget {
  const TimelineVerticalScrollbarRail({
    super.key,
    required this.scrollController,
    required this.child,
    required this.width,
  });

  final ScrollController scrollController;
  final Widget child;
  final double width;
}
```

But do not force this exact API if the existing code needs different values.

Use the minimal parameters required by the current implementation.

Do not create scroll controllers inside the new widget if they are currently owned by `LayerTimelineGrid`.

Do not move scroll synchronization logic into the new widget.

## Update LayerTimelineGrid

Update:

```txt id="92n96t"
lib/src/ui/timeline/layer_timeline_grid.dart
```

so it imports:

```dart id="0tml1q"
import 'timeline_vertical_scrollbar_rail.dart';
```

Then replace the old inline vertical scrollbar slot/rail code with:

```dart id="qwtthy"
TimelineVerticalScrollbarRail(...)
```

Pass existing values through unchanged.

After extraction, remove only the old inline vertical scrollbar slot/rail code from `layer_timeline_grid.dart`.

## Do not change

Do not change runtime behavior.

Do not change:

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

* vertical scroll controller ownership
* vertical scroll synchronization
* horizontal scroll synchronization
* sticky header/ruler behavior
* body-only vertical scrollbar behavior
* frame ruler click/drag/scrub behavior
* layer row behavior
* frame cell behavior
* selected exposure outline behavior
* cut-end boundary behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="yfym72"
TimelinePanel
LayerTimelineGrid
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
TimelineLayerControlsHeader
TimelineLayerControlsRow
TimelineVerticalScrollbarRail
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
* ruler/body alignment tests
* scrollbar tests, if any

If adding a focused smoke test is simple, add:

```txt id="qxckqx"
test/ui/timeline_vertical_scrollbar_rail_test.dart
```

Suggested optional checks:

* `timeline-vertical-scrollbar-slot` exists exactly once
* `timeline-vertical-scrollbar` exists exactly once
* provided child renders
* provided controller is passed to the `Scrollbar`

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="2swrnd"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="6zvktt"
1. Timeline vertical scrollbar appears in the same slot as before.
2. Vertical scrolling moves layer rows and frame rows together.
3. Sticky frame ruler/header does not vertically scroll.
4. Sticky + Layer header does not vertically scroll.
5. Horizontal scrolling still moves ruler/header/frame rows together.
6. Bottom horizontal scrollbar still works.
7. Layer controls rail and frame grid row alignment is unchanged.
8. Selected exposure outline still aligns with frame cells.
9. Cut-end boundaries still align after vertical and horizontal scrolling.
```

## Report back

Report:

* changed files
* new vertical scrollbar rail widget file
* whether optional test file was added
* how `LayerTimelineGrid` now delegates vertical scrollbar rail rendering
* confirmation that `timeline-vertical-scrollbar-slot` key did not change
* confirmation that `timeline-vertical-scrollbar` key did not change
* confirmation that scroll controller ownership did not change
* confirmation that vertical scroll behavior did not change
* confirmation that horizontal scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
