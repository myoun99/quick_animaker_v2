# ID Scope Decision

## Summary Decision

IDs should be treated as project-wide unique values, but edit APIs should still carry enough active Cut context to prevent ambiguous behavior and make intent clear.

This is the Phase 27 identity-scope decision:

- Project-wide unique IDs reduce accidental collisions.
- Explicit active Cut context makes controller/repository behavior easier to reason about.
- Even with globally unique IDs, timeline placement must remain cut-local.
- Linked material/source sharing must remain separate from timing and timeline placement.

This policy prepares the app for runtime multi-cut work without changing runtime code, schemas, repositories, commands, tests, or UI in Phase 27.

## Current Risk

The Phase 26 audit found that some repository and command paths currently update by `LayerId` or `FrameId` while searching across all tracks/cuts.

That is acceptable in the current single-cut workflow, but it becomes risky before multi-cut editing unless:

- IDs are treated as project-wide unique values, and/or
- edit APIs are made cut-aware enough to validate and express the intended target.

The risk is not only accidental ID collision. It is also ambiguous intent: an edit made while one cut is active should not silently affect another cut just because a broad search finds a matching ID elsewhere.

## Recommended Policy

Recommended ID and placement policy:

- `CutId` should be unique within the project.
- `LayerId` should be treated as unique within the project.
- `FrameId` should be treated as unique within the project.
- `StrokeId` should be treated as unique within the project or at least unique enough to avoid collision within saved project data.
- Timeline placement remains local to a `Layer` within a `Cut`.
- `FrameId` sharing means shared material/source, not shared timing.
- Edit APIs should carry enough active Cut context even when IDs are project-wide unique.

Project-wide unique IDs are a safety layer, not a replacement for explicit editing context.

## CutId

`CutId` identifies a cut in the project.

Future active-cut state should store a `CutId`. That selected `CutId` should define the cut context for layer, timeline, canvas, and related editing operations.

`CutId` should not be inferred from unrelated UI state when an explicit active cut is available.

## LayerId

`LayerId` should be project-wide unique.

Even if `LayerId` values are project-wide unique, layer edits should still be routed through active Cut context when possible. This makes it clear that a layer edit is intended for the selected cut and lets future code validate that the layer belongs to the expected cut.

Layer names may be similar or identical across cuts, but layer identity should remain ID-based.

## FrameId

`FrameId` should be project-wide unique as a material/source identity.

Linked-frame policy:

- Multiple authored timeline entries may reference the same `FrameId`.
- Sharing a `FrameId` means linked uses of the same material/source.
- Sharing a `FrameId` does not mean shared exposure duration.
- Sharing a `FrameId` does not mean shared timeline placement.
- Sharing a `FrameId` does not mean shared mark position.
- Sharing a `FrameId` does not mean shared blank/X position.
- Sharing a `FrameId` does not mean shared selected cell state.

Frame names are part of current linked material/source behavior: linked frames share the frame name because they share the same underlying frame identity.

## StrokeId

`StrokeId` is a drawing action identity.

Stroke IDs should be treated as project-wide unique or at least unique enough to avoid collision within saved project data. Phase 27 does not introduce new stroke storage behavior, new stroke identity behavior, or any stroke schema changes.

## Timeline Exposure References

`TimelineExposure.drawing` references a `FrameId`.

The exposure entry belongs to a layer timeline. The layer belongs to a cut. Therefore, exposure placement is cut/layer-local even when the referenced `FrameId` is shared.

This distinction is critical:

- `FrameId` identifies material/source.
- `Layer.timeline` owns authored placement and exposure entries.
- The containing `Cut` scopes that layer timeline.

As a result, two uses of one `FrameId` can share drawing material while keeping separate timing and placement.

## Linked Frame Implications

Current linked-frame rules to preserve:

- Linked frames share `FrameId`.
- Linked frames share strokes/material/source.
- Linked frames share frame name.
- Linked frames do not share timeline placement.
- Linked frames do not share authored exposure duration.
- Linked frames do not share mark position.
- Linked frames do not share blank/X position.
- Linked frames do not share selected cell state.

These rules should remain true as Cut work begins. Cross-cut linked material behavior should not be assumed until it is separately designed.

## Repository / Command Implications

Future implementation should consider:

- adding `CutId` to edit commands where it clarifies intent,
- making repository update paths validate the expected cut/layer/frame location,
- keeping project-wide unique IDs as a safety layer,
- adding tests that prove one cut cannot accidentally mutate another cut.

Repository and command APIs should avoid ambiguous broad searches once runtime multi-cut editing starts. If a method mutates a layer, frame, exposure, mark, or stroke as part of an active editing workflow, the method or its caller should know enough context to explain which cut the edit belongs to.

Phase 27 does not implement those changes.

## Test Implications

Future tests needed before or during active Cut implementation:

- Two cuts with distinct `LayerId`s and `FrameId`s.
- Two cuts with intentionally similar names but different IDs.
- Active Cut edits only the selected cut.
- Linked frames within a layer preserve material sharing but independent timing.
- Future cross-cut linked material tests only after that feature is designed.

Tests should verify both safety properties:

- Project-wide unique IDs prevent accidental collision.
- Active Cut context prevents ambiguous editing behavior and accidental cross-cut mutation.

## Non-Goals

This phase does not implement:

- ID generation refactor
- Repository API changes
- Command API changes
- Active Cut state
- Cut switching UI
- Global material pool
- Cross-cut linked paste
- Cross-layer linked paste
- Runtime behavior changes
- Model, controller, service, repository, command, UI, JSON schema, save/load, undo/redo, timeline, canvas, renderer, brush-engine, or test changes
