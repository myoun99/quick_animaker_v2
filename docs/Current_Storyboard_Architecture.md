# Current Storyboard Architecture

## Protected model policy

- Storyboard is an ordinary `Layer` with `kind: storyboard`.
- A `Cut` may have at most one storyboard layer.
- The storyboard layer is included in `Cut.layers`.
- Do not add `Cut.storyboardLayer.panels`.
- Do not treat storyboard as a separate non-layer persistence system.

## Panel role

`StoryboardPanel` is a project/cut overview and planning surface, not a drawing canvas. Do not wire brush drawing into `StoryboardPanel` unless a future current document explicitly changes this policy.

`StoryboardPanel` should help users inspect and plan cuts, tracks, and storyboard-layer presence. It should not own timeline range semantics, and it should not mutate `Project` during layout/read operations.

## Export direction

- Basic storyboard export should default to Primary Track only.
- Selected-track export is a future optional feature, not the default.
- Composite output across tracks/layers is a future optional feature, not the default.
- Export behavior must preserve storyboard-as-layer semantics unless a future current document explicitly changes this policy.

## Future direction

Track-based board view is a future direction. It should remain an overview/planning surface and should not redefine timeline playback duration, authored data extent, canvas/cache/storage validity, or brush editing ownership.

## Stability rules

- Do not refactor `TimelinePanel` for storyboard work unless a test-proven issue requires it.
- Do not change layer ordering semantics.
- Do not change `Cut.duration` semantics.
- Keep storyboard changes incremental and test-driven.
- Preserve stable UI keys used by tests.

## Protected UI keys

The storyboard surface should preserve stable keys used by tests, including `storyboard-panel`, track rows, cut blocks, storyboard layer strips, active cut indicators, and the horizontal viewport keys.
