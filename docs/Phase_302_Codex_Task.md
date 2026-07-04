# Phase 302 Codex Task — Brush Tool Controls and Editor Tool State

## Context

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool.

The current active work is the brush/canvas editing part.

Recent completed work:

- clipped canvas boundary behavior
- viewport pan / zoom / fit / reset
- canvas editor panel shell
- right and bottom panbars
- panbar small-size safety
- panbar thumb-follow interaction
- source-label canvas title/status
- production default project/cut/layer/frame cleanup
- no sample project/cut/layer/frame production startup
- app-level brush undo/redo baseline

The next step is to make the brush tool feel like a real drawing tool.

This phase must introduce a long-term brush tool control structure inspired by Clip Studio Paint / Photoshop style workflows.

Tool state / tool option UI should cover:

- current brush size
- current opacity
- current color
- clear current setting display

Do not build a large full application UI yet.

Do not implement a full brush preset system yet.

Do not implement pressure, eraser, multiple brush engines, or save/load.

This phase is about establishing the correct long-term state boundary and UI placement for brush tool settings.

## Core goals

### 1. Introduce editor-session brush tool state

Create a small, explicit editor-session brush tool state model.

Recommended names:

- BrushToolState
- BrushToolSettings
- BrushToolController
- BrushToolSession

Choose names that fit the current project style.

The state should contain at minimum:

- size
- opacity
- color

Rules:

- size must be finite and clamped to a safe range
- opacity must be finite and clamped to 0.0..1.0
- color should remain stable as an integer/Color-compatible value matching existing BrushEditCanvasInputSettings usage

This state is editor-session/tool UI state.

It must not be stored in:

- Project
- Track
- Cut
- Layer
- Frame
- Stroke
- BrushDab
- playback/cache data
- camera data
- save/load data

It can later become workspace preference or preset state, but not in this phase.

### 2. Separate BrushCanvasPanel from hardcoded input settings

Currently the brush canvas panel has an internal input settings value.

Replace the hardcoded/local-only approach with a clean tool-state flow.

Desired long-term direction:

- HomePage / editor session owns current brush tool state
- MainCanvasBrushHost / BrushCanvasPanel receives brush tool state
- MainCanvasBrushHost / BrushCanvasPanel receives callbacks for tool state changes
- BrushCanvasPanel passes current brush input settings to InteractiveBrushEditCanvasView
- InteractiveBrushEditCanvasView uses the current settings for new strokes

Do not introduce Provider, Riverpod, ChangeNotifier, Bloc, or broad app-wide state management.

Plain local state passed by constructor/callback is preferred for now.

### 3. Add a compact brush tool options UI

Add a compact UI area for brush settings.

The visual direction should be closer to Clip Studio Paint / Photoshop than a debug panel.

Recommended placement:

- Canvas editor panel top or bottom tool/options strip

Acceptable structure option A:

- Canvas editor shell
    - title/status area
    - tool options row
    - canvas viewport
    - right panbar
    - bottom zoom/panbar controls

Acceptable structure option B:

- Main editor area
    - top tool options bar above canvas panel
    - canvas panel remains focused on viewport/panbar/title

Choose the option that keeps the code modular and does not make BrushCanvasPanel a God Object.

The UI should include at minimum:

- brush size control
- opacity control
- color control
- current brush setting display

The controls can be simple but production-facing:

- slider for size
- slider for opacity
- small color swatches for black / red / blue / white / transparent-safe choices
- compact text display such as "Brush 10px / 100%"

Do not reintroduce old debug controls.

Do not add temporary buttons like "Black", "Red" as debug-only controls.

Color swatches are acceptable only if they are presented as a real brush option UI.

### 4. Use current brush tool state for new strokes

When the user changes:

- size
- opacity
- color

the next stroke must use the changed setting.

Rules:

- changing settings should not rewrite existing strokes
- committed strokes keep the settings they were drawn with
- undo/redo must still work
- frame/layer/cut switching must not reset the current brush tool settings
- viewport switching must not reset brush settings

### 5. Keep source data and tool state separate

Brush tool state must remain editor-session UI/tool state.

Do not add it to:

- Project.toJson
- Cut.toJson
- Layer.toJson
- Frame.toJson
- Stroke.toJson
- BrushDab source payload

Existing committed dab payload should continue to carry whatever materialized input values it already needs for rendering.

Do not create save/load format changes.

### 6. Keep UI modular

Avoid making brush_canvas_panel.dart a dumping ground.

Recommended structure:

- lib/src/ui/brush/brush_tool_state.dart
- lib/src/ui/brush/brush_tool_options_bar.dart
- lib/src/ui/brush/brush_tool_color_swatch.dart

Equivalent names are acceptable if they better match the current project structure.

BrushCanvasPanel should compose these widgets rather than embedding all UI logic directly.

A small state/helper model under lib/src/ui/brush/ is acceptable.

If a pure model belongs under lib/src/models/, justify that by making it source-independent and reusable.

For now, editor-session UI state under ui/brush is preferred.

## UI design notes

The user imagines a Clip Studio Paint / Photoshop-like feeling.

Interpret that as:

- compact professional tool option bar
- clear current brush values
- no toy/debug controls
- no oversized form-like panel
- no heavy full settings window
- controls placed near the canvas, not inside source model logic

This phase does not need visual polish, icons, themes, or full docking panels.

It should establish the right structure so later phases can add:

- brush presets
- eraser
- pen pressure
- shortcut keys
- color picker
- tool palette

without rewriting the state boundary.

## Scope

Allowed files:

- lib/src/ui/brush/
- lib/src/ui/canvas/
- lib/src/ui/home_page.dart
- lib/src/ui/brush/main_canvas_brush_host.dart
- test/ui/
- docs/

Use the smallest reasonable changes outside these paths.

## Non-goals

Do not implement:

- pen pressure
- eraser
- brush presets
- preset persistence
- save/load
- playback
- onion skin
- layer blend modes
- layer groups
- masks
- full color picker dialog
- keyboard shortcuts
- Provider
- Riverpod
- ChangeNotifier
- Bloc
- large dockable UI framework

Do not change the meaning of existing Project / Cut / Layer / Frame / Stroke source models.

## Required tests

### Brush tool state

Add or update tests for:

- default brush tool state maps to existing default brush input settings
- size is clamped to safe finite range
- opacity is clamped to 0.0..1.0
- color updates remain stable

### Tool options UI

Add or update tests for:

- brush tool options bar renders in production brush editing route
- size control updates brush tool state
- opacity control updates brush tool state
- color swatch updates brush tool state
- debug color buttons are not reintroduced

### Drawing behavior

Add or update tests for:

- changing brush size affects the next stroke
- changing opacity affects the next stroke
- changing color affects the next stroke
- existing committed strokes are not rewritten when settings change
- undo/redo still works after changing brush settings

### Selection persistence

Add or update tests for:

- brush tool settings survive frame selection changes
- brush tool settings survive layer selection changes
- brush tool settings survive cut selection changes
- brush tool settings are independent from CanvasViewport pan/zoom state

### Source boundary

Add or update tests for:

- Project/Cut/Layer/Frame/Stroke JSON does not gain editor brush tool state fields
- Brush tool state is not added to save/load source models

## Documentation updates

Update current docs where appropriate:

- docs/Current_Project_Architecture.md
- docs/Current_Brush_Architecture.md
- docs/Handoff_QuickAnimaker_v2_Current.md section 5 or later only

Do not edit Handoff sections 0 through 4.

Document:

- brush tool state is editor-session UI/tool state
- brush tool state is separate from source data
- current brush option UI placement
- future expansion path for presets / eraser / pressure / shortcuts

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

Phase 302: Add brush tool controls and editor tool state

PR description must mention:

- adds editor-session brush tool state
- adds compact production brush options UI
- connects size / opacity / color to new strokes
- keeps brush tool state out of source models and save/load data
- preserves viewport, panbar, boundary clipping, undo/redo behavior
- does not introduce broad state management