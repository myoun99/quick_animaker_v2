# Current Storyboard Architecture

## Protected model policy

- Storyboard is an ordinary `Layer` with `kind: storyboard`.
- A `Cut` may have at most one storyboard layer.
- The storyboard layer is included in `Cut.layers`.
- Do not add `Cut.storyboardLayer.panels`.
- Do not treat storyboard as a separate non-layer persistence system.

## Metadata ownership policy

- `CutMetadata` remains Cut-level note-only metadata.
- Do not add `actionMemo` or `dialogueMemo` to `CutMetadata`.
- Storyboard action/dialogue/note fields belong to `Frame.storyboardMetadata`.
- `Frame.storyboardMetadata` belongs to ordinary `Frame` data inside a `Layer(kind: storyboard)`.
- Storyboard metadata ownership must not introduce a separate storyboard persistence tree.

## Panel role

`StoryboardPanel` is a project/cut overview and planning surface, not a drawing canvas. Do not wire brush drawing into `StoryboardPanel` unless a future current document explicitly changes this policy.

`StoryboardPanel` should help users inspect and plan cuts, tracks, and storyboard-layer presence. It should not own timeline range semantics, and it should not mutate `Project` during layout/read operations.

## Storyboard panel segmentation direction

Long-term storyboard panel segmentation should be derived from ordinary storyboard-layer timeline data rather than stored in a separate panel tree.

- A storyboard layer's drawing heads / authored exposure heads may become the source for storyboard panel divisions.
- Panel cards, thumbnails, and export panels should be read models derived from `Layer(kind: storyboard)` frames, exposures, and `Frame.storyboardMetadata`.
- Do not add manually persisted `Cut.storyboardLayer.panels` as a shortcut for panel segmentation.
- Do not introduce a separate storyboard panel persistence model that can diverge from the storyboard layer timeline.
- Future storyboard export should initially derive panel images from storyboard-layer drawing heads / authored storyboard exposures.
- Any future manual panel-editing UI must still preserve storyboard-as-layer ownership unless a future current document explicitly changes this policy.

## Storyboard / timeline audio linkage direction

Future storyboard audio presentation and timeline audio playback should share the same project audio/sound source model rather than duplicating audio data inside `StoryboardPanel`.

- `StoryboardPanel` may eventually show audio strips, sound notes, dialogue timing, or overview audio cues.
- Those storyboard audio views should be derived from the same project track/layer/audio source model used by timeline playback.
- Do not add storyboard-only audio persistence that can diverge from the timeline/project audio source of truth.
- Final audio model, sound layer kinds, and save/load representation are deferred to future current architecture updates.

## Long-term multi-track overview direction

Long-term `StoryboardPanel` direction is a Premiere Pro / DaVinci Resolve-like multi-track overview, while still remaining an overview/planning surface rather than a drawing canvas.

- `Project.tracks` represent V1/V2/V3-like tracks.
- Tracks contain Cut blocks.
- A Cut block spans the Cut duration.
- If a Cut has a storyboard layer, `StoryboardPanel` may show that storyboard layer's head/exposure strip inside the Cut block.
- Reuse existing timeline primitives and layout logic when possible instead of creating a completely separate storyboard-specific timeline engine.
- This direction must preserve storyboard-as-layer policy and must not introduce `Cut.storyboardLayer.panels`.

## Export direction

- Basic storyboard export should default to Primary Track only.
- Selected-track export is a future optional feature, not the default.
- Composite output across tracks/layers is a future optional feature, not the default.
- Export behavior must preserve storyboard-as-layer semantics unless a future current document explicitly changes this policy.
- `StoryboardExportPlan` should be derived from `Project` data and must not mutate `Project`.

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
