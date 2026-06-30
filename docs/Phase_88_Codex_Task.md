# Phase 88 Codex Task - StoryboardPanel Shared Timeline Positioning

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Recent relevant phases:

* Phase 85:

    * Added `StoryboardTimelineLayoutEntry`.
    * Added `buildStoryboardTimelineLayout(Project)`.
    * StoryboardPanel Cut blocks now have derived:

        * `startFrame`
        * `endFrame`
        * `duration`
        * `trackIndex`
        * `cutIndex`
        * `cutId`
        * `trackId`
    * StoryboardPanel shows compact frame range:
      `storyboard-cut-frame-range-<cutId>`

* Phase 86:

    * Added shared timeline primitives:

        * `TimelineScale`
        * `TimelineBlock`
    * StoryboardPanel Cut blocks use `TimelineBlock`.

* Phase 87:

    * Extracted shared `timelineBlockDecoration`.
    * TimelinePanel cell decoration now uses shared timeline block style helper.
    * TimelinePanel behavior and keys were preserved.

## Phase goal

Use the existing shared timeline primitives and Phase 85 layout coordinates to render StoryboardPanel Cut blocks in a real timeline-positioned area.

Current StoryboardPanel still visually places Cut blocks mostly by Row order.

This phase should make StoryboardPanel use:

```text id="6t76uv"
left = startFrame * TimelineScale.pixelsPerFrame
width = duration * TimelineScale.pixelsPerFrame with visual min width policy
```

This is still a read-only layout/navigation phase.

No editing behavior should be added.

## Important design direction

StoryboardPanel and TimelinePanel should keep sharing small timeline primitives.

Use existing shared UI helpers:

```text id="d33ikh"
lib/src/ui/timeline/timeline_scale.dart
lib/src/ui/timeline/timeline_block.dart
```

Do not create a separate StoryboardPanel-only scale or block system.

Do not rewrite TimelinePanel in this phase.

## Required implementation

### 1. Use TimelineScale for horizontal positioning

StoryboardPanel already uses `TimelineScale.widthForDuration`.

Now also use:

```dart id="c99ga1"
TimelineScale.leftForFrame(entry.startFrame)
```

Each Cut block should get:

```text id="k3cv4x"
left = scale.leftForFrame(entry.startFrame)
width = scale.widthForDuration(entry.duration)
```

The minimum visual width policy may remain visual-only.

Do not mutate Project data.

Do not serialize TimelineScale.

Do not add zoom UI.

### 2. Add track timeline area

Each StoryboardPanel track row should contain a timeline content area.

Add stable key:

```text id="4w8pdn"
storyboard-track-timeline-area-<trackId>
```

The timeline area should contain a `Stack`.

Each Cut block should be wrapped by a positioned wrapper.

Add stable key:

```text id="p5lpra"
storyboard-cut-positioned-<cutId>
```

Do not remove the existing Cut block key:

```text id="kj4msn"
storyboard-cut-block-<cutId>
```

Expected structure concept:

```text id="4hmit4"
track row
  track label
  horizontal timeline area
    Stack
      Positioned(left: cutAStart, width: cutAWidth)
        TimelineBlock(key: storyboard-cut-block-cutA)
      Positioned(left: cutBStart, width: cutBWidth)
        TimelineBlock(key: storyboard-cut-block-cutB)
```

### 3. Calculate timeline area width

The timeline area should be wide enough to contain the last Cut.

Suggested calculation:

```text id="9i7lna"
maxEndFrame = max(entry.endFrame for this track)
timelineWidth = maxEndFrame * pixelsPerFrame
```

If minimum visual Cut width causes the last block to extend beyond `endFrame * pixelsPerFrame`, account for that visually.

Safer formula:

```text id="e2nhmd"
timelineWidth = max(leftFor(entry.startFrame) + widthForDuration(entry.duration))
```

for all entries on that track.

Keep enough width so no Cut block is clipped.

### 4. Preserve existing StoryboardPanel behavior

StoryboardPanel must still show:

* V-style track labels
* Cut title
* Cut duration
* Cut frame range
* Storyboard layer strip or empty placeholder
* active Cut indicator
* active Cut highlight
* Cut block tap behavior

Existing stable keys must remain unchanged:

```text id="8ticfh"
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-cut-frame-range-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
```

New keys:

```text id="mnpuu8"
storyboard-track-timeline-area-<trackId>
storyboard-cut-positioned-<cutId>
```

### 5. Preserve active Cut sync

Do not change HomePage active Cut wiring unless strictly necessary.

StoryboardPanel must still receive:

* `activeCutId`
* `onCutSelected`

Tapping an inactive Cut block should still call `onCutSelected(cut.id)`.

Tapping the active Cut may remain no-op.

### 6. Keep TimelinePanel stable

Do not modify TimelinePanel behavior in this phase.

Do not change TimelinePanel frame/cell keys.

Do not change TimelinePanel selection, exposure, layer row, scroll, or frame behavior.

Phase 88 is about StoryboardPanel positioning only, using shared primitives.

## Tests required

### 1. StoryboardPanel positioning tests

Update:

```text id="m72nox"
test/ui/storyboard_panel_test.dart
```

Add/verify:

* each track has:
  `storyboard-track-timeline-area-<trackId>`
* each Cut has:
  `storyboard-cut-positioned-<cutId>`
* existing Cut block key still exists:
  `storyboard-cut-block-<cutId>`
* second Cut appears to the right of first Cut
* frame range key still exists
* active indicator still appears
* tapping inactive Cut still calls `onCutSelected`
* frame range row remains overflow-safe

Use stable key-based finders.

Avoid broad `find.text('Cut 1')` assertions.

### 2. TimelineScale tests

Update existing tests if needed:

```text id="pvxqp3"
test/ui/timeline/timeline_scale_test.dart
```

Verify:

* `leftForFrame(0) == 0`
* `leftForFrame(24) == 24 * pixelsPerFrame`
* `widthForDuration(12)` respects visual min width policy
* track timeline width calculation does not clip minimum-width blocks, if a helper is added

### 3. Storyboard timeline layout tests

Existing tests must still pass:

```text id="v0t2j2"
test/ui/storyboard_timeline_layout_test.dart
```

No Project mutation.

Multiple tracks calculate independently.

Sequential Cut start/end frames stay correct.

### 4. Regression tests

All existing tests must still pass:

* StoryboardPanel tests
* TimelinePanel tests
* HomePage integration tests
* Cut create/duplicate/delete/reorder tests
* layer rename/delete/kind toggle tests

## Out of scope

Do not implement:

* StoryboardPanel drag
* StoryboardPanel resize
* trim handles
* cut reorder from StoryboardPanel
* gap/free placement model
* playhead
* zoom controls
* scroll controller sync
* timeline ruler
* exposure editing
* comma extension
* metadata editing
* thumbnails
* renderer/cache work
* export/PDF/image output
* selected-track export
* audio/sound/camera tracks
* new LayerKind values
* new Project/Track/Cut/Layer/Frame fields
* save/load format changes
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* StoryboardPanel Cut blocks are placed by `startFrame` x-coordinate.
* Cut block width is derived from `duration`.
* Positioning uses shared `TimelineScale`.
* Cut block visual shell remains shared `TimelineBlock`.
* Track timeline area key exists.
* Cut positioned wrapper key exists.
* Existing StoryboardPanel keys remain stable.
* Active Cut sync still works.
* Frame range display remains overflow-safe.
* TimelinePanel behavior is unchanged.
* No Project data is mutated.
* No persistent model is added.
* No editing behavior is added.
* No horizontal or vertical overflow is introduced.
* All existing tests pass.
* New positioning tests pass.
* `dart format lib test` passes.
* `flutter analyze` passes.
* `flutter test` passes.
* `git status` is clean.

## Required checks

Run:

```text id="nt51ld"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* how StoryboardPanel timeline area is structured
* how Cut left/width are calculated
* whether TimelineScale was reused
* whether TimelineBlock remains used
* new keys added
* confirmation that existing StoryboardPanel keys were preserved
* confirmation that active Cut sync still works
* confirmation that TimelinePanel behavior was unchanged
* confirmation that no Project data is mutated
* confirmation that no editing behavior was added
* tests added/updated
* final check results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
