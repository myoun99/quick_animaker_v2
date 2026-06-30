# Phase 81 Codex Task - Minimal Layer Copy/Paste UI

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Relevant completed phases:

* Phase 79:

    * Duplicate Layer exists.
    * Duplicate Layer is undoable/redoable.
    * Duplicate inserts after the source layer in raw `Cut.layers`.

* Phase 80:

    * Layer copy/paste foundation exists.
    * `LayerCopyPayload` exists.
    * `copyLayerToPayload(Layer)` exists.
    * Paste planning exists.
    * `PasteLayerCommand` exists.
    * Duplicate Layer was refactored to use the copy/paste foundation.
    * Duplicate Layer preserves the source layer name.
    * Duplicate layer names are allowed.
    * Rename now allows duplicate layer names.
    * Frame rename/link behavior was not changed.
    * Storyboard paste policy exists:

        * Storyboard payload pasted into a Cut with no Storyboard Layer pastes as Storyboard.
        * Storyboard payload pasted into a Cut with an existing Storyboard Layer pastes as Animation.
        * Animation payload pastes as Animation.

## Phase goal

Add minimal UI for copying and pasting layers using the existing Phase 80 layer clipboard foundation.

This phase should expose the internal layer copy/paste foundation through the timeline toolbar.

## Important design principle

Do not create a separate copy/paste implementation.

Copy Layer and Paste Layer must reuse the existing Phase 80 foundation:

```text
Layer -> LayerCopyPayload -> paste planner -> PasteLayerCommand
```

Duplicate Layer should remain available and should continue using the same copy/paste foundation.

## Required behavior

### 1. Add in-memory layer clipboard state

Add app-local clipboard state for copied layer payload.

Suggested state in `HomePage` or the appropriate controller:

```dart
LayerCopyPayload? _layerClipboard;
```

This is not the OS/system clipboard.

The copied layer should remain available while the user switches active Cut inside the current app session.

This enables:

```text
copy layer from Cut 1
select Cut 2
paste into Cut 2
```

Do not persist the clipboard to disk.

Do not serialize it to project save data.

### 2. Add Copy Layer action

Add a minimal Copy Layer action.

Suggested button key:

```text
copy-layer-button
```

Suggested tooltip:

```text
Copy Layer
```

Suggested icon:

```dart
Icons.content_copy
```

Behavior:

* Copy the active layer into `_layerClipboard`.
* Use `copyLayerToPayload(activeLayer)`.
* Do not mutate the repository.
* Do not add a history entry.
* Do not change active layer.
* Do not change current frame.
* Do not open a dialog.
* Disable the button if there is no active layer.

### 3. Add Paste Layer action

Add a minimal Paste Layer action.

Suggested button key:

```text
paste-layer-button
```

Suggested tooltip:

```text
Paste Layer
```

Suggested icon:

```dart
Icons.content_paste
```

Behavior:

* Enabled only when `_layerClipboard != null`.
* Paste the copied payload into the active Cut.
* Use the paste planner and `PasteLayerCommand`.
* Do not mutate repository directly from UI.
* Paste should be undoable/redoable through the existing history system.
* The pasted layer should become active.
* Do not open a dialog.

### 4. Paste insertion rule

Paste into the active Cut.

If there is an active layer in the target Cut:

```text
insert after active layer in raw Cut.layers
```

If there is no active layer, which should normally not happen:

```text
insert at the end of raw Cut.layers
```

Examples:

```text
target raw: A, B, C
active target layer: B
clipboard payload name: A
paste
result raw: A, B, A, C
```

```text
target raw: A
active target layer: A
clipboard payload name: A
paste
result raw: A, A
```

Raw order must stay logical/XSheet order.

Horizontal display remains adapter-driven and reversed visually.

### 5. Cross-Cut paste behavior

No special cross-Cut UI is needed.

But the clipboard should remain available after switching Cuts.

This should work:

```text
Cut 1: copy layer A
switch to Cut 2
paste
```

The pasted layer should be inserted into Cut 2 according to the active target layer in Cut 2.

Do not add a separate cross-Cut paste panel.

Do not add Cut selection dialogs.

### 6. Storyboard paste policy

Reuse Phase 80 Storyboard paste policy.

When pasting a copied Storyboard Layer:

```text
if target Cut has no Storyboard Layer
=> paste as LayerKind.storyboard
```

```text
if target Cut already has a Storyboard Layer
=> paste as LayerKind.animation
```

Animation payloads paste as Animation.

This must apply both within the same Cut and across Cuts.

### 7. Name behavior

Pasted layer should preserve the copied layer name.

Examples:

```text
copy A
paste
=> A
```

```text
copy BG
paste
=> BG
```

Duplicate layer names remain allowed.

Do not generate names like:

```text
A copy
A 2
B copy
D
```

Add Layer should still use cel-style default naming.

### 8. Active layer behavior

After Paste Layer:

* the pasted layer becomes active
* rename/delete/toggle-kind should target the pasted layer
* undo should remove the pasted layer
* redo should restore the pasted layer
* redo should make the restored pasted layer active if practical

### 9. Optional clipboard status text

Add a small debug/status text only if useful for tests and UI clarity.

Suggested key:

```text
layer-clipboard-status
```

Possible text:

```text
Layer Clipboard: empty
```

or:

```text
Layer Clipboard: A
```

This is optional but recommended because it makes widget tests more stable.

Do not add a large clipboard panel.

### 10. Keep existing Duplicate Layer behavior

Duplicate Layer button must still exist:

```text
duplicate-layer-button
```

Duplicate should still:

* duplicate the active layer
* preserve source layer name
* insert after source in raw order
* make duplicate active
* be undoable/redoable
* use the same copy/paste foundation

Do not regress Duplicate Layer while adding Copy/Paste UI.

## Required API shape

Add a coordinator/controller method for pasting if it does not already exist.

Suggested API:

```dart
LayerId pasteLayer({
  required CutId cutId,
  required LayerCopyPayload payload,
  int? insertionIndex,
})
```

or:

```dart
LayerId pasteLayerAfter({
  required CutId cutId,
  required LayerCopyPayload payload,
  LayerId? targetLayerId,
})
```

Choose the most project-consistent API.

The UI should call this API rather than directly creating/executing repository mutations.

## Tests required

### 1. Coordinator/paste tests

Add or update tests for:

* paste payload into active/target Cut
* paste creates new LayerId
* paste preserves layer name
* paste inserts after target raw index
* paste remaps FrameIds
* paste undo removes pasted layer
* paste redo restores pasted layer at same raw index
* paste in one Cut does not affect another Cut
* paste Storyboard payload into Cut with no Storyboard Layer creates Storyboard Layer
* paste Storyboard payload into Cut with existing Storyboard Layer creates Animation Layer

### 2. Widget tests

Add widget tests for:

* Copy Layer button is visible
* Paste Layer button is visible
* Copy Layer button is enabled when active layer exists
* Paste Layer button is disabled when clipboard is empty
* Copy active A updates internal clipboard/status
* Paste after copying A creates another visible A
* Pasted A becomes active
* Pasted layer can be renamed
* Pasted layer can be deleted
* Undo removes pasted layer
* Redo restores pasted layer
* Copy from one Cut, switch to another Cut, paste into that Cut if existing Cut switching helpers support it
* Storyboard paste policy if existing widget helpers make it reasonable

### 3. Regression tests

Existing tests must still pass, especially:

* Duplicate Layer tests
* Rename Layer tests
* Delete Layer tests
* Add Layer tests
* LayerKind toggle tests
* Storyboard max-one tests
* frame rename/link tests
* cut create/delete/duplicate/replace tests

## Out of scope

Do not implement:

* OS/system clipboard integration
* keyboard shortcuts
* Copy/Paste menu bar
* context menu
* right-click menu
* multi-layer copy
* multi-layer paste
* layer folders
* layer lock
* layer drag-and-drop reorder
* layer merge
* blending modes
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

* Copy Layer button exists
* Paste Layer button exists
* copy stores active layer as `LayerCopyPayload`
* paste inserts copied payload into active Cut
* paste is undoable/redoable
* pasted layer preserves copied layer name
* duplicate layer names are allowed
* pasted layer becomes active
* copy from one Cut and paste into another Cut is supported by in-memory clipboard behavior
* Storyboard paste policy is preserved
* Duplicate Layer still works
* raw/horizontal/XSheet order architecture is preserved
* all existing tests pass
* new tests cover minimal Copy/Paste UI

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
* clipboard state location
* Copy Layer button key
* Paste Layer button key
* coordinator/controller paste API
* paste insertion behavior
* pasted layer naming behavior
* active layer behavior after paste
* Storyboard paste policy confirmation
* Duplicate Layer regression confirmation
* confirmation that no OS clipboard or keyboard shortcut was added
* confirmation that no Sound/Camera/Section/Timesheet work was added
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
