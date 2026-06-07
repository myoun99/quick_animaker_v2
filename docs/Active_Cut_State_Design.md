# Active Cut State Design

## Summary Decision

Active Cut state should be explicit, but it should initially remain a lightweight application/session/controller-level selection, not a persistence-layer responsibility.

The first implementation should keep active Cut selection near the UI/controller boundary rather than inside `ProjectRepository`:

- `ProjectRepository` stores and mutates project data.
- Active Cut selection is app/session state.
- Controllers should be constructed with or intentionally receive the active `CutId`.
- Timeline, layer, and canvas editing should be scoped to the active `CutId`.
- Cut switching UI should come after active Cut scoping is implemented and tested.

This keeps the current single-cut workflow stable while making the implicit editing target explicit before runtime multi-cut work begins.

## Current State

The Phase 26 audit found that the data model already has a `Project -> Track -> Cut -> Layer -> Frame -> Stroke` hierarchy, but the running app still behaves around one implicit active cut:

- `HomePage` currently uses a hard-coded sample `CutId`.
- `LayerController` and `TimelineController` are constructed with one `CutId`.
- `CanvasView` receives one `CutId`.
- `TimelinePanel` is cut-agnostic and receives a layer list, active layer id, and current frame index.
- There is no active Cut selection state above controllers.
- There is no Cut switching UI.

That is acceptable for the current single-cut workflow, but it should not remain implicit once multiple cuts can be edited at runtime.

## Recommended Ownership

Active Cut state should not be stored directly inside the immutable `Project` model unless there is a strong persistence reason in a later phase. The selected Cut is UI/session context, not project content.

Recommended initial ownership:

- `HomePage` may own `activeCutId` at first.
- Alternatively, a small dedicated session/controller state object may own `activeCutId`.
- Do not introduce Provider, Riverpod, Bloc, or complex app-wide state management yet.

Potential future direction:

- A future `ProjectSessionController` or `EditingSessionController` may own selected `TrackId`, `CutId`, `LayerId`, and `FrameId` UI state.
- That future session object should still remain separate from project persistence and project data mutation responsibilities.

Phase 27 does not implement any of this ownership. It only documents the design direction.

## Controller Direction

Controllers should remain small and should not become God Objects.

Recommended future direction:

- `LayerController` should be scoped to the active `CutId`.
- `TimelineController` should be scoped to the active `CutId`.
- `CanvasController` should resolve drawing targets through the active `LayerController` and/or `TimelineController` context.
- When the active Cut changes, controllers may be rebuilt or retargeted in a small explicit way.
- Controller construction should make the active `CutId` visible rather than relying on hidden globals or repository-wide searches.

The next implementation should avoid changing every controller at once unless tests are added first. A safe path is to preserve existing single-cut behavior, make the current cut explicit, then add isolation tests before broader refactors.

## Repository Direction

`ProjectRepository` should remain focused on project data mutations, not UI selection.

Recommended future direction:

- Repository methods that mutate layers or frames should eventually be made cut-aware or otherwise guaranteed safe by project-wide unique IDs.
- Existing methods that update by `LayerId` or `FrameId` across all tracks/cuts should be treated as risky before multi-cut editing.
- A future phase should decide whether to add `CutId` parameters to edit commands/repository methods where that clarifies intent.
- Repository methods may validate that an expected `CutId`, `LayerId`, or `FrameId` relationship exists before applying a mutation.

Even if IDs are project-wide unique, edit APIs should still carry enough active Cut context to avoid ambiguous behavior and make the caller's intent clear.

## UI Direction

The first active-cut implementation should not add a full Cut switching UI yet.

Recommended UI direction:

- Preserve the existing single-cut workflow.
- Make the active cut explicit internally.
- Add tests proving behavior is unchanged.
- Add Cut list/switching UI only after active-cut scoping is stable.

Cut switching should be introduced only after the model/controller/service data flow can prove that layer, frame, timeline, canvas, and selection edits target the intended cut.

## Save / Load Direction

Active Cut selection is session/UI state, not project content, at least initially.

After load, the app can default to one deterministic active cut, such as:

- the first available video cut, or
- a deterministic existing sample cut when using the sample project.

The active Cut selection should not be saved into the project JSON schema unless a later phase intentionally designs persistent workspace/session state. Phase 27 does not change save/load behavior or schema.

## Undo / Redo Direction

Undo/redo commands should not implicitly change active Cut selection unless that behavior is explicitly designed later.

Future risk to note:

- Undo/redo after cut switching may require cut-aware selection restoration or separate UI-state handling.
- Command history may need to know the cut context for edits even if active selection itself remains session state.
- Replaying or reverting a command should mutate project data in the intended cut without silently retargeting to the current visible cut.

Phase 27 does not change undo/redo behavior.

## Non-Goals

This phase does not implement:

- Active Cut state
- Cut switching UI
- Multiple Cut editing UI
- Storyboard Panel
- Storyboard Layer
- Camera Layer
- Audio Layer
- Linked Layer
- Cross-cut paste
- Cross-layer paste
- Project-level material pool
- Provider/Riverpod/Bloc
- Runtime behavior changes
- Model, controller, service, repository, command, UI, save/load, undo/redo, timeline, canvas, renderer, or brush-engine changes

## Recommended Implementation Steps

Recommended future order:

1. Add minimal `activeCutId` session state while preserving current behavior.
2. Add tests proving the default active cut is deterministic.
3. Ensure `LayerController` and `TimelineController` are explicitly scoped to `activeCutId`.
4. Add tests for two cuts with independent layers/timelines.
5. Make repository/controller edit paths cut-aware where needed.
6. Only then add minimal Cut switching UI.
7. Defer Storyboard Panel until Cut switching is stable.

Throughout this sequence, timeline placement must remain independent per cut. Linked frames may share material/source identity, but not timing, placement, marks, blank/X position, or selected cell state.
