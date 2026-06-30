# Phase 124 Codex Task

## Title

Extract timeline ruler cut-end boundary widget

## Goal

Extract the cut-end boundary marker inside `TimelineFrameRuler` into a dedicated widget file.

This is a stabilization/refactor phase after PR177 and PR178.

No visual behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="n4hof3"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and stabilized the frame header row:

* PR177: `TimelineFrameHeaderRow`
* PR178: focused tests for `TimelineFrameHeaderRow`

`TimelineFrameRuler` now composes `TimelineFrameHeaderRow`, but it still owns the ruler cut-end boundary marker rendering.

This marker is a visual responsibility separate from:

* frame header row rendering
* frame ruler scrub/click behavior
* horizontal scroll offset policy
* frame coordinate conversion
* selected exposure display range
* authored/data extent

This phase extracts the ruler cut-end boundary marker into its own widget so future boundary styling changes do not grow `TimelineFrameRuler`.

## New file

Create:

```txt id="d6xl8f"
lib/src/ui/timeline/timeline_ruler_cut_end_boundary.dart
```

## What to extract

Move only the existing ruler cut-end boundary marker rendering from:

```txt id="gfvhaz"
lib/src/ui/timeline/timeline_frame_ruler.dart
```

into the new file as:

```dart id="8xv0qy"
class TimelineRulerCutEndBoundary extends StatelessWidget
```

Use the current implementation as the source of truth.

Likely code to extract includes the widget currently keyed as:

```txt id="rv4cpq"
timeline-cut-end-boundary-ruler
```

Do not redesign the boundary marker.

## Scope

This phase is only for the ruler boundary marker.

Do not extract or change the body/grid cut-end boundary marker:

```txt id="7iygkz"
timeline-cut-end-boundary
```

That can be a later phase.

## Required behavior to preserve

Preserve exactly:

* Stable key:

    * `timeline-cut-end-boundary-ruler`
* Existing position.
* Existing width.
* Existing height.
* Existing color.
* Existing opacity.
* Existing border/decoration.
* Existing relationship with the frame header row.
* Existing relationship with horizontal scroll.
* Existing behavior when the cut end is outside the rendered/visible ruler area.
* Existing ruler click/drag/scrub behavior.

## Important semantic rule

The cut-end boundary is a visual marker for playback/export duration.

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
* `authoredTimelineExtentFrameCount` must not be used by this boundary widget.

## Responsibility split

`TimelineFrameRuler` should remain responsible for:

* composing the header row
* composing the cut-end boundary marker
* owning ruler hit/scrub/click behavior
* computing or passing the current boundary position if it already does so

`TimelineRulerCutEndBoundary` should be responsible for:

* rendering the ruler cut-end boundary marker
* preserving the existing key and visual style
* receiving already-computed positioning/metrics values from `TimelineFrameRuler`

## Metrics and positioning rule

Do not rely on private members of another class from the new file.

If the current marker uses values from `TimelineGridMetrics`, pass:

```dart id="xyjc5m"
final TimelineGridMetrics metrics;
```

or pass only the exact primitive values needed, such as:

```dart id="virsr2"
final double left;
final double height;
```

Prefer the minimal API that preserves the current implementation.

Do not change metric values.

Do not move frame coordinate policy responsibilities into this widget.

If `TimelineFrameRuler` currently calculates boundary `left` position, keep that calculation in `TimelineFrameRuler` and pass the result to `TimelineRulerCutEndBoundary`.

## Update TimelineFrameRuler

Update:

```txt id="doq5oe"
lib/src/ui/timeline/timeline_frame_ruler.dart
```

so it imports:

```dart id="eb4f9p"
import 'timeline_ruler_cut_end_boundary.dart';
```

Then replace the old inline/positioned cut-end boundary marker with:

```dart id="dpq217"
TimelineRulerCutEndBoundary(...)
```

Pass existing values through unchanged.

After extraction, remove only the old inline marker code from `timeline_frame_ruler.dart`.

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
* frame ruler click/drag/scrub behavior
* frame header row behavior
* frame header tests
* timeline virtualization behavior
* selected exposure display-range semantics
* selected exposure outline visual style
* body/grid cut-end boundary
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel`, `LayerTimelineGrid`, `TimelineFrameRuler`, `TimelineFrameHeaderRow`, or the new boundary widget.

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
* ruler/body alignment tests
* cut-end boundary tests, if any

If adding a small widget smoke test is simple, add:

```txt id="ea8d5m"
test/ui/timeline_ruler_cut_end_boundary_test.dart
```

Suggested optional checks:

* `timeline-cut-end-boundary-ruler` key exists
* widget renders without error at a supplied left position
* widget does not intercept pointer behavior if the original marker did not

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="dxv9yb"
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
* new timeline ruler cut-end boundary widget file
* whether an optional widget test file was added
* how `TimelineFrameRuler` now delegates cut-end boundary rendering
* confirmation that `timeline-cut-end-boundary-ruler` key did not change
* confirmation that cut-end boundary visual behavior did not change
* confirmation that frame ruler click/drag/scrub behavior did not change
* confirmation that frame header row was not changed except for composition if necessary
* confirmation that body/grid cut-end boundary was not changed
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
