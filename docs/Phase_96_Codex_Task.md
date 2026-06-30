# Phase 96 Codex Task - Timeline Visible Scrollbar Foundation

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

Recent phases:

* Phase 91 added visible range calculation.
* Phase 92 added virtualization render plan calculation.
* Phase 93 added TimelineGridMetrics and a TimelinePanel virtualization adapter.
* Phase 94 separated LayerTimelineGrid into a fixed layer controls rail and a horizontal frame scroll area.
* Phase 95 applied the first horizontal frame virtualization slice to LayerTimelineGrid.

Current issue:

* Horizontal frame scrolling exists internally.
* But there is no clearly visible horizontal scrollbar.
* Users cannot easily tell where the horizontal scroll affordance is.
* The long-term target should be closer to TVPaint-style timeline behavior where scrollbars are visible, stable, and placed as part of the timeline UI.

## Phase goal

Add a visible scrollbar foundation for LayerTimelineGrid.

The goal is to make timeline scrolling discoverable and stable without changing editing behavior.

This phase should add:

* an always-visible horizontal scrollbar for the frame scroll area
* stable keys for scrollbar structure
* a structural foundation for a future vertical scrollbar placed between the layer controls rail and frame area
* no vertical layer virtualization yet

## Desired long-term layout direction

The long-term target is similar to TVPaint-style timeline ergonomics:

* left side: fixed layer controls rail
* right side: frame timeline area
* horizontal scrollbar: visible at the bottom of the frame timeline area
* vertical scrollbar: eventually visible between the layer controls rail and frame timeline area
* scrolling should feel explicit and controllable, not hidden

This phase does not need to perfectly clone TVPaint.

It should establish the correct structural direction.

## Required implementation

### 1. Add visible horizontal scrollbar

Update:

* lib/src/ui/timeline/layer_timeline_grid.dart

The existing horizontal ScrollController introduced in Phase 95 should be reused.

Add a Scrollbar around the horizontal frame scroll viewport.

Recommended behavior:

* thumbVisibility: true
* trackVisibility: true if supported cleanly
* controller: the existing horizontal ScrollController
* notificationPredicate adjusted if needed
* do not create a second competing horizontal controller

The horizontal scrollbar should be visible for the frame scroll area.

It should not include the layer controls rail.

### 2. Add stable scrollbar keys

Add stable keys:

* timeline-horizontal-scrollbar
* timeline-horizontal-scrollbar-viewport
* timeline-scrollbar-area

The existing key must remain stable:

* timeline-frame-scroll-viewport

If Flutter Scrollbar requires key placement on a wrapping widget rather than the Scrollbar itself, keep the key names stable and documented in tests.

### 3. Preserve horizontal virtualization

Do not remove or bypass Phase 95 virtualization.

The frame header row and frame cell rows should still build only the visible/overscanned horizontal frame range.

The spacer keys from Phase 95 must remain:

* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-row-leading-spacer-<layerId>
* timeline-frame-row-trailing-spacer-<layerId>

### 4. Prepare for future vertical scrollbar placement

Do not implement full vertical scrollbar behavior unless it is simple and safe.

However, the structure should not make future TVPaint-style vertical scrollbar placement harder.

Add a small structural placeholder or wrapper only if useful.

Possible key:

* timeline-vertical-scrollbar-slot

If adding this slot is too invasive, skip the slot and document that vertical scrollbar placement remains a future phase.

Do not implement vertical layer virtualization in this phase.

### 5. Preserve existing behavior

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

### 6. Tests

Update existing tests and add new tests as needed.

Required coverage:

* timeline-horizontal-scrollbar exists
* timeline-frame-scroll-viewport still exists
* timeline-frame-scroll-content still exists
* timeline-layer-controls-rail still exists
* horizontal scrollbar is associated with the horizontal frame scroll area
* horizontal scrolling still changes virtualized frame range
* layer controls rail remains mounted after horizontal scrolling
* large frameCount still does not build far-off frame headers/cells
* existing spacer keys still exist
* frame cell click still works
* layer row click still works

Avoid fragile pixel-perfect tests.

Prefer structural key tests and behavior tests.

### 7. Documentation update

Update docs/LongTerm_Performance_Architecture.md with a small Phase 96 note.

Suggested note:

Phase 96 added a visible horizontal scrollbar foundation for LayerTimelineGrid so horizontal frame virtualization is discoverable and controllable. The scrollbar is tied to the frame scroll viewport, not the fixed layer controls rail, preserving the long-term TVPaint-style direction where scroll controls are stable and visible.

Do not rewrite the whole document.

### 8. Out of scope

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
* full custom scrollbar painting
* playhead
* ruler
* zoom
* drag
* trim
* frame editing behavior
* cut editing behavior

This phase is only the visible horizontal scrollbar foundation and future scrollbar placement preparation.

## Long-term design rules

Timeline scrollbars should be visible and stable.

The long-term target is not hidden browser-like scrollbars.

For an animation timeline, scrollbars are part of the working UI.

Future phases may add:

* dedicated vertical scrollbar between layer controls rail and frame area
* synchronized vertical scrolling
* scroll thumb styling
* timeline ruler integration
* zoom-aware scrollbar behavior

Do not solve all of those in this phase.

## Acceptance criteria

This phase is complete when:

* LayerTimelineGrid has an always-visible horizontal scrollbar for the frame scroll area.
* The horizontal scrollbar does not include the layer controls rail.
* The horizontal scrollbar uses the existing horizontal ScrollController.
* Existing horizontal frame virtualization remains active.
* Existing layer controls rail remains fixed.
* Existing visible item keys remain stable.
* New scrollbar keys are added.
* No vertical layer virtualization is implemented.
* No model changes.
* No editing behavior changes.
* docs/LongTerm_Performance_Architecture.md has a small Phase 96 note.
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
* new scrollbar keys added
* whether a vertical scrollbar slot was added or intentionally deferred
* explanation of how the horizontal scrollbar is attached to the frame scroll viewport
* confirmation that horizontal virtualization still remains active
* confirmation that vertical layer virtualization was not implemented
* confirmation that existing visible item keys were preserved
* confirmation that StoryboardPanel was not changed
* confirmation that Project / Cut / Layer / Frame models were not changed
* confirmation that no editing behavior was added
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
