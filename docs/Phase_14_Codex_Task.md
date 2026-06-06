# Phase 14 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 14: Blank Exposure UX Refinement MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 13 and the Phase 13 collision hotfix are already complete.

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
* SplayTreeMap-based timeline exposure map
* `TimelineExposure`
* `TimelineExposureType`
* Drawing exposure entries
* Blank/null exposure entries
* Drawing frame heads displayed as `○`
* Blank/null heads displayed as `X`
* Blank/null exposures resolve to no frame
* TVPaint-like hold behavior
* `+ Exposure` push behavior
* `- Exposure` pull behavior
* Collision-chain shift hotfix
* Timeline map edit Undo/Redo
* JSON save/load for timeline map
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
```

This task implements only Phase 14.

---

## Scope

Implement only:

```text
Phase 14: Blank Exposure UX Refinement MVP
```

The goal is to refine how blank/null exposure is created, displayed, and replaced.

This phase should implement:

1. Rename the UI button `New Drawing` to `New Frame`.
2. Disable `Blank / X` creation inside existing blank/null regions.
3. Make blank/null regions visually distinct with a subtle, low-emphasis background.
4. Allow `New Frame` on an `X` blank head.
5. Allow `New Frame` inside a blank-held region.
6. New frame creation on an `X` head should replace the blank entry with a drawing entry.
7. New frame creation inside a blank-held region should add a drawing entry at that index.
8. New layers should start with a blank/null exposure at internal frame index `0`.
9. Keep timeline map behavior sparse.
10. Keep timeline edit Undo/Redo working.
11. Keep existing drawing, layer controls, exposure controls, X-sheet, and stroke Undo/Redo working.

This is a UX refinement phase, not a new model-architecture phase.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* `●` inbetween/timesheet mark creation
* Double-click behavior
* Long-press behavior
* Right-click menus
* Keyboard shortcuts
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

Do not implement Phase 15 or later.

This phase must stay focused on blank exposure UX refinement.

---

## UX Rules

### Meaning of timeline cell states

```text
○ = drawing frame head
X = blank/null exposure head
drawing hold = drawing frame is held from previous drawing head
blank hold = intentional blank/null area held from previous X head
empty = no timeline exposure entry has started yet
```

Important distinction:

```text
empty:
- no explicit instruction exists yet

blank / X:
- explicit instruction that no drawing should be shown
```

Therefore, blank/null regions should be visually different from ordinary empty cells.

---

## Button Rename

Update the UI label:

```text
New Drawing
```

to:

```text
New Frame
```

Do not rename public APIs unless it is helpful and low-risk.

It is acceptable to keep internal method names such as `createDrawingFrameForLayer` for now.

Required:

* Button text should be `New Frame`.
* Existing key can remain `new-drawing-button` if changing it causes unnecessary test churn.
* Tests should assert visible text `New Frame`.

---

## Blank / X Activation Rules

Update `Blank / X` button behavior.

### Blank / X should be enabled on:

```text
empty cell
held drawing cell
```

### Blank / X should be disabled on:

```text
drawingStart cell
blankStart cell
blankHeld cell
```

Reason:

* Creating `X` in an already blank area is redundant.
* Creating `X` directly on a drawing head is destructive and should be reserved for a future delete/replace feature.
* Creating `X` on held drawing is useful because it cuts off a drawing hold.

Examples:

```text
0 -> drawing A
```

At index 3:

```text
Blank / X allowed
Result:
0 -> drawing A
3 -> blank
```

But:

```text
0 -> drawing A
3 -> blank
```

At index 4:

```text
Blank / X disabled
```

because index 4 is already blankHeld.

---

## New Frame Activation Rules

Update `New Frame` button behavior.

### New Frame should be enabled on:

```text
empty cell
held drawing cell
blankStart cell
blankHeld cell
```

### New Frame should be disabled on:

```text
drawingStart cell
```

Reason:

* Creating a new frame on an empty cell is valid.
* Creating a new frame inside a drawing hold is valid.
* Creating a new frame on an `X` head should replace the blank entry.
* Creating a new frame inside a blank-held region should add a drawing entry at that index.
* Creating another frame on an existing drawing head would duplicate the head and should be disabled.

Examples:

```text
0 -> blank
```

At index 0:

```text
New Frame allowed
Result:
0 -> drawing A
```

Example:

```text
0 -> blank
```

At index 5:

```text
New Frame allowed
Result:
0 -> blank
5 -> drawing A
```

Example:

```text
0 -> drawing A
```

At index 3:

```text
New Frame allowed
Result:
0 -> drawing A
3 -> drawing B
```

---

## TimelineController Changes

Update:

```text
lib/src/controllers/timeline_controller.dart
```

The controller should expose clear helper logic for the new UX rules.

Suggested methods:

```dart
bool canCreateDrawingAt({
  required Layer layer,
  required int frameIndex,
});

bool canCreateBlankAt({
  required Layer layer,
  required int frameIndex,
});
```

Update their behavior to match this phase.

### canCreateDrawingAt

Should return:

```text
true:
- empty
- held drawing
- blankStart
- blankHeld

false:
- drawingStart
```

Equivalent logic:

```text
return frameIndex >= 0 && !isDrawingStartForLayer(layer, frameIndex)
```

But ensure it handles blank states correctly.

### canCreateBlankAt

Should return:

```text
true:
- empty
- held drawing

false:
- drawingStart
- blankStart
- blankHeld
```

Equivalent logic:

```text
return frameIndex >= 0
  && !isDrawingStartForLayer(...)
  && !isBlankStartForLayer(...)
  && !isBlankHeldForLayer(...)
```

### createDrawingFrameForLayer

Update behavior:

If current index has no timeline entry:

```text
add drawing entry at current index
add new Frame
```

If current index has a blank entry:

```text
replace blank entry with drawing entry
add new Frame
```

If current index is blankHeld:

```text
add drawing entry at current index
add new Frame
```

If current index is drawingStart:

```text
throw StateError or no-op, but UI should normally disable this
```

If current index is held drawing:

```text
add drawing entry at current index
add new Frame
```

All changes should be Undo/Redo-able through the existing timeline command.

Do not create dense frames.

### createBlankExposureForLayer

Update behavior:

If current index is empty:

```text
add blank entry
```

If current index is held drawing:

```text
add blank entry
```

If current index is drawingStart:

```text
do nothing or throw StateError, but UI should normally disable this
```

If current index is blankStart or blankHeld:

```text
do nothing
```

All changes should be Undo/Redo-able through the existing timeline command.

---

## LayerController / Default Layer Changes

Update:

```text
lib/src/controllers/layer_controller.dart
```

or wherever new layers are created.

New layers should start with a blank/null exposure at internal index `0`.

Expected default new layer:

```text
frames: []
timeline:
  0 -> blank
```

This means a newly created layer explicitly starts as no drawing visible.

Do not create a Frame for the default blank exposure.

Update any sample project initialization if needed.

### Existing initial project

If the app starts with default sample layers, those layers should also follow the same default direction if practical:

```text
timeline:
  0 -> blank
frames:
  []
```

Do not break older JSON compatibility.

---

## UI Display Changes

Update:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

Blank cells should be visually distinct:

```text
blankStart:
- display X
- use subtle low-emphasis background

blankHeld:
- no text
- use subtle low-emphasis background

empty:
- no text
- normal background
```

Do not use loud colors.

Prefer muted gray / low opacity / theme-compatible subtle color.

Do not use hard-coded bright red/yellow.

Example acceptable approach:

```dart
final colorScheme = Theme.of(context).colorScheme;
final blankColor = colorScheme.surfaceContainerHighest.withOpacity(0.35);
```

If `surfaceContainerHighest` is not available in current Flutter SDK, use a safe alternative such as:

```dart
Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35)
```

or a neutral low-emphasis `Color`.

Keep drawing held exposure block styling distinct from blank held exposure styling.

Do not introduce thumbnails.

Do not introduce drag handles.

Do not introduce `●`.

---

## HomePage Changes

Update:

```text
lib/src/ui/home_page.dart
```

Requirements:

* Button text should show `New Frame`.
* `Blank / X` button should use updated `canCreateBlankAt`.
* `New Frame` button should use updated `canCreateDrawingAt`.
* Creating a frame on an X head should work.
* Creating a frame inside a blank-held region should work.
* Existing `+ Exposure`, `- Exposure`, Undo, Redo should keep working.
* UI should call `setState` correctly after actions.

---

## TimelinePanel / UI Tests

Update tests under:

```text
test/ui/
```

Required UI test coverage:

1. `New Frame` text is visible.
2. Old `New Drawing` visible text should not be required anymore.
3. `Blank / X` button is disabled on blankStart.
4. `Blank / X` button is disabled on blankHeld.
5. `Blank / X` button is enabled on held drawing.
6. `New Frame` button is enabled on blankStart.
7. `New Frame` button is enabled on blankHeld.
8. `New Frame` button is disabled on drawingStart.
9. blankStart displays `X`.
10. blankHeld uses distinct blank styling or at least renders in a state distinguishable from empty.

If testing exact colors is brittle, prefer checking keys/structure/state where practical.

---

## TimelineController Tests

Update or add tests under:

```text
test/controllers/timeline_map_controller_test.dart
```

Required tests:

### 1. canCreateBlankAt false in blank region

Set up:

```text
0 -> blank
```

Verify:

```text
canCreateBlankAt(0) == false
canCreateBlankAt(1) == false
canCreateBlankAt(5) == false
```

### 2. canCreateBlankAt true in held drawing

Set up:

```text
0 -> drawing A
```

Verify:

```text
canCreateBlankAt(1) == true
```

### 3. canCreateBlankAt false on drawing head

Set up:

```text
0 -> drawing A
```

Verify:

```text
canCreateBlankAt(0) == false
```

### 4. canCreateDrawingAt true on blank head

Set up:

```text
0 -> blank
```

Verify:

```text
canCreateDrawingAt(0) == true
```

### 5. canCreateDrawingAt true in blank held

Set up:

```text
0 -> blank
```

Verify:

```text
canCreateDrawingAt(3) == true
```

### 6. New frame replaces X head

Set up:

```text
0 -> blank
```

Select index 0 and create a drawing frame.

Verify:

```text
timeline[0] is drawing
frames.length == 1
resolveFrameForLayer(index 0) returns new frame
```

### 7. New frame inside blank held adds drawing entry

Set up:

```text
0 -> blank
```

Select index 5 and create a drawing frame.

Verify:

```text
timeline:
0 -> blank
5 -> drawing
frames.length == 1
resolveFrameForLayer(4) == null
resolveFrameForLayer(5) returns new frame
```

### 8. Blank / X inside blank held does nothing

Set up:

```text
0 -> blank
```

Select index 5 and call createBlankExposureForLayer.

Verify:

```text
timeline still only has key 0
```

### 9. New layer default timeline starts blank

Create a layer through LayerController default creation API.

Verify:

```text
frames is empty
timeline[0] is blank
```

### 10. Undo/Redo still works

Verify for:

```text
New Frame replacing X
New Frame inside blank held
Blank/X cutting off drawing hold
```

---

## Model / JSON Tests

This phase should not require JSON schema changes.

However, update tests if default layer timeline behavior affects existing expectations.

Required:

* New blank default layer still serializes/deserializes correctly.
* Existing timeline JSON tests still pass.
* Old JSON without timeline still loads.

Do not change JSON shape unless absolutely necessary.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/controllers lib/src/ui test/controllers test/ui lib/main.dart
flutter analyze
flutter test
```

If model tests or layer-controller tests are modified, include those paths too:

```bash
dart format lib/src/controllers lib/src/models lib/src/ui test/controllers test/models test/ui lib/main.dart
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
6. Any important UX behavior notes

---

## Completion Criteria

This task is complete only when:

* UI button says `New Frame`.
* `Blank / X` is disabled in blankStart.
* `Blank / X` is disabled in blankHeld.
* `Blank / X` is disabled on drawingStart.
* `Blank / X` is enabled on held drawing.
* `New Frame` is disabled on drawingStart.
* `New Frame` is enabled on empty.
* `New Frame` is enabled on held drawing.
* `New Frame` is enabled on blankStart.
* `New Frame` is enabled on blankHeld.
* New Frame on an X head replaces X with drawing.
* New Frame inside blankHeld adds a drawing entry at that index.
* Blank/X inside blankHeld does not add redundant X entries.
* Blank/null held regions have subtle low-emphasis visual styling.
* New layers start with `0 -> blank` and no frames.
* No dense frame data is created.
* Timeline edit Undo/Redo still works.
* Existing stroke Undo/Redo still works.
* Existing drawing still works when a drawing frame is resolved.
* Existing exposure + / - still works.
* Existing collision-chain fix still works.
* Existing JSON tests still pass.
* `●` is not introduced.
* Double-click behavior is not introduced.
* Long-press behavior is not introduced.
* Frame naming is not introduced.
* Playback is not introduced.
* State management package is not added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 15.

Do not implement `●` inbetween/timesheet marks, double-click behavior, long-press behavior, frame naming, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame delete UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only blank exposure UX refinement.
