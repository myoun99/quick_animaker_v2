# Phase 78 Codex Task - Delete Layer Command and Minimal UI

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

The following layer-management phases are complete:

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

* Phase 76 / follow-up:

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

## Phase goal

Add undoable active layer deletion.

This should be a small layer-management phase.

The user should be able to delete the active layer from the timeline UI.

## Why this phase exists

Layer creation and renaming now exist.

The next basic layer operation is deletion.

This phase should implement deletion carefully without changing the layer order architecture or introducing section/timesheet work.

## Required behavior

### 1. Add an undoable delete layer command

Add a command for deleting a layer.

Suggested name:

```text id="j6cmcf"
DeleteLayerCommand
```

Use the naming style already used in the project.

The command must:

* target a specific Cut and Layer
* remove only the target Layer from `Cut.layers`
* preserve the raw order of all remaining layers
* store the deleted Layer snapshot
* store the deleted Layer raw index
* support undo by restoring the deleted Layer at the same raw index
* support redo by deleting the same Layer again

### 2. Add repository API

Add a repository method for deleting a layer.

Suggested API:

```dart id="mx842v"
deleteLayer({
  required CutId cutId,
  required LayerId layerId,
})
```

or similar.

The repository method should:

* remove the target layer from the target Cut
* throw if the Cut is not found
* throw if the Layer is not found
* not reorder the remaining layers
* not change other Cuts
* not change other Tracks

For undo, also add an insert/restore method if needed.

Suggested API:

```dart id="94j8nm"
insertLayerAt({
  required CutId cutId,
  required int index,
  required Layer layer,
})
```

or use an existing project style if one exists.

### 3. Add controller/coordinator API

Expose a clean API from the relevant controller/coordinator.

Possible API shape:

```dart id="3c8s4d"
deleteLayer({
  required CutId cutId,
  required LayerId layerId,
})
```

or similar.

The UI must not directly mutate the repository.

### 4. Last layer safety rule

For now, do not allow a Cut to become empty through layer deletion.

If a Cut has only one layer:

* delete layer command should be rejected
* no history entry should be added
* UI delete button should be disabled

Reason:
The rest of the app currently assumes a normal editing Cut has at least one editable layer in many flows.
Allowing zero-layer Cuts should be a separate future design phase.

### 5. Active layer behavior after delete

After deleting the active layer, select a stable nearby layer.

Raw order examples:

```text id="dwzlw2"
raw: A, B, C
active: B
delete B
result raw: A, C
new active: C
```

```text id="cwdjox"
raw: A, B, C
active: C
delete C
result raw: A, B
new active: B
```

```text id="t9mvu7"
raw: A, B, C
active: A
delete A
result raw: B, C
new active: B
```

Selection rule:

* Prefer the layer that shifts into the deleted layer's raw index.
* If no layer exists at that index, select the previous layer.
* If deletion is rejected because it is the last layer, keep the current active layer.

### 6. Keep layer order architecture unchanged

Deletion must not change the layer order design.

Before:

```text id="cel175"
raw: A, B, C
horizontal: C, B, A
xsheet: A | B | C
```

Delete B:

```text id="iu4kxl"
raw: A, C
horizontal: C, A
xsheet: A | C
```

Delete C:

```text id="h7ybzw"
raw: A, B
horizontal: B, A
xsheet: A | B
```

Do not reverse or sort raw `Cut.layers`.

Do not add a vertical adapter.

### 7. Add minimal Delete Layer UI

Add a Delete Layer button to the existing timeline action toolbar.

Suggested key:

```text id="42syfw"
delete-layer-button
```

Suggested tooltip:

```text id="g48myc"
Delete Layer
```

Suggested icon:

```text id="8wf5i1"
Icons.delete_outline
```

The button should:

* be visible in the timeline action toolbar
* be enabled only when the active Cut has at least two layers and an active layer exists
* be disabled when there is no active layer
* be disabled when there is only one layer
* delete only the active layer
* keep the remaining timeline usable after deletion

### 8. Add confirmation dialog

Because deleting a layer can remove drawing data, add a simple confirmation dialog.

Suggested keys:

```text id="4rywb7"
delete-layer-dialog
delete-layer-cancel-button
delete-layer-confirm-button
```

Suggested title:

```text id="77nuwg"
Delete Layer
```

Suggested body:

```text id="lvj8eg"
Delete layer "<layer name>"?
```

Dialog behavior:

* Cancel changes nothing.
* Confirm deletes the active layer.
* Confirm should call coordinator/controller API, not repository directly.

### 9. Undo/Redo behavior

Undo after layer delete should:

* restore the deleted layer at the same raw index
* restore its id
* restore its name
* restore its kind
* restore frames
* restore timeline exposures
* restore visibility
* restore opacity
* restore marks if the model has marks
* restore Storyboard metadata if present in frames
* restore the layer order
* make the restored layer active if practical

Redo after undo should:

* delete the same layer again
* leave a stable nearby layer active

### 10. Storyboard layer behavior

Deleting a Storyboard Layer should be allowed if the Cut has at least two layers.

After deleting a Storyboard Layer:

* the Cut has no Storyboard Layer
* another layer can later be toggled to Storyboard
* Storyboard max-one rule remains intact

Do not special-case Storyboard deletion beyond normal layer deletion.

### 11. Keep Phase 77 rename behavior working

Layer delete must not break rename.

After deleting a layer:

* remaining active layer can still be renamed
* rename still preserves active layer
* duplicate-name validation still uses the current Cut-local layer list

### 12. Keep existing keys stable

Do not remove or rename existing keys.

Important existing keys:

```text id="yblzt7"
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
```

## Tests required

### 1. Command/controller tests

Add tests for:

* delete layer removes target layer
* delete layer preserves remaining raw order
* undo restores deleted layer at the same raw index
* redo deletes it again
* delete preserves deleted layer snapshot for undo:

    * id
    * name
    * kind
    * frames
    * timeline
    * visibility
    * opacity
    * marks if present
* deleting a layer in one Cut does not affect another Cut
* deleting last remaining layer is rejected
* rejected last-layer delete does not add history
* deleting Storyboard Layer allows another layer to become Storyboard later, if existing command APIs make this easy to test

### 2. Widget tests

Add tests for:

* Delete Layer button is visible
* Delete Layer button is disabled with only one layer
* Delete Layer button is enabled with two or more layers
* clicking Delete Layer opens confirmation dialog
* Cancel changes nothing
* Confirm deletes the active layer
* after deleting B from A/B/C, C or the correct nearby layer becomes active
* undo restores the deleted layer
* redo deletes it again
* horizontal display order remains correct after delete
* XSheet display order remains correct after delete, if existing test helpers support XSheet mode
* remaining layer kind icons remain visible
* rename still works after deleting another layer

### 3. Regression tests

Make sure existing tests still pass, especially:

* cut create/delete/replace tests
* layer add tests
* layer order tests
* layer kind icon tests
* layer rename tests
* Storyboard max-one tests

## Out of scope

Do not implement any of the following:

* layer duplicate
* layer lock
* layer drag-and-drop reorder
* layer folders
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

## Acceptance criteria

This phase is complete when:

* the active layer can be deleted from the UI
* delete has a confirmation dialog
* delete is undoable/redoable
* deleting the last layer is rejected
* rejected delete does not add history
* active layer selection remains stable after deletion
* remaining raw layer order is preserved
* horizontal display order remains correct
* XSheet display order remains correct
* layer rename still works after deletion
* existing tests pass
* new tests cover command/controller and UI behavior

## Required checks

Run:

```text id="yy1x7x"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* command name
* repository API names
* controller/coordinator API name
* UI button key
* dialog keys
* last-layer deletion behavior
* active layer selection behavior after delete
* undo/redo behavior
* confirmation that raw layer order is preserved
* confirmation that horizontal/XSheet display order is preserved
* confirmation that rename still works after delete
* confirmation that no Sound/Camera/Section/Timesheet work was added
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
