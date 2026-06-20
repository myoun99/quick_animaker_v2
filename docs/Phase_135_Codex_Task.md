# Phase 135 Codex Task

## Title

Add focused tests for timeline frame rows scroll body

## Goal

Add focused widget tests for the extracted `TimelineFrameRowsScrollBody`.

This is a stabilization phase after PR189.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="bss08f"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR189 extracted the frame rows scroll body from `LayerTimelineGrid` into:

```txt id="l72cjp"
lib/src/ui/timeline/timeline_frame_rows_scroll_body.dart
```

The extracted widget is responsible for:

* preserving `timeline-frame-rows-scroll-body`
* rendering `TimelineFrameCellsRow` for each layer
* preserving layer order
* forwarding current frame/playback/frame range/spacer values
* forwarding exposure/mark/frame name providers
* forwarding layer/frame selection callbacks
* rendering the empty-layer placeholder

This phase adds focused tests so future refactors do not break those responsibilities.

## Test file

Create:

```txt id="u9r9nw"
test/ui/timeline_frame_rows_scroll_body_test.dart
```

## Widget under test

Test:

```txt id="j1p37s"
TimelineFrameRowsScrollBody
```

from:

```txt id="0i0sh1"
lib/src/ui/timeline/timeline_frame_rows_scroll_body.dart
```

## Test setup

Render the widget inside a minimal Material widget tree.

Use real project model classes where possible:

```txt id="wot1rw"
Layer
LayerId
```

Use the current constructors from the source of truth. Do not invent model constructors.

Use existing test patterns from:

```txt id="xmd36c"
test/ui/timeline_layer_controls_widgets_test.dart
test/ui/timeline_frame_cell_test.dart, if present
test/ui/timeline_cut_end_boundary_widgets_test.dart
```

If a helper is useful, keep it local to this test file.

## Required stable key

Test this key:

```txt id="9d4x5b"
timeline-frame-rows-scroll-body
```

It must exist exactly once.

Do not duplicate this key.

## Required tests

### 1. Stable body key exists exactly once

Render `TimelineFrameRowsScrollBody`.

Verify:

```txt id="f4dmi8"
timeline-frame-rows-scroll-body
```

exists exactly once.

### 2. Renders one row per layer

Provide two or three layers with stable IDs.

Verify each expected layer row appears via existing row keys generated downstream.

Expected key pattern:

```txt id="ktpupp"
timeline-layer-row-<layerId>
```

Use the actual `LayerId` string values from the test data.

This test should confirm that `TimelineFrameRowsScrollBody` forwards layers into `TimelineFrameCellsRow`.

### 3. Preserves layer order

With two or three layers, verify their row widgets appear in the same order as the input `layers` list.

Use `tester.getTopLeft(...)` or similar stable positional check if simple.

Avoid fragile pixel-perfect assertions beyond order comparison.

### 4. Renders frame cells for visible frame range

Provide a small visible frame range, for example:

```txt id="oefc8i"
frameStartIndex: 0
frameEndIndexExclusive: 3
```

Verify expected cell keys exist for at least one layer:

```txt id="0ugow4"
timeline-cell-<layerId>-0
timeline-cell-<layerId>-1
timeline-cell-<layerId>-2
```

Do not test beyond the provided visible range.

### 5. Empty layer placeholder renders without rows

Render with:

```txt id="9knpqn"
layers: []
```

Verify:

* `timeline-frame-rows-scroll-body` exists exactly once
* no `timeline-layer-row-*` is present
* no `timeline-cell-*` is present
* the body still lays out successfully

If inspecting the placeholder `SizedBox` is simple, verify it uses:

```txt id="01n1ek"
width: totalFrameContentWidth
height: metrics.layerRowHeight
```

Do not rely on screen-size defaults.

### 6. Active layer state is forwarded

Pass one layer as `activeLayerId`.

Verify that downstream active-row marker appears if the current implementation exposes a stable key.

Known possible key from earlier tests:

```txt id="10l5h0"
timeline-selected-layer
```

If this key is present in the current implementation, verify it appears for the active layer case.

If it is not practical to assert without fragile styling, skip this specific assertion and keep the row/cell tests.

Do not change production code just to make this easier.

### 7. Layer/frame callbacks are forwarded

If simple and stable, tap a visible frame cell and verify:

* `onSelectLayer` receives the layer ID
* `onSelectFrame` receives the frame index

Use existing `TimelineFrameCell` behavior and keys.

Do not add fragile gesture tests if the tap target is unstable.

If tapping a cell becomes fragile, replace this with a weaker but stable test that verifies the cell exists and report that callback behavior is covered by lower-level frame cell tests.

### 8. Exposure/mark/frame name providers are forwarded

Pass simple providers:

```txt id="l9js4f"
exposureStateForLayer
hasMarkForLayer
frameNameForLayer
```

Verify at least one stable visible result if current downstream implementation exposes it reliably.

Examples may include frame name text.

Do not assert exact colors or borders.

Do not change production code to expose test-only state.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="9tgw6k"
- exact colors
- exact border colors
- pixel-perfect row heights beyond order checks
- raw drag/scroll behavior
- assumptions about parent LayerTimelineGrid stack
- selected exposure outline behavior
- playhead behavior
- cut-end boundary behavior
```

Those are not responsibilities of `TimelineFrameRowsScrollBody`.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineFrameRowsScrollBody`
* `TimelineFrameScrollViewport`
* `LayerTimelineGrid`
* `TimelineVerticalScrollbarSlot`
* `TimelineVerticalScrollbarRail`
* `TimelineHorizontalScrollbarRail`
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

* frame rows scroll body key
* frame row order
* frame cell rendering
* frame/layer selection callback behavior
* empty layer placeholder behavior
* horizontal scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* bottom horizontal scrollbar behavior
* vertical scrollbar behavior
* selected exposure outline behavior
* cut-end boundary behavior
* playhead behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="cc0r2d"
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
```

Do not use `CustomPainter`.

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Do not redesign UI.

## Required checks

Run:

```bash id="3j51vu"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="6vdbgh"
1. Frame grid rows still render in the same order.
2. Frame cells still render for every visible layer.
3. Empty project/cut state still shows the expected frame body height.
4. Frame cell click still selects the frame.
5. Frame cell click still selects the layer.
6. Exposure markers still render correctly.
7. Frame names still render correctly.
8. Horizontal scrolling moves frame rows with ruler/header.
9. Vertical scrolling moves layer rows and frame rows together.
10. Layer controls rail and frame grid row alignment is unchanged.
11. Selected exposure outline still aligns with frame cells.
12. Playhead still aligns with the current frame column.
13. Cut-end boundaries still align after horizontal and vertical scrolling.
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that `timeline-frame-rows-scroll-body` is tested
* confirmation that no duplicate stable key was introduced
* confirmation that one row per layer is tested
* confirmation that layer order is tested
* confirmation that frame cell rendering is tested
* confirmation that empty placeholder behavior is tested
* confirmation whether callbacks are tested or intentionally left to lower-level frame cell tests
* confirmation whether exposure/mark/frame name forwarding is tested
* confirmation that no fragile pointer-offset or scroll test was added
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
