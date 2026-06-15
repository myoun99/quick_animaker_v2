# Phase 90 Codex Task - StoryboardPanel Fixed Track Label Rail Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Recent relevant phases:

* Phase 85:

    * Added StoryboardTimelineLayoutEntry.
    * Added buildStoryboardTimelineLayout(Project).
    * StoryboardPanel can derive Cut startFrame/endFrame/duration.

* Phase 86:

    * Added shared TimelineScale.
    * Added shared TimelineBlock.
    * StoryboardPanel Cut blocks use TimelineBlock.

* Phase 87:

    * TimelinePanel cell decoration started using shared timelineBlockDecoration.

* Phase 88:

    * StoryboardPanel Cut blocks became timeline-positioned with Stack/Positioned.
    * Added:

        * storyboard-track-timeline-area-<trackId>
        * storyboard-cut-positioned-<cutId>

* Follow-up fixes:

    * Compact horizontal overflow was fixed.
    * Compact vertical overflow was fixed.

* Phase 89:

    * Added horizontal StoryboardPanel timeline viewport.
    * Added:

        * storyboard-timeline-horizontal-viewport
    * Wide timeline content can now be displayed safely.

## Phase goal

Split the StoryboardPanel into:

```text id="dnr2pl"
fixed track label rail | horizontally scrollable timeline content
```

This phase should make track labels stay visually fixed on the left while the timeline content area scrolls horizontally.

This is still a read-only layout foundation.

Do not add editing behavior.

## Long-term direction

StoryboardPanel is moving toward a Premiere/DaVinci-like multi-track timeline structure.

The target concept is:

```text id="s6v3av"
V1 | [Cut 001--------][Cut 002----][Cut 003----------]
V2 |      [Alt Cut-----]       [Reference---]
V3 | [Memo/Temp/Revision---------------------]
```

This phase should only build the fixed-label/layout foundation.

Do not implement drag, trim, resize, playhead, zoom, ruler, or scroll sync with TimelinePanel.

## Required implementation

### 1. Add a fixed track label rail

Add a stable key:

```text id="2wrcm9"
storyboard-track-label-rail
```

The label rail should contain the existing per-track labels.

Preserve existing per-track label key:

```text id="6zm0tq"
storyboard-track-label-<trackId>
```

Track labels should no longer be part of the horizontally scrolling timeline content if this can be done safely.

### 2. Keep horizontal viewport for timeline content

Preserve existing viewport key:

```text id="g9r7hi"
storyboard-timeline-horizontal-viewport
```

This viewport should contain the wide positioned timeline content.

Add a stable key for the scroll content if useful:

```text id="j2jggf"
storyboard-timeline-scroll-content
```

The scroll content should contain the per-track timeline lanes and Cut blocks.

### 3. Preserve track timeline areas

Preserve existing key:

```text id="hd0sml"
storyboard-track-timeline-area-<trackId>
```

The timeline area should still be the positioned lane for a given track.

If the existing `_StoryboardTrackRow` must be split into label and lane pieces, keep the existing `storyboard-track-row-<trackId>` key on a stable per-track logical wrapper or lane wrapper.

Do not remove or rename it.

### 4. Preserve positioned Cut structure

Cut blocks must still use:

```text id="uw19zc"
TimelineScale.leftForFrame(entry.startFrame)
TimelineScale.widthForDuration(entry.duration)
TimelineBlock
```

Preserve existing keys:

```text id="bzzl4a"
storyboard-cut-positioned-<cutId>
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-cut-frame-range-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
```

Do not revert to Row-based Cut layout.

Do not remove Stack/Positioned layout.

### 5. Keep label/lane vertical alignment stable

The fixed label rail and timeline lanes must align vertically.

Each label row and its corresponding timeline lane should have the same height.

If the current implementation uses a track lane height constant, reuse it.

If a new small internal constant is needed, keep it private to StoryboardPanel.

Do not introduce new persistent model data.

### 6. Keep timeline width calculation safe

The timeline content width must still use the visual-width-safe formula:

```text id="nr2ria"
max(TimelineScale.leftForFrame(entry.startFrame) + TimelineScale.widthForDuration(entry.duration))
```

Keep the small trailing padding introduced in Phase 89 if still needed.

Do not calculate timeline width only from max endFrame.

### 7. Preserve compact Cut block safety

Do not regress the compact overflow fixes.

Cut block text must remain:

```text id="p2m6wy"
maxLines: 1
overflow: TextOverflow.ellipsis
softWrap: false
```

Do not reintroduce natural-height overflow.

Do not change the Cut block Column back to a dangerous layout that causes compact height overflow.

### 8. Preserve active Cut sync

StoryboardPanel must still receive:

```text id="grcq4t"
activeCutId
onCutSelected
```

Tapping an inactive Cut block must still call:

```dart id="ja1pwh"
onCutSelected(cut.id)
```

Tapping the active Cut may remain no-op.

### 9. Preserve existing StoryboardPanel keys

Do not remove or rename:

```text id="d1k48j"
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-timeline-horizontal-viewport
storyboard-track-timeline-area-<trackId>
storyboard-cut-positioned-<cutId>
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-cut-frame-range-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
```

Add:

```text id="mr3vxu"
storyboard-track-label-rail
```

Optional new key:

```text id="49scvl"
storyboard-timeline-scroll-content
```

### 10. Keep TimelinePanel unchanged

Do not modify TimelinePanel behavior in this phase.

Do not modify TimelinePanel frame/cell keys.

Do not modify TimelinePanel selection, exposure, layer row, frame row, drag, copy/paste, or frame commands.

## Suggested structure

A possible structure is:

```text id="j7win6"
StoryboardPanel
  title
  Row
    fixed label rail
      track label row V1
      track label row V2
      track label row V3
    Expanded
      horizontal viewport
        timeline scroll content
          timeline lane for V1
            Stack / Positioned Cut blocks
          timeline lane for V2
            Stack / Positioned Cut blocks
          timeline lane for V3
            Stack / Positioned Cut blocks
```

This is only a suggested structure.

Use the safest minimal change based on the current code.

## Tests required

Update:

```text id="3ggfc7"
test/ui/storyboard_panel_test.dart
```

Add or verify:

* `storyboard-track-label-rail` exists.
* `storyboard-timeline-horizontal-viewport` still exists.
* `storyboard-timeline-scroll-content` exists if added.
* Existing `storyboard-track-label-<trackId>` still exists.
* Existing `storyboard-track-timeline-area-<trackId>` still exists.
* Existing `storyboard-cut-positioned-<cutId>` still exists.
* Existing `storyboard-cut-block-<cutId>` still exists.
* A long sequential timeline pumps without overflow.
* Track label is outside the horizontal scroll content.
* Track labels and timeline lanes remain vertically aligned.
* Active Cut indicator still works.
* Tapping inactive Cut still calls `onCutSelected`.
* Compact Cut block overflow tests still pass.

Use key-based finders.

Avoid broad text finders such as:

```text id="cfmnqk"
find.text('Cut 1')
```

unless scoped or clearly safe.

## Out of scope

Do not implement:

* timeline ruler
* playhead
* zoom
* scroll sync with TimelinePanel
* vertical multi-track scrolling
* cut drag
* cut resize
* trim handles
* cut reorder from StoryboardPanel
* cut creation/deletion from StoryboardPanel
* exposure editing
* comma extension
* storyboard metadata editing
* thumbnails
* renderer/cache changes
* export
* audio/sound/camera tracks
* new LayerKind values
* Project/Track/Cut/Layer/Frame model changes
* save/load changes
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* StoryboardPanel has a fixed track label rail.
* Timeline content remains horizontally scrollable.
* Track labels stay outside the horizontal scroll content.
* Timeline lanes and track labels align vertically.
* Positioned Cut blocks still use TimelineScale.
* TimelineBlock remains used.
* Existing StoryboardPanel keys are preserved.
* New label rail key exists.
* Active Cut sync still works.
* Compact Cut block overflow fixes are preserved.
* TimelinePanel behavior is unchanged.
* No Project data is mutated.
* No editing behavior is added.
* All existing tests pass.
* New fixed-label tests pass.
* `dart format lib test` passes.
* `flutter analyze` passes.
* `flutter test` passes.
* `git status` is clean.

## Required checks

Run:

```text id="h2093l"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* fixed label rail structure
* horizontal viewport structure
* new keys added
* confirmation that existing StoryboardPanel keys were preserved
* confirmation that Cut blocks still use TimelineScale left/width
* confirmation that TimelineBlock remains used
* confirmation that active Cut sync still works
* confirmation that compact overflow fixes were preserved
* confirmation that TimelinePanel behavior was unchanged
* confirmation that no Project data is mutated
* confirmation that no editing behavior was added
* tests added/updated
* final check results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
