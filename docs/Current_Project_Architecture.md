# Current Project Architecture

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool targeting a TVPaint-style production workflow, with influences from Clip Studio Paint, OpenToonz, Flash, and Photoshop. The project should remain lightweight, modular, and built around small explicit domain boundaries rather than a god object.

## Core domain hierarchy

```txt
Project -> Track -> Cut -> Layer -> Frame
```

Brush drawing source data is not embedded directly in this hierarchy. It is owned by brush/canvas storage such as `BrushFrameStore`, keyed by the relevant frame identity context.

- `Project` owns project metadata, FPS, tracks, and project-wide camera settings; it must not directly own rendering, UI, saving, undo, or brush runtime logic.
- `Track` owns ordered cuts.
- `Cut` owns its canvas settings, duration, metadata, and layers.
- `Layer` owns frames plus layer display metadata such as visibility, opacity, name, and kind.
- `Frame` owns lightweight identity, timing, name/label, and storyboard metadata. It does not directly own brush drawing source payloads, heavy bitmap payloads, baked surfaces, preview caches, playback caches, image caches, or dirty state.
- `Stroke` / `BrushPaintCommand` represents drawing/action source data where appropriate, but current brush architecture stores brush source payloads outside `Frame` through `BrushFrameStore` or an equivalent brush/canvas storage boundary.

## Project camera and Cut canvas

Brush T2 separates project camera size from cut canvas size.

```txt
Project.cameraSize = 1920 x 1080 by default
Cut.canvasSize = 2340 x 1654 by default
```

`Project.cameraSize` is the project-wide camera/output frame size. All Cuts in the Project share this camera output size unless a future explicit camera-output architecture changes the rule.

`Cut.canvasSize` is the drawing/storage canvas bounds for that Cut. Cuts may have different canvas sizes.

Brush T2 does not add a separate drawable-area model. Drawing bounds equal the active `Cut.canvasSize`.

Phase 226 adds a canvas viewport foundation for brush editing. The visible editor viewport area is UI/layout space, not storage space. `CanvasViewport` pan/zoom/fit/reset state is temporary UI-only view state used to display the inner `Cut.canvasSize` drawing canvas and convert pointer positions between viewport/widget-local coordinates and canvas-space coordinates. Viewport state must not become drawing source data, save/load data, playback data, camera transform data, or cache identity.

Brush source dabs remain committed in canvas-space coordinates. Pan/zoom changes how the drawing canvas is viewed, not what coordinates are stored.

The active canvas display is clipped to the active `Cut.canvasSize`. Pointer-down outside the canvas may start a stroke session, but only in-canvas source dabs are collected and committed. Leaving `Cut.canvasSize` while drawing does not cancel or commit the stroke session; re-entering starts a new visible stroke segment so the previous in-canvas dab is not connected to the re-entry dab across the outside gap.

Future Camera T1 remains only a candidate: camera layer or camera-like track, camera view rectangle, darkened outside-camera editing area, playback cropped to camera frame, and editable camera position, size, and rotation. Phase 226 does not implement camera source data, camera keyframes, camera persistence, playback cropping, or camera export behavior.

Planned output size concepts:

- Canvas export: output the active `Cut.canvasSize`.
- Camera export: output the `Project.cameraSize` frame.

Storyboard-style output, TDTS output, XDTS output, and other timesheet/storyboard output formats are future export/sheet features.

## Lightweight domain and value-object boundaries

This summary preserves current model context without turning the handoff into an architecture specification. Keep these value objects lightweight and independent from rendering/runtime payloads:

- Core IDs are identity/value objects: `ProjectId`, `TrackId`, `CutId`, `LayerId`, `FrameId`, and `StrokeId`. Display names are labels, not identity.
- Canvas coordinates are explicit value objects: `CanvasPoint` is canvas-space, `ViewportPoint` is viewport/widget-local space, and `CanvasViewport` performs pure coordinate conversion.
- `CanvasViewport` must remain independent from Flutter rendering/input types such as `Offset`, `PointerEvent`, `Canvas`, `Paint`, and `CustomPainter`.
- Brush context remains lightweight at the domain boundary: `BrushSettings` is a frozen/value snapshot stored with stroke-like source commands; `BrushPreset` is reusable preset metadata; `BrushPreset.name` is a display label; and `BrushPresetId` is preset identity.
- `Stroke` / `BrushPaintCommand` should not directly reference `BrushPreset`. `BrushInputSample` is pre-stroke input data, while `StrokePoint` or equivalent stored command points are stored coordinate data inside source drawing commands.

## Brush T2 source data boundary

Brush T2 should use the simplest source-data model that does not block future optimization:

```txt
BrushFrameStore
- BrushFrameKey -> BrushFrameDrawing

BrushFrameDrawing
- commands: List<BrushPaintCommand>
- hiddenCommandIds: Set<BrushPaintCommandId>

BrushStrokeCommand
- BrushFrameKey
- BrushPaintCommandId
```

Brush stroke undo/redo participates in the single global user undo/redo stack. Brush-specific undo/redo controls do not exist.

`visibleCommandCount` is intentionally not part of the T2 brush model. It is unnecessary when undo/redo is global and would duplicate history state.

`BrushStrokeCommand`-like history entries should remain lightweight references to `BrushFrameKey + BrushPaintCommandId` rather than carrying large copied stroke payloads.

## Ownership and module boundaries

- Project data, timeline UI, brush editing, canvas/cache/storage, storyboard overview, persistence, playback, and product UI policy should stay as separate modules with narrow interfaces.
- Avoid global singleton state and avoid collapsing project, timeline, brush, cache, UI, and persistence concerns into one coordinator.
- Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, or similar app-wide state-management packages unless a future phase explicitly plans that architecture.
- Runtime code should remain test-driven and modular; documentation phases must not change runtime behavior.

## Long-term layer system direction

QuickAnimaker v2 keeps Photoshop-class layer capability as a long-term quality target, but runtime work must not copy Photoshop's layer-folder model by default.

- Long-term candidates include blend modes, masks, clipping-like relationships, adjustment/effect-style layer behavior, richer opacity/compositing rules, and PSD-oriented import/export compatibility.
- Folder/group-style organization is not decided yet and should be designed separately for QuickAnimaker's animation/timesheet workflow rather than assumed to be identical to Photoshop folders.
- Layer names remain display labels; `LayerId` remains identity.
- Layer system work must preserve lightweight domain metadata and keep heavy bitmap/composite payloads in brush/canvas/cache/storage boundaries.
- Do not introduce layer groups, folders, masks, blend modes, clipping, adjustment layers, or PSD import/export without a dedicated current architecture update and phase/task plan.

## Current module sources

- Brush policy: `docs/Current_Brush_Architecture.md`
- Timeline policy: `docs/Current_Timeline_Architecture.md`
- Canvas/cache/storage policy: `docs/Current_Canvas_Cache_Storage_Architecture.md`
- Storyboard policy: `docs/Current_Storyboard_Architecture.md`
- Cut management: `docs/Current_Cut_Management_Architecture.md`
- UI / product interaction policy: `docs/Current_UI_Product_Policy.md`
- Roadmap: `docs/Current_Implementation_Roadmap.md`

## Frame material identity

Same frame name means same drawing material inside the relevant layer. A non-empty frame name is a material identity label, and duplicate independent `FrameId`s with the same non-empty name in the same layer should be prevented or resolved by linking rather than preserved as separate materials.

Linked frames share drawing material/source identity through the same `FrameId`, drawing strokes/material, and frame name. Linked material identity must stay separate from authored timeline placement.

Future linked drawing-material work may introduce a dedicated drawing/material/source id. Do not add that shortcut before brush/canvas storage ownership, save/load source-payload boundaries, and linked Cut/Layer policy are explicitly designed.

## Phase 228 canvas viewport and startup policy

Canvas brush input clips each raw pointer segment against the active `Cut.canvasSize` before generating visible source dabs. This lets fast inside/outside boundary crossings draw to the edge, start at the edge on re-entry, and avoid connecting outside gaps.

`CanvasViewport` remains editor-session UI state. The production brush route can keep the same viewport across frame, layer, and cut selection changes, while local canvas viewport panbars update only pan/zoom UI state and never mutate project, cut, frame, source dabs, playback, cache, save/load, or camera data. The vertical panbar belongs in the canvas editor shell right strip, and the horizontal panbar belongs in the bottom bar rather than overlaying the drawing canvas.

Production startup uses the default project/track/cut/layer helper flow instead of sample-only project data. The default cut canvas size remains sourced from the default cut helper.

## Phase 229 canvas panel shell and panbar contract

The brush canvas editor shell owns only editor-session viewport UI state. `CanvasViewport` continues to be a transient pan/zoom value that is synchronized with the parent editor session, but it is not written into Project, Cut, Layer, Frame, Stroke, playback/cache, camera/source, or save/load data.

The canvas panel shell has an explicit small-height layout contract: the title bar is clipped to the available height, the central canvas/right-strip row is given a non-negative height, and the bottom controls are intentionally compacted and clipped instead of forcing a vertical `RenderFlex` overflow. The shell keeps the title, content, right-strip panbar region, and bottom panbar/toolbar region structurally present even when the panel is resized to very small heights.

Canvas viewport panbars use `CanvasViewportPanMetrics` for pure, testable scrollbar math. Metrics are based on the painted panbar track extent on the active axis, not the cross-axis size. Thumb extent, thumb travel, and thumb start are always finite and constrained to the track. When content has no scroll range, `canScroll` is false and panbar drag is a no-op so a centered fit pan is preserved instead of snapping to the top-left.

Panbar drag maps like a normal scrollbar: `thumbDelta / thumbTravel = scrollDelta / maxScroll`, and canvas pan is the negative of scroll. Horizontal panbar movement controls `panX`; vertical panbar movement controls `panY`. During panbar drag, `BrushCanvasPanel` updates its local live viewport for responsive repainting and synchronizes the parent editor-session viewport once at drag end or cancel. Non-drag viewport actions such as zoom, fit, reset, and direct canvas panning still synchronize immediately.

## Phase 303 editor brush tool state and right-side panel boundary

The main editor treats brush size, opacity, color, and spacing as editor-session UI/tool state. `HomePage` owns the current `BrushToolState` and passes it to `MainCanvasBrushHost` / `BrushCanvasPanel` as drawing input. Brush setting mutation belongs to the right-side `BrushSettingsPanel`, not the canvas or host layer; no Provider, Riverpod, ChangeNotifier, Bloc, or app-wide state layer is involved.

Brush tool settings are kept out of Project, Cut, Layer, Frame, Stroke, cache, playback, camera, and save/load formats. Selection changes for cut/layer/frame retarget the brush host while preserving the current editor-session brush settings, and viewport pan/zoom remains a separate `CanvasViewport` state. Spacing affects future dab sampling only, and active strokes snapshot input settings at pointer down so mid-stroke UI changes affect future strokes rather than the current stroke.

Phase 303 also introduces reusable editor panel primitives (`EditorPanelFrame`, `EditorPanelHeader`, `EditorPanelBody`, and `EditorPanelDock`) plus the first right-side `EditorPanelDock` direction. The dock is UI layout state only and must not become project/source/save-load data. It is intended to support future Brush, Color, Layers, Navigator, Timeline, Storyboard, and Brush Preset panels without changing domain ownership.
