# Phase 87 Codex Task - TimelinePanel Frame Block Shared Primitive Adoption

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Recent relevant phases:

* Phase 83:

    * Added read-only StoryboardPanel.

* Phase 84:

    * StoryboardPanel Cut blocks can sync active Cut selection.

* Phase 85:

    * Added StoryboardTimelineLayoutEntry.
    * Added buildStoryboardTimelineLayout(Project).
    * StoryboardPanel Cut blocks show compact frame range.

* Phase 86:

    * Added shared timeline UI primitive folder:
      `lib/src/ui/timeline/`
    * Added:
      `TimelineScale`
    * Added:
      `TimelineBlock`
    * StoryboardPanel Cut blocks now use shared TimelineBlock.
    * TimelinePanel was intentionally not refactored yet.

## Phase goal

Start connecting TimelinePanel to the shared timeline visual primitive system.

The goal is not to rewrite TimelinePanel.

The goal is to make one safe, minimal step so that TimelinePanel frame/cell/block visuals can gradually share the same primitive family as StoryboardPanel.

## Important design rule

Do not reuse the whole TimelinePanel inside StoryboardPanel.

Do not rewrite TimelinePanel architecture.

Do not change TimelinePanel behavior.

This phase should only reduce duplicated visual wrapper/styling logic.

## Target direction

TimelinePanel and StoryboardPanel should share small visual primitives such as:

```text
TimelineBlock
TimelineScale
shared border radius
shared active/selected border treatment
shared block tap shell
shared compact block layout options
```

TimelinePanel still owns:

```text
Layer rows
Frame cells
Exposure logic
Frame selection
Frame keys
Horizontal/vertical timeline rules
```

StoryboardPanel still owns:

```text
Track rows
Cut blocks
Storyboard layer strip display
Cut selection sync
```

## Required implementation

### 1. Inspect TimelinePanel first

Before changing code, inspect the current TimelinePanel implementation.

Find the smallest safe frame/cell/block visual wrapper that can adopt the shared TimelineBlock or shared style.

Look for:

* frame cell width
* frame cell height
* active/selected frame styling
* frame tap behavior
* frame block keys
* frame row/layer row structure
* any existing InkWell/Container decoration duplicated with TimelineBlock

Do not blindly replace large sections.

### 2. Keep existing TimelinePanel behavior

TimelinePanel must keep:

* existing frame/cell keys
* existing tap behavior
* existing selected/active behavior
* existing layer row behavior
* existing horizontal display order
* existing XSheet behavior
* existing frame exposure behavior
* existing tests

Do not rename existing keys.

Do not change public behavior.

### 3. Extend shared primitive only if necessary

If the current TimelineBlock is too StoryboardPanel-sized, extend it minimally.

Allowed safe extensions:

* optional `height`
* optional `borderRadius`
* optional compact padding
* optional active border width
* optional inactive/active color override only if needed
* optional mouse cursor behavior

Do not make TimelineBlock know about Project, Track, Cut, Layer, Frame, Stroke, or storyboard metadata.

TimelineBlock must remain a pure visual primitive.

### 4. Apply shared primitive to TimelinePanel minimally

Preferred approach:

* Identify the smallest TimelinePanel frame/cell visual wrapper.
* Replace only the outer visual shell with TimelineBlock or a shared timeline block style helper.
* Pass existing width/height/padding values so the UI does not visually jump.
* Preserve existing child content.
* Preserve existing tap callback.
* Preserve existing key location as much as possible.

If the existing frame cell cannot safely use TimelineBlock directly, then extract a shared style helper from TimelineBlock and use that in both TimelineBlock and TimelinePanel.

Do not perform a large rewrite.

### 5. Keep StoryboardPanel stable

StoryboardPanel must remain working exactly as before.

Do not remove:

```text
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

Do not break:

* active Cut highlight
* Cut block tap behavior
* frame range overflow fix
* storyboard layer strip display

### 6. Keep TimelineScale stable

Do not remove TimelineScale.

Do not add zoom UI.

Do not add absolute StoryboardPanel positioning in this phase.

This phase is about shared primitive adoption, not timeline coordinate rendering.

## Tests required

### 1. Shared TimelineBlock tests

Update existing TimelineBlock tests if the API is extended.

Verify:

* TimelineBlock still renders child content.
* TimelineBlock still calls tap callback.
* active and inactive states remain visually different.
* compact/height option works if added.
* TimelineBlock remains model-agnostic.

### 2. TimelinePanel regression tests

Existing TimelinePanel-related tests must pass.

Add a small test only if useful:

* a TimelinePanel frame/cell still renders with the same key
* tapping a frame/cell still works
* selected/active frame state still appears
* frame/cell dimensions remain stable enough for existing tests

Do not weaken existing TimelinePanel tests.

Do not replace precise assertions with broad assertions unless the old assertion was already brittle.

### 3. StoryboardPanel regression tests

Existing StoryboardPanel tests must still pass.

Verify:

* StoryboardPanel Cut block still uses TimelineBlock.
* frame range key still exists.
* frame range row does not overflow.
* active indicator still appears.
* tapping inactive Cut still calls onCutSelected.

### 4. HomePage integration tests

Existing HomePage tests must still pass, including:

* CutListBar switching updates StoryboardPanel highlight
* StoryboardPanel Cut selection syncs active Cut
* Cut create/duplicate/delete/reorder tests
* layer rename/delete/kind toggle tests
* TimelinePanel frame/layer tests

## Out of scope

Do not implement:

* StoryboardPanel absolute positioning
* StoryboardPanel drag
* StoryboardPanel resize
* trim handles
* cut reorder from StoryboardPanel
* playhead
* zoom controls
* timeline ruler
* scroll controller sync
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

* TimelinePanel begins using shared timeline visual primitive/style in a minimal safe way.
* TimelinePanel behavior is unchanged.
* Existing TimelinePanel keys remain stable.
* StoryboardPanel remains stable.
* TimelineBlock remains model-agnostic.
* No Project data is mutated.
* No persistent model is added.
* No editing behavior is added.
* No vertical or horizontal overflow is introduced.
* All existing tests pass.
* New/updated shared primitive tests pass.
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
* which TimelinePanel visual element was inspected
* whether TimelineBlock was extended
* how TimelinePanel now uses shared primitive/style
* confirmation that TimelinePanel keys were preserved
* confirmation that TimelinePanel behavior is unchanged
* confirmation that StoryboardPanel still works
* confirmation that frame range overflow fix remains
* confirmation that no Project data is mutated
* confirmation that no editing behavior was added
* tests added/updated
* final check results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
