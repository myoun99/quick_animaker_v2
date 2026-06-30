# Phase 102 Codex Task - Timeline Sticky Ruler and Playhead Selection Polish

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project type:
Flutter / Dart

Phase:
Phase 102

Goal:
Polish the TimelinePanel layout so the frame ruler/header remains vertically fixed while only the layer rows and frame cell rows scroll vertically. Also polish the playhead/current-frame visuals to use a cleaner red UI style.

Current state:
Phase 99 extracted TimelineFrameRuler.
Phase 100 added visual-only TimelinePlayhead.
Phase 101 changed the playhead into a red semi-transparent current-frame column highlight.
The playhead currently appears only when currentFrameIndex is inside the built horizontal frame range.
The playhead uses existing horizontal frame geometry.
The app was manually checked after Phase 101 direction, and the playhead visibility is improved, but the TimelinePanel vertical scroll structure still needs correction.

Problem:
The current vertical scroll behavior scrolls the frame ruler/header area together with the layer rows.
In normal timeline tools, the frame ruler/header should remain fixed vertically.
Only the timeline body rows should scroll vertically.

Also:
The red playhead column currently has a border/silhouette.
The desired playhead style is a simple semi-transparent red filled rectangle only.
The current selected frame border is still purple in some areas.
The selected/current frame border should use red styling to match the playhead.

Main goals:

1. Make the frame ruler/header sticky for vertical scrolling.
2. Make only the timeline body rows vertically scrollable.
3. Keep horizontal scrolling behavior synchronized between the frame ruler and frame cell rows.
4. Remove the playhead column border/silhouette.
5. Change current frame selected borders from purple to red styling.

Important:
This is a UI/layout polish phase.
This is not vertical layer virtualization.
This is not playback.
This is not zoom.
This is not playhead dragging.

Required layout behavior:

1. Sticky vertical frame ruler

The frame ruler/header row must not move when the user scrolls vertically.

This includes:

* frame number header row
* TimelineFrameRuler
* current frame ruler highlight/playhead portion if applicable

The frame ruler should still move horizontally with the frame grid.

Expected behavior:

* vertical scroll: frame ruler stays fixed
* horizontal scroll: frame ruler scrolls left/right with frame cells

2. Sticky left top header

The left top header area, especially the `+ Layer` header above the layer controls, should not move vertically when the user scrolls vertically.

Expected behavior:

* vertical scroll: `+ Layer` header stays fixed
* horizontal scroll: left layer controls/header area stays fixed

3. Body-only vertical scroll

Only the actual body rows should be vertically scrollable.

Vertically scrollable body:

* left layer rows
* right frame cell rows

Vertically fixed header:

* top-left `+ Layer` header
* frame ruler/header row

The left layer rows and right frame cell rows must stay vertically synchronized.

4. Vertical scrollbar placement

The vertical scrollbar should represent the body scroll area, not the sticky ruler/header.

Expected behavior:

* vertical scrollbar track/slot starts below the fixed frame ruler/header row
* vertical scrollbar controls only body row vertical scrolling
* the frame ruler/header does not move when using the vertical scrollbar

If exact visual placement needs adjustment, prefer correctness and stable layout over cosmetic perfection.

5. Horizontal scroll synchronization

The frame ruler and frame cell rows must remain horizontally synchronized.

Expected behavior:

* dragging the bottom horizontal scrollbar moves both frame ruler and frame cell rows together
* dragging/scrolling the frame grid horizontally moves both frame ruler and frame cell rows together
* left layer controls remain horizontally fixed

Do not create separate unsynchronized horizontal controllers.

Use the existing horizontal scroll controller if possible.

6. Keep current eager layer row implementation

Do not implement vertical layer virtualization in this phase.

This phase may split the vertical scroll viewport into sticky header and scrollable body areas, but it must not virtualize layer rows.

Do not introduce visible layer range calculation.
Do not lazy build layer rows.
Do not change domain models.

Playhead visual polish:

7. Remove playhead border/silhouette

Update the red playhead column highlight.

Desired style:

* semi-transparent red filled rectangle
* no border
* no outline
* no silhouette
* no separate line

Keep:

* `timeline-playhead`
* `timeline-playhead-column`

The playhead column should remain clearly visible with one layer.

The playhead should still:

* cover one full frame cell width
* span the ruler/header row and visible body rows if structurally possible
* align with currentFrameIndex
* use existing horizontal frame geometry
* appear only when currentFrameIndex is inside the built horizontal frame range
* not block taps

Use IgnorePointer or equivalent.

8. Current frame selected border should be red

Where the current frame header/cell selection currently uses purple border styling, change it to red styling.

Desired behavior:

* current frame header border should use red or red-accent color
* current frame cell border should use red or red-accent color
* avoid purple border for current frame selection
* do not globally change unrelated layer selection or app theme colors

This should apply to the visual indication of the currently selected/current frame in the timeline.

Do not change actual selection logic.

The goal is only visual consistency:
current frame = red playhead / red selected frame border.

Stable keys:

Preserve existing stable keys unless absolutely necessary.

Must preserve:

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

If new wrapper keys are needed, use semantic names.

Suggested new keys if useful:

* timeline-sticky-header-row
* timeline-scrollable-body
* timeline-layer-rows-scroll-body
* timeline-frame-rows-scroll-body

The exact key names may differ, but prefer stable semantic keys over fragile widget-position tests.

Testing requirements:

Update or add widget tests.

Likely file:
test/ui/layer_timeline_grid_test.dart

Required tests:

1. Frame ruler stays fixed during vertical scroll

Given:

* multiple layers enough to allow vertical scrolling

Action:

* record frame ruler/header row position
* perform vertical scroll

Expected:

* frame ruler/header row position does not move vertically
* a layer row/frame cell row does move vertically

2. - Layer header stays fixed during vertical scroll

Given:

* multiple layers enough to allow vertical scrolling

Action:

* record `+ Layer` header position
* perform vertical scroll

Expected:

* `+ Layer` header position does not move vertically
* layer rows below it move vertically

3. Layer rows and frame cell rows remain vertically synchronized

Given:

* multiple layers
* vertical scroll

Expected:

* corresponding layer control row and frame cell row remain aligned vertically

4. Frame ruler and frame cell rows remain horizontally synchronized

Given:

* many frames
* horizontal scroll

Expected:

* visible frame header range changes
* frame cells match the same visible frame range
* bottom horizontal scrollbar still works

5. Vertical scrollbar controls body only

Given:

* enough layers for vertical scroll

Action:

* use vertical scroll / scrollbar behavior as existing tests support

Expected:

* body rows move
* frame ruler/header remains fixed

6. Playhead column has no border

Expected:

* timeline-playhead-column exists for visible current frame
* its decoration/fill has no border
* it remains red semi-transparent fill

7. Current frame selected border uses red styling

Expected:

* current frame header selected border uses red or ColorScheme.error/red equivalent
* current frame cell selected border uses red or ColorScheme.error/red equivalent if applicable
* previous purple primary border is not used for current frame selection

8. Existing interaction tests still pass

Expected:

* frame header tap still works
* frame cell tap still works
* playhead does not block taps
* horizontal virtualization tests still pass
* bottom horizontal scrollbar tests still pass
* vertical scrollbar slot tests still pass
* small frame count minimum visible cells tests still pass

Documentation:

Update:
docs/LongTerm_Performance_Architecture.md

Add a short Phase 102 note:

* Frame ruler/header became vertically sticky.
* Vertical scroll now applies to the body rows only.
* Horizontal scroll remains shared between frame ruler and frame cells.
* Playhead visual was polished to a borderless red translucent column.
* Current frame border styling was aligned to red.
* No vertical layer virtualization, playback, zoom, or dragging was added.

Out of scope:

Do not implement vertical layer virtualization.
Do not implement playhead dragging.
Do not implement playback.
Do not implement zoom.
Do not implement ruler ticks redesign.
Do not implement current frame label.
Do not implement keyboard shortcuts.
Do not implement auto-scroll to playhead.
Do not implement timeline snapping.
Do not implement StoryboardPanel playhead.
Do not implement camera/sound sections.
Do not change Project / Track / Cut / Layer / Frame / Stroke models.
Do not change renderer/cache.
Do not change persistence/save/load.
Do not change command/undo/redo logic.
Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.
Do not implement Phase 103 or later.

Required checks:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* summary of layout structure changes
* confirmation that frame ruler/header is vertically sticky
* confirmation that `+ Layer` header is vertically sticky
* confirmation that only body rows scroll vertically
* confirmation that layer rows and frame cell rows remain vertically synchronized
* confirmation that frame ruler and frame cells remain horizontally synchronized
* confirmation that vertical layer virtualization was not implemented
* confirmation that playhead column border was removed
* confirmation that playhead is a red semi-transparent fill only
* confirmation that current frame selected border styling is red
* confirmation that playhead/header/cell taps still work
* confirmation that no dragging/playback/zoom was added
* confirmation that no model changes were made
* confirmation that no renderer/cache/persistence changes were made
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 102 is complete when:

* Vertical scrolling does not move the frame ruler/header row.
* Vertical scrolling does not move the `+ Layer` top header.
* Vertical scrolling moves only the body rows.
* Left layer rows and right frame cell rows stay vertically aligned.
* Horizontal scrolling moves frame ruler and frame cell rows together.
* Bottom horizontal scrollbar still works.
* Vertical scrollbar controls the body scroll area.
* Horizontal virtualization still works.
* Vertical layer virtualization is not implemented.
* Playhead column is red semi-transparent fill only.
* Playhead column has no border/outline/silhouette.
* Playhead remains visible with one layer.
* Current frame selected border styling is red.
* Frame header taps still work.
* Frame cell taps still work.
* Existing stable timeline keys are preserved.
* No domain model changes are made.
* No renderer/cache/persistence changes are made.
* No StoryboardPanel changes are made.
* dart format lib test completes.
* flutter analyze passes.
* flutter test passes.
