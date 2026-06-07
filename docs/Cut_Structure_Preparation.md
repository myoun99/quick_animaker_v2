# Cut Structure Preparation

## Current State

The current app effectively behaves around one active cut/timeline editing context.

The original architecture already includes this hierarchy:

```text
Project -> Track -> Cut -> Layer -> Frame -> Stroke
```

However, full multi-cut editing should not be assumed to exist yet. Current timeline, layer, canvas, save/load, undo/redo, and UI behavior should be treated as the stabilized single-cut workflow until future phases explicitly introduce active Cut state and cut switching.

See [Cut Structure Audit](Cut_Structure_Audit.md) for the current codebase audit before active Cut implementation.

## Target Direction

The next architecture direction should be:

- Stabilize the current single-cut timeline workflow first.
- Prepare for multiple cuts.
- Add cut selection/switching UI after the data flow is ready.
- Add Storyboard Panel only after Cut switching is stable.

This phase documents the direction only. It does not add model changes, active Cut state, Cut switching UI, Storyboard Panel, or new layer types.

## Important Constraint

Even if linked layers or linked materials are introduced later, timeline placement must remain independent per cut.

This applies to future linked-layer ideas too:

- Linked Layer should share material/source or layer identity, not necessarily timing.
- Cut-specific timing and timeline placement should remain independent.
- Cross-cut linked material should not imply cross-cut linked timing.
- Cross-layer linked material should not imply shared selected cell state, blank/X position, mark position, or authored exposure duration.

The existing linked-frame policy should guide future Cut work: shared material/source is separate from timeline placement.

## Recommended Implementation Order

Recommended order for future phases:

1. Document product direction.
2. Inspect existing Cut usage in models/controllers/services.
3. Ensure current timeline operations are scoped to the active Cut.
4. Add active Cut selection state.
5. Add minimal Cut list/switching UI.
6. Only then consider Storyboard Panel MVP.

Phase 25 covers only item 1.

## Cut Model Direction

Each Cut should own or resolve:

- `CutId`
- Cut name
- Canvas size
- Layers
- Duration

Future Cut-level concepts may include:

- Start position on global track timeline
- Thumbnail/representative frame
- Storyboard metadata
- Audio references

Do not implement those concepts in this phase.

## Timeline Direction

The timeline panel should continue to edit the active cut.

Do not introduce global multi-cut timeline editing yet. Global track/cut editing should be a later phase after the active Cut concept and Cut switching workflow are stable.

Timeline behavior should preserve these policies as Cut work begins:

- Timeline placement belongs to the active cut and authored timeline entries.
- Authored exposure duration belongs to the selected authored timeline entry.
- `+ Exposure` and `- Exposure` operate on the selected authored timeline entry, not every use of the same `FrameId`.
- Linked frames share `FrameId`, strokes/material, and frame name.
- Linked frames do not share timeline placement, authored exposure duration, mark position, blank/X position, or selected cell state.

## Storyboard Direction

The current long-term idea is that Storyboard Panel should likely come after Cut selection/switching UI.

A Storyboard Layer may later generate storyboard panels based on its drawings.

Current constraints:

- Storyboard Layer is not implemented yet.
- Storyboard Panel is not implemented yet.
- Camera Layer is not implemented yet.
- Audio Layer is not implemented yet.
- Linked Layer is not implemented yet.
- No model changes for Storyboard Layer should be made in this phase.
- No active Cut state or Cut switching UI should be added in this phase.

## Risks to Avoid

Future Cut and Storyboard work should avoid these risks:

- Do not rush into cross-cut linked paste.
- Do not introduce a project-level material pool without a careful design.
- Do not make timeline placement shared by linked materials.
- Do not make linked layers share timing by default.
- Do not add UI complexity before the active Cut concept is stable.
- Do not add long tutorial text to the UI.
- Do not add active Cut state as an incidental side effect of documentation or UI polish work.
- Do not add Cut switching UI before the model/controller/service data flow is ready.
- Do not implement Storyboard Panel, Storyboard Layer, Camera Layer, Audio Layer, Linked Layer, cross-layer linked paste, or cross-cut linked paste before their dedicated phases.
