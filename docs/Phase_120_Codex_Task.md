# Phase 120 Codex Task

## Title

Extract timeline layer controls row widget

## Goal

Extract the per-layer controls row rendering from `LayerTimelineGrid` into a dedicated widget file.

This is a stabilization/refactor phase after PR172, PR173, and PR174.

No visual behavior should change.

## Required reference

Before editing timeline code, read:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases reduced `LayerTimelineGrid` by extracting:

* `TimelineSelectedExposureOutline`
* `TimelineFrameCell`
* `TimelineFrameCellsRow`

After those extractions, `LayerTimelineGrid` should continue shrinking toward only owning:

* scroll controllers
* horizontal offset synchronization
* viewport/scrollbar layout
* ruler/header/body layout
* virtualization plan creation
* layer row iteration

The left-side layer controls row is still a separate visual responsibility. It should move into its own file so future layer-control UI changes do not increase `LayerTimelineGrid` complexity.

## New file

Create:

```txt
lib/src/ui/timeline/timeline_layer_controls_row.dart
```

## What to extract

Move the existing private per-layer controls row widget from:

```txt
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new file as:

```dart
class TimelineLayerControlsRow extends StatelessWidget
```

Use the current implementation as the source of truth.

Likely candidate:

```txt
_LayerControlsRow
```

Move only the row widget and directly related small helpers if they are used only by that row.

Do not redesign the layer controls row.

## Required behavior to preserve

Preserve exactly:

* Existing layer controls row layout.
* Existing row height.
* Existing active/inactive visual state.
* Existing layer label/name display.
* Existing icon/button/text behavior.
* Existing hit behavior.
* Existing layer selection callback behavior.
* Existing keys, if any.
* Existing colors, opacity, borders, padding, text style, and alignment.
* Existing relationship between layer controls row height and frame cells row height.
* Existing vertical scrolling behavior.

## Update LayerTimelineGrid

Update `LayerTimelineGrid` so it imports:

```dart
import 'timeline_layer_controls_row.dart';
```

Then replace the old private row usage with:

```dart
TimelineLayerControlsRow(...)
```

Pass all existing data and callbacks through.

After extraction, remove the old private `_LayerControlsRow` class from `layer_timeline_grid.dart`.

`LayerTimelineGrid` should remain responsible for:

* layer controls rail layout
* layer row iteration
* scroll synchronization
* timeline body layout
* virtualization
* frame ruler/header layout
* horizontal and vertical scrollbars

`TimelineLayerControlsRow` should be responsible for:

* rendering one layer controls row
* showing the layer label/name
* active/inactive visual state
* per-layer row hit behavior
* invoking the existing selection callback

## Metrics rule

Do not rely on private members of `LayerTimelineGrid` from the new file.

If the row currently uses:

```dart
LayerTimelineGrid._metrics
```

then replace that dependency with:

```dart
final TimelineGridMetrics metrics;
```

Pass the existing metrics from `LayerTimelineGrid` into `TimelineLayerControlsRow`.

Do not change metric values.

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
* `TimelineFrameCellsRow`
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
* PR174 row behavior through existing grid tests
* ruler/body alignment tests
* selected exposure outline tests

If adding a small widget smoke test is simple, add:

```txt
test/ui/timeline_layer_controls_row_test.dart
```

Suggested optional checks:

* renders the layer name/label
* active row renders without error
* tapping row invokes the existing layer selection callback

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash
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
* new timeline layer controls row widget file
* whether an optional widget test file was added
* how `LayerTimelineGrid` now delegates layer controls row rendering
* confirmation that layer controls visual behavior did not change
* confirmation that layer selection callback behavior did not change
* confirmation that timeline frame body, frame rows, frame cells, and selected exposure outline were not changed
* confirmation that PR165/PR168 resize offset behavior did not change
* confirmation that PR167 selected exposure display-range behavior did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
