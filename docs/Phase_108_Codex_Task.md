# Phase 108 Codex Task - Exposure Range Resolver Foundation

## Goal

Add a pure exposure range resolver for Timeline exposure blocks.

This phase is a foundation phase for future exposure block selection, handles, and duration editing.

Do not implement editing yet.

Do not implement drag handles yet.

Do not change the data model.

Do not change Timeline behavior.

## Background

After Phase 107:

- Timeline cells can visually render connected exposure blocks.
- drawingStart + heldExposure cells visually read as one drawing block.
- blankStart + blankHeld cells visually read as one blank block.
- Empty cells do not become blocks.
- Outside-playback authored data can still visually render when inside visibleFrameCount.
- Exposure block visuals are purely visual and do not create a new model.

The next long-term-safe step is to add a pure resolver that can answer:

- What exposure block range contains this frame?
- Is it a drawing block, blank block, or no block?
- What is the block start frame index?
- What is the block end frame index exclusive?
- Is this cell the start, middle, or end of the block?

This will be used later by UI selection, handle rendering, and exposure duration editing.

## Core Rule

This phase must not change user behavior.

It only adds pure logic and tests.

Do not add:
- block selection UI
- block drag editing
- resize handles
- context menus
- cut duration editing
- playback/export changes
- model/controller rewrites

## Required Helper

Create a small pure helper.

Suggested file:

- lib/src/ui/timeline/timeline_exposure_range_resolver.dart

Suggested types:

- TimelineExposureRangeKind.none
- TimelineExposureRangeKind.drawing
- TimelineExposureRangeKind.blank

Suggested value object:

- TimelineExposureRange

Suggested fields:

- kind
- startFrameIndex
- endFrameIndexExclusive
- selectedFrameIndex
- length
- containsSelectedFrame
- isSingleFrame
- isStartFrame
- isEndFrame
- isMiddleFrame

Names may differ if clearer.

## Resolver Behavior

The resolver should accept:

- selected frame index
- lower frame bound
- upper frame bound exclusive
- function/callback to read TimelineCellExposureState for a frame

Example conceptual API:

resolveTimelineExposureRange({
required int selectedFrameIndex,
required int minFrameIndex,
required int maxFrameIndexExclusive,
required TimelineCellExposureState Function(int frameIndex) exposureStateAt,
})

The exact API can differ, but it must be pure and easy to test.

## Range Semantics

### Drawing block

A drawing block is:

- drawingStart
- followed by zero or more heldExposure cells

If selected frame is drawingStart:

- range starts at that drawingStart
- range continues through following heldExposure cells

If selected frame is heldExposure:

- search backward to the nearest drawingStart or beginning of contiguous drawing segment
- search forward through heldExposure cells
- classify as drawing block

Important:
- heldExposure connects only to drawingStart / heldExposure
- heldExposure must not connect to blankStart / blankHeld / empty

### Blank block

A blank block is:

- blankStart
- followed by zero or more blankHeld cells

If selected frame is blankStart:

- range starts at that blankStart
- range continues through following blankHeld cells

If selected frame is blankHeld:

- search backward to the nearest blankStart or beginning of contiguous blank segment
- search forward through blankHeld cells
- classify as blank block

Important:
- blankHeld connects only to blankStart / blankHeld
- blankHeld must not connect to drawingStart / heldExposure / empty

### Empty cells

If selected frame is empty:

- return kind none
- range should represent no block

Do not invent an exposure range for empty cells.

## Boundary Rules

The resolver must not read outside the provided bounds.

If selectedFrameIndex is outside bounds, return a safe none result or throw a clear assertion depending on project style.

Prefer safe behavior for UI use:

- kind none
- start/end equal selectedFrameIndex or clamped safe values

But do not silently crash in normal UI paths.

The resolver must work for:

- frame 0
- single-frame drawing block
- single-frame blank block
- block at the beginning of range
- block at the end of visible range
- block continuing outside visible range but only partially visible

Do not expand visibleFrameCount.

Do not query beyond maxFrameIndexExclusive.

## Phase 104R / 105 / 106 / 107 Preservation

Must preserve:

- Cut.duration means playback/export duration only.
- Cut.duration is not a selection limit.
- Cut.duration is not an edit limit.
- Cut.duration is not a data deletion boundary.
- playbackFrameCount remains separate from visibleFrameCount.
- visibleFrameCount remains computed by TimelineFrameRange.
- outside-playback visible frames remain selectable/editable.
- authored data outside playback remains visible when inside visible range.
- authored data outside visible range remains stored but hidden.
- body cut end boundary remains.
- ruler cut end boundary remains.
- exposure block visual rendering remains.
- selected cell border remains visible.
- mark priority remains unchanged.
- frame name priority remains unchanged.
- stable widget keys remain unchanged.

## Suggested Tests

Add unit tests for the resolver.

Suggested test file:

- test/ui/timeline/timeline_exposure_range_resolver_test.dart

Cover:

1. empty selected frame returns none
2. drawingStart alone resolves single-frame drawing range
3. drawingStart + heldExposure + heldExposure resolves full drawing range
4. selected heldExposure resolves back to drawingStart
5. drawing range stops before empty
6. drawing range stops before blankStart
7. blankStart alone resolves single-frame blank range
8. blankStart + blankHeld + blankHeld resolves full blank range
9. selected blankHeld resolves back to blankStart
10. blank range stops before empty
11. blank range stops before drawingStart
12. block at frame 0 resolves safely
13. block ending at maxFrameIndexExclusive resolves safely
14. resolver does not query below minFrameIndex
15. resolver does not query at or beyond maxFrameIndexExclusive
16. selected frame outside bounds returns safe none or clear expected behavior

Add only minimal widget tests if truly useful.

Do not write brittle pixel-perfect tests.

## Out of Scope

Do not implement:

- exposure block selection UI
- exposure block handles
- exposure block drag editing
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

1. A pure exposure range resolver exists.
2. It can resolve drawing exposure ranges.
3. It can resolve blank exposure ranges.
4. It returns none for empty cells.
5. It handles selected held cells correctly.
6. It respects min/max frame bounds.
7. It does not query outside the provided bounds.
8. It does not change Timeline UI behavior.
9. It does not change the data model.
10. Phase 104R / 105 / 106 / 107 tests still pass.
11. dart format lib test passes.
12. flutter analyze passes.
13. flutter test passes.
14. git status is clean or only expected files are changed.

## Report Back

Report:

- changed files
- helper/type names added
- resolver API
- how drawing ranges are resolved
- how blank ranges are resolved
- how empty cells are handled
- how bounds are protected
- confirmation that no UI behavior changed
- confirmation that no data model/editing behavior changed
- confirmation that Phase 104R/105/106/107 behavior remains intact
- analyze result
- full test result
- git status summary