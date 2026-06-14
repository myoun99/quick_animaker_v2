# Phase 85 Codex Task - Storyboard Timeline Layout Coordinates

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Recent relevant phases:

* Phase 83:

    * Added a read-only `StoryboardPanel`.
    * It shows project-level tracks as V-style rows.
    * It shows Cut blocks by duration.
    * It detects `LayerKind.storyboard` inside each Cut.

* Phase 84:

    * `StoryboardPanel` now receives `activeCutId`.
    * `StoryboardPanel` now receives `onCutSelected`.
    * Cut blocks are tappable.
    * Active Cut block is visually highlighted.
    * StoryboardPanel Cut selection syncs with Canvas, TimelinePanel, and CutListBar.

* Phase 84 follow-up:

    * StoryboardPanel vertical layout was compacted to avoid HomePage test overflow.
    * Active indicator remains visible with key:
      `storyboard-cut-active-indicator-<cutId>`.

Long-term Storyboard Panel direction is documented in:

```text
docs/LongTerm_StoryboardPanel_TimelineDesign.md
```

The long-term direction is a Premiere/DaVinci-like timeline view for storyboard/cut planning.

## Phase goal

Introduce a small timeline layout coordinate foundation for StoryboardPanel.

The StoryboardPanel currently renders Cut blocks in order, but it does not explicitly calculate timeline positions.

This phase should calculate each Cut block's timeline position from:

```text
track.cuts order + cut.duration
```

For each Cut on a project-level track, calculate:

```text
startFrame
endFrame
duration
trackIndex
cutId
```

This is still a read-only layout/navigation phase.

No editing should be added.

## Why this phase matters

A Premiere-style storyboard timeline eventually needs:

* Cut block positions
* Cut start/end frame ranges
* playhead placement
* zoom/scroll behavior
* trim/resize
* drag/reorder
* selected-track export flattening

All of those require a clear timeline coordinate foundation.

This phase should create that foundation without adding editing behavior yet.

## Core behavior

For each Track:

```text
Track.cuts = [Cut A duration 24, Cut B duration 12, Cut C duration 36]
```

The calculated layout entries should be:

```text
Cut A: startFrame 0,  endFrame 24
Cut B: startFrame 24, endFrame 36
Cut C: startFrame 36, endFrame 72
```

Each track should calculate its own local timeline.

For now, there is no global free placement or gap model.

Cuts are sequential within each Track.

## Required implementation

### 1. Add Storyboard timeline layout helper

Add a small UI/service helper to calculate layout entries.

Suggested location:

```text
lib/src/ui/storyboard_timeline_layout.dart
```

Suggested class names:

```dart
class StoryboardTimelineLayoutEntry {
  final TrackId trackId;
  final CutId cutId;
  final int trackIndex;
  final int cutIndex;
  final int startFrame;
  final int endFrame;
  final int duration;
  final Cut cut;
}
```

Suggested helper:

```dart
List<StoryboardTimelineLayoutEntry> buildStoryboardTimelineLayout(Project project)
```

Exact names may follow project style.

Important:
This helper is not a new project model.

It is only a derived UI layout plan.

It must not be serialized.

It must not mutate Project.

### 2. Use layout entries inside StoryboardPanel

Update StoryboardPanel to render Cut blocks from the calculated timeline layout entries.

StoryboardPanel should still show:

* V-style track labels
* Cut blocks
* Cut title
* Cut duration
* Storyboard Layer strip or empty placeholder
* active Cut highlight
* tap behavior

Existing stable keys must remain unchanged:

```text
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
```

### 3. Add start/end frame display

Add minimal frame range display inside each Cut block.

Suggested text:

```text
0f - 24f
```

Suggested stable key:

```text
storyboard-cut-frame-range-<cutId>
```

For a Cut with duration 24 starting at 0:

```text
storyboard-cut-frame-range-cut-a
text: 0f - 24f
```

For the next Cut with duration 12:

```text
storyboard-cut-frame-range-cut-b
text: 24f - 36f
```

Keep the display compact to avoid HomePage overflow.

Do not reintroduce vertical overflow.

### 4. Keep existing duration display

Do not remove:

```text
storyboard-cut-duration-<cutId>
```

It may continue to show:

```text
24f
```

The frame range display is additional.

If vertical space becomes too tight, the frame range may be displayed as small text in the same row as duration.

### 5. Keep active Cut sync unchanged

StoryboardPanel must still receive:

* `activeCutId`
* `onCutSelected`

Cut blocks must still be tappable.

Active indicator must still work.

Cut selection must still use HomePage's existing `_handleCutSelected` flow.

No new state management should be introduced.

## Tests required

### 1. Layout helper tests

Add tests for the layout helper.

Suggested file:

```text
test/ui/storyboard_timeline_layout_test.dart
```

Test cases:

* single track with one Cut:

    * startFrame 0
    * endFrame equals duration

* single track with multiple Cuts:

    * Cut A 24f: 0 - 24
    * Cut B 12f: 24 - 36
    * Cut C 36f: 36 - 72

* multiple Tracks:

    * each Track calculates independently from 0
    * V1 Cut A starts at 0
    * V2 Cut X also starts at 0

* zero or invalid duration:

    * follow existing model policy if duration validation already exists
    * do not invent new duration rules unless necessary

* building layout does not mutate Project

### 2. StoryboardPanel widget tests

Update `test/ui/storyboard_panel_test.dart`.

Add/verify:

* frame range text appears for the first Cut
* frame range text appears for the second Cut using cumulative duration
* frame range key:
  `storyboard-cut-frame-range-<cutId>`
* active indicator still appears
* tapping inactive Cut still calls `onCutSelected`
* storyboard strip and empty placeholder still render
* panel remains compact enough not to overflow in its isolated widget tests

### 3. HomePage integration tests

Existing Phase 84 tests should still pass:

* StoryboardPanel Cut selection syncs active Cut surfaces
* CutListBar switching updates StoryboardPanel highlight

Add a minimal integration assertion if useful:

* HomePage StoryboardPanel includes frame range for active/default Cut

Avoid broad `find.text('Cut 1')` assertions.

Use stable keys.

## Out of scope

Do not implement:

* cut block drag
* cut block resize
* trim handles
* cut reorder from StoryboardPanel
* gap/free placement
* playhead
* zoom controls
* scroll controller sync
* exposure editing
* comma extension
* frame selection sync
* metadata editing
* thumbnails
* renderer/cache work
* export/PDF/image output
* selected-track export
* composite output
* audio/sound/camera tracks
* new LayerKind values
* new Project/Track/Cut/Layer/Frame model fields
* save/load format changes
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* Storyboard timeline layout entries are calculated from Track.cuts order and Cut.duration.
* Each Cut has calculated startFrame and endFrame.
* Multiple Tracks calculate independently.
* StoryboardPanel renders from the layout entries.
* StoryboardPanel displays a compact frame range for each Cut.
* Existing StoryboardPanel keys remain stable.
* Active Cut selection sync still works.
* No Project data is mutated.
* No new persistent model is added.
* No editing behavior is added.
* No HomePage vertical overflow is reintroduced.
* All existing tests pass.
* New layout helper tests pass.
* `dart format lib test` passes.
* `flutter analyze` passes.
* `flutter test` passes.
* `git status` is clean.

## Required checks

Run:

```text
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* layout helper location/name
* how startFrame/endFrame are calculated
* StoryboardPanel frame range key
* confirmation that existing StoryboardPanel keys were preserved
* confirmation that active Cut sync still works
* confirmation that no Project data is mutated
* confirmation that no editing behavior was added
* tests added/updated
* final check results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
