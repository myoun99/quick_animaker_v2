# Phase 98 Codex Task - Timeline Vertical Scrollbar Slot Foundation

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

QuickAnimaker v2 is building a long-term TVPaint-style bitmap animation timeline.

Recent timeline phases:

* Phase 91 added visible range calculation.
* Phase 92 added a virtualization render plan.
* Phase 93 added TimelineGridMetrics and a TimelinePanel virtualization adapter.
* Phase 94 separated fixed layer controls rail from the horizontal frame scroll viewport.
* Phase 95 applied horizontal frame virtualization.
* Phase 96 added a visible horizontal scrollbar foundation.
* Phase 97 moved the horizontal scrollbar into a stable bottom rail.
* PR 137 aligned the horizontal scrollbar to the frame-grid bottom area and kept the left bottom area reserved.
* PR 138 replaced the detached Flutter Scrollbar with a custom visible bottom horizontal scrollbar rail using the existing horizontal ScrollController.

Current desired next step:

Add a TVPaint-style vertical scrollbar slot between:

* the left layer controls rail
* the right frame grid area

Do not implement vertical layer virtualization yet.

## Goal

Add a visible vertical scrollbar foundation between the layer controls rail and the frame grid area.

Desired layout:

[ layer controls rail ] [ vertical scrollbar ] [ frame grid area                 ]
[ reserved bottom    ] [ reserved bottom    ] [ horizontal scrollbar full width ]

The vertical scrollbar must control the shared vertical scrolling of both:

* layer controls rows
* frame rows

The horizontal scrollbar must remain at the bottom of the frame grid area only.

## Required behavior

* Add a visible vertical scrollbar rail between layer controls and frame grid.
* The vertical scrollbar must not be placed at the far right of the timeline.
* The vertical scrollbar must not be inside the horizontally scrolling frame content.
* Layer controls and frame rows must continue to scroll vertically together.
* Do not split the layer controls and frame rows into independent vertical scroll views.
* Keep one shared vertical scroll behavior.
* Keep existing horizontal frame virtualization.
* Keep existing bottom horizontal scrollbar behavior from PR 138.
* Keep the left bottom reserved area.
* The horizontal scrollbar must still align with the frame grid area, not the layer controls area.

## Required implementation direction

Update:

* lib/src/ui/timeline/layer_timeline_grid.dart

Add an explicit vertical ScrollController for the shared vertical scroll area.

Recommended structure:

* timeline-scrollbar-area

    * Column

        * Expanded

            * Stack or equivalent safe structure

                * shared vertical SingleChildScrollView

                    * Row

                        * timeline-layer-controls-rail
                        * reserved vertical scrollbar slot width
                        * timeline-frame-grid-area
                * visible vertical scrollbar rail positioned in the reserved slot
        * bottom horizontal scrollbar row

            * left reserved spacer
            * vertical scrollbar bottom spacer
            * horizontal scrollbar rail aligned with frame grid area

The important point:

The vertical scroll must remain shared.

Do not create:

* one vertical scroll view for the layer controls rail
* another vertical scroll view for the frame grid

That can desync layer names and frame rows and must not be reintroduced.

## New keys

Add stable keys:

* timeline-vertical-scrollbar-slot
* timeline-vertical-scrollbar
* timeline-vertical-scrollbar-track
* timeline-vertical-scrollbar-thumb
* timeline-vertical-scrollbar-bottom-spacer
* timeline-vertical-scroll-viewport

Keep existing keys stable:

* timeline-scrollbar-area
* timeline-horizontal-scrollbar
* timeline-horizontal-scrollbar-track
* timeline-horizontal-scrollbar-thumb
* timeline-horizontal-scrollbar-viewport
* timeline-layer-controls-rail
* timeline-frame-grid-area
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-bottom-scrollbar-rail
* timeline-bottom-scrollbar-left-spacer
* timeline-frame-header-<frameIndex>
* timeline-cell-<layerId>-<frameIndex>
* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-row-leading-spacer-<layerId>
* timeline-frame-row-trailing-spacer-<layerId>
* timeline-layer-row-<layerId>
* timeline-layer-kind-icon-<layerId>
* timeline-layer-name-<layerId>
* timeline-add-layer-button

Do not remove existing keys.

## Vertical scrollbar behavior

The vertical scrollbar should be visible when content is taller than the viewport.

It should use the shared vertical ScrollController.

The vertical thumb should represent:

* viewport height
* total vertical content height
* current vertical scroll offset

Suggested calculation:

* totalContentHeight = header row height + layer row height * layerCount
* viewportHeight = visible timeline grid height excluding bottom horizontal scrollbar rail
* maxScrollExtent = max(0, totalContentHeight - viewportHeight)
* thumbHeight = viewportHeight * viewportHeight / totalContentHeight
* clamp thumbHeight to a usable minimum
* thumbTop is proportional to verticalScrollOffset / maxScrollExtent

If content fits without vertical scrolling:

* thumb may fill the rail or be hidden.
* Prefer visible but full-height/disabled-looking thumb only if it does not confuse tests or users.

Thumb dragging:
Prefer implementing thumb drag using the shared vertical ScrollController and jumpTo(...), clamped to valid extents.

If dragging is too risky for this phase, visible rail + thumb is acceptable, but report that drag is deferred.

However, do not break existing mouse wheel / touchpad vertical scrolling.

## Horizontal scrollbar interaction

The bottom horizontal scrollbar from PR 138 must remain.

The bottom row should now reserve space for:

* layer controls rail width
* vertical scrollbar slot width
* horizontal scrollbar rail under the frame grid area

This means:

* timeline-bottom-scrollbar-left-spacer remains under the layer controls rail
* timeline-vertical-scrollbar-bottom-spacer sits under the vertical scrollbar slot
* timeline-bottom-scrollbar-rail starts at the same x position as timeline-frame-grid-area

The horizontal scrollbar must not extend into:

* layer controls rail area
* vertical scrollbar slot area

## Metrics

Prefer keeping the vertical scrollbar slot width as a small stable timeline metric.

Acceptable options:

Option A:
Add verticalScrollbarWidth to TimelineGridMetrics.defaults.

Option B:
Use a private constant in LayerTimelineGrid if this is safer and smaller.

If adding to TimelineGridMetrics, update its tests.

Keep the width simple, around 12 to 16 logical pixels.

## Tests

Update or add tests in:

* test/ui/layer_timeline_grid_test.dart

If TimelineGridMetrics is changed, also update:

* test/ui/timeline/timeline_grid_metrics_test.dart

Required test coverage:

* timeline-vertical-scrollbar-slot exists.
* timeline-vertical-scrollbar exists.
* timeline-vertical-scrollbar-track exists.
* timeline-vertical-scrollbar-thumb exists.
* timeline-vertical-scroll-viewport exists.
* vertical scrollbar slot is between layer controls rail and frame grid area.
* vertical scrollbar slot is not inside the horizontal frame scroll content.
* layer controls rail and frame rows remain vertically aligned for many layers.
* vertical scrolling moves layer controls and frame rows together.
* horizontal scrolling still changes the virtualized frame range.
* horizontal scrolling does not move the layer controls rail.
* bottom horizontal scrollbar still exists.
* bottom horizontal scrollbar still starts at the frame grid area.
* bottom horizontal scrollbar does not extend under the layer controls rail or vertical scrollbar slot.
* frame cell selection still works.
* layer label selection still works.

Avoid fragile tests:

* Do not compare text baselines.
* Do not depend on internal Flutter Scrollbar implementation details.
* Use stable keys and high-level geometry relationships.

## Documentation

Update:

* docs/LongTerm_Performance_Architecture.md

Add a small Phase 98 note.

Suggested note:

Phase 98 adds a visible vertical scrollbar slot between the fixed layer controls rail and the frame grid area. The vertical scrollbar is tied to the shared vertical scroll area so layer controls and frame rows remain aligned. This prepares the timeline for future vertical virtualization without splitting the layer rail and frame rows into independent scroll views.

Do not rewrite the whole document.

## Out of scope

Do not change:

* Project / Track / Cut / Layer / Frame models
* persistence
* renderer/cache
* commands
* undo/redo
* StoryboardPanel
* HomePage
* layer editing behavior
* frame editing behavior
* horizontal virtualization logic
* save/load

Do not add:

* vertical layer virtualization
* layer reordering
* frame editing behavior
* playhead/ruler/zoom
* cut editing behavior
* full custom timeline renderer

This phase is only the visible vertical scrollbar slot foundation.

## Acceptance criteria

This phase is complete when:

* A visible vertical scrollbar slot exists between layer controls and frame grid.
* The vertical scrollbar controls or reflects the shared vertical scroll area.
* Layer controls and frame rows remain vertically aligned.
* The horizontal scrollbar remains visible at the bottom of the frame grid area.
* The horizontal scrollbar does not extend under the layer controls or vertical scrollbar slot.
* Existing horizontal virtualization still works.
* Existing tests pass.
* New tests cover the vertical scrollbar slot and scroll alignment.
* No model or editing behavior changes are introduced.
* docs/LongTerm_Performance_Architecture.md is updated.
* dart format lib test passes.
* flutter analyze passes.
* flutter test passes.
* git status is clean.

## Required checks

Run:

dart format lib test
flutter analyze
flutter test
git status

## Codex report requirements

In the final report, include:

* changed files
* new vertical scrollbar keys
* whether vertical scrollbar dragging was implemented or deferred
* how shared vertical scrolling is preserved
* how horizontal scrollbar alignment is preserved
* confirmation that horizontal virtualization remains active
* confirmation that vertical layer virtualization was not implemented
* confirmation that no models or editing behavior were changed
* final command results:

    * dart format lib test
    * flutter analyze
    * flutter test
    * git status
