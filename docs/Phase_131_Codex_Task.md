# Phase 131 Codex Task

## Title

Add focused tests for timeline horizontal scrollbar rail

## Goal

Add focused widget tests for the extracted bottom horizontal scrollbar rail widget.

This is a stabilization phase after PR185.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="aej1ii"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR185 extracted the bottom horizontal scrollbar rail from `LayerTimelineGrid` into:

```txt id="e0m0oa"
lib/src/ui/timeline/timeline_horizontal_scrollbar_rail.dart
```

The horizontal scrollbar rail is small but sensitive because it affects:

* stable keys
* frame grid horizontal scroll behavior
* ruler/header/frame-row horizontal alignment
* thumb rendering
* track tap handler
* thumb drag handler
* external controller usage
* viewport resize behavior

This phase adds focused tests so future refactors do not break the extracted widget.

## Important note from Phase 129

In Phase 129, pointer-based track tap tests for the vertical scrollbar were fragile in local Flutter tests.

For this phase, avoid fragile pointer hit-test assertions.

Do not require a test that proves `controller.offset` changes after a raw `tapAt()`.

Instead, stabilize the widget by testing:

* stable keys
* geometry
* external controller is passed through
* track tap handler exists
* thumb drag handler exists

Actual drag/tap scrolling must be verified manually.

## Test file

Create:

```txt id="s181k6"
test/ui/timeline_horizontal_scrollbar_rail_test.dart
```

## Widget under test

Test:

```txt id="zrejj7"
TimelineHorizontalScrollbarRail
```

from:

```txt id="fdf8g2"
lib/src/ui/timeline/timeline_horizontal_scrollbar_rail.dart
```

## Test setup

Render the widget inside a minimal Material widget tree.

Suggested shape:

```dart id="3jol5n"
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: SizedBox(
        width: 240,
        height: 16,
        child: TimelineHorizontalScrollbarRail(
          key: const ValueKey<String>('timeline-horizontal-scrollbar'),
          controller: controller,
          viewportWidth: 240,
          contentWidth: 720,
          height: 16,
        ),
      ),
    ),
  ),
);
```

Use actual project imports and existing test style.

## Required stable keys

Test these stable keys if present in current implementation:

```txt id="3kpbcm"
timeline-horizontal-scrollbar
timeline-bottom-scrollbar-rail
timeline-horizontal-scrollbar-track
timeline-horizontal-scrollbar-thumb
```

Do not invent new public keys.

Do not change key names.

## Required tests

### 1. Rail stable key exists exactly once

Render `TimelineHorizontalScrollbarRail`.

Verify this key exists exactly once:

```txt id="2b6a75"
timeline-horizontal-scrollbar
```

### 2. Internal rail / track / thumb keys exist exactly once

Render `TimelineHorizontalScrollbarRail`.

Verify these keys exist exactly once if they are present in the current implementation:

```txt id="42isdd"
timeline-bottom-scrollbar-rail
timeline-horizontal-scrollbar-track
timeline-horizontal-scrollbar-thumb
```

### 3. Thumb is visible when content is wider than viewport

Use:

```txt id="7ho8gf"
viewportWidth: 240
contentWidth: 720
height: 16
```

Verify the thumb widget exists.

If inspecting the `Positioned` under the thumb is simple, verify its width is greater than zero.

Do not make fragile color assertions.

### 4. Thumb width respects minimum width

Use a large content width, for example:

```txt id="8c7lyy"
viewportWidth: 240
contentWidth: 4800
height: 16
```

The calculated thumb width should not be smaller than the current minimum thumb width.

Current expected minimum:

```txt id="1qm1as"
32
```

Verify the thumb `Positioned.width` is `32`.

Do not change the minimum width value.

### 5. Thumb fills viewport when content does not exceed viewport

Use:

```txt id="7coqgo"
viewportWidth: 240
contentWidth: 240
height: 16
```

Verify the thumb width is `240`.

This protects the no-horizontal-scroll visual behavior.

### 6. External controller is passed through

Create a `ScrollController` in the test.

Pass it into `TimelineHorizontalScrollbarRail`.

Verify the rendered widget has the same controller instance.

Example:

```dart id="3scpof"
final rail = tester.widget<TimelineHorizontalScrollbarRail>(
  find.byKey(railKey),
);
expect(rail.controller, same(controller));
```

Do not create controllers inside the production widget.

### 7. Track tap handler exists

Find the `GestureDetector` ancestor of:

```txt id="udlrq6"
timeline-horizontal-scrollbar-track
```

Verify:

```dart id="9rya6d"
expect(trackGestureDetector.onTapDown, isNotNull);
```

Do not require the test to prove `controller.offset` changes after tap.

### 8. Thumb drag handler exists

Find the `GestureDetector` ancestor of:

```txt id="rmt06k"
timeline-horizontal-scrollbar-thumb
```

Verify:

```dart id="6xl3ng"
expect(thumbGestureDetector.onHorizontalDragUpdate, isNotNull);
```

Do not require the test to prove `controller.offset` changes after drag.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="ojrtyy"
- exact colors
- exact border colors
- raw tapAt offset changes
- raw drag offset changes
- hit-test dependent controller offset changes
```

If a pointer-based interaction test is attempted and becomes unstable, remove it and keep the handler-existence tests.

Do not alter production code just to make the test easier.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineHorizontalScrollbarRail`
* `LayerTimelineGrid`
* `TimelineVerticalScrollbarSlot`
* `TimelineVerticalScrollbarRail`
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

* horizontal scrollbar keys
* horizontal scrollbar width/height behavior
* horizontal scrollbar thumb minimum width
* horizontal scrollbar track behavior
* horizontal scrollbar controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* layer controls behavior
* frame cell behavior
* selected exposure outline behavior
* cut-end boundary behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="j3c0ml"
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
```

Do not use `CustomPainter`.

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Do not redesign UI.

## Required checks

Run:

```bash id="mcdfjm"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="wchhu1"
1. Bottom horizontal scrollbar appears under the frame grid only.
2. Horizontal scrollbar does not appear under the layer controls rail.
3. Dragging the horizontal scrollbar thumb scrolls frame cells horizontally.
4. Clicking/tapping the horizontal scrollbar track moves the horizontal scroll position.
5. Horizontal scrolling moves ruler/header/frame rows together.
6. Vertical scrolling still moves layer rows and frame rows together.
7. Sticky frame ruler/header does not vertically scroll.
8. Sticky + Layer header does not vertically scroll.
9. Layer controls rail and frame grid row alignment is unchanged.
10. Selected exposure outline still aligns with frame cells after horizontal scrolling.
11. Cut-end boundaries still align after horizontal and vertical scrolling.
12. Resizing the timeline viewport still clamps horizontal offset correctly.
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that `timeline-horizontal-scrollbar` is tested
* confirmation that `timeline-bottom-scrollbar-rail` is tested if present
* confirmation that track/thumb keys are tested
* confirmation that thumb width behavior is tested
* confirmation that external controller pass-through is tested
* confirmation that track tap handler existence is tested
* confirmation that thumb drag handler existence is tested
* confirmation that no fragile pointer offset test was added
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
