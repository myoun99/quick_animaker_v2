# Phase 140 Codex Task

## Title

Add focused tests for TimelineLayerFrameBodyLayout

## Goal

Add focused widget tests for the extracted `TimelineLayerFrameBodyLayout`.

This is a stabilization phase after PR194.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="dgm17x"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR194 extracted the high-level layer/frame body layout from `LayerTimelineGrid` into:

```txt id="sxu8rt"
lib/src/ui/timeline/timeline_layer_frame_body_layout.dart
```

The extracted widget is layout-only. It arranges:

```txt id="g1vvb3"
1. layer controls rail
2. vertical scrollbar slot
3. frame grid area
```

This phase adds focused tests so future refactors do not accidentally change child order or move the layer rail into the frame grid area.

## Test file

Create:

```txt id="ql2kp7"
test/ui/timeline_layer_frame_body_layout_test.dart
```

## Widget under test

Test:

```txt id="3pv705"
TimelineLayerFrameBodyLayout
```

from:

```txt id="4an81k"
lib/src/ui/timeline/timeline_layer_frame_body_layout.dart
```

## Test setup

Render the widget inside a minimal Material widget tree.

Use local test keys for provided children:

```txt id="ubrg5y"
test-layer-controls-rail
test-vertical-scrollbar-slot
test-frame-grid-area
```

Suggested harness:

```dart id="jnf6cm"
await tester.pumpWidget(
  const MaterialApp(
    home: Material(
      child: SizedBox(
        width: 600,
        height: 120,
        child: TimelineLayerFrameBodyLayout(
          layerControlsRail: SizedBox(
            key: ValueKey<String>('test-layer-controls-rail'),
            width: 120,
            height: 120,
          ),
          verticalScrollbarSlot: SizedBox(
            key: ValueKey<String>('test-vertical-scrollbar-slot'),
            width: 14,
            height: 120,
          ),
          frameGridArea: Expanded(
            child: SizedBox(
              key: ValueKey<String>('test-frame-grid-area'),
              height: 120,
            ),
          ),
        ),
      ),
    ),
  ),
);
```

Adjust the exact harness only if needed by Flutter layout constraints.

## Required tests

### 1. Provided layer controls rail renders

Verify:

```txt id="k7d0hh"
test-layer-controls-rail
```

exists exactly once.

### 2. Provided vertical scrollbar slot renders

Verify:

```txt id="fbn0op"
test-vertical-scrollbar-slot
```

exists exactly once.

### 3. Provided frame grid area renders

Verify:

```txt id="91exer"
test-frame-grid-area
```

exists exactly once.

### 4. Child order is preserved

Verify the direct `Row.children` order is:

```txt id="s8114z"
1. layerControlsRail
2. verticalScrollbarSlot
3. frameGridArea
```

Use widget inspection:

```dart id="egipk5"
final row = tester.widget<Row>(find.byType(Row));
expect(row.children.length, 3);
```

Then verify:

```txt id="iwjtfz"
- row.children[0] contains or is test-layer-controls-rail
- row.children[1] contains or is test-vertical-scrollbar-slot
- row.children[2] contains or is test-frame-grid-area
```

If the frame grid area is wrapped in `Expanded`, inspect descendants rather than requiring the direct child key to match.

### 5. Row cross axis alignment is preserved

Verify:

```txt id="fqk0xe"
Row.crossAxisAlignment == CrossAxisAlignment.start
```

This protects the layout behavior extracted from `LayerTimelineGrid`.

### 6. No production stable key is introduced or duplicated

This widget should not introduce public timeline keys.

Verify the test uses only local test keys.

Do not add keys like:

```txt id="psjqia"
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-vertical-scrollbar-slot
```

inside `TimelineLayerFrameBodyLayout`.

Those keys should remain owned by `LayerTimelineGrid` call sites.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="d4e1xa"
- exact colors
- exact borders
- scroll gesture behavior
- drag behavior
- LayerTimelineGrid parent layout
- TimelineFrameScrollViewport internals
- TimelineFrameGridStack internals
- raw controller offset changes
```

This phase tests only `TimelineLayerFrameBodyLayout`.

## Do not change

Do not change production behavior.

Do not change:

```txt id="61hh1b"
- LayerTimelineGrid
- TimelineLayerFrameBodyLayout
- TimelineFrameGridStack
- TimelineFrameRowsScrollBody
- TimelineFrameScrollViewport
- TimelineBodyCutEndBoundary
- TimelinePlayhead
- TimelineVerticalScrollbarSlot
- TimelineVerticalScrollbarRail
- TimelineHorizontalScrollbarRail
- TimelineLayerControlsHeader
- TimelineLayerControlsRow
- TimelineFrameHeaderRow
- TimelineRulerCutEndBoundary
- TimelineFrameRuler
- TimelineFrameCell
- TimelineFrameCellsRow
- TimelineSelectedExposureOutline
- TimelineFrameCoordinatePolicy
- TimelineHorizontalOffsetPolicy
- SelectedExposureDisplayRangePolicy
- Cut.duration
- playbackFrameCount
- TimelineController.authoredTimelineExtentFrameCount
```

Do not change:

```txt id="mvw3em"
- layer controls rail position
- vertical scrollbar slot position
- frame grid area position
- bottom horizontal scrollbar behavior
- vertical scrollbar behavior
- horizontal scroll controller ownership
- horizontal scroll synchronization
- vertical scroll synchronization
- sticky header/ruler behavior
- frame row order
- frame cell rendering
- selected exposure outline behavior
- cut-end boundary behavior
- playhead behavior
- timeline range semantics
```

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="t8f3xx"
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
TimelineLayerFrameBodyLayout
```

Do not use `CustomPainter`.

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Do not redesign UI.

## Required checks

Run:

```bash id="yl3os4"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="ixbssk"
1. Layer controls rail remains on the left.
2. Vertical scrollbar slot remains between layer controls rail and frame grid.
3. Bottom horizontal scrollbar remains under the frame grid only.
4. Frame grid rows still render in the same order.
5. Frame cells still render for every visible layer.
6. Frame cell click still selects the frame.
7. Frame cell click still selects the layer.
8. Selected exposure outline still aligns with frame cells.
9. Playhead still aligns with the current frame column.
10. Cut-end boundary still aligns after horizontal and vertical scrolling.
11. Horizontal scrolling moves frame rows with ruler/header.
12. Vertical scrolling moves layer rows and frame rows together.
13. Layer controls rail and frame grid row alignment is unchanged.
14. Empty layer placeholder behavior is unchanged.
```

## Report back

Report:

```txt id="k445k9"
- changed files
- new test file
- whether production code changed
- test cases added
- confirmation that layer controls rail child rendering is tested
- confirmation that vertical scrollbar slot child rendering is tested
- confirmation that frame grid area child rendering is tested
- confirmation that child order is tested
- confirmation that Row crossAxisAlignment is tested
- confirmation that no production stable key was introduced in TimelineLayerFrameBodyLayout
- confirmation that no duplicate stable key was introduced
- confirmation that no fragile pointer-offset or scroll test was added
- confirmation that horizontal scroll behavior did not change
- confirmation that vertical scroll behavior did not change
- confirmation that sticky header/ruler behavior did not change
- confirmation that timeline range semantics did not change
- confirmation that authoredTimelineExtentFrameCount was not reintroduced
- confirmation that no CustomPainter was introduced
- check results
- git status summary
```
