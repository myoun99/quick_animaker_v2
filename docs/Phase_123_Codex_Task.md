# Phase 123 Codex Task

## Title

Add focused tests for TimelineFrameHeaderRow

## Goal

Add focused widget tests for `TimelineFrameHeaderRow`.

This is a stabilization phase after PR177.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt id="uef6h4"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

PR177 extracted `TimelineFrameHeaderRow`.

During review, a key duplication risk was found around:

```txt id="n1vtnd"
timeline-frame-header-row
```

That was fixed, but this should now be protected by tests.

This phase adds focused tests to make sure future refactors do not break:

* stable frame header row key
* leading/trailing spacer keys
* per-frame header keys
* visible frame range rendering
* current frame rendering
* outside-playback rendering
* tap-to-select frame behavior

## Test file

Create:

```txt id="wlu7ls"
test/ui/timeline_frame_header_row_test.dart
```

## Widget under test

Test:

```txt id="hpc3hd"
lib/src/ui/timeline/timeline_frame_header_row.dart
```

## Test setup

Render `TimelineFrameHeaderRow` inside a minimal Material widget tree.

Example structure:

```dart id="61nhya"
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: TimelineFrameHeaderRow(
        frameStartIndex: ...,
        frameEndIndexExclusive: ...,
        currentFrameIndex: ...,
        playbackFrameCount: ...,
        leadingFrameSpacerWidth: ...,
        trailingFrameSpacerWidth: ...,
        metrics: TimelineGridMetrics.defaults,
        onSelectFrame: ...,
      ),
    ),
  ),
);
```

Use the actual project imports and existing test style.

## Required tests

Add focused tests for the following.

### 1. Stable row and spacer keys

Verify exactly one row key exists:

```txt id="kuqt0x"
timeline-frame-header-row
```

Verify spacer keys exist:

```txt id="rjqd44"
timeline-frame-header-leading-spacer
timeline-frame-header-trailing-spacer
```

Important:

`timeline-frame-header-row` must not be duplicated.

Use `findsOneWidget`.

### 2. Visible frame headers are rendered

Use a non-zero visible window, for example:

```txt id="eabxku"
frameStartIndex: 3
frameEndIndexExclusive: 6
```

Verify these frame header keys exist:

```txt id="tvkn8t"
timeline-frame-header-3
timeline-frame-header-4
timeline-frame-header-5
```

Verify a frame outside the window does not exist:

```txt id="f6gctg"
timeline-frame-header-6
```

### 3. Frame number text is one-based

For frame indices 3, 4, 5, verify visible labels are:

```txt id="x40zq7"
4
5
6
```

Do not change frame numbering behavior.

### 4. Tapping a frame header selects that frame

Tap:

```txt id="mezukm"
timeline-frame-header-4
```

Verify `onSelectFrame` receives:

```txt id="x42dbg"
4
```

### 5. Current frame header renders without changing key behavior

Set:

```txt id="ibfi5a"
currentFrameIndex: 4
```

Verify:

```txt id="jfjwow"
timeline-frame-header-4
```

still exists exactly once.

Do not make fragile color assertions unless the project already has a stable testing pattern for colors.

### 6. Outside-playback frame header still renders

Use:

```txt id="v5q0pz"
playbackFrameCount: 5
frameStartIndex: 3
frameEndIndexExclusive: 7
```

Verify outside-playback frame header keys still exist:

```txt id="yh0b8o"
timeline-frame-header-5
timeline-frame-header-6
```

This confirms outside-playback frames are visible/rendered, not removed.

Do not assert editability or data extent here.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineFrameHeaderRow` behavior
* `TimelineFrameRuler` behavior
* frame ruler click/drag/scrub behavior
* frame header visual style
* frame header keys
* frame number display
* outside-playback display
* `LayerTimelineGrid`
* `TimelineFrameCell`
* `TimelineFrameCellsRow`
* `TimelineLayerControlsRow`
* `TimelineLayerControlsHeader`
* `TimelineSelectedExposureOutline`
* `TimelineFrameCoordinatePolicy`
* `TimelineHorizontalOffsetPolicy`
* `SelectedExposureDisplayRangePolicy`
* `Cut.duration`
* `playbackFrameCount`
* `TimelineController.authoredTimelineExtentFrameCount`

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel`, `LayerTimelineGrid`, `TimelineFrameRuler`, or `TimelineFrameHeaderRow`.

Do not use `CustomPainter`.

## Acceptable production changes

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Example acceptable change:

```txt id="zoifcp"
Adding a missing super.key to a public widget constructor.
```

Do not redesign any UI.

## Required checks

Run:

```bash id="dxq4f1"
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
* confirmation that `timeline-frame-header-row` is asserted as exactly one widget
* confirmation that visible frame header keys are tested
* confirmation that tap-to-select frame behavior is tested
* confirmation that outside-playback frame headers are still rendered
* confirmation that no timeline range semantics changed
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
