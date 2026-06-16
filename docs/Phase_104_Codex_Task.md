# Phase 104 Codex Task - Timeline Cut Boundary and Post-Cut Tail Foundation

## Goal

Add a clear visual boundary for the end of the active Cut in the horizontal TimelinePanel, and show a fixed post-cut tail area after the Cut end.

This phase exists to separate:

* actual Cut frame count
* displayed Timeline frame count

This is required before implementing exposure block visuals, exposure handle dragging, cut duration editing, and the Premiere-style StoryboardPanel.

## Current State

Phase 103 added frame ruler click/drag scrubbing.

After PR 146, PR 147, and PR 148:

* The frame ruler can receive click/drag scrub input.
* Ruler selection clamps to the valid actual frame range.
* Padded frame headers cannot emit out-of-range frame indices.
* Ruler pointer coordinates are converted through the visible scrub viewport using global-to-local conversion.
* Sticky ruler layout from Phase 102 / PR 145 is preserved.
* The default sample Cut is still effectively too short for useful manual timeline checking.

## Required Behavior

### 1. Default sample Cut duration

Update the default sample project so the initial sample Cut has a duration of 24 frames.

Current sample project should become:

* Cut 1 duration: 24 frames
* Existing sample timeline may still contain a blank exposure at frame 0
* Do not add real frame data for all 24 frames
* Do not add new models

This is mainly for development and manual verification.

### 2. Display 24 post-cut tail frames

The horizontal TimelinePanel should display extra frames after the actual Cut end.

For this phase:

* actual cut frame count = `frameCount`
* post-cut tail frame count = 24
* display frame count = `frameCount + 24`

Example:

* actual Cut frames: 1-24
* post-cut tail display frames: 25-48
* total visible/renderable timeline range: 1-48

Internal frame indices are still zero-based:

* actual Cut frames: 0-23
* post-cut tail frames: 24-47

### 3. Separate actual frame count from display frame count

Do not keep using one `frameCount` value for both selection validity and rendered timeline width.

Implement a clear separation.

Preferred direction:

* Keep existing `frameCount` as the actual valid Cut frame count.
* Add a display count concept such as:

    * `displayFrameCount`
    * or `postCutTailFrameCount`
    * or a small helper that computes `displayFrameCount = frameCount + postCutTailFrameCount`

The virtualization/rendering plan should use the display frame count.

Selection and scrubbing should still clamp to the actual Cut frame count.

Important:

* `currentFrameIndex` must never become greater than `frameCount - 1` in this phase.
* Clicking/scrubbing in the post-cut tail area must not emit an out-of-range frame index.
* For this phase, clamping post-cut tail interactions to the last valid Cut frame is acceptable.

### 4. Cut end boundary line

Render a clear vertical red line at the actual Cut end boundary.

For a 24-frame Cut:

* the boundary is between frame 24 and frame 25
* internal x position is `frameCount * frameCellWidth`
* with 24 frames and 48px cells, boundary x is `24 * 48`

The line should:

* be red
* be thin but clearly visible
* scroll horizontally with the frame content
* remain aligned with the frame ruler and frame cells
* appear at the boundary between actual Cut frames and post-cut tail frames
* not replace the playhead
* not be confused with the playhead column

Suggested stable key:

* `timeline-cut-end-boundary`

If separate header/body boundary widgets are needed, use clear keys such as:

* `timeline-cut-end-boundary-header`
* `timeline-cut-end-boundary-body`

### 5. Post-cut tail visual style

Frames after the Cut end should be visually different from actual Cut frames.

The post-cut tail area should look like ghost/disabled future space.

Recommended visual direction:

* slightly muted background
* lower contrast header text
* still show frame numbers
* still show grid cells
* no real exposure state
* no drawing start / held exposure / blank start / blank held styling beyond the Cut end

The exact colors can follow the existing theme.

Do not overdesign the style in this phase.

### 6. Preserve frame ruler scrub behavior

The ruler scrub behavior from Phase 103 must remain intact.

Required:

* Clicking valid frame ruler positions selects the correct frame.
* Dragging the ruler scrubs frames.
* Horizontal scroll offset is respected.
* Padded/post-cut frame headers do not emit out-of-range frame indices.
* Duplicate callbacks for the same frame during drag are still suppressed.
* Selection clamps to `0 <= frameIndex < actualCutFrameCount`.

### 7. Preserve sticky ruler and scrollbar behavior

Do not undo Phase 102 / PR 145.

Required:

* The frame ruler remains vertically sticky.
* The left `+ Layer` header remains vertically sticky.
* Only body rows scroll vertically.
* Horizontal scroll keeps ruler and frame cells synchronized.
* The bottom horizontal scrollbar remains under the frame grid.
* The vertical scrollbar slot remains between layer rail and frame grid.
* No RenderFlex overflow.
* No second horizontal ScrollController.

### 8. Preserve existing keys

Do not remove or rename existing stable keys unless absolutely necessary.

Must preserve:

* `timeline-sticky-header-row`
* `timeline-frame-ruler`
* `timeline-frame-ruler-scrub-area`
* `timeline-frame-header-row`
* `timeline-frame-header-<frameIndex>`
* `timeline-frame-header-leading-spacer`
* `timeline-frame-header-trailing-spacer`
* `timeline-frame-scroll-viewport`
* `timeline-frame-scroll-content`
* `timeline-horizontal-scrollbar`
* `timeline-vertical-scrollbar`
* `timeline-vertical-scrollbar-slot`
* `timeline-layer-controls-rail`
* `timeline-frame-grid-area`
* `timeline-playhead`
* `timeline-playhead-column`

Add stable key:

* `timeline-cut-end-boundary`

Optional additional keys:

* `timeline-post-cut-tail`
* `timeline-post-cut-frame-header-<frameIndex>`
* `timeline-post-cut-frame-cell-<layerId>-<frameIndex>`

Only add optional keys if they are useful for clean tests.

## Likely Files To Change

Likely:

* `lib/src/ui/home_page.dart`
* `lib/src/ui/timeline/layer_timeline_grid.dart`
* `lib/src/ui/timeline/timeline_frame_ruler.dart`
* `test/ui/layer_timeline_grid_test.dart`
* `test/ui/timeline_panel_test.dart`
* `test/ui/home_page_test.dart` if needed

Optional:

* `docs/LongTerm_Performance_Architecture.md`
* `docs/LongTerm_StoryboardPanel_TimelineDesign.md`

Do not change domain models unless absolutely necessary.

## Suggested Implementation Direction

### A. Sample Cut duration

Update the sample Cut in `HomePage` so:

* `duration: 24`

Do not create 24 separate frame objects.

### B. Display frame count

Add a display frame count concept to the horizontal timeline.

Possible approach:

* Keep `LayerTimelineGrid.frameCount` as actual Cut frame count.
* Add `postCutTailFrameCount`, default 24.
* Compute:

    * `displayFrameCount = frameCount + postCutTailFrameCount`

Use `displayFrameCount` for:

* virtualization plan
* ruler header rendering
* horizontal content width
* trailing visible timeline range

Use actual `frameCount` for:

* scrub clamp
* current frame validity
* playhead validity
* frame selection
* exposure state validity
* cut end boundary position

### C. Post-cut frame styling

When rendering a header or cell with:

* `frameIndex >= frameCount`

treat it as post-cut tail.

For post-cut cells:

* use ghost/disabled style
* do not show exposure states as actual cells
* do not allow out-of-range selection
* if clicked/scrubbed, clamp to the last valid actual frame for now

### D. Cut end boundary

Render a vertical line at:

* x = `frameCount * metrics.frameCellWidth - horizontalScrollOffset`

The line should be visible only when the boundary is inside or near the viewport.

It should align with both:

* frame ruler
* frame grid rows

Prefer implementing it as a small visual overlay rather than changing cell widths.

Keep z-order clear:

* post-cut tail background below cells
* cut end boundary above cells
* playhead column remains visible
* playhead and cut end line should not destroy each other visually

## Tests Required

Add or update tests for:

### 1. Sample Cut duration

A HomePage or sample project test should verify the default sample Cut has 24 frames/duration.

### 2. Display frame count

With actual `frameCount: 24` and post-cut tail `24`, the horizontal ruler should be able to render/display frame headers up to frame index 47.

At minimum verify:

* `timeline-frame-header-23` exists
* `timeline-frame-header-24` exists as post-cut tail
* `timeline-frame-header-47` exists when visible or after scrolling if virtualization requires it

### 3. Cut end boundary

Verify `timeline-cut-end-boundary` exists.

Verify its position corresponds to the boundary after actual frame count.

For a 24-frame Cut with 48px cells, the boundary should be placed at the boundary after frame index 23.

### 4. Post-cut selection clamp

With actual `frameCount: 24` and display frame count 48:

* tapping or scrubbing around frame index 24 or beyond must not select 24 or greater
* selected frame should clamp to 23 for this phase

### 5. Valid frame selection still works

Verify:

* tapping frame index 0 selects 0
* tapping frame index 4 selects 4
* tapping frame index 9 selects 9
* tapping frame index 23 selects 23

### 6. Existing Phase 103 tests remain valid

Existing ruler tests must still pass:

* clicking different ruler positions selects different frames
* ruler tap updates stateful current frame selection
* dragging frame ruler scrub area scrubs changed frames
* frame ruler scrub respects horizontal scroll offset
* frame ruler scrub clamps selected frame to frame count
* padded frame header tap clamps to last valid frame

### 7. Existing sticky/overflow tests remain valid

Preserve all tests related to:

* sticky frame ruler
* vertical body-only scroll
* horizontal sync
* no RenderFlex overflow
* playhead rendering

## Out of Scope

Do not implement:

* exposure block border visuals
* exposure left/right handles
* exposure handle dragging
* exposure command refactor
* cut duration editing
* dragging the red cut end boundary
* extending the Cut by clicking post-cut tail
* auto-extending Cut duration
* playback
* zoom
* snapping
* auto-scroll while scrubbing
* multi-frame selection
* range selection
* onion skin
* StoryboardPanel changes
* camera track
* sound track
* renderer/cache changes
* persistence format changes
* undo/redo changes
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance Criteria

This phase is complete when:

1. Default sample Cut duration is 24.
2. Horizontal TimelinePanel displays 24 actual frames plus 24 post-cut tail frames.
3. A red cut end boundary appears between actual frame 24 and post-cut frame 25.
4. Post-cut tail frames are visually distinguishable from actual Cut frames.
5. Clicking/scrubbing actual frames selects correct frames.
6. Clicking/scrubbing post-cut tail does not select out-of-range frames.
7. Phase 103 ruler scrub still works.
8. Phase 102/PR145 sticky ruler and overflow behavior remains intact.
9. `dart format lib test` passes.
10. `flutter analyze` passes.
11. `flutter test` passes.
12. `git status` is clean or only expected files are changed.
