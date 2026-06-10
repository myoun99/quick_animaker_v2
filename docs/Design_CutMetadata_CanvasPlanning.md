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

Phase 64 corrects the scope of `CutMetadata`:

* `CutMetadata` is Cut-level metadata only.
* `CutMetadata` contains only `note`.
* `actionMemo` and `dialogueMemo` are not Cut-level metadata.
* `actionMemo` and `dialogueMemo` belong to future StoryboardPanel / ContePanel data because they can vary per storyboard panel.
* Legacy JSON containing `actionMemo` or `dialogueMemo` may be read for compatibility, but those fields are ignored by `CutMetadata`.

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

## Corrected implementation decision

Phase 63 introduced `CutMetadata` with `actionMemo`, `dialogueMemo`, and `note`.

Phase 64 corrects that model:

* `CutMetadata` keeps only `note`.
* `CutMetadata.empty()` defaults `note` to `''`.
* `CutMetadata.copyWith` supports `note` only.
* `CutMetadata` equality, `hashCode`, and JSON serialization use `note` only.
* `CutMetadata.fromJson` reads `note`, defaults a missing `note` to `''`, and safely ignores legacy `actionMemo` / `dialogueMemo` fields.

Phase 64 should not add UI.

Phase 64 should not add Conte Panel.

Phase 64 should not add Storyboard Panel.

Phase 64 should not add Cut canvas settings yet.

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

Current corrected structure:

class CutMetadata {
final String note;
}

Future StoryboardPanel / ContePanel data may later define panel-level action and dialogue fields, but those fields should not be added back to `CutMetadata`.

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
* Phase 64: CutMetadata scope correction to note-only Cut-level metadata
* Phase 65 or later: future Cut metadata UI or inspector preparation, if still needed
* Phase 66 or later: Cut visual / storyboard data planning
* Phase 67 or later: Cut canvas settings model planning
* Later: drawable area and tile-backed bitmap planning
* Later: camera/framing transform planning
* Much later: full Conte / Storyboard Panel

## Current decision

After Phase 64, proceed with `CutMetadata` as Cut-level metadata only.

Fields:

* note

Do not add `actionMemo` or `dialogueMemo` back to `CutMetadata`; those belong to future StoryboardPanel / ContePanel data.

Out of scope for this corrected metadata foundation:

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
* tile engine
* project camera changes

This document should be used as a stable reference in later chats if context becomes heavy.
