# Phase 94 Codex Task - LayerTimelineGrid Fixed Layer Controls Rail Foundation

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

Recent phases:

* Phase 91 added visible range calculation.
* Phase 92 added virtualization render plan calculation.
* Phase 93 added TimelineGridMetrics and a TimelinePanel virtualization adapter.

The current LayerTimelineGrid still renders eagerly.

This phase must not implement actual frame/cell virtualization yet.

## Phase goal

Restructure LayerTimelineGrid so the layer controls column is outside the horizontal frame scroll area.

This is a structural preparation phase for future horizontal frame virtualization.

The goal is:

* left fixed layer controls rail
* right horizontal frame scroll viewport
* keep current visible behavior as close as possible
* keep all existing frame cells and layer rows rendered eagerly for now
* do not apply visible range filtering yet

## Why this phase exists

Future TimelinePanel virtualization needs a clean horizontal viewport that represents frame cells only.

If layer controls and frame cells live inside the same horizontal scroll content, the virtualization math becomes harder and fragile:

* frame scroll offset may include the layer controls width
* leading spacer calculations become confusing
* frame header and frame cells are harder to keep aligned
* future fixed layer rail behavior becomes harder to introduce safely

This phase separates the structural concerns before actual virtualization.

## Required implementation

### 1. Update LayerTimelineGrid structure

Update:

* lib/src/ui/timeline/layer_timeline_grid.dart

The new high-level structure should be:

* vertical scrolling remains shared between layer controls and frame rows
* left rail contains:

    * Add Layer header cell
    * one layer controls row per layer
    * empty-state vertical space if needed
* right side contains:

    * horizontal SingleChildScrollView
    * frame header row
    * frame cell rows

The layer controls rail must not be inside the horizontal frame scroll viewport.

### 2. Add stable keys

Add these keys:

* timeline-layer-controls-rail
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content

If useful, also add:

* timeline-frame-header-row
* timeline-frame-row-area-<layerId>

Do not remove existing keys.

Existing keys must remain stable:

* timeline-add-layer-button
* timeline-layer-row-<layerId>
* timeline-frame-header-<frameIndex>
* timeline-cell-<layerId>-<frameIndex>
* timeline-layer-kind-icon-<layerId>
* timeline-layer-name-<layerId>

### 3. Preserve current metrics

Use TimelineGridMetrics.defaults from Phase 93.

Do not reintroduce hardcoded duplicate layout numbers.

The following values should remain consistent:

* minimumVisibleFrameCells = 24
* layerControlsWidth = 220
* frameCellWidth = 48
* layerRowHeight = 52

### 4. Preserve behavior

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

### 5. Keep eager rendering for now

This phase must not use visible range filtering yet.

Do not use calculateLayerTimelineGridVirtualizationPlan to reduce built cells yet.

All currently visibleFrameCount frame headers and cells should still be built.

Actual horizontal frame virtualization will be a later phase.

### 6. Tests

Update existing LayerTimelineGrid / TimelinePanel tests as needed.

Add tests if useful.

Required coverage:

* timeline-layer-controls-rail exists
* timeline-frame-scroll-viewport exists
* timeline-frame-scroll-content exists
* layer controls rail contains timeline-add-layer-button
* frame scroll content contains frame headers
* layer row controls still render
* frame cells still render
* clicking a frame cell still calls selection callbacks
* clicking a layer row still calls layer selection callbacks
* horizontal scrolling does not remove layer controls rail from the widget tree

Do not write fragile tests comparing incidental text top positions.

Prefer structural tests using stable keys.

### 7. Documentation update

Update docs/LongTerm_Performance_Architecture.md with a small Phase 94 note.

Suggested note:

Phase 94 separated LayerTimelineGrid into a fixed layer controls rail and a horizontal frame scroll area. This prepares the TimelinePanel for future horizontal frame virtualization by ensuring frame scroll geometry is independent from the layer controls column.

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

* actual visible range based frame virtualization
* vertical layer virtualization
* playhead
* ruler
* zoom
* drag
* trim
* scroll sync features
* frame editing behavior
* cut editing behavior

This phase is structural UI preparation only.

## Long-term design rules

This phase should make future virtualization easier.

The long-term target is:

* fixed layer rail
* horizontal frame viewport
* visible frame range calculation
* leading/trailing frame spacers
* visible-only frame headers and cells
* later vertical layer virtualization

Do not solve everything in this phase.

Do not mix structural rail separation and visible cell filtering in one PR.

## Acceptance criteria

This phase is complete when:

* LayerTimelineGrid has a fixed layer controls rail.
* Layer controls rail is not inside the horizontal frame scroll viewport.
* Horizontal frame scroll viewport contains frame headers and frame cells.
* Existing TimelinePanel behavior is preserved.
* Existing keys remain stable.
* New keys are added.
* No actual frame virtualization is implemented yet.
* No model changes.
* No editing behavior changes.
* docs/LongTerm_Performance_Architecture.md has a small Phase 94 note.
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
* new keys added
* explanation of the new LayerTimelineGrid structure
* confirmation that actual frame virtualization was not implemented yet
* confirmation that existing keys were preserved
* confirmation that StoryboardPanel was not changed
* confirmation that Project / Cut / Layer / Frame models were not changed
* confirmation that no editing behavior was added
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
