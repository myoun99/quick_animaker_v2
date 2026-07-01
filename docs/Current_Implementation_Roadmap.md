# Current Implementation Roadmap

This roadmap records current future direction only. Old phase-by-phase documents are historical task/order records, not current policy. Runtime implementation may lag behind current architecture policy; when that happens, keep implementation phases small enough to preserve behavior while moving toward the current docs.

## Status

- Docs consolidation is complete: `Current_*` documents are the source of truth, and the handoff should stay lightweight.
- Historical `Phase_*_Codex_Task.md` and other task-order files remain useful for sequence/context, but they must not override current architecture documents.
- Runtime brush, canvas/cache/storage, storyboard, save/load, and playback behavior may not yet implement every policy described in the current docs.
- Documentation-only phases should not modify runtime code and should reinforce tests that protect architecture meaning rather than exact markdown punctuation.

## Near-term order

1. Brush production integration / implementation direction:
   - Preserve Brush V1 smoke/dev context without wiring old smoke routes or debug UI back into production navigation.
   - Continue moving production brush editing toward Deferred Bake Hybrid Brush History with `UnifiedUndoHistory`, `BrushFrameStore`, live paint commands, deferred bake commands, and baked base surfaces.
   - Keep user-facing undo based on recent live paint/stroke-like commands, not tile deltas.
2. Canvas/cache/storage foundation before heavy playback or save/load work:
   - Establish clear ownership for frame-local drawing payloads outside lightweight `Frame` metadata.
   - Treat preview/composite cache images as derived data that can be invalidated and rebuilt.
   - Keep timeline range semantics out of storage validity decisions.
3. Storyboard panel work:
   - Improve overview/planning interactions only after preserving storyboard-as-layer semantics.
   - Keep storyboard data inside ordinary `Layer(kind: storyboard)` entries in `Cut.layers`.
   - Do not turn `StoryboardPanel` into a brush drawing canvas unless a future current document explicitly changes the policy.
4. Save/load foundation:
   - Persist project data and source drawing payloads through explicit repository/storage boundaries.
   - Distinguish durable source payloads from derived caches that may be rebuilt.
5. Playback/cache implementation:
   - Use prepared preview/composite bitmap cache images for playback.
   - Do not replay live paint commands, rerun brush rasterization, or composite every layer from scratch when a valid cache exists.

## Long-term candidates to preserve

These ideas are intentionally preserved as long-term candidates. They are not current implementation scope unless a future phase explicitly updates the matching `Current_*` document and task plan.

- Lightweight `lastActiveCutId` project-open metadata may be added later to restore the last viewed/edited Cut on reopen. It must remain separate from volatile `activeCutId` editing-session state and must not imply saving undo/redo history.
- Linked Cut, Linked Layer, cross-layer linked paste, and cross-cut linked paste remain future candidates for shared drawing/material workflows. They must preserve the separation between drawing material/source sharing and authored timeline placement/timing.
- A project-level or repository-level material/source ownership model may be needed later for robust cross-layer or cross-cut sharing. Do not introduce it as a shortcut before brush/canvas storage ownership and save/load boundaries are stable.
- UI should remain compact and production-tool-oriented. When UI policy changes, update `docs/Current_UI_Product_Policy.md` rather than scattering UI principles through phase task docs.

## Not yet

- Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad app-wide state management.
- Do not restore deleted obsolete non-phase docs or deleted Brush V1 workspace routes.
- Do not make `Cut.duration` decide authored data extent, editability, cache storage validity, or frame bitmap existence.
- Do not add `Cut.storyboardLayer.panels` or a separate storyboard persistence system.
- Do not make tile delta the user-facing brush undo model.
- Do not persist undo/redo history in project save files.
- Do not implement Linked Cut, Linked Layer, cross-layer linked paste, cross-cut linked paste, or project-level material/source ownership without a dedicated current architecture update.

## Dependency notes

- Brush payload ownership comes before robust save/load and playback because both need a stable distinction between source drawing data and derived caches.
- Canvas/cache/storage policy depends on brush architecture: heavy bitmap payloads and paint command buffers belong in `BrushFrameStore` or an equivalent frame-keyed store, while `Project`, `Cut`, `Layer`, and `Frame` remain lightweight domain metadata.
- Save/load must persist source project data and source drawing payloads; derived preview/playback caches may be stored as optimization metadata only if they can be safely invalidated and rebuilt.
- Playback depends on prepared cache/composite generation. The live playback path should consume valid preview/composite images, not execute brush editing commands.
- Storyboard export should begin with Primary Track output by default; selected-track export and full composite output are future optional features.
