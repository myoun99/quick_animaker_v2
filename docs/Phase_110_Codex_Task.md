# Phase 110 Codex Task - Simplify Exposure Block Cell Decoration

## Goal

Simplify the Timeline exposure block cell rendering.

Remove the custom border painter introduced during the Phase 107 hotfix and return to a simpler BoxDecoration-based cell rendering approach.

The goal is to keep exposure blocks visually readable while preserving visible per-frame cell dividers.

This phase is visual-only.

Do not implement editing.

Do not implement drag or resize behavior.

Do not change the data model.

## Background

After Phase 107:

* exposure blocks became visually connected.
* a custom painter was introduced later to avoid Flutter's BoxDecoration assertion.

The assertion occurred because Flutter does not allow:

* BoxDecoration with borderRadius
* combined with non-uniform Border side colors

The previous implementation tried to hide internal seams by using different border side colors.

That caused this runtime/test failure:

```txt
A borderRadius can only be given on borders with uniform colors.
The following is not uniform:
BorderSide.color
```

The current CustomPainter fix is safe, but the rendering structure is more complex than desired.

We now want a simpler long-term structure.

## Core Direction

Use only simple BoxDecoration for timeline cell background, border, and border radius.

Do not use CustomPainter for cell borders.

Do not hide internal seams by painting over them.

Do not use non-uniform border colors with borderRadius.

Instead, keep the per-frame divider lines visible.

This means connected exposure blocks should still have rounded start/end shapes, but each frame cell should remain visibly separated.

## Required Behavior

### 1. Remove custom border painter

Remove the custom cell border painter from:

* lib/src/ui/timeline/layer_timeline_grid.dart

Remove or stop using:

* _TimelineCellBorderPainter

Do not replace it with another CustomPainter.

### 2. Use safe BoxDecoration only

The timeline cell decoration must use a safe structure similar to:

```dart
BoxDecoration(
  color: backgroundColor,
  border: Border.all(
    color: borderColor,
    width: selected ? 3 : 1,
  ),
  borderRadius: blockBorderRadius,
)
```

Important:

* Use Border.all only.
* Do not use Border(left/right/top/bottom) with different colors.
* Do not use different side colors when borderRadius is present.
* Do not use a painter to mask internal borders.

### 3. Preserve exposure block shape rules

Keep the existing exposure block segment logic.

The visual rules should be:

* single-frame block: left and right rounded
* block start: left rounded, right square
* block middle: left and right square
* block end: left square, right rounded
* non-block empty cell: no block radius or existing neutral radius policy if already used

Timeline direction is left to right.

Therefore:

* exposure start/head should round the left side
* exposure end should round the right side

Apply the same rule to both drawing blocks and blank blocks.

### 4. Restore visible frame dividers inside exposure blocks

Connected exposure blocks must no longer erase per-frame dividers.

Internal vertical lines between frame cells should remain visible.

This is intentional.

The timeline should read as:

* connected exposure range
* but still divided into individual frame cells

This is important for animation timing readability.

### 5. Simplify selected exposure range highlight if necessary

Phase 109 added selected exposure range highlight.

Keep the selected range highlight behavior, but simplify it if needed.

Preferred approach:

* Do not add an overlay widget just to draw selected range borders.
* Prefer blending a subtle selected-range tint into the cell background color.
* Keep the main cell border visible via BoxDecoration.
* Keep selected cell border stronger than range highlight.

If keeping an overlay is simpler, it must not hide the base cell border and must remain non-interactive.

Do not add GestureDetector, hit testing, drag, resize, or commands.

### 6. Preserve selected cell border

The currently selected frame cell must remain clearly visible.

Selected cell border should still be stronger than normal cells.

The selected exposure range highlight must not obscure the selected cell border.

### 7. Preserve display priority

Do not change:

* mark priority
* frame name priority
* exposure symbol priority
* selected cell semantics
* existing timeline cell keys

Text and symbols must remain visible above the cell background.

### 8. Preserve behavior

Do not change:

* Cut.duration semantics
* playbackFrameCount
* visibleFrameCount
* TimelineFrameRange
* exposure range resolver
* exposure block visual segment helper
* selection behavior
* editing behavior
* cut end boundary
* playhead
* sticky ruler
* virtualization
* layer order
* storyboard layer behavior

## Stable Keys

Do not remove existing stable keys:

* timeline-cell-<layerId>-<frameIndex>
* timeline-selected-cell
* timeline-frame-ruler
* timeline-frame-ruler-scrub-area
* timeline-frame-header-row
* timeline-frame-header-<frameIndex>
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-cut-end-boundary
* timeline-cut-end-boundary-ruler
* timeline-playhead
* timeline-playhead-column

Phase 109 added optional selected exposure range cell keys:

* timeline-selected-exposure-range-cell-<layerId>-<frameIndex>

If the selected range highlight is simplified into the main cell decoration and those overlay widgets are removed, update the tests accordingly.

Do not keep unnecessary widget layers only for keys.

## Suggested Files

Likely:

* lib/src/ui/timeline/layer_timeline_grid.dart
* test/ui/layer_timeline_grid_test.dart

Possibly:

* test/ui/timeline/timeline_exposure_block_visual_test.dart

Only if the expected visual rules need pure helper test updates.

## Required Tests

Update or add tests that verify:

1. timeline cells no longer use the custom border painter
2. drawing exposure block start/middle/end radius rules are preserved
3. blank exposure block start/middle/end radius rules are preserved
4. internal frame dividers are not intentionally hidden
5. selected cell border remains visible
6. selected exposure range highlight still works
7. empty selected cells do not create range highlight
8. inactive layers do not show selected range highlight
9. outside-playback visible authored range still highlights
10. no Flutter paint assertion occurs

Avoid pixel-perfect tests.

Prefer checking:

* BoxDecoration type
* Border.all usage
* borderRadius values
* existing widget keys
* selected range visual state through cell decoration or lightweight keys

Do not remove meaningful tests just to pass.

## Out of Scope

Do not implement:

* exposure block drag editing
* exposure block resize behavior
* interactive handles
* exposure duration editing
* cut duration editing UI
* playback
* export
* zoom
* snapping
* auto-scroll
* onion skin
* StoryboardPanel changes
* renderer/cache/persistence changes
* model rewrite
* new state management
* Provider/Riverpod/Bloc/ChangeNotifier
* destructive trimming/deletion

## Acceptance Criteria

This phase is complete when:

1. _TimelineCellBorderPainter is removed or unused.
2. Timeline cell border rendering uses simple BoxDecoration.
3. BoxDecoration uses safe uniform Border.all when borderRadius is present.
4. Exposure block start/middle/end/single radius rules remain correct.
5. Per-frame divider lines remain visible inside exposure blocks.
6. Selected exposure range highlight still works.
7. Selected cell border remains clear.
8. Mark/frame name priority remains unchanged.
9. No editing behavior is added.
10. No data model change is added.
11. Phase 104R / 105 / 106 / 107 / 108 / 109 behavior remains intact.
12. dart format lib test passes.
13. flutter analyze passes.
14. flutter test passes.
15. git status is clean or only expected files are changed.

## Report Back

Report:

* changed files
* whether _TimelineCellBorderPainter was removed
* final cell decoration structure
* how BoxDecoration avoids the old Flutter assertion
* how exposure block radius rules are preserved
* how internal frame dividers remain visible
* how selected exposure range highlight is represented
* confirmation that no editing behavior changed
* confirmation that no data model changed
* confirmation that Phase 104R/105/106/107/108/109 behavior remains intact
* analyze result
* full test result
* git status summary
