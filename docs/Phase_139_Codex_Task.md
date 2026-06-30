# Phase 139 Codex Task

## Title

Extract timeline layer/frame body layout widget

## Goal

Extract the high-level body layout that places the layer controls rail, vertical scrollbar slot, and frame grid area from `LayerTimelineGrid` into a dedicated layout-only widget.

This is a refactor/stabilization phase after PR193.

No visual behavior, scroll behavior, selection behavior, or timeline range behavior should change.

## Required reference

Before editing timeline code, read:

```txt id="8ui1ad"
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted and tested the frame-grid internals:

```txt id="ol66u8"
PR187: TimelineFrameScrollViewport
PR188: tests for TimelineFrameScrollViewport
PR189: TimelineFrameRowsScrollBody
PR190: tests for TimelineFrameRowsScrollBody
PR191: TimelineFrameGridStack
PR192: tests for TimelineFrameGridStack
PR193: LayerTimelineGrid extracted composition smoke tests
```

`LayerTimelineGrid` is still responsible for too much composition.

The next safe extraction is the high-level body layout that arranges:

```txt id="3orzut"
1. left layer controls rail
2. vertical scrollbar slot / rail
3. right frame grid area
```

This phase should extract only that layout shell.

## New file

Create:

```txt id="5f59wq"
lib/src/ui/timeline/timeline_layer_frame_body_layout.dart
```

## Widget to create

Create:

```dart id="kkedib"
class TimelineLayerFrameBodyLayout extends StatelessWidget
```

Use the current implementation in `LayerTimelineGrid` as the source of truth.

## What to extract

Move only the high-level layout that places these already-created child widgets:

```txt id="5o29gz"
- timeline-layer-controls-rail
- timeline-vertical-scrollbar-slot
- timeline-frame-grid-area
```

The extracted widget should not create timeline semantics.

It should only arrange child widgets in the same order and structure as before.

## Recommended responsibility split

`LayerTimelineGrid` should remain responsible for creating the actual child widgets:

```txt id="3bj9up"
- layer controls rail widget
- vertical scrollbar slot/rail widget
- frame grid area widget
```

`TimelineLayerFrameBodyLayout` should only arrange those children.

Prefer an API like:

```dart id="q7goch"
class TimelineLayerFrameBodyLayout extends StatelessWidget {
  const TimelineLayerFrameBodyLayout({
    super.key,
    required this.layerControlsRail,
    required this.verticalScrollbarSlot,
    required this.frameGridArea,
  });

  final Widget layerControlsRail;
  final Widget verticalScrollbarSlot;
  final Widget frameGridArea;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        layerControlsRail,
        verticalScrollbarSlot,
        frameGridArea,
      ],
    );
  }
}
```

However, do not force this exact code if the current `LayerTimelineGrid` layout has a slightly different wrapper.

Use the smallest API that preserves the current structure exactly.

## Important layout rule

Preserve the important invariant:

```txt id="03euk1"
timeline-layer-controls-rail must remain outside timeline-frame-scroll-content.
```

The left layer controls rail must not be moved into the horizontal frame scroll viewport.

The vertical scrollbar slot must remain between the layer controls rail and the frame grid area.

The bottom horizontal scrollbar must remain under the frame grid area only, not under the layer controls rail.

## Stable keys to preserve

Do not rename, remove, or duplicate these keys:

```txt id="uo2ef7"
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-horizontal-scrollbar-viewport
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-frame-rows-scroll-body
timeline-cut-end-boundary
timeline-horizontal-scrollbar
timeline-bottom-scrollbar-rail
timeline-vertical-scrollbar-slot
timeline-vertical-scrollbar
timeline-playhead
timeline-playhead-column
```

Do not introduce new public timeline keys unless necessary.

Do not duplicate stable keys at both the call site and inside the extracted widget.

## Required behavior to preserve

Preserve exactly:

```txt id="2x0lu7"
- layer controls rail position
- vertical scrollbar slot position
- frame grid area position
- layer rail not horizontally scrolling with frame grid
- vertical scrollbar slot between layer rail and frame grid
- bottom horizontal scrollbar under frame grid only
- frame rows rendering
- cut-end boundary rendering
- playhead rendering
- selected exposure outline behavior
- horizontal scroll behavior
- vertical scroll behavior
- sticky header/ruler behavior
- row alignment between layer controls rail and frame grid
- empty layer placeholder behavior
```

## Important semantic rule

The extracted layout widget is layout-only.

It must not affect:

```txt id="y22gmq"
- Cut.duration
- authored/data extent
- visible frame range semantics
- playback frame range semantics
- selected exposure display range
- editability after Cut.duration
- frame selection semantics
- layer selection semantics
```

Do not introduce timeline range logic into the new widget.

Do not use `authoredTimelineExtentFrameCount` in the new widget.

## Update LayerTimelineGrid

Update:

```txt id="x8fdvg"
lib/src/ui/timeline/layer_timeline_grid.dart
```

so it imports:

```dart id="x1fu5t"
import 'timeline_layer_frame_body_layout.dart';
```

Then replace the current inline high-level layout with:

```dart id="e3f1ml"
TimelineLayerFrameBodyLayout(
  layerControlsRail: ...,
  verticalScrollbarSlot: ...,
  frameGridArea: ...,
)
```

The exact children should come from the existing implementation.

Do not move calculations into the new widget.

Do not move scroll controller ownership into the new widget.

Do not move callbacks into the new widget unless they are already part of the child widgets being passed in.

## Scope

This phase is only for extracting the high-level layer/frame body layout shell.

Do not extract or change:

```txt id="iwv8r9"
- TimelineFrameGridStack
- TimelineFrameRowsScrollBody
- TimelineFrameScrollViewport
- TimelineBodyCutEndBoundary
- TimelinePlayhead
- TimelineVerticalScrollbarSlot
- TimelineVerticalScrollbarRail
- TimelineHorizontalScrollbarRail
- TimelineLayerControlsHeader
- TimelineLayerControlsRow
- TimelineFrameHeaderRow
- TimelineRulerCutEndBoundary
- TimelineFrameRuler
- TimelineFrameCell
- TimelineFrameCellsRow
- TimelineSelectedExposureOutline
- TimelineFrameCoordinatePolicy
- TimelineHorizontalOffsetPolicy
- SelectedExposureDisplayRangePolicy
```

Those are separate concerns.

## Do not change

Do not change runtime behavior.

Do not change:

```txt id="n5xvrw"
- Cut.duration
- playbackFrameCount
- TimelineController.authoredTimelineExtentFrameCount
- frame rows rendering
- frame row order
- frame cell rendering
- frame/layer selection callbacks
- empty layer placeholder behavior
- cut-end boundary behavior
- playhead behavior
- selected exposure outline behavior
- horizontal scroll controller ownership
- horizontal scroll synchronization
- vertical scroll synchronization
- sticky header/ruler behavior
- bottom horizontal scrollbar behavior
- vertical scrollbar behavior
- timeline range semantics
```

Do not reintroduce `authoredTimelineExtentFrameCount` into:

```txt id="hggqw1"
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

Do not use `CustomPainter`.

## Tests

No new tests are required if this is a pure extraction.

Existing tests must continue to pass.

Especially keep passing:

```txt id="6oyzcu"
- timeline frame scroll viewport tests
- timeline frame rows scroll body tests
- timeline frame grid stack tests
- LayerTimelineGrid extracted composition smoke tests
- vertical scrollbar rail tests
- horizontal scrollbar rail tests
- layer controls widget tests
- cut-end boundary widget tests
- selected exposure outline tests
```

If adding a focused smoke test is very simple, add:

```txt id="rlu4pv"
test/ui/timeline_layer_frame_body_layout_test.dart
```

Suggested optional checks:

```txt id="uivpaf"
- provided layer controls rail child renders
- provided vertical scrollbar slot child renders
- provided frame grid area child renders
- child order is preserved
```

Skip the optional test if setup becomes larger than the extraction itself.

## Required checks

Run:

```bash id="twdrnm"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="4w4vho"
1. Layer controls rail remains on the left.
2. Vertical scrollbar slot remains between layer controls rail and frame grid.
3. Bottom horizontal scrollbar remains under the frame grid only.
4. Frame grid rows still render in the same order.
5. Frame cells still render for every visible layer.
6. Frame cell click still selects the frame.
7. Frame cell click still selects the layer.
8. Selected exposure outline still aligns with frame cells.
9. Playhead still aligns with the current frame column.
10. Playhead still appears only when current frame is inside the visible frame range.
11. Cut-end boundary still aligns after horizontal and vertical scrolling.
12. Horizontal scrolling moves frame rows with ruler/header.
13. Vertical scrolling moves layer rows and frame rows together.
14. Layer controls rail and frame grid row alignment is unchanged.
15. Empty layer placeholder behavior is unchanged.
```

## Report back

Report:

```txt id="bc58cz"
- changed files
- new layout widget file
- whether optional test file was added
- how LayerTimelineGrid now delegates layer/frame body layout
- confirmation that layer controls rail remains outside frame scroll content
- confirmation that vertical scrollbar slot remains between layer rail and frame grid
- confirmation that bottom horizontal scrollbar remains under frame grid only
- confirmation that no duplicate stable key was introduced
- confirmation that frame grid extracted structure keys still exist
- confirmation that row/cell keys still appear
- confirmation that horizontal scroll behavior did not change
- confirmation that vertical scroll behavior did not change
- confirmation that sticky header/ruler behavior did not change
- confirmation that timeline range semantics did not change
- confirmation that authoredTimelineExtentFrameCount was not reintroduced
- confirmation that no CustomPainter was introduced
- check results
- git status summary
```
