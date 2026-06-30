# Phase 136 Codex Task

## Title

Extract timeline frame grid stack widget

## Goal

Extract the frame grid stack composition from `LayerTimelineGrid` into a dedicated widget file.

This is a refactor/stabilization phase after PR189 and PR190.

No visual behavior, scroll behavior, selection behavior, or timeline range behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="o57qk0"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and stabilized:

* `TimelineFrameScrollViewport`
* `TimelineFrameRowsScrollBody`

Inside `LayerTimelineGrid`, the frame scroll content still composes a stack of frame-grid children inline.

That stack currently contains responsibilities such as:

```txt id="282z0l"
- TimelineFrameRowsScrollBody
- TimelineBodyCutEndBoundary
- conditional TimelinePlayhead overlay
```

This phase extracts only the stack composition wrapper so `LayerTimelineGrid` becomes smaller while retaining all calculations and timeline semantics in `LayerTimelineGrid`.

## New file

Create:

```txt id="9l1x69"
lib/src/ui/timeline/timeline_frame_grid_stack.dart
```

## Widget to create

Create:

```dart id="l321yp"
class TimelineFrameGridStack extends StatelessWidget
```

Use the current implementation in `LayerTimelineGrid` as the source of truth.

## What to extract

Move only the frame grid `Stack(...)` composition currently passed as the `child` of `TimelineFrameScrollViewport`.

The extracted widget should render the same stack children in the same order:

```txt id="m0251j"
1. TimelineFrameRowsScrollBody
2. TimelineBodyCutEndBoundary
3. conditional TimelinePlayhead overlay
```

Preserve child order exactly.

Do not add or remove stack children.

Do not change positioning.

## Scope

This phase is only for extracting the frame grid stack composition.

Do not extract or change:

* `TimelineFrameScrollViewport`
* `TimelineFrameRowsScrollBody`
* `TimelineBodyCutEndBoundary`
* `TimelinePlayhead`
* selected exposure outline
* frame cells
* frame cells row
* frame ruler
* frame header row
* layer controls rail
* vertical scrollbar
* horizontal scrollbar
* virtualization adapter
* frame range policies
* horizontal offset policies

Those are separate concerns.

## Stable keys to preserve

This phase should not introduce new public timeline keys unless necessary.

Existing keys must remain unchanged, especially:

```txt id="eip0hk"
timeline-frame-rows-scroll-body
timeline-cut-end-boundary
timeline-playhead
timeline-playhead-column
```

Do not duplicate any stable key.

Do not change existing row/cell keys generated downstream:

```txt id="sy0dzj"
timeline-frame-row-area-<layerId>
timeline-cell-<layerId>-<frameIndex>
timeline-selected-exposure-range-outline-<layerId>
```

## Required behavior to preserve

Preserve exactly:

* stack child order
* frame rows rendering
* cut-end boundary rendering
* cut-end boundary position
* playhead rendering
* playhead visibility condition
* playhead position and width behavior
* selected exposure outline behavior
* frame cell behavior
* row/cell key behavior
* empty layer placeholder behavior
* horizontal scroll behavior
* vertical scroll behavior
* row alignment with layer controls rail
* timeline resize/clamp behavior

## Important semantic rule

The frame grid stack is a layout composition widget only.

It must not affect:

* `Cut.duration`
* authored/data extent
* visible frame range semantics
* playback frame range semantics
* selected exposure display range
* editability after `Cut.duration`
* frame selection semantics
* layer selection semantics

Do not introduce any timeline range logic into the new widget.

Do not use `authoredTimelineExtentFrameCount` in the new widget.

## Responsibility split

`LayerTimelineGrid` should remain responsible for:

* scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* viewport size calculation
* content width calculation
* virtualization plan creation
* frame range calculation
* cut-end boundary x calculation
* playhead visibility condition
* playhead frame range values
* selected exposure outline inputs through row/cell widgets
* passing already-calculated values to the new stack widget

`TimelineFrameGridStack` should be responsible only for:

* rendering a `Stack`
* placing `TimelineFrameRowsScrollBody`
* placing `TimelineBodyCutEndBoundary`
* placing the provided/parameterized `TimelinePlayhead` overlay when requested
* preserving the same visual child order as before

## API guideline

Prefer a minimal API.

Possible shape:

```dart id="8k7wzi"
class TimelineFrameGridStack extends StatelessWidget {
  const TimelineFrameGridStack({
    super.key,
    required this.rowsBody,
    required this.cutEndBoundaryLeft,
    required this.showPlayhead,
    required this.playheadLeft,
    required this.playheadWidth,
    required this.playhead,
  });

  final Widget rowsBody;
  final double cutEndBoundaryLeft;
  final bool showPlayhead;
  final double playheadLeft;
  final double playheadWidth;
  final Widget playhead;
}
```

Do not force this exact API if the current implementation is simpler with different parameters.

A safer alternative is:

```dart id="wo7gbo"
class TimelineFrameGridStack extends StatelessWidget {
  const TimelineFrameGridStack({
    super.key,
    required this.rowsBody,
    required this.cutEndBoundary,
    this.playheadOverlay,
  });

  final Widget rowsBody;
  final Widget cutEndBoundary;
  final Widget? playheadOverlay;
}
```

This second shape is preferred if it avoids moving playhead and cut-end calculations out of `LayerTimelineGrid`.

Use the smallest API that keeps calculations in `LayerTimelineGrid`.

## Recommended approach

Prefer this responsibility split:

```dart id="2xt0a3"
TimelineFrameGridStack(
  rowsBody: TimelineFrameRowsScrollBody(...),
  cutEndBoundary: TimelineBodyCutEndBoundary(...),
  playheadOverlay: showPlayhead
      ? Positioned(
          left: 0,
          top: 0,
          width: plan.totalFrameContentWidth,
          child: TimelinePlayhead(...),
        )
      : null,
)
```

This keeps:

```txt id="t1s3yi"
- cut-end boundary left calculation
- playhead visibility condition
- playhead parameters
```

inside `LayerTimelineGrid`.

The new widget only arranges provided children in a `Stack`.

## Update LayerTimelineGrid

Update:

```txt id="hxex52"
lib/src/ui/timeline/layer_timeline_grid.dart
```

so it imports:

```dart id="mfbui2"
import 'timeline_frame_grid_stack.dart';
```

Then replace the inline `Stack(...)` passed to `TimelineFrameScrollViewport` with:

```dart id="5tmlu8"
TimelineFrameGridStack(...)
```

Pass existing child widgets through unchanged.

After extraction, remove only the old inline stack composition from `LayerTimelineGrid`.

## Do not change

Do not change runtime behavior.

Do not change:

* `TimelineFrameRowsScrollBody`
* `TimelineFrameScrollViewport`
* `TimelineBodyCutEndBoundary`
* `TimelinePlayhead`
* `TimelineVerticalScrollbarSlot`
* `TimelineVerticalScrollbarRail`
* `TimelineHorizontalScrollbarRail`
* `TimelineLayerControlsHeader`
* `TimelineLayerControlsRow`
* `TimelineFrameHeaderRow`
* `TimelineRulerCutEndBoundary`
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

* frame rows rendering
* frame row order
* frame cell rendering
* frame/layer selection callbacks
* empty layer placeholder behavior
* cut-end boundary behavior
* playhead behavior
* selected exposure outline behavior
* horizontal scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* bottom horizontal scrollbar behavior
* vertical scrollbar behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="wum3a8"
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
TimelineFrameScrollViewport
TimelineFrameRowsScrollBody
TimelineFrameGridStack
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
* PR186 horizontal scrollbar rail tests
* PR188 frame scroll viewport tests
* PR190 frame rows scroll body tests
* ruler/body alignment tests
* horizontal/vertical scrollbar tests

If adding a focused smoke test is simple, add:

```txt id="h3n5il"
test/ui/timeline_frame_grid_stack_test.dart
```

Suggested optional checks:

* provided rows body renders
* provided cut-end boundary renders
* provided playhead overlay renders when non-null
* no playhead overlay renders when null
* stack child order is preserved if simple to inspect

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="46xjej"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="5h4pwf"
1. Frame grid rows still render in the same order.
2. Frame cells still render for every visible layer.
3. Frame cell click still selects the frame.
4. Frame cell click still selects the layer.
5. Selected exposure outline still aligns with frame cells.
6. Playhead still aligns with the current frame column.
7. Playhead still appears only when current frame is inside the visible frame range.
8. Cut-end boundary still aligns after horizontal and vertical scrolling.
9. Horizontal scrolling moves frame rows with ruler/header.
10. Vertical scrolling moves layer rows and frame rows together.
11. Layer controls rail and frame grid row alignment is unchanged.
12. Empty layer placeholder behavior is unchanged.
```

## Report back

Report:

* changed files
* new frame grid stack widget file
* whether optional test file was added
* how `LayerTimelineGrid` now delegates frame grid stack composition
* confirmation that stack child order did not change
* confirmation that rows body behavior did not change
* confirmation that cut-end boundary behavior did not change
* confirmation that playhead behavior did not change
* confirmation that selected exposure outline behavior did not change
* confirmation that no duplicate stable key was introduced
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
