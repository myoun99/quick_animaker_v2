# Phase 100 Codex Task - Timeline Playhead Visual Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project type:
Flutter / Dart

Phase:
Phase 100

Goal:
Add a visual-only timeline playhead foundation to TimelinePanel.

Current state:
Phase 99 extracted the frame header row into TimelineFrameRuler.
TimelineFrameRuler preserves the existing frame header keys and receives the visible frame range from LayerTimelineGrid.
Horizontal frame virtualization already exists.
Vertical layer virtualization is still intentionally not implemented.
The bottom horizontal scrollbar works.
The vertical scrollbar slot works.
The app was manually confirmed working after PR 141.

Main goal:
Show a vertical playhead indicator for the currentFrameIndex in the timeline frame grid area.

This phase is visual foundation only.

The playhead should:
- align with the currentFrameIndex
- visually connect the frame ruler and frame cell rows
- use the existing horizontal virtualization geometry
- not change domain models
- not change renderer/cache/persistence
- not add playback
- not add dragging
- not add zoom
- not implement vertical layer virtualization

Required implementation direction:

1. Add a dedicated UI-only playhead widget.

Suggested file:
lib/src/ui/timeline/timeline_playhead.dart

Suggested widget:
TimelinePlayhead

Suggested inputs:
- int currentFrameIndex
- int frameStartIndex
- int frameEndIndexExclusive
- double leadingFrameSpacerWidth
- TimelineGridMetrics metrics
- int layerCount

The exact constructor may differ if needed, but the widget must remain UI-only.

TimelinePlayhead must not depend on:
- Project
- Track
- Cut
- Layer
- Frame
- Stroke
- ProjectRepository
- HistoryManager
- commands
- renderer
- cache
- persistence
- Provider / Riverpod / Bloc / ChangeNotifier

2. Render the playhead inside the existing horizontal frame scroll content.

Preferred structure:
Inside the existing timeline-frame-scroll-content area, wrap the ruler + frame rows in a Stack.

The Stack should contain:
- the existing Column:
    - TimelineFrameRuler
    - frame cell rows
- TimelinePlayhead above that Column

This allows the playhead to visually span from the ruler through the layer rows.

3. Playhead visibility rule:

If currentFrameIndex is inside the currently built frame range:
- show the playhead

If currentFrameIndex is outside the currently built frame range:
- do not show the playhead in this phase

Important:
Do not force building offscreen frames.
Do not scroll automatically.
Do not expand the virtualized range just to show the playhead.
Do not introduce a second visible range calculation.

4. Playhead position rule:

The playhead x position should be calculated from the same frame geometry used by the frame ruler.

Expected calculation:
leadingFrameSpacerWidth + ((currentFrameIndex - frameStartIndex) * metrics.frameCellWidth)

The playhead should align to the start edge of the current frame cell for now.

Do not implement center-of-cell behavior unless existing UI clearly expects it.
Do not add draggable handles yet.

5. Stable keys:

Add stable keys:

- timeline-playhead
- timeline-playhead-line

If a small marker/header is added later, do not add it in this phase.

6. Visual style:

Keep it simple.

The playhead should be visible but not overly complex.

Acceptable:
- a thin vertical line
- uses Theme colorScheme.primary or similar existing theme color
- spans ruler height + all visible layer row heights

Do not add:
- playhead triangle marker
- draggable handle
- current frame label
- hover behavior
- context menu

7. Existing behavior must remain unchanged:

Preserve:
- timeline-frame-ruler
- timeline-frame-header-row
- timeline-frame-header-<frameIndex>
- timeline-frame-header-leading-spacer
- timeline-frame-header-trailing-spacer
- timeline-frame-scroll-viewport
- timeline-frame-scroll-content
- timeline-horizontal-scrollbar
- timeline-vertical-scrollbar
- timeline-vertical-scrollbar-slot
- timeline-layer-controls-rail
- timeline-frame-grid-area

Do not break:
- horizontal scroll
- bottom horizontal scrollbar
- vertical scrollbar slot
- layer controls rail
- frame cell selection
- frame header selection
- horizontal virtualization
- small frame count minimum visible frame behavior

Testing requirements:

Update or add widget tests.

Likely files:
- test/ui/layer_timeline_grid_test.dart
- optional: test/ui/timeline/timeline_playhead_test.dart

Required tests:

1. Playhead appears for visible current frame

Given:
- currentFrameIndex is visible

Expected:
- timeline-playhead exists
- timeline-playhead-line exists

2. Playhead does not appear for non-visible current frame

Given:
- large frameCount
- currentFrameIndex far outside initial visible range

Expected:
- timeline-playhead does not exist initially

3. Playhead follows horizontal scroll range

Given:
- large frameCount
- currentFrameIndex is far to the right
- horizontal scroll moves to that range

Expected:
- timeline-playhead appears when currentFrameIndex becomes part of the built frame range

4. Playhead does not affect frame header tap

Given:
- tap timeline-frame-header-3

Expected:
- onSelectFrame receives 3

5. Playhead does not affect frame cell selection

Given:
- tap a frame cell

Expected:
- existing layer/frame selection behavior still works

6. Existing scrollbar tests must keep passing

Expected:
- bottom horizontal scrollbar alignment still passes
- vertical scrollbar slot tests still pass
- horizontal scrolling virtualization tests still pass

Documentation:

Update:
docs/LongTerm_Performance_Architecture.md

Add a short Phase 100 note:
- Timeline playhead visual foundation was added.
- It uses the existing visible frame range and spacer geometry.
- It does not implement dragging, playback, zoom, or vertical layer virtualization.
- It does not change domain models, renderer/cache, persistence, or StoryboardPanel.

Out of scope:

Do not implement vertical layer virtualization.
Do not implement playhead dragging.
Do not implement playback.
Do not implement onion skin.
Do not implement zoom.
Do not implement ruler ticks.
Do not implement frame numbers redesign.
Do not implement current frame label.
Do not implement keyboard shortcuts.
Do not implement auto-scroll to playhead.
Do not implement timeline snapping.
Do not implement StoryboardPanel playhead.
Do not implement camera/sound sections.
Do not change Project / Track / Cut / Layer / Frame / Stroke models.
Do not change renderer/cache.
Do not change persistence/save/load.
Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.
Do not implement Phase 101 or later.

Required checks:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- new widget file name
- new widget class name
- confirmation that playhead is visual-only
- confirmation that playhead appears only when currentFrameIndex is inside the built frame range
- confirmation that no playhead dragging was added
- confirmation that no playback was added
- confirmation that no zoom was added
- confirmation that vertical layer virtualization was not implemented
- confirmation that no model changes were made
- confirmation that no renderer/cache/persistence changes were made
- confirmation that StoryboardPanel was not changed
- confirmation that existing timeline keys were preserved
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 100 is complete when:

- TimelinePlayhead or equivalent dedicated playhead widget exists.
- timeline-playhead key exists when the playhead is visible.
- timeline-playhead-line key exists when the playhead is visible.
- Playhead aligns with currentFrameIndex using existing frame geometry.
- Playhead is rendered inside the horizontal frame scroll content.
- Playhead visually spans ruler + visible layer rows.
- Playhead is hidden when currentFrameIndex is outside the built frame range.
- No additional offscreen frames are built just for the playhead.
- Horizontal virtualization still works.
- Bottom horizontal scrollbar still works.
- Vertical scrollbar slot still works.
- Frame header tap still works.
- Frame cell selection still works.
- No dragging is implemented.
- No playback is implemented.
- No zoom is implemented.
- No vertical layer virtualization is implemented.
- No domain model changes are made.
- No renderer/cache/persistence changes are made.
- No StoryboardPanel changes are made.
- dart format lib test completes.
- flutter analyze passes.
- flutter test passes.