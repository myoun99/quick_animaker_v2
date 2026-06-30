# Phase 25 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 25: Product Direction Notes & Cut Structure Preparation Docs.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 24 and related follow-up fixes are already complete.

Current completed foundation:

```text
lib/main.dart
lib/src/models/
lib/src/services/project_repository.dart
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/
lib/src/services/project_json_serializer.dart
lib/src/services/project_file_service.dart
lib/src/controllers/canvas_controller.dart
lib/src/controllers/layer_controller.dart
lib/src/controllers/timeline_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/
lib/src/ui/timeline/
test/models/
test/services/
test/controllers/
test/ui/
docs/
```

The project already has:

* Immutable domain models
* Typed IDs
* JSON support
* ProjectRepository
* Command-based Undo/Redo MVP
* JSON save/load services
* Basic canvas drawing
* Layer MVP
* Layer visibility
* Layer opacity
* Integrated timeline/layer UI
* Horizontal timeline grid
* Vertical X-sheet timeline grid
* SplayTreeMap-based timeline exposure map
* `TimelineExposure`
* `TimelineExposureType`
* Drawing exposure entries
* Blank/null exposure entries
* Drawing frame heads displayed as `○`
* Named drawing frame heads
* Blank/null heads displayed as `X`
* `TimelineMark`
* `TimelineMarkType`
* Sparse per-layer marks map
* `●` inbetween/timesheet mark
* Mark toggle Undo/Redo
* Mark JSON save/load
* `New Frame` action
* `Blank / X` action
* `Mark ●` action
* `Rename Frame` dialog
* `Delete Cell` action
* Frame names
* `+ Exposure` and `- Exposure`
* Timeline map edit Undo/Redo
* New layers start with `0 -> blank`
* Initial sample layers start with `0 -> blank`
* Delete Cell deletes only drawingStart cells
* Delete Cell does not delete X
* Delete Cell does not delete mark-only cells
* Mark `●` is removed by the Mark button
* DrawingStart with `●` is deleted together by Delete Cell
* Selected timeline cell highlight
* Selected layer highlight
* Linked Frame Copy/Paste MVP
* `Copy Frame` action
* `Paste Linked Frame` action
* Linked use count display
* In-memory copied frame reference
* Same-layer linked paste using the same `FrameId`
* Linked frames share drawing material but do not share exposure duration
* Frame name conflict policy:

    * Same frame name means same material
    * Rename conflict shows Link / Cancel
    * Link merges timeline references into the existing material
    * Rename-only is intentionally not offered
* Timeline/cell action toolbar relocated into `TimelinePanel`
* Timeline/cell action toolbar icon buttons
* Tooltip labels for timeline/cell action buttons
* Compact timeline status text
* Timeline toolbar grouping
* Drawing block color cleanup:

    * Drawing head and held drawing cells use the same white or near-white base color
    * Blank/X head and held blank cells use the same dark gray base color
    * Selected cell highlight remains visible
* Passing `flutter analyze`
* Passing `flutter test`

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
docs/Phase_2_Codex_Task.md
docs/Phase_3_Codex_Task.md
docs/Phase_4_Codex_Task.md
docs/Phase_5_Codex_Task.md
docs/Phase_6_Codex_Task.md
docs/Phase_7_Codex_Task.md
docs/Phase_8_Codex_Task.md
docs/Phase_9_Codex_Task.md
docs/Phase_10_Codex_Task.md
docs/Phase_11_Codex_Task.md
docs/Phase_12_Codex_Task.md
docs/Phase_13_Codex_Task.md
docs/Phase_14_Codex_Task.md
docs/Phase_15_Codex_Task.md
docs/Phase_16_Codex_Task.md
docs/Phase_17_Codex_Task.md
docs/Phase_18_Codex_Task.md
docs/Phase_19_Codex_Task.md
docs/Phase_20_Codex_Task.md
docs/Phase_21_Codex_Task.md
docs/Phase_22_Codex_Task.md
docs/Phase_23_Codex_Task.md
docs/Phase_24_Codex_Task.md
```

This task implements only Phase 25.

---

## Scope

Implement only:

```text
Phase 25: Product Direction Notes & Cut Structure Preparation Docs
```

This is a documentation and architecture-direction phase.

The goal is to record the product direction decisions that have emerged from Phases 20 through 24 before starting multi-cut work.

This phase should add documentation only.

The main output should be:

```text
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
```

Optionally, this task may add a short reference entry to `docs/ImplementationPlan.md` if the existing document has a suitable phase list or notes section.

Do not implement new runtime behavior in this phase.

---

## Why This Phase Exists

The current timeline and linked-frame behavior has become specific enough that it should be documented before moving into multiple Cut support.

The next major direction is expected to be:

```text
1. Product direction notes
2. Cut structure preparation
3. Multiple Cut structure
4. Cut selection / switching UI
5. Storyboard Panel MVP
```

Before changing models, controllers, timeline behavior, or UI, this phase should capture the intended product rules so future Codex tasks do not accidentally violate them.

---

## Part A: Add Product Direction Notes

Create:

```text
docs/Product_Direction_Notes.md
```

This document should summarize the current product direction.

It must include at least the following sections:

```text
# Product Direction Notes

## Current Product Direction

## Timeline Editing Direction

## Frame Material Identity

## Linked Frame Policy

## Rename Conflict Policy

## UI Direction

## Explicit Non-Goals for the Current Stage

## Future Ideas
```

### Current Product Direction

Document that QuickAnimaker v2.1 is intended to become a professional bitmap-based 2D animation production tool inspired by:

```text
- TVPaint
- Clip Studio Paint
- Photoshop / PSD-style layer workflows
```

Emphasize that the project is not intended to become a toy drawing app or tutorial-style beginner interface.

The UI should move toward a practical production tool.

### Timeline Editing Direction

Document these current policies:

```text
- Timeline and X-sheet style editing are central to the product.
- Timeline cells may contain drawing exposure, blank/X exposure, marks, or empty/held positions depending on current authored timeline entries.
- `○` means unnamed drawing frame head.
- A frame name means named drawing frame head.
- `X` means blank/null exposure head.
- `●` means timeline mark / inbetween mark / timesheet mark.
- Exposure duration belongs to the selected authored timeline entry, not to the FrameId globally.
```

### Frame Material Identity

Document this policy clearly:

```text
Same frame name means same material.
```

Within the same layer, independent `FrameId`s with the same non-empty frame name should not be allowed as a long-term policy.

Frame identity and drawing material identity are currently represented by `FrameId`.

When two timeline references point to the same `FrameId`, they are linked uses of the same drawing material.

### Linked Frame Policy

Document this policy clearly:

```text
Linked frames share material/source only.
```

Linked frames share:

```text
- FrameId
- Drawing strokes / material
- Frame name
```

Linked frames do not share:

```text
- Timeline placement
- Authored exposure duration
- Blank/X position
- Mark position
- Selected cell state
```

Document that `+ Exposure` and `- Exposure` must operate on the selected authored timeline entry rather than mutating all uses of the same `FrameId`.

### Rename Conflict Policy

Document this policy clearly:

```text
If a frame is renamed to a name already used by another FrameId in the same layer, the user gets Link / Cancel only.
```

Allowed options:

```text
- Link
- Cancel
```

Intentionally not offered:

```text
- Rename only
- Keep independent duplicate material with the same name
```

Reason:

```text
Same name means same material.
Allowing same-layer duplicate FrameIds with the same name would make linked-frame and material identity behavior ambiguous.
```

### UI Direction

Document these UI rules:

```text
- The UI should feel like a practical production tool.
- Avoid tutorial-like long hints.
- Prefer icon buttons with Tooltip labels.
- Keep status text compact.
- Use grouping and layout to make tools understandable instead of long explanatory text.
- Avoid adding visual noise.
```

Timeline-specific UI direction:

```text
- Drawing exposure blocks should be visually calm.
- Drawing head and held drawing cells may share the same white or near-white base color.
- Blank/X head and held blank cells may share the same dark gray base color.
- Selected cell highlight must remain visible.
```

### Explicit Non-Goals for the Current Stage

Document that the following should not be implemented yet:

```text
- Multiple Cut UI
- Cut switching UI
- Storyboard Panel
- Camera Layer
- Audio Layer
- Storyboard Layer
- Linked Layer
- Cross-layer linked paste
- Cross-cut linked paste
- Project-level material pool
- Global FrameId refactor
- Layer type enum
- Collapsible layer sections
- Timeline virtualization
- Advanced export
```

### Future Ideas

Document these as future ideas only:

```text
- Cut / Storyboard system
- Cut selection and switching UI
- Storyboard Panel MVP
- Animation Layer
- Camera Layer
- Audio Layer
- Storyboard Layer
- Cross-layer / cross-cut linked paste
- Project-level material pool
- Linked Layer
```

Important: mark them as not implemented yet.

---

## Part B: Add Cut Structure Preparation Notes

Create:

```text
docs/Cut_Structure_Preparation.md
```

This document should prepare the next architecture direction without changing code.

It must include at least the following sections:

```text
# Cut Structure Preparation

## Current State

## Target Direction

## Important Constraint

## Recommended Implementation Order

## Cut Model Direction

## Timeline Direction

## Storyboard Direction

## Risks to Avoid
```

### Current State

Document that the current app effectively behaves around one active cut/timeline editing context, even though the original architecture already includes the `Project -> Track -> Cut -> Layer -> Frame -> Stroke` hierarchy.

Do not claim that full multi-cut editing already exists unless the current code truly supports it.

### Target Direction

Document the next direction:

```text
- Stabilize the current single-cut timeline workflow first.
- Prepare for multiple cuts.
- Add cut selection/switching UI after the data flow is ready.
- Add Storyboard Panel only after Cut switching is stable.
```

### Important Constraint

Document this important product rule:

```text
Even if linked layers or linked materials are introduced later, timeline placement must remain independent per cut.
```

This applies to future linked-layer ideas too:

```text
Linked Layer should share material/source or layer identity, not necessarily timing.
Cut-specific timing and timeline placement should remain independent.
```

### Recommended Implementation Order

Document this order:

```text
1. Document product direction.
2. Inspect existing Cut usage in models/controllers/services.
3. Ensure current timeline operations are scoped to the active Cut.
4. Add active Cut selection state.
5. Add minimal Cut list/switching UI.
6. Only then consider Storyboard Panel MVP.
```

### Cut Model Direction

Document that each Cut should own or resolve:

```text
- CutId
- Cut name
- Canvas size
- Layers
- Duration
```

Future Cut-level concepts may include:

```text
- Start position on global track timeline
- Thumbnail/representative frame
- Storyboard metadata
- Audio references
```

Do not implement those concepts in this phase.

### Timeline Direction

Document that the timeline panel should continue to edit the active cut.

Do not introduce global multi-cut timeline editing yet.

Global track/cut editing should be a later phase.

### Storyboard Direction

Document the current long-term idea:

```text
Storyboard Panel should likely come after Cut selection/switching UI.
```

Also document the newer Storyboard Layer idea:

```text
A Storyboard Layer may later generate storyboard panels based on its drawings.
```

But make clear:

```text
- Storyboard Layer is not implemented yet.
- Storyboard Panel is not implemented yet.
- No model changes for Storyboard Layer should be made in this phase.
```

### Risks to Avoid

Document these risks:

```text
- Do not rush into cross-cut linked paste.
- Do not introduce a project-level material pool without a careful design.
- Do not make timeline placement shared by linked materials.
- Do not make linked layers share timing by default.
- Do not add UI complexity before the active Cut concept is stable.
- Do not add long tutorial text to the UI.
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Runtime code behavior changes
- Model schema changes
- Controller changes
- Service changes
- Timeline behavior changes
- UI behavior changes
- New buttons
- New dialogs
- New app state
- Active Cut state
- Cut switching UI
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
- Persistence format changes
- JSON schema changes
- Save/load changes
- Undo/Redo changes
- Renderer changes
- Canvas drawing changes
- Brush engine changes
- Playback changes
- Provider
- Riverpod
- Bloc
- Complex app-wide state management
```

Do not implement Phase 26 or later.

This phase must stay focused on documentation.

---

## Files to Add

Add:

```text
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
```

Optional, only if appropriate:

```text
docs/ImplementationPlan.md
```

If `docs/ImplementationPlan.md` is updated, keep the change minimal.

Do not rewrite the whole implementation plan.

---

## Tests

Because this is a docs-only phase, no new unit tests are required.

However, the repository must still pass:

```bash
flutter analyze
flutter test
```

If the docs-only change does not affect Dart code, these commands should still pass.

---

## Completion Criteria

This phase is complete only when:

```text
1. docs/Product_Direction_Notes.md exists.
2. docs/Cut_Structure_Preparation.md exists.
3. The documents clearly record current linked-frame, frame-name, timeline, and UI direction policies.
4. The documents clearly separate current behavior from future ideas.
5. The documents explicitly state that Cut/Storyboard/Layer-type features are not implemented yet.
6. No runtime behavior is changed.
7. No model/controller/service/UI behavior is changed.
8. flutter analyze passes.
9. flutter test passes.
10. git status shows only the intended documentation changes.
```

---

## Suggested Final Response from Codex

After completing the task, summarize:

```text
Implemented Phase 25 docs-only preparation.

Added:
- docs/Product_Direction_Notes.md
- docs/Cut_Structure_Preparation.md

No runtime behavior was changed.

Validation:
- flutter analyze
- flutter test
```

Also mention whether `docs/ImplementationPlan.md` was updated.

---

## Short Instruction for Codex

Implement Phase 25 only. Add documentation files `docs/Product_Direction_Notes.md` and `docs/Cut_Structure_Preparation.md` to record the current product direction, linked-frame policy, same-name material policy, compact professional UI direction, and future Cut/Storyboard preparation. Do not change runtime code, models, controllers, services, UI behavior, JSON schema, save/load, undo/redo, or timeline behavior. Keep this phase docs-only. Run `flutter analyze` and `flutter test`.
