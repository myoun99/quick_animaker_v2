# Current Docs Index

This directory is intentionally small. The files below are the only current source-of-truth architecture and roadmap documents. Older phase tasks, review notes, checkpoint notes, decision memos, and LongTerm-prefixed drafts were consolidated and removed.

## Current source-of-truth documents

- [Current_Project_Architecture.md](Current_Project_Architecture.md) — product vision, domain hierarchy, and cross-module rules.
- [Current_Implementation_Roadmap.md](Current_Implementation_Roadmap.md) — current implementation direction and guarded future milestones.
- [Current_Brush_Architecture.md](Current_Brush_Architecture.md) — brush, drawing-state, undo, deferred bake, and playback-cache policy.
- [Current_Timeline_Architecture.md](Current_Timeline_Architecture.md) — timeline range semantics, virtualization direction, and timeline UI rules.
- [Current_Canvas_Cache_Storage_Architecture.md](Current_Canvas_Cache_Storage_Architecture.md) — bitmap canvas, cache, storage, performance, and persistence direction.
- [Current_Storyboard_Architecture.md](Current_Storyboard_Architecture.md) — storyboard panel model, UI semantics, protected keys, and roadmap.
- [Handoff_QuickAnimaker_v2_Current.md](Handoff_QuickAnimaker_v2_Current.md) — entry/rules/index handoff. Sections 0 through 4 remain user-owned.

## Rules

- Use the `Current_` prefix for source-of-truth docs.
- Do not use removed long-term draft documents as active references.
- Do not resurrect deleted phase task docs as current policy.
- If module-specific detail is needed, add it to the relevant `Current_*` document rather than the handoff.
- Runtime code policy lives in code and tests; these docs describe architecture direction without changing runtime behavior by themselves.
