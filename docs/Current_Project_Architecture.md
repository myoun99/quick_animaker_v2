# Current Project Architecture

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool targeting a TVPaint-style production workflow, with influences from Clip Studio Paint, OpenToonz, Flash, and Photoshop. The project should remain lightweight, modular, and built around small explicit domain boundaries rather than a god object.

## Core domain hierarchy

```txt
Project -> Track -> Cut -> Layer -> Frame -> Stroke
```

- `Project` owns project metadata, FPS, and tracks; it must not directly own rendering, UI, saving, undo, or brush logic.
- `Track` owns ordered cuts.
- `Cut` owns its canvas settings, duration, metadata, and layers.
- `Layer` owns frames plus layer display metadata such as visibility, opacity, name, and kind.
- `Frame` owns lightweight timing/metadata and stroke references; heavy brush bitmap payloads belong outside the frame model.
- `Stroke` represents drawing/action data where appropriate, but current brush architecture separates transient paint commands and bitmap payload storage from durable frame metadata.

## Lightweight domain and value-object boundaries

This summary preserves current model context without turning the handoff into an architecture specification. Keep these value objects lightweight and independent from rendering/runtime payloads:

- Core IDs are identity/value objects: `ProjectId`, `TrackId`, `CutId`, `LayerId`, `FrameId`, and `StrokeId`. Display names are labels, not identity.
- Canvas coordinates are explicit value objects: `CanvasPoint` is canvas-space, `ViewportPoint` is viewport/widget-local space, and `CanvasViewport` performs pure coordinate conversion.
- `CanvasViewport` must remain independent from Flutter rendering/input types such as `Offset`, `PointerEvent`, `Canvas`, `Paint`, and `CustomPainter`.
- Brush context remains lightweight at the domain boundary: `BrushSettings` is a frozen/value snapshot stored with `Stroke`; `BrushPreset` is reusable preset metadata; `BrushPreset.name` is a display label; and `BrushPresetId` is preset identity.
- `Stroke` should not directly reference `BrushPreset`. `BrushInputSample` is pre-stroke input data, while `StrokePoint` is stored coordinate data inside `Stroke`.

## Ownership and module boundaries

- Project data, timeline UI, brush editing, canvas/cache/storage, storyboard overview, persistence, playback, and product UI policy should stay as separate modules with narrow interfaces.
- Avoid global singleton state and avoid collapsing project, timeline, brush, cache, UI, and persistence concerns into one coordinator.
- Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, or similar app-wide state-management packages unless a future phase explicitly plans that architecture.
- Runtime code should remain test-driven and modular; documentation phases must not change runtime behavior.

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
