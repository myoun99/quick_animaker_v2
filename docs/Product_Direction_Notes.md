# Product Direction Notes

## Current Product Direction

QuickAnimaker v2.1 is intended to become a professional bitmap-based 2D animation production tool inspired by:

- TVPaint
- Clip Studio Paint
- Photoshop / PSD-style layer workflows

The product direction is a practical production workflow for frame-by-frame animation. It is not intended to become a toy drawing app, a beginner-only tutorial interface, or a UI that explains every action with long instructional text.

The product should continue moving toward:

- Bitmap-first drawing and animation.
- Timeline and X-sheet style exposure editing.
- Production-tool-like controls and compact feedback.
- Layer workflows that can eventually support more advanced PSD-like behavior.
- Cut-based production structure after the current single-cut workflow is stable.

## Timeline Editing Direction

Timeline and X-sheet style editing are central to the product.

Current timeline policies:

- Timeline cells may contain drawing exposure, blank/X exposure, marks, or empty/held positions depending on the current authored timeline entries.
- `○` means an unnamed drawing frame head.
- A frame name means a named drawing frame head.
- `X` means a blank/null exposure head.
- `●` means a timeline mark, inbetween mark, or timesheet mark.
- Exposure duration belongs to the selected authored timeline entry, not to the `FrameId` globally.
- `+ Exposure` and `- Exposure` operate on the selected authored timeline entry, not every use of the same `FrameId`.

This means timeline placement and timing should remain local to the authored exposure entry being edited. A linked drawing material may appear in more than one place, but changing exposure duration in one place must not implicitly change every linked use.

## Frame Material Identity

Same frame name means same material.

Within the same layer, duplicate independent `FrameId`s with the same non-empty frame name should not be allowed as the long-term product policy. If two different materials can carry the same name in the same layer, the meaning of linked frames becomes ambiguous.

Current material identity rules:

- Frame identity and drawing material identity are currently represented by `FrameId`.
- When two timeline references point to the same `FrameId`, they are linked uses of the same drawing material.
- A non-empty frame name is treated as a material identity label inside its layer.
- Same-layer duplicate independent `FrameId`s with the same non-empty name should be prevented or resolved by linking, not preserved as separate materials.

## Linked Frame Policy

Linked frames share material/source only.

Linked frames share:

- `FrameId`
- Drawing strokes / material
- Frame name

Linked frames do not share:

- Timeline placement
- Authored exposure duration
- Mark position
- Blank/X position
- Selected cell state

A linked frame is another use of the same drawing material, not a clone of every timeline decision around that material. Future work must preserve the distinction between shared material/source and independent timeline placement.

`+ Exposure` and `- Exposure` must operate on the selected authored timeline entry rather than mutating all uses of the same `FrameId`.

## Rename Conflict Policy

If a frame is renamed to a name already used by another `FrameId` in the same layer, the user gets Link / Cancel only.

Allowed options:

- Link
- Cancel

Intentionally not offered:

- Rename only
- Keep independent duplicate material with the same name

Reason:

- Same name means same material.
- Allowing same-layer duplicate independent `FrameId`s with the same non-empty name would make linked-frame and material identity behavior ambiguous.
- Rename-only would create or preserve that ambiguity, so it should not be offered.

## UI Direction

The UI should feel like a practical production tool.

Current UI direction:

- Avoid tutorial-like long hints.
- Prefer icon buttons with Tooltip labels.
- Keep status text compact.
- Use grouping and layout to make tools understandable instead of long explanatory text.
- Avoid adding visual noise.
- Keep timeline/cell action controls concise and production-tool-like.

Timeline-specific UI direction:

- Drawing exposure blocks should be visually calm.
- Drawing head and held drawing cells may share the same white or near-white base color.
- Blank/X head and held blank cells may share the same dark gray base color.
- Selected cell highlight must remain visible.

## Explicit Non-Goals for the Current Stage

The following should not be implemented in the current stage:

- Multiple Cut UI
- Cut switching UI
- Storyboard Panel
- Camera Layer
- Audio Layer
- Storyboard Layer
- Linked Layer
- Cross-layer linked paste
- Cross-cut linked paste
- Project-level material pool
- Global `FrameId` refactor
- Layer type enum
- Collapsible layer sections
- Timeline virtualization
- Advanced export

These are future directions or possible later architecture topics. They should not be introduced as side effects of current timeline, linked-frame, rename, or UI polish work.

## Future Ideas

The following are future ideas only and are not implemented yet:

- Multiple Cut structure
- Cut / Storyboard system
- Cut selection and switching UI
- Storyboard Panel MVP
- Storyboard Panel
- Animation Layer
- Camera Layer
- Audio Layer
- Storyboard Layer
- Linked Layer
- Cross-layer linked paste
- Cross-cut linked paste
- Cross-layer / cross-cut linked paste
- Project-level material pool

Future design should continue separating current behavior from proposed architecture. In particular, later linked-material, linked-layer, cross-layer paste, or cross-cut paste work must not accidentally make timeline placement shared unless that behavior has been explicitly designed and approved.
