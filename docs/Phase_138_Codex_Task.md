# Phase 138 Codex Task

## Title

Add LayerTimelineGrid extracted composition smoke tests

## Goal

Add focused smoke tests that verify the recently extracted timeline body components are still composed correctly inside `LayerTimelineGrid`.

This is a stabilization phase after PR187 through PR192.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="2m2wzl"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and tested small timeline body components:

```txt id="a4sv3p"
PR187: TimelineFrameScrollViewport
PR188: tests for TimelineFrameScrollViewport
PR189: TimelineFrameRowsScrollBody
PR190: tests for TimelineFrameRowsScrollBody
PR191: TimelineFrameGridStack
PR192: tests for TimelineFrameGridStack
```

Each component has focused tests, but `LayerTimelineGrid` is still the composition root for:

```txt id="ebdtsq"
- layer controls rail
- frame grid area
- frame scroll viewport
- frame scroll content
- frame rows scroll body
- body cut-end boundary
- playhead
- vertical scrollbar slot/rail
- bottom horizontal scrollbar rail
```

This phase adds a high-level smoke test to ensure the extracted pieces still appear together with stable keys and no duplicate structural keys.

## Test file

Prefer creating a new focused file:

```txt id="pdhq14"
test/ui/layer_timeline_grid_extracted_composition_test.dart
```

If the existing project strongly prefers adding these tests to:

```txt id="pu129i"
test/ui/layer_timeline_grid_test.dart
```

that is acceptable, but keep the new tests clearly grouped.

## Widget under test

Test:

```txt id="kl5fs9"
LayerTimelineGrid
```

Use the existing test harness and constructor patterns already present in the repository.

Before writing the tests, inspect existing tests such as:

```txt id="6s5knd"
test/ui/layer_timeline_grid_test.dart
test/ui/timeline_frame_rows_scroll_body_test.dart
test/ui/timeline_frame_grid_stack_test.dart
test/ui/timeline_frame_scroll_viewport_test.dart
```

Reuse existing model/test helpers where appropriate.

Do not invent new production APIs.

## Scope

This phase should add tests only.

Do not refactor production code.

Do not change UI behavior.

## Required stable keys to verify

Render a minimal `LayerTimelineGrid` with at least one layer and enough visible frames for the playhead to appear.

Verify these structural keys exist exactly once when applicable:

```txt id="b24unq"
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-rows-scroll-body
timeline-cut-end-boundary
timeline-horizontal-scrollbar
timeline-bottom-scrollbar-rail
timeline-vertical-scrollbar-slot
timeline-vertical-scrollbar
timeline-playhead
timeline-playhead-column
```

If a key is not currently rendered by `LayerTimelineGrid` in the chosen minimal harness, do not force production code to render it.

Instead, adjust the test setup using existing constructor values so the key appears naturally.

Do not invent new keys.

Do not rename existing keys.

## Required tests

### 1. Extracted frame-grid structure appears together

Render `LayerTimelineGrid`.

Verify these keys exist exactly once:

```txt id="e8d78d"
timeline-frame-grid-area
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-rows-scroll-body
```

This confirms the extracted viewport/body/stack pieces are still composed together.

### 2. Scrollbar rails and slots still appear together

Verify these keys exist exactly once if they are part of the current `LayerTimelineGrid` structure:

```txt id="r1gf2c"
timeline-horizontal-scrollbar
timeline-bottom-scrollbar-rail
timeline-vertical-scrollbar-slot
timeline-vertical-scrollbar
```

Do not test drag/scroll behavior here.

That is covered by lower-level tests and manual verification.

### 3. Layer controls rail still appears outside frame scroll content

Verify:

```txt id="6nl9w5"
timeline-layer-controls-rail
```

exists exactly once.

If simple and stable, verify it is not a descendant of:

```txt id="u7x6te"
timeline-frame-scroll-content
```

This protects the important invariant that the left layer controls rail is not inside the horizontal frame scroll viewport.

Avoid fragile pixel assertions if the descendant check is sufficient.

### 4. Frame rows body is inside frame scroll content

Verify:

```txt id="a3f8r7"
timeline-frame-rows-scroll-body
```

is a descendant of:

```txt id="8es1xt"
timeline-frame-scroll-content
```

This confirms the extracted rows body remains inside the horizontal frame scroll content.

### 5. Body cut-end boundary is inside frame scroll content

Verify:

```txt id="lmw2vo"
timeline-cut-end-boundary
```

exists exactly once.

If simple and stable, verify it is a descendant of:

```txt id="k5ui6u"
timeline-frame-scroll-content
```

Do not assert colors.

### 6. Playhead is inside frame scroll content when visible

Set up `currentFrameIndex` so it is inside the visible frame range.

Verify:

```txt id="60g6xx"
timeline-playhead
timeline-playhead-column
```

exist exactly once.

If simple and stable, verify the playhead is a descendant of:

```txt id="vnufag"
timeline-frame-scroll-content
```

Do not test `TimelinePlayhead` internals here beyond the stable keys.

### 7. No duplicate structural keys

In one test, verify the following keys appear at most once or exactly once depending on render setup:

```txt id="k89ta5"
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-rows-scroll-body
timeline-cut-end-boundary
timeline-horizontal-scrollbar
timeline-bottom-scrollbar-rail
timeline-vertical-scrollbar-slot
timeline-vertical-scrollbar
timeline-playhead
timeline-playhead-column
```

Do not attach the same stable key at both a call site and inside an extracted widget.

### 8. Existing row/cell keys still appear

With at least one layer and a small visible frame range, verify at least:

```txt id="ihgh86"
timeline-frame-row-area-<layerId>
timeline-cell-<layerId>-<frameIndex>
```

still appear.

This confirms the extraction did not break downstream row/cell rendering.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="1g7wuj"
- exact colors
- exact borders
- pixel-perfect coordinates unless already used in stable existing tests
- raw drag/scroll behavior
- controller offset changes from gestures
- screenshot/image comparisons
- assumptions about private widget types
```

This phase is a structural composition smoke test.

## Do not change

Do not change production behavior.

Do not change:

* `LayerTimelineGrid`
* `TimelineFrameGridStack`
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

* stack child order
* rows body behavior
* cut-end boundary behavior
* playhead behavior
* selected exposure outline behavior
* frame row order
* frame cell rendering
* frame/layer selection callbacks
* empty layer placeholder behavior
* horizontal scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* bottom horizontal scrollbar behavior
* vertical scrollbar behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="aolau7"
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

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Do not redesign UI.

## Required checks

Run:

```bash id="y8fn2k"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="u6i1gq"
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
13. Bottom horizontal scrollbar remains under the frame grid only.
14. Vertical scrollbar slot remains between layer rail and frame grid.
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that extracted frame-grid structure keys are tested
* confirmation that scrollbar rail/slot keys are tested
* confirmation that layer controls rail remains outside frame scroll content
* confirmation that frame rows body remains inside frame scroll content
* confirmation that body cut-end boundary remains inside frame scroll content
* confirmation that playhead appears inside frame scroll content when visible
* confirmation that no duplicate structural key was introduced
* confirmation that row/cell keys still appear
* confirmation that no fragile pointer-offset or scroll test was added
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
