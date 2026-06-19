# Phase 127 Codex Task

## Title

Add focused tests for timeline layer controls widgets

## Goal

Add focused widget tests for the extracted timeline layer controls widgets.

This is a stabilization phase after PR175 and PR176.

Do not change production behavior.

## Required reference

Before editing timeline code, read:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
```

Preserve all rules in that document.

## Why this phase exists

Recent phases extracted the left layer rail components:

* PR175: `TimelineLayerControlsRow`
* PR176: `TimelineLayerControlsHeader`

These widgets contain important stable keys and callbacks:

* add layer
* select layer
* toggle layer visibility
* change layer opacity
* active layer visual/semantic state

This phase adds focused tests so future refactors do not break those behaviors.

## Test file

Create:

```txt
test/ui/timeline_layer_controls_widgets_test.dart
```

## Widgets under test

Test:

```txt
lib/src/ui/timeline/timeline_layer_controls_header.dart
lib/src/ui/timeline/timeline_layer_controls_row.dart
```

## Test setup

Render each widget inside a minimal Material widget tree.

Use actual project imports and existing test style.

Suggested shape:

```dart
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: TimelineLayerControlsHeader(
        metrics: TimelineGridMetrics.defaults,
        onAddLayer: onAddLayer,
      ),
    ),
  ),
);
```

For `TimelineLayerControlsRow`, create a real `Layer` using the existing model constructor or existing test helpers.

Do not add production-only factory APIs just for tests.

## Required tests

### 1. Layer controls header add button key exists

Render `TimelineLayerControlsHeader`.

Verify this key exists exactly once:

```txt
timeline-add-layer-button
```

Use:

```dart
findsOneWidget
```

### 2. Tapping add layer button invokes callback

Tap:

```txt
timeline-add-layer-button
```

Verify the provided `onAddLayer` callback is called exactly once.

### 3. Layer controls row stable keys exist

Render `TimelineLayerControlsRow` with a test layer.

Verify these keys exist exactly once:

```txt
timeline-layer-row-<layerId>
timeline-layer-name-<layerId>
timeline-layer-kind-icon-<layerId>
timeline-layer-visibility-<layerId>
timeline-layer-opacity-<layerId>
```

Use the actual `LayerId` string generated in the test.

### 4. Tapping layer row selects layer

Tap:

```txt
timeline-layer-row-<layerId>
```

Verify `onSelectLayer` receives that layer id.

### 5. Tapping layer name selects layer

Tap:

```txt
timeline-layer-name-<layerId>
```

Verify `onSelectLayer` receives that layer id.

### 6. Tapping visibility button toggles layer visibility

Tap:

```txt
timeline-layer-visibility-<layerId>
```

Verify `onToggleLayerVisibility` receives that layer id.

### 7. Changing opacity invokes opacity callback

Find the slider by key:

```txt
timeline-layer-opacity-<layerId>
```

Verify `onLayerOpacityChanged` is invoked with the layer id and a new opacity value.

If direct pointer dragging is fragile, it is acceptable to read the `Slider` widget and invoke its `onChanged` callback directly in the test.

Do not change production code for this.

### 8. Active row exposes selected-layer semantic key

Render `TimelineLayerControlsRow` with:

```txt
active: true
```

Verify this key exists exactly once:

```txt
timeline-selected-layer
```

Render it with:

```txt
active: false
```

Verify the key does not exist.

This protects selected layer semantic behavior.

## Optional tests

Add these only if simple and not fragile:

* animation layer kind icon semantic label is `Animation layer`
* storyboard layer kind icon semantic label is `Storyboard layer`
* visible layer tooltip is `Hide layer`
* hidden layer tooltip is `Show layer`

Skip optional tests if setup becomes larger than the stabilization itself.

## Do not change

Do not change production behavior.

Do not change:

* `TimelineLayerControlsHeader`
* `TimelineLayerControlsRow`
* `TimelineFrameHeaderRow`
* `TimelineRulerCutEndBoundary`
* `TimelineBodyCutEndBoundary`
* `TimelineFrameRuler`
* `LayerTimelineGrid`
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

* layer controls keys
* add-layer behavior
* layer selection behavior
* visibility toggle behavior
* opacity slider behavior
* active row visual behavior
* active row semantic key behavior
* timeline range semantics
* frame ruler click/drag/scrub behavior
* frame cell behavior
* selected exposure outline behavior

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
```

Do not use `CustomPainter`.

## Acceptable production changes

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

Example acceptable change:

```txt
Adding a missing super.key to a public widget constructor.
```

Do not redesign any UI.

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
1. + Layer button still adds a layer.
2. Clicking a layer row still selects that layer.
3. Clicking the layer name still selects that layer.
4. Visibility button still toggles layer visibility.
5. Opacity slider still changes layer opacity.
6. Active layer row still has the same selected visual style.
7. Timeline frame grid row alignment is unchanged.
```

## Report back

Report:

* changed files
* new test file
* whether production code changed
* test cases added
* confirmation that `timeline-add-layer-button` is tested
* confirmation that add-layer callback is tested
* confirmation that layer row stable keys are tested
* confirmation that layer selection callback is tested
* confirmation that visibility callback is tested
* confirmation that opacity callback is tested
* confirmation that active selected-layer semantic key is tested
* confirmation that timeline range semantics did not change
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
