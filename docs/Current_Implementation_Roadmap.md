# Current Implementation Roadmap

## Purpose

The current implementation direction is a stable bitmap-first animation vertical slice that can grow into a professional frame-by-frame tool without sacrificing testability. Each phase should keep the app runnable and covered by tests.

## Protected development rules

- Implement only the assigned phase. Do not sneak in future-phase features.
- Keep every phase testable; run formatting, analysis, and tests before completion.
- Prefer simple working code over speculative over-engineering.
- Preserve the Project -> Track -> Cut -> Layer -> Frame -> Stroke hierarchy.
- Avoid god objects; split responsibilities into models, services, controllers, rendering/cache modules, and UI.
- Runtime code must not be changed by documentation-only phases.

## Current roadmap direction

1. Preserve stable foundations: immutable domain models, typed IDs, command-based undo/redo, save/load, timeline basics, storyboard overview, brush settings, brush input sampling, and canvas viewport coordinate conversion.
2. Continue bitmap-first canvas work through small model/service phases before UI expansion.
3. Keep brush architecture aligned with Deferred Bake Hybrid Brush History. User-facing brush undo is recent live paint-command based through `UnifiedUndoHistory`; the deferred bake buffer is not user-facing undo.
4. Build cache and playback behavior so playback uses prepared preview/composite bitmap cache images and does not replay live paint commands or run live brush rasterization.
5. Expand StoryboardPanel cautiously with interaction and layout tests while keeping storyboard data as ordinary `LayerKind.storyboard` layers.

## Not in current scope unless explicitly assigned

Full PSD compatibility, advanced Photoshop brush import, audio editing, cloud collaboration, 3D camera systems, vector-first architecture, persistent infinite history UI, and large timeline virtualization rewrites are not current implementation targets unless a phase explicitly asks for them.
