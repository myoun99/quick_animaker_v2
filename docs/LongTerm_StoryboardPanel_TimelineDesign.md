# Long Term Storyboard Panel Timeline Design

## Purpose

This document defines the long-term design direction for the QuickAnimaker v2 Storyboard Panel.

The Storyboard Panel should not be designed as an isolated storyboard-only data model.

Instead, it should behave like a professional video-editing timeline panel, inspired by tools such as Premiere Pro and DaVinci Resolve, while still using QuickAnimaker's existing animation data model.

## Core design idea

The Storyboard Panel is a project/cut timeline view.

It should show:

```text
Project
  Track / V1, V2...
    Cut block
      Storyboard Layer head / storyboard exposure strip
```

The primary visual unit is a Cut block.

Each Cut block spans the Cut duration.

If the Cut contains a `LayerKind.storyboard` layer, the Storyboard Panel should show that Storyboard Layer's head/exposure strip inside the Cut block.

If the Cut does not contain a Storyboard Layer, the panel should still show the Cut block, but without storyboard layer content inside it.

## Important model rule

Do not create a separate `Cut.storyboardPanel`, `Cut.storyboardLayer.panels`, or independent storyboard-panel model.

Storyboard data already lives in the normal animation model:

```text
Cut.layers
  Layer(kind: LayerKind.storyboard)
    frames
    timeline
    Frame.storyboardMetadata
```

The Storyboard Panel should read from this existing structure.

The panel is a UI/view layer, not a separate content model.

## Professional video-editing reference

The panel should conceptually follow professional video-editing timelines:

* track headers on the left
* horizontal time ruler
* V1, V2, ... style visual tracks
* rectangular Cut/clip blocks spanning time
* playhead line
* timeline zoom/pan behavior
* clip/cut block selection
* trim/drag behavior in future phases

The UI does not need to visually copy Premiere Pro or DaVinci exactly.

However, the logic should feel consistent with professional editing timelines.

## Relationship with the existing Timeline Panel

The Storyboard Panel should reuse timeline logic wherever possible.

Do not create a separate storyboard-only timeline engine.

The following concepts should eventually be shared or made reusable:

* time scale / frame-to-pixel mapping
* horizontal scrolling
* timeline ruler
* playhead positioning
* block selection
* frame range calculation
* drag-to-extend exposure duration
* trim/comma extension behavior
* hit testing for timeline blocks
* undoable timeline edit commands

The existing Timeline Panel and the future Storyboard Panel should feel like different views using the same underlying timeline interaction concepts.

## Cut block behavior

A Cut block represents one Cut.

The Cut block width should be based on Cut duration.

Example:

```text
Cut duration = 24 frames
=> Cut block spans 24 timeline units
```

The Storyboard Panel should be able to display multiple Cut blocks along the same horizontal timeline.

In the long term, Cut blocks should support:

* selection
* active Cut sync
* playhead sync
* drag to move, if project-level cut timing supports it later
* trim duration, if allowed later
* embedded storyboard exposure display

## Storyboard Layer display inside Cut block

If a Cut contains a Storyboard Layer:

```text
Cut.layers contains LayerKind.storyboard
```

then the Storyboard Panel should display that layer inside the Cut block.

The first minimal version may show only:

* Storyboard Layer exists
* layer name
* placeholder head
* frame/exposure count

Later versions may show:

* storyboard frame heads
* exposure blocks
* thumbnails
* frame names
* action/dialogue/note indicators
* selected storyboard frame highlight

## Storyboard Layer absence

If a Cut has no Storyboard Layer:

* the Cut block still appears
* the inner storyboard strip is empty
* UI may display a subtle placeholder such as `No Storyboard Layer`
* no Storyboard Layer should be created automatically just by opening the panel

Creating a Storyboard Layer should remain an explicit user action.

## Track meaning

The V1, V2, ... style tracks in the Storyboard Panel should represent project-level Cut tracks, not animation cel layers.

Do not confuse these with animation layers such as A, B, C.

Short-term:

```text
Project Track 1 -> V1
```

Long-term:

```text
Project.tracks -> V1, V2, V3...
```

Animation layers remain inside each Cut.

Storyboard Layer remains one of the Cut's layers.

## Relationship between Cut block and Storyboard Layer

The Cut block is the container.

The Storyboard Layer is displayed inside the Cut block only when it exists.

Conceptually:

```text
Cut block
  contains visual representation of Storyboard Layer
```

But the data model remains:

```text
Cut
  layers
    storyboard layer
```

Do not store the Storyboard Layer inside a separate Cut block object.

The Cut block is a UI representation of `Cut`.

## Storyboard metadata

Storyboard text data should use the existing model:

```text
Frame.storyboardMetadata
  actionMemo
  dialogueMemo
  note
```

Do not create new metadata fields for the Storyboard Panel unless a later phase explicitly requires it.

The panel may later display or edit this metadata, but it should use the existing `UpdateStoryboardFrameMetadataCommand`.

## Thumbnail policy

Do not implement full thumbnail rendering in the first Storyboard Panel phases.

Start with placeholders or lightweight labels.

Thumbnail rendering should be added only after the rendering/cache architecture is ready.

Early phases should avoid renderer/cache changes.

## Initial implementation direction

The Storyboard Panel should be introduced gradually.

Recommended phase sequence:

```text
Phase A: Storyboard Panel shell
- show panel area
- show project/cut timeline tracks
- show Cut blocks by duration
- no editing
- no thumbnails

Phase B: Storyboard Layer presence display
- inside each Cut block, show whether a Storyboard Layer exists
- show storyboard layer name or placeholder
- no editing

Phase C: Storyboard frame/exposure strip
- show storyboard frame heads/exposures inside Cut block
- read from Storyboard Layer timeline
- share timeline geometry with the normal Timeline Panel if possible

Phase D: Storyboard metadata display/edit
- show actionMemo/dialogueMemo/note
- edit via existing command
- undo/redo support

Phase E: Selection sync
- selecting a Cut block selects active Cut
- selecting a storyboard frame syncs active frame
- playhead sync between panel and main timeline

Phase F: Timeline interaction reuse
- drag to extend exposure/comma
- trim behavior
- shared hit testing and geometry utilities
```

## What not to do early

Do not implement these in the first Storyboard Panel phases:

* separate storyboard model
* separate storyboard panel data tree
* renderer/cache redesign
* thumbnail cache system
* drag/trim editing before shared timeline interaction is ready
* audio tracks
* camera tracks
* sound layers
* section UI
* vertical timesheet redesign
* action/dialogue editor before basic panel shell exists
## Storyboard export flattening policy

The Storyboard Panel and Storyboard Export should be treated as related but separate concepts.

The Storyboard Panel is a multi-track editing view.

Storyboard Export is a flattened ordered output for storyboard sheets, PDF export, image export, or print.

In other words:

```text
Storyboard Panel
= multi-track editing timeline

Storyboard Export
= ordered storyboard sheet output
```

## Why export needs flattening

The Storyboard Panel may show multiple project-level tracks such as:

```text
V1
V2
V3
```

These tracks are useful for editing, alternatives, references, revisions, temporary cuts, and future professional video-editing workflows.

However, a storyboard sheet is usually read in a single ordered sequence:

```text
Cut 001
Cut 002
Cut 003
Cut 004
...
```

Therefore, export should not simply print every timeline track as-is.

Export needs a flattening policy that converts the multi-track project timeline into an ordered storyboard output list.

## Default export mode: Primary Track

The default and safest storyboard export mode should be Primary Track export.

For the initial implementation:

```text
V1 = Primary storyboard output track
```

Only V1 should be exported by default.

Example:

```text
V1: Cut A -> Cut B -> Cut C
V2: Alt Cut B2 / reference / temporary idea
V3: notes / other experiment
```

Default storyboard export result:

```text
001 Cut A
002 Cut B
003 Cut C
```

This matches the traditional storyboard sheet expectation.

V2, V3, and later tracks should be treated as auxiliary tracks unless the user explicitly chooses another export mode.

## Meaning of non-primary tracks

In the early design, non-primary tracks should be considered optional/supporting tracks.

They may be used for:

* alternative cuts
* revision candidates
* reference timing
* temporary editing ideas
* comparison versions
* director notes or planning material in future phases

They should not automatically appear in the standard storyboard sheet export.

This avoids accidental export of work-in-progress or alternate material.

## Future export mode: Selected Tracks

A future export option may allow selected tracks to be included.

Example:

```text
Export tracks: V1 + V2
```

In this mode, the export plan should collect Cuts from the selected tracks and sort them into one ordered list.

Recommended ordering rule:

```text
1. Earlier timeline start frame comes first.
2. If two Cuts start at the same frame, lower track number comes first.
   Example: V1 before V2, V2 before V3.
3. If still tied, preserve original project order.
```

Example:

```text
V1: Cut A at 0f, Cut B at 24f
V2: Cut X at 12f
```

Selected Tracks export result:

```text
001 Cut A
002 Cut X
003 Cut B
```

This mode should not be implemented until timeline placement, Cut timing, and project-level track behavior are stable.

## Future export mode: Composite Output

A later export mode may follow professional video-editing compositing behavior.

In a composite-style output:

```text
higher video tracks override lower video tracks
```

Example:

```text
V2 appears above V1 at the same time range
=> V2 has output priority
```

This may be useful for preview/movie-style output, but it is not the safest default for storyboard sheets.

Storyboard sheets are usually about readable Cut order, not only final visible composited output.

Therefore:

```text
Composite Output should be a later optional export mode.
It should not be the default storyboard sheet export mode.
```

## StoryboardExportPlan

Long term, export should be generated through a separate planning layer.

Suggested concept:

```text
Project
  -> StoryboardExportPlan
    -> pages / rows / panels / PDF / image export
```

`StoryboardExportPlan` should be derived from the current Project data.

It should not mutate the Project.

It should not rewrite Project.tracks or Cut order.

It should not create a new storyboard data model.

The Project remains the editing state.

The export plan is only a temporary output plan.

Conceptually:

```text
Project.tracks
= editing structure

StoryboardExportPlan
= output structure
```

## Recommended initial export behavior

The first storyboard export implementation should use:

```text
Export mode: Primary Track
Primary track: V1
Output order: Cut order in V1
```

It should ignore V2/V3 by default.

It should be simple, predictable, and close to traditional storyboard sheet behavior.

## Cut numbering in export

Export numbering should be calculated at export time.

It should not require changing Cut names.

Example project data:

```text
V1: Opening, Action, Reaction
```

Export result:

```text
001 Opening
002 Action
003 Reaction
```

If a future Selected Tracks export includes V2:

```text
V1: Opening at 0f, Reaction at 48f
V2: Insert at 24f
```

Export result:

```text
001 Opening
002 Insert
003 Reaction
```

The numbering belongs to the export plan, not necessarily to the underlying Cut model.

## Relationship with Storyboard Panel

The Storyboard Panel should remain a multi-track timeline view.

It may show:

```text
V1
V2
V3
```

with Cut blocks placed on each track.

Storyboard Export should flatten that view into a readable sequence according to the selected export mode.

Do not force the Storyboard Panel itself to become a single-track view just because storyboard sheets are single-order output.

The panel and export serve different purposes:

```text
Panel:
  editing, planning, comparing, arranging

Export:
  readable storyboard sheet output
```

## Early implementation warning

Do not implement export logic during the first Storyboard Panel shell phases.

The early Storyboard Panel phases should focus on:

* showing the panel
* showing V-style tracks
* showing Cut blocks
* showing Storyboard Layer presence inside Cut blocks

Export should come later, after the panel model and timeline behavior are stable.

## Policy summary

Long-term policy:

```text
1. Storyboard Panel is multi-track.
2. Storyboard Export is flattened.
3. Default export uses V1 / Primary Track only.
4. Selected Tracks export may be added later.
5. Composite Output may be added much later as an optional mode.
6. Export order should be calculated in StoryboardExportPlan.
7. Export should not mutate Project data.
8. Cut numbering for export should be generated at export time.
```

## Design target

The final Storyboard Panel should feel closer to a professional editing timeline than to a simple storyboard grid.

It should support the workflow:

```text
View project/cut structure
See cut lengths
See storyboard presence inside each cut
Navigate cuts visually
Eventually edit storyboard exposure timing
Eventually edit storyboard notes
```

The panel should visually and logically connect:

```text
Project timeline
Cut blocks
Storyboard layer content
Frame/storyboard metadata
```

without breaking the existing core hierarchy:

```text
Project -> Track -> Cut -> Layer -> Frame
```
