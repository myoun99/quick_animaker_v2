# Phase 15 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 15: Timeline Marks MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 14 and the Phase 14 follow-up fixes are already complete.

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
* Integrated timeline/layer UI
* Horizontal timeline grid
* Vertical X-sheet timeline grid
* SplayTreeMap-based timeline exposure map
* `TimelineExposure`
* `TimelineExposureType`
* Drawing exposure entries
* Blank/null exposure entries
* Drawing frame heads displayed as `○`
* Blank/null heads displayed as `X`
* Blank/null held regions displayed with subtle low-emphasis styling
* Blank/null exposures resolve to no frame
* TVPaint-like hold behavior
* `+ Exposure` push behavior
* `- Exposure` pull behavior
* Collision-chain shift behavior
* Timeline map edit Undo/Redo
* JSON save/load for timeline map
* `New Frame` button
* New layers start with `0 -> blank`
* Initial sample layers start with `0 -> blank`
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
docs/Phase_13_Codex_Task.md
docs/Phase_14_Codex_Task.md
```

This task implements only Phase 15.

---

## Scope

Implement only:

```text
Phase 15: Timeline Marks MVP
```

The goal is to add a first version of timeline marks, starting with the `●` inbetween/timesheet mark.

This phase should implement:

1. Timeline mark model.
2. Timeline mark type enum.
3. Per-layer sparse timeline marks map.
4. `●` mark display in horizontal timeline.
5. `●` mark display in vertical X-sheet.
6. Toggle mark action for the current layer/current timeline index.
7. Mark Undo/Redo.
8. Mark JSON serialization/deserialization.
9. Tests for model, JSON, controller, UI, and Undo/Redo.
10. Preserve all existing exposure behavior.

This phase must keep marks separate from exposure entries.

---

## Very Important Concept

The symbols have different meanings:

```text
○ = drawing frame head
X = blank/null exposure head
● = timeline mark / inbetween mark / timesheet mark
```

Important:

```text
○ changes drawing exposure.
X changes drawing exposure and makes the layer blank/null.
● does NOT change drawing exposure.
```

A mark must never affect frame resolution.

Example:

```text
0 -> drawing A
3 -> mark ●
```

Resolution:

```text
0 -> A
1 -> A
2 -> A
3 -> A
4 -> A
```

The mark is only a visual/timesheet instruction.

Example:

```text
0 -> drawing A
3 -> blank X
5 -> mark ●
```

Resolution:

```text
0-2 -> A
3+  -> null until next drawing exposure
5   -> still null, but has ● mark
```

The mark does not replace X and does not create a frame.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* Double-click behavior
* Long-press behavior
* Right-click menus
* Keyboard shortcuts
* Frame name editing
* Frame rename dialog
* Timesheet export
* PDF export
* CSV export
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

Do not implement Phase 16 or later.

This phase must stay focused only on timeline marks MVP.

---

## Design Direction

Do not put `●` into `Layer.timeline`.

`Layer.timeline` is for exposure-changing entries only:

```text
drawing
blank/null
```

Instead, add a separate marks structure.

Recommended model-level concept:

```dart
SplayTreeMap<int, TimelineMark>
```

or:

```dart
Map<int, TimelineMark>
```

with sorted behavior handled in the controller.

Recommended Layer shape after this phase:

```dart
class Layer {
  final LayerId id;
  final String name;
  final List<Frame> frames;
  final SplayTreeMap<int, TimelineExposure> timeline;
  final SplayTreeMap<int, TimelineMark> marks;
  final bool isVisible;
  final double opacity;
}
```

If using `SplayTreeMap` directly in the model is awkward, use an immutable `Map<int, TimelineMark>` and normalize/sort when needed.

Rules:

* Mark indexes are internal 0-based timeline indexes.
* Marks are sparse.
* Marks do not create Frames.
* Marks do not create timeline exposure entries.
* Marks do not affect `resolveFrameForLayer`.
* Marks do not affect `effectiveDurationForLayerFrame`.
* Marks do not affect `+ Exposure`.
* Marks do not affect `- Exposure`.
* Marks do not affect blank/null resolution.
* Marks should persist through JSON save/load.

---

## TimelineMark Model

Create:

```text
lib/src/models/timeline_mark.dart
lib/src/models/timeline_mark_type.dart
```

Suggested enum:

```dart
enum TimelineMarkType {
  inbetween,
}
```

Suggested model:

```dart
class TimelineMark {
  const TimelineMark({
    required this.type,
  });

  const TimelineMark.inbetween() : type = TimelineMarkType.inbetween;

  final TimelineMarkType type;

  TimelineMark copyWith({
    TimelineMarkType? type,
  });

  Map<String, dynamic> toJson();

  factory TimelineMark.fromJson(Map<String, dynamic> json);
}
```

Rules:

* For now, only `TimelineMarkType.inbetween` is required.
* JSON value for the type may be `"inbetween"`.
* Invalid JSON should throw a clear error.
* Implement equality and `hashCode`.
* Keep model independent from Flutter UI.

---

## Layer Model Changes

Update:

```text
lib/src/models/layer.dart
```

Add:

```dart
final SplayTreeMap<int, TimelineMark> marks;
```

or equivalent sparse map.

Rules:

* Default marks should be empty.
* Layer constructors should remain easy to use.
* `copyWith` should support marks.
* Equality/hashCode should include marks.
* JSON should include marks only if needed, or include an empty collection consistently.
* Old JSON without marks must still load with empty marks.
* Negative mark indexes should be rejected during JSON parsing.
* Duplicate mark indexes should be rejected if using list JSON shape.

Recommended JSON shape:

```json
"marks": [
  {
    "index": 3,
    "mark": {
      "type": "inbetween"
    }
  }
]
```

or:

```json
"marks": {
  "3": {
    "type": "inbetween"
  }
}
```

Use the same style already used for `timeline` if possible.

---

## TimelineController Changes

Update:

```text
lib/src/controllers/timeline_controller.dart
```

Add mark APIs.

Suggested APIs:

```dart
bool hasMarkAt({
  required Layer layer,
  required int frameIndex,
});

TimelineMark? markAt({
  required Layer layer,
  required int frameIndex,
});

bool canToggleMarkAt({
  required Layer layer,
  required int frameIndex,
});

void toggleMarkForLayer({
  required LayerId layerId,
});
```

Rules:

* `canToggleMarkAt` should return false for negative indexes.
* `toggleMarkForLayer` should use the current timeline index.
* If no mark exists at current index, add `TimelineMark.inbetween()`.
* If an inbetween mark already exists at current index, remove it.
* Toggle must not affect layer.timeline.
* Toggle must not affect layer.frames.
* Toggle must not affect current selected frame.
* Toggle must be Undo/Redo-able.
* Toggling a mark on drawingStart is allowed.
* Toggling a mark on held drawing is allowed.
* Toggling a mark on blankStart is allowed.
* Toggling a mark on blankHeld is allowed.
* Toggling a mark on empty is allowed.
* Marks are allowed everywhere on non-negative timeline indexes.

---

## Undo/Redo for Marks

Timeline mark edits must be undoable.

Preferred simple MVP:

Use the existing layer snapshot command if possible.

If `UpdateLayerTimelineCommand` already snapshots the whole Layer before/after, either reuse it or rename/extend it only if necessary.

Options:

1. Reuse existing `UpdateLayerTimelineCommand` for any layer timeline-like edit.
2. Add `UpdateLayerCommand` if a more general name is cleaner.
3. Add `UpdateLayerMarksCommand` if keeping commands specific is simpler.

Requirements:

* Toggling mark on should be undoable.
* Toggling mark off should be undoable.
* Redo should reapply mark on/off.
* Undo/Redo must not break existing stroke Undo/Redo.
* Undo/Redo must not break New Frame / Blank X / + Exposure / - Exposure.

Keep this MVP simple and reliable.

---

## UI Changes

Update:

```text
lib/src/ui/home_page.dart
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
lib/src/ui/timeline/timeline_panel.dart
```

### New Button

Add a button near `New Frame`, `Blank / X`, `- Exposure`, `+ Exposure`:

```text
Toggle Mark
```

or:

```text
Mark ●
```

Preferred visible label:

```text
Mark ●
```

Behavior:

* Toggles `●` at the current layer/current timeline index.
* Enabled when there is an active layer and current frame index is non-negative.
* Should call `setState`.
* Should work on drawing heads, held drawing, X heads, blank-held cells, and empty cells.

Suggested key:

```dart
ValueKey<String>('toggle-mark-button')
```

### Timeline Cell Display

Cells must support exposure state and mark state at the same time.

Display priority:

```text
If cell has a mark:
  show ●
else if drawingStart:
  show ○
else if blankStart:
  show X
else:
  show empty text
```

Important:

* If a mark exists on a drawing head, display `●` in the cell for now.
* The underlying exposure remains drawingStart.
* The drawing frame must still resolve normally.
* If a mark exists on an X head, display `●` in the cell for now.
* The underlying exposure remains blankStart.
* Blank/null resolution must still work.
* Future phases may add richer stacked symbols, but not now.

Rationale:
For MVP, one visible symbol per cell is acceptable. Mark visibility takes priority because it is the active annotation.

### Blank Styling

If a mark is on a blank/null region, keep the blank/null low-emphasis background.

Examples:

```text
blankStart with mark:
- display ●
- keep blankStart/blank background styling

blankHeld with mark:
- display ●
- keep blankHeld background styling
```

### Drawing Styling

If a mark is on a drawing/held drawing region:

```text
- display ●
- keep the existing drawing/held drawing background styling
```

### Semantics

Add semantics label for mark cells where practical:

```text
timeline mark
```

or:

```text
inbetween mark
```

Tests may use this.

---

## TimelineCell State / Props

Current UI likely uses:

```text
TimelineCellExposureState
```

Do not mix mark type into exposure state if avoidable.

Preferred:

* Keep `TimelineCellExposureState` for exposure only.
* Add a separate mark resolver/callback.

Possible approach:

```dart
final bool Function(Layer layer, int frameIndex) hasMarkForLayer;
```

or:

```dart
final TimelineMark? Function(Layer layer, int frameIndex) markForLayer;
```

Pass this into:

```text
LayerTimelineGrid
XSheetTimelineGrid
TimelinePanel
```

Do not create a fake exposure state for marks.

---

## Persistence

Update JSON serialization/deserialization.

Required:

* Project with layer marks round-trips.
* Old JSON without `marks` loads with empty marks.
* Marks do not create Frames.
* Marks do not create TimelineExposure entries.
* Negative mark index in JSON throws clear error.
* Duplicate mark index in JSON throws clear error if using list shape.

---

## Tests

Add/update tests.

### Model tests

Add:

```text
test/models/timeline_mark_test.dart
```

Required:

* `TimelineMark.inbetween()` creates inbetween mark.
* JSON round-trip.
* Invalid type throws.
* Equality/hashCode.

Update existing layer/model JSON tests:

* Layer marks default empty.
* Layer marks copyWith works.
* Layer marks equality works.
* Layer marks JSON round-trip.
* Old JSON without marks loads as empty marks.

---

### TimelineController tests

Update:

```text
test/controllers/timeline_map_controller_test.dart
```

or add a focused mark test file:

```text
test/controllers/timeline_mark_controller_test.dart
```

Required tests:

1. Empty layer has no mark at index.
2. Toggle mark on at current index adds mark.
3. Toggle mark off at same index removes mark.
4. Mark can be added on drawingStart.
5. Mark can be added on held drawing.
6. Mark can be added on blankStart.
7. Mark can be added on blankHeld.
8. Mark can be added on empty cell.
9. Mark does not affect `resolveFrameForLayer`.
10. Mark does not affect blank/null resolution.
11. Mark does not affect effective duration.
12. Mark does not affect `+ Exposure`.
13. Mark does not affect `- Exposure`.
14. Undo mark add restores previous marks.
15. Redo mark add reapplies mark.
16. Undo mark remove restores mark.
17. Redo mark remove removes mark.
18. Dense frames are not created.

---

### UI tests

Update:

```text
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
test/ui/timeline_panel_test.dart
test/widget_test.dart
```

Required:

1. `Mark ●` button is visible.
2. Button has key `toggle-mark-button`.
3. Pressing `Mark ●` toggles `●` in current cell.
4. Pressing it again removes `●`.
5. `●` displays on drawingStart.
6. `●` displays on held drawing.
7. `●` displays on blankStart.
8. `●` displays on blankHeld.
9. `●` displays on empty cell.
10. Mark display does not remove underlying blank styling.
11. Mark display does not remove underlying drawing styling.
12. Horizontal timeline renders marks.
13. X-sheet renders marks.
14. Existing `○` still appears when no mark.
15. Existing `X` still appears when no mark.
16. Existing `New Frame`, `Blank / X`, `+ Exposure`, `- Exposure` controls still work.

If checking exact colors is brittle, test structure/semantics instead.

---

## Model / JSON Compatibility

Old project JSON without `marks` must continue to load.

Do not break:

* Existing JSON serialization tests
* Existing timeline exposure JSON tests
* Existing project file service tests
* Existing repository tests
* Existing canvas tests
* Existing layer tests
* Existing UI tests

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/models lib/src/controllers lib/src/services lib/src/ui test/models test/controllers test/services test/ui test/widget_test.dart lib/main.dart
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

Do not run broad `dart format lib test` unless necessary.

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

* `TimelineMark` exists.
* `TimelineMarkType` exists.
* Layer has sparse marks map.
* Marks default to empty.
* Old JSON without marks loads.
* JSON save/load preserves marks.
* `●` mark can be toggled on.
* `●` mark can be toggled off.
* Mark toggle is Undo/Redo-able.
* Marks do not affect drawing frame resolution.
* Marks do not affect blank/null resolution.
* Marks do not affect exposure duration.
* Marks do not affect + Exposure.
* Marks do not affect - Exposure.
* Marks do not create frames.
* Marks do not create timeline exposure entries.
* Horizontal timeline displays `●`.
* X-sheet displays `●`.
* `Mark ●` button exists.
* Existing `○` behavior remains.
* Existing `X` behavior remains.
* Existing blank styling remains.
* Existing New Frame behavior remains.
* Existing Blank / X behavior remains.
* Existing exposure editing remains.
* Existing Undo/Redo remains.
* Existing stroke drawing remains.
* Existing layer controls remain.
* Double-click behavior is not introduced.
* Long-press behavior is not introduced.
* Frame naming is not introduced.
* Playback is not introduced.
* State management package is not added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 16.

Do not implement double-click behavior, long-press behavior, frame naming, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame delete UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Timeline Marks MVP.
