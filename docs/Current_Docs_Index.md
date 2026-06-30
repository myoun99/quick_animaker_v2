# Current Docs Index

This directory keeps a small `Current_`-prefixed source-of-truth architecture set alongside historical phase task/order records. The `Current_*` files are current policy. `Phase_*_Codex_Task.md` and other `*_Task.md` files are historical records only and must not be used as current architecture policy when they conflict with `Current_*` docs.

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
- Phase task/order docs are allowed historical records, but they are not current architecture policy.
- If module-specific detail is needed, add it to the relevant `Current_*` document rather than the handoff.
- Runtime code policy lives in code and tests; these docs describe architecture direction without changing runtime behavior by themselves.
