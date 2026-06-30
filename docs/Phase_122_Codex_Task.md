# Phase 122 Codex Task

## Title

Extract timeline frame header row widget

## Goal

Extract the timeline frame header row from `LayerTimelineGrid` into a dedicated widget file.

This is a stabilization/refactor phase after PR176.

No visual behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="psp833"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases reduced `LayerTimelineGrid` by extracting:

* `TimelineSelectedExposureOutline`
* `TimelineFrameCell`
* `TimelineFrameCellsRow`
* `TimelineLayerControlsRow`
* `TimelineLayerControlsHeader`

After those extractions, `LayerTimelineGrid` should continue moving toward a pure layout coordinator.

The frame header row is a separate visual responsibility from:

* frame ruler
* left layer controls header
* frame cells body
* scroll controller ownership
* virtualization plan creation

This phase extracts the frame header row so future changes to frame labels, current-frame highlight, or visible frame window presentation do not grow `LayerTimelineGrid`.

## New file

Create:

```txt id="y1ik38"
lib/src/ui/timeline/timeline_frame_header_row.dart
```

## What to extract

Move the existing frame header row rendering from:

```txt id="f8k9ry"
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new file as:

```dart id="rdu7g8"
class TimelineFrameHeaderRow extends StatelessWidget
```

Use the current implementation as the source of truth.

Likely code to extract includes the widget that renders:

```txt id="f56qw8"
timeline-frame-header-row
timeline-frame-header-<frameIndex>
timeline-frame-header-leading-spacer
timeline-frame-header-trailing-spacer
```

Do not redesign the header row.

## Required behavior to preserve

Preserve exactly:

* Stable row key:

    * `timeline-frame-header-row`
* Stable frame header keys:

    * `timeline-frame-header-<frameIndex>`
* Stable spacer keys:

    * `timeline-frame-header-leading-spacer`
    * `timeline-frame-header-trailing-spacer`
* Current frame header highlight.
* Existing frame number text.
* Existing current-frame visual style.
* Existing outside-playback visual style if currently present.
* Existing width, height, alignment, borders, colors, text style, padding, and opacity.
* Existing relationship between frame header row and body frame cells.
* Existing horizontal scrolling behavior.
* Existing non-vertical-scrolling sticky behavior.

## Important distinction

Do not confuse the frame header row with the frame ruler.

`TimelineFrameRuler` should remain responsible for ruler interaction/scrubbing.

`TimelineFrameHeaderRow` should only render the frame header cells / labels.

Do not move ruler drag/click behavior into the new frame header row.

## Metrics rule

Do not rely on private members of `LayerTimelineGrid` from the new file.

If the header row currently uses:

```dart id="hj8a0f"
LayerTimelineGrid._metrics
```

then replace that dependency with:

```dart id="86q5gf"
final TimelineGridMetrics metrics;
```

Pass the existing metrics from `LayerTimelineGrid` into `TimelineFrameHeaderRow`.

Do not change metric values.

## Range semantics rule

The frame header row is display/visual UI.

It must not become the source of truth for:

* `Cut.duration`
* authored/data extent
* selected exposure range
* editability
* playback/export length

In particular:

* `Cut.duration` is playback/export duration only.
* visible/display range is for UI display and interaction.
* virtualized frame window is a rendering optimization.
* `authoredTimelineExtentFrameCount` must not be used by frame header rendering.

## Update LayerTimelineGrid

Update `LayerTimelineGrid` so it imports:

```dart id="icd8dk"
import 'timeline_frame_header_row.dart';
```

Then replace the old inline/private frame header row rendering with:

```dart id="u0p6zt"
TimelineFrameHeaderRow(...)
```

Pass through existing values such as:

* current frame index
* playback frame count if currently used for visual styling
* frame start index
* frame end index exclusive
* leading frame spacer width
* trailing frame spacer width
* metrics

After extraction, remove the old private frame header row widget and any helpers used only by that header row from `layer_timeline_grid.dart`.

`LayerTimelineGrid` should remain responsible for:

* placing the frame header row in the correct sticky top area
* scroll controllers
* horizontal scroll layout
* vertical scroll layout
* ruler/header/body composition
* virtualization plan creation
* layer row iteration

`TimelineFrameHeaderRow` should be responsible for:

* rendering one frame header row
* rendering frame header cells
* rendering leading/trailing spacers
* showing current frame visual state
* preserving existing frame header keys and visual style

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
* `TimelineLayerControlsRow`
* `TimelineLayerControlsHeader`
* `TimelineFrameRuler`
* timeline virtualization behavior
* selected exposure display-range semantics
* selected exposure outline visual style
* frame cell visual style
* layer controls visual style
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
* PR175 layer controls row behavior through existing grid tests
* PR176 layer controls header behavior through existing grid tests
* ruler/body alignment tests
* selected exposure outline tests

If adding a small widget smoke test is simple, add:

```txt id="i123ui"
test/ui/timeline_frame_header_row_test.dart
```

Suggested optional checks:

* `timeline-frame-header-row` exists
* first visible frame header key exists
* last visible frame header key exists
* leading/trailing spacer keys exist
* current frame header renders without error

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="tcij3m"
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
* new timeline frame header row widget file
* whether an optional widget test file was added
* how `LayerTimelineGrid` now delegates frame header row rendering
* confirmation that frame header row keys did not change
* confirmation that current frame header visual behavior did not change
* confirmation that frame ruler behavior did not change
* confirmation that layer controls header and row were not changed
* confirmation that timeline frame body, frame rows, frame cells, and selected exposure outline were not changed
* confirmation that PR165/PR168 resize offset behavior did not change
* confirmation that PR167 selected exposure display-range behavior did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
