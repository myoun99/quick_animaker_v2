# Long-Term Design Memo - Timesheet-Oriented Layer Sections

## Purpose

This memo records long-term direction for QuickAnimaker's layer, timeline, and future timesheet structure.

The goal is to support a TVPaint-style drawing workflow while also allowing a future vertical Japanese animation timesheet view similar to A1 Pictures sheets and Toei Digital Timesheet layouts.

This is a long-term design note.

Do not implement all of this immediately.

## Reference Direction

Traditional Japanese animation timesheets often organize information into areas such as:

* ACTION / key animation direction
* SOUND / dialogue / SE
* CELL / drawing exposure
* CAMERA / camera direction

QuickAnimaker should eventually support a similar conceptual structure when switching to a vertical timesheet view.

The system does not need to copy paper sheets exactly, but the data structure should not block a timesheet-like layout.

## Final Section Direction

QuickAnimaker should eventually use three major timeline sections:

1. Camera Section
2. Sound Section
3. Main Section

Important visual stacking rule:

From top to bottom in the horizontal timeline UI:

1. Camera Section
2. Sound Section
3. Main Section

From bottom to top:

1. Main Section
2. Sound Section
3. Camera Section

This bottom-to-top order is intentional.

The Main Section should stay at the bottom because it is the primary drawing/cel area.

Sound and camera information should sit above it, closer to how timing sheets separate sound/camera instructions from cel drawing work.

## Horizontal Timeline Section Layout

Future horizontal timeline layout should roughly be:

Camera Section

* Camera Control Layer
* Camera Direction Layer: PAN
* Camera Direction Layer: BOOK
* Camera Direction Layer: BG

Sound Section

* Dialogue Layer
* SE Layer
* Sound Note Layer

Main Section

* Animation Layer
* Storyboard Layer
* Animation Layer
* Rough Layer
* Guide Layer

This means the visible UI order is:

top:
Camera
Sound
Main
bottom

Or described from the bottom:

bottom:
Main
Sound
Camera
top

## Vertical Timesheet View Direction

In a future vertical timesheet mode, the same conceptual sections can be remapped into a timesheet-like layout.

A rough mapping:

Main Section

* maps to ACTION / CELL related areas
* contains animation and storyboard drawing layers

Sound Section

* maps to SOUND / dialogue / SE areas

Camera Section

* maps to CAMERA / shooting instruction areas

The horizontal timeline's section stack should not force the vertical timesheet to use the same visual direction.

Instead, the system should use an orientation-specific display adapter.

Example:

Horizontal timeline:
Camera Section
Sound Section
Main Section

Vertical timesheet:
ACTION / SOUND / CELL / CAMERA style columns

The internal data order should not be blindly treated as the visual order.

## Data Order vs Display Order

The project must distinguish these concepts:

* data model order
* compositing order
* horizontal timeline display order
* vertical timesheet display order
* insertion order for new layers

These must not be accidentally treated as the same thing.

A layer appearing visually higher in the horizontal timeline should not automatically mean the data list must be stored in the same top-to-bottom order unless that policy is explicitly defined.

A layer appearing further left in a vertical timesheet should not automatically mean it is earlier or lower in the compositing stack.

Recommended architecture:

* Store a clear logical layer order.
* Use display adapters to convert logical order into horizontal UI order.
* Use a separate display adapter to convert logical order into vertical timesheet columns.
* Do not hard-code one UI orientation as the source of truth.

## Layer Insertion Direction

In the horizontal timeline UI, creating a new layer should add it above the current target layer or above the current section's active layer area.

The user expectation is:

* new layer appears above, not below
* layer stack feels like drawing software
* upper layers visually sit above lower layers

If no active layer exists, a new Main Section layer should be inserted at the top of the Main Section.

This should be implemented deliberately.

Do not rely on list append behavior if it makes new layers appear below existing layers.

## Main Section

The Main Section contains drawable visual layers.

This section includes:

* Animation Layer
* Storyboard Layer
* Rough Layer
* Guide Layer

Important:

Storyboard Layer should stay in the same visual/main layer area as animation layers.

Storyboard Layer should not be separated into a completely different section.

Reason:

Users may want to place animation layers above or below the storyboard layer while drawing.

Example:

Main Section:

* Animation Layer A
* Storyboard Layer
* Animation Layer B
* Rough Layer
* Guide Layer

This gives more flexibility during drawing and layout work.

## Storyboard Layer Rule

A Cut should have at most one Storyboard Layer.

Storyboard Layer is represented as:

LayerKind.storyboard

Storyboard Layer is still a normal Layer.

It uses the existing:

* Layer
* Frame
* Stroke

structure.

It can also use:

* Frame.storyboardMetadata

    * actionMemo
    * dialogueMemo
    * note

Storyboard Layer should not be modeled as:

Cut.storyboardLayer.panels

## Sound Section

The Sound Section contains sound/timing-related information.

Possible future layer types:

* Dialogue Layer
* SE Layer
* Sound Note Layer

The Sound Section should sit above the Main Section and below the Camera Section in the horizontal timeline.

In future vertical timesheet mode, it should map naturally to the SOUND area of Japanese animation sheets.

Sound layers may be multiple.

Do not hard-code only one SE layer too early.

Recommended long-term rule:

* Sound layers may be multiple.
* A default project/cut may start with no sound layer or one optional sound layer.
* UI can add sound layers later.

Do not implement sound layers yet unless a specific phase requests it.

## Camera Section

The Camera Section should sit above the Sound Section.

Camera information should be split into at least two concepts:

1. Camera Control Layer
2. Camera Direction Layer

## Camera Control Layer

This is for actual camera manipulation.

Examples:

* pan
* zoom
* follow
* camera shake
* camera transform
* camera keyframes

This layer is functional and affects rendering/camera behavior in the future.

There should normally be a limited number of camera control layers, possibly only one main camera control layer at first.

## Camera Direction Layer

This is for written camera instructions on the timesheet.

Examples:

* PAN
* TU
* TB
* BOOK
* BG
* follow note
* shooting note
* camera instruction memo

This layer is text/instruction-oriented.

It does not directly control the render camera.

A Camera Direction Layer's name should be usable as the column/header name in a future timesheet view.

Example:

If the camera direction layer name is:

PAN

Then the timesheet column/header can show:

PAN

Camera Direction Layers may be multiple.

Reason:

Real animation sheets may have more than one camera/shooting instruction column or need multiple camera-related note lanes.

## Layer Type Icon Direction

Layer labels should eventually show a type icon at the far left.

Possible icons:

* Animation Layer: drawing/brush/cel icon
* Storyboard Layer: storyboard/book/panel icon
* Sound Layer: sound/note icon
* Camera Control Layer: camera icon
* Camera Direction Layer: camera note/direction icon

This should be implemented in a later UI phase.

Do not implement this together with core model changes unless explicitly requested.

## Layer Naming Direction

Animation/Main Section layers should use Japanese cel-style naming.

Default names:

* A
* B
* C
* ...
* Z
* AA
* AB
* AC
* ...

Layer naming should be Cut-local.

Example:

Cut 1:

* A
* B
* C

Cut 2:

* A
* B
* C

Creating layers in Cut 2 should not continue from Cut 1.

Wrong:

Cut 1 has A, B, C, D, E.
Cut 2 creates F.

Correct:

Cut 1 has A, B, C, D, E.
Cut 2 creates A.

If a layer name is missing inside a Cut, the next created layer should preferably use the smallest available cel name.

Example:

Existing layers:

* A
* B
* D

Next new layer:

* C

## Initial Exposure Direction

New Cuts and new Layers should start with a predictable default exposure.

Required future rule:

* frame index 1 should start as x

Meaning:

* x = blank exposure / no drawing / empty cell

Avoid automatic frame names such as:

* C2

New Cuts should not start with no exposure.

New Layers should not start with no exposure.

Default should be:

Layer A
index 1 = x

This should make the timeline easier to understand and closer to animation sheet expectations.

## Implementation Priority

Recommended upcoming phases:

### Phase 74

Layer Defaults and Storyboard Layer Rule Correction

Scope:

* Cut may have at most one Storyboard Layer.
* Layer name generation becomes Cut-local.
* Layer default names become A, B, C... AA, AB...
* New Cut default Layer name becomes A.
* New Layer default exposure starts with index 1 = x.
* Remove automatic C2-style default frame naming.
* New layer insertion should be defined as above current/target layer, not appended below by accident.
* Do not add sound/camera sections yet.
* Do not add type icons yet.

### Phase 75

Layer Type Icon UI

Scope:

* Show LayerKind icon at the left side of layer label.
* Initially support animation/storyboard icons only.
* Do not add sound/camera layer kinds yet unless specifically scoped.

### Later Phase

Timeline Section Planning

Scope:

* Camera Section
* Sound Section
* Main Section
* Horizontal section display order:

    * top: Camera
    * middle: Sound
    * bottom: Main
* Vertical timesheet mapping:

    * ACTION / SOUND / CELL / CAMERA style layout
* No implementation until layer kind/default behavior is stable.

### Later Phase

Sound and Camera Layer Models

Possible future LayerKind or TrackKind additions:

* sound
* cameraControl
* cameraDirection

Do not add these too early.

## Current Decision Summary

Current accepted direction:

* Horizontal timeline should eventually display sections from top to bottom:

    * Camera Section
    * Sound Section
    * Main Section
* Described from bottom to top:

    * Main Section
    * Sound Section
    * Camera Section
* Main visual layer area contains both Animation Layers and Storyboard Layer.
* Storyboard Layer is a normal drawable Layer.
* Cut should have at most one Storyboard Layer.
* Sound and Camera should eventually be separate sections.
* Camera should distinguish between actual camera-control data and camera-direction memo layers.
* Camera Direction Layers may be multiple.
* Layer type icons should eventually appear on the left side of layer labels.
* Layer names should use A/B/C style and reset per Cut.
* New layers in horizontal timeline should be inserted above the current/target layer or at the top of the current section.
* New Cut/New Layer should start with frame index 1 = x.
