# Long-Term Timeline Range Semantics

## Purpose

This document is the long-term design reference for timeline range semantics.
It exists to keep playback, display, virtualization, authored data, selected
exposure visuals, horizontal scrolling, and frame coordinate conversion as
separate concepts.

Future changes should preserve these distinctions. A timeline value that is
correct for one concept must not be reused as a bound for another concept unless
the policy for that concept explicitly says so.

## 1. Playback range

### Definition

The playback range is defined by `Cut.duration`.

It is used for playback and export duration. It determines where cut playback
ends, and it may be visualized in the timeline by a cut-end boundary.

### Must not mean

`Cut.duration` must not be treated as any of the following:

* a frame data limit
* a selection limit
* an editing limit
* a selected exposure outline limit
* the authored data extent

### Important rule

Frames outside `Cut.duration` may still be visible, selectable, and editable if
the UI display range includes them.

The playback range answers the question “where does playback/export end?” It
does not answer “which frames can the user see or edit?”

## 2. Visible/display range

### Definition

The visible/display range is the range of frames the timeline chooses to display.
It is usually derived from playback duration plus a safety tail. The current
default safety tail is handled by the existing timeline frame range policy.

### Must not mean

The visible/display range must not be treated as any of the following:

* authored/data extent
* playback/export duration
* permanent project length

### Important rule

The visible/display range exists for UI display and interaction only.

It defines the frame area the user can currently see and interact with. It does
not define how much authored data exists, how long playback/export lasts, or the
permanent length of the project.

## 3. Virtualized frame window

### Definition

The virtualized frame window is the subset of the visible/display range currently
rendered by the timeline body. It is usually represented by `frameStartIndex` and
`frameEndIndexExclusive`, and it is controlled by horizontal offset and viewport
width.

### Must not mean

The virtualized frame window must not be treated as any of the following:

* selected exposure data extent
* `Cut.duration`
* authored extent

### Important rule

Virtualization is a rendering optimization. It must not change timeline data
semantics.

The timeline may render only a window of frames for performance, but that window
must not become the source of truth for playback, data ownership, selection
semantics, or editability.

## 4. Authored/data extent

### Definition

The authored/data extent is the extent of actual authored timeline data. It is
tracked separately by `TimelineController.authoredTimelineExtentFrameCount`.

### Must not mean

The authored/data extent must not be treated as any of the following:

* selected exposure outline visual bound
* playback duration
* visible range

### Important rule

`authoredTimelineExtentFrameCount` must not be reintroduced into `TimelinePanel`
or `LayerTimelineGrid` for selected exposure outline rendering.

Authored/data extent answers questions about data that exists. It must not be
used to shorten display-range visuals or to redefine playback/display behavior.

## 5. Selected exposure visual range

### Definition

The selected exposure visual range is a visual highlight for the selected
exposure block. It is a display-range visual effect, and it is resolved by
`selected_exposure_display_range_policy.dart`.

### Important rules

* It may continue beyond `Cut.duration`.
* It may continue beyond `playbackFrameCount`.
* It must not be bounded by `authoredTimelineExtentFrameCount`.
* It is clamped only for rendering to the current virtualized frame window.
* It must not create, delete, or resize timeline data.
* It must not imply authored data exists through the whole outlined visual span.

The selected exposure visual range is about what outline should be drawn for the
current display state. It is not a data extent, playback extent, or editing
extent.

## 6. Effective horizontal scroll offset

### Definition

The effective horizontal scroll offset is the clamped horizontal offset used for
actual rendering and hit testing. It is resolved by
`timeline_horizontal_offset_policy.dart`.

### Important rules

* Ruler, body, selected exposure outline, and hit testing must use the same
  effective offset.
* Raw scroll controller offset may be temporarily out of bounds after resize.
* The effective offset must be clamped before layout or hit-test math uses it.
* `ScrollController` correction is a widget side effect and should stay outside
  the pure policy.

The raw scroll offset is an input request. The effective horizontal scroll offset
is the value that rendering and hit testing should share.

## 7. Frame coordinate conversion

### Definition

Frame coordinate conversion is frame index ↔ x-position conversion. It is
handled by `timeline_frame_coordinate_policy.dart`.

### Important rules

* Ruler hit testing must use the effective horizontal offset.
* Selected exposure outline position and width should use shared coordinate
  helpers.
* Coordinate helpers must remain pure and not know about `Cut.duration`, authored
  extent, or playback semantics.

Frame coordinate conversion should only translate between frame indices and
positions. It must not embed timeline range policy or data semantics.
