# Phase 115 Codex Task

## Title

Document timeline range semantics and policy invariants

## Goal

Create a long-term design reference for timeline range semantics so future changes do not confuse:

* playback range
* visible/display range
* virtualized frame window
* authored/data extent
* selected exposure visual range
* effective horizontal scroll offset

This is a documentation and guardrail phase after PR165, PR166, PR167, PR168, and PR169.

No runtime behavior should change.

## Why this phase exists

Several recent bugs were caused by mixing different timeline concepts:

* `Cut.duration` was confused with editability or visibility.
* authored/data extent was used to bound a visual selected exposure outline.
* visible display range was confused with data range.
* raw horizontal scroll offset was confused with effective clamped offset after resizing.
* frame coordinate conversion was scattered in `LayerTimelineGrid`.

The recent policy extractions fixed the behavior. This phase documents the rules so future work does not undo them.

## Files to create

Create:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
```

## Files to update

Update only documentation comments in these files:

```txt
lib/src/ui/timeline/selected_exposure_display_range_policy.dart
lib/src/ui/timeline/timeline_horizontal_offset_policy.dart
lib/src/ui/timeline/timeline_frame_coordinate_policy.dart
```

Do not change runtime logic.

## Required documentation content

In `docs/LongTerm_Timeline_Range_Semantics.md`, document the following concepts.

### 1. Playback range

Definition:

* `Cut.duration`
* Used for playback/export duration.
* Used to determine where the cut playback ends.
* May be visualized by cut-end boundary.

Must not mean:

* frame data limit
* selection limit
* editing limit
* selected exposure outline limit
* authored data extent

Important rule:

Frames outside `Cut.duration` may still be visible, selectable, and editable if the UI display range includes them.

### 2. Visible/display range

Definition:

* The range of frames the timeline chooses to display.
* Usually derived from playback duration plus safety tail.
* Current default safety tail is handled by existing timeline frame range policy.

Must not mean:

* authored/data extent
* playback/export duration
* permanent project length

Important rule:

Visible/display range exists for UI display and interaction only.

### 3. Virtualized frame window

Definition:

* The subset of the visible/display range currently rendered by the timeline body.
* Usually represented by `frameStartIndex` and `frameEndIndexExclusive`.
* Controlled by horizontal offset and viewport width.

Must not mean:

* selected exposure data extent
* Cut duration
* authored extent

Important rule:

Virtualization is a rendering optimization. It must not change timeline data semantics.

### 4. Authored/data extent

Definition:

* The extent of actual authored timeline data.
* Tracked separately by `TimelineController.authoredTimelineExtentFrameCount`.

Must not mean:

* selected exposure outline visual bound
* playback duration
* visible range

Important rule:

`authoredTimelineExtentFrameCount` must not be reintroduced into `TimelinePanel` or `LayerTimelineGrid` for selected exposure outline rendering.

### 5. Selected exposure visual range

Definition:

* A visual highlight for the selected exposure block.
* It is a display-range visual effect.
* It is resolved by `selected_exposure_display_range_policy.dart`.

Important rules:

* It may continue beyond `Cut.duration`.
* It may continue beyond `playbackFrameCount`.
* It must not be bounded by `authoredTimelineExtentFrameCount`.
* It is clamped only for rendering to the current virtualized frame window.
* It must not create, delete, or resize timeline data.
* It must not imply authored data exists through the whole outlined visual span.

### 6. Effective horizontal scroll offset

Definition:

* The clamped horizontal offset used for actual rendering and hit testing.
* It is resolved by `timeline_horizontal_offset_policy.dart`.

Important rules:

* Ruler, body, selected exposure outline, and hit testing must use the same effective offset.
* Raw scroll controller offset may be temporarily out of bounds after resize.
* The effective offset must be clamped before layout/hit-test math uses it.
* ScrollController correction is a widget side effect and should stay outside the pure policy.

### 7. Frame coordinate conversion

Definition:

* Frame index ↔ x-position conversion.
* It is handled by `timeline_frame_coordinate_policy.dart`.

Important rules:

* Ruler hit testing must use the effective horizontal offset.
* Selected exposure outline position and width should use shared coordinate helpers.
* Coordinate helpers must remain pure and not know about `Cut.duration`, authored extent, or playback semantics.

## Required policy file comments

Add top-level Dart doc comments to the following files.

### selected_exposure_display_range_policy.dart

Add a comment explaining:

* This policy resolves selected exposure outline visual range.
* It is display-range based.
* It intentionally does not accept `playbackFrameCount`, `Cut.duration`, or `authoredTimelineExtentFrameCount`.
* It clamps only visible intersection for rendering.
* It must not be used as timeline data extent.

### timeline_horizontal_offset_policy.dart

Add a comment explaining:

* This policy resolves pure horizontal offset clamp math.
* It is used to preserve ruler/body/outline/hit-test alignment after viewport resize.
* It has no `ScrollController` side effects.
* Widget-side correction scheduling must remain in `LayerTimelineGrid`.

### timeline_frame_coordinate_policy.dart

Add a comment explaining:

* This policy resolves pure frame index / x-position conversion.
* It must use the effective horizontal offset when converting local x to frame index.
* It must not know about playback duration, authored extent, or Cut duration.
* It is shared by ruler hit testing and timeline overlay positioning.

## Do not change

Do not change runtime behavior.

Do not change:

* `Project`
* `Track`
* `Cut`
* `Layer`
* `Frame`
* `Stroke`
* `Cut.duration`
* `playbackFrameCount`
* `TimelineController.authoredTimelineExtentFrameCount`
* `TimelineFrameRange`
* `TimelineHorizontalOffsetPolicy` behavior
* `SelectedExposureDisplayRangePolicy` behavior
* `TimelineFrameCoordinatePolicy` behavior
* timeline virtualization behavior
* selected exposure outline rendering
* timeline visual style
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel` or `LayerTimelineGrid`.

Do not use `CustomPainter`.

## Tests

No new tests are required unless comments or docs reveal an existing issue.

Existing tests must continue to pass.

Do not add source-file string inspection tests.

Do not import `dart:io` in widget tests.

## Required checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

## Report back

Report:

* changed files
* created documentation file
* updated policy file comments
* confirmation that no runtime logic changed
* confirmation that `authoredTimelineExtentFrameCount` was not reintroduced into `TimelinePanel` or `LayerTimelineGrid`
* confirmation that selected exposure outline remains display-range visual semantics
* confirmation that horizontal offset and frame coordinate policies remain pure
* confirmation that no `CustomPainter` was introduced
* analyze result
* full test result
* git status summary
