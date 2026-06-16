# Phase 101 Codex Task - Timeline Playhead Column Highlight Polish

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project type:
Flutter / Dart

Phase:
Phase 101

Goal:
Polish the TimelinePanel playhead visual so the current frame is clearly visible as a TVPaint-style current-frame column highlight.

Current state:
Phase 100 added a visual-only TimelinePlayhead foundation.
The playhead currently appears only when currentFrameIndex is inside the built horizontal frame range.
The playhead uses the existing horizontal virtualization geometry.
The playhead does not implement dragging, playback, zoom, or vertical layer virtualization.
The app was manually checked after Phase 100, and the playhead exists, but it is too hard to see when there is only one layer or when it overlaps the selected frame border.

Problem:
The current playhead is a thin vertical line.
When the current frame is selected, the playhead overlaps the selected header/cell border and becomes difficult to distinguish.
With one layer, the playhead can appear almost invisible.
The playhead should be visually clearer and should communicate the current frame column more directly.

Main goal:
Change the playhead visual from a thin line into a red semi-transparent current-frame column highlight.

The playhead highlight should:

* cover the full current frame column width
* span the frame ruler/header area and the visible frame cell rows
* remain clearly visible even with only one layer
* use a red semi-transparent fill
* optionally use a stronger red border if needed
* remain UI-only
* preserve existing timeline behavior

Visual direction:
Use the attached/reference direction from TVPaint-style timeline behavior:
the current frame should be recognizable as a vertical highlighted column across the ruler and frame rows.

Preferred appearance:

* a semi-transparent red rectangle over the current frame column
* width equals one frame cell width
* x position aligns with currentFrameIndex
* height spans ruler row plus visible layer rows
* overlay should not block user input

A simple implementation is enough.
Do not over-design it.

Required implementation direction:

1. Update the existing playhead widget.

Likely file:
lib/src/ui/timeline/timeline_playhead.dart

The existing TimelinePlayhead widget may be updated.
Do not create a complex new system.

2. Current frame column geometry:

The highlight x-position should use the same existing frame geometry.

Expected left position:
leadingFrameSpacerWidth + ((currentFrameIndex - frameStartIndex) * metrics.frameCellWidth)

Expected width:
metrics.frameCellWidth

Expected height:
metrics.layerRowHeight * (1 + visible layer row count)

The first row is the frame ruler/header row.
The rest are visible frame cell rows.

If there are no layers, preserve the current empty-row behavior and keep the highlight height reasonable.

3. Visibility rule:

If currentFrameIndex is inside the built frame range:
show the playhead highlight.

If currentFrameIndex is outside the built frame range:
do not show the playhead highlight.

Important:
Do not force build offscreen frames.
Do not auto-scroll to the playhead.
Do not expand the virtualized frame range only for the playhead.
Do not calculate a separate visible range.

4. Interaction rule:

The playhead highlight must not block interaction.

Use IgnorePointer or an equivalent approach.

Frame header taps must still work.
Frame cell taps must still work.
Horizontal scrolling must still work.

5. Keys:

Keep:

* timeline-playhead

The old key:

* timeline-playhead-line

may be replaced if the visual is no longer a line.

Preferred new key:

* timeline-playhead-column

If a separate fill/border is used, acceptable keys:

* timeline-playhead-fill
* timeline-playhead-border

Update tests accordingly.

Do not remove or rename unrelated stable timeline keys.

Preserve:

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

6. Color:

Use a red visual.

Preferred:

* Colors.red with opacity
  or
* Theme-safe red derived from ColorScheme.error with opacity

The highlight should be visibly red.
It should still allow frame text/cells to be recognizable underneath.

Do not introduce global theme changes.

7. Existing behavior must remain unchanged:

Do not change:

* Project / Track / Cut / Layer / Frame / Stroke models
* renderer/cache
* persistence/save/load
* StoryboardPanel
* command system
* undo/redo
* timeline data model
* horizontal virtualization
* vertical scrollbar slot
* bottom horizontal scrollbar
* layer controls rail
* frame selection logic
* layer selection logic

Out of scope:

Do not implement playhead dragging.
Do not implement playback.
Do not implement zoom.
Do not implement ruler ticks.
Do not implement frame number redesign.
Do not implement current frame label.
Do not implement keyboard shortcuts.
Do not implement auto-scroll to playhead.
Do not implement snapping.
Do not implement vertical layer virtualization.
Do not implement StoryboardPanel playhead.
Do not implement camera/sound sections.
Do not change domain models.
Do not change renderer/cache/persistence.
Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.
Do not implement Phase 102 or later.

Testing requirements:

Update existing tests.

Likely file:
test/ui/layer_timeline_grid_test.dart

Optional:
test/ui/timeline/timeline_playhead_test.dart

Required tests:

1. Playhead column appears for visible current frame

Given:
currentFrameIndex is visible.

Expected:
timeline-playhead exists.
timeline-playhead-column or equivalent new column/fill key exists.

2. Playhead column does not appear for non-visible current frame

Given:
large frameCount.
currentFrameIndex is outside the initially built frame range.

Expected:
timeline-playhead does not exist.
timeline-playhead-column or equivalent does not exist.

3. Playhead column appears after horizontal scroll brings current frame into built range

Given:
large frameCount.
currentFrameIndex is far to the right.
horizontal scroll moves to that range.

Expected:
current frame header exists.
timeline-playhead exists.
timeline-playhead-column or equivalent exists.

4. Playhead column does not block frame header tap

Given:
currentFrameIndex is visible.

Action:
tap a visible frame header.

Expected:
onSelectFrame receives the tapped zero-based frame index.

5. Playhead column does not block frame cell tap

Given:
currentFrameIndex is visible.

Action:
tap a visible frame cell.

Expected:
existing layer/frame selection callbacks still fire.

6. Existing timeline tests still pass

Expected:
bottom horizontal scrollbar tests pass.
vertical scrollbar slot tests pass.
horizontal virtualization tests pass.
small frame count minimum visible cells tests pass.
frame header plain text test passes.
cell selection tests pass.

Documentation:

Update docs only if useful and small.

Preferred update:
docs/LongTerm_Performance_Architecture.md

Add a short Phase 101 note:

* Phase 101 polished the visual playhead into a red current-frame column highlight.
* It remains UI-only.
* It uses existing horizontal frame geometry.
* It does not add dragging, playback, zoom, or vertical layer virtualization.

Required checks:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* updated widget file name
* updated widget class name
* exact playhead keys used
* confirmation that the playhead is now a red current-frame column highlight
* confirmation that the highlight spans ruler/header row and visible frame rows
* confirmation that the highlight remains visible with one layer
* confirmation that the highlight does not block frame header taps
* confirmation that the highlight does not block frame cell taps
* confirmation that playhead visibility still depends on the built frame range
* confirmation that no offscreen frames are force-built
* confirmation that no auto-scroll was added
* confirmation that no dragging was added
* confirmation that no playback was added
* confirmation that no zoom was added
* confirmation that no vertical layer virtualization was added
* confirmation that no model changes were made
* confirmation that no renderer/cache/persistence changes were made
* confirmation that StoryboardPanel was not changed
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 101 is complete when:

* The current frame is shown as a red semi-transparent column highlight.
* The highlight covers one full frame cell width.
* The highlight spans the ruler/header row and visible frame cell rows.
* The highlight is clearly visible when only one layer exists.
* The highlight aligns with currentFrameIndex.
* The highlight is hidden when currentFrameIndex is outside the built frame range.
* The highlight does not force offscreen frame building.
* The highlight does not auto-scroll.
* Frame header taps still work.
* Frame cell taps still work.
* Horizontal scrolling still works.
* Horizontal virtualization still works.
* Bottom horizontal scrollbar still works.
* Vertical scrollbar slot still works.
* Existing timeline stable keys are preserved.
* No playhead dragging is implemented.
* No playback is implemented.
* No zoom is implemented.
* No vertical layer virtualization is implemented.
* No domain model changes are made.
* No renderer/cache/persistence changes are made.
* No StoryboardPanel changes are made.
* dart format lib test completes.
* flutter analyze passes.
* flutter test passes.
