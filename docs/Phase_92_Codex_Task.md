# Phase 92 Codex Task - Timeline Virtualization Render Plan Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

QuickAnimaker v2 is prioritizing long-term performance and scalability.

Important documents:

* docs/Handoff_QuickAnimaker_v2_Current.md
* docs/LongTerm_Performance_Architecture.md
* docs/Phase_91_Codex_Task.md

Phase 91 added:

* lib/src/ui/timeline/timeline_visible_range.dart
* test/ui/timeline/timeline_visible_range_test.dart

Phase 91 introduced:

* TimelineVisibleRange
* TimelineVisibleRanges
* calculateVisibleIndexRange
* calculateTimelineVisibleRanges

These functions calculate visible frame and layer index ranges without building widgets.

## Phase goal

Add a pure render-plan foundation for future TimelinePanel virtualization.

This phase should not rewrite TimelinePanel yet.

The goal is to calculate the spacer sizes and visible ranges needed to later render only visible timeline cells while preserving full scrollable timeline dimensions.

This phase is still calculation-only.

## Why this phase exists

The current TimelinePanel still eagerly builds many frame cells using Row and Column.

Phase 91 calculates which frames and layers should be visible.

Phase 92 should calculate how a future virtualized TimelinePanel can preserve correct scroll geometry while only building visible cells.

A future virtualized UI will likely need:

* leading frame spacer width
* trailing frame spacer width
* leading layer spacer height
* trailing layer spacer height
* total virtual content width
* total virtual content height
* visible frame range
* visible layer range

This phase creates that foundation without changing current UI rendering.

## Required implementation

### 1. Add a pure render plan helper

Create:

* lib/src/ui/timeline/timeline_virtualization_plan.dart

This file should be pure Dart logic.

It may import:

* dart:math if needed
* timeline_visible_range.dart

It must not import:

* material.dart
* widgets.dart
* flutter UI libraries
* Project / Track / Cut / Layer / Frame models

### 2. Add TimelineVirtualizationPlan

Add an immutable class:

* TimelineVirtualizationPlan

Recommended fields:

* TimelineVisibleRange frameRange
* TimelineVisibleRange layerRange
* double leadingFrameSpacerWidth
* double trailingFrameSpacerWidth
* double leadingLayerSpacerHeight
* double trailingLayerSpacerHeight
* double totalFrameContentWidth
* double totalLayerContentHeight
* double visibleFrameContentWidth
* double visibleLayerContentHeight

Useful getters may be added if helpful.

Do not over-engineer.

### 3. Add calculateTimelineVirtualizationPlan

Add a function similar to:

* calculateTimelineVirtualizationPlan

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

The function should internally use calculateTimelineVisibleRanges.

Expected calculations:

* totalFrameContentWidth = frameCount * frameCellWidth
* totalLayerContentHeight = layerCount * layerRowHeight
* leadingFrameSpacerWidth = frameRange.startIndex * frameCellWidth
* trailingFrameSpacerWidth = (frameCount - frameRange.endIndexExclusive) * frameCellWidth
* leadingLayerSpacerHeight = layerRange.startIndex * layerRowHeight
* trailingLayerSpacerHeight = (layerCount - layerRange.endIndexExclusive) * layerRowHeight
* visibleFrameContentWidth = frameRange.count * frameCellWidth
* visibleLayerContentHeight = layerRange.count * layerRowHeight

All spacer values must be clamped so they never become negative.

### 4. Handle invalid inputs consistently

Follow the Phase 91 behavior:

* frameCellWidth <= 0 should throw ArgumentError
* layerRowHeight <= 0 should throw ArgumentError
* frameCount <= 0 should produce empty frame range and zero frame widths
* layerCount <= 0 should produce empty layer range and zero layer heights
* negative scroll offsets should be handled safely by the underlying visible range calculator
* negative viewport sizes should be handled safely by the underlying visible range calculator

### 5. Tests

Create:

* test/ui/timeline/timeline_virtualization_plan_test.dart

Required test cases:

* empty frameCount produces zero frame dimensions
* empty layerCount produces zero layer dimensions
* initial viewport calculates leading and trailing frame spacers
* horizontal scroll offset changes leading frame spacer
* vertical scroll offset changes leading layer spacer
* overscan affects visible frame content width
* plan clamps trailing spacer at the end
* invalid frameCellWidth throws ArgumentError
* invalid layerRowHeight throws ArgumentError
* 100000 frameCount produces correct total width and visible-only range without creating widgets

Do not build widgets in these tests.

Do not create a list of 100000 frame objects.

This phase must remain calculation-only.

### 6. Optional export policy

If there is a suitable timeline export/barrel file, export the new file there.

If there is no existing suitable barrel file, do not create a new broad export refactor.

Keep the change minimal.

### 7. Documentation update

Update docs/LongTerm_Performance_Architecture.md with a small Phase 92 note.

Suggested note:

Phase 92 introduced TimelineVirtualizationPlan as a calculation-only render plan foundation. It converts visible frame/layer ranges into leading/trailing spacer dimensions and total virtual content dimensions so future TimelinePanel virtualization can preserve scroll geometry while rendering only visible cells.

Do not rewrite the whole document.

### 8. Out of scope

Do not modify:

* TimelinePanel rendering
* LayerTimelineGrid rendering
* StoryboardPanel rendering
* HomePage layout
* Project / Track / Cut / Layer / Frame models
* persistence
* save/load
* renderer/cache
* commands
* undo/redo
* Provider / Riverpod / Bloc / ChangeNotifier

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

This phase is pure calculation foundation only.

## Long-term design rules

The virtualization plan must stay independent from widgets and domain models.

It should only calculate:

* visible ranges
* total virtual dimensions
* leading spacer sizes
* trailing spacer sizes
* visible content dimensions

This keeps the future TimelinePanel virtualization path safe and testable.

The future virtualized TimelinePanel should be able to use this plan to build:

* leading horizontal spacer
* visible frame cells
* trailing horizontal spacer
* leading vertical spacer
* visible layer rows
* trailing vertical spacer

## Acceptance criteria

This phase is complete when:

* lib/src/ui/timeline/timeline_virtualization_plan.dart exists.
* TimelineVirtualizationPlan exists.
* calculateTimelineVirtualizationPlan exists.
* Tests cover spacer calculations, clamping, invalid dimensions, empty counts, and 100000 frameCount.
* No UI rendering behavior changes.
* No model changes.
* No editing behavior changes.
* No eager 100000 widget build is introduced.
* docs/LongTerm_Performance_Architecture.md has a small Phase 92 note.
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
* confirmation that Project / Cut / Layer / Frame models were not changed
* confirmation that no editing behavior was added
* confirmation that large frame count is tested by calculation only, not widget construction
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
