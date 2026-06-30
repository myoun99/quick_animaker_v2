# Phase 119 Codex Task

## Title

Extract timeline frame cells row widget

## Goal

Extract the frame cells row rendering from `LayerTimelineGrid` into a dedicated widget file.

This is a stabilization/refactor phase after PR172 and PR173.

No visual behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="p1mda2"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases separated timeline responsibilities:

* PR167: selected exposure display-range policy
* PR168: horizontal offset clamp policy
* PR169: frame coordinate policy
* PR170: long-term timeline range semantics document
* PR171: handoff reference to range semantics
* PR172: selected exposure outline widget
* PR173: individual timeline frame cell widget

After PR173, `LayerTimelineGrid` still owns `_FrameCellsRow`.

That row is now mostly a coordinator for:

* deciding which frame indices to render
* resolving selected exposure display range
* deciding per-cell selected exposure segment state
* deciding exposure block visual segment state
* passing state into `TimelineFrameCell`
* placing `TimelineSelectedExposureOutline`

This phase moves that row coordinator into its own file so `LayerTimelineGrid` can continue shrinking.

## New file

Create:

```txt id="c8qstl"
lib/src/ui/timeline/timeline_frame_cells_row.dart
```

## What to extract

Move the existing private `_FrameCellsRow` widget from:

```txt id="j3xa8c"
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new file as a public or package-internal widget:

```dart id="m6tqwk"
class TimelineFrameCellsRow extends StatelessWidget
```

Use the current `_FrameCellsRow` implementation as the source of truth.

Do not redesign the row.

## Required behavior to preserve

Preserve exactly:

* row key:

    * `timeline-frame-row-area-<layerId>`
* rendered frame index loop:

    * `frameStartIndex` to `frameEndIndexExclusive`
* visible frame virtualization behavior
* selected frame behavior
* selected exposure range segment behavior
* exposure block visual segment behavior
* outside-playback cell styling
* per-cell stable key behavior through `TimelineFrameCell`
* selected exposure outline placement through `TimelineSelectedExposureOutline`
* current row height and frame cell width
* current hit behavior
* current selection callbacks

## Required semantic preservation

Do not confuse row rendering with timeline data semantics.

In particular:

* `Cut.duration` is not an editability limit.
* `playbackFrameCount` is not authored data extent.
* `authoredTimelineExtentFrameCount` must not be used by row rendering.
* selected exposure outline is a display-range visual effect.
* virtualization is rendering optimization only.
* visible frame window is not data extent.

## Metrics rule

Do not rely on private members of `LayerTimelineGrid` from the new file.

If `_FrameCellsRow` currently uses:

```dart id="m3bvxv"
LayerTimelineGrid._metrics
```

then replace that dependency with one of these approaches:

Preferred:

```dart id="v6i8j0"
final TimelineGridMetrics metrics;
```

Pass the existing metrics from `LayerTimelineGrid` into `TimelineFrameCellsRow`.

Alternative, only if it matches existing project style:

```dart id="6qbf17"
static const TimelineGridMetrics _metrics = TimelineGridMetrics.defaults;
```

Do not change metric values.

## Update LayerTimelineGrid

Update `LayerTimelineGrid` so it imports:

```dart id="zgnxmq"
import 'timeline_frame_cells_row.dart';
```

Then replace `_FrameCellsRow(...)` usage with:

```dart id="67k6f1"
TimelineFrameCellsRow(...)
```

Pass all existing data and callbacks through.

After extraction, remove the old private `_FrameCellsRow` class from `layer_timeline_grid.dart`.

`LayerTimelineGrid` should remain responsible for:

* scroll controllers
* horizontal offset synchronization
* vertical/horizontal scroll layout
* ruler/header/body layout
* virtualization plan creation
* layer row iteration

`TimelineFrameCellsRow` should be responsible for:

* one layer row of frame cells
* frame iteration inside the row
* selected exposure display range resolution for that row
* per-cell exposure visual segment calculation
* selected exposure outline placement for that row

## Do not change

Do not change runtime behavior.

Do not change:

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
* `TimelineFrameCoordinatePolicy`
* `TimelineSelectedExposureOutline`
* `TimelineFrameCell`
* timeline virtualization behavior
* selected exposure display-range semantics
* selected exposure outline visual style
* frame cell visual style
* ruler behavior
* resize offset clamp behavior
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel` or `LayerTimelineGrid`.

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
* PR173 frame cell behavior through existing grid tests
* ruler/body alignment tests
* selected exposure outline tests

If adding a new widget test is simple, add a small smoke test for `TimelineFrameCellsRow`, but do not create fragile visual assertions.

Suggested optional test:

```txt id="rd8zrl"
test/ui/timeline_frame_cells_row_test.dart
```

Minimum optional checks:

* row key `timeline-frame-row-area-<layerId>` exists
* expected first and last visible cell keys exist
* selected exposure outline key appears when display range intersects

Skip this optional test if setup becomes large or duplicates existing `LayerTimelineGrid` tests.

## Required checks

Run:

```bash id="oa64nw"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Report back

Report:

* changed files
* new timeline frame cells row widget file
* whether an optional row widget test file was added
* how `LayerTimelineGrid` now delegates row rendering
* confirmation that stable row key did not change
* confirmation that stable cell keys did not change
* confirmation that selected exposure display-range behavior did not change
* confirmation that selected exposure outline widget was not changed
* confirmation that timeline frame cell widget was not changed
* confirmation that PR165/PR168 resize offset behavior did not change
* confirmation that PR167 selected exposure display-range behavior did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
