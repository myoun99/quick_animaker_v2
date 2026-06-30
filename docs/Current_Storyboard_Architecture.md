# Current Storyboard Architecture

## Model rule

Storyboard is represented as an ordinary layer, not as a separate storyboard-only content model.

```text
Cut.layers
  Layer(kind: LayerKind.storyboard)
    frames
    timeline
    Frame.storyboardMetadata
```

Rules:

- Do not add `Cut.storyboardPanel`, `Cut.storyboardLayer.panels`, or an independent storyboard-panel model.
- A Cut may have at most one storyboard layer.
- StoryboardPanel is a project overview / cut planning surface, not the drawing canvas.
- Opening StoryboardPanel must not automatically create a storyboard layer. Creating one is an explicit user action.

## StoryboardPanel behavior

- The primary visual unit is a Cut block.
- Cut block width is based on `Cut.duration`.
- Project tracks are shown as V1, V2, and similar project-level lanes, not animation cel layers.
- If a Cut has a storyboard layer, the panel displays its storyboard strip inside the Cut block.
- If no storyboard layer exists, the Cut block remains visible with an empty/subtle placeholder state.

## Protected stable keys

- `storyboard-panel`
- `storyboard-track-row-<trackId>`
- `storyboard-track-timeline-area-<trackId>`
- `storyboard-cut-block-<cutId>`
- `storyboard-cut-positioned-<cutId>`
- `storyboard-layer-strip-<cutId>`
- `storyboard-layer-empty-<cutId>`
- `storyboard-cut-active-indicator-<cutId>`
- `storyboard-timeline-horizontal-viewport`

## Protected tests and principles

- Keep storyboard smoke and interaction tests passing.
- Do not refactor TimelinePanel unless a test-proven issue requires it.
- Do not change layer ordering or `Cut.duration` semantics.
- Do not wire brush drawing into StoryboardPanel yet.
- Do not create separate storyboard persistence yet.
- Keep StoryboardPanel work incremental and test-driven.
