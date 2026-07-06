# Current UI Product Policy

## Status

This is the current source-of-truth policy for QuickAnimaker v2 user-facing UI/product interaction principles.

Runtime implementation may lag behind this document. Future UI work should update this document when product interaction policy changes.

## Product UI goal

QuickAnimaker v2 is a production-oriented 2D bitmap animation tool for a real animator workflow. UI should favor practical production speed, clear tool affordances, and lightweight behavior over tutorial-like explanations.

The UI should feel closer to a compact production tool than an onboarding demo.

## Core UI principles

- Keep user-facing UI compact and practical.
- Prefer icon buttons with tooltips over long inline instructional text.
- Keep status text short and useful.
- Avoid tutorial-like long hints in persistent production UI.
- Avoid restoring deleted smoke/dev/debug routes into production navigation.
- Do not add debug-only controls to production UI unless a future current document explicitly plans them.
- Preserve stable semantic keys used by widget tests when changing UI structure.
- UI should not perform project mutations during build, layout, or read-only rendering.
- Mutating UI actions should call explicit helpers, controllers, commands, or repository boundaries rather than directly editing unrelated state.

## Interaction and architecture boundaries

- Project, timeline, brush editing, canvas/cache/storage, storyboard overview, playback, and persistence UI should remain separated by narrow interfaces.
- UI widgets should not become god objects that coordinate unrelated project, brush, cache, storage, persistence, and playback concerns.
- Do not introduce Provider, Riverpod, Bloc, hidden globals, or broad app-wide state-management packages for UI convenience unless a future phase explicitly designs that architecture.
- Lightweight, local Flutter built-ins (`ChangeNotifier` / `ValueNotifier`) are allowed for focused editor rebuild isolation — for example the `EditorSessionManager` that backs `HomePage`. Keep them narrow (one editor/session scope, no app-wide singleton) and prefer plain widget state where it already suffices.
- UI state should remain small and local where possible. Shared editing/session state should use focused boundaries such as editing-session state, controllers, commands, or dedicated services.

## Tool controls

- Prefer compact controls that are understandable to experienced animation users.
- When labels are necessary, keep them short.
- Tooltips may carry slightly longer explanations, but they should still be concise.
- Avoid replacing production controls with explanatory cards unless the phase is specifically about onboarding, help, or documentation UI.

## Panel-specific boundaries

Phase 303 establishes the first long-term editor panel frame direction. Reusable panel primitives now include `EditorPanelFrame`, `EditorPanelHeader`, `EditorPanelBody`, and `EditorPanelDock`. These primitives are intended to be reused by future Brush, Color, Layers, Navigator, Timeline, Storyboard, Brush Preset, and tool-property panels instead of creating one-off panel chrome for each feature.

`EditorPanelDock` is the first durable panel dock direction, not a full docking framework. It supports a `side` (left/right); the brush library + tool-property dock sits on the LEFT of the canvas, Clip-Studio-like. It should remain compact editor UI and must not add drag-to-dock, floating panels, workspace persistence, source-data changes, save/load schema changes, or broad app-wide state management unless a later phase explicitly designs those systems.

Panel scrollbars are shared UI: wrap panel scrollables in `PanelScrollbar` (`lib/src/ui/panels/panel_scrollbar.dart`) and pad the scroll-end edge by `panelScrollbarGutter` so the always-visible bar owns allocated space instead of overlaying content. Visuals come from the app-level `ScrollbarThemeData`; do not restyle scrollbars per panel. The timeline's custom scrollbar rails already reserve their own space and stay as they are.

The right dock stacks `BrushPresetPanel` ("Brushes" — the preset library list with tip previews, import, save, delete) above `BrushSettingsPanel` (the editable tool properties). This is the Clip-Studio-like list/properties split; future panels (for example a tool panel) join the same dock as additional `EditorPanelFrame` children. `BrushSettingsPanel` remains the only editable brush settings UI. `BrushCanvasPanel` should stay focused on the canvas viewport, panbars, zoom/fit/reset controls, and drawing input. Do not reintroduce duplicate editable brush settings into the canvas panel or route brush setting mutation callbacks through the canvas/host layer.

This is a Photoshop-like panel and brush-settings structure, but it is not Photoshop ABR compatibility and does not claim exact Photoshop brush engine parity.

- `TimelinePanel` remains the public timeline entry point and should not be refactored for unrelated UI work without a test-proven reason or explicitly planned phase.
- The timeline is sectioned like a Japanese paper timesheet (`timeline_section_policy.dart`): drawing cels, then SE (slot reserved — no LayerKind yet), then camera. Raw/model order keeps sections in that order (camera last); the horizontal timeline reverses it (camera rows on top), and the X-sheet reads left-to-right like a sheet (ACTION cel columns, then CAMERA). Display enforces the section order defensively via `sectionedLayerOrder`; section boundaries draw a heavier divider (top edge in horizontal rows, left edge in X-sheet columns) without changing row/column geometry. Future per-kind lane rendering (SE preview, camera instruction wedges, AE-style camera keyframe lanes) must dispatch by LayerKind inside the shared cell/row widgets so both orientations stay in lockstep.
- The X-sheet (`XSheetTimelineGrid`) is the horizontal timeline transposed, not a separate implementation: it reuses the shared frame-range, offset-resolution, virtualization-plan, coordinate, cell-style/block-visual, selected-exposure-range, playhead, and cut-end-boundary policies with the axes swapped (transposed `TimelineGridMetrics`; frame axis fed through the plan's "horizontal" inputs). New frame-axis behavior must be implemented in those shared policies/widgets with an `Axis` parameter so both orientations gain it together — never as X-sheet-only or horizontal-only forks.
- Comma-drag exposure editing is the first shared frame-axis interaction (`timeline_exposure_comma_drag_policy.dart` / `timeline_exposure_comma_drag_handle.dart`): the active layer's selected drawing exposure block shows a drag grip at its trailing edge, and dragging along the frame axis steps the existing increase/decrease exposure commands one frame per crossed cell (one undo entry per step, same as the toolbar buttons). The grip appears only when the block has a real end edge — a following authored entry — because the last block's trailing held run bleeds to the window edge by long-term range semantics and cannot be shortened; camera rows never get a grip (their cells mirror keyframes, not exposure runs). The step math is orientation-free and dispatch is by LayerKind inside the shared cell/row widgets.
- `StoryboardPanel` remains an overview/planning surface, not a brush drawing canvas, unless a future current document explicitly changes that policy. It OWNS the cut lifecycle UI: the cut management actions (new/rename/note/canvas size/duplicate/move/delete, acting on the active cut) live in its toolbar. The top toolbar keeps only the quick cut-switcher chips (select + drag reorder); undo/redo and export live in the AppBar.
- Brush editing UI must respect the current brush architecture and must not reintroduce deleted Brush V1 smoke workspace routes into production navigation.
- Canvas viewport controls should remain compact and local to the editor surface: pan, zoom, fit-to-view, and reset-view are UI-only operations and must not mutate drawing source data, `Cut.canvasSize`, `Project.cameraSize`, save/load data, playback behavior, or cache identity.
- The visible editor viewport area is separate from the inner `Cut.canvasSize` drawing canvas. Fit and zoom controls should use the visible editor viewport size, while brush dabs remain canvas-space coordinates.
- Canvas drawing display should be clipped to the inner `Cut.canvasSize`; pointer sessions may begin outside that canvas, but outside movement is not visible source data and re-entry starts a new visible segment without connecting across the outside gap.
- The compact canvas editor shell is local canvas UI: top status/title bar, center viewport content, right pan/scroll strip, and bottom zoom/fit/reset controls. It must not introduce source data, persistence, playback, camera, or app-wide state-management changes.
- Camera T1 is future work only: do not add editable camera layers, camera keyframes, camera transform source data, playback cropping, or export changes through canvas viewport UI.
- Playback UI should consume prepared preview/composite cache policy rather than encouraging live brush command replay during playback.

## Manual check expectations

When a UI phase changes visible behavior, manual checks should confirm:

1. App launches normally.
2. Existing core flows still work.
3. New controls are compact and production-oriented.
4. No unintended debug/smoke UI appears in production navigation.
5. Stable UI keys expected by tests remain preserved unless the phase explicitly updates those tests.

For documentation-only or internal command/helper phases, manual UI checks may be optional, but PR review should still state whether visible behavior is expected to change.
