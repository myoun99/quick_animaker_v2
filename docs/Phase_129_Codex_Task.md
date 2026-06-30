# Phase 129 Codex Task

## Title

Add focused tests for timeline vertical scrollbar rail

## Goal

Add focused widget tests for the extracted vertical scrollbar slot/rail widgets.

This is a stabilization phase after PR183.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="t81cnd"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR183 extracted vertical scrollbar rail rendering from `LayerTimelineGrid` into:

```txt id="ebesdo"
lib/src/ui/timeline/timeline_vertical_scrollbar_rail.dart
```

The vertical scrollbar rail is small but sensitive because it affects:

* stable keys
* body-only vertical scroll behavior
* thumb rendering
* track tap behavior
* controller-driven thumb position
* layer rail / frame grid alignment

This phase adds focused tests so future refactors do not break the extracted widget.

## Test file

Create:

```txt id="ukob87"
test/ui/timeline_vertical_scrollbar_rail_test.dart
```

## Widgets under test

Test:

```txt id="3ncfrv"
TimelineVerticalScrollbarSlot
TimelineVerticalScrollbarRail
```

from:

```txt id="w21q5l"
lib/src/ui/timeline/timeline_vertical_scrollbar_rail.dart
```

## Test setup

Render the widgets inside a minimal Material widget tree.

For `TimelineVerticalScrollbarSlot`, a simple `MaterialApp` / `Material` is enough.

For `TimelineVerticalScrollbarRail`, render it inside a fixed-size parent.

Suggested shape:

```dart id="o4uj4k"
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: SizedBox(
        width: 12,
        height: 120,
        child: TimelineVerticalScrollbarRail(
          controller: controller,
          viewportHeight: 120,
          contentHeight: 360,
          width: 12,
        ),
      ),
    ),
  ),
);
```

Use actual project imports and existing test style.

## Required tests

### 1. Slot stable key exists exactly once

Render `TimelineVerticalScrollbarSlot`.

Verify this key exists exactly once:

```txt id="0v957a"
timeline-vertical-scrollbar-slot
```

Also verify the widget keeps the supplied width and height if this is simple to inspect.

### 2. Rail stable key exists exactly once

Render `TimelineVerticalScrollbarRail`.

Verify this key exists exactly once:

```txt id="rxmza3"
timeline-vertical-scrollbar
```

### 3. Track and thumb keys exist

Render `TimelineVerticalScrollbarRail`.

Verify these keys exist exactly once:

```txt id="la2gxc"
timeline-vertical-scrollbar-track
timeline-vertical-scrollbar-thumb
```

### 4. Thumb is visible when content is taller than viewport

Use:

```txt id="86k1bx"
viewportHeight: 120
contentHeight: 360
```

Verify the thumb widget exists.

If inspecting the `Positioned` under the thumb is simple, verify its height is greater than zero.

Do not make fragile color assertions.

### 5. Thumb height respects minimum height

Use a large content height, for example:

```txt id="unfbw0"
viewportHeight: 120
contentHeight: 2400
```

The calculated thumb height should not be smaller than the current minimum thumb height.

Current expected minimum:

```txt id="pcqg88"
32
```

Verify the thumb `Positioned.height` is `32`.

Do not change the minimum height value.

### 6. Thumb fills viewport when content does not exceed viewport

Use:

```txt id="bfz1oo"
viewportHeight: 120
contentHeight: 120
```

Verify the thumb height is `120`.

This protects the no-scroll visual behavior.

### 7. Track tap uses the provided controller

Create a `ScrollController`.

Attach it to a simple scrollable in the test if needed so `hasClients` is true.

Render the rail with the same controller.

Tap the scrollbar track below the initial thumb position.

Verify controller offset changes from `0` to a value greater than `0`.

If full pointer-based tap setup becomes too fragile, test only the render/keys/geometry behavior and report why the interaction test was skipped.

Do not alter production code just to make this test easier.

### 8. Controller ownership remains external

The test should create the `ScrollController` externally and pass it into `TimelineVerticalScrollbarRail`.

Do not add controller creation inside the production widget.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineVerticalScrollbarSlot`
* `TimelineVerticalScrollbarRail`
* `LayerTimelineGrid`
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

* vertical scrollbar keys
* vertical scrollbar width
* vertical scrollbar thumb minimum height
* vertical scrollbar track behavior
* vertical scrollbar controller ownership
* vertical scroll synchronization
* horizontal scroll synchronization
* sticky header/ruler behavior
* layer controls behavior
* frame cell behavior
* selected exposure outline behavior
* cut-end boundary behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="qcl4om"
TimelinePanel
LayerTimelineGrid
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
TimelineLayerControlsHeader
TimelineLayerControlsRow
TimelineVerticalScrollbarRail
```

Do not use `CustomPainter`.

## Acceptable production changes

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Example acceptable change:

```txt id="bbh894"
Adding a missing super.key to a public widget constructor.
```

Do not redesign any UI.

## Required checks

Run:

```bash id="ualtim"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="n65f4j"
1. Timeline vertical scrollbar appears in the same slot as before.
2. Scrollbar thumb is visible when there are enough layers to scroll.
3. Dragging the scrollbar thumb scrolls the timeline body vertically.
4. Tapping the scrollbar track moves the body scroll position.
5. Vertical scrolling moves layer rows and frame rows together.
6. Sticky frame ruler/header does not vertically scroll.
7. Sticky + Layer header does not vertically scroll.
8. Horizontal scrolling still moves ruler/header/frame rows together.
9. Layer controls rail and frame grid row alignment is unchanged.
10. Selected exposure outline still aligns with frame cells after scrolling.
11. Cut-end boundaries still align after vertical and horizontal scrolling.
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that `timeline-vertical-scrollbar-slot` is tested
* confirmation that `timeline-vertical-scrollbar` is tested
* confirmation that track/thumb keys are tested
* confirmation that thumb height behavior is tested
* confirmation that controller ownership remains external
* confirmation whether track tap/controller interaction was tested or intentionally skipped
* confirmation that vertical scroll behavior did not change
* confirmation that horizontal scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
