# Phase 144 Codex Task

## Title

Add timeline long-term range semantics regression tests

## Goal

Add regression tests that lock the long-term timeline range semantics from the UI side.

This phase should verify that timeline UI behavior does not accidentally collapse these separate concepts:

```txt id="p9u21f"
- Cut.duration
- playbackFrameCount
- visible/display frame range
- authored/data extent
- selected exposure range outline
```

This is the final test-focused stabilization phase before the Phase 145 checkpoint.

Do not change production behavior.

## Required references

Before editing code, read:

```txt id="bnso9v"
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

Also inspect the current tests added in recent phases:

```txt id="25j5tg"
test/controllers/timeline_controller_responsibility_test.dart
test/ui/timeline_panel_smoke_test.dart
test/ui/layer_timeline_grid_extracted_composition_test.dart
test/ui/layer_timeline_grid_test.dart
```

## Why this phase exists

Recent phases stabilized:

```txt id="quecqe"
- extracted timeline layout widgets
- TimelinePanel smoke behavior
- TimelineController responsibility boundaries
```

Now we need one final regression test layer before checkpointing the timeline work.

The important long-term rule is:

```txt id="spcj3t"
Cut.duration is playback/export duration only.
It must not become the authored data extent.
It must not become the UI editability limit.
It must not limit visible cells or selected exposure outlines by itself.
```

## Target files to inspect

Inspect current implementation and tests first:

```txt id="swuhny"
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/timeline_panel.dart
lib/src/ui/timeline/timeline_frame_rows_scroll_body.dart
lib/src/ui/timeline/timeline_frame_grid_stack.dart
lib/src/ui/timeline/timeline_playhead.dart
lib/src/ui/timeline/timeline_body_cut_end_boundary.dart
lib/src/ui/timeline/timeline_ruler_cut_end_boundary.dart
lib/src/controllers/timeline_controller.dart
```

Do not invent new production APIs.

Do not add new stable production keys.

## Test file

Prefer creating:

```txt id="68shm9"
test/ui/timeline_long_term_range_semantics_test.dart
```

If the repository already has a better existing timeline semantics test file, adding a new group there is acceptable.

## Scope

This phase should normally add tests only.

Production code should not change unless required to fix an existing analyzer/test issue.

## Required test themes

Write tests against current public widgets/APIs only.

Use real model objects where possible:

```txt id="m124ph"
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
TimelineExposure
```

Use current constructor patterns from existing tests.

### 1. Timeline UI can render cells beyond playback duration when visible

Create a setup where:

```txt id="kms3ah"
playbackFrameCount / Cut.duration is small, for example 3
the visible timeline range still includes later cells because of the current UI's minimum/safety visible range behavior
```

Render through the current public timeline widget that best represents this behavior, preferably `TimelinePanel` or `LayerTimelineGrid`.

Verify that a cell beyond playback duration exists, for example:

```txt id="d2csty"
timeline-cell-<layerId>-10
```

Only use a frame index that is naturally visible under the current implementation.

Do not force production code to render more cells.

### 2. Out-of-playback authored frame can still be represented

Create a layer with an authored `TimelineExposure` beyond `Cut.duration` / `playbackFrameCount`.

Example:

```txt id="h7w19m"
Cut.duration or playbackFrameCount = 3
TimelineExposure at frame 10
```

Verify the existing UI can represent that authored frame if the frame cell is visible.

Use current stable keys/text/marks from existing tests.

Do not add new UI indicators.

### 3. Cut-end boundary is visual playback boundary, not authored data boundary

Render a timeline with:

```txt id="wpu9g2"
playbackFrameCount = 3
authored exposure beyond frame 3
```

Verify existing cut-end boundary keys still render:

```txt id="57qrht"
timeline-cut-end-boundary
timeline-cut-end-boundary-ruler
```

The test should express that the cut-end boundary is a visual playback boundary and does not remove authored cells beyond it.

Do not assert fragile pixel-perfect coordinates unless existing helper tests already do so.

### 4. Playhead can exist independently of authored extent

If the current implementation supports current frame inside visible range but beyond authored data, render with:

```txt id="nwffx3"
currentFrameIndex > authoredTimelineExtentFrameCount
```

Verify:

```txt id="glsrla"
timeline-playhead
timeline-playhead-column
```

still render if the current frame is visible.

Do not force visibility if the current frame is outside the current public visible range policy.

### 5. Selected exposure outline is display-range visual highlight

If current existing tests expose selected exposure state through `TimelineCellExposureState`, add a regression test that verifies the selected exposure range outline can render without being limited by `Cut.duration`.

Use existing stable key pattern:

```txt id="hr1uy6"
timeline-selected-exposure-range-outline-<layerId>
```

Do not change selected exposure semantics.

If current public test setup cannot naturally create this case, skip it and report why.

### 6. TimelinePanel does not expose authoredTimelineExtentFrameCount to UI

This should be a code-structure regression check only if the project already has similar source-text tests.

Do not add brittle file-grep tests unless the repository already uses that style.

Prefer behavior tests.

If skipped, report that this was intentionally skipped to avoid brittle implementation tests.

## Strong prohibitions

Do not change production behavior.

Do not change:

```txt id="zf60jq"
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
- TimelineController
- StoryboardPanel
```

Do not add:

```txt id="x9h3gh"
- canvas
- drawing canvas
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

```txt id="rrh5ws"
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

## Avoid fragile tests

Avoid:

```txt id="t1jhd1"
- exact colors
- exact border widths
- screenshot/image comparison
- raw drag offset assertions
- private implementation classes
- tests that require pixel-perfect coordinates
- brittle source-code grep unless the repo already uses that pattern
```

Prefer stable keys and public behavior.

## If a required theme is not supported by current public API

Do not expand production code.

Do not add APIs.

In the final report, clearly state:

```txt id="wydwv8"
Skipped because the current public API/test setup does not expose this behavior safely.
```

## Required checks

Run:

```bash id="sqqrvi"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="22o31o"
1. TimelinePanel still opens.
2. A short cut still shows the cut-end boundary at the playback end.
3. Timeline cells beyond playback duration still appear when visible.
4. Authored frames beyond playback duration do not disappear merely because they are beyond Cut.duration.
5. Playhead still aligns with current frame.
6. Selected exposure outline still aligns with frame cells.
7. Horizontal scrolling still moves frame rows with ruler/header.
8. Vertical scrolling still keeps layer rows and frame rows aligned.
9. Frame selection remains unchanged.
10. Layer selection remains unchanged.
11. StoryboardPanel behavior is unchanged.
```

## Report back

Report:

```txt id="c5eewg"
- changed files
- new test file
- whether production code changed
- tested long-term range semantics
- skipped themes and reasons
- stable keys tested
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
