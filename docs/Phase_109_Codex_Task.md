# Phase 109 Codex Task - Exposure Range Selection Highlight and Handle Visual Foundation

## Goal

Add a visual selection highlight for the exposure range containing the currently selected frame.

This phase builds on Phase 108's pure exposure range resolver.

This is still visual-only.

Do not implement exposure editing.

Do not implement drag handles.

Do not implement resize behavior.

Do not change the data model.

## Background

After Phase 107:

* drawingStart + heldExposure ranges visually read as connected drawing blocks.
* blankStart + blankHeld ranges visually read as connected blank blocks.
* Empty cells do not become blocks.
* Outside-playback authored data can render when visible.

After Phase 108:

* a pure resolver can determine the exposure range containing a selected frame.
* the resolver can classify drawing / blank / none.
* it returns startFrameIndex and endFrameIndexExclusive.
* it respects min/max bounds and does not query outside them.

Phase 109 should use that resolver to make the currently selected exposure range visually clear in the timeline.

## Core Rule

This phase only adds visual range selection foundation.

It must not change timeline behavior.

Do not add:

* exposure block dragging
* exposure block resizing
* handle hit testing
* duration editing
* context menus
* new commands
* data model changes
* controller changes unless strictly necessary for read-only visual state

## Required Behavior

### 1. Highlight the selected exposure range

When the selected/current frame is inside a drawing exposure range:

* visually highlight the whole drawing exposure range
* not just the selected cell

When the selected/current frame is inside a blank exposure range:

* visually highlight the whole blank exposure range
* not just the selected cell

When the selected/current frame is empty:

* keep existing single-cell selection behavior
* do not invent a range

The selected cell border must remain visible and clear.

### 2. Use Phase 108 resolver

Use the existing pure resolver from Phase 108.

Do not reimplement range search logic inside the widget.

Preferred:

* for each visible layer row, resolve the selected range for that layer and currentFrameIndex
* pass the resolved range information into the rendered cells
* each cell can determine whether it is inside the selected exposure range

The selected range must be based on:

* active layer
* currentFrameIndex
* exposureStateForLayer

Do not highlight ranges on inactive layers.

### 3. Keep outside-playback behavior

Selected exposure ranges outside playback must still work if they are visible.

Example:

* playbackFrameCount = 24
* visibleFrameCount = 48
* drawingStart at frame 45
* heldExposure at frame 46
* currentFrameIndex = 45

The visible authored range at 45..47 should be able to show the selection highlight.

Do not clamp to playbackFrameCount.

Do not hide outside-playback selected ranges.

### 4. Virtualization safety

Do not disable virtualization.

Do not expand visibleFrameCount.

The resolver must be called with visible bounds that are safe.

Important:

* the resolver must not query outside the visible timeline range
* the selection highlight may only cover the visible portion of a range
* hidden authored data remains stored but is not rendered

### 5. Visual handle foundation

Add visual-only range edge markers if practical.

These are not interactive.

They are only visual placeholders for future editing handles.

Allowed:

* a small left edge marker on the selected range start cell
* a small right edge marker on the selected range end cell
* only on active layer
* only when the selected frame is inside an exposure range

Not allowed:

* drag behavior
* resize behavior
* mouse cursor changes implying editability
* gesture detectors
* hit testing logic
* commands

If handle markers make this phase too large, implement only the selection range highlight and leave handle markers for the next phase.

### 6. Visual style

Keep the style simple.

Recommended:

* selected exposure range overlay should be subtle but readable
* selected cell border remains stronger than range highlight
* drawing and blank ranges may share the same selection outline style
* do not use heavy gradients
* do not make non-selected layers visually noisy

The highlight should not obscure:

* mark symbol
* frame name
* exposure symbols
* selected cell border
* cut end boundary
* playhead

### 7. Preserve priorities

Do not change display priority:

* mark priority remains highest
* frame name priority remains above default exposure symbol
* selected cell border remains clear
* exposure block visual remains underneath content
* range highlight must not hide text/symbols

### 8. Preserve stable keys

Do not remove existing stable keys.

Preserve:

* timeline-cell-<layerId>-<frameIndex>
* timeline-selected-cell
* timeline-frame-ruler
* timeline-frame-ruler-scrub-area
* timeline-frame-header-row
* timeline-frame-header-<frameIndex>
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-cut-end-boundary
* timeline-cut-end-boundary-ruler
* timeline-playhead
* timeline-playhead-column

If adding optional keys, use names like:

* timeline-selected-exposure-range-cell-<layerId>-<frameIndex>
* timeline-exposure-range-start-handle-<layerId>-<frameIndex>
* timeline-exposure-range-end-handle-<layerId>-<frameIndex>

Only add keys that are useful for tests/debugging.

## Suggested Files

Likely:

* lib/src/ui/timeline/layer_timeline_grid.dart
* lib/src/ui/timeline/timeline_exposure_range_resolver.dart
* test/ui/layer_timeline_grid_test.dart
* test/ui/timeline/timeline_exposure_range_resolver_test.dart

Possibly:

* lib/src/ui/timeline/timeline_exposure_range_selection_visual.dart
* test/ui/timeline/timeline_exposure_range_selection_visual_test.dart

Only add a separate helper file if it keeps the widget clean.

## Required Tests

### 1. Widget tests for range highlight

Add lightweight widget tests proving:

* selecting drawingStart highlights drawingStart + heldExposure cells on the active layer
* selecting heldExposure highlights back to the drawingStart range
* selecting blankStart highlights blankStart + blankHeld cells on the active layer
* selecting blankHeld highlights back to the blankStart range
* selecting empty cell does not highlight a range
* inactive layers do not show selected range highlight
* outside-playback visible authored range can be highlighted

Avoid pixel-perfect tests.

Prefer checking stable keys or simple widget structure.

### 2. Preserve existing behavior tests

Existing tests must continue to pass for:

* exposure block visual rendering
* selected cell border
* mark priority
* frame name priority
* outside-playback selection/editing
* authored data outside playback visible inside visible range
* body/ruler cut end boundaries
* ruler scrub
* sticky ruler
* no overflow
* cut switching

### 3. Optional helper tests

If a helper is added for visual selection classification, test it as a pure helper.

## Out of Scope

Do not implement:

* exposure block drag editing
* exposure block resize behavior
* interactive handles
* duration editing
* cut duration editing UI
* playback
* export
* zoom
* snapping
* auto-scroll
* onion skin
* StoryboardPanel changes
* renderer/cache/persistence changes
* model rewrite
* new state management
* Provider/Riverpod/Bloc/ChangeNotifier
* destructive trimming/deletion

## Acceptance Criteria

This phase is complete when:

1. The selected drawing exposure range is visually highlighted.
2. The selected blank exposure range is visually highlighted.
3. Empty selected cells do not create range highlights.
4. Only the active layer shows selected range highlight.
5. Outside-playback visible authored ranges can be highlighted.
6. Existing exposure block visuals remain intact.
7. Selected cell border remains clear.
8. Mark/frame name priority remains unchanged.
9. No editing behavior is added.
10. No data model change is added.
11. Phase 104R / 105 / 106 / 107 / 108 behavior remains intact.
12. dart format lib test passes.
13. flutter analyze passes.
14. flutter test passes.
15. git status is clean or only expected files are changed.

## Report Back

Report:

* changed files
* whether a helper was added
* how the selected exposure range is resolved
* how drawing range highlight works
* how blank range highlight works
* how empty cells are handled
* how inactive layers are protected
* how outside-playback visible ranges are handled
* whether visual-only handles were added
* confirmation that no editing behavior changed
* confirmation that no data model changed
* confirmation that Phase 104R/105/106/107/108 behavior remains intact
* analyze result
* full test result
* git status summary
