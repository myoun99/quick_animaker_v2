# Phase 26 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 26: Cut Structure Audit & Active Cut Preparation Notes.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 25 are complete.

Current completed foundation includes:

```text
lib/main.dart
lib/src/models/
lib/src/services/
lib/src/controllers/
lib/src/ui/
lib/src/ui/canvas/
lib/src/ui/timeline/
test/models/
test/services/
test/controllers/
test/ui/
docs/
```

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

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_25_Codex_Task.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
```

This task implements only Phase 26.

---

## Scope

Implement only:

```text
Phase 26: Cut Structure Audit & Active Cut Preparation Notes
```

This is primarily a codebase audit and documentation phase.

The goal is to inspect the existing code and document how `Cut` is currently represented, accessed, assumed, or bypassed before introducing active Cut state or multiple Cut UI.

This phase should not change runtime behavior.

The main output should be:

```text
docs/Cut_Structure_Audit.md
```

Optionally, this task may add a very small note to:

```text
docs/Cut_Structure_Preparation.md
```

Only do this if it helps link the audit document from the preparation document.

---

## Why This Phase Exists

The project architecture is based on:

```text
Project
 └ Track
    └ Cut
       └ Layer
          └ Frame
             └ Stroke
```

However, the current application effectively behaves around one active cut/timeline editing context.

Before implementing multiple cuts, active Cut state, Cut switching UI, Storyboard Panel, or global track/cut editing, the codebase needs a clear audit of:

* Where `Cut` exists in the models
* Where controllers assume a first/default cut
* Where UI assumes one active timeline context
* Where services serialize/deserialize cuts
* Which future changes will be needed to support multiple cuts safely

This phase should make the next implementation phase safer.

---

## Required Output

Create:

```text
docs/Cut_Structure_Audit.md
```

This document must include at least these sections:

```text
# Cut Structure Audit

## Current Summary

## Model Usage

## Repository / Service Usage

## Controller Usage

## UI Usage

## Test Coverage

## Current Single-Cut Assumptions

## Risks Before Multi-Cut Work

## Recommended Next Phase
```

---

## Part A: Inspect Model Usage

Inspect:

```text
lib/src/models/
```

Document how `Project`, `Track`, `Cut`, `Layer`, `Frame`, and related IDs currently represent the hierarchy.

The audit should answer:

```text
- Does Project contain Tracks?
- Does Track contain Cuts?
- Does Cut contain Layers?
- Does Cut own canvas size?
- Does Cut own or imply duration?
- Are there helper methods that assume the first Track or first Cut?
- Are there any direct shortcuts that bypass Cut?
```

Do not change model behavior in this phase.

---

## Part B: Inspect Repository / Service Usage

Inspect:

```text
lib/src/services/
```

Document how current services handle cuts.

Include:

```text
- ProjectRepository cut access patterns
- JSON serialization/deserialization of Track/Cut/Layer/Frame
- Any command classes that create, update, or assume Cut structure
- Any save/load assumptions related to one cut
```

The audit should identify whether existing services are already structurally multi-cut capable or whether they are practically single-cut in current usage.

Do not change service behavior in this phase.

---

## Part C: Inspect Controller Usage

Inspect:

```text
lib/src/controllers/
```

Document how controllers currently find or edit timeline/layer/canvas data.

Include:

```text
- CanvasController assumptions
- LayerController assumptions
- TimelineController assumptions
- Any first-track / first-cut access
- Any selected layer/frame state that implicitly belongs to one active cut
```

The audit should identify what will need to change before active Cut state can be added safely.

Do not change controller behavior in this phase.

---

## Part D: Inspect UI Usage

Inspect:

```text
lib/src/ui/
```

Especially inspect:

```text
lib/src/ui/home_page.dart
lib/src/ui/timeline/
lib/src/ui/canvas/
```

Document how UI currently assumes the active editing context.

Include:

```text
- Whether HomePage assumes a single active cut
- Whether TimelinePanel receives only one cut/layer set
- Whether CanvasView assumes one active cut/layer/frame context
- Whether layer selection is scoped to one implicit cut
```

Do not add Cut switching UI in this phase.

---

## Part E: Inspect Tests

Inspect:

```text
test/
```

Document which tests indirectly or directly cover Cut behavior.

Include:

```text
- Model tests
- Service tests
- Controller tests
- UI tests
- Timeline tests
- Save/load tests
```

Identify gaps that future multi-cut work should cover.

Do not add or change tests in this phase unless a minimal docs-only test fixture reference already exists and needs no behavior change.

Preferred: no test changes.

---

## Important Product Policies To Preserve

The audit must explicitly mention that future Cut work must preserve these policies:

```text
- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Rename conflict must offer Link / Cancel only.
- Rename-only must not be offered.
- Linked frames share material/source only.
- Linked frames share FrameId, strokes/material, and frame name.
- Linked frames do not share timeline placement, authored exposure duration, mark position, blank/X position, or selected cell state.
- Exposure +/- operates on the selected authored timeline entry, not every use of the same FrameId.
- Timeline placement must remain independent per cut.
- Future linked layers must not share timing by default.
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Runtime behavior changes
- Model schema changes
- Controller behavior changes
- Service behavior changes
- UI behavior changes
- JSON schema changes
- Save/load format changes
- Undo/Redo behavior changes
- Timeline behavior changes
- Canvas behavior changes
- Renderer changes
- Brush engine changes
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
- Global FrameId refactor
- Provider
- Riverpod
- Bloc
- Complex app-wide state management
```

Do not implement Phase 27 or later.

This phase must stay focused on audit documentation.

---

## Files To Add

Add:

```text
docs/Cut_Structure_Audit.md
```

Optional minimal update:

```text
docs/Cut_Structure_Preparation.md
```

Only update `docs/Cut_Structure_Preparation.md` if adding a short reference such as:

```text
See docs/Cut_Structure_Audit.md for the current codebase audit before active Cut implementation.
```

Do not rewrite existing docs.

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
1. docs/Cut_Structure_Audit.md exists.
2. The audit describes model usage of Project / Track / Cut / Layer / Frame.
3. The audit describes repository/service usage of Cut.
4. The audit describes controller assumptions around Cut.
5. The audit describes UI assumptions around one active cut/timeline context.
6. The audit identifies current single-cut assumptions.
7. The audit lists risks before multi-cut work.
8. The audit recommends the next phase.
9. No runtime code is changed.
10. No model/controller/service/UI behavior is changed.
11. flutter analyze passes.
12. flutter test passes.
13. git status shows only intended documentation changes before commit, and clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 26 Cut Structure Audit docs.

Added:
- docs/Cut_Structure_Audit.md

Optional updated:
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

Read `docs/Phase_26_Codex_Task.md` and implement Phase 26 only. This is a docs-first audit phase. Inspect the existing models, services, controllers, UI, and tests to document how `Cut` is currently represented and where the app still assumes a single active cut/timeline context. Add `docs/Cut_Structure_Audit.md`. Do not change runtime code, models, controllers, services, UI behavior, JSON schema, save/load, undo/redo, timeline behavior, active Cut state, Cut switching UI, Storyboard Panel, or Phase 27+ work. Run `flutter analyze`, `flutter test`, and `git status`.
