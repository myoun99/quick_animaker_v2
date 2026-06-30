# Phase 79 Codex Task - Duplicate Layer Command and Minimal UI

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

The layer-management foundation is now in place.

Completed relevant phases:

* Phase 74:

    * Cut-local cel-style layer names: A, B, C, ..., Z, AA, AB...
    * New Cut default Layer is A.
    * New Layer default name uses the smallest available cel name in that Cut.
    * New Cut and new Layer start with blank exposure at visible frame 1.
    * A Cut may have at most one Storyboard Layer.

* Phase 75:

    * Horizontal timeline layer rows show LayerKind icons.
    * Animation and Storyboard icons are visible.
    * Storyboard toggle updates the icon.

* Phase 76 and follow-up:

    * Raw `Cut.layers` order is logical cel/XSheet order.
    * Example raw order: A, B, C.
    * Horizontal timeline display uses visual stack order through adapter.
    * Example horizontal display: C, B, A.
    * XSheet/vertical display uses raw order directly.
    * Example XSheet display: A | B | C.

* Phase 77:

    * Active layer can be renamed from the timeline UI.
    * Rename is undoable/redoable.
    * Rename updates only `Layer.name`.
    * Rename preserves id, kind, frames, timeline, visibility, opacity, and order.
    * Rename keeps the active layer selected after refresh.

* Phase 78:

    * Active layer can be deleted from the timeline UI.
    * Delete has a confirmation dialog.
    * Delete is undoable/redoable.
    * Delete restores the deleted layer at the same raw index on undo.
    * Last-layer deletion is rejected.
    * Raw/horizontal/XSheet layer order architecture is preserved.

## Phase goal

Add undoable active layer duplication.

The user should be able to duplicate the active layer from the timeline UI.

This should be a small layer-management phase.

## Why this phase exists

The app now supports:

* Add Layer
* Rename Layer
* Delete Layer

The next natural basic layer operation is:

* Duplicate Layer

After this phase, the first basic layer-management set will be mostly complete.

## Required behavior

### 1. Add an undoable duplicate layer command

Add a command for duplicating a layer.

Suggested name:

```text id="sxvv7r"
DuplicateLayerCommand
```

Use the naming style already used in the project.

The command must:

* target a specific Cut
* target a specific source Layer
* insert a new duplicated Layer into `Cut.layers`
* store the duplicated Layer snapshot
* store the inserted raw index
* support undo by removing the duplicated Layer
* support redo by restoring the same duplicated Layer at the same raw index

### 2. Add repository API if needed

Add or reuse repository APIs for inserting/removing a duplicated layer.

Possible APIs:

```dart id="230xma"
insertLayer({
  required CutId cutId,
  required Layer layer,
  int? index,
})
```

and:

```dart id="jjra0d"
deleteLayer({
  required CutId cutId,
  required LayerId layerId,
})
```

If these already exist from previous phases, reuse them.

Do not duplicate repository logic unnecessarily.

### 3. Add coordinator/controller API

Expose a clean API from the relevant coordinator/controller.

Suggested API:

```dart id="qg7k6l"
duplicateLayer({
  required CutId cutId,
  required LayerId sourceLayerId,
  required LayerId newLayerId,
})
```

or similar project-style API.

The UI must not directly mutate the repository.

The coordinator/controller should:

* find the source layer
* compute the new duplicated layer name
* compute the raw insertion index
* create the duplicated layer snapshot
* execute the command through `HistoryManager`

### 4. New duplicated layer name

The duplicated layer must use the same Cut-local cel-style naming rule as Add Layer.

Do not name the duplicated layer:

```text id="ijxu6v"
A copy
B copy
A 2
B 2
```

Instead, use the smallest available cel name in the Cut.

Examples:

```text id="wgy3v2"
existing raw: A
duplicate A -> new name B
```

```text id="n3x8br"
existing raw: A, B, C
duplicate B -> new name D
```

```text id="iohgq1"
existing raw: A, C
duplicate A -> new name B
```

This keeps the cel naming model consistent.

### 5. Raw insertion rule

Duplicating a layer should place the duplicated layer directly above the source layer in visual stack terms.

Because raw `Cut.layers` order is logical/XSheet order, this means:

* insert the duplicate after the source layer in raw order

Examples:

```text id="wsd57h"
raw: A, B, C
active/source: B
duplicate B -> D
result raw: A, B, D, C
horizontal display: C, D, B, A
xsheet display: A | B | D | C
```

```text id="o7gyjd"
raw: A, B, C
active/source: A
duplicate A -> D
result raw: A, D, B, C
horizontal display: C, B, D, A
xsheet display: A | D | B | C
```

```text id="v7t34d"
raw: A, B, C
active/source: C
duplicate C -> D
result raw: A, B, C, D
horizontal display: D, C, B, A
xsheet display: A | B | C | D
```

Do not reverse raw `Cut.layers`.

Do not add a vertical adapter.

### 6. Active layer after duplicate

After duplicating a layer:

* the duplicated layer should become active
* timeline UI should show the duplicated layer as selected
* rename/delete/toggle-kind should target the duplicated layer afterward

Undo after duplicate should:

* remove the duplicated layer
* select a stable nearby layer if practical
* source layer should remain available

Redo after undo should:

* restore the same duplicated layer
* make the duplicated layer active if practical

### 7. Deep copy behavior

The duplicated layer should be an independent layer.

It must have:

* a new LayerId
* a new name
* copied visibility
* copied opacity
* copied timeline exposure structure
* copied marks
* copied frames
* copied frame contents
* copied frame metadata

Important:
Avoid sharing mutable collections between the source layer and duplicated layer.

If the existing model uses immutable value objects, preserving value equality is fine.
But the duplicated layer must not reuse the same `LayerId`.

If Frames or Strokes have identifiers and the existing architecture expects IDs to be unique, generate new FrameIds and StrokeIds and remap timeline exposures to the new frame IDs.

If the current codebase has no clear ID generator for frame/stroke duplication, implement the smallest project-consistent helper needed for this phase and cover it with tests.

### 8. Storyboard layer behavior

A Cut may have at most one Storyboard Layer.

Duplicating a Storyboard Layer as another Storyboard Layer would violate the max-one rule.

Therefore:

* if the source layer is `LayerKind.animation`, duplicate it as `LayerKind.animation`
* if the source layer is `LayerKind.storyboard`, duplicate its drawing/frame/timeline contents but create the duplicate as `LayerKind.animation`

This means duplicating a Storyboard Layer creates an Animation Layer copy.

Do not create a second Storyboard Layer.

Do not remove the existing Storyboard Layer.

Do not change Storyboard max-one behavior.

### 9. Add minimal Duplicate Layer UI

Add a Duplicate Layer button to the existing timeline action toolbar.

Suggested key:

```text id="6172xh"
duplicate-layer-button
```

Suggested tooltip:

```text id="6mkitr"
Duplicate Layer
```

Suggested icon:

```text id="yg9nb5"
Icons.copy_outlined
```

The button should:

* be visible in the timeline action toolbar
* be enabled when an active layer exists
* be disabled when there is no active layer
* duplicate only the active layer
* make the duplicated layer active
* not open a confirmation dialog

No confirmation dialog is needed because duplication is non-destructive.

### 10. Undo/Redo behavior

Undo after layer duplicate should:

* remove the duplicated layer
* preserve the source layer
* preserve raw order of remaining layers
* leave a stable active layer selected if practical

Redo after undo should:

* restore the same duplicated layer
* restore it at the same raw index
* restore the same duplicated LayerId
* restore the same name
* restore copied layer content
* make the duplicated layer active if practical

### 11. Keep existing layer operations working

Duplicate must not break:

* Add Layer
* Rename Layer
* Delete Layer
* Toggle Storyboard Layer
* LayerKind icons
* horizontal timeline order
* XSheet order
* last-layer delete protection
* cut create/delete/duplicate/replace tests

### 12. Keep existing keys stable

Do not remove or rename existing keys.

Important existing keys include:

```text id="70h3da"
timeline-layer-row-<layerId>
timeline-layer-name-<layerId>
timeline-layer-kind-icon-<layerId>
timeline-layer-visibility-<layerId>
timeline-layer-opacity-<layerId>
timeline-selected-layer
timeline-toolbar-add-layer-button
timeline-add-layer-button
toggle-storyboard-layer-button
active-layer-kind-label
rename-layer-button
rename-layer-dialog
rename-layer-text-field
rename-layer-cancel-button
rename-layer-ok-button
delete-layer-button
delete-layer-dialog
delete-layer-cancel-button
delete-layer-confirm-button
```

Add the new key:

```text id="d6jrfp"
duplicate-layer-button
```

## Tests required

### 1. Command/coordinator tests

Add tests for:

* duplicate layer inserts a new layer
* duplicate layer preserves source layer
* duplicate layer uses new LayerId
* duplicate layer uses next available cel-style name
* duplicate layer is inserted after the source raw index
* duplicate layer preserves copied visibility
* duplicate layer preserves copied opacity
* duplicate layer preserves copied frames
* duplicate layer preserves copied timeline exposures
* duplicate layer preserves copied marks
* duplicate layer preserves frame metadata
* undo removes the duplicate
* redo restores the same duplicate at the same raw index
* duplicating in one Cut does not affect another Cut
* duplicating Animation Layer creates Animation Layer
* duplicating Storyboard Layer creates Animation Layer, not another Storyboard Layer
* Storyboard max-one rule remains intact after duplicate

### 2. Widget tests

Add tests for:

* Duplicate Layer button is visible
* Duplicate Layer button is disabled when there is no active layer if such UI state is testable
* Duplicate Layer button is enabled when active layer exists
* duplicating active A creates B when only A exists
* duplicating active B in A/B/C creates D
* duplicated layer becomes active
* raw order is correct after duplicate
* horizontal order is correct after duplicate
* XSheet order is correct after duplicate, if existing test helpers support XSheet mode
* undo removes duplicate
* redo restores duplicate
* rename works on duplicated layer
* delete works on duplicated layer
* LayerKind icons remain visible
* duplicating Storyboard Layer does not create a second Storyboard Layer

### 3. Regression tests

Make sure existing tests still pass, especially:

* Add Layer tests
* Rename Layer tests
* Delete Layer tests
* Layer kind toggle tests
* Layer kind icon tests
* Horizontal/XSheet order tests
* Cut command tests

## Out of scope

Do not implement any of the following:

* layer folders
* layer lock
* layer drag-and-drop reorder
* layer merge
* layer opacity presets
* layer blending modes
* new LayerKind values
* Sound layers
* Camera layers
* Rough layers
* Guide layers
* section UI
* vertical timesheet redesign
* Storyboard Panel UI
* Conte Panel UI
* actionMemo UI
* dialogueMemo UI
* CutMetadata changes
* StoryboardFrameMetadata schema changes
* renderer changes
* canvas changes
* brush changes
* save format changes
* persistence redesign
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* the active layer can be duplicated from the UI
* duplicate is undoable/redoable
* duplicated layer gets a new LayerId
* duplicated layer gets the next available cel-style name
* duplicated layer is inserted directly above the source visually
* raw layer order remains logical/XSheet order
* horizontal display order remains adapter-driven
* XSheet display order remains raw order
* duplicated layer becomes active
* duplicating Storyboard Layer does not create a second Storyboard Layer
* Add/Rename/Delete/Toggle Storyboard still work
* existing tests pass
* new tests cover command/coordinator and UI behavior

## Required checks

Run:

```text id="z86xla"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* command name
* repository API names used or added
* coordinator/controller API name
* UI button key
* duplicated layer naming behavior
* raw insertion behavior
* active layer selection behavior after duplicate
* undo/redo behavior
* Storyboard duplication behavior
* confirmation that raw/horizontal/XSheet order architecture is preserved
* confirmation that Add/Rename/Delete still work
* confirmation that no Sound/Camera/Section/Timesheet work was added
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
