# Current Project Architecture

QuickAnimaker v2 is a Flutter/Dart bitmap-first 2D animation production tool inspired by TVPaint, Clip Studio Paint, Photoshop, OpenToonz, and Flash-style workflows.

## Core hierarchy

The protected domain hierarchy is:

```text
Project
  -> Track
    -> Cut
      -> Layer
        -> Frame
          -> Stroke
```

Rules:

- `Project` owns metadata, FPS, created date, global project settings, and tracks.
- `Track` owns ordered cuts and represents project-level video/audio lanes.
- `Cut` owns layers, duration, and its own canvas size.
- `Layer` owns frames, visibility, opacity, kind, and future group/mask/blend features.
- `Frame` owns identity, timing, exposure metadata, and lightweight stroke metadata. Heavy bitmap payloads belong in external drawing stores.
- `Stroke` records a user drawing action or metadata snapshot, including frozen brush settings.

## Cross-module principles

- Bitmap-first drawing is the core direction; vector data may exist only as future or temporary metadata.
- UI widgets must not own domain logic. Pure Dart models/services should remain testable without Flutter UI.
- Core models should stay immutable and use copy-style updates.
- Avoid god objects such as giant project, renderer, canvas, cache, history, or persistence managers.
- Separate authored data, rendered caches, UI viewport state, and persistence format concerns.
- Module-specific source-of-truth rules live in the relevant `Current_*` document.

## Current module references

- Brush policy: `docs/Current_Brush_Architecture.md`.
- Timeline policy: `docs/Current_Timeline_Architecture.md`.
- Canvas/cache/storage policy: `docs/Current_Canvas_Cache_Storage_Architecture.md`.
- Storyboard policy: `docs/Current_Storyboard_Architecture.md`.
- Roadmap policy: `docs/Current_Implementation_Roadmap.md`.
