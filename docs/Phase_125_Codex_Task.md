# Phase 125 Codex Task

## Title

Extract timeline body cut-end boundary widget

## Goal

Extract the body/grid cut-end boundary marker from `LayerTimelineGrid` into a dedicated widget file.

This is a stabilization/refactor phase after PR179.

No visual behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="gm5rvj"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and stabilized timeline header/ruler responsibilities:

* PR177: `TimelineFrameHeaderRow`
* PR178: focused tests for `TimelineFrameHeaderRow`
* PR179: `TimelineRulerCutEndBoundary`

After PR179, the ruler-side cut-end boundary marker is separated, but the body/grid-side cut-end boundary marker still remains inside `LayerTimelineGrid`.

This phase extracts the body/grid cut-end boundary marker into its own widget so future cut-end styling or layout changes do not grow `LayerTimelineGrid`.

## New file

Create:

```txt id="riixr9"
lib/src/ui/timeline/timeline_body_cut_end_boundary.dart
```

## What to extract

Move only the existing body/grid cut-end boundary marker rendering from:

```txt id="rjyru7"
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new file as:

```dart id="yxjkbd"
class TimelineBodyCutEndBoundary extends StatelessWidget
```

Use the current implementation as the source of truth.

Likely code to extract includes the widget currently keyed as:

```txt id="ek0fbo"
timeline-cut-end-boundary
```

Do not redesign the boundary marker.

## Scope

This phase is only for the body/grid boundary marker.

Do not change the ruler boundary marker:

```txt id="0h6mlc"
timeline-cut-end-boundary-ruler
```

That was already extracted in PR179.

## Required behavior to preserve

Preserve exactly:

* Stable key:

    * `timeline-cut-end-boundary`
* Existing position.
* Existing width.
* Existing height.
* Existing color.
* Existing opacity.
* Existing border/decoration.
* Existing relationship with the body frame grid.
* Existing relationship with horizontal scroll.
* Existing behavior when the cut end is outside the rendered/visible body area.
* Existing behavior with vertical scrolling.
* Existing behavior with frame cells and selected exposure outline.

## Important semantic rule

The body cut-end boundary is a visual marker for playback/export duration.

It must not become:

* an editability limit
* a selection limit
* a data/authored extent limit
* a selected exposure range limit
* a virtualized range limit

In particular:

* `Cut.duration` is playback/export duration only.
* visible/display range is for UI display and interaction.
* authored/data extent is separate.
* frames after `Cut.duration` may still be visible and editable.
* selected exposure outline may continue through the display range.
* `authoredTimelineExtentFrameCount` must not be used by this boundary widget.

## Responsibility split

`LayerTimelineGrid` should remain responsible for:

* composing the frame grid body
* computing or passing the current boundary position if it already does so
* scroll controllers
* horizontal offset synchronization
* vertical/horizontal scrollbar layout
* ruler/header/body composition
* virtualization plan creation
* layer row iteration

`TimelineBodyCutEndBoundary` should be responsible for:

* rendering the body/grid cut-end boundary marker
* preserving the existing key and visual style
* receiving already-computed positioning/metrics values from `LayerTimelineGrid`

## Metrics and positioning rule

Do not rely on private members of another class from the new file.

If the current marker uses values from `TimelineGridMetrics`, pass:

```dart id="0kdb15"
final TimelineGridMetrics metrics;
```

or pass only the exact primitive values needed, such as:

```dart id="b1ul5p"
final double left;
final double height;
```

Prefer the minimal API that preserves the current implementation.

Do not change metric values.

Do not move frame coordinate policy responsibilities into this widget.

If `LayerTimelineGrid` currently calculates boundary `left` position, keep that calculation in `LayerTimelineGrid` and pass the result to `TimelineBodyCutEndBoundary`.

## Update LayerTimelineGrid

Update:

```txt id="7yppyn"
lib/src/ui/timeline/layer_timeline_grid.dart
```

so it imports:

```dart id="sz2695"
import 'timeline_body_cut_end_boundary.dart';
```

Then replace the old inline/positioned body cut-end boundary marker with:

```dart id="k70h7c"
TimelineBodyCutEndBoundary(...)
```

Pass existing values through unchanged.

After extraction, remove only the old inline body boundary marker code from `layer_timeline_grid.dart`.

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
* `TimelineFrameHeaderRow`
* `TimelineRulerCutEndBoundary`
* `TimelineFrameRuler`
* frame ruler click/drag/scrub behavior
* frame header row behavior
* frame cells behavior
* selected exposure display-range semantics
* selected exposure outline visual style
* ruler cut-end boundary
* timeline virtualization behavior
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel`, `LayerTimelineGrid`, `TimelineFrameRuler`, `TimelineFrameHeaderRow`, `TimelineRulerCutEndBoundary`, or the new body boundary widget.

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
* PR178 frame header row tests
* PR179 ruler cut-end boundary behavior through existing tests
* ruler/body alignment tests
* cut-end boundary tests, if any

If adding a small widget smoke test is simple, add:

```txt id="azmv2e"
test/ui/timeline_body_cut_end_boundary_test.dart
```

Suggested optional checks:

* `timeline-cut-end-boundary` key exists
* widget renders without error at a supplied left position
* widget does not intercept pointer behavior if the original marker did not

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="do0znp"
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
* new timeline body cut-end boundary widget file
* whether an optional widget test file was added
* how `LayerTimelineGrid` now delegates body cut-end boundary rendering
* confirmation that `timeline-cut-end-boundary` key did not change
* confirmation that body cut-end boundary visual behavior did not change
* confirmation that ruler cut-end boundary was not changed
* confirmation that frame ruler click/drag/scrub behavior did not change
* confirmation that frame header row was not changed
* confirmation that frame cells and selected exposure outline were not changed
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
