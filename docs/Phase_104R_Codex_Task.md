# Phase 104R Codex Task - Timeline Frame Range Semantics Refactor

## Goal

Refactor the Timeline frame range semantics introduced around Phase 104.

This phase is not a new visual feature phase.

The goal is to make the long-term meaning of Cut duration, visible timeline range, authored timeline data, and editable frames explicit and safe.

The current Phase 104 implementation treated Cut.duration as the selectable/editable frame limit in several places. That is not the desired long-term design.

## Core Design Decision

Cut.duration is the official playback/export duration only.

Cut.duration must not be treated as:

- the maximum possible frame index
- the maximum editable frame index
- the maximum storable timeline data index
- a destructive trim boundary
- a reason to delete or ignore timeline data outside the duration

Cut.duration means:

- playback runs from frame index 0 to Cut.duration - 1
- export uses frame index 0 to Cut.duration - 1
- the red cut end boundary is drawn at Cut.duration
- frames after Cut.duration are outside playback range

Frames after Cut.duration may still be visible, selectable, editable, and stored when they are inside the visible timeline work area.

## Required Conceptual Model

### 1. Cut duration

Cut.duration:

- official playback frame count
- official export frame count
- red cut end boundary position
- not a data deletion boundary
- not a selection clamp boundary
- not an edit clamp boundary

Example:

- Cut.duration = 24
- playback/export frames = 0..23
- cut end boundary is between frame 24 and frame 25

### 2. Safety / work-area frames

Use a fixed safety/work-area range after Cut.duration.

For now:

- default Cut duration = 24 frames
- default safety/work-area frames = 24 frames

Visible timeline range:

- visibleFrameCount = Cut.duration + safetyFrameCount

Example:

- Cut.duration = 24
- safetyFrameCount = 24
- visibleFrameCount = 48
- visible frames = 0..47
- displayed numbers = 1..48

### 3. Authored timeline data

Timeline data may exist outside the current visible timeline range.

This data must not be deleted or rewritten just because Cut.duration changes.

Example:

- Cut.duration = 24
- safetyFrameCount = 24
- frame 46 is visible and a drawing can be created there
- later Cut.duration is reduced to 5
- visibleFrameCount becomes 29
- frame 46 is no longer visible
- the drawing data at frame 46 must remain stored
- if Cut.duration is later increased so that frame 46 becomes visible again, the drawing must reappear

This is mandatory.

Do not implement destructive trimming.

Do not delete timeline entries outside Cut.duration.

Do not delete timeline entries outside visibleFrameCount.

### 4. Display frame count

Do not use authored timeline data extent to force the timeline to show all stored data.

The visible timeline range should be based primarily on:

- Cut.duration
- safetyFrameCount
- minimum visible frame cells if needed by layout

Recommended formula:

visibleFrameCount = max(
Cut.duration + safetyFrameCount,
minimumVisibleFrameCells
)

Do not automatically expand visibleFrameCount just because authored data exists beyond it.

Reason:
If the user reduces Cut.duration, far-future authored data should become hidden but remain stored.

### 5. Selection range

Selection should be allowed within the visible timeline range.

Selection should not clamp to Cut.duration.

Correct:

- Cut.duration = 24
- safetyFrameCount = 24
- visibleFrameCount = 48
- selecting frame index 24 is allowed
- selecting frame index 45 is allowed
- selecting frame index 47 is allowed

Incorrect:

- selecting frame index 24 clamps to 23
- clicking outside playback range clamps to the last playback frame
- outside playback range is treated as disabled

If a frame is outside visibleFrameCount, it cannot be selected through the current visible UI because it is not visible.

Future duration editing may need to clamp currentFrameIndex if the selected frame becomes hidden. For now, if necessary, clamp only to visibleFrameCount - 1, not Cut.duration - 1.

### 6. Editing range

Editing should be allowed within the visible timeline range.

The following actions must be allowed outside Cut.duration when the target frame is visible:

- select frame
- create drawing frame
- create blank exposure
- toggle mark
- rename existing frame
- copy frame
- paste linked frame
- delete authored drawing cell if present
- increase/decrease exposure when the existing command rules allow it

Do not automatically extend Cut.duration when editing outside playback range.

Example:

- Cut.duration = 24
- safetyFrameCount = 24
- user creates a drawing at frame index 45
- Cut.duration remains 24
- drawing exists outside playback range
- playback still stops at frame index 23

### 7. Playback range

Playback must be limited to Cut.duration.

This phase does not need to implement playback.

But the design rule must be respected:

- playback frame range = 0..Cut.duration - 1
- export frame range = 0..Cut.duration - 1
- outside playback frames are editable work data, not playback data

## Terminology Refactor

Avoid misleading names.

### Avoid

- actualFrameCount if it means Cut.duration
- postCutTail if it implies disabled or invalid
- totalFrameCount if it ambiguously means Cut duration
- selectableFrameCount if it means Cut.duration

### Prefer

- playbackFrameCount
- visibleFrameCount
- safetyFrameCount
- workAreaTailFrameCount
- authoredTimelineExtentFrameCount
- outsidePlaybackRange
- insidePlaybackRange

## Required Code Direction

### 1. Central defaults

Create or reuse a central place for defaults.

Required constants:

- defaultCutDurationFrames = 24
- defaultTimelineSafetyFrameCount = 24

Possible file:

- lib/src/controllers/default_cut_helpers.dart

or a better long-term file:

- lib/src/core/timeline/timeline_defaults.dart
- lib/src/ui/timeline/timeline_frame_range_policy.dart

Do not duplicate raw 24 values in multiple UI/test files.

### 2. Frame range policy helper

Create a small pure helper to compute timeline ranges.

Suggested file:

- lib/src/ui/timeline/timeline_frame_range_policy.dart

Suggested model:

TimelineFrameRangePolicy or TimelineFrameRange

Inputs:

- playbackFrameCount
- safetyFrameCount
- minimumVisibleFrameCells

Outputs:

- playbackFrameCount
- safetyFrameCount
- visibleFrameCount
- playbackEndFrameIndexExclusive
- visibleEndFrameIndexExclusive

Rules:

- playbackFrameCount must be at least 1
- safetyFrameCount must be at least 0
- visibleFrameCount = max(playbackFrameCount + safetyFrameCount, minimumVisibleFrameCells)

Do not include authored timeline extent in visibleFrameCount for this phase.

### 3. TimelinePanel API

TimelinePanel should receive clearly named values.

Preferred direction:

- playbackFrameCount
- safetyFrameCount

Avoid passing a vague `frameCount` if possible.

If renaming everything is too large for one phase, add the new names internally and migrate gradually, but the code must clearly document the meaning.

### 4. LayerTimelineGrid behavior

LayerTimelineGrid should:

- render visibleFrameCount frames
- draw cut end boundary at playbackFrameCount * frameCellWidth
- style frames >= playbackFrameCount as outside playback range
- allow selecting and editing frames < visibleFrameCount
- not clamp selection to playbackFrameCount - 1
- clamp selection only to visibleFrameCount - 1 when needed

### 5. TimelineFrameRuler behavior

TimelineFrameRuler should:

- render visible frames
- show headers beyond playbackFrameCount
- style headers beyond playbackFrameCount as outside playback range
- still allow clicking those headers
- not clamp header selection to playbackFrameCount - 1

### 6. Cell exposure behavior

Do not force cells outside playback range to empty.

Incorrect:

if (frameIndex >= playbackFrameCount) {
exposureState = empty;
hasMark = false;
frameName = null;
}

Correct:

- Always ask the timeline/exposure resolver for the actual cell state if the frame is visible.
- Then apply outside-playback visual styling on top if frameIndex >= playbackFrameCount.

This allows authored data outside playback range to remain visible when the visible range includes it.

### 7. Cut end boundary

Keep the red cut end boundary.

Required key:

- timeline-cut-end-boundary

Position:

- playbackFrameCount * frameCellWidth

Meaning:

- playback/export end
- not edit limit
- not data limit

### 8. Data persistence rule

No command in this phase may delete timeline data because it is outside Cut.duration.

No command in this phase may delete timeline data because it is outside visibleFrameCount.

Duration changes in the future must hide or reveal data through visible range only.

## Required Tests

### 1. Defaults

Test:

- default Cut duration is 24
- newly created Cuts use duration 24
- safety/work-area frame count is 24

### 2. Visible range

With:

- Cut.duration = 24
- safetyFrameCount = 24

Verify:

- visibleFrameCount is 48
- frame headers up to frame index 47 can be rendered
- cut end boundary is between frame index 23 and 24

### 3. Outside playback selection

With:

- Cut.duration = 24
- safetyFrameCount = 24

Verify:

- clicking frame index 24 selects 24
- clicking frame index 45 selects 45
- clicking frame index 47 selects 47
- selection does not clamp to 23

### 4. Outside playback editing

With:

- Cut.duration = 24
- safetyFrameCount = 24

Verify:

- select frame index 45
- create a drawing frame
- the drawing appears at frame index 45
- Cut.duration remains 24
- cut end boundary remains at frame index 24

### 5. Outside playback authored data remains visible while inside visible range

With:

- Cut.duration = 24
- safetyFrameCount = 24
- authored drawing at frame index 45

Verify:

- frame index 45 shows the drawing/exposure state
- frame index 45 also has outside-playback visual treatment
- exposure state is not forced to empty

### 6. Authored data outside visible range remains stored but hidden

Create a project/cut with:

- Cut.duration = 5
- safetyFrameCount = 24
- authored drawing at frame index 45

Visible range should be:

- frame index 0..28

Verify:

- frame index 45 is not visible/rendered
- repository/model still contains the authored data at frame index 45

Then use a version of the same cut/project with:

- Cut.duration = 24
- safetyFrameCount = 24

Verify:

- frame index 45 becomes visible again
- the drawing/exposure state at frame index 45 is restored/visible

Do not implement a duration editing UI just for this test.
Use model/project setup or helper methods.

### 7. Outside visible range is not automatically displayed

With:

- Cut.duration = 5
- safetyFrameCount = 24
- authored data at frame index 45

Verify:

- visible timeline does not automatically expand to frame index 45
- authored data extent alone does not control visibleFrameCount

### 8. Existing cut switching tests

Existing tests must continue to pass:

- new frame after switching to Cut 2 stays scoped to Cut 2
- blank and mark edits after switching to Cut 2 do not affect Cut 1
- undo and redo smoke after cut switching keeps Cut 2 active

### 9. Existing Phase 103/104 tests

Preserve tests for:

- ruler click/drag scrub
- horizontal scroll sync
- sticky ruler
- no RenderFlex overflow
- cut end boundary exists
- sample/default Cut duration
- new Cut default duration

Update tests that currently expect post-cut/outside-playback frames to clamp to the last playback frame. That expectation is now wrong.

## Out of Scope

Do not implement:

- exposure block visuals
- exposure handles
- exposure drag editing
- cut duration editing UI
- playback system
- export system
- zoom
- snapping
- auto-scroll
- StoryboardPanel redesign
- renderer/cache/persistence changes
- deleting hidden data
- trimming data outside duration
- trimming data outside visible range

## Acceptance Criteria

This phase is complete when:

1. Cut.duration is treated as playback/export length only.
2. Visible timeline range is Cut.duration + safetyFrameCount.
3. safetyFrameCount default is 24.
4. default Cut duration is 24.
5. newly created Cuts default to 24.
6. Frames outside Cut.duration but inside visible range are selectable.
7. Frames outside Cut.duration but inside visible range are editable.
8. Editing outside Cut.duration does not extend Cut.duration.
9. Authored data outside Cut.duration is visible if it falls inside visible range.
10. Authored data outside visible range remains stored but hidden.
11. Increasing visible range later reveals previously hidden authored data.
12. The red cut end boundary remains at Cut.duration.
13. Existing timeline/cut switching behavior remains intact.
14. `dart format lib test` passes.
15. `flutter analyze` passes.
16. `flutter test` passes.
17. `git status` is clean or only expected files are changed.

## Report Back

Report:

- changed files
- final terminology used for playbackFrameCount / visibleFrameCount / safetyFrameCount
- where the default 24-frame Cut duration is defined
- where the default 24 safety frames are defined
- how visibleFrameCount is computed
- how outside-playback frames are styled
- confirmation that outside-playback visible frames are selectable
- confirmation that outside-playback visible frames are editable
- confirmation that outside-playback authored data is not forced empty
- confirmation that hidden authored data remains stored
- confirmation that cut end boundary remains at playback duration
- analyze result
- full test result
- git status summary