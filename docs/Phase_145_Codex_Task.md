# Phase 145 Codex Task

## Title

Create timeline stabilization checkpoint documentation

## Goal

Create a final timeline stabilization checkpoint document.

This phase closes the current timeline refactoring / stabilization line before moving to the next major area.

Do not change production code.

Do not change tests unless required by formatting or documentation links.

## Required references

Before editing, read:

```txt id="7xt5bw"
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

Also inspect recent timeline and storyboard stabilization tests:

```txt id="ryv1lu"
test/ui/timeline_panel_smoke_test.dart
test/ui/timeline_long_term_range_semantics_test.dart
test/controllers/timeline_controller_responsibility_test.dart
test/ui/layer_timeline_grid_extracted_composition_test.dart
test/ui/storyboard_panel_smoke_test.dart
```

## Why this phase exists

Recent work stabilized the timeline system through extraction and tests.

This checkpoint should summarize:

```txt id="tw5kls"
- what is now stable
- what semantics must not be broken
- which stable keys exist
- which tests protect the behavior
- what should happen next
```

This document will be used as the handoff source for the next GPT chat.

## Required output file

Create:

```txt id="2wndz6"
docs/Timeline_Stabilization_Checkpoint.md
```

If the file already exists, update it.

## Optional handoff update

If this file exists:

```txt id="51949p"
docs/Handoff_QuickAnimaker_v2_Current.md
```

add a short section pointing to:

```txt id="k8qx7o"
docs/Timeline_Stabilization_Checkpoint.md
```

Do not rewrite the whole handoff file unless necessary.

If the handoff file does not exist, do not create a replacement unless the repository already expects that file.

## Required checkpoint contents

The checkpoint document must include these sections.

### 1. Status

State that the timeline refactoring / stabilization line is complete through Phase 145.

Mention that the next major area should start after handoff.

Recommended next order:

```txt id="s77qgo"
1. Storyboard / conte panel stabilization
2. 2D brush architecture
3. Canvas / drawing implementation
```

### 2. Timeline architecture overview

Summarize the current high-level responsibility split.

Include:

```txt id="xernpo"
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
```

Keep this descriptive, not implementation-heavy.

### 3. Stable key inventory

List the important stable keys that must be preserved.

Include at least:

```txt id="96lybh"
timeline-sticky-header-row
timeline-frame-ruler
timeline-frame-ruler-scrub-area
timeline-frame-header-row
timeline-frame-header-<frameIndex>
timeline-frame-header-leading-spacer
timeline-frame-header-trailing-spacer
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-horizontal-scrollbar
timeline-vertical-scrollbar
timeline-vertical-scrollbar-slot
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-playhead
timeline-playhead-column
timeline-cut-end-boundary
timeline-cut-end-boundary-ruler
timeline-cell-<layerId>-<frameIndex>
timeline-selected-exposure-range-outline-<layerId>
timeline-layer-row-<layerId>
timeline-layer-name-<layerId>
timeline-layer-kind-icon-<layerId>
timeline-layer-visibility-<layerId>
timeline-layer-opacity-<layerId>
timeline-add-layer-button
timeline-vertical-scrollbar-track
timeline-vertical-scrollbar-thumb
timeline-bottom-scrollbar-rail
timeline-horizontal-scrollbar-track
timeline-horizontal-scrollbar-thumb
timeline-horizontal-scrollbar-viewport
timeline-frame-rows-scroll-body
timeline-frame-row-area-<layerId>
timeline-scrollable-body
timeline-layer-rows-scroll-body
```

### 4. Long-term range semantics

Summarize the critical rules from:

```txt id="kxplwq"
docs/LongTerm_Timeline_Range_Semantics.md
```

Include these exact concepts:

```txt id="7tfz7i"
- Cut.duration is playback/export duration only.
- Cut.duration is not authored/data extent.
- Cut.duration is not the editability limit.
- Cut.duration is not the selected exposure outline limit.
- TimelineController.authoredTimelineExtentFrameCount is authored/data extent only.
- authoredTimelineExtentFrameCount must not be reintroduced into UI widgets as a visible range limit.
- visible frame range is UI/display policy.
- selected exposure outline is a display-range visual highlight.
- authored frames beyond Cut.duration can exist.
- editing beyond Cut.duration must not auto-extend Cut.duration.
```

### 5. Layer ordering semantics

Document:

```txt id="qjaxlr"
- Raw timeline layer order is [A, B, C].
- Horizontal display order is reversed [C, B, A].
- Vertical XSheet raw order remains [A, B, C].
- New layer insertion is after active layer in raw order.
- Layer names may duplicate.
- Layer identity is by LayerId.
```

### 6. Storyboard semantics relevant to timeline

Document:

```txt id="uwmj40"
- Storyboard is represented as an ordinary Layer(kind: storyboard).
- A cut may have at most one storyboard layer.
- StoryboardPanel is not a drawing canvas yet.
- StoryboardPanel must not own timeline range semantics.
```

### 7. Protected tests

Summarize the important test files added or stabilized during recent phases.

Include:

```txt id="x0z9zg"
test/ui/timeline_layer_controls_widgets_test.dart
test/ui/timeline_vertical_scrollbar_rail_test.dart
test/ui/timeline_horizontal_scrollbar_rail_test.dart
test/ui/timeline_frame_scroll_viewport_test.dart
test/ui/timeline_frame_rows_scroll_body_test.dart
test/ui/timeline_frame_grid_stack_test.dart
test/ui/timeline_layer_frame_body_layout_test.dart
test/ui/layer_timeline_grid_extracted_composition_test.dart
test/ui/timeline_panel_smoke_test.dart
test/controllers/timeline_controller_responsibility_test.dart
test/ui/timeline_long_term_range_semantics_test.dart
test/ui/storyboard_panel_smoke_test.dart
```

If any file name differs in the repository, use the actual current file name.

### 8. Manual verification checklist

Include a checklist for future maintainers:

```txt id="v14hxj"
1. TimelinePanel opens.
2. Frame ruler/header render correctly.
3. Layer controls rail remains fixed on the left.
4. Vertical scrollbar slot remains between layer rail and frame grid.
5. Bottom horizontal scrollbar remains under frame grid only.
6. Horizontal scrolling moves frame rows with ruler/header.
7. Vertical scrolling keeps layer rows and frame rows aligned.
8. Playhead aligns with current frame.
9. Cut-end boundary aligns with playback end.
10. Cells beyond playback duration can still appear when visible.
11. Authored frames beyond Cut.duration are not hidden merely because they exceed Cut.duration.
12. Selected exposure outline aligns with frame cells.
13. Layer selection still works.
14. Frame selection still works.
15. StoryboardPanel still opens.
```

### 9. Next recommended phases

Document the next order:

```txt id="j50lrx"
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
Phase 148: 2D brush model / brush settings architecture
Phase 149: Brush input sampling tests
Phase 150: Canvas viewport foundation
```

Do not implement these phases now.

## Strong prohibitions

Do not change production code.

Do not change:

```txt id="xsxrlu"
- TimelinePanel
- LayerTimelineGrid
- TimelineController
- StoryboardPanel
- Project / Track / Cut / Layer / Frame models
- Cut.duration semantics
- playbackFrameCount semantics
- authoredTimelineExtentFrameCount semantics
- selected exposure range semantics
- visible frame range semantics
```

Do not add:

```txt id="08m6qu"
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

Do not reintroduce `authoredTimelineExtentFrameCount` into UI widgets.

## Required checks

Run:

```bash id="7ntk3j"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Report back

Report:

```txt id="045dvn"
- changed files
- checkpoint document created/updated
- whether handoff file was updated
- confirmation that production code was not changed
- confirmation that tests were not changed unless necessary
- confirmation that no canvas/drawing/brush code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no CustomPainter was added
- check results
- git status summary
```
