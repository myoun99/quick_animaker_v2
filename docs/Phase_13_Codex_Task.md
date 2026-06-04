# Phase 13 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 13: Timeline Map Model MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 12 and the Phase 12 exposure hotfix are already complete.

Current completed foundation:

```text
lib/main.dart
lib/src/models/
lib/src/services/project_repository.dart
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/
lib/src/services/project_json_serializer.dart
lib/src/services/project_file_service.dart
lib/src/controllers/canvas_controller.dart
lib/src/controllers/layer_controller.dart
lib/src/controllers/timeline_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/
lib/src/ui/timeline/
test/models/
test/services/
test/controllers/
test/ui/
docs/
```

The project already has:

* Immutable domain models
* Typed IDs
* JSON support
* ProjectRepository
* Command-based Undo/Redo MVP
* JSON save/load services
* Basic canvas drawing
* Layer MVP
* Layer visibility
* Layer opacity
* Sparse timeline MVP
* Integrated timeline/layer UI
* Horizontal timeline grid
* Vertical X-sheet timeline grid
* Frame exposure duration editing
* TVPaint-like automatic hold behavior
* Effective visible duration logic for exposure editing
* `+ Exposure` push behavior
* `- Exposure` pull behavior
* Drawing frame heads displayed as `○`
* Held exposure cells displayed as block-like areas
* UI frame labels displayed as 1-based numbers
* Internal timeline indexes kept as 0-based
* Passing `flutter analyze`
* Passing `flutter test`

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
docs/Phase_2_Codex_Task.md
docs/Phase_3_Codex_Task.md
docs/Phase_4_Codex_Task.md
docs/Phase_5_Codex_Task.md
docs/Phase_6_Codex_Task.md
docs/Phase_7_Codex_Task.md
docs/Phase_8_Codex_Task.md
docs/Phase_9_Codex_Task.md
docs/Phase_10_Codex_Task.md
docs/Phase_11_Codex_Task.md
docs/Phase_12_Codex_Task.md
```

This task implements only Phase 13.

---

## Scope

Implement only:

```text
Phase 13: Timeline Map Model MVP
```

The goal is to introduce a proper SplayTreeMap-based timeline map so drawing frame data and timeline placement are separated.

This phase should implement:

1. `TimelineExposure` model.
2. `TimelineExposureType` enum.
3. `SplayTreeMap<int, TimelineExposure>`-based timeline map on `Layer`.
4. Drawing exposure entries.
5. Blank/null exposure entries.
6. `○` drawing frame head behavior using timeline map.
7. `X` blank/null exposure head behavior using timeline map.
8. TVPaint-like hold from drawing entry to the next timeline exposure entry.
9. Blank/null hold from blank entry to the next timeline exposure entry.
10. Timeline resolution based on the timeline map.
11. `New Drawing` creates a drawing timeline entry.
12. New `Blank / X` action creates a blank/null timeline entry.
13. `+ Exposure` and `- Exposure` operate by moving timeline map entries.
14. Timeline map editing is registered into Undo/Redo.
15. JSON serialization/deserialization preserves timeline map.
16. Existing drawing, layers, opacity, visibility, timeline UI, X-sheet UI, and stroke Undo/Redo continue to work.

This is a model/controller/persistence/Undo phase.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* `●` inbetween/timesheet mark creation
* Double-click behavior
* Long-press behavior
* Frame name editing
* Frame rename dialog
* Frame block dragging
* Exposure handle dragging
* Frame copy/paste
* Frame delete UI
* Frame reorder UI
* Layer reorder
* Cut/clip editing
* Thumbnail rendering
* Waveforms
* Keyframe interpolation
* Advanced save/load UI
* File picker UI
* Bitmap raster engine
* Advanced brush engine
* Pressure/tilt/speed dynamics
* Layer groups
* Layer masks
* Blend modes
* Infinite canvas
* Tile system
* Disk cache
* Playback cache
* Provider
* Riverpod
* Bloc
* Complex app-wide state management

Do not implement Phase 14 or later.

This phase must stay focused on the timeline map model, blank/null exposure, and Undo/Redo for timeline map edits.

---

## Important Design Direction

The old QuickAnimaker v1 model used a SplayTreeMap-style timeline structure where the key was the timeline index and the value was the frame ID.

Use the same concept, but implement it in the v2 typed-ID architecture.

Recommended v2 direction:

```dart
SplayTreeMap<int, TimelineExposure>
```

Concept:

```text
0  -> drawing(Frame A)
6  -> drawing(Frame B)
12 -> blank/null
16 -> drawing(Frame C)
```

Resolution:

```text
0-5   -> Frame A
6-11  -> Frame B
12-15 -> null / blank
16+   -> Frame C
```

The timeline map stores exposure-changing events only.

Do not store dense per-frame data.

---

## TimelineExposure Model

Create:

```text
lib/src/models/timeline_exposure.dart
lib/src/models/timeline_exposure_type.dart
```

Suggested enum:

```dart
enum TimelineExposureType {
  drawing,
  blank,
}
```

Suggested model:

```dart
class TimelineExposure {
  const TimelineExposure({
    required this.type,
    this.frameId,
  });

  final TimelineExposureType type;
  final FrameId? frameId;

  TimelineExposure copyWith({
    TimelineExposureType? type,
    FrameId? frameId,
  });

  Map<String, dynamic> toJson();

  factory TimelineExposure.fromJson(Map<String, dynamic> json);
}
```

Rules:

* `drawing` exposure must have a non-null `frameId`.
* `blank` exposure must have `frameId == null`.
* Invalid JSON should throw a clear error.
* Use immutable style.
* Implement equality and `hashCode`.
* Keep this model independent from Flutter UI.

---

## Layer Model Changes

Update:

```text
lib/src/models/layer.dart
```

Add a timeline map field.

Suggested field:

```dart
final SplayTreeMap<int, TimelineExposure> timeline;
```

If direct `SplayTreeMap` in the model is awkward for equality/JSON, an immutable `Map<int, TimelineExposure>` can be exposed while internally sorted in controller.

But the preferred model-level concept is:

```text
timeline index -> TimelineExposure
```

Rules:

* Timeline indexes must be non-negative integers.
* Timeline map keys are internal 0-based indexes.
* Timeline map values are exposure entries.
* `Layer.frames` continues to store actual drawing frames.
* `Layer.timeline` stores where drawing/blank exposure entries start.
* Do not duplicate frames into held cells.
* Do not create dense frame data.

### Backward compatibility

Existing JSON/tests may not have `timeline`.

For old layer JSON:

* If `timeline` is missing, derive a default timeline from `frames` using existing `Frame.duration` order.
* If a layer has frames `[A duration 3, B duration 2]`, create:

    * `0 -> drawing(A)`
    * `3 -> drawing(B)`
* If a layer has no frames, timeline should be empty.
* This preserves older project loading behavior.

---

## JSON Serialization

Update all necessary JSON methods so `Layer.timeline` persists.

Suggested JSON shape:

```json
"timeline": [
  {
    "index": 0,
    "exposure": {
      "type": "drawing",
      "frameId": "frame-a"
    }
  },
  {
    "index": 6,
    "exposure": {
      "type": "blank"
    }
  }
]
```

or:

```json
"timeline": {
  "0": {
    "type": "drawing",
    "frameId": "frame-a"
  },
  "6": {
    "type": "blank"
  }
}
```

Choose one shape and keep it simple.

Requirements:

* Preserve timeline order.
* Reject negative indexes.
* Reject duplicate indexes.
* Reject drawing entries without frame IDs.
* Reject blank entries with frame IDs if practical.
* Make round-trip tests pass.
* Keep old JSON compatibility.

Do not modify file picker UI.

---

## Timeline Resolution Semantics

Update:

```text
lib/src/controllers/timeline_controller.dart
```

Timeline resolution should use the layer timeline map.

Rules:

### Empty timeline

If `layer.timeline` is empty:

```text
all indexes -> null
```

### Drawing entry

If timeline has:

```text
0 -> drawing(Frame A)
6 -> drawing(Frame B)
```

Then:

```text
0-5 -> Frame A
6+  -> Frame B
```

### Blank/null entry

If timeline has:

```text
0 -> drawing(Frame A)
6 -> blank
10 -> drawing(Frame B)
```

Then:

```text
0-5  -> Frame A
6-9  -> null / blank
10+  -> Frame B
```

### Empty before first entry

If timeline has:

```text
5 -> drawing(Frame A)
```

Then:

```text
0-4 -> null
5+  -> Frame A
```

### Last drawing holds forward

If the last entry is drawing:

```text
5 -> drawing(Frame A)
```

Then:

```text
5 to visible timeline end -> Frame A
```

### Last blank holds forward

If the last entry is blank:

```text
5 -> blank
```

Then:

```text
5 to visible timeline end -> null
```

---

## Timeline Cell State

Existing UI uses:

```text
TimelineCellExposureState.empty
TimelineCellExposureState.drawingStart
TimelineCellExposureState.heldExposure
```

Add a blank/null state.

Update:

```text
lib/src/ui/timeline/timeline_cell_exposure_state.dart
```

Suggested enum:

```dart
enum TimelineCellExposureState {
  empty,
  drawingStart,
  heldExposure,
  blankStart,
  blankHeld,
}
```

UI display rules:

```text
drawingStart -> ○
heldExposure -> block fill, no text
blankStart -> X
blankHeld -> blank/null block fill, no text or subtle fill
empty -> empty cell
```

Do not use `●` in this phase.

`●` is reserved for future inbetween/timesheet marks.

---

## UI Changes

Update:

```text
lib/src/ui/home_page.dart
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
lib/src/ui/timeline/timeline_panel.dart
```

### New Blank / X Button

Add a simple button near `New Drawing`, `- Exposure`, `+ Exposure`:

```text
Blank / X
```

or:

```text
Set X
```

Behavior:

* On current layer/current timeline index, create a blank/null exposure entry.
* It should display as `X`.
* It should cause resolution to return null from that index until the next drawing/blank entry.
* It should not create a `Frame`.
* It should not create stroke data.
* It should be Undo/Redo-able.

### New Drawing

Update behavior:

* Creates a new `Frame`.
* Adds it to `Layer.frames`.
* Adds a timeline drawing entry at current timeline index.
* Displays `○`.
* If an entry already exists at that index, replace it only if safe, or throw/disable.
* Prefer disabling or no-op if an entry already exists at the current index.

### X / Blank Entry

Behavior:

```text
Before:
0 -> drawing A

Current index = 6
Set X

After:
0 -> drawing A
6 -> blank
```

Resolution:

```text
0-5 -> A
6+  -> null, until next drawing entry
```

If current index already has a drawing entry:

* Do not delete the drawing frame in this phase.
* Either disable X or replace the timeline entry with blank while leaving the unused frame in `Layer.frames`.
* Prefer disabling X on drawing head to avoid accidental loss.
* It can be refined later.

If current index already has blank entry:

* It is acceptable to do nothing.
* Toggle/remove behavior can be implemented later, not required now.

---

## Exposure Editing with Timeline Map

`+ Exposure` and `- Exposure` should operate by moving following timeline entries.

Important: once timeline map is introduced, exposure duration is determined by distance between timeline entries.

### + Exposure

If selected entry is at index `0` and next entry is at index `6`:

```text
0 -> drawing A
6 -> drawing B
```

`+ Exposure` on A should move B and directly connected following entries by `+1`:

```text
0 -> drawing A
7 -> drawing B
```

If there is a connected sequence:

```text
0 -> drawing A
6 -> drawing B
9 -> drawing C
```

and B/C are considered directly connected as authored blocks, then move B and connected following entries together if the current implementation can track that safely.

MVP acceptable behavior:

* Move the immediate next timeline entry by +1.
* If following entries are exactly adjacent by their effective spans or authored connected logic, move them together.
* Preserve tests for connected push/pull from Phase 12 where possible.

### - Exposure

If selected entry is at index `0` and next entry is at index `6`:

```text
0 -> drawing A
6 -> drawing B
```

`- Exposure` on A should move B one earlier:

```text
0 -> drawing A
5 -> drawing B
```

Rules:

* Do not move next entry to the same index as current entry.
* Effective duration must never go below 1.
* If current entry and next entry are already adjacent:

    * `0 -> A`, `1 -> B`
    * `- Exposure` should do nothing.
* If there is no next entry, `- Exposure` should do nothing or be disabled.
* Do not create dense frames.

### Blank entries participate in push/pull

Blank entries are timeline exposure entries.

Example:

```text
0 -> drawing A
6 -> blank
10 -> drawing B
```

`+ Exposure` on A:

```text
0 -> drawing A
7 -> blank
10 -> drawing B
```

If blank and B are connected according to the chosen connected-entry rule, move both.

MVP acceptable:

* At minimum, the immediate next entry should move.
* Do not corrupt ordering.
* Do not allow duplicate timeline indexes.

---

## Undo/Redo for Timeline Map Edits

Timeline map edits must be undoable.

Required operations:

```text
New Drawing
Set X / Blank
+ Exposure
- Exposure
```

Use command-based Undo/Redo.

Preferred simple MVP:

Create a command that snapshots the layer before and after a timeline edit.

Suggested command:

```text
lib/src/services/commands/update_layer_timeline_command.dart
```

Possible shape:

```dart
class UpdateLayerTimelineCommand implements Command {
  UpdateLayerTimelineCommand({
    required this.repository,
    required this.before,
    required this.after,
  });

  final ProjectRepository repository;
  final Layer before;
  final Layer after;

  @override
  void execute() {
    repository.replaceLayer(after);
  }

  @override
  void undo() {
    repository.replaceLayer(before);
  }
}
```

You may choose a better name or structure.

Requirements:

* Undo restores the previous layer timeline and frames.
* Redo reapplies the edited layer timeline and frames.
* It must handle:

    * New drawing frame added
    * Blank entry added
    * Timeline entry moved by + Exposure
    * Timeline entry moved by - Exposure
* Do not break existing stroke Undo/Redo.
* Exposure Undo does not need the “move to target frame first” behavior used for strokes.
* Keep this MVP simple and reliable.

If `ProjectRepository.replaceLayer` does not exist, add a minimal method.

Do not implement broad repository rewrites.

---

## ProjectRepository Changes

Update only as needed.

Likely needed:

```dart
void replaceLayer(Layer layer)
```

or:

```dart
void updateLayer({
  required LayerId layerId,
  required Layer Function(Layer layer) update,
})
```

Requirements:

* Preserve immutability.
* Rebuild Project -> Track -> Cut -> Layer parent chain.
* Throw clear `StateError` if layer is not found.
* Add tests.

---

## TimelineController Changes

Update controller to use layer timeline map instead of `_explicitFrameStarts`.

Expected changes:

* Remove or greatly reduce `_explicitFrameStarts`.
* Use `Layer.timeline` as source of truth.
* Resolve frame by finding the greatest timeline index <= target index.
* If entry is drawing, return its frame.
* If entry is blank, return null.
* Create drawing entry via timeline map.
* Create blank entry via timeline map.
* Increase/decrease exposure by moving timeline map entries.
* Use HistoryManager/Command for timeline edits if controller performs edits.
* Keep public API clear.

Suggested APIs:

```dart
Frame? resolveFrameForLayer({
  required Layer layer,
  int? frameIndex,
});

TimelineExposure? resolveExposureEntryForLayer({
  required Layer layer,
  int? frameIndex,
});

bool isDrawingStartForLayer({
  required Layer layer,
  required int frameIndex,
});

bool isBlankStartForLayer({
  required Layer layer,
  required int frameIndex,
});

bool isHeldExposureForLayer({
  required Layer layer,
  required int frameIndex,
});

bool isBlankHeldForLayer({
  required Layer layer,
  required int frameIndex,
});

int? exposureStartIndexForLayer({
  required Layer layer,
  required FrameId frameId,
});

int? effectiveDurationForLayerFrame({
  required Layer layer,
  required FrameId frameId,
});

bool canCreateDrawingAt({
  required Layer layer,
  required int frameIndex,
});

bool canCreateBlankAt({
  required Layer layer,
  required int frameIndex,
});

void createDrawingFrameForLayer({
  required LayerId layerId,
  required FrameId frameId,
  int duration = 1,
});

void createBlankExposureForLayer({
  required LayerId layerId,
});

void increaseExposure({
  required LayerId layerId,
  required FrameId frameId,
});

void decreaseExposure({
  required LayerId layerId,
  required FrameId frameId,
});
```

You may adjust names if clearer.

---

## CanvasController Interaction

Existing drawing behavior must keep working.

Rules:

* If current timeline index resolves to a drawing frame, drawing adds strokes to that frame.
* If current timeline index resolves to blank/null, drawing should not add strokes to a blank entry.
* Current MVP may require user to press `New Drawing` first before drawing.
* Do not automatically create drawing frames on simple click.
* Do not automatically replace X with drawing just because the user draws unless existing behavior already does this.
* Keep behavior predictable.

If needed, make `CanvasController` no-op when current layer/current frame resolves to null.

Do not break tests.

---

## UI Display Rules

### Horizontal Timeline

Update `LayerTimelineGrid`.

Cells:

```text
drawingStart -> ○
heldExposure -> connected drawing block fill
blankStart -> X
blankHeld -> blank/null block fill
empty -> empty
```

### X-sheet

Update `XSheetTimelineGrid`.

Cells:

```text
drawingStart -> ○
heldExposure -> drawing block fill
blankStart -> X
blankHeld -> blank/null block fill
empty -> empty
```

No `●`.

No double-click.

No long-press.

---

## Persistence

Update save/load JSON tests.

Required:

* Project with layer timeline drawing entries round-trips.
* Project with layer timeline blank entries round-trips.
* Old JSON without timeline still loads by deriving timeline from frames.
* No dense frame data is created during serialization.
* Blank entries do not create frames.

---

## Tests

Add and update tests.

### Model tests

Add tests for:

```text
test/models/timeline_exposure_test.dart
```

Required:

* drawing exposure requires frameId.
* blank exposure has no frameId.
* JSON round-trip for drawing.
* JSON round-trip for blank.
* equality/hashCode.

Update layer/model serialization tests:

* Layer timeline map serializes.
* Layer timeline map deserializes.
* Missing timeline derives from frames.

---

### Repository / Command tests

Add tests for:

```text
test/services/commands/update_layer_timeline_command_test.dart
```

or existing command test file.

Required:

* Execute applies after layer.
* Undo restores before layer.
* Redo reapplies after layer through `HistoryManager`.
* New drawing timeline edit can be undone/redone.
* Blank X timeline edit can be undone/redone.
* Exposure push/pull timeline edit can be undone/redone.

Add repository tests if `replaceLayer` or `updateLayer` is added:

* Replaces only target layer.
* Keeps other layers unchanged.
* Throws for missing layer.

---

### TimelineController tests

Update:

```text
test/controllers/timeline_controller_test.dart
```

Required tests:

1. Empty timeline resolves null.
2. Drawing entry resolves frame until next entry.
3. Blank entry resolves null until next entry.
4. Empty before first entry remains null.
5. Last drawing entry holds forward.
6. Last blank entry holds forward as null.
7. `isDrawingStartForLayer` detects drawing head.
8. `isBlankStartForLayer` detects X head.
9. `isHeldExposureForLayer` detects drawing hold.
10. `isBlankHeldForLayer` detects blank hold.
11. `New Drawing` creates one frame and one drawing timeline entry.
12. `Set X` creates one blank timeline entry and no frame.
13. `+ Exposure` moves following timeline entry later.
14. `- Exposure` moves following timeline entry earlier.
15. `- Exposure` cannot reduce effective duration below 1.
16. Dense frame duplication is not introduced.
17. Undo New Drawing restores previous timeline/frames.
18. Undo Set X restores previous timeline.
19. Undo + Exposure restores previous timeline.
20. Undo - Exposure restores previous timeline.

---

### UI tests

Update:

```text
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
test/ui/timeline_panel_test.dart
```

Required:

* drawingStart displays `○`.
* blankStart displays `X`.
* heldExposure does not display `●`.
* blankHeld does not display `●`.
* empty remains blank.
* `Blank / X` button is visible.
* `Blank / X` callback works.
* Existing New Drawing callback works.
* Existing + Exposure / - Exposure buttons work.
* Horizontal timeline still renders.
* X-sheet timeline still renders.
* Frame labels remain 1-based.
* Keys remain 0-based.

---

## Backward Compatibility

Existing tests from previous phases must still pass.

Do not remove tests unless they are truly obsolete and replaced by stronger tests.

Special care:

* Existing saved model JSON tests may need timeline defaults.
* Existing `Layer` constructors may need default `timeline`.
* Existing sample project initialization must still work.
* Existing canvas drawing tests must still work.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/models lib/src/controllers lib/src/services lib/src/ui test/models test/controllers test/services test/ui lib/main.dart
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

Do not run `dart format lib test` unless necessary, because that may reformat unrelated files broadly.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `dart format` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes
7. Any migration/backward compatibility notes

---

## Completion Criteria

This task is complete only when:

* `TimelineExposure` exists.
* `TimelineExposureType` exists.
* Layer has a timeline exposure map.
* Timeline map supports drawing entries.
* Timeline map supports blank/null entries.
* Drawing entry displays as `○`.
* Blank/null entry displays as `X`.
* Drawing entry holds until next exposure entry.
* Blank entry holds as null until next exposure entry.
* Last drawing entry holds forward.
* Last blank entry holds forward as null.
* Timeline resolution uses the timeline map.
* `New Drawing` creates a frame and drawing timeline entry.
* `Blank / X` creates a blank timeline entry and no frame.
* `+ Exposure` moves following timeline entries later.
* `- Exposure` moves following timeline entries earlier.
* Effective duration never goes below 1.
* Dense frame duplication is not introduced.
* Timeline edits are undoable/redone through command/history.
* JSON save/load preserves timeline entries.
* Old JSON without timeline remains loadable.
* Existing drawing still works.
* Existing layer controls still work.
* Existing visibility/opacity still work.
* Existing stroke Undo/Redo still works.
* Horizontal timeline still works.
* X-sheet timeline still works.
* Frame labels remain 1-based in UI.
* Internal indexes remain 0-based.
* `●` is not introduced.
* Double-click behavior is not introduced.
* Frame naming is not introduced.
* Playback is not introduced.
* State management package is not added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 14.

Do not implement `●` inbetween/timesheet marks, double-click behavior, long-press behavior, frame naming, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame delete UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only the Timeline Map Model MVP with blank/null X exposure and Undo/Redo for timeline map edits.
