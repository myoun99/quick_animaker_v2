# Phase 82 Codex Task - Layer System Stabilization and Cleanup

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

The layer system now has the first complete basic operation set:

* Add Layer
* Rename Layer
* Delete Layer
* Duplicate Layer
* Copy Layer
* Paste Layer
* Toggle LayerKind between Animation and Storyboard
* Storyboard max-one rule per Cut

Relevant recent phases:

* Phase 77:

    * Rename Layer command and minimal UI.
    * Rename is undoable/redoable.
    * Layer names are now display labels, not unique IDs.

* Phase 78:

    * Delete Layer command and minimal UI.
    * Delete is undoable/redoable.
    * Last layer deletion is rejected.
    * Active layer selection is updated after delete.

* Phase 79:

    * Duplicate Layer command/UI added.
    * Duplicate originally had a duplicate-specific command and planner.

* Phase 80:

    * Layer copy/paste foundation introduced.
    * `LayerCopyPayload` exists.
    * `copyLayerToPayload(Layer)` exists.
    * Paste planning exists.
    * `PasteLayerCommand` exists.
    * Duplicate Layer was refactored to use copy/paste foundation.
    * Duplicated layer preserves source layer name.
    * Duplicate layer names are allowed.
    * Rename allows duplicate layer names.
    * Frame rename/link behavior was not changed.
    * Storyboard paste policy exists.

* Phase 81:

    * Minimal Copy Layer / Paste Layer UI added.
    * App-local in-memory layer clipboard exists.
    * `copy-layer-button`, `paste-layer-button`, and `layer-clipboard-status` exist.
    * Copy does not mutate repository or history.
    * Paste uses coordinator/paste command.
    * Paste is undoable/redoable.
    * Pasted layer becomes active.

## Phase goal

Stabilize and clean up the layer system after Add/Rename/Delete/Duplicate/Copy/Paste were added.

This is not a new feature phase.

This phase should remove fragile tests, stale command/planner remnants, and ambiguous layer naming behavior before starting Storyboard Panel work.

## Main objectives

This phase should:

* audit the full layer operation stack
* remove or safely deprecate obsolete duplicate-only layer command/planner code
* make tests resilient to generated IDs
* strengthen Add/Rename/Delete/Duplicate/Copy/Paste regression tests
* document the final layer-name policy
* document the final layer copy/paste policy
* preserve frame-name behavior
* preserve Storyboard paste policy
* update handoff docs
* ensure all tests/analyze pass

## Important design rules

### 1. Layer identity

Layer identity is `LayerId`.

Layer name is only a display label.

Layer names may be duplicated.

Valid example:

```text
A
A
B
```

Invalid assumption:

```text
Layer.name is unique inside a Cut
```

Do not reintroduce duplicate-name rejection for layers.

### 2. Frame identity and frame names

Do not change frame behavior in this phase.

Frame names should remain unique/link-based according to the existing behavior.

Layer duplicate-name allowance must not affect frame rename/link behavior.

### 3. Storyboard max-one rule

A Cut may have at most one `LayerKind.storyboard`.

This rule is about `LayerKind.storyboard`, not about `Layer.name`.

Multiple layers may be named `Storyboard`, but only one layer may have `kind == LayerKind.storyboard`.

### 4. Copy/Paste foundation

Layer copy/paste should use:

```text
LayerCopyPayload
copyLayerToPayload
planPasteLayerCommandInput
PasteLayerCommand
CutCommandCoordinator.pasteLayer
```

Duplicate Layer should be a convenience operation using the same paste path.

Do not maintain separate duplicate-only deep-copy logic if it is no longer used.

## Required stabilization work

### 1. Audit obsolete duplicate-only layer code

Check whether these are still used by production code or tests:

```text
DuplicateLayerCommand
DuplicateLayerCommandInputPlan
planDuplicateLayerCommandInput
duplicateLayerAsIndependentCopy
duplicate-only layer copy helpers
duplicate_layer_command.dart
```

If they are no longer used:

* remove them
* remove exports
* update export tests
* update imports
* remove stale tests that only test obsolete duplicate-only command behavior

If a piece is still used by duplicate-cut logic or another valid path:

* keep it
* rename or document it so it is not confused with layer paste foundation
* make sure it is not duplicating paste-layer logic

The desired long-term direction is:

```text
Duplicate Layer
= copyLayerToPayload(sourceLayer)
+ pasteLayer(... insertionIndex: sourceIndex + 1)
```

Do not keep two separate layer-copy implementations.

### 2. Stabilize generated ID assumptions in tests

Some widget tests currently assume generated IDs such as:

```text
timeline-layer-row-layer-1
```

This is brittle.

Generated IDs may change as the ID planner evolves.

Update tests to avoid hardcoding generated IDs unless the ID is explicitly part of the model fixture and guaranteed.

Prefer stable assertions such as:

* selected layer contains expected name
* count of timeline layer rows increased
* active layer label updated
* repository-backed test helper verifies raw order
* a returned LayerId from coordinator is used in service tests
* UI finds `timeline-selected-layer` and checks descendant text

Widget tests should not fail just because the next generated layer id changes from `layer-1` to `layer-2`.

If a widget test must reference a generated id, add a helper that discovers it from the UI or from test repository state rather than hardcoding it.

### 3. Stabilize layer operation tests

Add or update tests to cover the final intended behavior.

#### Add Layer

Verify:

* Add Layer still creates the next cel-style default name.
* Add Layer inserts visually above active layer by raw `sourceIndex + 1`.
* Add Layer selection remains correct.
* Add Layer is undoable/redoable if existing architecture supports it.

#### Rename Layer

Verify:

* empty name is rejected
* whitespace-only name is rejected
* duplicate layer names are allowed
* rename is undoable/redoable
* rename preserves LayerId, LayerKind, frames, timeline, marks, visibility, opacity, and raw order
* frame rename/link tests remain unchanged

#### Delete Layer

Verify:

* delete removes active layer
* delete is undoable/redoable
* last layer deletion is rejected
* deleting Storyboard Layer is allowed if at least two layers exist
* deleting Storyboard Layer frees Storyboard slot
* active selection after delete is stable
* raw/horizontal/XSheet order remains correct

#### Duplicate Layer

Verify:

* duplicate uses copy/paste foundation
* duplicate preserves source layer name
* duplicate gets new LayerId
* duplicate remaps FrameIds
* duplicate inserts after source raw index
* duplicate becomes active
* undo removes duplicate
* redo restores duplicate
* duplicating Storyboard Layer in same Cut creates Animation Layer
* no duplicate-only copy logic is used if obsolete code was removed

#### Copy Layer

Verify:

* copy stores `LayerCopyPayload`
* copy does not mutate repository
* copy does not add history
* copy does not change active layer
* copy preserves source name/kind/frames/timeline/marks in payload

#### Paste Layer

Verify:

* paste creates new LayerId
* paste preserves copied layer name
* paste remaps FrameIds
* paste inserts after requested raw index
* paste becomes active
* paste is undoable/redoable
* paste in one Cut does not affect another Cut
* Storyboard payload into Cut with no Storyboard Layer pastes as Storyboard
* Storyboard payload into Cut with existing Storyboard Layer pastes as Animation
* Animation payload pastes as Animation

### 4. Clipboard UI stability

Verify these UI keys remain stable:

```text
copy-layer-button
paste-layer-button
layer-clipboard-status
duplicate-layer-button
rename-layer-button
delete-layer-button
toggle-storyboard-layer-button
active-layer-kind-label
timeline-selected-layer
```

Do not rename these keys.

Check that:

* Paste button is disabled when clipboard is empty.
* Copy active layer enables Paste button.
* Clipboard status text updates.
* Clipboard state survives Cut switching inside the same HomePage session.
* Clipboard state is not persisted to project save data.
* Clipboard does not use OS/system clipboard.

### 5. Storyboard policy stability

Make the policy explicit in tests and comments where helpful:

```text
payload.kind == storyboard
target Cut has no storyboard
=> paste as storyboard
```

```text
payload.kind == storyboard
target Cut already has storyboard
=> paste as animation
```

```text
payload.kind == animation
=> paste as animation
```

This policy must apply to:

* Paste Layer
* Duplicate Layer
* future cross-Cut paste

### 6. Handoff and long-term docs update

Update the project handoff docs so future phases know the current stable layer policy.

Update:

```text
docs/Handoff_QuickAnimaker_v2_Current.md
```

Add or update sections describing:

* Layer names are not unique.
* LayerId is the identity.
* Frame name behavior remains separate.
* Duplicate uses copy/paste foundation.
* Copy/Paste uses app-local in-memory clipboard.
* PasteLayerCommand is the canonical layer insert command for pasted payloads.
* Storyboard paste policy.
* Raw layer order remains logical/XSheet order.
* Horizontal timeline display remains adapter-driven reversed order.
* Copy/Paste UI keys.

If useful, also reference:

```text
docs/LongTerm_StoryboardPanel_TimelineDesign.md
```

Do not rewrite large docs unnecessarily.

Keep the handoff update focused.

## What to avoid

Do not add new user-facing features in this phase.

Do not implement:

* Storyboard Panel UI
* Copy/Paste keyboard shortcuts
* OS/system clipboard
* context menus
* right-click menus
* multi-layer copy/paste
* layer folders
* layer lock
* drag-and-drop layer reorder
* layer merge
* blending modes
* new LayerKind values
* Sound layers
* Camera layers
* Rough layers
* Guide layers
* section UI
* vertical timesheet redesign
* renderer changes
* canvas changes
* brush changes
* save format changes
* persistence redesign
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* obsolete duplicate-only layer code is removed or clearly justified
* Duplicate Layer uses the same copy/paste foundation as Paste Layer
* hardcoded generated layer ID expectations are removed from fragile widget tests
* layer names are consistently treated as duplicate-allowed display labels
* frame name/link behavior is unchanged
* Add/Rename/Delete/Duplicate/Copy/Paste tests are stable
* Storyboard paste policy is covered by tests
* clipboard UI keys remain stable
* handoff docs describe the final layer policy
* no new user-facing feature beyond stabilization was added
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
* obsolete duplicate-only code removed or retained, with reason
* generated-ID test stabilization summary
* layer-name policy confirmation
* frame-name behavior confirmation
* copy/paste foundation confirmation
* Storyboard paste policy confirmation
* clipboard UI stability confirmation
* Handoff doc update summary
* confirmation that no Storyboard Panel UI was added
* confirmation that no Sound/Camera/Section/Timesheet work was added
* test results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
