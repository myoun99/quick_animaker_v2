# Phase 95 Codex Task - LayerTimelineGrid Horizontal Frame Virtualization First Slice

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

QuickAnimaker v2 is preparing TimelinePanel for long-term 2D virtualization.

Important documents:

* docs/Handoff_QuickAnimaker_v2_Current.md
* docs/LongTerm_Performance_Architecture.md
* docs/Phase_91_Codex_Task.md
* docs/Phase_92_Codex_Task.md
* docs/Phase_93_Codex_Task.md
* docs/Phase_94_Codex_Task.md

Recent phases:

* Phase 91 added visible range calculation.
* Phase 92 added virtualization render plan calculation.
* Phase 93 added TimelineGridMetrics and a TimelinePanel virtualization adapter.
* Phase 94 separated LayerTimelineGrid into a fixed layer controls rail and a horizontal frame scroll area.

The current LayerTimelineGrid still eagerly renders all frame headers and all frame cells.

## Phase goal

Apply the first actual horizontal frame virtualization slice to LayerTimelineGrid.

This phase should virtualize only the horizontal frame axis.

The fixed layer controls rail must remain as introduced in Phase 94.

The vertical layer axis should remain eagerly rendered for now.

## What this phase should change

Before this phase:

* LayerTimelineGrid builds all frame headers from 0 to visibleFrameCount.
* Each layer row builds all frame cells from 0 to visibleFrameCount.
* This is not acceptable for large frame counts.

After this phase:

* LayerTimelineGrid should calculate a visible frame range from the horizontal scroll offset and viewport width.
* It should build only the visible/overscanned frame headers.
* It should build only the visible/overscanned frame cells for each eagerly rendered layer row.
* It should preserve full horizontal scroll geometry using leading and trailing frame spacers.
* The layer controls rail should stay fixed outside horizontal scrolling.

## Required implementation

### 1. Update LayerTimelineGrid to use horizontal frame virtualization

Update:

* lib/src/ui/timeline/layer_timeline_grid.dart

LayerTimelineGrid may be converted from StatelessWidget to StatefulWidget if needed.

Recommended approach:

* Add a private horizontal ScrollController.
* Listen to horizontal scroll offset.
* Use LayoutBuilder around the horizontal frame scroll viewport to get viewport width.
* Use calculateLayerTimelineGridVirtualizationPlan from Phase 93.
* Use the returned frameRange and spacer widths to build:

    * leading frame spacer
    * visible frame headers
    * trailing frame spacer
    * leading frame spacer per row
    * visible frame cells per row
    * trailing frame spacer per row

Do not virtualize vertical layer rows yet.

### 2. Keep effective frame count behavior

Use the adapter behavior from Phase 93:

* effectiveFrameCount = max(frameCount, TimelineGridMetrics.defaults.minimumVisibleFrameCells)

This preserves the current minimum 24-frame visual area.

### 3. Keep existing keys stable for built items

Existing keys must remain unchanged for any frame/layer that is currently built:

* timeline-frame-header-<frameIndex>
* timeline-cell-<layerId>-<frameIndex>
* timeline-layer-row-<layerId>
* timeline-layer-kind-icon-<layerId>
* timeline-layer-name-<layerId>
* timeline-add-layer-button
* timeline-layer-controls-rail
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content

Do not rename these keys.

### 4. Add spacer keys

Add stable keys for spacer widgets.

Recommended keys:

* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-row-leading-spacer-<layerId>
* timeline-frame-row-trailing-spacer-<layerId>

These keys will help tests verify scroll geometry without relying on fragile pixel comparisons.

### 5. Preserve Phase 94 structure

The high-level structure must remain:

* left fixed layer controls rail
* right horizontal frame scroll viewport
* frame scroll content contains frame header row and frame cell rows

The layer controls rail must not be inside the horizontal frame scroll viewport.

### 6. Keep behavior unchanged

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
* frame/cell key format

### 7. Do not implement vertical virtualization yet

This phase is horizontal frame virtualization only.

Do not filter layer rows by vertical visible range.

Do not introduce vertical ScrollController logic yet unless strictly necessary for preserving current behavior.

Vertical layer virtualization will be a later phase.

### 8. Tests

Update existing tests as needed.

Add tests for the new horizontal virtualization behavior.

Required coverage:

* timeline-layer-controls-rail still exists.
* timeline-frame-scroll-viewport still exists.
* timeline-frame-scroll-content still exists.
* initial viewport builds visible frame headers and cells.
* initial viewport does not build far-off frame headers/cells when frameCount is large.
* leading and trailing spacers exist.
* horizontal scroll changes which frame headers/cells are built.
* layer controls rail remains mounted after horizontal scrolling.
* clicking a visible frame cell still calls frame selection callbacks.
* clicking a layer row still calls layer selection callbacks.
* minimumVisibleFrameCells behavior still works when frameCount is smaller than 24.
* large frameCount such as 100000 does not build all frame headers/cells.

Important test rule:

Do not assert every exact pixel unless necessary.

Prefer structural tests using keys and visible ranges.

### 9. Performance guardrail test

Add at least one test that proves a large frameCount does not eagerly build all frame cells.

Example expectation:

* Pump a grid with frameCount = 100000 and a constrained viewport.
* Confirm timeline-frame-header-99999 is not found initially.
* Confirm timeline-cell-<layerId>-99999 is not found initially.
* Confirm only nearby visible frame headers/cells are built.

Do not create 100000 Frame model objects for this test.

The test should use frameCount only.

### 10. Documentation update

Update docs/LongTerm_Performance_Architecture.md with a small Phase 95 note.

Suggested note:

Phase 95 applied the first horizontal frame virtualization slice to LayerTimelineGrid. The fixed layer controls rail remains eager and stable, while frame headers and frame cells are now built only for the visible/overscanned horizontal frame range with leading/trailing spacers preserving full scroll geometry.

Do not rewrite the whole document.

### 11. Out of scope

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
* playhead
* ruler
* zoom
* drag
* trim
* scroll sync features beyond what is necessary for horizontal frame virtualization
* frame editing behavior
* cut editing behavior

This phase is only the first horizontal frame virtualization slice.

## Long-term design rules

This phase should reduce frame-axis widget construction while preserving existing behavior.

Future phases may add:

* vertical layer virtualization
* scroll sync between header/body if needed
* playhead/ruler support
* zoom-dependent frame widths
* cache-aware cell rendering

Do not solve all of those in this phase.

Keep this phase focused on horizontal frame virtualization only.

## Acceptance criteria

This phase is complete when:

* LayerTimelineGrid builds only the visible/overscanned frame headers for the horizontal viewport.
* LayerTimelineGrid builds only the visible/overscanned frame cells for each currently rendered layer row.
* Full horizontal scroll geometry is preserved with leading/trailing spacers.
* Layer controls rail remains outside horizontal scrolling.
* Existing visible behavior is preserved as much as possible.
* Existing keys for built frame headers/cells remain unchanged.
* New spacer keys are added.
* No vertical layer virtualization is implemented yet.
* No model changes.
* No editing behavior changes.
* docs/LongTerm_Performance_Architecture.md has a small Phase 95 note.
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
* whether LayerTimelineGrid was converted to StatefulWidget
* new spacer keys added
* explanation of the horizontal virtualization structure
* confirmation that vertical layer virtualization was not implemented
* confirmation that existing visible item keys were preserved
* confirmation that StoryboardPanel was not changed
* confirmation that Project / Cut / Layer / Frame models were not changed
* confirmation that no editing behavior was added
* confirmation that large frameCount does not build all frame headers/cells
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
