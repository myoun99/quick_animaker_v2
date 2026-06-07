# Cut Structure Audit

## Current Summary

QuickAnimaker v2.1 already has a structural `Project -> Track -> Cut -> Layer -> Frame -> Stroke` model hierarchy, and the persistence layer round-trips that hierarchy through JSON. In the running Flutter app, however, the editing workflow is still effectively a single implicit cut/timeline context:

- `HomePage` creates one sample project with one track and one cut identified by the static `CutId('sample-cut')`.
- `LayerController`, `TimelineController`, and `CanvasView` are constructed around that one `CutId`.
- The timeline UI receives only the active cut's layer list, active layer id, and current frame index; it has no project, track, cut list, or cut selection concept.
- The canvas paints layers resolved for the supplied `CutId`, but the only supplied runtime cut id is the sample active cut.
- Repository methods can traverse all tracks/cuts to find ids, but many operations are keyed by only `LayerId` or `FrameId`, so they are structurally broad and not yet safe as an active-cut scoping boundary if ids are reused across cuts.

Phase 26 is documentation-only. No active cut state, cut switching UI, Storyboard Panel, runtime behavior change, schema change, save/load change, undo/redo change, timeline behavior change, canvas behavior change, renderer change, brush-engine change, or test change is introduced here.

## Model Usage

### Hierarchy representation

- `Project` owns an immutable list of `Track` values through `tracks` and serializes/deserializes that list in `toJson` / `fromJson`.
- `Track` owns an immutable list of `Cut` values through `cuts` and serializes/deserializes that list. `TrackType` currently supports `video` and `audio`, though the UI sample uses one video track.
- `Cut` owns:
  - `CutId id`
  - `String name`
  - immutable `List<Layer> layers`
  - `int duration`
  - `CanvasSize canvasSize`
- `Layer` owns:
  - `LayerId id`
  - `String name`
  - immutable `List<Frame> frames`
  - `SplayTreeMap<int, TimelineExposure> timeline`
  - `SplayTreeMap<int, TimelineMark> marks`
  - visibility and opacity
- `Frame` owns:
  - `FrameId id`
  - `int duration`
  - immutable `List<Stroke> strokes`
  - optional `String? name`

### Answers to required model questions

- **Does `Project` contain tracks?** Yes. `Project.tracks` is the top-level child collection.
- **Does `Track` contain cuts?** Yes. `Track.cuts` is the per-track cut collection.
- **Does `Cut` contain layers?** Yes. `Cut.layers` is the per-cut layer collection.
- **Does `Cut` own canvas size?** Yes. `Cut.canvasSize` is part of the cut model and JSON.
- **Does `Cut` own or imply duration?** Yes. `Cut.duration` is part of the cut model and JSON. In current timeline behavior, the visible/editable timeline length is primarily derived by `TimelineController.totalFrameCount` from authored layer timelines rather than from `Cut.duration`.
- **Are there helper methods that assume the first track or first cut?** The core model classes themselves do not provide helper methods that pick `tracks.first` or `cuts.first`. Tests often build single-track/single-cut fixtures and assert `.single` hierarchy traversal, but that is test fixture shape rather than model behavior.
- **Are there direct shortcuts that bypass `Cut`?** The model hierarchy does not store layers directly on `Project` or `Track`; layers remain under `Cut`. The practical shortcuts appear in controllers/repository methods that locate layers or frames by id across all cuts rather than requiring a cut scope for every edit.

### Timeline/material model notes

- Timeline placement is layer-owned through `Layer.timeline`, not frame-owned.
- Marks are layer-owned through `Layer.marks`, not frame-owned.
- `TimelineExposure.drawing` references a `FrameId`; `TimelineExposure.blank` carries no `FrameId`.
- `Frame.duration` still exists, but recent timeline exposure behavior treats authored timeline entries as the selected timing unit when a frame has multiple authored uses.
- Frame material/source identity is currently represented by `FrameId` inside a layer. Multiple authored timeline entries can reference the same `FrameId` to represent linked uses of the same material.

## Repository / Service Usage

### `ProjectRepository`

`ProjectRepository` stores one current `Project` and exposes broad update methods:

- Project lifecycle:
  - `currentProject`
  - `hasProject`
  - `requireProject()`
  - `replaceProject()`
  - `clearProject()`
  - `updateProject()`
- Track operations:
  - `addTrack(Track track)`
  - `replaceTrack(Track track)`
  - `removeTrack(TrackId trackId)`
- Cut operation:
  - `addCut({required TrackId trackId, required Cut cut})`
- Layer/frame/stroke operations:
  - `addLayer({required CutId cutId, required Layer layer})`
  - `replaceLayer({required Layer layer})`
  - `updateLayer({required LayerId layerId, ...})`
  - `addFrame({required LayerId layerId, required Frame frame})`
  - `updateFrame({required FrameId frameId, ...})`
  - `addStroke({required FrameId frameId, required Stroke stroke})`

Current cut access patterns are mixed:

- `addCut` is correctly scoped by `TrackId`.
- `addLayer` is correctly scoped by `CutId`.
- `replaceLayer` / `updateLayer` search every track and cut for a matching `LayerId` without also requiring a `CutId`.
- `addFrame` searches every track and cut for a matching `LayerId` without also requiring a `CutId`.
- `updateFrame` and `addStroke` search every track, cut, and layer for a matching `FrameId` without requiring a `CutId` or `LayerId`.

This means the repository is structurally multi-cut-capable for storing cuts, but many edit operations are practically single-cut-safe only if ids are globally unique or if the app continues to operate in one active cut context.

### JSON serialization/deserialization

JSON round-trips follow the model tree:

```text
Project JSON
  tracks[]
    cuts[]
      layers[]
        frames[]
        timeline[] / timeline{}
        marks[] / marks{}
```

Important notes:

- `ProjectJsonSerializer` delegates to `Project.toJson()` and `Project.fromJson()`.
- `ProjectFileService` saves and loads whole projects through `ProjectJsonSerializer`.
- `Track.toJson()` serializes all cuts in `cuts`.
- `Cut.toJson()` serializes `layers`, `duration`, and `canvasSize`.
- `Layer.toJson()` serializes frames, timeline exposure entries, marks, visibility, and opacity.
- The serializer appears structurally capable of preserving multiple tracks and multiple cuts because it serializes lists at both levels.
- Save/load behavior is still practically exercised by one-cut UI/project fixtures, and no save/load UI exists for selecting a different active cut after load.

### Commands and history

Commands snapshot/restore full projects or replace layers through the repository:

- `AddCutCommand` requires a `TrackId` and `Cut`.
- `AddLayerCommand` requires a `CutId` and `Layer`.
- `AddFrameCommand` requires only a `LayerId` and `Frame`.
- `AddStrokeCommand` requires only a `FrameId` and `Stroke`.
- `UpdateLayerTimelineCommand` stores before/after `Layer` values and replaces by `LayerId`.

The command layer therefore mirrors the repository split: cut creation and layer creation are explicitly scoped, while timeline/frame/stroke edits rely on layer or frame ids without an active-cut parameter.

## Controller Usage

### `CanvasController`

`CanvasController` is constructed with a repository, history manager, fallback `FrameId`, and optional `LayerController` / `TimelineController`.

Current behavior:

- `currentFrameId` resolves through active layer/timeline when controllers are present, otherwise falls back to the supplied callback or fallback `FrameId`.
- `strokes` returns the selected active frame's strokes when layer/timeline controllers exist; otherwise it searches the whole project for the current `FrameId`.
- `endStroke()` adds the stroke to the resolved `FrameId` through `AddStrokeCommand`, which ultimately updates by `FrameId` across the repository.
- `layerFramesForCut(CutId cutId)` can resolve visible paintable layer/frame pairs for a supplied cut id by searching all tracks/cuts. If there is no `TimelineController`, it falls back to the first frame in each layer; with a timeline controller, it resolves each layer at the current frame index.
- Undo/redo stores frame indexes, not cut ids. This works for the current single implicit cut but would need cut-aware handling if undo can cross active cuts later.

Multi-cut risk:

- Drawing is selected through the active layer/timeline pair, but persistence of a stroke is by `FrameId` only.
- The fallback `_findFrame` searches all tracks/cuts by `FrameId`.
- Undo frame-index navigation is not scoped to a cut.

### `LayerController`

`LayerController` is constructed with a fixed `CutId` and uses `_findCut()` to locate that cut by searching all project tracks/cuts.

Current behavior:

- `layers` returns `_findCut().layers`.
- `activeLayerId` is controller-local state and implicitly belongs to the controller's fixed cut.
- If no initial layer is supplied, the active layer defaults to the first layer in the cut.
- `addLayerWithDefaults()` creates an empty layer with a blank exposure at index 0 and adds it to the controller's fixed cut.
- Visibility and opacity changes call repository `updateLayer` by `LayerId` only.

Multi-cut risk:

- Layer selection is scoped by the controller's constructor `CutId`, but the app has no higher-level active cut state that can rebuild/switch this controller.
- Layer mutations after selection rely on `LayerId` only in the repository.
- If `LayerId`s are not globally unique across cuts, repository-level updates may affect the first matching layer found while traversing the project.

### `TimelineController`

`TimelineController` is constructed with a fixed `CutId` and maintains a single `_currentFrameIndex`.

Current behavior:

- `_findCutOrNull()` searches all project tracks/cuts for the fixed `CutId`.
- `totalFrameCount` is derived from timelines in the fixed cut's layers.
- Frame/cell resolution methods operate on `Layer` objects passed by the UI/controller.
- New drawings, blanks, marks, delete, linked paste, rename, link, and exposure changes operate on a `LayerId` and the controller's `_currentFrameIndex`.
- `_requireLayer()` looks up the layer inside the controller's fixed cut before editing.
- `UpdateLayerTimelineCommand` then replaces the layer by `LayerId` in the repository.
- Exposure increase/decrease targets `_entryForExposureEdit`, which prefers the selected authored entry at the current frame index; only if no selected entry matches and a `frameId` is supplied does it fall back to the first authored entry for that `FrameId`.
- When a frame has multiple authored timeline uses, exposure changes shift timeline entries but avoid treating `Frame.duration` as a global duration update for every linked use.

Multi-cut risk:

- `_currentFrameIndex` is a single controller-local timeline position, not a per-cut selection map.
- Timeline selection does not carry a `CutId` beyond the controller instance.
- Edits start cut-scoped in `_requireLayer()`, but final repository replacement is by `LayerId` only.
- There is no controller-level API for changing active cut or validating whether selected layer/frame state remains valid after a cut switch.

## UI Usage

### `HomePage`

`HomePage` is the strongest single-cut assumption in runtime UI:

- It declares static `_cutId = CutId('sample-cut')` and `_frameId = FrameId('sample-frame')`.
- It creates one `ProjectRepository` seeded with `_createSampleProject()`.
- `_createSampleProject()` creates one project, one track, one cut, and two layers.
- It constructs one `LayerController`, one `TimelineController`, and one `CanvasController`, all tied to `_cutId`.
- It passes `_cutId` directly to `CanvasView`.
- It passes `_layerController.layers`, `_layerController.activeLayerId`, and `_timelineController.currentFrameIndex` to `TimelinePanel`.
- Copy/paste linked frame state stores `LayerId`, `FrameId`, and optional frame name, but no `CutId`; this is acceptable for same-layer linked paste in the single-cut UI, but it is not enough for cross-cut-safe state.

There is no current UI for:

- listing cuts,
- selecting an active cut,
- switching cuts,
- showing a storyboard panel,
- showing a global track/cut timeline,
- preserving separate selected layer/cell state per cut.

### Timeline UI

`TimelinePanel`, `LayerTimelineGrid`, and `XSheetTimelineGrid` are cut-agnostic widgets. They receive:

- `List<Layer> layers`
- `LayerId? activeLayerId`
- `int currentFrameIndex`
- `int frameCount`
- callbacks for selecting layer/frame and mutating layer controls

This makes them reusable for a future active cut, but today they display exactly the layer list supplied by `HomePage` from the one implicit cut. They do not know about `Project`, `Track`, `Cut`, `CutId`, or a cut switch event.

Layer selection in these widgets is scoped only by `LayerId` and the provided layer list. Selected cell state is `activeLayerId + currentFrameIndex`, with no `CutId`.

### Canvas UI

`CanvasView` optionally accepts a `CutId` and asks `CanvasController.layerFramesForCut(cutId)` for paintable layers. This is a useful seam for future active-cut rendering. Current limitations:

- The only runtime `cutId` passed by `HomePage` is the static sample cut id.
- Pointer input goes through `CanvasController` and ultimately edits the resolved active frame via `FrameId`.
- Canvas size is not currently read from `Cut.canvasSize` by the widget layout; the UI uses available widget space.

`StrokePainter` paints the provided paintable layers and active stroke points. It is not cut-aware; it simply paints the resolved data it receives.

### Layer UI

`LayerPanel` is a reusable layer-list widget that receives only layers and an active layer id. It has no project/track/cut context. It can be reused for a future active cut, but it must be fed cut-scoped layers by a higher-level cut-aware state/controller.

## Test Coverage

Current tests cover the hierarchy and single-cut timeline behavior well, but they mostly use one-cut fixtures.

### Model tests

- `test/models/project_hierarchy_test.dart` verifies the full `Project -> Track -> Cut -> Layer -> Frame -> Stroke` hierarchy and immutable child lists.
- `test/models/copy_with_test.dart` covers copy behavior across model objects, including `Cut` and surrounding hierarchy.
- `test/models/id_test.dart` covers typed ids including `CutId`.
- `test/models/json_serialization_test.dart` round-trips a full project hierarchy and timeline-related layer fields.
- `test/models/timeline_exposure_test.dart` and `test/models/timeline_mark_test.dart` cover timeline exposure/mark value behavior.

### Service tests

- `test/services/project_repository_test.dart` covers project replacement, track/cut/layer/frame/stroke operations, and error behavior.
- `test/services/project_json_serializer_test.dart` and `test/services/project_file_service_test.dart` cover save/load and JSON decode/encode behavior.
- `test/services/commands_test.dart`, `test/services/history_manager_test.dart`, and `test/services/update_layer_timeline_command_test.dart` cover command/history behavior.

### Controller tests

- `test/controllers/layer_controller_test.dart` covers a controller fixed to one `CutId`, active layer selection, adding layers, visibility, and opacity.
- `test/controllers/timeline_controller_test.dart` covers current frame selection, timeline resolution, drawing/blank creation, deletion, marks, rename/link behavior, linked uses, and exposure edits.
- `test/controllers/canvas_controller_test.dart` covers stroke capture and undo/redo interactions with the current timeline/layer selection.
- `test/controllers/frame_copy_paste_controller_test.dart`, `frame_editing_controller_test.dart`, `timeline_map_controller_test.dart`, and `timeline_mark_controller_test.dart` cover current single-layer/single-cut timeline policies.

### UI tests

- `test/ui/canvas_view_test.dart` pumps `CanvasView` with a supplied `CutId` and verifies drawing/painting behavior.
- `test/ui/layer_panel_test.dart` covers layer list selection and layer controls without cut context.
- `test/ui/timeline_panel_test.dart`, `layer_timeline_grid_test.dart`, and `xsheet_timeline_grid_test.dart` cover timeline rendering and selection for supplied layers/current frame index.
- `test/widget_test.dart` covers the top-level app sample workflow.

### Coverage gaps for future multi-cut work

Future phases should add tests before or alongside active-cut implementation for:

- Multiple cuts in one track with independent layer lists and timeline maps.
- Multiple tracks with cuts that may contain similarly named or similarly shaped layers.
- Explicit active cut selection state and controller switching.
- Selected layer and selected cell behavior after switching cuts.
- Stroke edits proving the active cut's frame is updated and another cut's same-named/same-index material is not changed.
- Repository behavior when two cuts contain the same `LayerId` or `FrameId`, or a formal decision that ids are globally unique.
- Save/load of multiple cuts followed by active-cut restoration or deterministic active-cut defaulting.
- Undo/redo after switching cuts.
- Canvas rendering with two cuts where only the active cut's layers are painted.
- Timeline operations proving placement remains independent per cut.

## Current Single-Cut Assumptions

1. `HomePage` creates and edits one hard-coded sample cut.
2. There is no active cut state above controllers.
3. Controllers are constructed with one `CutId` and are never switched to another cut.
4. `TimelineController.currentFrameIndex` is a single selected timeline position rather than cut-scoped selection state.
5. `LayerController.activeLayerId` implicitly belongs to the one controller cut.
6. `TimelinePanel` receives one list of layers and does not know which cut they came from.
7. `CanvasView` can receive a `CutId`, but the runtime app passes only the sample cut id.
8. Linked-frame copy state in `HomePage` does not include a cut id.
9. Repository `updateLayer`, `addFrame`, `updateFrame`, and `addStroke` are not explicitly cut-scoped.
10. Commands for frame/stroke/timeline edits generally do not carry a `CutId`.
11. Undo/redo stroke navigation records frame indexes but not cut ids.
12. Canvas layout does not currently derive its displayed size from `Cut.canvasSize`.
13. Tests largely use one-cut fixtures, so they do not prove multi-cut isolation.

## Risks Before Multi-Cut Work

The following risks should be addressed before or during the next implementation phase:

- **Ambiguous id scoping:** Decide whether `LayerId` and `FrameId` are globally unique across a project or only unique within a cut/layer. If they are not globally unique, repository and command methods need cut-aware parameters before multi-cut editing is safe.
- **Partial cut scoping:** Controllers often find a layer inside a fixed cut before editing, but the repository replacement step may still replace by `LayerId` globally.
- **Selection leakage:** Active layer, selected frame index, copied linked-frame state, and undo stroke frame indexes are not cut-qualified.
- **Timeline duration source:** `Cut.duration` exists, but `TimelineController.totalFrameCount` derives visible length from layer timeline entries. Future work must define how cut duration and authored timeline length interact.
- **Canvas size usage:** `Cut.canvasSize` exists but is not currently the display/layout source for `CanvasView`.
- **Save/load active cut:** Save/load can preserve cut data structurally, but there is no active-cut restoration/defaulting policy.
- **Linked material vs timing:** Future cross-cut or linked-layer work could accidentally share timing if active-cut boundaries are not explicit.
- **Undo/redo after cut switching:** History commands restore full projects or replace layers, but UI selection and active cut restoration are not designed yet.
- **Test coverage:** Existing tests prove current behavior but not multi-cut isolation.

Future Cut work must preserve these product policies:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent `FrameId`s with the same non-empty name should not be allowed.
- Rename conflict must offer Link / Cancel only.
- Rename-only must not be offered.
- Linked frames share material/source only.
- Linked frames share `FrameId`, strokes/material, and frame name.
- Linked frames do not share timeline placement, authored exposure duration, mark position, blank/X position, or selected cell state.
- Exposure +/- operates on the selected authored timeline entry, not every use of the same `FrameId`.
- Timeline placement must remain independent per cut.
- Future linked layers must not share timing by default.

## Recommended Next Phase

Recommended next implementation phase: make the current single active cut explicit without adding broad multi-cut UI.

Suggested Phase 27 scope:

1. Define an active-cut state/design note or minimal controller state that owns the selected `CutId`.
2. Keep the default active cut deterministic, likely the first available video cut in the loaded project or the existing sample cut for the sample project.
3. Thread the active `CutId` intentionally into controller construction and any edit APIs that need cut scoping.
4. Decide and document id uniqueness rules for `CutId`, `LayerId`, and `FrameId` before changing repository behavior.
5. Add multi-cut isolation tests around repository/controller behavior before adding cut switching UI.
6. Preserve the existing single-cut UI workflow while making the data flow cut-aware internally.
7. Defer Cut switching UI until active-cut scoping is tested.
8. Defer Storyboard Panel, Storyboard Layer, Camera Layer, Audio Layer, Linked Layer, cross-cut paste, cross-layer paste, and project-level material pools to later dedicated phases.

The next phase should not make timeline placement shared across cuts. It should keep timeline placement, authored exposure duration, marks, blank/X positions, and selected cell state independent for each cut while allowing linked material/source concepts to remain separate from timing.
