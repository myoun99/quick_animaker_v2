# Phase 107 Codex Task - Exposure Block Visual Foundation

## Goal

Add the visual foundation for exposure blocks in the Timeline.

This phase is visual-only.

The goal is to make contiguous exposure ranges look like connected blocks, similar to TVPaint/Xsheet-style animation timelines, while preserving the current data model and all Phase 104R/105/106 semantics.

## Background

Current state:

- Timeline cells show per-frame symbols such as drawing start, held exposure, blank start, blank held, marks, and frame names.
- Cut.duration means playback/export duration only.
- Cut.duration is not an edit limit.
- Cut.duration is not a selection limit.
- Cut.duration is not a data deletion boundary.
- visibleFrameCount is computed from playbackFrameCount + safetyFrameCount using TimelineFrameRange.
- Outside-playback visible frames are selectable and editable.
- Authored data outside playback remains visible when inside visible range.
- Authored data outside visible range remains stored but hidden.
- Cut end boundary is visible in both the body grid and ruler.

This phase must build on those rules.

## Core Design Rule

Exposure blocks are a visual representation of existing timeline exposure data.

They must not become a new data model in this phase.

Do not introduce a separate exposure block model.

Do not rewrite the Layer.timeline structure.

Do not add duration editing.

Do not add drag handles.

Do not add block resizing.

## Desired Visual Concept

A drawing exposure should visually appear as one connected block across:

- drawingStart cell
- heldExposure cells that continue from that drawing

A blank exposure should visually appear as one connected block across:

- blankStart cell
- blankHeld cells that continue from that blank

Examples:

Drawing exposure:

frame 0: drawingStart
frame 1: heldExposure
frame 2: heldExposure

should look like one connected drawing block spanning frames 0..2.

Blank exposure:

frame 5: blankStart
frame 6: blankHeld
frame 7: blankHeld

should look like one connected blank block spanning frames 5..7.

Empty cells should not become blocks.

Marks and frame names should remain overlays/content on top of the cell/block visuals.

## Required Behavior

### 1. Preserve existing cell meaning

Do not change the meaning of:

- TimelineCellExposureState.empty
- TimelineCellExposureState.drawingStart
- TimelineCellExposureState.heldExposure
- TimelineCellExposureState.blankStart
- TimelineCellExposureState.blankHeld

Do not change resolver behavior.

Do not change editing commands.

This phase only changes how connected exposure states are visually styled.

### 2. Add exposure block segment calculation

Create a small pure helper that determines how a cell participates in a visual block.

Suggested file:

- lib/src/ui/timeline/timeline_exposure_block_visual.dart

Possible concepts:

- TimelineExposureBlockKind.none
- TimelineExposureBlockKind.drawing
- TimelineExposureBlockKind.blank

and/or:

- continuesFromPrevious
- continuesToNext

The helper should be based on:

- current cell exposure state
- previous cell exposure state
- next cell exposure state

The helper should be pure and easy to test.

Preferred long-term logic:

- drawingStart starts a drawing block
- heldExposure continues a drawing block when adjacent to drawingStart/heldExposure
- blankStart starts a blank block
- blankHeld continues a blank block when adjacent to blankStart/blankHeld
- empty is not a block

Do not infer new authored data.
Only interpret existing exposure states visually.

### 3. Handle virtualization safely

The visual block calculation must not depend only on currently rendered cells.

For a visible cell, it is acceptable to query adjacent frame states using the existing exposureStateForLayer callback:

- frameIndex - 1
- frameIndex
- frameIndex + 1

This avoids wrong rounded edges at virtualization boundaries.

If frameIndex is 0, there is no previous frame.

If next frame is outside the visible range, do not crash.

Do not expand visibleFrameCount just because a block continues outside the visible range.

Do not disable virtualization.

### 4. Keep outside-playback behavior

Exposure blocks must also work outside playback range.

Example:

- playbackFrameCount = 24
- visibleFrameCount = 48
- drawingStart at frame 45

Frame 45 should show authored drawing data and the exposure block visual if it is visible.

Do not force outside-playback cells to empty.

Do not clamp outside-playback selections.

Do not hide outside-playback authored blocks if they are inside visibleFrameCount.

### 5. Visual styling

The exact design can be simple.

The important requirement is that connected exposure cells read as one visual block.

Recommended initial style:

- drawing block: use existing drawing cell colors as base
- blank block: use existing blank cell colors as base
- connected cells should reduce internal visual separation
- block start may have rounded left corners
- block end may have rounded right corners
- middle cells may have square left/right corners
- selected cell border must remain visible
- mark symbol must still have priority over exposure symbol/name
- frame name must still display according to existing priority rules

Do not introduce complex gradients or heavy painting.

Prefer simple Container/BoxDecoration changes.

### 6. Preserve current priorities

The current display priority must remain:

- mark has priority over frame name / exposure symbol
- frame name has priority over default drawing symbol
- blank X remains visible for blank start
- held exposure semantics remain available
- selected cell visual remains visible

Do not regress accessibility/semantics labels.

### 7. No behavior changes

Do not change:

- Cut.duration semantics
- playbackFrameCount
- visibleFrameCount
- safetyFrameCount
- authoredTimelineExtentFrameCount
- TimelineFrameRange calculation
- selection behavior
- editing behavior
- cut end boundary behavior
- horizontal/vertical scroll behavior
- sticky ruler behavior
- layer order behavior
- storyboard layer behavior

## Suggested Files

Likely:

- lib/src/ui/timeline/layer_timeline_grid.dart
- lib/src/ui/timeline/timeline_cell_style.dart
- lib/src/ui/timeline/timeline_exposure_block_visual.dart
- test/ui/layer_timeline_grid_test.dart
- test/ui/timeline/timeline_exposure_block_visual_test.dart

Possibly:

- lib/src/ui/timeline/timeline_cell_exposure_state.dart

Only if necessary.

Do not edit model/controller files unless there is a clear compile need.

## Required Tests

### 1. Pure helper tests

Add tests for the exposure block visual helper.

Cover:

- empty creates no block
- drawingStart alone creates a single drawing block
- drawingStart followed by heldExposure continues to the right
- heldExposure between drawing states continues both directions
- heldExposure at the end of a drawing exposure ends the block
- blankStart alone creates a single blank block
- blankStart followed by blankHeld continues to the right
- blankHeld between blank states continues both directions
- drawing and blank blocks do not connect to each other
- empty breaks blocks

### 2. Widget visual tests

Add lightweight widget tests proving:

- a drawingStart + heldExposure sequence renders connected drawing block visuals
- a blankStart + blankHeld sequence renders connected blank block visuals
- outside-playback authored data still renders as a block when visible
- mark priority remains unchanged
- frame name priority remains unchanged
- selected cell border remains visible

Do not write brittle pixel-perfect tests.

Prefer checking stable helper output and widget structure/classes/keys where possible.

### 3. Existing behavior tests must still pass

Preserve existing tests for:

- outside-playback visible frame selection
- outside-playback visible frame editing
- authored data outside playback visible inside visible range
- authored data outside visible range hidden but stored
- body cut end boundary
- ruler cut end boundary
- body/ruler boundary alignment
- ruler scrub
- sticky ruler
- no overflow
- cut switching
- layer ordering

## Stable Keys

Do not remove existing stable keys.

Preserve:

- timeline-cell-<layerId>-<frameIndex>
- timeline-frame-ruler
- timeline-frame-ruler-scrub-area
- timeline-frame-header-row
- timeline-frame-header-<frameIndex>
- timeline-frame-scroll-viewport
- timeline-frame-scroll-content
- timeline-cut-end-boundary
- timeline-cut-end-boundary-ruler
- timeline-playhead
- timeline-playhead-column

If adding new visual block widgets, use stable optional keys such as:

- timeline-exposure-block-<layerId>-<frameIndex>

Only add keys if useful for tests and debugging.

## Out of Scope

Do not implement:

- exposure block drag editing
- exposure block resize handles
- exposure duration editing
- cut duration editing UI
- playback
- export
- zoom
- snapping
- auto-scroll
- onion skin
- StoryboardPanel changes
- renderer/cache/persistence changes
- model rewrite
- new state management
- Provider/Riverpod/Bloc/ChangeNotifier
- destructive trimming/deletion

## Acceptance Criteria

This phase is complete when:

1. Existing drawing/held exposure ranges visually read as connected blocks.
2. Existing blank/blank held ranges visually read as connected blank blocks.
3. Empty cells do not become blocks.
4. Outside-playback visible authored data can display as a block.
5. Cut.duration semantics remain unchanged.
6. visibleFrameCount semantics remain unchanged.
7. Selection/editing behavior remains unchanged.
8. Cut end boundaries remain unchanged.
9. Sticky ruler and scroll behavior remain unchanged.
10. Accessibility/semantics do not regress.
11. dart format lib test passes.
12. flutter analyze passes.
13. flutter test passes.
14. git status is clean or only expected files are changed.

## Report Back

Report:

- changed files
- helper/type names added
- how drawing exposure blocks are detected
- how blank exposure blocks are detected
- how virtualization boundary cases are handled
- how outside-playback blocks remain visible
- confirmation that no data model was added
- confirmation that no editing behavior changed
- confirmation that Phase 104R/105/106 behavior remains intact
- analyze result
- full test result
- git status summary