# Phase 142 Codex Task

## Title

Add TimelinePanel baseline smoke tests

## Goal

Add focused baseline smoke tests for the existing `TimelinePanel`.

This phase resumes the timeline stabilization line after the StoryboardPanel baseline smoke test.

Do not change production behavior.

## Required references

Before editing code, read:

```txt id="kou9v2"
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

Preserve all timeline range and project model rules.

## Why this phase exists

Recent phases stabilized the internal `LayerTimelineGrid` structure:

```txt id="ghjdob"
PR187: TimelineFrameScrollViewport
PR189: TimelineFrameRowsScrollBody
PR191: TimelineFrameGridStack
PR194: TimelineLayerFrameBodyLayout
PR195: tests for TimelineLayerFrameBodyLayout
```

Then PR196 added StoryboardPanel baseline tests.

Now the timeline stabilization should return to the upper-level `TimelinePanel`.

This phase should lock the current `TimelinePanel` baseline behavior before further responsibility-boundary cleanup.

## Target files to inspect

Inspect existing implementation and tests first:

```txt id="nd41c0"
lib/src/ui/timeline/timeline_panel.dart
lib/src/ui/timeline/layer_timeline_grid.dart
test/ui/timeline_panel_test.dart, if present
test/ui/layer_timeline_grid_extracted_composition_test.dart
test/ui/layer_timeline_grid_test.dart
```

Use the current production implementation as the source of truth.

Do not invent new production APIs.

Do not invent new production keys.

## Test file

Prefer creating:

```txt id="9da2d4"
test/ui/timeline_panel_smoke_test.dart
```

If an existing `TimelinePanel` test file already exists and the project clearly prefers using it, adding a new group there is acceptable.

## Widget under test

Test:

```txt id="i5tgxo"
TimelinePanel
```

Use the actual constructor from production code.

Use real model objects where possible:

```txt id="7ij6db"
Project
Track
Cut
Layer
Frame
CanvasSize
ProjectId
TrackId
CutId
LayerId
FrameId
```

Reuse current test helpers if they already exist.

Do not add test-only production constructors.

## Required baseline tests

### 1. TimelinePanel renders without throwing

Render a minimal project with:

```txt id="wqxoxz"
- one project
- one track
- one cut
- at least one layer
- at least one frame
```

Verify `TimelinePanel` renders successfully.

If `TimelinePanel` already has a stable root key, verify it exactly once.

Do not add a new root key in this phase.

### 2. LayerTimelineGrid structure is present through TimelinePanel

Verify that rendering `TimelinePanel` naturally renders the existing timeline structure keys from `LayerTimelineGrid`.

Use keys that currently exist, such as:

```txt id="mvqad6"
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-rows-scroll-body
```

Only test keys that are naturally present in the current `TimelinePanel` render setup.

Do not force production code to expose new keys.

### 3. Frame ruler/header structure remains present

If `TimelinePanel` currently renders the frame ruler/header through `LayerTimelineGrid`, verify existing keys such as:

```txt id="dg4uus"
timeline-frame-ruler
timeline-frame-header-row
```

If those keys are not present in the current render setup, inspect production code and use the current existing keys.

Do not add keys.

### 4. Layer row and frame cell still appear

With at least one layer and visible frame range, verify existing downstream keys still appear through `TimelinePanel`, for example:

```txt id="0v55od"
timeline-layer-row-<layerId>
timeline-frame-row-area-<layerId>
timeline-cell-<layerId>-<frameIndex>
```

Use the actual layer ID and current key patterns.

### 5. Current frame / playhead baseline appears

Set up the current frame so it is inside the visible frame range.

Verify existing playhead keys appear:

```txt id="l0ha5m"
timeline-playhead
timeline-playhead-column
```

Do not test `TimelinePlayhead` internals here.

### 6. Add layer callback still reaches TimelinePanel boundary

If `TimelinePanel` exposes or forwards an add-layer callback, tap:

```txt id="vsi8de"
timeline-add-layer-button
```

and verify the callback is invoked.

If the current `TimelinePanel` does not expose this callback directly, skip this test rather than changing production code.

### 7. Frame selection callback still reaches TimelinePanel boundary

If `TimelinePanel` exposes or forwards frame selection, tap a stable frame cell key and verify the callback receives the expected frame index.

If the current constructor does not expose this directly, skip this test.

Do not add new callbacks.

### 8. Layer selection callback still reaches TimelinePanel boundary

If `TimelinePanel` exposes or forwards layer selection, tap a stable layer row or frame cell and verify the callback receives the expected `LayerId`.

If the current constructor does not expose this directly, skip this test.

Do not add new callbacks.

### 9. No duplicate structural keys

Verify the important structural keys appear exactly once when rendered:

```txt id="wzokqu"
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-rows-scroll-body
timeline-horizontal-scrollbar
timeline-bottom-scrollbar-rail
timeline-vertical-scrollbar-slot
timeline-vertical-scrollbar
timeline-playhead
timeline-playhead-column
```

If a key is not currently rendered in the chosen setup, do not force it. Adjust the setup only using existing constructor parameters.

## Avoid fragile tests

Do not use fragile assertions such as:

```txt id="f651mr"
- exact colors
- exact borders
- screenshot/image comparison
- raw drag/scroll offset changes
- pixel-perfect coordinates
- private widget types
- assumptions about implementation wrappers not expressed by stable keys
```

This phase is a high-level smoke test for current `TimelinePanel` behavior.

## Do not change

Do not change production behavior.

Do not change:

```txt id="qwyx1q"
- TimelinePanel production behavior
- LayerTimelineGrid production behavior
- TimelineController behavior
- Project / Track / Cut / Layer / Frame models
- Cut.duration semantics
- playbackFrameCount semantics
- TimelineController.authoredTimelineExtentFrameCount semantics
- selected exposure range semantics
- visible frame range semantics
- frame selection semantics
- layer selection semantics
```

Do not add:

```txt id="s8y7ld"
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

```txt id="5lz5yo"
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
```

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Do not redesign UI.

## Required checks

Run:

```bash id="1q3orr"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="wzbmq6"
1. TimelinePanel still opens.
2. Frame ruler/header still render normally.
3. Layer controls rail remains on the left.
4. Vertical scrollbar slot remains between layer controls rail and frame grid.
5. Bottom horizontal scrollbar remains under the frame grid only.
6. Frame grid rows still render in the same order.
7. Frame cells still render for every visible layer.
8. Frame cell click still selects the frame.
9. Frame cell click still selects the layer.
10. Selected exposure outline still aligns with frame cells.
11. Playhead still aligns with the current frame column.
12. Cut-end boundary still aligns after horizontal and vertical scrolling.
13. Horizontal scrolling moves frame rows with ruler/header.
14. Vertical scrolling moves layer rows and frame rows together.
15. Empty layer placeholder behavior is unchanged.
```

## Report back

Report:

```txt id="7wnzbw"
- changed files
- new test file
- whether production code changed
- test cases added
- stable keys tested
- model constructors used
- callback coverage, if available
- skipped callback tests, if constructor does not expose them
- confirmation that TimelinePanel behavior did not change
- confirmation that LayerTimelineGrid behavior did not change
- confirmation that no canvas/drawing/brush code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no CustomPainter was added
- confirmation that timeline range semantics did not change
- confirmation that authoredTimelineExtentFrameCount was not reintroduced
- check results
- git status summary
```
