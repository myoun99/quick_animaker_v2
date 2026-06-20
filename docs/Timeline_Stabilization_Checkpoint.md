# Timeline Stabilization Checkpoint

## Status

The timeline refactoring / stabilization line is complete through Phase 145.

This checkpoint closes the current timeline stabilization work so the next major area can start after handoff. Recommended next order:

1. Storyboard / conte panel stabilization
2. 2D brush architecture
3. Canvas / drawing implementation

## Timeline architecture overview

The current timeline architecture is split into small responsibilities. Keep these pieces descriptive and compositional; do not collapse long-term range semantics back into widgets.

- `TimelinePanel` is the public timeline entry point. It wires timeline data, selected/current state, callbacks, and orientation into the timeline UI surface.
- `LayerTimelineGrid` owns the horizontal timeline grid composition: layer controls on the side, frame ruler/header at the top, scrollable frame body, scrollbar rails, playhead, and cut-end boundary visuals.
- `TimelineController` owns timeline cursor/read/edit orchestration against project data. It exposes authored/data extent as a controller concern, not as a widget display limit.
- `TimelineFrameRuler` renders the ruler surface and scrub area for frame navigation.
- `TimelineFrameHeaderRow` renders the frame-number header row, including leading/trailing spacer structure for horizontal scrolling alignment.
- `TimelineLayerControlsHeader` renders the layer-controls header area and add-layer action boundary.
- `TimelineLayerControlsRow` renders per-layer controls such as the layer label, kind icon, visibility, and opacity controls.
- `TimelineVerticalScrollbarRail` renders the vertical scrollbar rail/track/thumb structure for the timeline body.
- `TimelineHorizontalScrollbarRail` renders the bottom horizontal scrollbar rail/track/thumb/viewport structure.
- `TimelineFrameScrollViewport` defines the visible viewport for horizontally scrollable frame content.
- `TimelineFrameRowsScrollBody` groups the rendered frame rows inside the scrollable timeline body.
- `TimelineFrameGridStack` layers frame rows with overlay visuals such as playhead and cut-end boundary.
- `TimelineLayerFrameBodyLayout` lays out a layer row's frame body across the visible/virtualized frame range.
- `TimelineRulerCutEndBoundary` renders the cut-end marker in ruler/header space.
- `TimelineBodyCutEndBoundary` renders the cut-end marker in the frame body.
- `TimelinePlayhead` renders the current-frame playhead and its column marker across the frame grid.

## Stable key inventory

These keys are part of the stabilized timeline contract and should be preserved unless a future phase explicitly updates all dependent tests and handoff documentation.

- `timeline-sticky-header-row`
- `timeline-frame-ruler`
- `timeline-frame-ruler-scrub-area`
- `timeline-frame-header-row`
- `timeline-frame-header-<frameIndex>`
- `timeline-frame-header-leading-spacer`
- `timeline-frame-header-trailing-spacer`
- `timeline-frame-scroll-viewport`
- `timeline-frame-scroll-content`
- `timeline-horizontal-scrollbar`
- `timeline-vertical-scrollbar`
- `timeline-vertical-scrollbar-slot`
- `timeline-layer-controls-rail`
- `timeline-frame-grid-area`
- `timeline-playhead`
- `timeline-playhead-column`
- `timeline-cut-end-boundary`
- `timeline-cut-end-boundary-ruler`
- `timeline-cell-<layerId>-<frameIndex>`
- `timeline-selected-exposure-range-outline-<layerId>`
- `timeline-layer-row-<layerId>`
- `timeline-layer-name-<layerId>`
- `timeline-layer-kind-icon-<layerId>`
- `timeline-layer-visibility-<layerId>`
- `timeline-layer-opacity-<layerId>`
- `timeline-add-layer-button`
- `timeline-vertical-scrollbar-track`
- `timeline-vertical-scrollbar-thumb`
- `timeline-bottom-scrollbar-rail`
- `timeline-horizontal-scrollbar-track`
- `timeline-horizontal-scrollbar-thumb`
- `timeline-horizontal-scrollbar-viewport`
- `timeline-frame-rows-scroll-body`
- `timeline-frame-row-area-<layerId>`
- `timeline-scrollable-body`
- `timeline-layer-rows-scroll-body`

## Long-term range semantics

The timeline must keep playback/export duration, visible display range, virtualized rendering windows, authored data extent, selected exposure visuals, scroll offset policy, and frame coordinate conversion separate.

Critical rules:

- `Cut.duration` is playback/export duration only.
- `Cut.duration` is not authored/data extent.
- `Cut.duration` is not the editability limit.
- `Cut.duration` is not the selected exposure outline limit.
- `TimelineController.authoredTimelineExtentFrameCount` is authored/data extent only.
- `authoredTimelineExtentFrameCount` must not be reintroduced into UI widgets as a visible range limit.
- The visible frame range is UI/display policy.
- The selected exposure outline is a display-range visual highlight.
- Authored frames beyond `Cut.duration` can exist.
- Editing beyond `Cut.duration` must not auto-extend `Cut.duration`.

Additional stabilization notes:

- The virtualized frame window is a rendering optimization, not a data or playback boundary.
- Ruler, body, selected exposure outline, and hit testing must share the same effective clamped horizontal offset.
- Frame coordinate helpers should remain pure conversions and should not embed playback, authored extent, or data semantics.

## Layer ordering semantics

Layer order must continue to distinguish raw model order from display order.

- Raw timeline layer order is `[A, B, C]`.
- Horizontal display order is reversed `[C, B, A]`.
- Vertical XSheet raw order remains `[A, B, C]`.
- New layer insertion is after active layer in raw order.
- Layer names may duplicate.
- Layer identity is by `LayerId`.

## Storyboard semantics relevant to timeline

Storyboard behavior is intentionally model-aligned and timeline-safe.

- Storyboard is represented as an ordinary `Layer(kind: storyboard)`.
- A cut may have at most one storyboard layer.
- `StoryboardPanel` is not a drawing canvas yet.
- `StoryboardPanel` must not own timeline range semantics.
- Storyboard layer strips may be shown in storyboard/conte surfaces, but they must not redefine timeline playback, authored extent, visible range, or selected exposure semantics.

## Protected test files

The following tests are important stabilization coverage and should be treated as protected unless a future phase explicitly changes the contract they cover.

- `test/ui/timeline_panel_smoke_test.dart` protects `TimelinePanel` smoke rendering, major structural keys, basic callback forwarding, frame/layer row keys, and playhead baseline.
- `test/ui/timeline_long_term_range_semantics_test.dart` protects long-term range rules: selected exposure display range, authored frames beyond playback duration, and avoiding authored extent as a selected-outline or UI visible range limit.
- `test/controllers/timeline_controller_responsibility_test.dart` protects controller responsibilities: current-frame cursor behavior, authored extent calculation from data, and preserving `Cut.duration` through timeline edits and read-only queries.
- `test/ui/layer_timeline_grid_extracted_composition_test.dart` protects extracted `LayerTimelineGrid` composition, scrollbar rail/slot structure, frame body containment, cut-end boundary placement, and playhead structure.
- `test/ui/storyboard_panel_smoke_test.dart` protects current storyboard panel surface keys, track/cut block display, cut duration/range labels, storyboard layer strip display, active cut indicator, cut selection callback, and empty storyboard layer state.

Do not weaken these tests to make unrelated timeline changes pass. If a future phase intentionally changes a protected key or semantic, update this checkpoint and the relevant handoff notes in the same phase.

## Manual verification checklist

Use this checklist after future timeline or storyboard-adjacent changes:

1. Open a project with at least one cut, multiple layers, and a known active layer.
2. Confirm the horizontal timeline renders layer controls, frame ruler/header, frame grid, playhead, cut-end boundary, and both scrollbar rails.
3. Confirm layer controls stay outside the horizontal frame scroll content.
4. Confirm horizontal scrolling keeps the ruler, body, selected exposure outline, hit testing, and playhead aligned after viewport resizing.
5. Confirm authored frames can exist beyond `Cut.duration` without changing playback/export duration.
6. Confirm editing beyond `Cut.duration` does not auto-extend `Cut.duration`.
7. Confirm selected exposure outline remains a display-range highlight and is not shortened by `authoredTimelineExtentFrameCount`.
8. Confirm raw layer order `[A, B, C]` displays horizontally as `[C, B, A]` while vertical XSheet order remains `[A, B, C]`.
9. Confirm adding a layer inserts after the active layer in raw order and therefore appears above the active layer in horizontal display.
10. Confirm duplicate layer names do not affect selection or identity; `LayerId` remains the identity.
11. Confirm a cut has at most one storyboard layer and the storyboard layer is still an ordinary `Layer(kind: storyboard)`.
12. Confirm `StoryboardPanel` remains a storyboard/conte overview, not a canvas or owner of timeline range semantics.

## Next recommended phases after handoff

After this checkpoint, avoid continuing timeline refactors unless a regression appears. Recommended next phases:

1. Storyboard / conte panel stabilization: stabilize storyboard panel structure, keys, and non-canvas timeline overview behavior.
2. 2D brush architecture: design the model/service boundaries for future bitmap brush work without adding rendering or canvas behavior prematurely.
3. Canvas / drawing implementation: begin actual drawing/canvas work only after brush architecture is explicit and stable.

Still out of scope for this checkpoint: production code changes, timeline UI widget changes, `TimelineController` changes, model changes, timeline semantics changes, canvas code, drawing code, brush engine code, stroke rendering, undo/redo, save/load, Provider/Riverpod/ChangeNotifier introduction, and `CustomPainter` usage.
