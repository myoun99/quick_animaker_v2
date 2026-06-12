# Phase 77 Codex Task - Rename Layer Command and Minimal UI

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

The following phases are complete:

* Phase 74:

    * Cut-local cel-style layer names: A, B, C, ..., Z, AA, AB...
    * New Cut default Layer is A.
    * New Layer default name uses the smallest available cel name in that Cut.
    * New Cut and new Layer start with blank exposure at visible frame 1.
    * A Cut may have at most one Storyboard Layer.

* Phase 75:

    * Horizontal timeline layer rows show LayerKind icons.
    * Animation and Storyboard layer icons are visible.
    * Storyboard toggle updates the icon.

* Phase 76 / follow-up:

    * Raw `Cut.layers` order is logical cel/XSheet order.
    * Example raw order: A, B, C.
    * Horizontal timeline display uses visual stack order through adapter.
    * Example horizontal display: C, B, A.
    * XSheet/vertical display uses raw order directly.
    * Example XSheet display: A | B | C.

## Phase goal

Add undoable layer renaming.

This should be a small layer-management phase.

The user should be able to rename the active layer from the timeline UI.

## Why this phase exists

Layer names are currently generated automatically as A/B/C.

That is good for default cel-style workflow, but users need to rename layers later for practical animation work.

Examples:

* A
* B
* BG
* LO
* Rough
* Guide
* Storyboard
* PAN
* BOOK

This phase only adds rename support.

It must not add new layer types or sections yet.

## Required behavior

### 1. Add an undoable layer rename command

Add a command for renaming a layer.

Suggested name:

```text id="gy25vf"
RenameLayerCommand
```

or

```text id="w3n2qv"
UpdateLayerNameCommand
```

Use the naming style already used in the project.

The command must:

* target a specific Cut and Layer
* update only `Layer.name`
* preserve Layer id
* preserve Layer kind
* preserve frames
* preserve timeline exposures
* preserve visibility
* preserve opacity
* support undo
* support redo

### 2. Add controller/coordinator API

Expose a clean API from the relevant controller/coordinator.

Possible API shape:

```dart id="re78w7"
renameLayer({
  required LayerId layerId,
  required String name,
})
```

or similar.

Use the existing project style.

The UI should not directly mutate the repository.

### 3. Validation rules

Layer name validation:

* trim leading/trailing whitespace
* reject empty names
* reject names that are already used by another layer in the same Cut
* allow unchanged name to no-op without adding history
* keep comparison simple and predictable

Recommended behavior:

```text id="x1mwvv"
current name: A
input: " A "
result: no-op

current name: A
input: "B"
if another layer named B exists in the same Cut: reject

current name: A
input: ""
reject
```

Do not silently create duplicate layer names.

### 4. Add minimal Rename Layer UI

Add a Rename Layer button to the existing timeline action toolbar.

Suggested key:

```text id="6h6xez"
rename-layer-button
```

Suggested tooltip:

```text id="cnl9jm"
Rename Layer
```

Suggested icon:

```text id="uq0zkx"
Icons.drive_file_rename_outline
```

or another stable Material rename/edit icon.

The button should:

* be enabled when an active layer exists
* be disabled when no active layer exists
* open a dialog
* prefill the active layer name
* rename only the active layer
* update the visible timeline layer name after OK
* keep the active layer selected after rename

### 5. Add Rename Layer dialog

Add a small dialog similar to existing rename dialogs.

Suggested key names:

```text id="5m93j3"
rename-layer-text-field
rename-layer-cancel-button
rename-layer-ok-button
```

Optional dialog key:

```text id="czoq1g"
rename-layer-dialog
```

Dialog behavior:

* text field starts with the active layer name
* Cancel changes nothing
* OK applies the trimmed name if valid
* empty name should not rename
* duplicate name should not rename

For duplicate/invalid input, choose a simple safe behavior:

* keep dialog open with validation text

or

* close nothing and show inline error

Use the simplest approach that fits current code style.

### 6. Keep layer order unchanged

Renaming a layer must not change:

* raw `Cut.layers` order
* horizontal display order
* XSheet display order
* active layer id
* timeline exposure data

Examples:

Before:

```text id="komel2"
raw: A, B, C
horizontal: C, B, A
xsheet: A | B | C
```

Rename B to BG:

```text id="zhk0rg"
raw: A, BG, C
horizontal: C, BG, A
xsheet: A | BG | C
```

### 7. Keep default layer naming behavior

Do not redesign the default A/B/C naming helper.

New layers should still use the current smallest available cel name behavior.

This phase should not change the rules for generating new layer names.

If a renamed layer frees a cel name, keep whatever the existing helper naturally does.

Do not add special casing in this phase unless required by existing tests.

### 8. Keep LayerKind behavior unchanged

Renaming must not affect LayerKind.

Examples:

* Animation layer renamed to BG remains `LayerKind.animation`.
* Storyboard layer renamed to Storyboard remains `LayerKind.storyboard`.

Storyboard max-one rule must remain unchanged.

### 9. Keep Phase 75 icons working

The layer kind icon should remain visible after renaming.

Renaming a layer should update the text label only.

### 10. Keep existing keys stable

Do not remove or rename existing keys.

Important keys:

```text id="dpgxr7"
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
```

## Tests required

### 1. Command/controller tests

Add or update tests for:

* rename layer changes name
* undo restores old name
* redo reapplies new name
* rename preserves id/kind/frames/timeline/visibility/opacity
* empty name is rejected
* duplicate name in same Cut is rejected
* unchanged name is no-op
* renaming in one Cut does not affect another Cut

### 2. Widget tests

Add widget tests for:

* Rename Layer button is visible
* Rename Layer button is enabled with active layer
* dialog opens with active layer name
* renaming A to BG updates the horizontal layer label
* active layer remains selected after rename
* undo/redo works if undo/redo UI already exists for layer commands
* duplicate name does not create duplicate visible labels
* Cancel changes nothing
* layer kind icon remains visible after rename

### 3. Order tests

Make sure existing order tests still pass:

* raw order remains A, B, C
* horizontal display remains C, B, A
* XSheet display remains A | B | C

Renaming must not reorder layers.

## Out of scope

Do not implement any of the following:

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
* StoryboardFrameMetadata changes
* renderer changes
* canvas changes
* brush changes
* save format changes
* persistence redesign
* Provider/Riverpod/Bloc/ChangeNotifier
* drag-and-drop layer reordering
* layer delete
* layer duplicate
* layer lock

## Acceptance criteria

This phase is complete when:

* active layer can be renamed from the UI
* rename is undoable/redoable
* invalid names are rejected
* duplicate names in the same Cut are rejected
* layer order does not change after rename
* LayerKind does not change after rename
* Phase 75 icons still work
* Phase 76 raw/display order behavior still works
* existing tests pass
* new tests cover command/controller and UI behavior

## Required checks

Run:

```text id="e8prfp"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* command name
* controller/coordinator API name
* UI button key
* dialog keys
* validation behavior
* undo/redo behavior
* confirmation that layer order is unchanged
* confirmation that LayerKind is unchanged
* confirmation that Phase 75 icons still work
* confirmation that no Sound/Camera/Section/Timesheet work was added
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
