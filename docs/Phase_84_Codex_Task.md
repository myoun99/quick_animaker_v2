# Phase 84 Codex Task - Storyboard Panel Active Cut Sync

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Recent relevant phases:

* Phase 83:

    * Added a read-only `StoryboardPanel`.
    * `StoryboardPanel` shows project-level tracks as V-style rows.
    * It shows Cut blocks by duration.
    * It detects `LayerKind.storyboard` inside each Cut and shows either a storyboard strip or `No Storyboard Layer`.
    * No model changes.
    * No editing.
    * No thumbnails.
    * No renderer/cache work.

* PR 115 follow-up:

    * Existing widget tests were stabilized after StoryboardPanel introduced duplicate visible Cut names.
    * CutListBar tests now use cut-list keys rather than broad `find.text(...)`.

Long-term Storyboard Panel direction is documented in:

```text
docs/LongTerm_StoryboardPanel_TimelineDesign.md
```

## Phase goal

Connect the read-only Storyboard Panel Cut blocks to the existing active Cut selection system.

This phase should make StoryboardPanel a navigation view.

The user should be able to click/tap a Cut block in the Storyboard Panel and switch the active Cut.

This is still not an editing phase.

## Core behavior

Add active Cut synchronization between:

* CutListBar
* Canvas
* TimelinePanel
* StoryboardPanel

Expected behavior:

```text
Click Cut block in StoryboardPanel
=> active Cut changes
=> Canvas shows that Cut
=> TimelinePanel shows that Cut's layers/frames
=> CutListBar active state updates
=> StoryboardPanel active Cut highlight updates
```

Also:

```text
Click Cut in CutListBar
=> active Cut changes
=> StoryboardPanel highlight updates
```

## Important rules

### 1. No project mutation

Changing the active Cut is UI/session state only.

Do not mutate Project data.

Do not create history entries.

Do not modify save/load data.

Do not modify Cut/Track/Layer/Frame models.

### 2. No editing

Do not implement:

* Cut block drag
* Cut block resize
* cut reorder
* exposure editing
* comma extension
* frame selection sync
* metadata editing
* thumbnail rendering

This phase is only active Cut selection/highlight.

### 3. Preserve StoryboardPanel model rule

StoryboardPanel must remain a view of existing data:

```text
Project -> Track -> Cut -> Layer -> Frame
```

Do not create:

```text
StoryboardPanelModel
StoryboardClipModel
StoryboardTrackModel
Cut.storyboardPanel
Cut.storyboardLayer.panels
```

## Required implementation

### 1. Add active Cut input to StoryboardPanel

Update `StoryboardPanel` to accept the current active Cut id.

Suggested API:

```dart
StoryboardPanel({
  super.key,
  required Project project,
  required CutId activeCutId,
  required ValueChanged<CutId> onCutSelected,
})
```

Exact shape may follow project style, but the panel should know:

* which Cut is active
* how to notify HomePage when a Cut block is selected

Do not make StoryboardPanel own app state.

### 2. Add Cut block tap/click behavior

Each Cut block should be tappable.

When a non-active Cut block is tapped:

```text
onCutSelected(cut.id)
```

When the active Cut block is tapped:

```text
no-op is acceptable
```

Do not add context menu.

Do not add double-click behavior.

Do not add drag behavior.

### 3. Add active Cut visual highlight

The active Cut block should be visually distinguishable.

Use a simple visual style:

* stronger border
* selected background
* small active indicator text
* or subtle highlight

Keep it minimal.

Stable key suggestion:

```text
storyboard-cut-active-indicator-<cutId>
```

Do not rename the existing keys:

```text
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
```

### 4. Wire StoryboardPanel into HomePage

HomePage currently passes only:

```dart
StoryboardPanel(project: _repository.requireProject())
```

Update this to pass:

* current active Cut id
* callback to switch active Cut

The callback should reuse existing active-Cut switching logic.

Do not duplicate cut switching logic if HomePage already has helper methods.

The callback must refresh active cut controllers/layer controllers the same way CutListBar switching does.

After selecting a Cut from StoryboardPanel:

* Canvas must target the selected Cut.
* TimelinePanel must show selected Cut's layers.
* active layer should resolve according to existing cut switching behavior.
* existing copied layer clipboard should remain unchanged.
* existing copied frame reference behavior should follow current cut switching rules.

### 5. Keep StoryboardPanel testable as isolated widget

Update `test/ui/storyboard_panel_test.dart`.

The test widget should pass:

* `activeCutId`
* `onCutSelected`

Use a captured variable or callback counter to test selection.

## Tests required

### 1. StoryboardPanel unit/widget tests

Add/update tests for:

* active Cut block shows active indicator
* inactive Cut block does not show active indicator
* tapping inactive Cut block calls `onCutSelected` with that CutId
* tapping active Cut block does not have to call callback, or if it calls callback, behavior is harmless and documented in test
* V1/V2 labels still render
* storyboard strip/empty placeholder still render
* building panel does not mutate Project

Suggested keys:

```text
storyboard-cut-active-indicator-<cutId>
storyboard-cut-block-<cutId>
```

### 2. HomePage integration widget tests

Add tests for:

* StoryboardPanel is visible in HomePage.
* Default active Cut block is highlighted.
* Create or use a second Cut.
* Tap the second Cut's StoryboardPanel block.
* Canvas active Cut changes to second Cut.
* CutListBar active tooltip changes to second Cut.
* Timeline layer label changes if the second Cut has different layers.
* StoryboardPanel highlight moves to second Cut.
* Switching through CutListBar also updates StoryboardPanel highlight.

Avoid broad `find.text('Cut 1')` assertions.

Use stable keys and descendant finders.

### 3. Regression tests

Existing tests must still pass:

* StoryboardPanel shell tests
* CutListBar create/duplicate/delete/rename/switch tests
* Layer Add/Rename/Delete/Duplicate/Copy/Paste tests
* Storyboard Layer max-one tests
* frame rename/link tests

## Out of scope

Do not implement:

* Storyboard Panel editing
* cut block drag
* cut block resize
* cut reorder from StoryboardPanel
* exposure drag
* comma extension
* frame selection sync
* playhead sync
* metadata editor
* actionMemo/dialogueMemo/note editor
* thumbnails
* rendering/cache work
* export
* PDF/image/storyboard sheet output
* OS/system clipboard
* keyboard shortcuts
* context menus
* audio/camera/sound layers
* new LayerKind values
* section UI
* vertical timesheet redesign
* Project/Track/Cut/Layer/Frame model changes
* save/load format changes
* Provider/Riverpod/Bloc/ChangeNotifier

## Acceptance criteria

This phase is complete when:

* StoryboardPanel receives active Cut id
* StoryboardPanel receives Cut selection callback
* active Cut block is highlighted
* tapping a StoryboardPanel Cut block switches active Cut in HomePage
* switching Cut through CutListBar updates StoryboardPanel highlight
* Canvas/Timeline/CutListBar stay synchronized
* no Project data mutation occurs from selection
* no editing behavior is added
* no data model is added
* existing StoryboardPanel display behavior is preserved
* all existing tests pass
* new tests cover active highlight and selection sync
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
* StoryboardPanel API update
* active Cut highlight key/style
* how `onCutSelected` is wired to HomePage
* confirmation that selection creates no history entry
* confirmation that no Project data is mutated
* confirmation that no editing/thumbnail/rendering/export work was added
* tests added/updated
* final check results:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
