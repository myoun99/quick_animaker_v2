# Phase 132 Codex Task

## Title

Extract timeline frame scroll viewport widget

## Goal

Extract the frame grid horizontal scroll viewport/content wrapper from `LayerTimelineGrid` into a dedicated widget file.

This is a refactor/stabilization phase after PR183 through PR186.

No visual behavior or scroll behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="0n0py9"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and stabilized timeline scrollbar responsibilities:

* PR183: `TimelineVerticalScrollbarSlot` / `TimelineVerticalScrollbarRail`
* PR184: vertical scrollbar rail tests
* PR185: `TimelineHorizontalScrollbarRail`
* PR186: horizontal scrollbar rail tests

`LayerTimelineGrid` still owns too much frame-grid scroll viewport composition.

This phase extracts the frame grid horizontal scroll viewport/content wrapper into a dedicated widget while preserving existing scroll behavior.

## New file

Create:

```txt id="ojfnkp"
lib/src/ui/timeline/timeline_frame_scroll_viewport.dart
```

## Widget to create

Create:

```dart id="o6msqo"
class TimelineFrameScrollViewport extends StatelessWidget
```

Use the current implementation in `LayerTimelineGrid` as the source of truth.

## What to extract

Move only the existing frame grid horizontal scroll viewport/content wrapper from:

```txt id="7ac5q6"
lib/src/ui/timeline/layer_timeline_grid.dart
```

into the new widget.

Likely stable keys involved:

```txt id="3gxfl7"
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-grid-area
```

Preserve existing keys exactly.

Do not duplicate keys.

If a key currently appears once, it must still appear once after extraction.

## Scope

This phase is only for extracting the frame scroll viewport/content wrapper.

Do not extract:

* vertical scrollbar rail
* horizontal scrollbar rail
* frame cells
* frame cells row
* layer controls rows
* frame header row
* frame ruler
* playhead
* cut-end boundary widgets
* selected exposure outline
* virtualization adapter
* frame range policies
* horizontal offset policies

Those are separate concerns.

## Required behavior to preserve

Preserve exactly:

* `timeline-frame-scroll-viewport` key
* `timeline-frame-scroll-content` key
* `timeline-frame-grid-area` key, if currently part of this section
* current horizontal scroll controller usage
* current horizontal scroll synchronization
* current vertical scroll behavior
* current frame row rendering
* current layer row alignment
* current selected exposure outline behavior
* current cut-end boundary behavior
* current playhead behavior
* current body viewport clipping behavior
* current content width calculation behavior
* current behavior when visible frame range changes
* current behavior when viewport width changes
* current behavior after resize clamp from earlier phases

## Important semantic rule

The frame scroll viewport is a layout/scroll wrapper only.

It must not affect:

* `Cut.duration`
* authored/data extent
* visible frame range semantics
* playback frame range semantics
* selected exposure display range
* editability after `Cut.duration`
* frame selection
* layer selection

Do not introduce any timeline range logic into the new widget.

Do not use `authoredTimelineExtentFrameCount` in the new widget.

## Responsibility split

`LayerTimelineGrid` should remain responsible for:

* owning scroll controllers
* horizontal scroll synchronization
* vertical scroll synchronization
* viewport size calculation
* content width calculation
* virtualization plan creation
* frame range calculation
* row building
* selected exposure outline positioning
* cut-end boundary positioning
* playhead positioning
* passing already-built child widgets and existing controllers/values to the new viewport widget

`TimelineFrameScrollViewport` should be responsible only for:

* rendering the frame grid scroll viewport/content wrapper
* preserving stable keys
* receiving existing controller/size/child values
* placing the provided child inside the same viewport/content structure as before

## API guideline

Prefer a minimal API that preserves the current implementation.

Possible shape:

```dart id="gcigfi"
class TimelineFrameScrollViewport extends StatelessWidget {
  const TimelineFrameScrollViewport({
    super.key,
    required this.controller,
    required this.contentWidth,
    required this.child,
  });

  final ScrollController controller;
  final double contentWidth;
  final Widget child;
}
```

Do not force this exact API if the existing code needs different values.

Use the minimal parameters required by the current implementation.

Do not create scroll controllers inside the new widget if they are currently owned by `LayerTimelineGrid`.

Do not move horizontal scroll synchronization logic into the new widget.

Do not move `TimelineHorizontalOffsetPolicy` responsibilities into the new widget.

## Key rule

Avoid this mistake:

```dart id="m6s4qe"
class TimelineFrameScrollViewport extends StatelessWidget {
  const TimelineFrameScrollViewport({
    super.key = const ValueKey('timeline-frame-scroll-viewport'),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('timeline-frame-scroll-viewport'),
    );
  }
}
```

That duplicates the same key.

The stable key must exist exactly once.

## Update LayerTimelineGrid

Update:

```txt id="8a1s9n"
lib/src/ui/timeline/layer_timeline_grid.dart
```

so it imports:

```dart id="g3ehfm"
import 'timeline_frame_scroll_viewport.dart';
```

Then replace the old inline frame scroll viewport/content wrapper code with:

```dart id="6sp5tn"
TimelineFrameScrollViewport(...)
```

Pass existing values through unchanged.

After extraction, remove only the old inline viewport/content wrapper code from `layer_timeline_grid.dart`.

## Do not change

Do not change runtime behavior.

Do not change:

* `TimelineVerticalScrollbarSlot`
* `TimelineVerticalScrollbarRail`
* `TimelineHorizontalScrollbarRail`
* `TimelineLayerControlsHeader`
* `TimelineLayerControlsRow`
* `TimelineFrameHeaderRow`
* `TimelineRulerCutEndBoundary`
* `TimelineBodyCutEndBoundary`
* `TimelineFrameRuler`
* `TimelineFrameCell`
* `TimelineFrameCellsRow`
* `TimelineSelectedExposureOutline`
* `TimelineFrameCoordinatePolicy`
* `TimelineHorizontalOffsetPolicy`
* `SelectedExposureDisplayRangePolicy`
* `Cut.duration`
* `playbackFrameCount`
* `TimelineController.authoredTimelineExtentFrameCount`

Do not change:

* horizontal scroll controller ownership
* horizontal scroll synchronization
* vertical scroll synchronization
* sticky header/ruler behavior
* bottom horizontal scrollbar behavior
* vertical scrollbar behavior
* frame ruler click/drag/scrub behavior
* layer row behavior
* frame cell behavior
* selected exposure outline behavior
* cut-end boundary behavior
* playhead behavior
* timeline range semantics

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="yx1alt"
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
```

Do not use `CustomPainter`.

## Tests

No new tests are required if this is a pure extraction.

Existing tests must continue to pass.

Do not remove or weaken existing tests:

* PR165 resize tests
* PR166/PR167 selected exposure display-range tests
* PR168 horizontal offset policy tests
* PR169 frame coordinate policy tests
* PR172 selected exposure outline widget tests
* PR178 frame header row tests
* PR181 cut-end boundary widget tests
* PR182 layer controls widget tests
* PR184 vertical scrollbar rail tests
* PR186 horizontal scrollbar rail tests
* ruler/body alignment tests
* horizontal/vertical scrollbar tests

If adding a focused smoke test is simple, add:

```txt id="cigjfl"
test/ui/timeline_frame_scroll_viewport_test.dart
```

Suggested optional checks:

* `timeline-frame-scroll-viewport` exists exactly once
* `timeline-frame-scroll-content` exists exactly once
* provided child renders
* provided content width is preserved if easy to inspect
* no duplicate key is introduced

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="53pxr8"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="z8p8pz"
1. Frame grid still scrolls horizontally.
2. Horizontal scrolling moves ruler/header/frame rows together.
3. Bottom horizontal scrollbar still controls frame grid horizontal scrolling.
4. Vertical scrolling still moves layer rows and frame rows together.
5. Sticky frame ruler/header does not vertically scroll.
6. Sticky + Layer header does not vertically scroll.
7. Layer controls rail and frame grid row alignment is unchanged.
8. Frame cells still receive click/selection normally.
9. Selected exposure outline still aligns with frame cells after horizontal scrolling.
10. Playhead still aligns with the current frame column.
11. Cut-end boundaries still align after horizontal and vertical scrolling.
12. Timeline viewport resize still clamps horizontal offset correctly.
```

## Report back

Report:

* changed files
* new frame scroll viewport widget file
* whether optional test file was added
* how `LayerTimelineGrid` now delegates frame scroll viewport rendering
* confirmation that `timeline-frame-scroll-viewport` key did not change
* confirmation that `timeline-frame-scroll-content` key did not change
* confirmation that no duplicate key was introduced
* confirmation that horizontal scroll controller ownership did not change
* confirmation that horizontal scroll behavior did not change
* confirmation that vertical scroll behavior did not change
* confirmation that sticky header/ruler behavior did not change
* confirmation that selected exposure outline behavior did not change
* confirmation that cut-end boundary behavior did not change
* confirmation that playhead behavior did not change
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
