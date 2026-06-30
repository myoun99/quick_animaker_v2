# Phase 126 Codex Task

## Title

Add focused tests for timeline cut-end boundary widgets

## Goal

Add focused widget tests for the extracted cut-end boundary widgets.

This is a stabilization phase after PR179 and PR180.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted the two cut-end boundary markers:

* PR179: `TimelineRulerCutEndBoundary`
* PR180: `TimelineBodyCutEndBoundary`

Both widgets are small but important because their stable keys are used to verify the visual playback/export duration marker.

This phase adds tests to protect:

* `timeline-cut-end-boundary-ruler`
* `timeline-cut-end-boundary`
* marker positioning
* marker width
* marker non-interactive behavior
* separation between ruler boundary and body boundary

## Test file

Create:

```txt
test/ui/timeline_cut_end_boundary_widgets_test.dart
```

## Widgets under test

Test:

```txt
lib/src/ui/timeline/timeline_ruler_cut_end_boundary.dart
lib/src/ui/timeline/timeline_body_cut_end_boundary.dart
```

## Test setup

These widgets use `Positioned`, so render each inside a `Stack`.

Example shape:

```dart
await tester.pumpWidget(
  const MaterialApp(
    home: Material(
      child: SizedBox(
        width: 300,
        height: 120,
        child: Stack(
          children: [
            TimelineRulerCutEndBoundary(left: 48),
          ],
        ),
      ),
    ),
  ),
);
```

Use the actual project imports and existing test style.

## Required tests

### 1. Ruler cut-end boundary stable key exists exactly once

Render `TimelineRulerCutEndBoundary`.

Verify:

```txt
timeline-cut-end-boundary-ruler
```

exists exactly once.

Use:

```dart
findsOneWidget
```

### 2. Body cut-end boundary stable key exists exactly once

Render `TimelineBodyCutEndBoundary`.

Verify:

```txt
timeline-cut-end-boundary
```

exists exactly once.

Use:

```dart
findsOneWidget
```

### 3. Ruler and body boundary keys are not confused

Render both widgets in the same `Stack`.

Verify both keys exist exactly once:

```txt
timeline-cut-end-boundary-ruler
timeline-cut-end-boundary
```

This protects against accidental key reuse.

### 4. Boundary width remains 2

For both widgets, verify the rendered `Positioned` has:

```txt
width: 2
```

Do not use fragile color assertions unless the project already has a stable pattern for color testing.

### 5. Boundary left position is passed through

For both widgets, render with a known `left` value, for example:

```txt
left: 48
```

Verify the `Positioned` has the same left value.

### 6. Boundary marker keeps IgnorePointer

For both widgets, verify an `IgnorePointer` exists under the boundary widget.

This protects the non-interactive marker behavior.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineRulerCutEndBoundary`
* `TimelineBodyCutEndBoundary`
* `TimelineFrameRuler`
* `LayerTimelineGrid`
* `TimelineFrameHeaderRow`
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

* boundary colors
* boundary width
* boundary positioning
* boundary keys
* boundary IgnorePointer behavior
* frame ruler click/drag/scrub behavior
* frame cell selection behavior
* selected exposure outline behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt
TimelinePanel
LayerTimelineGrid
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
```

Do not use `CustomPainter`.

## Acceptable production changes

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Example acceptable change:

```txt
Adding a missing super.key to a public widget constructor.
```

Do not redesign any UI.

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
* new test file
* whether production code changed
* test cases added
* confirmation that `timeline-cut-end-boundary-ruler` is asserted exactly once
* confirmation that `timeline-cut-end-boundary` is asserted exactly once
* confirmation that ruler/body boundary keys are not confused
* confirmation that boundary width is tested
* confirmation that boundary left position is tested
* confirmation that IgnorePointer behavior is tested
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
