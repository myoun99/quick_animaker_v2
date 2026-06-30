# Phase 86 Codex Task - Shared Timeline Visual Primitive Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Important direction change

Do not implement the previous Phase 86 idea as a standalone StoryboardPanel absolute-positioning refactor yet.

The better long-term direction is:

```text id="rfsxf0"
TimelinePanel and StoryboardPanel should share small timeline UI primitives.
```

Do not duplicate a separate StoryboardPanel-only timeline system if existing TimelinePanel visuals and frame/cell/block concepts can be reused or gradually unified.

This phase should create a small shared timeline visual foundation first.

## Current state

Recent relevant phases:

* Phase 83:

    * Added read-only `StoryboardPanel`.
    * Shows V-style project tracks.
    * Shows Cut blocks and storyboard layer strips.

* Phase 84:

    * `StoryboardPanel` receives `activeCutId`.
    * `StoryboardPanel` receives `onCutSelected`.
    * Cut blocks are tappable.
    * Active Cut block is highlighted.
    * StoryboardPanel selection syncs with HomePage active Cut state.

* Phase 85:

    * Added `StoryboardTimelineLayoutEntry`.
    * Added `buildStoryboardTimelineLayout(Project)`.
    * Each Cut now has derived:

        * `trackId`
        * `cutId`
        * `trackIndex`
        * `cutIndex`
        * `startFrame`
        * `endFrame`
        * `duration`
        * original `Cut` reference
    * StoryboardPanel displays compact frame range:
      `storyboard-cut-frame-range-<cutId>`

* Phase 85 follow-up:

    * Fixed right-side overflow in the duration/frame range row.
    * Frame range text is overflow-safe with `Flexible` and ellipsis.

Long-term Storyboard Panel direction is documented in:

```text id="qos7xa"
docs/LongTerm_StoryboardPanel_TimelineDesign.md
```

The long-term goal is a Premiere/DaVinci-like timeline panel, but with a consistent QuickAnimaker timeline visual language.

## Phase goal

Create a shared timeline visual primitive foundation that can be used by both:

```text id="jmm3fy"
TimelinePanel
StoryboardPanel
```

This phase should reduce duplicated block styling and make future timeline features easier to maintain.

The immediate target is:

```text id="za0f2h"
Make StoryboardPanel Cut blocks use shared timeline block primitives/styles.
Prepare TimelinePanel frame/cell blocks to gradually share the same primitives.
```

This is still a visual/layout foundation phase.

No editing behavior should be added.

## Design principle

Do not reuse the entire TimelinePanel inside StoryboardPanel.

That would be wrong because the semantic levels are different:

```text id="wxr22k"
TimelinePanel:
Layer -> Frame / exposure / cel blocks

StoryboardPanel:
Track -> Cut / storyboard strip blocks
```

Instead, extract small reusable UI primitives:

```text id="ubz092"
shared timeline block
shared timeline scale
shared timeline lane constants
shared selected/active border style
shared compact label layout
```

## Required implementation

### 1. Inspect existing TimelinePanel visual structure

Before changing code, inspect the existing TimelinePanel implementation.

Look for existing concepts such as:

* frame cell/block size
* row/lane height
* selected/active border
* hover/tap behavior if any
* frame label text style
* timeline horizontal scrolling
* timeline row spacing
* timeline block color/border style

Do not perform a large TimelinePanel refactor in this phase.

### 2. Add shared timeline UI folder

Preferred location:

```text id="a2bw9z"
lib/src/ui/timeline/
```

Add small shared files as needed.

Suggested files:

```text id="zw70mj"
lib/src/ui/timeline/timeline_block.dart
lib/src/ui/timeline/timeline_scale.dart
```

Exact file names may follow project style.

### 3. Add shared TimelineScale

Add a small scale/helper that can be reused by TimelinePanel and StoryboardPanel.

Suggested API:

```dart id="kwph54"
class TimelineScale {
  const TimelineScale({
    this.pixelsPerFrame = 8.0,
    this.minBlockWidth = 96.0,
  });

  final double pixelsPerFrame;
  final double minBlockWidth;

  double leftForFrame(int frame);
  double widthForDuration(int duration);
}
```

Rules:

* `leftForFrame(frame)` should return `frame * pixelsPerFrame`.
* `widthForDuration(duration)` should return `duration * pixelsPerFrame`, with optional visual minimum if needed.
* Minimum width is visual-only.
* Do not mutate Project data.
* Do not serialize this class.
* Do not add zoom UI yet.

If the existing TimelinePanel already has a scale or width helper, prefer adapting/extracting that instead of duplicating a new incompatible helper.

### 4. Add shared TimelineBlock visual primitive

Add a small reusable timeline block widget or style helper.

Suggested concept:

```dart id="m8spkg"
class TimelineBlock extends StatelessWidget {
  const TimelineBlock({
    super.key,
    required this.width,
    required this.isActive,
    required this.onTap,
    required this.child,
  });

  final double width;
  final bool isActive;
  final VoidCallback? onTap;
  final Widget child;
}
```

Exact API may follow project style.

Important:
This should be a visual primitive, not a model.

It should support:

* width
* active/selected visual state
* tap callback
* compact content
* shared border radius / border / color treatment
* no internal project knowledge

Do not make this widget know about:

* Project
* Track
* Cut
* Layer
* Frame
* Stroke
* Storyboard metadata

It should be reusable by both frame blocks and cut blocks.

### 5. Use shared primitive in StoryboardPanel

Update StoryboardPanel Cut blocks to use the shared primitive or shared style.

StoryboardPanel must still preserve all existing behavior:

* V-style track labels
* Cut title
* Cut duration
* Cut frame range
* Storyboard layer strip or empty placeholder
* active Cut indicator
* active Cut highlight
* Cut block tap behavior

Existing stable keys must remain unchanged:

```text id="s2o75s"
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

The existing `storyboard-cut-block-<cutId>` key may be placed on the shared `TimelineBlock` wrapper or on the inner block, as long as tests still find it.

### 6. Prepare but do not fully refactor TimelinePanel

Do not rewrite TimelinePanel in this phase.

Allowed minimal changes:

* Move existing visual constants into shared timeline style constants.
* Add tests proving shared primitives can represent TimelinePanel-like blocks.
* Optionally replace one very small internal block wrapper if it is safe and does not break tests.

Not allowed:

* large TimelinePanel rewrite
* layer row architecture change
* frame selection behavior change
* frame block key changes
* timeline scroll behavior change
* frame exposure logic change

The safest path is:

```text id="yk1hky"
Phase 86:
Shared primitive introduced + StoryboardPanel uses it.

Later phase:
TimelinePanel frame block gradually adopts shared primitive.
```

### 7. Keep Storyboard timeline layout helper

Do not remove:

```text id="fo3cv9"
StoryboardTimelineLayoutEntry
buildStoryboardTimelineLayout(Project)
storyboard-cut-frame-range-<cutId>
```

They remain valid.

If useful, `StoryboardTimelineLayout` may use the new shared `TimelineScale`.

## Tests required

### 1. Shared timeline primitive tests

Add tests for the new shared timeline helper/widget.

Suggested file:

```text id="v4shln"
test/ui/timeline/timeline_scale_test.dart
test/ui/timeline/timeline_block_test.dart
```

or a combined file:

```text id="dmum5t"
test/ui/timeline_shared_test.dart
```

Test cases:

* `TimelineScale.leftForFrame(0)` returns 0
* `TimelineScale.leftForFrame(24)` returns `24 * pixelsPerFrame`
* `TimelineScale.widthForDuration(12)` returns expected width or min visual width according to policy
* `TimelineBlock` renders child content
* `TimelineBlock` calls tap callback
* `TimelineBlock` has different visual state when active/selected
* `TimelineBlock` does not know about Project/Cut/Layer/Frame models

### 2. StoryboardPanel tests

Update existing StoryboardPanel tests.

Verify:

* existing stable keys still work
* frame range key still exists
* frame range row remains overflow-safe
* active indicator still appears
* tapping inactive Cut still calls `onCutSelected`
* storyboard strip and empty placeholder still render
* StoryboardPanel Cut block uses shared primitive enough to prevent duplicated styling

Avoid broad `find.text('Cut 1')` assertions.

### 3. TimelinePanel regression tests

Existing TimelinePanel-related tests must still pass.

Do not weaken TimelinePanel tests.

Do not rename existing TimelinePanel keys.

### 4. HomePage integration tests

Existing tests must still pass:

* StoryboardPanel active Cut sync
* CutListBar switching updates StoryboardPanel highlight
* Canvas/Timeline/CutListBar remain synchronized
* Cut create/duplicate/delete/rename/reorder tests
* layer rename/delete/kind toggle tests

## Out of scope

Do not implement:

* StoryboardPanel drag
* StoryboardPanel resize
* trim handles
* cut reorder from StoryboardPanel
* gap/free placement
* playhead
* zoom controls
* scroll controller sync
* timeline ruler
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
* new Project/Track/Cut/Layer/Frame fields
* save/load format changes
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* A shared timeline UI primitive foundation exists.
* Shared timeline scale/helper exists or existing scale logic is safely extracted.
* StoryboardPanel Cut blocks use the shared timeline block/style primitive.
* Existing StoryboardPanel keys remain stable.
* Existing active Cut sync still works.
* Existing frame range display still works and does not overflow.
* TimelinePanel behavior is not broken.
* No Project data is mutated.
* No persistent model is added.
* No editing behavior is added.
* No vertical or horizontal overflow is introduced.
* All existing tests pass.
* New shared primitive tests pass.
* `dart format lib test` passes.
* `flutter analyze` passes.
* `flutter test` passes.
* `git status` is clean.

## Required checks

Run:

```text id="h787qw"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* shared timeline primitive files
* shared timeline scale/helper API
* whether existing TimelinePanel code was touched
* how StoryboardPanel now uses the shared primitive
* confirmation that existing StoryboardPanel keys were preserved
* confirmation that active Cut sync still works
* confirmation that frame range overflow remains fixed
* confirmation that no Project data is mutated
* confirmation that no editing behavior was added
* tests added/updated
* final check results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
