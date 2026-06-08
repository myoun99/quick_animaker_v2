# Cut / Conte Direction Notes

## Purpose

This document records the long-term Cut and Conte direction for QuickAnimaker v2.1.

It is intentionally direction-only. It does not define a final data model, UI layout, command API, repository API, save/load format, or implementation plan for future phases.

## Naming Policy

Use `Conte`, not `Conti`.

Preferred future UI and product terms:

- `Conte Panel`
- `Conte Layer`

`Storyboard` may be used as a general explanatory English concept in documents, but product naming should prefer `Conte`.

Avoid introducing new code, files, classes, or UI named `Conti`. Avoid naming future UI as `Storyboard Panel` unless the direction is explicitly re-decided later.

Rationale: the product is oriented toward Japanese animation / sakuga workflow language, where コンテ is the intended concept.

## Current Cut State

The currently implemented Cut state is minimal:

- The app has a minimal `CutListBar`.
- `Cut 1` and `Cut 2` are shown in the sample project.
- Cut switching is implemented between existing cuts.
- `EditingSessionState` owns `activeCutId`.
- `LayerController` and `TimelineController` are rebuilt or retargeted when `activeCutId` changes.
- `CanvasView` receives the active cut id.
- Active-cut edit safety tests exist.

Current limitations:

- No cut create/delete/rename UI yet.
- No cut duplicate UI yet.
- No cut management panel yet.
- No Conte Panel yet.
- No Conte Layer yet.
- No Camera Layer yet.
- No Audio Layer behavior yet.

## Long-Term Conte Panel Direction

A future `Conte Panel` should eventually exist as a major workflow view.

Possible long-term placements include:

- A standalone panel similar in importance to `TimelinePanel`.
- A mode or view switch adjacent to Timeline / X-sheet workflows.

Do not decide the final `Conte Panel` placement now. The final UI location should be decided only after Cut switching and active-cut editing are stable enough to support the next workflow layer safely.

Do not implement `Conte Panel` in this phase.

## Conte Layer Direction

A future `Conte Layer` may exist inside a Cut.

Long-term direction:

- A `Conte Layer` may use its drawing heads / frame heads to define `Conte Panel` divisions.
- Instead of manually adding separate panels one by one, the `Conte Layer` drawing heads can become the source for panel segmentation.
- Later Conte export may use `Conte Layer` drawings as panel images.

This is a long-term design direction only. It is not implemented yet, and this document does not choose the final data model for it.

## V / A Track Direction

The project may eventually use production-friendly track naming or organization similar to V/A workflows:

- V-style organization such as `V1`, `V2`, `V3`, and later tracks.
- A-style organization such as `A1`, `A2`, `A3`, and later tracks.

Video, animation, Conte, camera, and related visual layers may conceptually live under V-style organization. Audio tracks may conceptually live under A-style organization.

This is long-term direction only. It does not imply immediate UI, schema, repository, command, or layer-type changes.

## Linked Frame / Linked Material Direction

Linked frames share material/source only.

Linked frames may share:

- `FrameId`
- Drawing strokes / material
- Frame name

Linked frames must not share:

- Timeline placement
- Authored exposure duration
- Mark position
- Blank/X position
- Selected cell state

A linked frame is another use of the same drawing material/source, not a shared timeline decision. Timeline placement and timing must remain independent for each authored use.

Future cross-layer linked paste and cross-cut linked paste remain long-term goals. They should not be implemented by simply carrying UI copy state across layers or cuts. They likely require a safer project-level material/source structure, such as a project-level material pool or source registry.

Even if project-level material/source is introduced later, timeline placement must remain independent per cut and per layer.

## What Not To Implement Yet

The following are not implemented now and should not be introduced as side effects of this direction note:

- Conte Panel
- Conte Layer
- Storyboard Panel
- Cut create/delete/rename
- Cut duplicate
- Cut management panel
- Camera Layer
- Audio Layer behavior
- V/A track UI
- Cross-cut linked paste
- Cross-layer linked paste
- Project-level material pool
- Conte export
- JSON schema changes
- Save/load changes
- Repository API changes
- Command API changes
- Undo/redo changes
- Timeline behavior changes
- Canvas behavior changes

## Suggested Future Phase Order

This advisory order is conservative and non-binding:

1. Continue stabilizing Cut switching and active-cut editing.
2. Add minimal Cut create/delete/rename only when active-cut editing is safe enough.
3. Document the `Conte Layer` data model before implementation.
4. Add a `Conte Layer` model/type only after layer-type direction is clear.
5. Add a passive `Conte Panel` read model.
6. Add a `Conte Panel` MVP.
7. Add Conte export later.
