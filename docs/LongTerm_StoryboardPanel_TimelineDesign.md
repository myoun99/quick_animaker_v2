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
