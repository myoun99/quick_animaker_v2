# Phase 121 Codex Task

## Title

Extract timeline layer controls header widget

## Goal

Extract the left sticky layer controls header / add-layer header area from `LayerTimelineGrid` into a dedicated widget file.

This is a stabilization/refactor phase after PR175.

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
* `TimelineLayerControlsRow`

After PR175, the per-layer row on the left side is separated, but the left sticky header / add-layer control area still belongs to `LayerTimelineGrid`.

This phase separates that header so future layer rail or add-layer UI changes do not increase `LayerTimelineGrid` complexity.

The long-term direction is:

```txt
LayerTimelineGrid:
- scroll controllers
- scroll synchronization
- viewport and scrollbar layout
- ruler/header/body layout
- virtualization plan creation
- layer row iteration

TimelineLayerControlsHeader:
- left sticky layer rail header
- + Layer / add layer control rendering
- header visual state and hit behavior

TimelineLayerControlsRow:
- one layer controls row
```

## New file

Create:

```txt
lib/src/ui/timeline/timeline_layer_controls_header.dart
```

## What to extract

Move the existing private left layer controls header / add-layer header widget from:

```txt
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new file as:

```dart
class TimelineLayerControlsHeader extends StatelessWidget
```

Use the current implementation as the source of truth.

Likely candidates may include a private header widget, sticky layer header area, or the widget that renders the `+ Layer` control.

Do not redesign the header.

## Required behavior to preserve

Preserve exactly:

* Existing sticky left header layout.
* Existing `+ Layer` / add-layer button behavior.
* Existing row/header height.
* Existing width.
* Existing keys, if any.
* Existing text, icon, tooltip, semantics, and callback behavior.
* Existing colors, opacity, borders, padding, text style, and alignment.
* Existing relationship between the left layer controls header and the frame ruler/header area.
* Existing behavior where this header does not vertically scroll with body rows.

## Metrics rule

Do not rely on private members of `LayerTimelineGrid` from the new file.

If the header currently uses:

```dart
LayerTimelineGrid._metrics
```

then replace that dependency with:

```dart
final TimelineGridMetrics metrics;
```

Pass the existing metrics from `LayerTimelineGrid` into `TimelineLayerControlsHeader`.

Do not change metric values.

## Update LayerTimelineGrid

Update `LayerTimelineGrid` so it imports:

```dart
import 'timeline_layer_controls_header.dart';
```

Then replace the old private header usage with:

```dart
TimelineLayerControlsHeader(...)
```

Pass all existing data and callbacks through.

After extraction, remove the old private header widget and any helpers used only by that header from `layer_timeline_grid.dart`.

`LayerTimelineGrid` should remain responsible for:

* placing the layer controls header in the correct sticky area
* scroll controllers
* vertical/horizontal scrollbar layout
* frame ruler/header/body layout
* virtualization
* layer row iteration

`TimelineLayerControlsHeader` should be responsible for:

* rendering the left sticky layer controls header
* rendering the existing add-layer control
* invoking the existing add-layer callback
* preserving the existing header visual style

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
* timeline virtualization behavior
* selected exposure display-range semantics
* selected exposure outline visual style
* frame cell visual style
* layer controls row visual style
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
* ruler/body alignment tests
* selected exposure outline tests

If adding a small widget smoke test is simple, add:

```txt
test/ui/timeline_layer_controls_header_test.dart
```

Suggested optional checks:

* renders the existing add-layer label/button
* tapping the add-layer control invokes the existing callback
* the stable key exists if the original header already had one

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
* new timeline layer controls header widget file
* whether an optional widget test file was added
* how `LayerTimelineGrid` now delegates left header rendering
* confirmation that add-layer behavior did not change
* confirmation that layer controls header visual behavior did not change
* confirmation that layer controls row was not changed
* confirmation that timeline frame body, frame rows, frame cells, and selected exposure outline were not changed
* confirmation that PR165/PR168 resize offset behavior did not change
* confirmation that PR167 selected exposure display-range behavior did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
