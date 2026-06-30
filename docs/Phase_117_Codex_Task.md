# Phase 117 Codex Task

## Title

Extract selected exposure outline widget

## Goal

Extract the selected exposure outline overlay rendering from `LayerTimelineGrid` into a dedicated small widget.

This is a stabilization/refactor phase after PR167, PR169, PR170, and PR171.

No visual behavior should change.

## Why this phase exists

The selected exposure outline had several recent regressions because range semantics, coordinate math, and rendering were mixed inside `LayerTimelineGrid`.

Recent phases separated:

* selected exposure display-range semantics
* horizontal offset clamp policy
* frame coordinate policy
* long-term timeline range semantics documentation
* handoff reference to the range semantics document

This phase keeps going in the same direction by separating the actual selected exposure outline widget from the row implementation.

After this phase:

* `_FrameCellsRow` should decide whether the row has a selected exposure display range.
* The new widget should render the row-level outline.
* The coordinate math should use `timeline_frame_coordinate_policy.dart`.
* The semantics should continue to come from `selected_exposure_display_range_policy.dart`.

## Required reference

Before editing timeline code, read:

```txt id="vxkxjw"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## New file

Create:

```txt id="7zp9ul"
lib/src/ui/timeline/timeline_selected_exposure_outline.dart
```

## Suggested widget

Create a small widget for the selected exposure outline overlay.

Suggested shape:

```dart id="0knqw1"
class TimelineSelectedExposureOutline extends StatelessWidget {
  const TimelineSelectedExposureOutline({
    super.key,
    required this.layerId,
    required this.displayRange,
    required this.frameStartIndex,
    required this.leadingFrameSpacerWidth,
    required this.frameCellWidth,
    required this.rowHeight,
    required this.borderColor,
    required this.borderRadius,
  });

  final LayerId layerId;
  final SelectedExposureDisplayRange displayRange;
  final int frameStartIndex;
  final double leadingFrameSpacerWidth;
  final double frameCellWidth;
  final double rowHeight;
  final Color borderColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!displayRange.hasVisibleIntersection) {
      return const SizedBox.shrink();
    }

    return Positioned(
      key: ValueKey<String>(
        'timeline-selected-exposure-range-outline-$layerId',
      ),
      left: frameVisibleX(
        frameIndex: displayRange.visibleStartFrameIndex,
        frameStartIndex: frameStartIndex,
        frameCellWidth: frameCellWidth,
        leadingFrameSpacerWidth: leadingFrameSpacerWidth,
      ),
      top: 0,
      width: frameRangeVisibleWidth(
        startFrameIndex: displayRange.visibleStartFrameIndex,
        endFrameIndexExclusive: displayRange.visibleEndFrameIndexExclusive,
        frameCellWidth: frameCellWidth,
      ),
      height: rowHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}
```

Adjust exact imports/types if needed.

## Required behavior

The new widget must preserve the existing selected exposure outline behavior exactly:

* Same key:

    * `timeline-selected-exposure-range-outline-<layerId>`
* Same row-level overlay approach.
* Same transparent fill.
* Same red outline color.
* Same border width.
* Same border radius.
* Same `IgnorePointer`.
* Same `DecoratedBox`.
* Same visible intersection positioning.
* Same width calculation.
* No `CustomPainter`.

The widget must use:

```txt id="rcp4i7"
selected_exposure_display_range_policy.dart
timeline_frame_coordinate_policy.dart
```

for its input semantics and coordinate math.

## Update LayerTimelineGrid

Update `_FrameCellsRow` in `LayerTimelineGrid`:

* Keep using `resolveSelectedExposureDisplayRange(...)`.
* Remove inline `Positioned + IgnorePointer + DecoratedBox` selected outline rendering from `_FrameCellsRow`.
* Replace it with `TimelineSelectedExposureOutline(...)`.
* Keep existing per-cell selected range segment logic unchanged.
* Keep existing `Stack` structure unchanged.
* Keep existing cell rendering unchanged.

The intent is to reduce `_FrameCellsRow` complexity without changing behavior.

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

Add a small widget test for the new outline widget.

Create:

```txt id="gu208n"
test/ui/timeline_selected_exposure_outline_test.dart
```

Test cases:

### 1. does not render outline when there is no visible intersection

* Create a `SelectedExposureDisplayRange` with no visible intersection.
* Pump the widget inside a `Stack`.
* Expect the outline key is not found.

### 2. renders outline with stable key when visible intersection exists

* Use `layerId = LayerId('layer-1')`
* Use visible intersection such as `10..13`
* Pump inside a `Stack`
* Expect key:

    * `timeline-selected-exposure-range-outline-layer-1`
* Expect an `IgnorePointer` exists under the outline.

### 3. computes outline left and width with coordinate policy

Use:

* `frameStartIndex = 8`
* `visibleStartFrameIndex = 10`
* `visibleEndFrameIndexExclusive = 13`
* `frameCellWidth = 48`
* `leadingFrameSpacerWidth = 96`

Expected:

```txt id="e8423y"
left = 96 + (10 - 8) * 48 = 192
width = (13 - 10) * 48 = 144
```

Use widget position/size assertions if stable in the existing test environment.

Avoid fragile pixel assumptions beyond values derived from the policy inputs.

### 4. existing LayerTimelineGrid tests continue to pass

Do not remove existing tests:

* PR165 resize tests
* PR166/PR167 selected exposure display-range tests
* PR168 horizontal offset policy tests
* PR169 frame coordinate policy tests
* ruler/body alignment tests

## Required checks

Run:

```bash id="5odv7a"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

Also run:

```bash id="gp6z8b"
git diff --check
```

## Report back

Report:

* changed files
* new selected exposure outline widget file
* new widget test file
* how `_FrameCellsRow` now delegates outline rendering
* confirmation that selected exposure display-range semantics did not change
* confirmation that outline key did not change
* confirmation that outline visual style did not change
* confirmation that PR165/PR168 resize offset behavior did not change
* confirmation that PR169 coordinate policy is used for outline position/width
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
