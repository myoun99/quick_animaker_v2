# Phase 89 Codex Task - StoryboardPanel Timeline Viewport Foundation

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
    * StoryboardPanel can derive:

        * trackIndex
        * cutIndex
        * startFrame
        * endFrame
        * duration

* Phase 86:

    * Added shared TimelineScale.
    * Added shared TimelineBlock.
    * StoryboardPanel Cut blocks use TimelineBlock.

* Phase 87:

    * Extracted shared timelineBlockDecoration.
    * TimelinePanel cell decoration uses shared timeline style helper.

* Phase 88:

    * StoryboardPanel Cut blocks are positioned by:

        * left = TimelineScale.leftForFrame(entry.startFrame)
        * width = TimelineScale.widthForDuration(entry.duration)
    * Added:

        * storyboard-track-timeline-area-<trackId>
        * storyboard-cut-positioned-<cutId>

* Follow-up fixes:

    * Compact horizontal metadata overflow was fixed.
    * Compact vertical Cut block overflow was fixed.
    * StoryboardPanel Cut blocks must remain safe at small widths/heights.

## Phase goal

Add a read-only horizontal timeline viewport foundation to StoryboardPanel.

The StoryboardPanel now uses real timeline coordinates, so the timeline content can become wider than the visible panel.

This phase should make that wide timeline content viewable and overflow-safe through a horizontal viewport/scroll structure.

This is still a read-only layout/navigation foundation.

No editing behavior should be added.

## Important design direction

Long term, StoryboardPanel is a Premiere/DaVinci-like multi-track timeline.

This phase should prepare for that direction without implementing editing.

The goal is not to visually clone Premiere.

The goal is to make the internal layout closer to:

```text id="7qnsuw"
fixed track label area | horizontally scrollable timeline content area
V1                   | [Cut 001------][Cut 002----][Cut 003---------]
V2                   |      [Alt Cut------]
V3                   | [Reference----------------]
```

For this phase, keep the implementation minimal and safe.

## Required implementation

### 1. Add a horizontal viewport around StoryboardPanel timeline content

StoryboardPanel should avoid clipping or overflowing when timelineWidth is wider than the panel.

Add a horizontal scroll/viewport foundation for the timeline content area.

Suggested key:

```text id="pr7vg6"
storyboard-timeline-horizontal-viewport
```

This viewport should contain the positioned Cut blocks.

The viewport may be implemented with:

```dart id="8pfim2"
SingleChildScrollView(
  key: const ValueKey<String>('storyboard-timeline-horizontal-viewport'),
  scrollDirection: Axis.horizontal,
  child: ...
)
```

Use the safest small change based on the current StoryboardPanel structure.

### 2. Preserve track labels

Track labels should remain visible and stable.

Existing key must remain:

```text id="d04cae"
storyboard-track-label-<trackId>
```

Do not remove the current V-style labels.

If a large refactor is required to keep labels fixed while timeline content scrolls, do not do a large refactor in this phase.

Prefer a minimal safe viewport.

### 3. Preserve existing positioned timeline structure

Keep existing keys:

```text id="ot4zgv"
storyboard-track-timeline-area-<trackId>
storyboard-cut-positioned-<cutId>
storyboard-cut-block-<cutId>
```

Each Cut block should still be positioned by TimelineScale.

Do not go back to Row-based Cut ordering.

Do not remove Stack/Positioned layout.

### 4. Keep timeline width calculation safe

The scroll content width should be at least wide enough to contain all positioned Cut blocks.

Continue using the safe visual-width formula:

```text id="482afk"
timelineWidth = max(leftForFrame(entry.startFrame) + widthForDuration(entry.duration))
```

Do not calculate width only from max endFrame if minBlockWidth can cause clipping.

### 5. Add viewport padding only if necessary

If the last Cut is too close to the right edge, it is acceptable to add a small trailing padding.

Do not use arbitrary large padding.

Suggested maximum:

```text id="u96d50"
8px to 16px trailing padding
```

### 6. No editing behavior

Do not add:

* drag
* resize
* trim
* reorder
* cut creation from StoryboardPanel
* cut deletion from StoryboardPanel
* playhead
* zoom controls
* ruler
* scroll sync with TimelinePanel
* keyboard navigation
* selection marquee

This phase is only a viewport foundation.

### 7. Keep compact Cut block safety

Do not regress PR 124/125 overflow fixes.

StoryboardPanel Cut blocks must remain safe at compact size.

Keep text one-line and ellipsis-safe:

```text id="oty6ui"
maxLines: 1
overflow: TextOverflow.ellipsis
softWrap: false
```

Keep vertical layout compact-height-safe.

Do not reintroduce natural-height assumptions.

Do not set the Cut content Column back to `MainAxisSize.min` if that causes overflow.

### 8. Preserve active Cut sync

StoryboardPanel must still receive:

```text id="rn0ehu"
activeCutId
onCutSelected
```

Tapping an inactive Cut block must still call:

```dart id="uth4r8"
onCutSelected(cut.id)
```

Tapping the active Cut may remain no-op.

### 9. Preserve existing StoryboardPanel keys

Do not remove or rename:

```text id="5rvdk7"
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
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

New key:

```text id="7ddn7a"
storyboard-timeline-horizontal-viewport
```

### 10. Keep TimelinePanel unchanged

Do not modify TimelinePanel behavior in this phase.

Do not modify TimelinePanel frame/cell keys.

Do not modify TimelinePanel selection, exposure, layer row, frame row, drag, copy/paste, or frame commands.

## Tests required

Update:

```text id="lm8xc7"
test/ui/storyboard_panel_test.dart
```

Add or verify:

* `storyboard-timeline-horizontal-viewport` exists.
* Existing `storyboard-track-timeline-area-<trackId>` still exists.
* Existing `storyboard-cut-positioned-<cutId>` still exists.
* Existing `storyboard-cut-block-<cutId>` still exists.
* A long timeline with multiple sequential Cuts can be pumped without overflow.
* The last Cut is still present inside the scrollable viewport.
* Active Cut indicator still works.
* Tapping inactive Cut still calls `onCutSelected`.
* Compact Cut blocks remain overflow-safe.

Use key-based finders.

Avoid broad text finders such as:

```text id="p8axiu"
find.text('Cut 1')
```

unless scoped or clearly safe.

## Out of scope

Do not implement:

* timeline ruler
* playhead
* zoom
* scroll sync with TimelinePanel
* vertical multi-track scroll sync
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

* StoryboardPanel has a horizontal timeline viewport.
* Wide timeline content can be displayed without panel overflow.
* Positioned Cut blocks still use TimelineScale.
* TimelineBlock remains used.
* Existing StoryboardPanel keys are preserved.
* New viewport key exists.
* Active Cut sync still works.
* Compact Cut block overflow fixes are preserved.
* TimelinePanel behavior is unchanged.
* No Project data is mutated.
* No editing behavior is added.
* All existing tests pass.
* New viewport tests pass.
* `dart format lib test` passes.
* `flutter analyze` passes.
* `flutter test` passes.
* `git status` is clean.

## Required checks

Run:

```text id="0o2s49"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* how the horizontal viewport is structured
* new key added
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
