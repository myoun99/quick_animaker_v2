# Current Timeline Architecture

## Status

Timeline stabilization completed around Phase 145. Avoid timeline refactors unless fixing a test-proven regression or implementing an explicitly planned phase.

## Component boundaries

`TimelinePanel` remains the public timeline entry point. Timeline components should stay small and compositional: grid layout, frame ruler/header, scroll viewports, layer controls, scrollbar rails, playhead, cut-end boundary, and selected exposure visuals each have focused responsibilities.

## Range semantics

Timeline range semantics must not drive canvas/cache/storage semantics. Keep playback/export duration, visible display range, virtualized rendering windows, authored data extent, selected exposure visuals, horizontal scrolling, and frame coordinate conversion separate.

- `Cut.duration` is playback/export duration only.
- `Cut.duration` must not limit data extent, editability, selected exposure outline, or visible range.
- Authored frames beyond `Cut.duration` can exist.
- Editing beyond `Cut.duration` must not auto-extend `Cut.duration`.
- Virtualized frame windows are rendering optimizations, not data or playback boundaries.
- Frame coordinate helpers should remain pure conversions and should not embed playback, authored extent, canvas/cache, or storage semantics.


## Cut-end boundary and visible tail policy

`Cut.duration` remains playback/export duration only. The cut end should be visualized as a cut-end boundary such as a red line or cut-end marker, not as deletion, storage validity, or authored data extent.

- Frames beyond `Cut.duration` may remain visible and editable.
- The post-cut area must not imply playback/export duration.
- Visible tail after the cut end should be finite and UI-controlled, not infinite eager rendering.
- Virtualized windows remain rendering optimizations only.
- Editing beyond `Cut.duration` must not automatically extend `Cut.duration`.
- If a future cut-end handle or duration drag is implemented, undo should be committed at drag end, not on every pointer-move frame.
- If a future left/head handle is added, treat it as head-position/timeline-placement policy; it must not silently mutate drawing material or unrelated timeline entries.

## Timesheet-oriented layer sections

Long-term timeline direction is inspired by traditional Japanese animation timesheets. This is architecture direction only; do not implement these future layer types in runtime code unless a future runtime phase explicitly asks for them.

Top-to-bottom horizontal timeline section order:

1. Camera Section
2. Sound Section
3. Main Section

Bottom-to-top reading order:

1. Main Section
2. Sound Section
3. Camera Section

This order matters.

- Main Section contains animation layers, storyboard layers, future rough layers, future guide layers, and ordinary drawable layers. Storyboard remains inside Main Section as an ordinary `Layer(kind: storyboard)`, and users should be able to place animation layers above and below storyboard layers.
- Sound Section may later contain dialogue layers, SE layers, and sound note layers corresponding to traditional SOUND/timesheet columns. Do not implement sound features now unless a future runtime phase explicitly asks for them.
- Sound/SE-related layers may be multiple in the future; do not hard-code Sound Section design around a single SE lane too early.
- Camera Section may later contain camera control layers and camera direction layers.
- Camera Control Layer is for actual render camera control such as pan, zoom, follow, shake, and camera keyframes.
- Camera Direction Layer is for written camera instructions on the sheet, such as PAN, BOOK, BG, TU, and TB. It may correspond to visible sheet headers/columns and must be distinguished from actual camera-control data.
- Camera Direction Layers may be multiple in the future; their layer names may become sheet headers/columns such as PAN, BOOK, BG, TU, or TB.

## Default layer naming and initial exposure

Layer names are display labels; `LayerId` is identity. Layer names may duplicate, and code must not infer identity or linking from a layer name.

Default animation layer names should use Japanese cel-style names per Cut, not globally across the project:

```txt
A, B, C, ... Z, AA, AB, AC, ...
```

When possible, generate the smallest available cel name within the Cut. For example, if existing layers are `A`, `B`, and `D`, the new default layer name should be `C`.

New Cuts and new Layers should not start with no exposure at all. They should begin at visible frame 1 with blank exposure `x`.

- `x` means blank exposure / no drawing / empty cell.
- Do not auto-create a drawn frame name such as `C2` at visible frame 1.
- This is a timeline/exposure default policy, not a brush payload creation policy.
- Blank exposure must not imply source drawing payload allocation.

## Layer kind icon direction

Timeline layer controls may show layer kind icons.

- Current layer kind meanings are `animation` for animation/drawing layers and `storyboard` for storyboard/conte layers.
- Preserve stable semantic keys such as `timeline-layer-kind-icon-<layerId>` when relevant.
- Future icons may represent sound, camera, rough, or guide layer kinds only after those layer kinds are explicitly planned.
- Do not implement new layer kinds or icons in this documentation task.

## Linked frame exposure and placement policy

Same frame name means same drawing material, and linked frames share drawing material/source identity. Linked frames do not share placement, exposure duration, timeline marks, blank/X positions, selected cell state, or other authored timeline entry state.

`+ Exposure` and `- Exposure` operate on the selected authored timeline entry, not every use of the same `FrameId`. Exposure duration belongs to the selected authored timeline entry, not to the `FrameId` globally.

Future timeline or rename work must not accidentally mutate every linked use of a `FrameId` when only placement, exposure, marks, or authored timeline entry state is being edited.

## Layer ordering

Layer ordering must keep raw model order separate from display order.

```txt
raw order [A, B, C]
horizontal display [C, B, A]
vertical XSheet [A, B, C]
```

New layer insertion is after the active raw layer. Layer names may duplicate; `LayerId` is identity.

## Storyboard interaction

Storyboard layers may be displayed in storyboard/conte surfaces, but storyboard behavior must not redefine timeline playback, authored extent, visible range, selected exposure semantics, or canvas/cache/storage semantics.
