# Phase 41 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 41: Cut Management Policy Notes.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 40 are complete.

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
* Cut / Conte direction notes

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Cut_Conte_Direction_Notes.md
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
docs/Phase_40_Codex_Task.md
```

This task implements only Phase 41.

---

## Scope

Implement only:

```text
Phase 41: Cut Management Policy Notes
```

This is a docs-only phase.

The goal is to document the product and technical policy for future Cut management work before implementing Cut create/delete/rename/duplicate/reorder.

Do not change runtime code.

Do not change tests.

Do not implement any new UI.

---

## Main Goal

Add a new policy document:

```text
docs/Cut_Management_Policy.md
```

The document should define policies for:

```text
- Cut names
- Cut deletion and active cut fallback
- Last cut deletion
- Cut duplication
- Future linked cut / shared-use cut direction
- Undo/redo scope
- Volatile undo/redo history
- Last active cut restoration
- Sample project / sample cut direction
```

Also update existing product direction docs only if needed:

```text
docs/Product_Direction_Notes.md
docs/Cut_Conte_Direction_Notes.md
```

Keep updates small and focused.

Preferred result:

```text
docs-only changes
```

---

## Required Document

Create:

```text
docs/Cut_Management_Policy.md
```

Suggested sections:

```text
# Cut Management Policy

## Purpose

## Cut Identity And Names

## Cut Deletion Policy

## Last Cut Deletion Policy

## Cut Duplication Policy

## Future Linked Cut Direction

## Undo / Redo Policy

## Last Active Cut Restore Policy

## Sample Project Direction

## What Not To Implement Yet

## Suggested Future Phase Order
```

Adapt headings if needed, but preserve the intent.

---

## Cut Identity And Names

Document:

```text
- `CutId` is the real identity.
- Cut name is a user-facing display label.
- Duplicate cut names should be allowed.
- Cut name duplication should not block rename.
- Future UI may show duplicate-name warnings, filters, or a compact duplicate-name list/button.
- Cut name policy is intentionally different from frame name/material policy.
```

Important distinction:

```text
Frame name policy:
- same frame name means same material within the same layer
- duplicate independent FrameIds with the same non-empty name in the same layer should not be allowed

Cut name policy:
- duplicate cut names are allowed
- CutId, not name, identifies the cut
```

Do not weaken frame name/material policy.

---

## Cut Deletion Policy

Document the future intended behavior:

```text
When deleting the active cut:
1. Prefer the previous cut in project order.
2. If no previous cut exists, use the next cut.
3. If no cut remains, create a new default empty cut.
```

Clarify:

```text
- Active cut should never remain pointing to a missing cut.
- The app should maintain at least one editable cut after a delete operation completes.
- The temporary internal delete operation should not leave the app in a long-lived zero-cut state.
```

---

## Last Cut Deletion Policy

Document:

```text
- Deleting the last cut should be allowed from the user's perspective.
- Internally, deleting the last cut should immediately create a new default empty cut.
- The result should be a valid project with one editable cut.
```

Do not implement it in this phase.

---

## Cut Duplication Policy

Document the MVP policy:

```text
- Initial Cut duplicate should be an independent deep copy.
- A duplicated cut should receive a new CutId.
- Duplicated layers should receive new LayerIds.
- Duplicated frames should receive new FrameIds.
- The duplicate should not be linked by default.
- Timeline placement in the duplicate should be copied as independent authored placement.
- Strokes/material content may be copied as independent content for the MVP.
```

Clarify:

```text
The first Cut duplicate implementation should not introduce linked cuts, linked layers, cross-cut linked frames, or project-level material pool.
```

---

## Future Linked Cut Direction

Document the long-term idea:

```text
- Linked Cut is a long-term idea for shared-use cuts / 겸용컷 workflows.
- Linked Cut may be useful for output, timesheet, and relationship tracking.
- Linked Cut may behave like a higher-level relationship that can automatically create or manage linked layers.
- Linked Cut should not mean timeline placement is globally shared by default.
- Linked Cut should be designed later after Linked Layer and project-level material/source direction are clearer.
```

Important policy:

```text
Even if future Linked Cut exists:
- material/source sharing and timeline placement sharing must remain separate concepts.
- linked material/source does not automatically mean shared timing.
```

Do not implement Linked Cut in this phase.

---

## Undo / Redo Policy

Document the newly agreed policy clearly:

```text
- Undo/Redo is project editing session history.
- Undo/Redo may include both project data mutations and editing session state mutations.
- Cut create/delete/rename/duplicate/reorder should be undoable/redoable.
- Active cut selection switch should be undoable/redoable during the current session.
- Undoing/redoing active cut selection should restore `EditingSessionState.activeCutId`.
- Undoing/redoing active cut selection should rebuild or retarget active-cut-scoped controllers.
- Cut switch itself should not mutate Project data by itself.
```

Also document:

```text
- Active cut selection switch is an editing-session history command.
- Cut create/delete/rename/duplicate/reorder are project mutation history commands.
- Both can live in the same time-ordered HistoryManager stack.
```

---

## Volatile Undo / Redo History

Document this as a hard policy:

```text
- Undo/Redo stack is volatile.
- Undo/Redo stack must not be serialized into project save files.
- Undo/Redo stack is cleared when the app closes.
- Undo/Redo stack is cleared when the project closes.
- Opening a saved project starts with an empty undo/redo stack.
- The maximum undo history count should be user-configurable later.
- Example history count: 500, but the default value can be decided later.
```

Important:

```text
Save/load schema should not include undo stack or redo stack.
```

---

## Last Active Cut Restore Policy

Document the newly agreed policy:

```text
- The current/last active cut id should be saved as lightweight project metadata.
- Reopening a project should restore the last active cut by default.
- This should be default behavior, not an optional setting for now.
- If the saved last active cut id no longer exists, fall back to default active cut resolution.
```

Clarify the distinction:

```text
- Save the last active cut id.
- Do not save undo/redo stack.
- Restoring the last active cut does not restore prior undoable cut-switch commands.
```

Recommended fallback:

```text
1. Try saved lastActiveCutId.
2. If missing or invalid, use defaultActiveCutIdFor(project).
3. If the project has no cuts and future project policy supports it, create a default empty cut.
```

Do not implement save/load metadata in this phase.

---

## Sample Project Direction

Document:

```text
- Current Cut 1 / Cut 2 sample data is temporary development/demo data.
- It exists to test Cut switching and active-cut safety.
- In the final product, hardcoded sample cuts should not be the normal startup project.
- Later project creation/opening flow should replace the hardcoded sample project.
```

Possible future directions:

```text
- New project starts with one default empty cut.
- Demo/sample project can exist separately as a template or development-only fixture.
- The hardcoded sample project can be removed when real project creation/open/save flow is ready.
```

Do not remove sample data in this phase.

---

## What Not To Implement Yet

Document that the following are still not implemented:

```text
- Cut create UI
- Cut delete UI
- Cut rename UI
- Cut duplicate UI
- Cut reorder UI
- Cut management panel
- Linked Cut
- Linked Layer
- Cross-cut linked paste
- Cross-layer linked paste
- Project-level material pool
- Save/load lastActiveCutId
- Undoable active cut switch
- Persistent project open/close flow
- Conte Panel
- Conte Layer
```

---

## Suggested Future Phase Order

Add an advisory order such as:

```text
1. Document Cut management policy.
2. Add pure helper tests for Cut deletion fallback.
3. Add command/service design for Cut create/delete/rename.
4. Add undoable active cut switch command.
5. Add minimal Cut rename UI.
6. Add minimal Cut create UI.
7. Add minimal Cut delete UI with previous/next/new fallback.
8. Add Cut duplicate as independent deep copy.
9. Add save/load metadata for lastActiveCutId.
10. Remove hardcoded sample project when real project creation/opening flow is ready.
11. Design Linked Layer / Linked Cut later.
```

This order is advisory and non-binding.

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
- Cut reorder behavior
- Cut management panel
- Linked Cut
- Linked Layer
- Cross-cut linked paste
- Cross-layer linked paste
- Project-level material pool
- Save/load lastActiveCutId
- Undoable active cut switch
- Persistent project open/close flow
- Conte Panel
- Conte Layer
- Storyboard Panel
- Camera Layer
- Audio Layer behavior
- Layer type enum
- V/A track UI
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

Do not implement Phase 42 or later.

---

## Allowed Changes

Allowed:

```text
- Add docs/Cut_Management_Policy.md.
- Optionally add a short cross-reference from docs/Product_Direction_Notes.md.
- Optionally add a short cross-reference from docs/Cut_Conte_Direction_Notes.md.
```

Preferred result:

```text
docs-only changes
```

---

## Expected User-Visible Behavior

After Phase 41:

```text
The app should look and behave exactly the same as Phase 40.
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
4. No Cut management panel appeared.
5. No Conte Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. docs/Cut_Management_Policy.md exists.
2. The document clearly states CutId is identity and duplicate cut names are allowed.
3. The document distinguishes Cut name policy from Frame name/material policy.
4. The document defines cut deletion active-cut fallback: previous, next, new default cut.
5. The document states deleting the last cut is allowed and should create a new default cut.
6. The document states Cut duplicate MVP should be independent deep copy.
7. The document records Linked Cut as long-term only.
8. The document states active cut selection switch should be undoable/redoable during the current session.
9. The document states undo/redo history is volatile and must not be saved.
10. The document states last active cut id should be saved/restored as lightweight project metadata.
11. The document states sample Cut 1 / Cut 2 data is temporary development/demo data.
12. No runtime code changed.
13. No tests changed.
14. No JSON schema changed.
15. No UI was added.
16. flutter analyze passes.
17. flutter test passes.
18. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 41 Cut Management Policy Notes.

Changed:
- Added docs/Cut_Management_Policy.md.
- Documented duplicate cut name policy.
- Documented cut delete fallback policy.
- Documented last cut deletion policy.
- Documented independent cut duplicate policy.
- Documented future Linked Cut direction.
- Documented undo/redo and volatile history policy.
- Documented last active cut restore policy.
- Documented sample project direction.

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

Read `docs/Phase_41_Codex_Task.md` and implement Phase 41 only. This phase is docs-only. Add `docs/Cut_Management_Policy.md` documenting Cut management policies: duplicate cut names are allowed and CutId is identity; deleting active cut should fall back previous → next → new default cut; deleting the last cut is allowed from the user perspective and should create a new default cut; Cut duplicate MVP should be an independent deep copy; Linked Cut is long-term only; active cut selection switch should be undoable/redoable during the current session; undo/redo history is volatile and must not be saved; last active cut id should be saved/restored as lightweight project metadata; hardcoded sample Cut 1 / Cut 2 data is temporary. Do not change runtime code, tests, UI, JSON schema, save/load, repository APIs, command APIs, undo/redo implementation, timeline/canvas behavior, or implement Phase 42+. Run `flutter analyze`, `flutter test`, and `git status`.
