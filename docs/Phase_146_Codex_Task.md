# Phase 146 Codex Task

## Title

StoryboardPanel stabilization / feature foundation

## Repository

```txt
myoun99/quick_animaker_v2
```

## Base branch

```txt
master
```

## Project type

```txt
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 145.

Phase 145 closed the timeline refactoring / stabilization line with a checkpoint document.

This Phase 146 starts the next recommended area:

```txt
Storyboard / conte panel stabilization
```

This is still not a canvas phase.

Do not implement drawing, brush, rendering, save/load, undo/redo, or state-management framework work.

## Required references

Before editing, read:

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

Also inspect:

```txt
lib/src/ui/storyboard_panel.dart
lib/src/ui/storyboard_timeline_layout.dart
test/ui/storyboard_panel_smoke_test.dart
test/ui/storyboard_timeline_layout_test.dart
```

## Goal

Stabilize StoryboardPanel behavior as a storyboard/conte overview panel.

The goal is to protect these rules:

```txt
- Storyboard is represented as an ordinary Layer(kind: storyboard).
- A Cut may have at most one storyboard layer.
- StoryboardPanel is not a drawing canvas.
- StoryboardPanel must not own timeline range semantics.
- StoryboardPanel must read Project / Track / Cut / Layer data without mutating project data.
- StoryboardPanel should remain a multi-track storyboard/conte overview surface.
```

This phase may add a small pure helper/policy and focused tests.

Keep the change small.

## Important design rules

### Storyboard layer rule

Storyboard is not a separate Cut.storyboardLayer.

Correct model:

```txt
Cut
  layers: [
    Layer(kind: animation),
    Layer(kind: storyboard),
    Layer(kind: animation),
  ]
```

The storyboard layer is an ordinary `Layer`.

It is selected by:

```txt
Layer.kind == LayerKind.storyboard
```

Do not select storyboard layers by name.

Do not create `Cut.storyboardLayer`.

Do not create `StoryboardLayer` as a new model.

Do not move storyboard panels out of `Cut.layers`.

### One storyboard layer per cut

A cut may have at most one storyboard layer.

If a helper finds more than one `LayerKind.storyboard` layer in a single Cut, it should not silently pick the first one.

Preferred behavior:

```txt
throw StateError
```

Reason:

Multiple storyboard layers in a single Cut violates the current model invariant and should be surfaced early.

### Timeline range semantics

Do not let StoryboardPanel redefine timeline range semantics.

The following must remain true:

```txt
Cut.duration is playback/export duration only.
Cut.duration is not authored/data extent.
Cut.duration is not the editability limit.
Cut.duration is not the selected exposure outline limit.
TimelineController.authoredTimelineExtentFrameCount is authored/data extent only.
authoredTimelineExtentFrameCount must not be reintroduced into UI widgets as a visible range limit.
visible frame range is UI/display policy.
selected exposure outline is a display-range visual highlight.
authored frames beyond Cut.duration can exist.
editing beyond Cut.duration must not auto-extend Cut.duration.
```

StoryboardPanel may display cut blocks using cut durations.

StoryboardPanel must not import or depend on `TimelineController`.

StoryboardPanel must not use authored timeline extent to decide storyboard cut block size.

StoryboardPanel must not own selected exposure range policy.

StoryboardPanel must not own horizontal frame virtualization policy.

## Required production changes

### 1. Add a small storyboard layer policy/helper

Preferred file:

```txt
lib/src/ui/storyboard_layer_policy.dart
```

Preferred public function:

```dart
Layer? storyboardLayerForCut(Cut cut)
```

Behavior:

```txt
- Return null if the cut has no LayerKind.storyboard layer.
- Return the storyboard Layer if exactly one exists.
- Throw StateError if more than one LayerKind.storyboard layer exists in the same Cut.
- Do not mutate the Cut.
- Do not mutate Layers.
- Do not inspect layer names.
- Do not inspect Frame data.
- Do not inspect timeline authored extent.
- Do not depend on TimelineController.
- Do not depend on renderer/canvas/brush code.
```

The helper should use only model data.

Expected imports should be minimal:

```dart
import '../models/cut.dart';
import '../models/layer.dart';
import '../models/layer_kind.dart';
```

Exact relative import path may vary depending on final file location.

### 2. Update StoryboardPanel to use the helper

In:

```txt
lib/src/ui/storyboard_panel.dart
```

Replace the private storyboard layer lookup logic with the new helper.

Remove the private helper if it becomes unused.

Keep existing stable keys unchanged:

```txt
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-track-label-row-<trackId>
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
storyboard-timeline-horizontal-viewport
storyboard-track-label-rail
storyboard-timeline-scroll-content
```

Do not rename existing keys.

Do not change the public constructor of `StoryboardPanel` unless absolutely necessary.

Do not change visual styling unless required by the helper extraction.

## Required tests

### 1. Add storyboard layer policy tests

Preferred file:

```txt
test/ui/storyboard_layer_policy_test.dart
```

Required test cases:

```txt
storyboardLayerForCut returns null when no storyboard layer exists
storyboardLayerForCut returns the ordinary Layer(kind: storyboard) when exactly one exists
storyboardLayerForCut finds storyboard layer regardless of layer name
storyboardLayerForCut finds storyboard layer regardless of raw layer position
storyboardLayerForCut throws StateError when a cut has multiple storyboard layers
storyboardLayerForCut does not mutate the Cut
```

Important test details:

```txt
- Include animation layers above and below the storyboard layer.
- Use duplicate or misleading layer names to prove selection is by LayerKind, not name.
- Use LayerId as identity, not name.
- Avoid const lists containing non-const Frame or TimelineExposure constructors.
```

Correct pattern:

```dart
frames: [
  Frame(id: const FrameId('head'), duration: 1, strokes: const []),
],
```

Do not write:

```dart
frames: const [
  Frame(...),
],
```

because `Frame(...)` is not a const constructor.

### 2. Extend or add StoryboardPanel stabilization tests

You may extend:

```txt
test/ui/storyboard_panel_smoke_test.dart
```

or create:

```txt
test/ui/storyboard_panel_stabilization_test.dart
```

Required coverage:

```txt
StoryboardPanel renders a storyboard layer that is between animation layers in raw Cut.layers order
StoryboardPanel still renders empty state when no storyboard layer exists
StoryboardPanel does not select storyboard layer by name
StoryboardPanel surfaces invalid multiple-storyboard-layer cuts with StateError
StoryboardPanel keeps existing stable keys
StoryboardPanel keeps cut selection callback behavior for inactive cuts
StoryboardPanel renders multi-track rows as storyboard/conte overview, not as a drawing canvas
```

### 3. Extend storyboard timeline layout tests if useful

Existing file:

```txt
test/ui/storyboard_timeline_layout_test.dart
```

Add coverage only if it stays small.

Useful tests:

```txt
buildStoryboardTimelineLayout ignores layers and frames when calculating cut block frame ranges
buildStoryboardTimelineLayout uses Cut.duration for storyboard cut block duration
buildStoryboardTimelineLayout does not mutate Project
buildStoryboardTimelineLayout keeps each Track starting from frame 0 independently
```

Do not turn this into a full timeline range semantics test.

The long-term timeline range semantics are already protected elsewhere.

This phase only protects storyboard/conte overview assumptions.

## Out of scope

Do not add:

```txt
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

```txt
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

Do not reintroduce `authoredTimelineExtentFrameCount` into StoryboardPanel or storyboard layout code.

Do not weaken protected timeline tests.

## Expected changed files

Likely changed files:

```txt
docs/Phase_146_Codex_Task.md
lib/src/ui/storyboard_layer_policy.dart
lib/src/ui/storyboard_panel.dart
test/ui/storyboard_layer_policy_test.dart
test/ui/storyboard_panel_smoke_test.dart
```

Possibly changed files:

```txt
test/ui/storyboard_panel_stabilization_test.dart
test/ui/storyboard_timeline_layout_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt
- changed files
- helper/policy file added
- helper function name
- confirmation that StoryboardPanel still treats storyboard as ordinary Layer(kind: storyboard)
- confirmation that multiple storyboard layers in one Cut are not silently accepted
- confirmation that storyboard layer lookup does not use Layer.name
- confirmation that Project/Cut/Layer data is not mutated
- confirmation that stable StoryboardPanel keys were not renamed
- confirmation that StoryboardPanel does not import/use TimelineController
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

Phase 146 is complete when:

```txt
- docs/Phase_146_Codex_Task.md exists.
- Storyboard layer lookup is covered by a small pure policy/helper.
- StoryboardPanel uses that helper instead of owning ad-hoc storyboard layer search logic.
- A cut with no storyboard layer still shows the empty storyboard layer state.
- A cut with exactly one Layer(kind: storyboard) still shows the storyboard layer strip.
- A cut with multiple storyboard layers fails loudly instead of silently picking one.
- Tests prove storyboard layer lookup is by LayerKind, not by Layer.name.
- Existing StoryboardPanel stable keys remain intact.
- Existing timeline stabilization tests still pass.
- No canvas/drawing/brush/stroke/rendering/undo/save/state-management framework work was added.
```
