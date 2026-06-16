# QuickAnimaker v2 Long-Term Priority / Performance Handoff Update

## 1. Global development priority

From this point forward, QuickAnimaker v2 development should prioritize long-term correctness, performance, scalability, and maintainability over short-term fixes.

When reviewing PRs or writing new phase tasks:

* Do not only silence the current test failure.
* Identify the structural cause of the issue.
* Prefer a solution that remains correct when the project grows to many cuts, many layers, and many frames.
* It is acceptable for a phase to be harder if it prevents future architectural debt.
* Avoid fixes that only increase fixed sizes to hide overflow.
* Prefer semantic wrapper keys and structural tests over fragile text-position tests.
* Preserve existing keys unless a phase explicitly defines a migration.
* If a test is wrong because it checks the wrong semantic layer, fix the test meaning rather than distorting the UI to satisfy it.

## 2. Track label alignment policy

For StoryboardPanel track labels, the project should distinguish between the visible label text and the structural label row.

The visible text key should remain:

* storyboard-track-label-<trackId>

This key should stay on the Text widget.

A separate structural row wrapper key should be used:

* storyboard-track-label-row-<trackId>

This key should be placed on the full label row wrapper.

Recommended structure:

* storyboard-track-label-rail

    * storyboard-track-label-row-<trackId>

        * storyboard-track-label-<trackId>

* storyboard-timeline-scroll-content

    * storyboard-track-row-<trackId>

        * storyboard-track-timeline-area-<trackId>

Alignment tests should compare:

* storyboard-track-label-row-<trackId>
* storyboard-track-timeline-area-<trackId>

Do not compare the top position of the Text widget with the top position of the timeline lane.

Reason:

The Text may be centered, styled, resized, or changed later.
The row wrapper and lane wrapper are the correct long-term layout boundaries.

## 3. Current TimelinePanel performance status

The current TimelinePanel / LayerTimelineGrid is not yet long-term virtualized.

Current structure:

* LayerTimelineGrid uses nested SingleChildScrollView.
* Frame headers are built with a loop over visibleFrameCount.
* Each layer row builds frame cells with a loop over visibleFrameCount.
* visibleFrameCount is currently max(frameCount, 24).

This is acceptable only for early MVP and small projects.

It is not acceptable for the long-term target of large projects such as:

* thousands of frames
* tens of thousands of frames
* 100k-frame stress cases
* many layers multiplied by many frame cells

Do not assume the current eager Row / Column frame grid is production-ready.

Phase 93 introduced TimelineGridMetrics and a TimelinePanel virtualization adapter so future TimelinePanel virtualization calculations use the same dimensions as the current LayerTimelineGrid instead of duplicating hardcoded values.

## 4. Required long-term TimelinePanel direction

TimelinePanel must eventually use viewport-based virtualization.

The long-term frame grid should not build every frame cell widget.

Required direction:

* Maintain scroll controllers for horizontal and vertical timeline axes.
* Compute visible frame range from horizontal scroll offset and viewport width.
* Compute visible layer range from vertical scroll offset and viewport height.
* Build only visible frame headers.
* Build only visible layer rows.
* Build only visible frame cells inside visible rows.
* Add small overscan/cache margins for smooth scrolling.
* Keep selection, playhead, and frame commands independent from widget existence.
* Do not store UI scroll or viewport state inside Project / Cut / Layer / Frame domain models.
* Keep data sparse.
* Do not create persistent objects for every empty frame cell.

Suggested future abstractions:

TimelineViewportState

* horizontalScrollOffset
* verticalScrollOffset
* viewportWidth
* viewportHeight
* cellWidth
* rowHeight
* visibleFrameStart
* visibleFrameEnd
* visibleLayerStart
* visibleLayerEnd
* overscanBefore
* overscanAfter

TimelineVisibleRangeCalculator

* input:

    * scroll offsets
    * viewport size
    * cell size
    * row size
    * total frames
    * total layers
* output:

    * visible frame index range
    * visible layer index range

TimelineGridViewport

* renders only the visible region
* preserves stable keys for visible cells
* does not instantiate offscreen cells

## 5. ListView.builder policy

Do not assume ListView.builder alone solves TimelinePanel performance.

ListView.builder is useful for one-axis lazy building.

TimelinePanel is a two-axis grid:

* vertical axis = layers
* horizontal axis = frames

A vertical ListView.builder for layer rows is not enough if each row still builds all frame cells in a wide Row.

A horizontal ListView.builder inside each row is also not enough unless:

* all rows share the same horizontal scroll offset
* the frame header shares the same horizontal scroll offset
* current frame selection remains synchronized
* cell keys remain stable
* visible range calculation is shared and tested

Preferred long-term solution:

Use explicit 2D viewport/range calculation, then render only visible rows and visible cells.

## 6. StoryboardPanel performance status

StoryboardPanel is currently more efficient than TimelinePanel because it renders Cut blocks instead of every frame cell.

However, it still currently builds positioned Cut blocks for all layout entries in a track.

This is acceptable for early storyboard timeline foundation work.

Long-term, if projects can contain many cuts, StoryboardPanel should also virtualize.

Future StoryboardPanel virtualization direction:

* Compute visible timeline frame range from horizontal scroll offset.
* Render only Cut blocks that intersect the visible range plus overscan.
* Keep fixed track label rail outside horizontal scroll.
* Keep active cut sync independent from whether a Cut block is currently visible.
* Do not mutate Project while deriving visible layout.

## 7. StoryboardPanel current structural direction

StoryboardPanel is moving toward a Premiere / DaVinci-like multi-track timeline.

Current direction is correct:

* fixed track label rail
* horizontal timeline viewport
* scroll content separated from labels
* timeline lanes per track
* Cut blocks positioned by TimelineScale
* TimelineBlock used for visual block primitive

Preserve this direction.

Do not revert to simple Row-based Cut layout.

## 8. Compact timeline block policy

All timeline blocks must be safe at compact widths and compact heights.

Do not assume text fits.

Use:

* maxLines: 1
* overflow: TextOverflow.ellipsis
* softWrap: false
* Flexible / Expanded where appropriate
* ClipRect where content can legitimately exceed compact space
* stable wrapper keys for layout tests

Do not fix overflow only by increasing minimum width or minimum height unless the phase explicitly requires it.

## 9. Test policy for long-term UI stability

Prefer tests that check semantic structure instead of incidental pixel position of inner text.

Good tests:

* wrapper row aligns with lane
* fixed label rail exists
* horizontal viewport exists
* scroll content exists
* label is outside scroll content
* timeline area contains positioned Cut block
* active cut indicator exists for active Cut
* inactive Cut tap calls onCutSelected
* compact block pumps without overflow
* long timeline pumps without overflow

Fragile tests to avoid:

* Text top equals lane top
* exact text position when text is centered
* broad find.text without scoping
* relying on full offscreen widget construction in a virtualized future

## 10. Future recommended Phase

Before adding ruler, playhead, or zoom, add a performance architecture phase.

Recommended next phase:

Phase 91 - Timeline Virtualization Architecture and Guardrails

Goal:

* Audit current TimelinePanel eager rendering.
* Define the target 2D virtualization architecture.
* Add documentation and tests that prevent future phases from assuming all frame cells are built.
* Do not rewrite TimelinePanel yet unless the phase explicitly says so.
* Prepare the path for a later TimelinePanel virtualization implementation phase.

Possible outputs:

* docs/Timeline_Virtualization_Strategy.md
* tests for visible range calculator if introduced
* no model changes
* no renderer changes
* no UI behavior changes unless minimal internal helpers are needed

## 11. Non-negotiable long-term performance rule

QuickAnimaker v2 should not rely on building all frame-cell widgets for large timelines.

Any timeline feature must be designed so it can eventually support:

* 100k frames
* many layers
* sparse exposures
* lazy visible rendering
* stable selection and editing even when cells are offscreen

## 12. Current conclusion

The current implementation is not yet ListView.builder-based or fully virtualized.

The current eager Row / Column implementation is acceptable for the early MVP phase, but it must not be treated as the final performance architecture.

For the user's goal of a lightweight, low-lag animation program, TimelinePanel virtualization must become a major architectural priority before heavy timeline features are added.

## 10. Phase 91 Timeline visible range foundation

Phase 91 introduced a pure Dart `TimelineVisibleRange` calculation layer as the first concrete foundation for future TimelinePanel 2D virtualization.

This foundation computes clamped visible frame and layer index ranges from scroll offsets, viewport extents, item extents, item counts, and overscan margins without building timeline widgets or storing viewport state in domain models.

Phase 92 introduced a pure Dart `TimelineVirtualizationPlan` render plan foundation. It converts visible frame/layer ranges into leading/trailing spacer dimensions and total virtual content dimensions so future TimelinePanel virtualization can preserve scroll geometry while rendering only visible cells.


Phase 94 separated `LayerTimelineGrid` into a fixed layer controls rail and a horizontal frame scroll area. This prepares the TimelinePanel for future horizontal frame virtualization by ensuring frame scroll geometry is independent from the layer controls column while frame headers and cells still render eagerly for now.


## Phase 95 update

Phase 95 applied the first horizontal frame virtualization slice to LayerTimelineGrid. The fixed layer controls rail remains eager and stable, while frame headers and frame cells are now built only for the visible/overscanned horizontal frame range with leading/trailing spacers preserving full scroll geometry.

## Phase 96 update

Phase 96 added a visible horizontal scrollbar foundation for LayerTimelineGrid so horizontal frame virtualization is discoverable and controllable. The scrollbar is tied to the frame scroll viewport, not the fixed layer controls rail, preserving the long-term TVPaint-style direction where scroll controls are stable and visible.

## Phase 97 update

Phase 97 moved the horizontal scrollbar into a stable bottom rail so timeline scrolling remains visible and discoverable regardless of layer count. This keeps the frame grid above the scrollbar and preserves the fixed layer controls rail / frame viewport separation required for long-term TVPaint-style timeline ergonomics.

## 9. Phase 98 timeline vertical scrollbar slot foundation

Phase 98 adds a visible TVPaint-style vertical scrollbar slot between the fixed layer controls rail and the horizontal frame grid area.

Current Phase 98 rules:

* The layer controls rail and frame rows still use one shared vertical scroll viewport.
* Do not split layer controls and frame rows into independent vertical scroll views.
* The vertical scrollbar rail is reserved between the layer controls rail and the frame grid area, not at the far right of the timeline.
* The bottom horizontal scrollbar remains aligned with the frame grid area only.
* The bottom rail reserves both the layer controls width and the vertical scrollbar slot width before the horizontal scrollbar begins.
* Vertical layer virtualization is still deferred.
* The vertical scrollbar thumb may drive the shared vertical scroll controller, but this is UI scroll state only and must not be stored in Project / Cut / Layer / Frame models.

Stable keys introduced for this structure:

* `timeline-vertical-scrollbar-slot`
* `timeline-vertical-scrollbar`
* `timeline-vertical-scrollbar-track`
* `timeline-vertical-scrollbar-thumb`
* `timeline-vertical-scrollbar-bottom-spacer`
* `timeline-vertical-scroll-viewport`
