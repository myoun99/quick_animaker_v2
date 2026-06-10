# Design Note - Cut Metadata and Cut Canvas Planning

This document records the agreed direction for future Cut metadata, storyboard/conte information, per-Cut canvas sizing, and drawable area planning in QuickAnimaker v2.

This document is a design memory / decision note.

It is not an implementation task by itself.

## Current project context

QuickAnimaker v2 is a Flutter / Dart bitmap animation tool inspired by TVPaint-style workflows, but adapted for practical Japanese animation production needs.

Recent completed phases:

* Phase 58: Cut reorder command foundation
* Phase 59: Move Cut Left / Move Cut Right UI
* Phase 60: Cut reorder planner extraction
* Phase 61: Cut list drag reorder MVP
* Phase 62: Cut drag reorder hardening

The current Cut list now supports:

* creating Cuts
* renaming Cuts
* duplicating Cuts
* deleting Cuts
* moving Cuts left/right
* dragging Cuts to reorder
* undo/redo for Cut reorder
* active Cut retention after reorder

The next major direction is preparing for future Conte / Storyboard workflows.

However, the full Conte Panel should not be implemented yet.

## Important long-term design decision

A Cut should eventually be treated not only as a timeline segment, but also as a production unit.

A Cut may need:

* storyboard/conte text information
* production notes
* per-Cut canvas settings
* drawable working area settings
* later, camera/framing data

These concepts should be introduced gradually and safely.

## Cut metadata direction

The first metadata foundation should be text-based and low-risk.

The agreed initial metadata fields are:

* actionMemo
* dialogueMemo
* note

These fields correspond to common conte/storyboard needs.

### actionMemo

`actionMemo` represents the action or movement memo for the Cut.

Examples:

* Character A runs in from screen right.
* Character turns toward camera.
* Explosion causes hair and clothes to move.
* Camera shakes after impact.
* TU from full body to face.

This field should be used for animation/action/staging descriptions.

### dialogueMemo

`dialogueMemo` represents dialogue, voice, or spoken-line notes for the Cut.

Examples:

* A: "Wait!"
* B: "It is already too late."
* Monologue line.
* Timing-related dialogue note.
* Lip-sync reference note.

This field should not be mixed with general production notes unless necessary.

### note

`note` represents general free-form notes for the Cut.

Examples:

* Sakkan attention needed.
* FX-heavy Cut.
* Background separate order.
* 3D reference required.
* Retake: fix expression.
* Ask director about camera timing.

This is a general-purpose memo field.

## Initial implementation decision

Phase 63 should introduce only:

* CutMetadata value object
* actionMemo
* dialogueMemo
* note
* default empty metadata
* equality / copyWith support as appropriate
* tests

Phase 63 should not add UI.

Phase 63 should not add Conte Panel.

Phase 63 should not add Storyboard Panel.

Phase 63 should not add save/load schema changes unless the project already requires model serialization changes for tests.

Phase 63 should not add Cut canvas settings yet.

## Future production metadata candidates

Later, additional production management fields may be considered:

* status
* priority
* assignee
* dueDate
* retakeCount
* checkedBy
* lastReviewedAt

Possible status values:

* todo
* inProgress
* done
* retake
* hold

These are not part of Phase 63.

These should be added only when there is a clear UI or workflow need.

## Per-Cut canvas size direction

A major long-term design direction is that each Cut should eventually be able to have its own canvas size.

This is important because Japanese animation production often requires different working canvas sizes per Cut.

Examples:

* normal Cut
* TU
* TB
* horizontal PAN
* vertical PAN
* oversized layout
* follow camera
* camera shake margin
* BOOK / multi-plane style needs

A project-wide canvas size alone is not enough for practical production.

## Separate camera size from Cut canvas size

The following concepts must remain separate:

* Project camera size
* Cut canvas size
* Cut drawable area
* Cut camera/framing transform

### Project camera size

The Project camera size is the final output frame or common camera frame.

Example:

* 1920 x 1080
* 3840 x 2160

This should be common across the Project.

The camera frame represents the final visible render/export area.

### Cut canvas size

The Cut canvas size is the working canvas for that specific Cut.

Examples:

* Cut 001: 1920 x 1080
* Cut 002: 2880 x 1620 for TB
* Cut 003: 3840 x 1080 for horizontal PAN
* Cut 004: 1080 x 3000 for vertical PAN

This should eventually be configurable per Cut.

This should not be implemented in Phase 63.

### Cut drawable area

The drawable area is the region where the bitmap drawing system allows drawing.

This is separate from the visible camera frame and may be larger than the Cut canvas.

The long-term idea is to avoid truly infinite bitmap canvas at first because bitmap data can become too large.

Instead, QuickAnimaker may use a bounded drawable area.

Initial design idea:

* drawable area defaults to 3.0 times the Cut canvas size
* user can customize this scale later
* actual stored bitmap data should eventually be tile-based
* empty/unpainted areas should not be fully allocated

Example:

Project camera size:

* 1920 x 1080

Cut canvas size:

* 1920 x 1080

Drawable area scale:

* 3.0

Drawable area:

* 5760 x 3240

For a horizontal PAN Cut:

Cut canvas size:

* 3840 x 1080

Drawable area scale:

* 3.0

Drawable area:

* 11520 x 3240

Important:

The drawable area is a permitted working boundary.

It should not imply allocating one huge bitmap immediately.

A future tile engine should store only dirty / painted tiles.

## Future model direction

Possible future structure:

class Cut {
final CutId id;
final String name;
final int duration;
final List<Layer> layers;
final CutMetadata metadata;
final CutCanvasSettings canvasSettings;
}

Initial Phase 63 should add only CutMetadata.

Possible future structure:

class CutMetadata {
final String actionMemo;
final String dialogueMemo;
final String note;
}

Possible future structure:

class CutCanvasSettings {
final CanvasSize canvasSize;
final DrawableAreaSettings drawableArea;
final CameraFraming cameraFraming;
}

Possible future structure:

class DrawableAreaSettings {
final double scaleX;
final double scaleY;
}

Or initially:

class DrawableAreaSettings {
final double scale;
}

Default value may be:

* scale = 3.0

Possible future structure:

class CameraFraming {
final double translateX;
final double translateY;
final double scale;
}

Camera/framing should be introduced later, not now.

## Important architectural warning

Per-Cut canvas size and drawable area affect many systems:

* CanvasController
* CanvasView
* Stroke coordinate system
* Layer bitmap size
* Frame data
* Renderer
* Cache
* Save/load
* Undo/redo
* Timeline preview
* Export
* Camera view
* Tile engine

Therefore, per-Cut canvas size and drawable area must not be added casually.

They should be introduced only after the model, coordinate system, renderer, and persistence plans are ready.

## Suggested future phase order

Recommended near-term order:

* Phase 63: CutMetadata foundation
* Phase 64: CutMetadata command foundation
* Phase 65: very small Cut metadata UI or inspector preparation
* Phase 66: Cut visual / storyboard data planning
* Phase 67 or later: Cut canvas settings model planning
* Later: drawable area and tile-backed bitmap planning
* Later: camera/framing transform planning
* Much later: full Conte / Storyboard Panel

## Current decision

Proceed with Phase 63 as:

CutMetadata foundation only.

Fields:

* actionMemo
* dialogueMemo
* note

Out of scope for Phase 63:

* UI
* Conte Panel
* Storyboard Panel
* Cut status
* Cut assignee
* Cut due date
* Cut canvas size
* drawable area
* camera framing
* renderer changes
* save/load schema changes unless unavoidable
* tile engine
* project camera changes

This document should be used as a stable reference in later chats if context becomes heavy.
