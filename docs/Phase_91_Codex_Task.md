# Phase 91 Codex Task - Timeline Visible Range Calculator Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

QuickAnimaker v2 is moving toward a TVPaint-style bitmap animation tool with a scalable timeline.

Important current status:

* TimelinePanel / LayerTimelineGrid currently uses eager Row / Column rendering.
* It builds frame headers with a loop over visibleFrameCount.
* It builds frame cells for each layer with a loop over visibleFrameCount.
* This is acceptable for early MVP.
* This is not acceptable for the long-term target of large projects such as 10k to 100k frames.

Recently added long-term document:

* docs/LongTerm_Performance_Architecture.md

This document defines the long-term performance direction:

* prefer long-term structure over quick fixes
* avoid eager construction of all timeline frame cells
* move toward 2D viewport/range calculation
* keep selection and editing independent from widget existence
* keep Project/Cut/Layer/Frame models free from UI viewport state

## Phase goal

Add a pure visible range calculator foundation for future TimelinePanel virtualization.

This phase should not rewrite TimelinePanel yet.

The goal is to create a tested, reusable calculation layer that future phases can use to render only visible frame cells and visible layer rows.

This phase is a foundation phase.

## Required implementation

### 1. Add a new pure helper file

Create:

* lib/src/ui/timeline/timeline_visible_range.dart

This file should not depend on Flutter widgets.

It may use only Dart core libraries.

Do not import material.dart or widgets.dart.

### 2. Add TimelineVisibleRange model

Add a small immutable class:

* TimelineVisibleRange

Recommended fields:

* int startIndex
* int endIndexExclusive

Rules:

* startIndex is inclusive.
* endIndexExclusive is exclusive.
* Empty range is allowed.
* Range must be clamped to 0..itemCount by the calculator.
* The class should be simple and testable.

Useful getters may be added if helpful:

* int get count
* bool get isEmpty
* bool contains(int index)

Do not over-engineer.

### 3. Add single-axis visible range calculation

Add a function similar to:

* calculateVisibleIndexRange

Input should include:

* double scrollOffset
* double viewportExtent
* double itemExtent
* int itemCount
* int overscanBefore
* int overscanAfter

Expected behavior:

* Negative scrollOffset should be treated as 0.
* itemExtent must be greater than 0.
* viewportExtent less than 0 should be treated safely or rejected clearly.
* itemCount less than or equal to 0 returns an empty range.
* startIndex is floor(scrollOffset / itemExtent) minus overscanBefore.
* endIndexExclusive is ceil((scrollOffset + viewportExtent) / itemExtent) plus overscanAfter.
* Clamp result to 0..itemCount.
* The function should never return an out-of-bounds index.

Recommended defaults:

* overscanBefore = 2
* overscanAfter = 2

### 4. Add two-axis timeline visible range calculation

Add a small immutable class:

* TimelineVisibleRanges

Recommended fields:

* TimelineVisibleRange frames
* TimelineVisibleRange layers

Add a function similar to:

* calculateTimelineVisibleRanges

Input should include:

* double horizontalScrollOffset
* double verticalScrollOffset
* double viewportWidth
* double viewportHeight
* double frameCellWidth
* double layerRowHeight
* int frameCount
* int layerCount
* int frameOverscanBefore
* int frameOverscanAfter
* int layerOverscanBefore
* int layerOverscanAfter

This function should internally use calculateVisibleIndexRange.

The result should describe:

* visible frame index range
* visible layer index range

This will be used later by TimelinePanel virtualization.

### 5. Export policy

If there is an existing timeline barrel/export file, export the new helper there.

If there is no suitable barrel file, do not create a large export refactor in this phase.

Keep the change minimal.

### 6. Tests

Create:

* test/ui/timeline/timeline_visible_range_test.dart

Required test cases:

* empty itemCount returns empty range
* initial viewport returns expected visible range with overscan
* horizontal scroll offset shifts visible frame range
* overscan clamps to zero at start
* overscan clamps to itemCount at end
* negative scrollOffset is handled safely
* itemExtent <= 0 is rejected or handled clearly
* two-axis calculation returns both frame and layer ranges
* very large frameCount such as 100000 works without generating a list of all frames

Important:
Do not test by building 100000 widgets.

This phase should test calculation only.

### 7. Documentation update

Update docs/LongTerm_Performance_Architecture.md only if a small note is useful.

Suggested note:

* Phase 91 introduced TimelineVisibleRange calculation as the first concrete foundation for future TimelinePanel 2D virtualization.

Do not rewrite the entire document.

### 8. Out of scope

Do not modify:

* TimelinePanel rendering
* LayerTimelineGrid rendering
* StoryboardPanel rendering
* HomePage layout
* Project/Track/Cut/Layer/Frame models
* persistence
* renderer/cache
* save/load
* commands
* undo/redo
* Provider/Riverpod/Bloc/ChangeNotifier

Do not add:

* actual virtualized TimelinePanel UI
* playhead
* ruler
* zoom
* drag
* trim
* scroll sync
* frame editing behavior
* cut editing behavior

This phase is calculation foundation only.

## Long-term design rules

The visible range calculator must be independent from widgets.

It should not know about:

* Project
* Track
* Cut
* Layer
* Frame
* Stroke
* TimelinePanel widget tree
* StoryboardPanel widget tree

It should only calculate index ranges from scroll offsets, viewport sizes, item sizes, item counts, and overscan.

This makes it reusable later for:

* frame headers
* timeline cells
* layer rows
* storyboard cut lanes
* future ruler/playhead calculations

## Acceptance criteria

This phase is complete when:

* lib/src/ui/timeline/timeline_visible_range.dart exists.
* TimelineVisibleRange exists.
* TimelineVisibleRanges exists.
* calculateVisibleIndexRange exists.
* calculateTimelineVisibleRanges exists.
* Tests cover empty ranges, overscan, clamping, scroll offset, and large counts.
* No UI rendering behavior changes.
* No model changes.
* No editing behavior changes.
* No eager 100k widget build is introduced.
* dart format lib test passes.
* flutter analyze passes.
* flutter test passes.
* git status is clean.

## Required checks

Run:

dart format lib test
flutter analyze
flutter test
git status

## Codex report requirements

In the final report, include:

* changed files
* new calculator classes/functions
* test cases added
* confirmation that TimelinePanel rendering was not changed
* confirmation that StoryboardPanel rendering was not changed
* confirmation that Project/Cut/Layer/Frame models were not changed
* confirmation that no editing behavior was added
* confirmation that large frame count is tested by calculation only, not widget construction
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
