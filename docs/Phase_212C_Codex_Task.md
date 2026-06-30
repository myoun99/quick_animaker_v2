# Phase 212C Codex Task

## Title

Slim handoff section 5+ into a lightweight current-doc entry point

## 1. Goal

The user wants `docs/Handoff_QuickAnimaker_v2_Current.md` to function only as a lightweight continuation and document-entry guide.

Sections 0 through 4 are user-managed and must remain untouched.

Sections 5 and later should not contain architecture ideas, module policies, model invariants, or design notes unless they are only short pointers to the current source-of-truth docs.

The goal of this phase is:

```txt id="7u5uf4"
Keep handoff sections 0-4 unchanged.
Replace handoff section 5+ with a short entry-point guide.
Move any still-useful content into Current_* docs only if it is not already there.
Delete duplicated handoff architecture details when they already exist in Current_* docs.
Do not change runtime code.
```

## 2. Required reading

Read these files directly before editing:

```txt id="znytz6"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Current_Docs_Index.md
docs/Current_Project_Architecture.md
docs/Current_Implementation_Roadmap.md
docs/Current_Brush_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Timeline_Architecture.md
docs/Current_Cut_Management_Architecture.md
docs/Current_Storyboard_Architecture.md
```

## 3. Hard rules

```txt id="kfl7xh"
- Do not edit handoff sections 0, 1, 2, 3, or 4.
- Do not change the wording of handoff sections 0-4.
- AI may edit only section 5 and later.
- Handoff section 5+ must be short.
- Handoff section 5+ must not contain detailed architecture policy.
- Handoff section 5+ must not contain idea notes.
- Handoff section 5+ must point readers to Current_* docs instead.
- Current_* docs remain the source of truth.
- Phase_*_Codex_Task.md files remain historical task/order records.
- Do not restore deleted obsolete non-phase docs.
- Do not modify runtime code under lib/.
```

## 4. What to remove from handoff

Current handoff section 5 contains detailed model and brush/canvas notes such as:

```txt id="lnbzdh"
- Project -> Track -> Cut -> Layer -> Frame -> Stroke hierarchy
- value object list
- model invariants
- BrushSettings / BrushPreset / BrushInputSample details
- CanvasPoint / ViewportPoint / CanvasViewport details
```

Remove these detailed notes from handoff section 5+ if they are already represented in the relevant Current docs.

These details should not remain in handoff as architecture policy.

## 5. Where content belongs

Use this mapping:

```txt id="bxh9p6"
- Core domain hierarchy and model boundaries:
  docs/Current_Project_Architecture.md

- Brush / PaintCommand / BrushFrameStore / heavy payload separation:
  docs/Current_Brush_Architecture.md
  docs/Current_Canvas_Cache_Storage_Architecture.md

- Timeline / Cut.duration / linked frame / layer ordering:
  docs/Current_Timeline_Architecture.md

- CutId / activeCutId / cut deletion fallback:
  docs/Current_Cut_Management_Architecture.md

- Storyboard-as-layer:
  docs/Current_Storyboard_Architecture.md

- Next implementation order:
  docs/Current_Implementation_Roadmap.md
```

If a handoff detail is useful but missing from all relevant Current docs, move or summarize it into the most appropriate `Current_*` document.

Do not create a large new architecture document unless truly necessary. Prefer updating existing Current docs.

## 6. Desired final handoff 5+ shape

Replace handoff section 5+ with a short structure similar to this:

```md id="ds7xs8"
## 5. Current source-of-truth entry point

This handoff intentionally stays lightweight. It is not an architecture specification.

For current architecture policy, read:

- Docs index: `docs/Current_Docs_Index.md`
- Project architecture: `docs/Current_Project_Architecture.md`
- Implementation roadmap: `docs/Current_Implementation_Roadmap.md`
- Brush: `docs/Current_Brush_Architecture.md`
- Timeline: `docs/Current_Timeline_Architecture.md`
- Cut management: `docs/Current_Cut_Management_Architecture.md`
- Canvas / cache / storage: `docs/Current_Canvas_Cache_Storage_Architecture.md`
- Storyboard: `docs/Current_Storyboard_Architecture.md`

Before working on a module, read the matching Current document directly.

## 6. Current-doc rule

`Current_*` documents are the source of truth for current policy.
Old phase/task docs remain historical records and must not override the matching Current document.

## 7. Latest continuation note

Phase 212C slimmed handoff section 5+ into a lightweight Current-doc entry point.
Continue from `docs/Current_Docs_Index.md` and the relevant `Current_*` document before planning runtime work.
```

The exact wording may differ, but the final handoff should remain short and pointer-only.

## 7. Current docs check

After slimming handoff, verify that useful architecture information still exists in Current docs.

At minimum, Current docs must still preserve:

```txt id="1t9zuk"
- Project -> Track -> Cut -> Layer -> Frame -> Stroke
- Project / Track / Cut / Layer / Frame / Stroke boundaries
- Frame remains lightweight
- Heavy brush bitmap payloads live outside Frame
- BrushFrameStore owns heavy frame-local drawing payloads
- Stroke / PaintCommand / BrushFrameStore are conceptually distinct
- Cache images are derived, not source of truth
- Cut.duration is playback/export duration only
- Storyboard is ordinary Layer(kind: storyboard)
- activeCutId is session/controller state
- Current_* docs are source of truth
```

If any item is missing, add it to the appropriate Current doc, not to handoff.

## 8. Tests

Update architecture tests if needed so they protect the new intended handoff shape.

Tests should verify:

```txt id="b4v0v7"
- Handoff sections 0-4 still exist.
- Handoff sections 0-4 are not removed or renamed.
- Handoff section 5+ points to Current_Docs_Index.md and Current_* docs.
- Handoff section 5+ states that handoff is lightweight / not architecture policy.
- Handoff section 5+ does not contain large duplicated architecture sections such as "핵심 도메인 모델".
- Current docs still preserve required architecture policy.
```

Do not make tests brittle to exact punctuation or markdown backticks.

## 9. Out of scope

Do not do these:

```txt id="v0h7us"
- Do not modify runtime code under lib/.
- Do not implement new features.
- Do not rewrite all Current docs.
- Do not delete Phase_*_Codex_Task.md files.
- Do not restore obsolete non-phase docs.
- Do not move detailed architecture back into handoff.
- Do not change handoff sections 0-4.
```

## 10. Required checks

Run:

```bash id="s9l2yo"
dart format lib test
flutter analyze
flutter test
git diff --check
git status
```

If Dart/Flutter is unavailable, report that clearly.

## 11. Report

Report:

```txt id="vd9g53"
- Handoff sections 0-4 untouched
- Handoff section 5+ slimmed
- Handoff now pointer-only / lightweight
- Any useful handoff details moved to Current docs if missing
- Current docs still preserve required policies
- Architecture tests updated
- Runtime code unchanged
- Phase task docs preserved
- Check results
```
