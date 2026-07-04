# Phase 304 Codex Task — Brush Tool Mode Foundation and Eraser

## Context

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool.

Current active work remains the brush/canvas editing part.

Phase 303 introduced:

- reusable editor panel primitives
- right-side EditorPanelDock
- BrushSettingsPanel
- BrushToolState with size, opacity, color, and spacing
- active stroke input setting snapshot at pointer down
- brush settings as editor-session UI/tool state, not source project data

The next step is to continue the brush finishing part by adding the first tool-mode foundation and an eraser.

The user’s preferred high-level part order is:

1. Brush finishing
2. Panel system expansion
3. Canvas / cache / storage foundation
4. Camera T1
5. Playback / cache
6. Timeline
7. Storyboard
8. Layer / save-load and other larger systems later

This phase belongs to part 1: Brush finishing.

## Goal

Add a production-safe foundation for tool modes and implement the first eraser tool.

This must be done as a long-term architecture step, not as a temporary “paint white” shortcut.

The eraser should be a proper source operation that can be undone/redone and replayed in drawing order.

## Core requirements

### 1. Add editor tool mode state

Add an editor-session tool mode concept.

Recommended enum:

- `EditorToolMode.brush`
- `EditorToolMode.eraser`

Equivalent naming is acceptable if it fits the project better.

Rules:

- Tool mode is editor-session UI state.
- Tool mode is owned by HomePage or the focused editor session boundary.
- Tool mode is not Project / Cut / Layer / Frame source metadata.
- Do not add Provider, Riverpod, Bloc, ChangeNotifier, global singleton state, or broad app-wide state management.
- Tool mode should be snapshotted at pointer down, like BrushToolState input settings.

### 2. Add a compact left tool palette foundation

Add the first compact left-side tool palette.

Recommended files:

- `lib/src/ui/tools/editor_tool_mode.dart`
- `lib/src/ui/tools/editor_tool_palette.dart`

Equivalent paths are acceptable if they fit the project structure.

The palette should:

- appear on the left side of the main editor workspace
- provide Brush and Eraser buttons
- use compact production-style UI
- show selected tool state clearly
- use tooltips
- avoid tutorial-like long text
- not become a full docking framework
- not implement workspace persistence
- not implement floating panels or drag-to-dock

This is the first tool palette foundation only.

### 3. Connect tool mode to drawing input

Extend the brush input path so each active stroke knows whether it is a paint stroke or an erase stroke.

Rules:

- Snapshot active tool mode at pointer down.
- Changing selected tool while a stroke is active must affect future strokes only.
- The current active stroke must continue using its pointer-down tool mode.
- Brush settings snapshot should continue to work.
- Eraser uses relevant brush size and spacing.
- Eraser may ignore color and opacity if appropriate, but the data model should remain future-safe.

### 4. Represent eraser as source operation, not destructive deletion

Do not implement eraser by deleting previous source dabs.

Do not implement eraser by painting white.

The eraser stroke should be represented as a source operation that participates in drawing order.

Possible design directions:

- Add a source operation enum to `BrushPaintCommand`, such as `paint` / `erase`.
- Or add an equivalent source-level stroke operation type.
- Keep `BrushDab` as materialized dab geometry if that is cleaner, but the renderer must still know whether the stroke/command is paint or erase.
- Preserve existing source commands; eraser should not mutate or remove old paint commands.
- Undoing an eraser stroke should hide the eraser command and reveal the earlier paint result again.
- Redoing the eraser stroke should apply the eraser operation again.

Choose the smallest long-term-safe implementation that preserves future save/load compatibility.

### 5. Render eraser in the active canvas display

The active editor display should render paint and erase commands in order.

Rules:

- Existing paint commands should still display normally.
- Erase commands should visually erase previous marks in the affected area.
- Rendering order matters.
- Do not flatten committed source dabs in a way that loses erase operation order.
- Avoid live bitmap baking in the editing hot path.
- Keep current source-dab active display direction.
- Keep performance lightweight.

If Flutter canvas blending is used, use a local layer only where necessary and avoid broad expensive redraw architecture changes.

### 6. Preserve undo/redo behavior

Brush and eraser strokes must both participate in the existing app-level undo/redo flow.

Preserve:

- `HistoryManager`
- `BrushStrokeHistoryCommand`
- `BrushFrameEditingCoordinator`
- `BrushFrameStore.hiddenCommandIds`
- global undo/redo only
- no brush-local undo/redo buttons

Undoing an eraser stroke must not delete source data. It should hide/restore the eraser command through the existing command visibility model.

### 7. Preserve existing Phase 303 behavior

Keep:

- right-side BrushSettingsPanel
- EditorPanelFrame / Header / Body / Dock
- BrushToolState size / opacity / color / spacing
- active input settings snapshot
- canvas viewport pan / zoom / fit / reset
- panbars
- Cut.canvasSize clipping
- no source/save-load schema work
- no playback/cache implementation

### 8. Documentation updates

Update:

- `docs/Current_Brush_Architecture.md`
- `docs/Current_UI_Product_Policy.md`
- `docs/Current_Project_Architecture.md` if source-operation boundary changes
- `docs/Current_Implementation_Roadmap.md`
- `docs/Handoff_QuickAnimaker_v2_Current.md` section 5 or later only

Do not edit Handoff sections 0 through 4.

Document:

- user’s preferred high-level part order
- Phase 304 adds editor tool mode foundation
- Brush and Eraser are editor-session selected tools
- eraser is a source operation, not destructive deletion and not white paint
- active strokes snapshot tool mode at pointer down
- eraser participates in global undo/redo through the same brush command visibility model
- save/load remains later, but the source operation model must not block future save/load

## Required tests

Add or update tests for:

### Tool mode state

- default selected tool is Brush
- selecting Eraser updates editor-session tool mode
- selecting Brush again updates editor-session tool mode
- tool mode is not stored in Project / Cut / Layer / Frame JSON or source metadata

### Tool palette

- left tool palette renders Brush and Eraser buttons
- selected tool is visually indicated
- no long tutorial/debug text appears
- no Provider / Riverpod / Bloc / ChangeNotifier is introduced

### Brush / eraser input

- brush stroke creates a paint source operation
- eraser stroke creates an erase source operation
- eraser stroke uses size and spacing for sampling
- changing tool mode mid-stroke affects future strokes only
- changing brush settings mid-stroke still uses the pointer-down snapshot

### Rendering

- paint stroke appears
- eraser stroke visually removes/clears the relevant area after paint
- paint after eraser appears again in later drawing order
- rendering preserves source command order

### Undo/redo

- undo paint stroke hides paint
- undo eraser stroke restores the previously painted appearance
- redo eraser stroke erases again
- undo/redo remains global and does not add brush-local undo controls

### Regression

- pan / zoom / fit / reset still work
- panbars still work
- Cut.canvasSize clipping still works
- existing brush settings panel still works
- existing source dab tests still pass

## Non-goals

Do not implement:

- brush presets
- pressure
- smoothing
- flow UI
- hardness UI
- roundness
- angle
- texture
- dual brush
- color picker dialog
- bucket fill
- lasso / selection
- hand tool
- full docking framework
- workspace persistence
- save/load
- playback
- playback cache
- cache baking
- Camera T1
- layer panel
- layer blend modes
- layer masks
- PSD import/export
- Provider
- Riverpod
- Bloc
- ChangeNotifier

## Validation

Run:

- `dart format lib test docs`
- `dart format --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`

If any command cannot run, report it clearly.

## PR requirements

Create a PR from master.

PR title:

`Phase 304: Add brush tool mode and eraser foundation`

PR description must mention:

- adds editor tool mode foundation
- adds compact left tool palette with Brush and Eraser
- implements eraser as a source operation, not white paint or destructive deletion
- snapshots tool mode at pointer down
- keeps BrushSettingsPanel as the primary brush settings UI
- preserves global undo/redo behavior
- preserves source/cache/save-load boundaries
- does not add broad state management