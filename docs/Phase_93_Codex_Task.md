# Phase 93 Codex Task - Timeline Grid Metrics and Virtualization Adapter Foundation

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
* docs/Phase_92_Codex_Task.md

Phase 91 added:

* lib/src/ui/timeline/timeline_visible_range.dart
* TimelineVisibleRange
* TimelineVisibleRanges
* calculateVisibleIndexRange
* calculateTimelineVisibleRanges

Phase 92 added:

* lib/src/ui/timeline/timeline_virtualization_plan.dart
* TimelineVirtualizationPlan
* calculateTimelineVirtualizationPlan

The current TimelinePanel / LayerTimelineGrid still uses eager Row / Column rendering.

This phase must not rewrite TimelinePanel yet.

## Phase goal

Create a shared timeline grid metrics foundation and a TimelinePanel-specific virtualization adapter.

The goal is to connect the pure virtualization calculators to the actual TimelinePanel dimensions without changing rendering behavior yet.

This phase should prepare for a future TimelinePanel virtualization implementation.

## Why this phase exists

LayerTimelineGrid currently has private constants such as:

* minimum visible cells
* layer controls width
* frame cell width
* row height

Future virtualization must use exactly the same values as the real TimelinePanel.

If the virtualization calculator uses duplicated hardcoded values, future bugs can happen:

* wrong visible frame range
* wrong spacer width
* wrong scroll geometry
* header/body desync
* off-by-one visible cell errors

Therefore, this phase extracts or centralizes these grid metrics and adds a TimelinePanel-specific adapter that calculates a virtualization plan using those metrics.

## Required implementation

### 1. Add timeline grid metrics

Create:

* lib/src/ui/timeline/timeline_grid_metrics.dart

Add an immutable class:

* TimelineGridMetrics

Recommended fields:

* int minimumVisibleFrameCells
* double layerControlsWidth
* double frameCellWidth
* double layerRowHeight

Recommended default values should match the current LayerTimelineGrid behavior:

* minimumVisibleFrameCells = 24
* layerControlsWidth = 220
* frameCellWidth = 48
* layerRowHeight = 52

Add a const default instance if useful:

* TimelineGridMetrics.defaults

Keep this file pure Dart.

Do not import Flutter widgets.

### 2. Make LayerTimelineGrid use TimelineGridMetrics

Update:

* lib/src/ui/timeline/layer_timeline_grid.dart

LayerTimelineGrid should continue to render exactly the same way.

But its internal constants should be backed by TimelineGridMetrics or the same shared default values.

Do not change visible behavior.

Do not change keys.

Do not change callback behavior.

Do not change layout dimensions.

This is allowed because it prevents future metric drift.

### 3. Add TimelinePanel virtualization adapter

Create:

* lib/src/ui/timeline/timeline_panel_virtualization_adapter.dart

This file should be pure Dart or close to pure Dart.

It may import:

* timeline_grid_metrics.dart
* timeline_virtualization_plan.dart

It must not import:

* material.dart
* widgets.dart
* Project / Track / Cut / Layer / Frame models

Add a function similar to:

* calculateLayerTimelineGridVirtualizationPlan

Input should include:

* double horizontalScrollOffset
* double verticalScrollOffset
* double viewportWidth
* double viewportHeight
* int frameCount
* int layerCount
* TimelineGridMetrics metrics
* int frameOverscanBefore
* int frameOverscanAfter
* int layerOverscanBefore
* int layerOverscanAfter

Behavior:

* Use metrics.frameCellWidth as frameCellWidth.
* Use metrics.layerRowHeight as layerRowHeight.
* Use max(frameCount, metrics.minimumVisibleFrameCells) as the effective frame count.
* Pass the effective frame count to calculateTimelineVirtualizationPlan.
* Do not create widgets.
* Do not inspect Project/Cut/Layer/Frame.
* Do not mutate anything.

This adapter is the bridge between current TimelinePanel sizing and the pure virtualization plan.

### 4. Tests

Create:

* test/ui/timeline/timeline_grid_metrics_test.dart
* test/ui/timeline/timeline_panel_virtualization_adapter_test.dart

Required tests for TimelineGridMetrics:

* default minimumVisibleFrameCells is 24
* default layerControlsWidth is 220
* default frameCellWidth is 48
* default layerRowHeight is 52
* custom metrics can be created

Required tests for adapter:

* uses minimumVisibleFrameCells when frameCount is smaller than 24
* uses actual frameCount when frameCount is larger than 24
* uses metrics.frameCellWidth for total width and spacers
* uses metrics.layerRowHeight for layer heights
* horizontal scroll offset affects frame spacer
* vertical scroll offset affects layer spacer
* 100000 frameCount works by calculation only
* no widgets are built

### 5. Documentation update

Update docs/LongTerm_Performance_Architecture.md with a small Phase 93 note.

Suggested note:

Phase 93 introduced TimelineGridMetrics and a TimelinePanel virtualization adapter so future TimelinePanel virtualization calculations use the same dimensions as the current LayerTimelineGrid instead of duplicating hardcoded values.

Do not rewrite the whole document.

### 6. Out of scope

Do not modify:

* TimelinePanel rendering behavior
* LayerTimelineGrid visual behavior
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

This phase is metric/adapter foundation only.

## Long-term design rules

Timeline virtualization must not duplicate layout metrics.

The current UI and future virtualization plan must share the same grid metric source.

Future TimelinePanel virtualization should be able to use:

* TimelineGridMetrics
* TimelineVisibleRange
* TimelineVirtualizationPlan
* calculateLayerTimelineGridVirtualizationPlan

This keeps the rendering layer and calculation layer aligned.

## Acceptance criteria

This phase is complete when:

* lib/src/ui/timeline/timeline_grid_metrics.dart exists.
* lib/src/ui/timeline/timeline_panel_virtualization_adapter.dart exists.
* TimelineGridMetrics exists.
* calculateLayerTimelineGridVirtualizationPlan exists.
* LayerTimelineGrid uses shared metrics/default values without behavior changes.
* Tests cover default metrics, custom metrics, small frame count, large frame count, spacer calculations, and 100000 frameCount.
* No UI rendering behavior changes.
* No model changes.
* No editing behavior changes.
* No eager 100000 widget build is introduced.
* docs/LongTerm_Performance_Architecture.md has a small Phase 93 note.
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
* new metric class
* new adapter function
* confirmation that LayerTimelineGrid visual behavior was not changed
* confirmation that TimelinePanel rendering was not virtualized yet
* confirmation that StoryboardPanel rendering was not changed
* confirmation that Project / Cut / Layer / Frame models were not changed
* confirmation that no editing behavior was added
* confirmation that large frame count is tested by calculation only, not widget construction
* final check results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
