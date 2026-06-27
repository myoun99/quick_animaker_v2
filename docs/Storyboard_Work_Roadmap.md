# Storyboard Work Roadmap

## Status

StoryboardPanel already exists and has stable smoke/interaction tests.

The next work area should improve StoryboardPanel carefully without destabilizing TimelinePanel or Brush V1.

## Protected existing semantics

- Storyboard is represented as an ordinary Layer with kind storyboard.
- A Cut may have at most one storyboard layer.
- Storyboard layers are included in Cut.layers.
- StoryboardPanel is a project overview / cut planning surface, not the drawing canvas.
- Do not add a separate Cut.storyboardLayer.panels model.
- Do not treat storyboard as a separate non-layer system.

## Protected stable keys

List these protected keys exactly:

- storyboard-panel
- storyboard-track-row-<trackId>
- storyboard-track-timeline-area-<trackId>
- storyboard-cut-block-<cutId>
- storyboard-cut-positioned-<cutId>
- storyboard-layer-strip-<cutId>
- storyboard-layer-empty-<cutId>
- storyboard-cut-active-indicator-<cutId>
- storyboard-timeline-horizontal-viewport

## Protected tests

Mention that these tests must remain passing:

- test/ui/storyboard_panel_smoke_test.dart
- test/ui/storyboard_panel_interaction_test.dart
- timeline semantics tests
- brush canvas tests

## Storyboard work principles

- Do not refactor TimelinePanel unless a test-proven issue requires it.
- Do not change layer ordering semantics.
- Do not change Cut.duration semantics.
- Do not introduce brush drawing into StoryboardPanel yet.
- Do not wire BrushCanvasSmokeScreen into StoryboardPanel.
- Do not create a separate storyboard persistence model yet.
- Keep changes incremental and test-driven.

## Candidate next phases

Propose a conservative next sequence:

1. Storyboard current-state audit and guard tests.
2. Storyboard selection / active cut interaction polish.
3. Storyboard cut block layout stability.
4. Storyboard layer strip metadata display.
5. Storyboard empty-state and edge-case regression tests.
6. Storyboard-to-canvas handoff planning, without wiring brush UI yet.

## Out of scope for the next Storyboard phase

- Actual canvas drawing inside StoryboardPanel.
- Brush engine integration.
- Save/load.
- Renderer/cache integration.
- Timeline virtualization.
- Layer panel rewrite.
- App-wide state management package.
