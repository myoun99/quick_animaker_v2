# Current Timeline Architecture

## Core range semantics

Timeline values must remain separate by meaning. A value that is correct for one concept must not be reused as another bound unless that policy explicitly says so.

### Playback range

- Defined by `Cut.duration`.
- Used for playback and export duration.
- Must not be treated as the frame data limit, editing limit, selection limit, selected exposure visual bound, or authored data extent.
- Frames outside `Cut.duration` may still be visible, selectable, and editable when the display range includes them.

### Visible/display range

- UI range chosen for display and interaction, usually playback duration plus a safety tail.
- Must not define authored data extent, permanent project length, or playback/export duration.

### Virtualized frame window

- The subset of the visible/display range rendered by the timeline body.
- Controlled by horizontal offset and viewport width.
- A rendering optimization only; it must not change playback, data ownership, selection, or editability semantics.

### Authored/data extent

- The extent of actual authored timeline data, tracked separately from display and playback range.
- Must not be used as the selected exposure outline visual bound, playback duration, or visible range.

## TimelinePanel performance direction

TimelinePanel / LayerTimelineGrid may be eager in the early MVP, but the production direction is viewport-based two-axis virtualization:

- Maintain horizontal and vertical scroll controllers.
- Compute visible frame and layer ranges from scroll offsets, viewport sizes, and cell/row metrics.
- Build only visible frame headers, visible layer rows, and visible cells with overscan.
- Keep selection, playhead, frame commands, and authored data independent from widget existence.
- Do not persist UI scroll or viewport state into `Project`, `Cut`, `Layer`, or `Frame`.
- Keep data sparse; do not create persistent objects for empty cells.

## Protected UI/layout rules

- Timeline semantics tests must remain passing.
- Storyboard and timeline views may share time scale, frame-to-pixel mapping, horizontal scrolling, playhead positioning, block selection, frame range calculation, and undoable timeline edit commands where appropriate.
- A vertical `ListView.builder` alone is not enough for production timeline performance if each row still eagerly builds every frame cell.
