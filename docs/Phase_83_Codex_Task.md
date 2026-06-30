# Phase 83 Codex Task - Storyboard Panel Shell

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

The layer system is now stabilized.

Recent relevant phases:

* Phase 77:

    * Rename Layer command/UI.
    * Layer names are display labels, not identity.

* Phase 78:

    * Delete Layer command/UI.
    * Last-layer deletion protection.

* Phase 79:

    * Duplicate Layer command/UI.

* Phase 80:

    * Layer copy/paste foundation.
    * Duplicate Layer refactored to use copy/paste foundation.
    * Layer names may be duplicated.
    * Storyboard paste policy established.

* Phase 81:

    * Minimal Copy Layer / Paste Layer UI.
    * App-local layer clipboard.

* Phase 82:

    * Layer system stabilization.
    * Obsolete duplicate-only layer command/planner removed.
    * Generated-ID assumptions in tests were reduced.
    * Handoff docs updated with stable layer policy.

Long-term Storyboard Panel direction is documented in:

```text
docs/LongTerm_StoryboardPanel_TimelineDesign.md
```

Read that document before implementing this phase.

## Phase goal

Add the first minimal Storyboard Panel shell.

This phase is UI/view foundation only.

The panel should begin the long-term Premiere/DaVinci-style timeline direction:

```text
Project
  Track / V1, V2...
    Cut block
      Storyboard Layer presence/head area
```

Do not implement editing yet.

Do not implement thumbnails yet.

Do not add a separate Storyboard data model.

## Core design rule

Storyboard Panel must read from the existing data model:

```text
Project -> Track -> Cut -> Layer -> Frame
```

Storyboard data already lives here:

```text
Cut.layers
  Layer(kind: LayerKind.storyboard)
    frames
    timeline
    Frame.storyboardMetadata
```

Do not create:

```text
Cut.storyboardPanel
Cut.storyboardLayer.panels
StoryboardPanelModel
StoryboardClipModel
StoryboardTrackModel
```

The Storyboard Panel is a view of existing Project/Track/Cut/Layer/Frame data.

## Required behavior

### 1. Add a minimal Storyboard Panel widget

Create a small UI component for the Storyboard Panel.

Suggested file:

```text
lib/src/ui/storyboard_panel.dart
```

Suggested widget name:

```text
StoryboardPanel
```

The exact file/widget names may follow project style, but the panel should be isolated enough that future phases can expand it.

The panel should have a stable root key:

```text
storyboard-panel
```

Suggested title text:

```text
STORYBOARD
```

Suggested title key:

```text
storyboard-panel-title
```

### 2. Display project tracks as V tracks

The Storyboard Panel should show project-level tracks as video-style tracks.

For now:

```text
Project.tracks[0] -> V1
Project.tracks[1] -> V2
Project.tracks[2] -> V3
```

These V tracks are project/cut tracks.

They are not animation layers.

Do not confuse V1/V2 project tracks with Cut layers such as A/B/C.

Add stable keys if useful:

```text
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
```

The visible label may be:

```text
V1
V2
V3
```

### 3. Display Cut blocks by Cut duration

For each Cut in each Project Track, display a rectangular Cut block.

The Cut block should represent the Cut duration.

In this first shell phase, a simple proportional width is enough.

Example:

```text
Cut duration = 24
=> wider block than duration = 12
```

Do not implement zoom yet.

Do not implement scrolling complexity beyond what is necessary to avoid overflow.

Stable key suggestion:

```text
storyboard-cut-block-<cutId>
```

Each Cut block should display at least:

* Cut name
* Cut duration
* whether a Storyboard Layer exists

Suggested text examples:

```text
Cut 1 · 24f
Storyboard: yes
```

or:

```text
Cut 1 · 24f
No Storyboard Layer
```

Exact wording may follow UI style, but tests should use stable keys where possible.

### 4. Show Storyboard Layer presence inside Cut block

For each Cut block:

* If the Cut has a `LayerKind.storyboard` layer:

    * show a simple inner storyboard strip/head area
    * show the storyboard layer name
    * show the storyboard frame count or exposure count if easily available

* If the Cut has no `LayerKind.storyboard` layer:

    * show the Cut block only
    * show a subtle placeholder such as `No Storyboard Layer`

Stable key suggestions:

```text
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
```

This is only display.

Do not create a Storyboard Layer automatically.

Do not modify the repository.

### 5. Add the panel to HomePage

Add the Storyboard Panel to the main UI in a minimal, non-disruptive way.

It can be placed near the existing bottom timeline area, or in a simple panel area that fits the current layout.

The first phase does not need perfect final design.

However, it should visually suggest the long-term editing timeline direction:

* dark panel
* horizontal track rows
* Cut blocks
* Storyboard title area
* V1/V2-style labels

Do not break the existing canvas or timeline UI.

### 6. No editing in this phase

The Storyboard Panel shell must be read-only.

Do not implement:

* cut block drag
* cut block resize
* frame exposure drag
* comma extension
* trim handles
* frame selection sync
* playhead sync
* metadata editing
* thumbnail rendering

These are future phases.

### 7. Do not change layer system behavior

Do not change any of the following:

* Add Layer
* Rename Layer
* Delete Layer
* Duplicate Layer
* Copy Layer
* Paste Layer
* LayerKind toggle
* Storyboard max-one rule
* Storyboard paste policy
* raw/horizontal/XSheet layer order
* frame rename/link behavior

This phase should only add a read-only Storyboard Panel shell.

### 8. Do not change data model

Do not modify:

* Project
* Track
* Cut
* Layer
* Frame
* StoryboardFrameMetadata
* save/load schema
* persistence format

If a model change seems necessary, stop and keep the implementation read-only with existing model data.

### 9. Test expectations

Add widget tests for the panel shell.

Tests should verify:

* Storyboard Panel exists.
* Title `STORYBOARD` exists.
* Project track row is shown as V1.
* Cut block exists for the active/default project Cut.
* Cut block displays Cut name or duration.
* If a Storyboard Layer exists in fixture, Storyboard Layer strip is shown.
* If no Storyboard Layer exists, empty placeholder is shown.
* Opening/rendering the panel does not mutate repository state.
* Existing layer operation tests still pass.

Avoid brittle generated IDs.

Use stable keys based on existing model IDs where possible.

## Suggested keys

Use stable keys like:

```text
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
```

Do not rename existing layer/timeline keys.

## Out of scope

Do not implement:

* Storyboard metadata editor
* actionMemo editor
* dialogueMemo editor
* note editor
* thumbnail rendering
* thumbnail cache
* frame preview rendering
* playhead sync
* frame selection sync
* cut block drag
* cut block resize
* exposure drag
* comma extension
* trim handles
* zoom controls
* audio tracks
* camera tracks
* sound layers
* new LayerKind values
* section UI
* vertical timesheet redesign
* renderer changes
* canvas changes
* brush changes
* save/load format changes
* persistence redesign
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* a read-only Storyboard Panel shell exists
* the panel is visible in the main UI
* the panel shows V-style project track labels
* the panel shows Cut blocks based on existing Cuts
* Cut blocks show basic Cut information
* Cut blocks show whether a Storyboard Layer exists
* no repository mutation occurs from merely showing the panel
* no new data model is introduced
* no Storyboard editing is added
* no thumbnail/render/cache work is added
* existing layer operations still pass
* `dart format lib test` passes
* `flutter analyze` passes
* `flutter test` passes
* `git status` is clean

## Required checks

Run:

```text
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* Storyboard Panel widget/file name
* where the panel was added in HomePage
* stable keys added
* how Project Track -> V track label is displayed
* how Cut block width/duration is represented
* how Storyboard Layer presence is detected
* confirmation that no Storyboard data model was added
* confirmation that no editing/thumbnail/rendering was added
* confirmation that layer operations were not changed
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
