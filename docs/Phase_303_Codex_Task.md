# Phase 303 Codex Task — Editor Panel Frame and Brush Settings Panel

## Context

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool.

The current active area is the brush/canvas editor.

Phase 302 introduced editor-session BrushToolState and a compact brush options bar. That phase established the important boundary that brush size, opacity, and color are editor-session tool state, not Project / Cut / Layer / Frame / Stroke source data.

The next step is to move from a temporary canvas-local brush options strip toward a long-term production UI layout inspired by Photoshop / Clip Studio Paint / TVPaint.

The user wants brush settings to live in a right-side vertical panel, like Photoshop-style panels. This must be implemented through a reusable panel frame structure, not as a one-off brush UI.

## Product direction

Target feeling:

- Photoshop / Clip Studio-like right-side settings panels
- reusable panel frames
- future panel reuse for Timeline, Layers, Color, Navigator, Storyboard, Brush Presets, etc.
- compact professional editor UI
- no debug-looking controls
- no one-off hardcoded panel styling per feature

The goal is not to implement a complete docking framework yet.

The goal is to establish the first long-term panel frame boundary and move brush settings into a right-side Brush Settings panel.

## Core goals

### 1. Add reusable editor panel frame components

Create reusable UI components for editor panels.

Recommended files:

- lib/src/ui/panels/editor_panel_frame.dart
- lib/src/ui/panels/editor_panel_header.dart
- lib/src/ui/panels/editor_panel_body.dart
- lib/src/ui/panels/editor_panel_dock.dart

Equivalent names are acceptable if they better match the project structure.

The panel frame should provide:

- consistent border
- consistent background
- title/header area
- body area
- compact padding
- stable sizing behavior
- no overflow at small sizes
- reusable structure for future panels

The header can include placeholder structure for future collapse/pin/close buttons, but do not implement actual docking/collapse behavior unless it stays minimal and tested.

Do not create a large docking framework.

Do not add drag-to-dock, floating panels, panel tabs, resizing, or workspace persistence in this phase.

### 2. Add a right-side editor panel dock

Add a right-side panel area to the main editor layout.

The dock should be able to host one or more panels vertically.

Initial panel:

- Brush Settings

Future panels should be able to reuse the same dock:

- Color
- Layers
- Navigator
- Brush Presets
- Tool Properties

The right dock should be editor UI state only.

Do not store panel layout in Project / Cut / Layer / Frame / Stroke.

Do not add save/load changes.

### 3. Replace canvas-local brush options bar with Brush Settings panel

Move brush setting controls from the canvas editor tool/options strip into a right-side Brush Settings panel.

Create:

- lib/src/ui/brush/brush_settings_panel.dart

The panel should use the reusable EditorPanelFrame.

The panel should control the existing editor-session BrushToolState.

It should include:

- brush size
- opacity
- color swatches
- current setting display
- spacing

The old BrushToolOptionsBar may be removed, renamed, or reduced to a small read-only summary if needed.

Preferred direction:

- BrushSettingsPanel is the primary control UI.
- Canvas panel should stay focused on canvas viewport, title/status, panbars, zoom/fit/reset.
- Do not keep duplicate editable brush controls in both canvas and right panel.

### 4. Extend BrushToolState with spacing

Add spacing to BrushToolState.

Spacing should be Photoshop-style in concept.

Recommended representation:

- spacing as a ratio, where 0.25 means 25% of brush size
- default spacing: 0.25
- min spacing: 0.05
- max spacing: 4.0

Equivalent values are acceptable if justified, but keep them safe.

Rules:

- spacing must always be finite and clamped
- public BrushToolState constructor must store valid spacing
- copyWith must clamp spacing
- toInputSettings or equivalent brush input conversion must carry spacing to the input layer
- spacing remains editor-session tool state
- spacing is not Project / Cut / Layer / Frame / Stroke source data
- spacing is not save/load data

Committed source dabs should continue to carry the materialized values needed to render the stroke that was actually drawn.

Changing spacing must affect future strokes only.

Changing spacing must not rewrite existing strokes.

### 5. Connect spacing to brush input sampling

Spacing must affect dab generation.

The intended model:

- effective spacing in pixels is based on brush size times spacing ratio
- smaller spacing creates denser dabs
- larger spacing creates wider gaps
- spacing must be clamped to avoid excessive dab generation
- spacing must not make the editor freeze or generate unbounded dabs

Example concept:

- size 20px, spacing 0.25 -> dab interval about 5px
- size 20px, spacing 1.0 -> dab interval about 20px

Use the existing brush sampling architecture. Do not rewrite the brush engine broadly.

Do not introduce bitmap baking in the live editing hot path.

Do not introduce playback cache or save/load changes.

### 6. Keep Photoshop-compatible direction without claiming full compatibility

Document this clearly:

- The goal is Photoshop-like brush settings structure.
- This phase does not implement Photoshop ABR import.
- This phase does not claim exact Photoshop brush engine parity.
- The parameter model should leave room for future hardness, flow, angle, roundness, pressure, smoothing, texture, dual brush, and presets.

Do not implement those future settings yet except spacing.

### 7. Preserve existing behavior

Preserve:

- brush drawing
- canvas viewport pan / zoom / fit / reset
- panbars
- canvas boundary clipping
- app-level undo / redo
- frame/layer/cut selection behavior
- BrushToolState persistence across selection changes
- source data boundary
- no Provider / Riverpod / ChangeNotifier / Bloc

## Required tests

### Panel frame tests

Add tests for:

- EditorPanelFrame renders header and body
- panel frame has stable structure at small sizes
- panel frame does not overflow at small sizes
- right dock can host BrushSettingsPanel

### Brush settings panel tests

Add tests for:

- BrushSettingsPanel renders in the production HomePage / main editor route
- size control updates BrushToolState
- opacity control updates BrushToolState
- color swatch updates BrushToolState
- spacing control updates BrushToolState
- controls are reachable even in constrained panel width
- no debug brush controls are reintroduced

### BrushToolState tests

Add tests for:

- default spacing is stable
- public constructor clamps spacing
- copyWith clamps spacing
- NaN / infinity spacing falls back to default
- toInputSettings or equivalent conversion carries spacing safely

### Drawing behavior tests

Add tests for:

- smaller spacing creates more sampled dabs for the same stroke distance
- larger spacing creates fewer sampled dabs for the same stroke distance
- changing spacing affects only future strokes
- existing committed strokes are not rewritten when spacing changes
- undo/redo still works after changing spacing

### Source boundary tests

Add or update tests for:

- Project / Cut / Layer / Frame / Stroke JSON does not gain editor panel state
- Project / Cut / Layer / Frame / Stroke JSON does not gain BrushToolState
- spacing is not added as project source metadata
- committed dabs keep materialized drawing values only

## Documentation updates

Update:

- docs/Current_Project_Architecture.md
- docs/Current_Brush_Architecture.md
- docs/Current_UI_Product_Policy.md if it exists and is relevant
- docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only

Do not edit Handoff sections 0 through 4.

Document:

- reusable EditorPanelFrame direction
- right-side editor panel dock direction
- BrushSettingsPanel is the primary brush settings UI
- BrushToolState remains editor-session tool state
- spacing is part of BrushToolState
- spacing affects future dab sampling
- Photoshop-compatible direction means Photoshop-like structure, not full ABR compatibility yet

## Non-goals

Do not implement:

- full docking framework
- floating panels
- panel tabs
- panel resizing
- workspace layout persistence
- Photoshop ABR import
- full Photoshop brush engine parity
- brush presets
- eraser
- pen pressure
- hardness
- flow
- angle
- roundness
- smoothing
- texture
- dual brush
- color picker dialog
- save/load
- playback
- playback cache
- onion skin
- layer groups
- layer masks
- blend modes
- Provider
- Riverpod
- ChangeNotifier
- Bloc

## Validation

Run:

- dart format lib test docs
- dart format --set-exit-if-changed lib test
- flutter analyze
- flutter test

If a command cannot run, report it clearly.

## PR requirements

Create a PR from master.

PR title:

Phase 303: Add editor panels and brush settings panel

PR description must mention:

- adds reusable editor panel frame components
- adds right-side panel dock
- moves brush settings into BrushSettingsPanel
- extends BrushToolState with spacing
- connects spacing to brush dab sampling
- keeps brush settings out of source models and save/load data
- preserves viewport, panbar, clipping, undo/redo behavior
- does not introduce broad state management