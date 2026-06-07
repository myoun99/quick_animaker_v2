# Phase 27 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 27: Active Cut State & ID Scope Design Notes.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 26 are complete.

Recent completed work includes:

* TimelinePanel-based timeline/cell editing UI
* New Frame / Blank X / Mark ● / Rename / Delete / Exposure +/- actions
* Timeline marks
* X/null exposure
* Linked Frame Copy/Paste MVP
* Same-layer linked paste using shared `FrameId`
* Linked frames share drawing material/source but do not share exposure duration
* Exposure +/- operates on the selected authored timeline entry, not globally by `FrameId`
* Rename conflict policy:

    * Same frame name means same material
    * Same-layer duplicate independent `FrameId`s with the same non-empty name should not be allowed
    * Conflict offers Link / Cancel only
    * Rename-only is intentionally not offered
* Compact production-tool-like timeline UI
* Product direction notes
* Cut structure preparation notes
* Cut structure audit notes

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Phase_26_Codex_Task.md
```

This task implements only Phase 27.

---

## Scope

Implement only:

```text
Phase 27: Active Cut State & ID Scope Design Notes
```

This is a documentation/design phase.

The goal is to decide and document how active Cut state and ID scope should work before any runtime implementation.

This phase should not change runtime behavior.

The main output should be:

```text
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
```

Optionally, this task may add a small reference link to:

```text
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
```

Only add short links if useful.

Do not rewrite existing documents.

---

## Why This Phase Exists

Phase 26 identified that the app currently has a structural `Project -> Track -> Cut -> Layer -> Frame -> Stroke` hierarchy, but the runtime editing workflow still behaves around one implicit active cut.

Before adding active Cut state, Cut switching UI, multiple Cut editing, or Storyboard Panel work, the project needs two explicit design decisions:

```text
1. Where active Cut state should live.
2. How CutId / LayerId / FrameId identity scope should be treated.
```

Without this, future implementation could accidentally:

* make timeline placement shared across cuts,
* mutate the wrong layer/frame if ids are reused,
* make linked material behavior ambiguous,
* add Cut UI before the controller/repository flow is ready,
* mix active cut selection with global project persistence responsibilities.

---

## Required Output A

Create:

```text
docs/Active_Cut_State_Design.md
```

This document must include at least these sections:

```text
# Active Cut State Design

## Summary Decision

## Current State

## Recommended Ownership

## Controller Direction

## Repository Direction

## UI Direction

## Save / Load Direction

## Undo / Redo Direction

## Non-Goals

## Recommended Implementation Steps
```

### Summary Decision

Document this recommended decision:

```text
Active Cut state should be explicit, but should initially remain a lightweight application/controller-level selection, not a persistence-layer responsibility.
```

The first implementation should probably keep active Cut selection near the UI/controller boundary, not inside `ProjectRepository`.

Recommended direction:

```text
- ProjectRepository stores and mutates project data.
- Active Cut selection is app/session state.
- Controllers should be constructed with or receive the active CutId intentionally.
- Timeline/layer/canvas editing should be scoped to the active CutId.
- Cut switching UI should come after active Cut scoping is tested.
```

### Current State

Summarize the current state from the audit:

```text
- HomePage currently uses a hard-coded sample CutId.
- LayerController and TimelineController are constructed with one CutId.
- CanvasView receives one CutId.
- TimelinePanel is cut-agnostic and receives a layer list.
- There is no active Cut selection state above controllers.
- There is no Cut switching UI.
```

### Recommended Ownership

Document that active Cut state should not be stored directly inside the immutable `Project` model unless there is a strong persistence reason later.

Recommended initial ownership:

```text
HomePage or a small dedicated controller/state object may own activeCutId initially.
```

Important:

```text
Do not introduce Provider, Riverpod, Bloc, or complex app-wide state management yet.
```

Potential future direction:

```text
A future ProjectSessionController or EditingSessionController may own selected Track/Cut/Layer/Frame UI state.
```

But do not implement it in this phase.

### Controller Direction

Document that controllers should remain small and avoid becoming God Objects.

Recommended future direction:

```text
- LayerController should be scoped to the active CutId.
- TimelineController should be scoped to the active CutId.
- CanvasController should resolve drawing targets through the active LayerController/TimelineController.
- When active Cut changes, controllers may be rebuilt or retargeted in a small explicit way.
```

Document that the next implementation should avoid changing every controller at once unless tests are added first.

### Repository Direction

Document that `ProjectRepository` should remain focused on project data mutations, not UI selection.

Recommended future direction:

```text
- Repository methods that mutate layers/frames should eventually be made cut-aware or otherwise guaranteed safe by project-wide unique IDs.
- Existing methods that update by LayerId or FrameId across all cuts should be treated as risky before multi-cut editing.
- A future phase should decide whether to add CutId parameters to edit commands/repository methods.
```

### UI Direction

Document that the first active-cut implementation should not add a full Cut switching UI yet.

Recommended UI direction:

```text
- Preserve the existing single-cut workflow.
- Make the active cut explicit internally.
- Add tests proving behavior is unchanged.
- Add Cut list/switching UI only after active-cut scoping is stable.
```

### Save / Load Direction

Document:

```text
Active Cut selection is session/UI state, not project content, at least initially.
```

After load, the app can default to:

```text
- the first available video cut, or
- a deterministic existing sample cut when using the sample project.
```

Do not implement this in Phase 27.

### Undo / Redo Direction

Document that undo/redo commands should not implicitly change active Cut selection unless explicitly designed later.

Future risk to note:

```text
Undo/redo after cut switching may require cut-aware selection restoration or UI-state handling.
```

Do not implement this in Phase 27.

### Non-Goals

Explicitly state that this phase does not implement:

```text
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
```

### Recommended Implementation Steps

Recommend this future order:

```text
1. Add minimal activeCutId session state while preserving current behavior.
2. Add tests proving the default active cut is deterministic.
3. Ensure LayerController and TimelineController are explicitly scoped to activeCutId.
4. Add tests for two cuts with independent layers/timelines.
5. Make repository/controller edit paths cut-aware where needed.
6. Only then add minimal Cut switching UI.
7. Defer Storyboard Panel until Cut switching is stable.
```

---

## Required Output B

Create:

```text
docs/Id_Scope_Decision.md
```

This document must include at least these sections:

```text
# ID Scope Decision

## Summary Decision

## Current Risk

## Recommended Policy

## CutId

## LayerId

## FrameId

## StrokeId

## Timeline Exposure References

## Linked Frame Implications

## Repository / Command Implications

## Test Implications

## Non-Goals
```

### Summary Decision

Document this recommended decision:

```text
IDs should be treated as project-wide unique values, but edit APIs should still carry enough active Cut context to prevent ambiguous behavior and make intent clear.
```

This is the main Phase 27 design decision.

The reasoning:

```text
- Project-wide unique IDs reduce accidental collisions.
- Explicit active Cut context makes controller/repository behavior easier to reason about.
- Even with globally unique IDs, timeline placement must remain cut-local.
- Linked material/source sharing must remain separate from timing/timeline placement.
```

### Current Risk

Document the Phase 26 audit risk:

```text
Some repository and command methods currently update by LayerId or FrameId while searching across all tracks/cuts.
```

This is acceptable in the current single-cut workflow, but risky before multi-cut editing unless IDs are globally unique and/or edit APIs are made cut-aware.

### Recommended Policy

Document:

```text
- CutId should be unique within the project.
- LayerId should be treated as unique within the project.
- FrameId should be treated as unique within the project.
- StrokeId should be treated as unique within the project or at least unique enough to avoid collision within saved project data.
- Timeline placement remains local to a Layer within a Cut.
- FrameId sharing means shared material/source, not shared timing.
```

### CutId

Document:

```text
CutId identifies a cut in the project.
```

Future active-cut state should store a `CutId`.

### LayerId

Document:

```text
LayerId should be project-wide unique.
```

Even if project-wide unique, layer edits should still be routed through active Cut context when possible.

### FrameId

Document:

```text
FrameId should be project-wide unique as a material/source identity.
```

Important linked-frame policy:

```text
Multiple authored timeline entries may reference the same FrameId.
That means linked uses of the same material/source.
It does not mean shared exposure duration, timeline placement, mark position, blank/X position, or selected cell state.
```

### StrokeId

Document that StrokeId is a drawing action identity.

Do not introduce new stroke storage behavior.

### Timeline Exposure References

Document:

```text
TimelineExposure.drawing references a FrameId.
The exposure entry belongs to a Layer timeline.
The Layer belongs to a Cut.
Therefore, exposure placement is cut/layer-local even when the FrameId is shared.
```

### Linked Frame Implications

Document all current linked-frame rules:

```text
- Linked frames share FrameId.
- Linked frames share strokes/material/source.
- Linked frames share frame name.
- Linked frames do not share timeline placement.
- Linked frames do not share authored exposure duration.
- Linked frames do not share mark position.
- Linked frames do not share blank/X position.
- Linked frames do not share selected cell state.
```

### Repository / Command Implications

Document that future implementation should consider:

```text
- adding CutId to edit commands where it clarifies intent,
- making repository update paths validate the expected cut/layer/frame location,
- keeping project-wide unique ids as a safety layer,
- adding tests that prove one cut cannot accidentally mutate another cut.
```

Do not implement those changes in this phase.

### Test Implications

Document future tests needed:

```text
- Two cuts with distinct LayerIds and FrameIds.
- Two cuts with intentionally similar names but different ids.
- Active Cut edits only the selected cut.
- Linked frames within a layer preserve material sharing but independent timing.
- Future cross-cut linked material tests only after that feature is designed.
```

### Non-Goals

Explicitly state that this phase does not implement:

```text
- ID generation refactor
- Repository API changes
- Command API changes
- Active Cut state
- Cut switching UI
- Global material pool
- Cross-cut linked paste
- Cross-layer linked paste
```

---

## Optional Small Link Updates

Optionally add short links to existing docs:

In `docs/Cut_Structure_Audit.md`, a short reference may be added near the recommended next phase:

```text
See docs/Active_Cut_State_Design.md and docs/Id_Scope_Decision.md for Phase 27 design decisions.
```

In `docs/Cut_Structure_Preparation.md`, a short reference may be added near the audit link:

```text
See docs/Active_Cut_State_Design.md and docs/Id_Scope_Decision.md for active Cut and ID scope direction.
```

Do not rewrite existing docs.

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Runtime behavior changes
- Model schema changes
- ID generation changes
- Controller behavior changes
- Service behavior changes
- Repository API changes
- Command API changes
- UI behavior changes
- JSON schema changes
- Save/load format changes
- Undo/Redo behavior changes
- Timeline behavior changes
- Canvas behavior changes
- Renderer changes
- Brush engine changes
- Tests
- New buttons
- New dialogs
- New app state
- Active Cut state
- Cut switching UI
- Multiple Cut editing UI
- Storyboard Panel
- Storyboard Layer
- Camera Layer
- Audio Layer
- Layer type enum
- Linked Layer
- Cross-layer paste
- Cross-cut paste
- Project-level material pool
- Provider
- Riverpod
- Bloc
- Complex app-wide state management
```

Do not implement Phase 28 or later.

This phase must stay focused on design documentation.

---

## Files To Add

Add:

```text
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
```

Optional minimal updates:

```text
docs/Cut_Structure_Audit.md
docs/Cut_Structure_Preparation.md
```

Only add short reference links if useful.

---

## Tests

Because this phase should be documentation-only, no new tests are required.

However, after the docs are added, run:

```bash
flutter analyze
flutter test
git status
```

Do not run `dart format` on Markdown files.

If formatting Dart files is necessary for any reason, use only:

```bash
dart format lib test
```

But this phase should not require Dart formatting because no Dart code should be changed.

---

## Completion Criteria

This phase is complete only when:

```text
1. docs/Active_Cut_State_Design.md exists.
2. docs/Id_Scope_Decision.md exists.
3. Active Cut state ownership is documented.
4. The decision not to store active Cut selection in ProjectRepository is documented.
5. Controller/repository/UI direction for active Cut is documented.
6. ID scope policy is documented.
7. Project-wide unique ID direction is documented.
8. The need for active Cut context even with project-wide unique IDs is documented.
9. Linked-frame timing/material separation is preserved in the docs.
10. No runtime code is changed.
11. No model/controller/service/repository/UI behavior is changed.
12. No tests are changed.
13. flutter analyze passes.
14. flutter test passes.
15. git status shows only intended documentation changes before commit, and clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 27 Active Cut State & ID Scope Design docs.

Added:
- docs/Active_Cut_State_Design.md
- docs/Id_Scope_Decision.md

Optional updated:
- docs/Cut_Structure_Audit.md
- docs/Cut_Structure_Preparation.md

No runtime behavior was changed.

Validation:
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_27_Codex_Task.md` and implement Phase 27 only. This is a docs-only design phase. Add `docs/Active_Cut_State_Design.md` and `docs/Id_Scope_Decision.md` to document how active Cut state should be owned and how `CutId`, `LayerId`, `FrameId`, and `StrokeId` should be scoped before runtime multi-cut work begins. Do not change runtime code, models, controllers, services, repository APIs, command APIs, UI behavior, JSON schema, save/load, undo/redo, timeline behavior, tests, active Cut state, Cut switching UI, Storyboard Panel, or Phase 28+ work. Run `flutter analyze`, `flutter test`, and `git status`.
