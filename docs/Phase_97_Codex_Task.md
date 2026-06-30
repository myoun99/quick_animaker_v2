# Phase 97 Codex Task - Timeline Bottom Horizontal Scrollbar Rail Placement

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

QuickAnimaker v2 is preparing TimelinePanel for long-term 2D virtualization and TVPaint-style timeline usability.

Important documents:

* docs/Handoff_QuickAnimaker_v2_Current.md
* docs/LongTerm_Performance_Architecture.md
* docs/Phase_91_Codex_Task.md
* docs/Phase_92_Codex_Task.md
* docs/Phase_93_Codex_Task.md
* docs/Phase_94_Codex_Task.md
* docs/Phase_95_Codex_Task.md
* docs/Phase_96_Codex_Task.md

Recent phases:

* Phase 91 added visible range calculation.
* Phase 92 added virtualization render plan calculation.
* Phase 93 added TimelineGridMetrics and a TimelinePanel virtualization adapter.
* Phase 94 separated LayerTimelineGrid into a fixed layer controls rail and a horizontal frame scroll area.
* Phase 95 applied the first horizontal frame virtualization slice to LayerTimelineGrid.
* Phase 96 added a visible horizontal scrollbar foundation.

Current issue:

* The horizontal scrollbar exists.
* But it is visually attached to the frame row area.
* Its vertical position can feel dependent on the number of layer rows.
* The desired long-term behavior is a stable bottom scrollbar rail, similar to TVPaint-style timeline ergonomics.
* The horizontal scrollbar should feel like a fixed part of the TimelinePanel bottom area, not like it belongs to one layer row.

## Phase goal

Move the horizontal scrollbar into a stable bottom rail.

The desired visual structure is:

TimelinePanel

* toolbar / current frame info
* cell actions / layer actions
* frame grid area
* bottom horizontal scrollbar rail

Within LayerTimelineGrid, the desired structure is:

* fixed layer controls rail on the left
* frame grid viewport on the right
* horizontal scrollbar rail at the bottom of the frame grid area

The scrollbar should stay at the bottom of the timeline panel/grid area regardless of whether there is one layer or many layers.

## Required implementation

### 1. Update horizontal scrollbar placement

Update:

* lib/src/ui/timeline/layer_timeline_grid.dart

Move or restructure the horizontal scrollbar so it is placed in a stable bottom rail instead of being visually tied to the last visible layer row.

The frame grid area should remain above the scrollbar.

Recommended structural direction:

* main timeline grid area

    * left fixed layer controls rail
    * right frame viewport
* bottom horizontal scrollbar rail

    * aligned under the frame viewport area
    * not under the fixed layer controls rail, unless a left spacer is intentionally used to align with the frame area

The scrollbar must remain connected to the existing horizontal ScrollController.

Do not introduce a second competing horizontal ScrollController.

### 2. Keep scrollbar always visible

The horizontal scrollbar should remain discoverable.

Keep behavior equivalent to Phase 96:

* thumbVisibility: true
* trackVisibility: true if supported cleanly
* tied to the frame scroll viewport
* not tied to the fixed layer controls rail

### 3. Add or update stable keys

Keep existing keys stable:

* timeline-scrollbar-area
* timeline-horizontal-scrollbar
* timeline-horizontal-scrollbar-viewport
* timeline-layer-controls-rail
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-frame-header-<frameIndex>
* timeline-cell-<layerId>-<frameIndex>
* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-row-leading-spacer-<layerId>
* timeline-frame-row-trailing-spacer-<layerId>
* timeline-layer-row-<layerId>
* timeline-layer-kind-icon-<layerId>
* timeline-layer-name-<layerId>
* timeline-add-layer-button

Add stable keys if helpful:

* timeline-bottom-scrollbar-rail
* timeline-bottom-scrollbar-left-spacer
* timeline-frame-grid-area

Do not remove existing keys.

### 4. Preserve horizontal virtualization

Do not remove or bypass Phase 95 virtualization.

The frame header row and frame cell rows should still build only the visible/overscanned horizontal frame range.

Large frameCount should still not build all frame headers/cells.

### 5. Preserve fixed layer controls rail

The left layer controls rail must remain outside the horizontal frame scroll viewport.

Horizontal scrolling should still move only:

* frame headers
* frame cells
* frame spacers

Horizontal scrolling should not move:

* layer controls rail
* add layer button
* layer names
* layer visibility buttons
* layer opacity controls

### 6. Preserve current editing behavior

Do not change:

* selected layer behavior
* selected frame behavior
* add layer callback
* layer visibility callback
* layer opacity callback
* layer kind icon behavior
* exposure cell rendering
* frame header labels
* empty layer behavior
* horizontal virtualization range calculation
* frame/cell key format

### 7. Vertical scrollbar is still out of scope

Do not implement the TVPaint-style vertical scrollbar between layer controls rail and frame area yet.

That should be handled in a later phase.

This phase is only about making the horizontal scrollbar live in a stable bottom rail.

### 8. Tests

Update existing tests and add new tests as needed.

Required coverage:

* timeline-bottom-scrollbar-rail exists
* timeline-horizontal-scrollbar still exists
* timeline-frame-scroll-viewport still exists
* timeline-frame-scroll-content still exists
* timeline-layer-controls-rail still exists
* horizontal scrollbar is still associated with the horizontal frame scroll area
* bottom scrollbar rail is structurally outside the frame row content
* horizontal scrolling still changes virtualized frame range
* layer controls rail remains mounted after horizontal scrolling
* large frameCount still does not build far-off frame headers/cells
* existing spacer keys still exist
* frame cell click still works
* layer row click still works

Avoid fragile pixel-perfect tests.

Prefer structural tests using stable keys and descendant/non-descendant relationships.

A small geometry test is allowed only if it checks the high-level relationship:

* bottom scrollbar rail is below the frame grid area

Do not compare incidental text baselines or exact frame header positions.

### 9. Documentation update

Update docs/LongTerm_Performance_Architecture.md with a small Phase 97 note.

Suggested note:

Phase 97 moved the horizontal scrollbar into a stable bottom rail so timeline scrolling remains visible and discoverable regardless of layer count. This keeps the frame grid above the scrollbar and preserves the fixed layer controls rail / frame viewport separation required for long-term TVPaint-style timeline ergonomics.

Do not rewrite the whole document.

### 10. Out of scope

Do not modify:

* Project / Track / Cut / Layer / Frame models
* persistence
* save/load
* renderer/cache
* commands
* undo/redo
* StoryboardPanel
* HomePage
* Provider / Riverpod / Bloc / ChangeNotifier

Do not add:

* vertical layer virtualization
* TVPaint-style vertical scrollbar
* full custom scrollbar painting
* playhead
* ruler
* zoom
* drag
* trim
* frame editing behavior
* cut editing behavior

This phase is only the bottom horizontal scrollbar rail placement.

## Long-term design rules

Timeline scrollbars should be visible, stable, and placed as part of the working timeline UI.

The horizontal scrollbar should not shift depending on how many layer rows are present.

The long-term target is:

* stable bottom horizontal scrollbar rail
* future vertical scrollbar between layer controls and frame area
* frame viewport independent from layer controls rail
* scroll controls that feel like part of an animation timeline, not hidden browser scrollbars

Do not solve the vertical scrollbar in this phase.

## Acceptance criteria

This phase is complete when:

* The horizontal scrollbar is placed in a stable bottom rail.
* The scrollbar location does not feel tied to the last layer row.
* The frame grid area remains above the scrollbar.
* The horizontal scrollbar still controls the frame scroll viewport.
* Layer controls rail remains fixed outside horizontal scrolling.
* Existing horizontal frame virtualization remains active.
* Existing visible item keys remain stable.
* New bottom rail keys are added.
* No vertical layer virtualization is implemented.
* No vertical scrollbar is implemented.
* No model changes.
* No editing behavior changes.
* docs/LongTerm_Performance_Architecture.md has a small Phase 97 note.
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
* new bottom scrollbar rail keys added
* explanation of how the horizontal scrollbar was moved into a stable bottom rail
* confirmation that the scrollbar still uses the existing horizontal ScrollController
* confirmation that horizontal virtualization still remains active
* confirmation that vertical layer virtualization was not implemented
* confirmation that vertical scrollbar was not implemented
* confirmation that existing visible item keys were preserved
* confirmation that StoryboardPanel was not changed
* confirmation that Project / Cut / Layer / Frame models were not changed
* confirmation that no editing behavior was added
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
