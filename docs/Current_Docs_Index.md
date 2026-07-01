# Current Docs Index

## Current source-of-truth docs

- Docs index: `docs/Current_Docs_Index.md`
- Handoff / conversation flow: `docs/Handoff_QuickAnimaker_v2_Current.md`
- Project architecture: `docs/Current_Project_Architecture.md`
- Implementation roadmap: `docs/Current_Implementation_Roadmap.md`
- Brush: `docs/Current_Brush_Architecture.md`
- Timeline: `docs/Current_Timeline_Architecture.md`
- Cut management: `docs/Current_Cut_Management_Architecture.md`
- Canvas / cache / storage: `docs/Current_Canvas_Cache_Storage_Architecture.md`
- Storyboard: `docs/Current_Storyboard_Architecture.md`
- UI / product interaction policy: `docs/Current_UI_Product_Policy.md`

## AI reading rule

Current_* docs are the source of truth for current architecture policy. Before planning or implementing in a module, read the matching `Current_*` document directly. Do not rely on old phase/task docs as current policy. Phase task docs are historical task/order records, not current architecture policy.

## Consolidated / deleted non-current docs

Useful current content was moved into the `Current_*` documents and obsolete non-phase source documents were deleted rather than kept as legacy redirects. Phase task docs and other task-order docs are preserved as historical records.

- `docs/Architecture.md`, `docs/Product_Direction_Notes.md` -> `docs/Current_Project_Architecture.md` and `docs/Current_Timeline_Architecture.md`
- `docs/Brush_Architecture_Current.md`, `docs/Bitmap_Canvas_Brush_Architecture.md`, `docs/Brush_App_Integration_Decisions.md`, `docs/Brush_V1_Complete.md`, `docs/Brush_V1_Integration_Review.md` -> `docs/Current_Brush_Architecture.md` and `docs/Current_Canvas_Cache_Storage_Architecture.md`
- `docs/Active_Cut_State_Design.md`, `docs/Cut_Management_Policy.md` -> `docs/Current_Cut_Management_Architecture.md`
- `docs/Timeline_Stabilization_Checkpoint.md`, `docs/LongTerm_Timeline_Range_Semantics.md`, `docs/LongTerm_Roadmap_After_Phase_150.md` -> `docs/Current_Timeline_Architecture.md`, `docs/Current_Canvas_Cache_Storage_Architecture.md`, and `docs/Current_Implementation_Roadmap.md`
- `docs/Storyboard_Work_Roadmap.md` -> `docs/Current_Storyboard_Architecture.md` and `docs/Current_Implementation_Roadmap.md`
- Compact production-tool UI principles are preserved in `docs/Current_UI_Product_Policy.md`.

## Current-doc maintenance rule

If a module has a `Current_*` document, update that document when architecture policy changes. Old phase/task docs may explain why a phase happened, but they must not override current docs.
