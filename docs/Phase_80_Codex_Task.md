# Phase 80 Codex Task - Layer Clipboard Foundation and Duplicate Refactor

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Relevant completed phases:

* Phase 77:

    * Active layer rename exists.
    * Rename is undoable/redoable.
    * Rename currently rejects duplicate layer names in the same Cut.

* Phase 78:

    * Active layer delete exists.
    * Delete is undoable/redoable.
    * Last-layer deletion is rejected.
    * Delete preserves raw/horizontal/XSheet layer order architecture.

* Phase 79:

    * Active layer duplicate exists.
    * Duplicate is undoable/redoable.
    * Duplicate inserts the copied layer after the source raw index.
    * Duplicate currently uses the next available cel-style layer name.
    * Duplicate creates new IDs and copies frames/timeline/marks.
    * Duplicating a Storyboard Layer creates an Animation Layer copy.

## Design correction for this phase

Layer names and frame names should follow different rules.

### Frame name rule

Frame names should remain unique by default.

When a user tries to use the same frame name, the app may link to the existing frame rather than creating a duplicate drawing frame.

Do not change frame rename/link behavior in this phase.

### Layer name rule

Layer names should not be treated as unique IDs.

Layer names are display labels only.

Internal identity must be based on `LayerId`.

Therefore, duplicate layer names must be allowed.

Examples:

```text id="0bcbd0"
A
A
B
```

is valid.

```text id="dqmbsf"
Storyboard
Storyboard
```

is valid as names, but not necessarily as LayerKind.

The Storyboard max-one rule is about `LayerKind.storyboard`, not about `Layer.name`.

## Phase goal

Introduce a long-term Layer copy/paste foundation and refactor Duplicate Layer to use it.

Duplicate Layer should conceptually become:

```text id="v7elw7"
Copy Layer payload
+
Paste Layer payload
```

The UI still only needs the existing Duplicate Layer button for now.

Do not add Copy Layer / Paste Layer buttons yet.

## Main objectives

This phase should:

* add an internal Layer copy payload structure
* add paste planning logic
* add a paste command
* refactor Duplicate Layer to use the copy/paste foundation
* make duplicated layer names preserve the source layer name
* allow duplicate layer names during rename
* keep frame-name behavior unchanged
* preserve Storyboard Layer paste policy
* preserve raw/horizontal/XSheet order architecture

## Required behavior

### 1. Add Layer copy payload

Add an internal immutable payload representing copied layer data.

Suggested name:

```text id="9eit5q"
LayerCopyPayload
```

Possible location:

```text id="jv4mhg"
lib/src/services/clipboard/
```

or another project-consistent location.

The payload should contain copied display/content data, but not the original layer identity as the pasted identity.

It should include at least:

* source layer name
* source LayerKind
* visibility
* opacity
* frames
* timeline exposures
* marks

It may also include metadata needed for diagnostics or future paste behavior, but it should not require the source layer to still exist when pasting.

The payload should be independent from the source project structure.

### 2. Add Layer copy helper

Add a helper that creates `LayerCopyPayload` from a `Layer`.

Suggested function:

```dart id="w0tply"
LayerCopyPayload copyLayerToPayload(Layer source)
```

or project-style equivalent.

This helper should not mutate the repository.

This helper should not add a history entry.

### 3. Add paste planner

Add a paste planning helper.

Suggested name:

```text id="u6aj4e"
LayerPastePlanner
```

or:

```dart id="i3lj3k"
planPasteLayerCommandInput(...)
```

The planner should:

* generate a new LayerId
* generate new FrameIds when needed
* remap timeline exposures to the new FrameIds
* decide the final pasted LayerKind
* decide or accept the raw insertion index
* create the final pasted Layer snapshot

The planner should use current project IDs to avoid ID collisions.

### 4. Paste Layer command

Add an undoable paste command.

Suggested name:

```text id="6q8mkg"
PasteLayerCommand
```

The command should:

* target a Cut
* insert a prepared pasted Layer at a raw index
* store the inserted Layer snapshot
* store the raw insertion index
* undo by removing the pasted Layer
* redo by restoring the same pasted Layer at the same raw index

Use existing repository APIs if possible:

```dart id="t38vvw"
ProjectRepository.insertLayer(...)
ProjectRepository.deleteLayer(...)
```

Do not duplicate repository mutation logic unnecessarily.

### 5. Refactor Duplicate Layer

Refactor Duplicate Layer so it uses the same copy/paste path.

Conceptual flow:

```text id="swuhaa"
source Layer
-> LayerCopyPayload
-> Paste planner
-> PasteLayerCommand
```

Duplicate Layer should remain available from the same UI button:

```text id="8qzkja"
duplicate-layer-button
```

Do not remove the existing Duplicate Layer button.

If `DuplicateLayerCommand` already exists, either:

* refactor it to delegate to the paste-layer foundation, or
* replace it with `PasteLayerCommand` inside the coordinator while keeping public exports/tests project-consistent.

Choose the cleanest project-consistent option.

Avoid duplicated copy logic between Duplicate and Paste.

### 6. Duplicate layer naming rule

Duplicated layer should preserve the source layer name.

Examples:

```text id="m87m23"
raw: A
duplicate A
result raw: A, A
```

```text id="efay6x"
raw: A, B, C
duplicate B
result raw: A, B, B, C
```

```text id="3dxaj4"
raw: BG, Character, FX
duplicate Character
result raw: BG, Character, Character, FX
```

Do not rename duplicates to:

```text id="xkza1b"
A copy
A 2
B copy
D
```

The old Phase 79 next-cel-name behavior should be removed for duplication.

Add Layer should still use the cel-style default naming rule.

This phase changes Duplicate Layer naming only.

### 7. Allow duplicate layer names on rename

Change layer rename validation so same-name layers are allowed.

Rename should still reject:

* empty names
* whitespace-only names

Rename should allow:

```text id="n9tm9j"
A -> B
```

even when another layer named B already exists.

Rename must still be undoable/redoable.

Do not change frame rename behavior.

Frame names should remain unique/link-based according to the existing behavior.

### 8. Storyboard paste policy

The paste planner must enforce Storyboard Layer kind rules.

A Cut may have at most one `LayerKind.storyboard`.

When pasting a Layer payload:

```text id="vc6o60"
if payload.kind == LayerKind.storyboard
and target Cut has no Storyboard Layer
=> paste as LayerKind.storyboard
```

```text id="ivn8ys"
if payload.kind == LayerKind.storyboard
and target Cut already has a Storyboard Layer
=> paste as LayerKind.animation
```

```text id="o9baqv"
if payload.kind == LayerKind.animation
=> paste as LayerKind.animation
```

This rule should apply to Duplicate Layer as well.

This means:

```text id="h5srpz"
Duplicating the only Storyboard Layer in the same Cut
=> target Cut already has that Storyboard Layer
=> duplicate becomes Animation Layer
```

So Phase 79 behavior remains correct, but now it should be implemented by paste policy rather than special duplicate-only logic.

### 9. Raw insertion behavior

Duplicate Layer should continue to insert after the source layer in raw `Cut.layers`.

Examples:

```text id="9nbcm5"
raw: A, B, C
duplicate B
result raw: A, B, B, C
horizontal: C, B, B, A
xsheet: A | B | B | C
```

```text id="h4uwmk"
raw: A, B, C
duplicate A
result raw: A, A, B, C
horizontal: C, B, A, A
xsheet: A | A | B | C
```

Do not reverse raw `Cut.layers`.

Do not add a vertical adapter.

### 10. Active layer behavior

After Duplicate Layer:

* the pasted duplicate should become active
* rename/delete/toggle-kind should target the duplicate
* undo should remove the duplicate
* redo should restore the same duplicate and make it active if practical

### 11. No Copy/Paste UI yet

Do not add the following UI in this phase:

* Copy Layer button
* Paste Layer button
* clipboard toolbar
* cross-Cut paste UI
* keyboard shortcuts

This phase is internal foundation plus Duplicate refactor.

Copy/Paste UI should be a future phase.

### 12. Keep existing behavior stable

Do not break:

* Add Layer
* Rename Layer except duplicate-name validation change
* Delete Layer
* Duplicate Layer button
* Toggle Storyboard Layer
* LayerKind icons
* horizontal display order
* XSheet display order
* frame rename/link behavior
* cut create/delete/duplicate/replace tests

## Tests required

### 1. Layer copy payload tests

Add tests for:

* payload preserves source name
* payload preserves source kind
* payload preserves visibility
* payload preserves opacity
* payload preserves frames
* payload preserves timeline
* payload preserves marks
* payload does not reuse source LayerId as pasted LayerId

### 2. Paste planner / paste command tests

Add tests for:

* paste creates new LayerId
* paste creates/remaps FrameIds where needed
* paste preserves layer name
* paste preserves visibility
* paste preserves opacity
* paste preserves frames/frame metadata
* paste preserves timeline exposure structure with remapped frame ids
* paste preserves marks
* undo removes pasted layer
* redo restores same pasted layer at same raw index
* paste in one Cut does not affect another Cut

### 3. Duplicate refactor tests

Update or add tests for:

* duplicating A creates another layer named A
* duplicating B in A/B/C creates raw A/B/B/C
* duplicate source remains unchanged
* duplicate gets new LayerId
* duplicate gets remapped FrameIds
* duplicate becomes active in UI
* undo removes duplicate
* redo restores duplicate
* duplicate uses paste-layer foundation, or at least no duplicate-only copy logic remains

### 4. Storyboard paste policy tests

Add tests for:

* pasting Storyboard payload into Cut with no Storyboard Layer creates Storyboard Layer
* pasting Storyboard payload into Cut with existing Storyboard Layer creates Animation Layer
* duplicating Storyboard Layer in same Cut creates Animation Layer
* Cut still has at most one Storyboard Layer after duplicate/paste

### 5. Rename tests

Update rename tests:

* renaming a layer to an existing layer name is allowed
* empty rename is still rejected
* whitespace-only rename is still rejected
* rename undo/redo still works
* frame rename/link tests remain unchanged

### 6. Widget tests

Update or add widget tests:

* Duplicate Layer button still visible
* Duplicate Layer button still enabled when active layer exists
* duplicating active A produces another visible A
* duplicated A becomes active
* duplicated layer can be renamed to a name that already exists
* duplicated layer can be deleted
* horizontal order remains correct with duplicate names
* XSheet order remains correct with duplicate names if existing helpers support XSheet mode

## Out of scope

Do not implement:

* Copy Layer button
* Paste Layer button
* keyboard shortcuts
* system clipboard integration
* cross-Cut paste UI
* cross-Track paste UI
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

* Layer copy payload exists
* paste planning exists
* paste command exists
* Duplicate Layer uses the copy/paste foundation
* Duplicate Layer preserves source layer name
* duplicate layer names are allowed
* rename allows duplicate layer names
* frame rename/link behavior is unchanged
* Storyboard paste policy is enforced
* raw/horizontal/XSheet order architecture is preserved
* existing tests pass
* new tests cover copy/paste foundation and duplicate refactor

## Required checks

Run:

```text id="lld0hx"
dart format lib test
flutter analyze
flutter test
git status
```

## Codex report requirements

In the final report, include:

* changed files
* copy payload type name
* paste planner/helper name
* paste command name
* coordinator/controller API changes
* duplicate naming behavior
* rename duplicate-name behavior
* Storyboard paste policy
* raw insertion behavior
* active layer behavior
* confirmation that frame rename/link behavior was not changed
* confirmation that no Copy/Paste UI was added
* confirmation that no Sound/Camera/Section/Timesheet work was added
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
