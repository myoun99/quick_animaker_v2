# Phase 103 Codex Task - Timeline Ruler Scrub Interaction Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project type:
Flutter / Dart

Phase:
Phase 103

Goal:
Add a basic ruler scrub interaction to TimelinePanel so the user can click or drag on the frame ruler to change the current frame.

Current state:
Phase 99 extracted TimelineFrameRuler.
Phase 100 added a visual-only TimelinePlayhead.
Phase 101 polished the playhead into a red current-frame column highlight.
Phase 102 made the frame ruler/header vertically sticky and made body rows scroll vertically.
PR 145 fixed the sticky ruler overflow regression by laying out the ruler at full frame content width while clipping it to the visible viewport.
The app and tests were manually confirmed normal after PR 145.

Problem:
The timeline now visually shows the current frame clearly, but the ruler interaction is still basic.
A normal animation timeline should allow the user to scrub the current frame by clicking or dragging on the ruler area.

Main goal:
Allow the user to change currentFrameIndex by pointer interaction on the frame ruler area.

Required behavior:

1. Click on frame ruler changes current frame

When the user clicks/taps inside the frame ruler/header area:

* calculate the frame index under the pointer
* call the existing onSelectFrame callback with that zero-based frame index
* update current frame through existing parent state flow

2. Drag on frame ruler scrubs current frame

When the user drags horizontally across the frame ruler/header area:

* calculate the frame index under the pointer as the pointer moves
* call onSelectFrame with the zero-based frame index
* avoid repeatedly calling onSelectFrame with the same index if the pointer remains inside the same frame cell

3. Use existing horizontal geometry

The frame index calculation must use the existing timeline frame geometry.

Important values:

* metrics.frameCellWidth
* current horizontal scroll offset
* visible viewport local x position
* frameCount

Expected rough calculation:
frameIndex = floor((localX + horizontalScrollOffset) / metrics.frameCellWidth)

Then clamp:
0 <= frameIndex < frameCount

If the implementation uses the existing virtualization plan/spacer geometry instead, that is also acceptable, but do not introduce a separate incompatible ruler geometry.

4. Keep ruler vertically sticky

Do not undo Phase 102 / PR 145 layout work.

The frame ruler must remain:

* vertically sticky
* horizontally synchronized with frame cell rows
* clipped to the visible viewport
* not vertically scrollable

5. Keep playhead behavior

The existing red playhead column should continue to follow currentFrameIndex.

Do not redesign playhead visuals in this phase.

Preserve:

* timeline-playhead
* timeline-playhead-column

6. Preserve existing frame header tap behavior

Existing individual frame header widgets may still call onSelectFrame.

Do not break:

* timeline-frame-header-<frameIndex> tap behavior
* current frame red border styling
* frame cell selection
* layer selection
* horizontal scrolling
* vertical body scrolling

7. Avoid interaction conflicts

The ruler scrub gesture should not block unrelated timeline interactions.

Expected:

* pointer interaction on the frame ruler scrubs/selects frames
* pointer interaction on frame cells still selects cells
* pointer interaction on layer rows still selects layers
* bottom horizontal scrollbar still works
* vertical scrollbar still works

It is acceptable if dragging on the ruler means scrub rather than horizontal scroll.
Do not add a second horizontal ScrollController.

8. Stable keys

Preserve existing stable keys:

* timeline-sticky-header-row
* timeline-frame-ruler
* timeline-frame-header-row
* timeline-frame-header-<frameIndex>
* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-horizontal-scrollbar
* timeline-vertical-scrollbar
* timeline-vertical-scrollbar-slot
* timeline-layer-controls-rail
* timeline-frame-grid-area
* timeline-playhead
* timeline-playhead-column

If adding a gesture wrapper, use a semantic key if useful.

Suggested key:

* timeline-frame-ruler-scrub-area

The exact key name may differ, but prefer stable semantic keys.

Implementation direction:

Likely files:

* lib/src/ui/timeline/layer_timeline_grid.dart
* lib/src/ui/timeline/timeline_frame_ruler.dart
* test/ui/layer_timeline_grid_test.dart
* optional: docs/LongTerm_Performance_Architecture.md

Suggested approach:

* Add a GestureDetector or Listener around the sticky frame ruler viewport area.
* Convert local pointer x position to zero-based frame index.
* Use the existing horizontal scroll offset.
* Clamp to valid frame range.
* Call widget.onSelectFrame(frameIndex).
* Track the last scrubbed frame index inside the widget state if needed, to avoid duplicate callbacks during drag.

Do not:

* introduce a new state management package
* introduce a new current-frame controller
* change domain models
* change renderer/cache/persistence
* change StoryboardPanel
* add playback
* add zoom
* add auto-scroll
* add snapping
* add vertical layer virtualization

Testing requirements:

Update or add widget tests.

Likely file:
test/ui/layer_timeline_grid_test.dart

Required tests:

1. Ruler click selects frame

Given:

* frame ruler is visible
* currentFrameIndex starts at 0

Action:

* tap/click a visible frame ruler position, for example around frame 3

Expected:

* onSelectFrame receives the correct zero-based frame index

2. Ruler horizontal drag scrubs frames

Given:

* frame ruler is visible

Action:

* drag horizontally across the ruler from one frame to another

Expected:

* onSelectFrame receives changed frame indices
* final callback corresponds to the frame under the drag end position

3. Ruler scrub respects horizontal scroll offset

Given:

* large frameCount
* horizontal scroll moved right

Action:

* tap/click the visible ruler area after scroll

Expected:

* onSelectFrame receives the frame index corresponding to the scrolled timeline position, not always a small unscrolled frame index

4. Ruler scrub clamps to valid range

Given:

* frameCount is finite

Action:

* tap/drag near the left or right edge

Expected:

* selected frame index is never less than 0
* selected frame index is never greater than or equal to frameCount

5. Existing frame header tap still works

Expected:

* tapping timeline-frame-header-3 still calls onSelectFrame(3)

6. Existing frame cell selection still works

Expected:

* tapping a frame cell still calls existing layer/frame selection callbacks

7. Sticky ruler regression still passes

Expected:

* sticky frame ruler does not cause RenderFlex overflow
* frame ruler remains vertically sticky
* * Layer header remains vertically sticky
* body rows scroll vertically

8. Existing timeline tests still pass

Expected:

* bottom horizontal scrollbar tests pass
* vertical scrollbar tests pass
* horizontal virtualization tests pass
* playhead tests pass
* selected red border tests pass

Documentation:

Update docs only if useful and small.

Preferred update:
docs/LongTerm_Performance_Architecture.md

Add a short Phase 103 note:

* Frame ruler click/drag scrub foundation was added.
* It uses existing horizontal scroll/frame geometry.
* It does not add playback, zoom, snapping, auto-scroll, or vertical layer virtualization.
* It does not change domain models, renderer/cache, persistence, or StoryboardPanel.

Out of scope:

Do not implement playback.
Do not implement play button behavior.
Do not implement timeline zoom.
Do not implement ruler tick redesign.
Do not implement current frame label.
Do not implement keyboard shortcuts.
Do not implement auto-scroll while scrubbing.
Do not implement snapping.
Do not implement multi-frame selection.
Do not implement range selection.
Do not implement onion skin.
Do not implement vertical layer virtualization.
Do not implement StoryboardPanel playhead/scrub.
Do not implement camera/sound sections.
Do not change Project / Track / Cut / Layer / Frame / Stroke models.
Do not change renderer/cache.
Do not change persistence/save/load.
Do not change command/undo/redo logic.
Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.
Do not implement Phase 104 or later.

Required checks:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* summary of ruler scrub implementation
* exact gesture wrapper/key used if added
* frame index calculation method
* confirmation that click on ruler selects frame
* confirmation that drag on ruler scrubs frame
* confirmation that horizontal scroll offset is respected
* confirmation that frame index is clamped to valid range
* confirmation that frame ruler remains vertically sticky
* confirmation that frame ruler remains horizontally synchronized with frame rows
* confirmation that existing frame header taps still work
* confirmation that frame cell taps still work
* confirmation that playhead visual was not redesigned
* confirmation that no playback was added
* confirmation that no zoom was added
* confirmation that no auto-scroll was added
* confirmation that no vertical layer virtualization was added
* confirmation that no model changes were made
* confirmation that no renderer/cache/persistence changes were made
* confirmation that StoryboardPanel was not changed
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 103 is complete when:

* Clicking the frame ruler changes currentFrameIndex through onSelectFrame.
* Dragging horizontally on the frame ruler scrubs currentFrameIndex through onSelectFrame.
* Scrubbed frame index uses existing horizontal scroll/frame geometry.
* Scrubbed frame index respects horizontal scroll offset.
* Scrubbed frame index is clamped to valid frame range.
* Existing frame header tap behavior still works.
* Existing frame cell selection still works.
* Red playhead column follows currentFrameIndex as before.
* Frame ruler remains vertically sticky.
* * Layer header remains vertically sticky.
* Body rows still scroll vertically.
* Horizontal ruler/frame row synchronization still works.
* Bottom horizontal scrollbar still works.
* Vertical scrollbar still works.
* Horizontal virtualization still works.
* No RenderFlex overflow is introduced.
* No playback is implemented.
* No zoom is implemented.
* No auto-scroll is implemented.
* No vertical layer virtualization is implemented.
* No domain model changes are made.
* No renderer/cache/persistence changes are made.
* No StoryboardPanel changes are made.
* dart format lib test completes.
* flutter analyze passes.
* flutter test passes.
