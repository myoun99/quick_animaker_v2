# Phase 99 Codex Task - Timeline Frame Ruler Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

QuickAnimaker v2 is building a long-term TVPaint-style bitmap animation timeline.

Current confirmed state:

* Phase 98 completed.
* PR 139 merged.
* PR 140 merged.
* User confirmed the app works normally after PR 140.
* Horizontal bottom scrollbar works normally.
* Vertical scrollbar slot works normally.
* Vertical layer virtualization is still intentionally deferred.

Recent timeline phases:

* Phase 91 added visible range calculation.
* Phase 92 added a virtualization render plan.
* Phase 93 added TimelineGridMetrics and TimelinePanel virtualization adapter.
* Phase 94 separated fixed layer controls rail from the horizontal frame scroll viewport.
* Phase 95 applied the first horizontal frame virtualization slice.
* Phase 96 added a visible horizontal scrollbar foundation.
* Phase 97 moved the horizontal scrollbar into a stable bottom rail.
* Phase 98 added the visible vertical scrollbar slot between the layer controls rail and the frame grid area.
* PR 140 fixed a runtime crash caused by reading ScrollPosition.maxScrollExtent before ScrollPosition.hasContentDimensions became true.

Important current TimelinePanel / LayerTimelineGrid structure:

* One shared vertical scroll viewport controls both:

    * layer controls rail
    * frame rows
* The vertical scrollbar slot is between:

    * fixed layer controls rail
    * frame grid area
* The horizontal frame scroll is inside the frame grid area.
* The bottom horizontal scrollbar is under the frame grid area only.
* The bottom row reserves:

    * layer controls width
    * vertical scrollbar slot width
    * horizontal scrollbar rail under the frame grid area

## Goal

Add a small, safe foundation for a long-term timeline frame ruler.

This phase should extract the current frame header row behavior into a dedicated reusable ruler component while preserving the existing UI behavior.

The purpose is to prepare for future phases such as:

* playhead visual overlay
* frame ruler tick styling
* timeline zoom
* shared timeline ruler logic between TimelinePanel and StoryboardPanel
* future 2D virtualization

This phase must not implement those future features yet.

## Why this phase

The current frame header row already acts like a simple frame ruler, but it is embedded directly inside LayerTimelineGrid.

Before adding a playhead or zoom, the timeline should have a stable ruler boundary with semantic keys and tests.

This keeps the code long-term safe because future playhead/ruler work can attach to a dedicated ruler component instead of adding more logic directly into LayerTimelineGrid.

## Required implementation direction

Create a dedicated frame ruler widget.

Recommended new file:

* lib/src/ui/timeline/timeline_frame_ruler.dart

Recommended widget name:

* TimelineFrameRuler

The widget should be UI-only.

It should accept only the data needed to render the visible ruler range:

* frameStartIndex
* frameEndIndexExclusive
* currentFrameIndex
* leadingFrameSpacerWidth
* trailingFrameSpacerWidth
* metrics
* onSelectFrame

It should not depend on:

* Project
* Track
* Cut
* Layer
* Frame
* Stroke
* Provider
* Riverpod
* Bloc
* ChangeNotifier
* renderer/cache
* persistence
* commands
* undo/redo

The ruler must use the current horizontal virtualization result.

Do not calculate a separate visible range inside TimelineFrameRuler.

LayerTimelineGrid should continue to calculate the virtualization plan once and pass the plan's frame range/spacer values into TimelineFrameRuler.

## Required behavior

The visible behavior should remain the same as before this phase.

Frame headers should still:

* display frame numbers as 1-based text
* use stable key:

    * timeline-frame-header-<frameIndex>
* call onSelectFrame(frameIndex) when tapped
* show current frame selection using the existing visual style
* respect horizontal virtualization
* render only visible/overscanned frame headers
* keep leading/trailing spacer geometry

Add a stable wrapper key:

* timeline-frame-ruler

Keep existing keys stable:

* timeline-frame-header-row
* timeline-frame-header-<frameIndex>
* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-horizontal-scrollbar
* timeline-horizontal-scrollbar-track
* timeline-horizontal-scrollbar-thumb
* timeline-horizontal-scrollbar-viewport
* timeline-bottom-scrollbar-rail
* timeline-bottom-scrollbar-left-spacer
* timeline-vertical-scrollbar-slot
* timeline-vertical-scrollbar
* timeline-vertical-scrollbar-track
* timeline-vertical-scrollbar-thumb
* timeline-vertical-scrollbar-bottom-spacer
* timeline-vertical-scroll-viewport
* timeline-layer-controls-rail
* timeline-frame-grid-area
* timeline-cell-<layerId>-<frameIndex>
* timeline-frame-row-leading-spacer-<layerId>
* timeline-frame-row-trailing-spacer-<layerId>
* timeline-layer-row-<layerId>
* timeline-layer-kind-icon-<layerId>
* timeline-layer-name-<layerId>
* timeline-add-layer-button

Do not remove or rename existing keys.

## Suggested structure

In LayerTimelineGrid, replace the inline frame header Row with TimelineFrameRuler.

Current conceptual structure:

timeline-frame-scroll-content
Column
timeline-frame-header-row
leading spacer
frame headers
trailing spacer
frame rows

New conceptual structure:

timeline-frame-scroll-content
Column
timeline-frame-ruler
timeline-frame-header-row
leading spacer
frame headers
trailing spacer
frame rows

The new TimelineFrameRuler may internally render the existing Row.

Keep the existing frame header row key on the Row or equivalent structural wrapper.

## Frame header extraction

The current private _FrameHeader widget can be moved to the new file if that is the cleanest option.

Acceptable options:

Option A:

* Move _FrameHeader into timeline_frame_ruler.dart as a private helper used by TimelineFrameRuler.

Option B:

* Rename it to TimelineFrameHeader if public access is needed.

Prefer Option A unless tests or imports require public access.

Do not make this phase larger than necessary.

## Tests

Update or add tests in:

* test/ui/layer_timeline_grid_test.dart

Add test coverage for:

1. timeline-frame-ruler exists.
2. timeline-frame-header-row still exists.
3. timeline-frame-header-leading-spacer still exists.
4. timeline-frame-header-trailing-spacer still exists.
5. timeline-frame-header-0 still exists in a normal small timeline.
6. Tapping a frame header still calls onSelectFrame with the correct zero-based frame index.
7. Large frame counts still render only visible/overscanned headers.
8. timeline-frame-header-99999 is not built initially for frameCount 100000.
9. Horizontal scroll still changes the virtualized frame header range.
10. Existing horizontal scrollbar tests still pass.
11. Existing vertical scrollbar tests still pass.
12. Existing frame cell selection tests still pass.

Avoid fragile tests:

* Do not compare text baselines.
* Do not depend on exact inner Text positions.
* Do not depend on Flutter internal Scrollbar implementation.
* Use stable keys and high-level structure.

## Optional pure widget test

If useful, add a small direct widget test for TimelineFrameRuler.

Possible new test file:

* test/ui/timeline/timeline_frame_ruler_test.dart

Only add this if it stays simple.

Suggested direct tests:

* renders wrapper key timeline-frame-ruler
* renders header row key timeline-frame-header-row
* renders visible frame header keys from frameStartIndex to frameEndIndexExclusive - 1
* does not render headers outside the supplied range
* calls onSelectFrame with the tapped frame index

Do not over-test visual styling.

## Documentation

Update:

* docs/LongTerm_Performance_Architecture.md

Add a short Phase 99 note near the existing Phase 98 update.

Suggested note:

Phase 99 extracts the TimelinePanel frame header row into a dedicated TimelineFrameRuler foundation. The ruler uses the existing horizontal visible frame range and spacer geometry rather than calculating a separate range. This prepares future playhead, ruler tick, and zoom work without changing domain models, renderer/cache, persistence, or vertical layer virtualization.

Do not rewrite the whole document.

## Out of scope

Do not implement:

* vertical layer virtualization
* playhead line
* playhead dragging
* timeline zoom
* ruler major/minor tick styling
* StoryboardPanel ruler reuse
* StoryboardPanel changes
* layer reorder
* layer folder
* layer lock
* layer merge
* sound section
* camera section
* vertical timesheet view
* renderer/cache changes
* persistence changes
* model changes
* command changes
* undo/redo changes
* Provider/Riverpod/Bloc/ChangeNotifier introduction

## Files likely to change

Expected:

* lib/src/ui/timeline/layer_timeline_grid.dart
* lib/src/ui/timeline/timeline_frame_ruler.dart
* test/ui/layer_timeline_grid_test.dart
* docs/LongTerm_Performance_Architecture.md

Optional:

* test/ui/timeline/timeline_frame_ruler_test.dart

Do not touch unrelated files.

## Acceptance criteria

The phase is complete when:

* TimelineFrameRuler exists as a dedicated widget.
* LayerTimelineGrid uses TimelineFrameRuler for the frame header/ruler row.
* Existing visible behavior is preserved.
* Existing frame header keys are preserved.
* New key timeline-frame-ruler exists.
* Horizontal frame virtualization still works.
* Large frame count tests still confirm offscreen headers/cells are not built.
* Horizontal bottom scrollbar still works.
* Vertical scrollbar slot still works.
* Layer controls and frame rows still share one vertical scroll viewport.
* No domain models are changed.
* No renderer/cache/persistence logic is changed.
* No vertical layer virtualization is implemented.

## Commands to run locally

Run:

dart format lib test
flutter analyze
flutter test

If formatting changes files, include those formatted files in the commit.

## PR description requirements

When opening the PR, include:

* Summary of the TimelineFrameRuler extraction.
* Confirmation that existing frame header keys were preserved.
* Confirmation that horizontal virtualization still uses the existing plan/range.
* Confirmation that vertical layer virtualization was not implemented.
* Test results.
