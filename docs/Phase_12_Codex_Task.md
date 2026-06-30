# Phase 12 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 12: Timeline Exposure Semantics MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 11 are already complete.

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
* New Drawing button
* Increase/decrease exposure controls
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
```

This task implements only Phase 12.

---

## Scope

Implement only:

```text
Phase 12: Timeline Exposure Semantics MVP
```

The goal is to refine how sparse drawing frames are interpreted on the timeline.

This phase should implement:

1. TVPaint-like automatic hold behavior.
2. A drawing frame should hold until the next drawing frame starts.
3. If no later drawing frame exists, the last drawing frame should hold to the visible timeline end.
4. `+ Exposure` should push directly adjacent following frame blocks one frame later.
5. `- Exposure` should pull directly adjacent following frame blocks one frame earlier.
6. Non-adjacent blocks separated by empty gaps should not move.
7. Duration must never go below 1.
8. Sparse timeline behavior must be preserved.
9. Dense frame duplication must not be introduced.
10. Existing UI, drawing, layer controls, visibility, opacity, and Undo/Redo should keep working.

This is a timeline semantics phase, not a new visual feature phase.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* Timeline mark data model
* `●` inbetween/timesheet mark creation
* Double-click mark behavior
* Frame name editing
* Frame rename dialog
* Frame block dragging
* Exposure handle dragging
* Frame copy/paste
* Frame delete
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

Do not implement Phase 13 or later.

This phase must stay focused on exposure semantics only.

---

## Important Current Limitation

The current timeline uses this MVP interpretation:

```text
Layer.frames is an ordered list.
Frame.duration is used as exposure length.
TimelineController.resolveFrameForLayer() walks frames and accumulated duration.
Some newly created frames use an in-memory explicit start index map.
```

This was enough for earlier phases, but now we need stronger semantics.

For Phase 12, prefer improving `TimelineController` logic without major model rewrites if possible.

However, if minimal helper structures are required inside `TimelineController`, they are allowed.

Do not add new model fields unless absolutely necessary.

Do not change JSON persistence unless absolutely necessary.

The long-term project may later introduce a proper persisted exposure/start-frame model. Do not implement that full migration in this phase unless there is no simpler safe option.

---

## Core Concept

A drawing frame has a start position.

The drawing should remain visible until the next drawing frame starts.

Example:

```text
Frame A starts at internal index 0
Frame B starts at internal index 4

Timeline:
0 → Frame A head
1 → Frame A hold
2 → Frame A hold
3 → Frame A hold
4 → Frame B head
5 → Frame B hold
6 → Frame B hold
...
```

In the UI, because frame labels are 1-based:

```text
Display:
1 → Frame A head
2 → Frame A hold
3 → Frame A hold
4 → Frame A hold
5 → Frame B head
6 → Frame B hold
...
```

Internal indexes must remain 0-based.

---

## Automatic Hold Behavior

### Rule 1: Hold until next frame

If a layer has multiple drawing frames:

```text
Frame A starts at index 0
Frame B starts at index 5
```

Then:

```text
index 0 → Frame A drawing head
index 1 → Frame A held exposure
index 2 → Frame A held exposure
index 3 → Frame A held exposure
index 4 → Frame A held exposure
index 5 → Frame B drawing head
```

The visible exposure of Frame A is determined by the next frame's start index.

### Rule 2: Last frame holds to visible timeline end

If a layer has only one frame:

```text
Frame A starts at index 0
```

Then it should be displayed as holding to the visible timeline end.

For example, if the UI currently shows at least 24 frame cells:

```text
index 0 → Frame A drawing head
index 1 through 23 → Frame A held exposure
```

Do not create dense frame data for indexes 1 through 23.

This is a display/resolve behavior, not data duplication.

### Rule 3: Empty layer remains empty

If a layer has no frames:

```text
index 0 through visible end → empty
```

---

## Frame Start Index Semantics

Phase 12 needs reliable start-index behavior.

Preferred MVP approach:

* Continue using the existing internal `_explicitFrameStarts` structure if possible.
* Ensure every frame can have a start index.
* For older/sequential frames without explicit starts, derive starts by walking durations.
* When a new frame is created at current timeline index, store its explicit start index.
* When pushing/pulling frames, update explicit starts for affected frames.
* Keep frames ordered by start index where necessary.

Useful helper concepts:

```dart
class FrameExposureEntry {
  final Frame frame;
  final int startIndex;
  final int duration;
}
```

This can be a private helper class inside `timeline_controller.dart`.

Do not expose this as a public model unless necessary.

---

## Resolving Frames

Update `TimelineController.resolveFrameForLayer()` semantics.

It should resolve:

1. A frame head at its start index.
2. A held exposure after its start index until the next frame start.
3. The last frame should hold until the visible timeline end.
4. Empty areas before the first frame should remain empty.
5. Gaps between non-adjacent frames should remain empty only if the chosen semantics explicitly supports gaps.

Important:

For this phase, we want both:

```text
A newly created frame holds forward like TVPaint.
Non-adjacent blocks separated by empty gaps should remain non-adjacent for push/pull operations.
```

This means frame starts are important.

Example:

```text
Frame A starts at 0
Frame B starts at 5
```

Then A visibly holds from 0 to 4, and B starts at 5.

For push/pull adjacency, B is considered adjacent to A if B starts exactly at A's effective end.

If the current implementation still stores duration, use duration to determine the authored end when needed.

---

## Authored Duration vs Display Hold

This phase introduces an important distinction:

```text
authored duration = the frame's explicit duration value
display hold = how far the drawing is shown in the UI/resolve behavior
```

Recommended MVP interpretation:

1. `Frame.duration` remains the authored exposure length.
2. If there is no next frame and the frame is the last drawing on the layer, display it as holding to the visible timeline end.
3. If there is a next frame, the previous frame display hold ends at the next frame start.
4. Increasing/decreasing exposure changes authored duration and may move adjacent following frame starts.

This keeps the existing model while making the UI feel like TVPaint hold.

---

## Creating a New Drawing Frame

When the selected layer has no resolved frame at the current timeline index and the user presses New Drawing:

* Create exactly one new sparse `Frame`.
* Set its explicit start index to the current timeline index.
* Default duration should remain 1.
* Do not create frames for skipped indexes.
* Do not duplicate strokes.
* The new frame should display as `○` at its head and hold forward until the next frame or visible timeline end.

Example:

```text
Current index: 10
New Drawing
```

Result:

```text
Frame starts at index 10
index 10 → ○
index 11 onward → held exposure, until next frame or visible end
```

Do not create frames at indexes 0 through 9.

---

## + Exposure Push Behavior

When `increaseExposure()` is applied to a frame:

### Case A: No following frame

If there is no following frame, the selected frame already displays as holding to the visible timeline end.

Preferred MVP behavior:

* Increase the frame's authored `duration` by 1 if existing tests expect it.
* Or leave duration unchanged if that is cleaner.
* But the visible result should remain a forward hold.

Choose the least disruptive option that keeps tests understandable.

### Case B: Following frame is directly adjacent

If the selected frame's authored end touches the next frame's start, then increasing exposure should push the next frame and any connected following frame blocks one frame later.

Example:

```text
Before:
index 0 → ○ A
index 1 → hold A
index 2 → ○ B
index 3 → hold B
index 4 → ○ C

A duration = 2
B starts at 2
C starts at 4
```

User applies `+ Exposure` to A.

Expected:

```text
After:
index 0 → ○ A
index 1 → hold A
index 2 → hold A
index 3 → ○ B
index 4 → hold B
index 5 → ○ C

A duration = 3
B start moves from 2 to 3
C start moves from 4 to 5
```

B and C are both moved because they are a connected sequence after A.

### Case C: Following frame is not adjacent

If there is a gap between the selected frame's authored end and the next frame start, then increasing exposure should not move the later block until it actually collides.

Example:

```text
Before:
index 0 → ○ A
index 1 → hold A
index 2 → empty authored gap
index 3 → empty authored gap
index 4 → ○ B

A duration = 2
B starts at 4
```

User applies `+ Exposure` to A once.

Expected:

```text
A duration = 3
B still starts at 4
```

No push yet, because A's authored end moved from 2 to 3 and B starts at 4.

If user applies `+ Exposure` again:

```text
A duration = 4
B still starts at 4
```

Now A's authored end touches B's start.

If user applies `+ Exposure` again:

```text
A duration = 5
B should be pushed to 5
```

This preserves gaps until collision.

---

## - Exposure Pull Behavior

When `decreaseExposure()` is applied to a frame:

### Case A: Duration is 1

If the frame's authored duration is already 1:

* Do nothing.
* Do not move following frames.
* Do not allow duration below 1.

### Case B: Following frame is directly adjacent

If the selected frame's authored end touches the next frame's start, then decreasing exposure should pull the next frame and any connected following frame blocks one frame earlier.

Example:

```text
Before:
index 0 → ○ A
index 1 → hold A
index 2 → hold A
index 3 → ○ B
index 4 → hold B
index 5 → ○ C

A duration = 3
B starts at 3
C starts at 5
```

User applies `- Exposure` to A.

Expected:

```text
After:
index 0 → ○ A
index 1 → hold A
index 2 → ○ B
index 3 → hold B
index 4 → ○ C

A duration = 2
B start moves from 3 to 2
C start moves from 5 to 4
```

B and C move because they are a connected following block sequence.

### Case C: Following frame is not adjacent

If there is a gap between selected frame's authored end and the next frame start, then decreasing exposure should not move the later block.

Example:

```text
Before:
index 0 → ○ A
index 1 → hold A
index 2 → empty authored gap
index 3 → empty authored gap
index 4 → ○ B

A duration = 2
B starts at 4
```

User applies `- Exposure` to A.

Expected:

```text
A duration = 1
B still starts at 4
```

The gap grows. B is not pulled because it was not adjacent.

---

## Connected Following Block Definition

A connected following block sequence means:

```text
Frame B starts exactly at Frame A authored end.
Frame C starts exactly at Frame B authored end.
Frame D starts exactly at Frame C authored end.
```

If there is any gap, stop moving.

Example connected sequence:

```text
A start 0, duration 2 → A authored end 2
B start 2, duration 2 → B authored end 4
C start 4, duration 1 → C authored end 5
```

If A changes and affects the next block, B and C should move together.

Example non-connected sequence:

```text
A start 0, duration 2 → A authored end 2
B start 4, duration 2 → B authored end 6
```

B is not connected to A because there is a gap from 2 to 3.

---

## UI Behavior

The existing UI should keep working:

* `○` marks drawing frame heads.
* Held exposure cells appear as block-like areas.
* Empty cells remain blank.
* Frame labels remain 1-based in the UI.
* Internal indexes remain 0-based.
* New Drawing button still creates one sparse frame.
* `+ Exposure` uses push semantics.
* `- Exposure` uses pull semantics.
* Horizontal timeline and X-sheet timeline both reflect the updated resolution.

Do not implement `●` timeline marks yet.

Do not implement double-click behavior yet.

Do not implement frame naming yet.

---

## TimelineController Changes

Update:

```text
lib/src/controllers/timeline_controller.dart
```

Expected areas to update:

* Frame start resolution helpers
* `totalFrameCount`
* `resolveFrameForLayer`
* `isDrawingStartForLayer`
* `isHeldExposureForLayer`
* `exposureStartIndexForLayer`
* `createDrawingFrameForLayer`
* `increaseExposure`
* `decreaseExposure`

Suggested private helpers:

```dart
List<_FrameExposureEntry> _entriesForLayer(Layer layer);

_FrameExposureEntry? _entryForFrame({
  required Layer layer,
  required FrameId frameId,
});

List<_FrameExposureEntry> _connectedFollowingEntries({
  required Layer layer,
  required FrameId frameId,
});

void _shiftFrameStarts({
  required LayerId layerId,
  required Iterable<FrameId> frameIds,
  required int delta,
});
```

These names are suggestions only.

Important:

* Keep public API small.
* Keep helper classes private.
* Throw clear errors for missing layer/frame.
* Keep duration >= 1.
* Avoid modifying model files if possible.

---

## ProjectRepository Changes

Modify only if needed.

Existing `updateFrame()` may be enough for duration changes.

If a layer's frame order must be sorted after start shifts, you may need to update the whole layer.

Allowed:

```dart
void replaceLayer({required Layer layer})
void updateLayer(...)
```

already likely exists.

Avoid adding broad new repository methods unless necessary.

Do not modify persistence services.

---

## CanvasController Interaction

Existing drawing behavior must keep working.

When a user draws on a currently selected held exposure:

* If it resolves to an existing frame, drawing should add strokes to that resolved frame.
* This is acceptable for now.

When user explicitly creates a New Drawing at an empty cell:

* It should create a new frame head at that cell.

Do not implement automatic drawing-frame creation on simple click.

Do not implement double-click behavior.

---

## Tests

Update and add tests primarily under:

```text
test/controllers/timeline_controller_test.dart
test/ui/
```

Update service tests only if repository behavior changes.

---

## timeline_controller_test.dart Required Tests

Add or update tests for the following.

### 1. Last frame holds to visible timeline end

Layer:

```text
Frame A starts at index 0, duration 1
No next frame
```

Verify:

```text
index 0 → A drawing start
index 1 → A held exposure
index 2 → A held exposure
index 10 → A held exposure
```

If a finite visible range is used, test within that range.

### 2. Frame holds until next frame

Layer:

```text
Frame A starts at 0
Frame B starts at 4
```

Verify:

```text
0 → A drawing start
1 → A held exposure
2 → A held exposure
3 → A held exposure
4 → B drawing start
```

### 3. Empty before first frame remains empty

Layer:

```text
Frame A starts at 5
```

Verify:

```text
0 → empty
1 → empty
4 → empty
5 → A drawing start
```

### 4. New drawing creates one sparse frame and holds forward

Select index 10 and create a new drawing.

Verify:

```text
layer.frames.length == 1
index 10 → new frame drawing start
index 11 → held exposure
no frames created at 0 through 9
```

### 5. Increase exposure pushes directly adjacent following blocks

Set up:

```text
A start 0 duration 2
B start 2 duration 2
C start 4 duration 1
```

Increase A.

Verify:

```text
A duration == 3
B start == 3
C start == 5
```

And resolution:

```text
0 → A
1 → A
2 → A
3 → B
5 → C
```

### 6. Increase exposure does not move non-adjacent blocks

Set up:

```text
A start 0 duration 2
B start 4 duration 2
```

Increase A once.

Verify:

```text
A duration == 3
B start == 4
```

### 7. Increase exposure pushes when it collides after gap is consumed

Set up:

```text
A start 0 duration 2
B start 4 duration 2
```

Increase A three times.

Expected:

```text
after first: A duration 3, B start 4
after second: A duration 4, B start 4
after third: A duration 5, B start 5
```

### 8. Decrease exposure pulls directly adjacent following blocks

Set up:

```text
A start 0 duration 3
B start 3 duration 2
C start 5 duration 1
```

Decrease A.

Verify:

```text
A duration == 2
B start == 2
C start == 4
```

### 9. Decrease exposure does not move non-adjacent blocks

Set up:

```text
A start 0 duration 3
B start 5 duration 2
```

Decrease A.

Verify:

```text
A duration == 2
B start == 5
```

### 10. Decrease exposure does not go below 1

Set up:

```text
A duration 1
```

Decrease A.

Verify:

```text
A duration == 1
No following frames move
```

### 11. Dense frame duplication is not introduced

After several increase/decrease operations:

```text
layer.frames.length should equal the number of actual drawing frames.
```

Do not create intermediate frames.

---

## UI Tests

Update only if necessary.

Existing UI tests should still pass with the new semantics.

If any UI test needs adjustment:

* Keep frame labels 1-based.
* Keep keys 0-based.
* Keep `○` for drawing heads.
* Keep held exposure block semantics.
* Keep empty cells blank.
* Do not expect `●`.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/controllers lib/src/ui test/controllers test/ui lib/main.dart
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

Do not run `dart format lib test` unless necessary, because that may reformat unrelated files.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `dart format` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes

---

## Completion Criteria

This task is complete only when:

* Newly created drawing frames hold forward like TVPaint.
* Last frame displays as holding to the visible timeline end.
* A frame holds until the next drawing frame starts.
* Empty space before the first frame remains empty.
* `+ Exposure` increases duration.
* `+ Exposure` pushes directly adjacent following frame blocks.
* `+ Exposure` does not push non-adjacent blocks separated by gaps.
* `- Exposure` decreases duration.
* `- Exposure` pulls directly adjacent following frame blocks.
* `- Exposure` does not pull non-adjacent blocks separated by gaps.
* Duration never goes below 1.
* No dense frame duplication is introduced.
* Sparse timeline behavior is preserved.
* Existing drawing still works.
* Existing New Drawing still works.
* Existing layer selection still works.
* Existing visibility/opacity still works.
* Existing Undo/Redo still works.
* Horizontal timeline still works.
* X-sheet timeline still works.
* Frame labels remain 1-based in UI.
* Internal indexes remain 0-based.
* `○` remains drawing frame head marker.
* `●` is not introduced.
* No timeline mark model is added.
* No double-click behavior is added.
* No frame naming is added.
* No playback is added.
* No state management package is added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 13.

Do not implement `●` inbetween/timesheet marks, double-click behavior, frame naming, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame delete, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only timeline exposure semantics.
