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
