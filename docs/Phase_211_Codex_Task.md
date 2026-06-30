# Phase 211 Codex Task

## Goal

Consolidate the docs directory into a small set of `Current_`-prefixed source-of-truth architecture and roadmap documents while preserving phase task/order records as historical records.

Use the prefix:

```text
Current_
```

Do not create new `LongTerm_` source-of-truth documents.

## Critical scope corrections

Phase task documents are not deletion candidates.

Keep all files matching these patterns:

```text
docs/Phase_*_Codex_Task.md
docs/*_Task.md
```

These files are historical task/order records. They may describe old phase instructions, superseded decisions, or past implementation orders. They must not be treated as current architecture policy when they conflict with `Current_*` documents.

## Required current docs

The current source-of-truth document set is:

```text
docs/Current_Docs_Index.md
docs/Current_Project_Architecture.md
docs/Current_Implementation_Roadmap.md
docs/Current_Brush_Architecture.md
docs/Current_Timeline_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Storyboard_Architecture.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

## Consolidation rules

- Keep the `Current_*` consolidation direction.
- Extract useful current content from obsolete non-phase docs before deleting them.
- Prefer deleting obsolete non-phase docs over leaving legacy notices.
- Handoff remains and may keep the Current docs index at section 5.
- Do not edit handoff sections 0 through 4.
- Handoff should be an entry/rules/index document, not detailed module architecture.
- Module-specific source of truth should live in `Current_*` docs.
- Runtime code must remain unchanged.

## Rename / consolidate

- `docs/Brush_Architecture_Current.md` -> `docs/Current_Brush_Architecture.md`.
- Integrate current project architecture content into `docs/Current_Project_Architecture.md`.
- Integrate current timeline content into `docs/Current_Timeline_Architecture.md`.
- Integrate current roadmap content into `docs/Current_Implementation_Roadmap.md`.
- Integrate current canvas/cache/storage content into `docs/Current_Canvas_Cache_Storage_Architecture.md`.
- Integrate current storyboard content into `docs/Current_Storyboard_Architecture.md`.

## Delete obsolete non-phase docs when safe

Delete obsolete non-phase docs after useful current content has been integrated, including old long-term drafts, review docs, complete docs, checkpoint docs, decision docs, old brush docs, and memo docs that are no longer current.

Do not delete `Phase_*_Codex_Task.md` or other `*_Task.md` files.

Do not leave active docs pointing to deleted non-phase files.

## Current docs index policy

`docs/Current_Docs_Index.md` must state:

- `Current_*` docs are current source of truth.
- `Phase_*_Codex_Task.md` and other `*_Task.md` files are historical records.
- Phase task docs must not be used as current architecture policy.

## Architecture tests

Add/update architecture tests to protect:

- Required `Current_*` docs exist.
- `Current_Docs_Index.md` references all current docs.
- Handoff sections 0 through 4 remain present.
- Phase task/order docs are allowed in `docs/`.
- Obsolete non-phase docs are not active docs.
- Module-specific current docs contain their key rules.
- Tile delta is not current user-facing brush undo policy.
- Runtime code is unchanged.

Tests must not enforce that the docs directory has exactly 8 files.

## Required commands

Run:

```bash
find docs -maxdepth 1 -type f | sort

rg "LongTerm_|Brush_Architecture_Current|Bitmap_Canvas_Brush_Architecture|Brush_App_Integration_Decisions|Timeline_Stabilization_Checkpoint|LongTerm_Timeline_Range_Semantics|LongTerm_Roadmap_After_Phase_150|Architecture.md" docs test

rg "tile delta|TileDelta|Undo source = tile delta data|Undo should prefer tile deltas" docs test

rg "Current_Docs_Index|Current_Project_Architecture|Current_Implementation_Roadmap|Current_Brush_Architecture|Current_Timeline_Architecture|Current_Canvas_Cache_Storage_Architecture|Current_Storyboard_Architecture" docs test
```

Then run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

## Report

Report:

- Phase_*_Codex_Task.md restored.
- Phase_211_Codex_Task.md corrected.
- Current_* docs kept.
- Phase task docs preserved as historical task/order records.
- Obsolete non-phase docs deleted.
- PR body/report updated so it does not say legacy Phase_* docs were removed.
- Tests updated.
- Runtime code unchanged.
- Check results.
