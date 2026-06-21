# Phase 147 Codex Task

## Title

StoryboardPanel interaction tests

## Repository

```txt id="0ulh08"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="52eajd"
master
```

## Project type

```txt id="xgptnl"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 146.

Phase 146 stabilized StoryboardPanel storyboard layer lookup by extracting a pure storyboard layer policy/helper.

Phase 147 should add focused StoryboardPanel interaction tests.

This is primarily a test-only stabilization phase.

## Required references

Before editing, read:

```txt id="p24eb7"
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Phase_146_Codex_Task.md
```

Also inspect:

```txt id="dyvcyh"
lib/src/ui/storyboard_panel.dart
lib/src/ui/storyboard_layer_policy.dart
lib/src/ui/storyboard_timeline_layout.dart
test/ui/storyboard_panel_smoke_test.dart
test/ui/storyboard_layer_policy_test.dart
test/ui/storyboard_timeline_layout_test.dart
```

## Goal

Add interaction-focused widget tests for `StoryboardPanel`.

The goal is to lock down existing interaction behavior before moving toward brush architecture.

This phase should protect:

```txt id="87rfcq"
- inactive cut tap calls onCutSelected with the exact CutId
- active cut tap does not call onCutSelected
- cut selection works across multiple tracks
- cut selection uses CutId identity, not cut name
- duplicate cut names do not break selection
- storyboard layer presence or absence does not change cut selection behavior
- StoryboardPanel remains a storyboard/conte overview, not a drawing canvas
- StoryboardPanel does not own timeline range semantics
```

Do not add new UI features.

Do not add drawing/canvas/brush behavior.

## Strong scope rule

This should be a test-only phase unless a real bug is found.

Preferred changed files:

```txt id="vqogju"
test/ui/storyboard_panel_interaction_test.dart
```

Optional changed files:

```txt id="8br7n2"
test/ui/storyboard_panel_smoke_test.dart
test/ui/storyboard_panel_test_fixtures.dart
```

Only create a shared test fixture file if duplication becomes distracting.

Avoid production changes.

If a production change is required to make a legitimate interaction test pass, keep it minimal and explain clearly in the report.

## Required test file

Create:

```txt id="3kjl03"
test/ui/storyboard_panel_interaction_test.dart
```

## Required interaction tests

Add focused widget tests covering the following.

### 1. Tapping an inactive cut calls onCutSelected once

Given:

```txt id="7rpsx8"
- a project with at least two cuts
- activeCutId = cut-a
```

When:

```txt id="826f3o"
tap storyboard-cut-block-cut-b
```

Expected:

```txt id="tzybdr"
onCutSelected is called exactly once
selected CutId is CutId('cut-b')
```

Use stable keys, not fragile text position assumptions.

### 2. Tapping the active cut does not call onCutSelected

Given:

```txt id="u0l5yt"
- activeCutId = cut-a
```

When:

```txt id="abcn0n"
tap storyboard-cut-block-cut-a
```

Expected:

```txt id="bsnvp3"
onCutSelected is not called
```

Reason:

`StoryboardPanel` currently passes `onTap: null` for the active cut.

This behavior should be protected.

### 3. Cut selection works across multiple tracks

Given:

```txt id="av66n8"
V1: cut-a
V2: cut-b
```

When:

```txt id="kxdgf9"
tap storyboard-cut-block-cut-b
```

Expected:

```txt id="fk003h"
onCutSelected receives CutId('cut-b')
```

This protects StoryboardPanel as a multi-track storyboard/conte overview.

### 4. Selection uses CutId, not cut name

Given:

```txt id="xvjvmn"
- two cuts with the same display name
- different CutId values
```

When:

```txt id="a60gnc"
tap the second cut by key
```

Expected:

```txt id="bnuakx"
onCutSelected receives the second cut's CutId
```

Do not rely on cut name text for identity.

Cut name is a display label.

CutId is the true identity.

### 5. Storyboard layer presence does not affect cut selection

Given:

```txt id="3h6stb"
- cut-a has a storyboard layer
- cut-b has no storyboard layer
```

When:

```txt id="lg7b3o"
tap cut-b
```

Expected:

```txt id="k1a5ic"
onCutSelected receives CutId('cut-b')
```

Selection must be cut-block based.

It must not depend on whether a cut has a storyboard layer strip.

### 6. Storyboard layer absence still keeps cut block tappable

Given:

```txt id="ihz53l"
- a cut with no LayerKind.storyboard layer
- No Storyboard Layer empty state is shown
```

When:

```txt id="xdbpqb"
tap that cut block while inactive
```

Expected:

```txt id="iaebhr"
onCutSelected receives that CutId
```

The empty storyboard layer state must not block cut selection.

### 7. Existing stable keys remain available during interaction tests

At minimum, interaction tests should continue to rely on these keys:

```txt id="963yfb"
storyboard-panel
storyboard-track-row-<trackId>
storyboard-track-timeline-area-<trackId>
storyboard-cut-block-<cutId>
storyboard-cut-positioned-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
storyboard-timeline-horizontal-viewport
```

Do not rename stable keys.

## Test style requirements

Use widget tests.

Prefer stable keys:

```dart id="yv6z8a"
find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b'))
```

Avoid relying on fragile text position.

Text assertions are okay only when testing visible labels or empty states.

Do not test implementation-private widget class names.

Do not depend on render pixel colors.

Do not add golden tests.

Do not add screenshots.

## Model construction rules for tests

Use the existing immutable models.

Avoid const lists containing non-const model constructors.

Correct:

```dart id="j4w1ar"
frames: [
  Frame(id: const FrameId('frame-a'), duration: 1, strokes: const []),
],
```

Wrong:

```dart id="8ah451"
frames: const [
  Frame(...),
],
```

`Frame(...)` is not a const constructor.

`TimelineExposure.drawing(...)` is also not a const constructor.

## Architecture rules

Storyboard rules:

```txt id="e6xctm"
- Storyboard is an ordinary Layer(kind: storyboard).
- A Cut may have at most one storyboard layer.
- StoryboardPanel is not a drawing canvas.
- StoryboardPanel reads Project data.
- StoryboardPanel must not mutate Project data.
- StoryboardPanel must not create storyboard layers.
- StoryboardPanel must not edit storyboard metadata.
```

Identity rules:

```txt id="ouihll"
- CutId is the true identity of a Cut.
- LayerId is the true identity of a Layer.
- Cut.name is a display label.
- Layer.name is a display label.
- Duplicate Cut names are allowed.
- Duplicate Layer names are allowed.
```

Timeline range rules:

```txt id="8vogcp"
- Cut.duration is playback/export duration only.
- Cut.duration is not authored/data extent.
- Cut.duration is not the editability limit.
- Cut.duration is not the selected exposure outline limit.
- StoryboardPanel must not own timeline range semantics.
- StoryboardPanel must not import TimelineController.
- StoryboardPanel must not use authoredTimelineExtentFrameCount.
```

## Out of scope

Do not add:

```txt id="a0j5jm"
canvas
drawing canvas
brush engine
stroke rendering
onion skin
undo/redo
save/load
Provider
Riverpod
Bloc
ChangeNotifier
CustomPainter
renderer changes
tile engine changes
cache changes
persistence changes
storyboard thumbnail rendering
storyboard drawing
storyboard image import
storyboard export
storyboard metadata editing UI
Cut inspector
metadata side panel
layer reorder
layer folder
layer lock
sound section
camera section
```

Do not change:

```txt id="ukmpe3"
TimelinePanel
LayerTimelineGrid
TimelineController
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineLayerControlsHeader
TimelineLayerControlsRow
TimelineVerticalScrollbarRail
TimelineHorizontalScrollbarRail
TimelineFrameScrollViewport
TimelineFrameRowsScrollBody
TimelineFrameGridStack
TimelineLayerFrameBodyLayout
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
TimelinePlayhead
Cut.duration semantics
authoredTimelineExtentFrameCount semantics
selected exposure range semantics
visible frame range semantics
```

Do not weaken existing tests.

Do not remove existing StoryboardPanel smoke tests.

Do not remove Phase 146 storyboard layer policy tests.

## Expected changed files

Likely:

```txt id="skltnz"
test/ui/storyboard_panel_interaction_test.dart
```

Possibly:

```txt id="7pjflq"
test/ui/storyboard_panel_smoke_test.dart
test/ui/storyboard_panel_test_fixtures.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="yyqvam"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="dn60wx"
- changed files
- whether this stayed test-only
- interaction tests added
- confirmation that inactive cut tap calls onCutSelected once
- confirmation that active cut tap does not call onCutSelected
- confirmation that selection works across multiple tracks
- confirmation that selection uses CutId, not cut name
- confirmation that duplicate cut names do not break selection
- confirmation that storyboard layer presence/absence does not affect cut selection
- confirmation that stable StoryboardPanel keys were not renamed
- confirmation that StoryboardPanel still does not import/use TimelineController
- confirmation that no timeline range semantics were changed
- confirmation that no canvas/drawing/brush code was added
- confirmation that no undo/redo or save/load code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no CustomPainter was added
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 147 is complete when:

```txt id="owfc52"
- StoryboardPanel interaction tests exist.
- Inactive cut selection is protected.
- Active cut non-selection is protected.
- Multi-track cut selection is protected.
- Duplicate cut name behavior is protected by CutId-based assertions.
- Empty storyboard layer state does not block cut selection.
- Existing StoryboardPanel smoke and policy tests still pass.
- Existing timeline stabilization tests still pass.
- No canvas/drawing/brush/stroke/rendering/undo/save/state-management framework work was added.
```
