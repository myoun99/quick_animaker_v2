# Phase 137 Codex Task

## Title

Add focused tests for timeline frame grid stack

## Goal

Add focused widget tests for the extracted `TimelineFrameGridStack`.

This is a stabilization phase after PR191.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="g491kb"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR191 extracted frame grid stack composition from `LayerTimelineGrid` into:

```txt id="0zn0ad"
lib/src/ui/timeline/timeline_frame_grid_stack.dart
```

The extracted widget is responsible only for layout composition:

```txt id="p49sou"
1. render rows body
2. render body cut-end boundary
3. render optional playhead overlay
```

This phase adds focused tests so future refactors do not break child order, boundary rendering, playhead visibility, or playhead overlay positioning.

## Test file

Create:

```txt id="r9y5ex"
test/ui/timeline_frame_grid_stack_test.dart
```

## Widget under test

Test:

```txt id="wzaqc0"
TimelineFrameGridStack
```

from:

```txt id="ddqb6h"
lib/src/ui/timeline/timeline_frame_grid_stack.dart
```

## Current widget API

Use the current constructor from production code.

At the time of this task, it should look like:

```dart id="zas13h"
TimelineFrameGridStack({
  required Widget rowsBody,
  required double cutEndBoundaryLeft,
  required bool showPlayhead,
  required double playheadWidth,
  required Widget playhead,
})
```

Do not change this API unless required by analyzer/test issues.

## Test setup

Render the widget inside a minimal Material widget tree.

Suggested shape:

```dart id="55qe31"
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: SizedBox(
        width: 480,
        height: 120,
        child: TimelineFrameGridStack(
          rowsBody: const SizedBox(
            key: ValueKey<String>('test-rows-body'),
            width: 480,
            height: 120,
          ),
          cutEndBoundaryLeft: 240,
          showPlayhead: true,
          playheadWidth: 480,
          playhead: const SizedBox(
            key: ValueKey<String>('test-playhead'),
            width: 480,
            height: 120,
          ),
        ),
      ),
    ),
  ),
);
```

Use actual project imports and existing test style.

## Required stable keys

The stack itself does not need to introduce a new public key.

Test existing downstream keys produced by the stack:

```txt id="8cl12g"
timeline-cut-end-boundary
```

Also use local test keys for provided children:

```txt id="0i5l53"
test-rows-body
test-playhead
```

Do not invent new production keys.

Do not change existing production keys.

## Required tests

### 1. Provided rows body renders

Render `TimelineFrameGridStack` with a rows body child using key:

```txt id="o7q502"
test-rows-body
```

Verify it exists exactly once.

### 2. Body cut-end boundary renders

Render `TimelineFrameGridStack`.

Verify:

```txt id="2spb8r"
timeline-cut-end-boundary
```

exists exactly once.

This confirms the stack creates `TimelineBodyCutEndBoundary`.

### 3. Cut-end boundary left is passed through

Use:

```txt id="v2qkzh"
cutEndBoundaryLeft: 240
```

Find the `Positioned` ancestor of:

```txt id="s9mt6k"
timeline-cut-end-boundary
```

Verify its `left` is `240`.

Do not assert colors.

### 4. Playhead overlay renders when showPlayhead is true

Use:

```txt id="8x8mqp"
showPlayhead: true
```

Pass a playhead child with key:

```txt id="d0ig4w"
test-playhead
```

Verify it exists exactly once.

### 5. Playhead overlay does not render when showPlayhead is false

Use:

```txt id="m8gl61"
showPlayhead: false
```

Pass the same playhead child.

Verify:

```txt id="51b0fi"
test-playhead
```

does not exist.

### 6. Playhead overlay width is passed through

Use:

```txt id="6ky7zo"
playheadWidth: 480
showPlayhead: true
```

Find the `Positioned` ancestor of:

```txt id="dvwku6"
test-playhead
```

Verify:

```txt id="6pusui"
left == 0
top == 0
width == 480
```

Do not assert playhead internals here.

`TimelinePlayhead` itself is not under test in this phase.

### 7. Stack child order is preserved

Verify the direct `Stack.children` order is:

```txt id="faz0cj"
1. rows body
2. TimelineBodyCutEndBoundary
3. playhead Positioned, only when showPlayhead is true
```

Use a stable widget inspection if simple:

```dart id="h3iqpj"
final stack = tester.widget<Stack>(find.byType(Stack));
expect(stack.children.length, 3);
```

Then verify:

```txt id="lgimj7"
- first child contains test-rows-body
- second child is TimelineBodyCutEndBoundary or contains timeline-cut-end-boundary
- third child contains test-playhead
```

If direct type inspection becomes too brittle, use render order/descendant checks and do not overfit.

### 8. No duplicate stable key is introduced

Verify:

```txt id="t3wbir"
timeline-cut-end-boundary
```

exists exactly once.

If the test rows body uses `timeline-frame-rows-scroll-body` as a provided key in one test, verify it also exists exactly once.

Do not attach the same stable key both at call site and inside a child.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="unoh0j"
- exact colors
- exact border colors
- raw scroll behavior
- raw drag behavior
- selected exposure outline behavior
- TimelinePlayhead internals
- TimelineFrameRowsScrollBody internals
- LayerTimelineGrid parent layout
```

This phase tests only `TimelineFrameGridStack`.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineFrameGridStack`
* `TimelineFrameRowsScrollBody`
* `TimelineFrameScrollViewport`
* `TimelineBodyCutEndBoundary`
* `TimelinePlayhead`
* `LayerTimelineGrid`
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

```txt id="hlus7u"
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

```bash id="p548q8"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="6y9t7w"
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
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that provided rows body rendering is tested
* confirmation that `timeline-cut-end-boundary` rendering is tested
* confirmation that cut-end boundary left passthrough is tested
* confirmation that playhead overlay visible/hidden behavior is tested
* confirmation that playhead overlay width/position passthrough is tested
* confirmation that stack child order is tested
* confirmation that no duplicate stable key was introduced
* confirmation that no fragile pointer-offset or scroll test was added
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
