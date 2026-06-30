# Current Implementation Roadmap

This roadmap records current future direction only. Old phase-by-phase documents are historical task/order records, not current policy.

1. Docs consolidation: keep handoff lightweight and use `Current_*` documents as source of truth.
2. Brush production integration cleanup: preserve Brush V1 smoke/dev context while preventing accidental production route wiring.
3. Brush current architecture implementation: move toward Deferred Bake Hybrid Brush History with `UnifiedUndoHistory`, `BrushFrameStore`, live paint commands, deferred bake commands, and baked base surfaces.
4. Canvas/cache/storage foundation aligned with brush architecture: derived preview/composite bitmap caches, dirty tracking, and storage boundaries that do not depend on timeline range semantics.
5. Storyboard panel work: improve overview/planning interactions while preserving storyboard-as-layer semantics.
6. Save/load: persist project data and future bitmap payload/cache metadata through explicit repository boundaries.
7. Playback/cache implementation: use prepared preview/composite bitmap cache images; playback must not replay live paint commands or run brush rasterization.
