# Phase 40 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 40: Cut / Conte Direction Notes.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 39 are complete.

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
* Active Cut state design notes
* ID scope decision notes
* Minimal explicit `activeCutId` flow in `HomePage`
* Active Cut isolation tests using two-cut fixtures
* Default active cut resolver
* Active cut lookup helper extraction
* `EditingSessionState` owns `activeCutId`
* `HomePage` controller construction clearly derives from `EditingSessionState.activeCutId`
* `CutListEntry` / `cutListEntriesFor` read model helper
* Passive `CutListBar` UI using `cutListEntriesFor`
* Optional `CutListBar.onCutSelected` callback for selection intent
* Minimal Cut switching between existing sample cuts
* Active-cut edit safety regression tests
* Cut switching UX polish

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Phase_28_Codex_Task.md
docs/Phase_29_Codex_Task.md
docs/Phase_30_Codex_Task.md
docs/Phase_31_Codex_Task.md
docs/Phase_32_Codex_Task.md
docs/Phase_33_Codex_Task.md
docs/Phase_34_Codex_Task.md
docs/Phase_35_Codex_Task.md
docs/Phase_36_Codex_Task.md
docs/Phase_37_Codex_Task.md
docs/Phase_38_Codex_Task.md
docs/Phase_39_Codex_Task.md
```

This task implements only Phase 40.

---

## Scope

Implement only:

```text
Phase 40: Cut / Conte Direction Notes
```

This is a docs-only phase.

The goal is to document the newly clarified long-term direction for:

```text
- Cut switching
- Conte naming
- Conte Panel
- Conte Layer
- V/A style track organization
- future cross-cut / cross-layer linked paste
- project-level material/source direction
```

Do not change runtime code.

Do not change tests.

Do not implement any new UI.

---

## Main Goal

Add a new direction document:

```text
docs/Cut_Conte_Direction_Notes.md
```

Also update existing product direction docs only if needed:

```text
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
```

Keep updates small and focused.

The document should clarify that the long-term Japanese animation workflow term should be:

```text
Conte
```

not:

```text
Conti
```

The document should also clarify that `Storyboard` may appear as an explanatory English concept, but the product direction should prefer:

```text
Conte Panel
Conte Layer
```

for internal names and future UI wording.

---

## Required Document Content

Create:

```text
docs/Cut_Conte_Direction_Notes.md
```

It should include sections similar to:

```text
# Cut / Conte Direction Notes

## Purpose

## Naming Policy

## Current Cut State

## Long-Term Conte Panel Direction

## Conte Layer Direction

## V / A Track Direction

## Linked Frame / Linked Material Direction

## What Not To Implement Yet

## Suggested Future Phase Order
```

Adapt headings if needed, but preserve the intent.

---

## Naming Policy

Document this clearly:

```text
- Use `Conte`, not `Conti`.
- Preferred UI/product terms:
  - Conte Panel
  - Conte Layer
- `Storyboard` can be used as an explanatory general concept in documents, but future product naming should prefer `Conte`.
- Avoid introducing new code/files/classes named `Conti`.
- Avoid naming future UI as `Storyboard Panel` unless explicitly re-decided later.
```

Rationale:

```text
The project is oriented toward Japanese animation / sakuga workflow language, where コンテ is the intended concept.
```

Do not over-explain.

Keep it concise.

---

## Current Cut State

Document the current implemented state:

```text
- The app has a minimal CutListBar.
- Cut 1 and Cut 2 are shown in the sample project.
- Cut switching is implemented between existing cuts.
- EditingSessionState owns activeCutId.
- LayerController and TimelineController are rebuilt/retargeted when activeCutId changes.
- CanvasView receives the active cut id.
- Active-cut edit safety tests exist.
```

Also document current limitations:

```text
- No cut create/delete/rename UI yet.
- No cut duplicate UI yet.
- No cut management panel yet.
- No Conte Panel yet.
- No Conte Layer yet.
- No Camera Layer yet.
- No Audio Layer behavior yet.
```

---

## Long-Term Conte Panel Direction

Document this product direction:

```text
- A future Conte Panel should eventually exist as a major workflow view.
- It may become a standalone panel similar in importance to TimelinePanel.
- It may alternatively become a mode/view switch alongside Timeline/X-sheet.
- The final UI placement should be decided after Cut switching and active-cut editing are stable.
```

Important:

```text
Do not decide the final panel placement in this phase.
Do not implement Conte Panel in this phase.
```

---

## Conte Layer Direction

Document the user's preferred long-term idea:

```text
- A future Conte Layer may exist inside a Cut.
- The drawing heads / frame heads of a Conte Layer may define Conte Panel divisions.
- Instead of manually adding separate panels one by one, the Conte Layer's drawing heads can become the source for panel segmentation.
- Later Conte export can use Conte Layer drawings as panel images.
```

Clarify:

```text
This is a long-term design direction only.
It is not implemented yet.
```

---

## V / A Track Direction

Document the long-term track organization idea:

```text
- The project may eventually use production-friendly track naming/organization similar to Premiere-style V1, V2, V3... and A1, A2, A3...
- Video/animation/conte/camera-related layers may conceptually live under V-style organization.
- Audio tracks may conceptually live under A-style organization.
- This does not imply immediate implementation.
```

Avoid committing too early to exact data model changes.

---

## Linked Frame / Linked Material Direction

Reaffirm existing policy:

```text
- Linked frames share material/source only.
- Linked frames may share FrameId, strokes/material, and frame name.
- Linked frames must not share timeline placement.
- Linked frames must not share authored exposure duration.
- Linked frames must not share mark position.
- Linked frames must not share blank/X position.
- Linked frames must not share selected cell state.
```

Document future direction:

```text
- Cross-layer linked paste and cross-cut linked paste are still long-term goals.
- They should not be implemented by simply carrying UI copy state across cuts.
- They likely require a safer project-level material/source structure.
- A project-level material pool or project-level source registry may be needed later.
```

Important:

```text
Even if project-level material/source is introduced later, timeline placement must remain independent per cut/layer.
```

---

## What Not To Implement Yet

Document that the following are still not implemented:

```text
- Conte Panel
- Conte Layer
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
```

---

## Suggested Future Phase Order

Add a conservative suggested order such as:

```text
1. Continue stabilizing Cut switching and active-cut editing.
2. Add minimal Cut create/delete/rename only when active-cut editing is safe enough.
3. Document Conte Layer data model before implementation.
4. Add Conte Layer model/type only after layer-type direction is clear.
5. Add passive Conte Panel read model.
6. Add Conte Panel MVP.
7. Add Conte export later.
```

This order is advisory, not binding.

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Runtime code changes
- Test changes
- Cut create behavior
- Cut delete behavior
- Cut rename behavior
- Cut duplicate behavior
- Cut management panel
- Conte Panel
- Conte Layer
- Storyboard Panel
- Storyboard Layer
- Camera Layer
- Audio Layer behavior
- Layer type enum
- V/A track UI
- Cross-layer paste
- Cross-cut paste
- Project-level material pool
- Global FrameId refactor
- ID generation refactor
- Repository API redesign
- Command API redesign
- JSON schema changes
- Save/load format changes
- Undo/Redo redesign
- Timeline behavior redesign
- Timeline placement sharing
- Canvas painting behavior redesign
- Canvas layout redesign
- Renderer changes
- Brush engine changes
- Provider
- Riverpod
- Bloc
- ChangeNotifier
- Stream-based session state
- Complex app-wide state management
```

Do not implement Phase 41 or later.

---

## Allowed Changes

Allowed:

```text
- Add docs/Cut_Conte_Direction_Notes.md.
- Optionally add a short cross-reference from docs/Product_Direction_Notes.md.
- Optionally add a short cross-reference from docs/Cut_Structure_Preparation.md.
```

Preferred result:

```text
docs-only changes
```

---

## Expected User-Visible Behavior

After Phase 40:

```text
The app should look and behave exactly the same as Phase 39.
```

No runtime behavior should change.

---

## Tests / Validation

Since this is docs-only:

```bash
flutter analyze
flutter test
git status
```

Do not run `dart format` on Markdown files.

Do not run `dart format` on docs.

---

## Manual Check In Android Studio

Manual app check is optional for this docs-only phase.

If performed, verify:

```text
1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No new UI appeared.
4. No Conte Panel appeared.
5. No Storyboard Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. docs/Cut_Conte_Direction_Notes.md exists.
2. The document clearly states `Conte`, not `Conti`.
3. The document explains Conte Panel and Conte Layer as long-term directions.
4. The document explains the Conte Layer drawing-head-to-panel segmentation idea.
5. The document explains V/A style track direction as long-term only.
6. The document reaffirms linked material/source policy.
7. The document explains that cross-cut/cross-layer linked paste likely needs project-level material/source structure later.
8. No runtime code changed.
9. No tests changed.
10. No JSON schema changed.
11. No UI was added.
12. flutter analyze passes.
13. flutter test passes.
14. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 40 Cut / Conte Direction Notes.

Changed:
- Added docs/Cut_Conte_Direction_Notes.md.
- Documented Conte naming policy.
- Documented long-term Conte Panel / Conte Layer direction.
- Documented V/A track direction.
- Reaffirmed linked frame/material policy.
- Documented future cross-cut/cross-layer linked paste direction.

Validation:
- flutter analyze
- flutter test
- git status

This phase was docs-only.
No runtime code changed.
No tests changed.
No UI changed.
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_40_Codex_Task.md` and implement Phase 40 only. This phase is docs-only. Add `docs/Cut_Conte_Direction_Notes.md` documenting the long-term Cut / Conte direction: use `Conte`, not `Conti`; future `Conte Panel` and `Conte Layer`; Conte Layer drawing heads may define Conte Panel divisions; long-term V/A track direction; linked frames/materials share source only, not timeline placement; future cross-cut/cross-layer linked paste likely needs project-level material/source structure. Do not change runtime code, tests, UI, JSON schema, repository APIs, command APIs, save/load, undo/redo, timeline/canvas behavior, or implement Phase 41+. Run `flutter analyze`, `flutter test`, and `git status`.
