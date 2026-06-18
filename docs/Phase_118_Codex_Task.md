# Phase 118 Codex Task

## Title

Extract timeline frame cell widget

## Goal

Extract the individual timeline frame cell rendering from `LayerTimelineGrid` into a dedicated small widget file.

This is a stabilization/refactor phase after PR167, PR168, PR169, PR170, PR171, and PR172.

No visual behavior should change.

## Required reference

Before editing timeline code, read:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

`LayerTimelineGrid` has already been reduced by extracting:

* selected exposure display-range policy
* horizontal offset clamp policy
* frame coordinate policy
* selected exposure outline widget

The next remaining responsibility inside `LayerTimelineGrid` is individual frame cell rendering.

Frame cells are visually important and easy to regress because they combine:

* cell key stability
* selected frame border behavior
* selected exposure range segment behavior
* outside-playback styling
* exposure block visual segment styling
* marks / labels
* empty / drawing / held / blank visual state

This phase extracts that rendering into a focused widget so future changes to cell visuals have a smaller surface area.

## New file

Create:

```txt
lib/src/ui/timeline/timeline_frame_cell.dart
```

## What to extract

Move the existing private timeline cell widget and its directly related rendering helpers from `LayerTimelineGrid` into the new file.

Look for the current private cell widget and helper logic inside:

```txt
lib/src/ui/timeline/layer_timeline_grid.dart
```

Likely candidates include:

* the private cell widget used by `_FrameCellsRow`
* the cell decoration helper
* cell content/label/mark rendering helpers if they are only used by that cell
* selected frame border logic
* selected exposure range segment styling logic

Use the existing code as the source of truth.

Do not redesign the cell.

## Required behavior to preserve

The extracted widget must preserve the current timeline cell behavior exactly.

Preserve:

* Stable cell key:

    * `timeline-cell-<layerId>-<frameIndex>`
* Selected frame visual behavior.
* Selected exposure range segment behavior.
* Internal frame divider behavior.
* Exposure block visual segment behavior.
* Empty / drawing / held / blank state visuals.
* Outside-playback styling.
* Mark / frame-name rendering if currently present.
* Existing colors, border widths, border radius, opacity, text style, and layout.
* Existing hit testing / tap behavior.
* Existing cell size.

## Important semantic rules

Do not confuse cell visual state with timeline data semantics.

In particular:

* `Cut.duration` is not a cell editability limit.
* `playbackFrameCount` is not a data extent.
* `authoredTimelineExtentFrameCount` must not be used by frame cell rendering.
* selected exposure outline is a display-range visual effect.
* virtualization is a rendering optimization only.

## Update LayerTimelineGrid

Update `_FrameCellsRow` in `LayerTimelineGrid`:

* Replace the inline/private cell rendering with the new `TimelineFrameCell` widget.
* Keep `_FrameCellsRow` responsible for deciding which frames to render.
* Keep `_FrameCellsRow` responsible for passing already-computed state into the cell.
* Do not move timeline row layout or virtualization into the cell.
* Do not move selected exposure outline rendering back into the cell.
* Do not change `TimelineSelectedExposureOutline`.

The goal is:

```txt
LayerTimelineGrid / _FrameCellsRow:
- row layout
- frame iteration
- selected exposure display range resolution
- outline widget placement

TimelineFrameCell:
- one frame cell rendering
```

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
* timeline virtualization behavior
* selected exposure display-range semantics
* selected exposure outline visual style
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

Existing `LayerTimelineGrid` widget tests should continue to pass.

Add a small widget test for the extracted cell only if it can be done without duplicating too much implementation detail.

Suggested test file:

```txt
test/ui/timeline_frame_cell_test.dart
```

Suggested minimum tests:

### 1. renders with stable cell key

* Render one `TimelineFrameCell`.
* Use `layerId = LayerId('layer-1')`
* Use `frameIndex = 3`
* Expect key:

    * `timeline-cell-layer-1-3`

### 2. selected frame uses selected border behavior

* Render a selected cell not inside selected exposure range.
* Verify the widget renders without errors.
* If a stable decoration assertion already exists in existing tests, prefer keeping that instead of adding fragile pixel/color assertions.

### 3. selected exposure range segment suppresses individual selected thick border

* Render a selected cell inside selected exposure range.
* Verify it renders without errors.
* Do not add fragile style assertions unless existing code already exposes stable values.

If direct widget tests require too much setup, do not force them. Existing `LayerTimelineGrid` tests are more important.

Do not remove existing tests:

* PR165 resize tests
* PR166/PR167 selected exposure display-range tests
* PR168 horizontal offset policy tests
* PR169 frame coordinate policy tests
* PR172 selected exposure outline widget tests
* ruler/body alignment tests
* selected exposure outline tests

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
* new timeline frame cell widget file
* whether a new frame cell widget test file was added
* how `_FrameCellsRow` now delegates individual cell rendering
* confirmation that stable cell keys did not change
* confirmation that selected frame visual behavior did not change
* confirmation that selected exposure range segment behavior did not change
* confirmation that selected exposure outline widget was not changed or moved back
* confirmation that PR165/PR168 resize offset behavior did not change
* confirmation that PR167 selected exposure display-range behavior did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
