# Phase 105 Codex Task - Timeline Ruler Cut Boundary Mirror

## Goal

Add the red cut end boundary line to the frame ruler area as well, so the playback boundary is visible in both:

- the sticky frame ruler/header area
- the frame cell body area

This is a small UI refinement phase.
It must reuse the existing playback boundary semantics from Phase 104R.

## Current State

After Phase 104R:

- Cut.duration means playback/export duration only.
- Visible timeline range is based on playback duration + safety/work-area frames.
- The red cut end boundary already appears in the frame grid/body area.
- Outside-playback frames remain selectable/editable when visible.
- The ruler currently does not visually show the cut end boundary.

## Required Behavior

### 1. Show cut end boundary in the ruler

Render a red vertical cut end boundary in the frame ruler/header area.

This ruler boundary must represent the exact same playback boundary as the body boundary.

For example:

- if playbackFrameCount is 24
- the boundary is between displayed frame 24 and 25
- the ruler boundary must be drawn at the same x position as the body boundary

### 2. Use the same source of truth

Do not calculate a different ruler-specific boundary meaning.

The ruler boundary and body boundary must use the same playback boundary semantics.

Preferred rule:

- boundaryX = playbackFrameCount * frameCellWidth

If there is already a helper or internal calculation for the body boundary, reuse it.

Do not create two divergent implementations.

### 3. Keep horizontal sync

The ruler boundary must remain horizontally synchronized with:

- frame ruler headers
- frame cell body area
- bottom horizontal scrollbar movement

When the user scrolls horizontally:

- the ruler boundary and body boundary must move together
- they must stay visually aligned

### 4. Keep sticky ruler behavior

Do not break the existing sticky ruler layout.

Required:

- ruler remains vertically sticky
- + Layer header remains vertically sticky
- only body rows scroll vertically
- no RenderFlex overflow
- no second horizontal ScrollController

### 5. Preserve current semantics

Do not change any Phase 104R frame-range semantics.

Specifically:

- Cut.duration still means playback/export duration only
- outside-playback visible frames remain selectable
- outside-playback visible frames remain editable
- authored data outside playback remains visible when inside visible range
- hidden data remains stored
- no selection clamp to playbackFrameCount - 1

This phase is visual-only.

### 6. Visual style

The ruler cut boundary should visually match the body cut boundary as closely as practical.

Recommended:

- same red color
- same or nearly same thickness
- clean vertical line
- clearly visible against ruler background

If needed, separate keys may be used for header and body boundary widgets.

### 7. Stable keys

Preserve existing key:

- timeline-cut-end-boundary

If the current key refers only to the body boundary, keep it stable there.

Add a new ruler-specific stable key if needed:

- timeline-cut-end-boundary-ruler

Optional:
- timeline-cut-end-boundary-body

Use clear names.
Do not remove useful existing keys.

## Likely Files

Likely:
- lib/src/ui/timeline/timeline_frame_ruler.dart
- lib/src/ui/timeline/layer_timeline_grid.dart
- test/ui/timeline/timeline_frame_ruler_test.dart
- test/ui/layer_timeline_grid_test.dart

Possibly:
- lib/src/ui/timeline/timeline_grid_metrics.dart
- lib/src/ui/timeline/timeline_frame_range_policy.dart

Only if truly needed.

## Implementation Direction

Preferred direction:

- keep the body cut boundary as-is
- add a ruler/header boundary overlay in the ruler rendering path
- ensure it uses the same playbackFrameCount and frameCellWidth semantics
- ensure it scrolls with the ruler content, not with the static left rail

Good approach examples:
- Stack around the ruler row content with a positioned boundary line
- or small overlay layer aligned to the frame scroll content

Avoid:
- hardcoding a separate ruler-only x offset
- introducing a separate scroll controller
- duplicating semantics in multiple places without shared logic

## Tests Required

### 1. Ruler boundary exists

Add or update a test to verify that the ruler cut boundary is rendered.

Expected:
- finder for timeline-cut-end-boundary-ruler returns one widget

### 2. Body boundary still exists

Preserve existing test coverage for the body cut boundary.

Expected:
- body boundary still exists
- existing body boundary behavior is unchanged

### 3. Ruler boundary alignment

Verify that the ruler boundary x position matches the body boundary x position.

It is acceptable to compare left positions or centers with a small tolerance.

### 4. Horizontal scroll sync

After horizontally scrolling the timeline:

- ruler boundary still exists
- body boundary still exists
- ruler and body boundary remain aligned

### 5. Existing semantics unchanged

Preserve tests proving:

- outside-playback frames are still selectable
- outside-playback frames are still editable
- ruler scrub still works
- sticky ruler behavior remains intact
- no overflow regressions

## Out of Scope

Do not implement:
- exposure block visuals
- exposure handles
- exposure drag editing
- cut duration editing UI
- draggable cut end boundary
- playback
- export
- zoom
- snapping
- auto-scroll
- StoryboardPanel changes
- renderer/cache/persistence changes
- state-management refactor

## Acceptance Criteria

This phase is complete when:

1. The red cut end boundary is visible in the ruler area.
2. The red cut end boundary remains visible in the body area.
3. The ruler and body boundaries use the same playback boundary meaning.
4. The ruler and body boundaries stay horizontally aligned during scrolling.
5. Sticky ruler layout remains intact.
6. No overflow regression is introduced.
7. Phase 104R semantics remain unchanged.
8. dart format lib test passes.
9. flutter analyze passes.
10. flutter test passes.
11. git status is clean or only expected files are changed.

## Report Back

Report:
- changed files
- how the ruler boundary was rendered
- whether the body boundary implementation was reused or mirrored
- confirmation that ruler/body boundary positions stay aligned
- confirmation that Phase 104R semantics were not changed
- analyze result
- full test result
- git status summary