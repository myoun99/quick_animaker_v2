# Phase 143 Codex Task

## Title

Add TimelineController responsibility baseline tests

## Goal

Add focused tests that lock the current public behavior and responsibility boundaries of `TimelineController`.

This is a timeline stabilization phase before the Phase 145 checkpoint.

Do not change production behavior.

## Required references

Before editing code, read:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

Preserve all timeline range and project model rules.

## Why this phase exists

Recent phases stabilized the timeline UI structure:

```txt
PR187: TimelineFrameScrollViewport
PR189: TimelineFrameRowsScrollBody
PR191: TimelineFrameGridStack
PR194: TimelineLayerFrameBodyLayout
PR195: tests for TimelineLayerFrameBodyLayout
PR197: TimelinePanel baseline smoke tests
PR198: fix TimelinePanel smoke test tap target
```

Now the next risk is not visual layout.

The next risk is responsibility drift:

```txt
- current frame
- active layer
- frame selection
- layer selection
- playback duration
- authored/data extent
- visible frame range
```

This phase should add baseline tests for the existing `TimelineController` public behavior so future storyboard / brush / canvas work does not accidentally change timeline semantics.

## Target files to inspect

Inspect current implementation and tests first:

```txt
lib/src/controllers/timeline_controller.dart
test/controllers/timeline_controller_test.dart, if present
test/ui/timeline_panel_smoke_test.dart
test/ui/layer_timeline_grid_extracted_composition_test.dart
docs/LongTerm_Timeline_Range_Semantics.md
```

Use the current production implementation as the source of truth.

Do not invent new production APIs.

Do not rename existing APIs.

Do not add Provider, Riverpod, ChangeNotifier, or any new state management package.

## Test file

Prefer creating:

```txt
test/controllers/timeline_controller_responsibility_test.dart
```

If the repository already has an existing `TimelineController` test file, adding a new group there is acceptable.

## Scope

This phase should normally add tests only.

Production code should not change unless required to fix an existing analyzer/test issue.

## Required test themes

Because the exact current `TimelineController` public API may have changed, inspect the implementation first and write tests against the existing public API.

Do not force a new API to satisfy these tests.

### 1. Current frame is playback cursor state

Test that the controller’s current frame behavior matches the current implementation.

If the controller exposes something like:

```txt
currentFrameIndex
setCurrentFrame
selectFrame
```

then verify that changing the current frame updates only the current-frame state and does not mutate project data.

Do not test UI widgets here.

### 2. Active layer is selection state

If the controller exposes active layer state, verify selecting/changing active layer updates the active layer only.

Use real `LayerId` objects.

Do not mutate layer order unless existing controller behavior already does so.

### 3. Frame selection and layer selection remain separate responsibilities

If both frame and layer selection exist, verify:

```txt
- selecting a frame does not accidentally change active layer unless current production behavior says it should
- selecting a layer does not accidentally change current frame unless current production behavior says it should
```

Use current production behavior as source of truth.

Do not redesign selection semantics.

### 4. Cut.duration remains playback/export duration

Read `docs/LongTerm_Timeline_Range_Semantics.md`.

Verify, using existing public API if available, that:

```txt
Cut.duration is treated as playback/export duration.
Editing or authored extent must not be inferred from Cut.duration alone.
```

If the controller currently exposes:

```txt
playbackFrameCount
visibleFrameCount
authoredTimelineExtentFrameCount
```

then add tests that lock the current distinction.

### 5. authoredTimelineExtentFrameCount is authored/data extent only

If `TimelineController.authoredTimelineExtentFrameCount` exists, add focused tests for it.

The key semantic rule:

```txt
authoredTimelineExtentFrameCount must not be used as the visible UI limit.
```

Test the current calculation behavior using real cuts/layers/frames.

Do not add references to `authoredTimelineExtentFrameCount` into UI widgets.

### 6. Visible frame count is not authored extent

If the controller exposes `visibleFrameCount`, test that it represents display/playback visibility policy, not authored data extent.

Do not change its current behavior.

Only lock the current expected behavior.

### 7. Editing beyond Cut.duration does not auto-extend Cut.duration

If the controller currently supports adding/selecting/editing frames beyond `Cut.duration`, add a test verifying that doing so does not mutate `Cut.duration`.

If the current controller does not support editing beyond duration yet, do not invent that functionality.

Instead, add a comment in the test report that this case was skipped because the public API does not currently expose editing beyond duration.

### 8. Empty project/cut/layer safety

If current controller supports empty project/cut/layer states, add simple tests verifying no crash and stable default state.

Do not add new empty-state behavior unless required by existing tests.

## Strong prohibitions

Do not change production behavior.

Do not change:

```txt
- Cut.duration semantics
- playbackFrameCount semantics
- authoredTimelineExtentFrameCount semantics
- visible frame range semantics
- selected exposure range semantics
- frame selection semantics
- layer selection semantics
- Project / Track / Cut / Layer / Frame models
- TimelinePanel
- LayerTimelineGrid
- StoryboardPanel
```

Do not add:

```txt
- canvas
- drawing
- brush engine
- stroke rendering
- onion skin
- undo/redo
- save/load
- Provider
- Riverpod
- ChangeNotifier
- CustomPainter
```

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt
TimelinePanel
LayerTimelineGrid
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
TimelineLayerControlsHeader
TimelineLayerControlsRow
TimelineVerticalScrollbarRail
TimelineHorizontalScrollbarRail
TimelineFrameScrollViewport
TimelineFrameRowsScrollBody
TimelineFrameGridStack
TimelineLayerFrameBodyLayout
StoryboardPanel
```

## If TimelineController API is smaller than expected

If `TimelineController` currently has fewer public APIs than this task describes, do not expand it.

Write tests only for public behavior that already exists.

In the final report, clearly state which responsibility themes were covered and which were skipped because there is no existing public API.

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

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt
1. TimelinePanel still opens.
2. Current frame display still updates normally.
3. Frame cell click still selects the frame.
4. Layer row/name click still selects the layer.
5. Active layer visual remains correct.
6. Playhead still aligns with the current frame column.
7. Selected exposure outline still aligns with frame cells.
8. Cut.duration is not changed by ordinary frame selection.
9. Timeline range behavior is unchanged.
10. StoryboardPanel behavior is unchanged.
```

## Report back

Report:

```txt
- changed files
- new test file
- whether production code changed
- TimelineController public APIs covered
- responsibility themes covered
- responsibility themes skipped due to missing public API
- confirmation that Cut.duration semantics did not change
- confirmation that playbackFrameCount semantics did not change
- confirmation that authoredTimelineExtentFrameCount semantics did not change
- confirmation that no UI widget reintroduced authoredTimelineExtentFrameCount
- confirmation that no canvas/drawing/brush code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no CustomPainter was added
- check results
- git status summary
```
