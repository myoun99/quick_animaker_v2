# Phase 133 Codex Task

## Title

Add focused tests for timeline frame scroll viewport

## Goal

Add focused widget tests for the extracted `TimelineFrameScrollViewport`.

This is a stabilization phase after PR187.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="u73x8w"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR187 extracted the frame grid horizontal scroll viewport/content wrapper from `LayerTimelineGrid` into:

```txt id="zwbz46"
lib/src/ui/timeline/timeline_frame_scroll_viewport.dart
```

The viewport wrapper is small but important because it preserves:

* horizontal scroll viewport key
* frame scroll content key
* horizontal scroll controller usage
* content width/height
* child rendering
* frame grid scroll structure

This phase adds focused tests so future refactors do not accidentally duplicate keys or break the viewport/content wrapper.

## Test file

Create:

```txt id="nw4a40"
test/ui/timeline_frame_scroll_viewport_test.dart
```

## Widget under test

Test:

```txt id="uquvfc"
TimelineFrameScrollViewport
```

from:

```txt id="b3b3ex"
lib/src/ui/timeline/timeline_frame_scroll_viewport.dart
```

## Test setup

Render the widget inside a minimal Material widget tree.

Suggested shape:

```dart id="1lctv6"
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: SizedBox(
        width: 240,
        height: 120,
        child: TimelineFrameScrollViewport(
          controller: controller,
          contentWidth: 720,
          contentHeight: 120,
          child: const SizedBox(
            key: ValueKey<String>('test-frame-scroll-child'),
            width: 720,
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

Test these current stable keys:

```txt id="o88udn"
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
```

If `timeline-frame-grid-area` is not inside `TimelineFrameScrollViewport`, do not test it here.

Do not invent new keys.

Do not change key names.

## Required tests

### 1. Viewport keys exist exactly once

Render `TimelineFrameScrollViewport`.

Verify these keys exist exactly once:

```txt id="agdlp9"
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
```

### 2. No duplicate stable keys are introduced

In the same test or a separate test, verify each stable key appears exactly once.

Do not attach the same stable key to the widget constructor and an internal child at the same time.

### 3. Provided child renders

Pass a child with a test key:

```txt id="3wm1v6"
test-frame-scroll-child
```

Verify it renders exactly once.

### 4. Provided controller is passed to the horizontal scroll view

Create a `ScrollController` externally.

Pass it into `TimelineFrameScrollViewport`.

Find the `SingleChildScrollView` with key:

```txt id="tn7zth"
timeline-frame-scroll-viewport
```

Verify:

```dart id="foqw07"
final scrollView = tester.widget<SingleChildScrollView>(
  find.byKey(frameScrollViewportKey),
);

expect(scrollView.controller, same(controller));
expect(scrollView.scrollDirection, Axis.horizontal);
```

Do not create a controller inside the production widget.

### 5. Content size is preserved

Find the `SizedBox` that contains the provided child or inspect an ancestor of the test child.

Verify the provided content dimensions are preserved:

```txt id="msthot"
contentWidth: 720
contentHeight: 120
```

Use a stable approach.

For example, if the child is wrapped by the content `SizedBox`, inspect the nearest `SizedBox` ancestor whose width/height match the provided values.

Do not rely on screen-size defaults.

### 6. It remains a layout wrapper only

The tests should not require any timeline model objects, layers, cuts, frames, or playback range setup.

The viewport widget should be testable with a plain child.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="jtpnhf"
- exact colors
- hit-test dependent drag behavior
- controller offset changing from raw gestures
- assumptions about parent LayerTimelineGrid layout
- timeline model setup
```

Do not alter production code just to make the test easier.

## Do not change

Do not change production behavior.

Do not change:

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

* frame scroll viewport keys
* horizontal scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* bottom horizontal scrollbar behavior
* vertical scrollbar behavior
* frame ruler click/drag/scrub behavior
* layer controls behavior
* frame cell behavior
* selected exposure outline behavior
* cut-end boundary behavior
* playhead behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="3472ro"
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
```

Do not use `CustomPainter`.

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Do not redesign UI.

## Required checks

Run:

```bash id="ap7ure"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="6h0s2s"
1. Frame grid still scrolls horizontally.
2. Horizontal scrolling moves ruler/header/frame rows together.
3. Bottom horizontal scrollbar still controls frame grid horizontal scrolling.
4. Vertical scrolling still moves layer rows and frame rows together.
5. Sticky frame ruler/header does not vertically scroll.
6. Sticky + Layer header does not vertically scroll.
7. Layer controls rail and frame grid row alignment is unchanged.
8. Frame cells still receive click/selection normally.
9. Selected exposure outline still aligns with frame cells after horizontal scrolling.
10. Playhead still aligns with the current frame column.
11. Cut-end boundaries still align after horizontal and vertical scrolling.
12. Timeline viewport resize still clamps horizontal offset correctly.
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that `timeline-horizontal-scrollbar-viewport` is tested
* confirmation that `timeline-frame-scroll-viewport` is tested
* confirmation that `timeline-frame-scroll-content` is tested
* confirmation that no duplicate stable key was introduced
* confirmation that provided child rendering is tested
* confirmation that external controller pass-through is tested
* confirmation that horizontal scroll direction is tested
* confirmation that content size behavior is tested
* confirmation that no fragile pointer-offset test was added
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
