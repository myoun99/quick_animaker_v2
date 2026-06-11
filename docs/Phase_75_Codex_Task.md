# Phase 75 Codex Task - Layer Type Icon UI

Repository:
myoun99/quick_animaker_v2

Base branch:
master

Project:
QuickAnimaker v2 Flutter/Dart project.

## Current state

Phase 74 and its follow-up fixes are complete.

Current accepted behavior:

* New Cuts start with one animation Layer named `A`.
* New Layers use Cut-local cel-style names: `A`, `B`, `C`, ..., `Z`, `AA`, `AB`, ...
* New Cuts and new Layers start with a blank exposure at visible frame 1.
* Internal timeline indexing remains zero-based.

    * visible frame 1 == internal index 0
* A Cut may have at most one `LayerKind.storyboard`.
* Storyboard Layer is still a normal `Layer`.
* `Frame.storyboardMetadata` is frame-level.
* `CutMetadata` remains note-only.
* Initial app sample state is minimal:

    * Cut 1 only
    * Layer A only
    * frame 1 = X / blank exposure
    * no initial Cut 2
    * no initial Layer B
    * no initial C2 drawing frame

## Phase goal

Add a small visual layer type icon to the horizontal timeline layer row.

The icon should appear at the left side of the layer label/name area.

Initial support:

* `LayerKind.animation`
* `LayerKind.storyboard`

This is a UI-only phase.

## Why this phase exists

The project now supports Animation Layers and Storyboard Layers as different `Layer.kind` values.

However, the horizontal timeline currently makes the user rely mostly on the selected layer status label or the toggle button state.

The user should be able to see each layer type directly in the layer list.

## Required behavior

### 1. Show a layer type icon in each layer row

In the horizontal timeline layer row, show an icon before the layer name.

Example visual intent:

```text
[animation icon] A
[storyboard icon] B
```

The icon must be based on `layer.kind`.

### 2. Animation icon

For `LayerKind.animation`, show a drawing/cel/brush-style Material icon.

Acceptable examples:

* `Icons.brush_outlined`
* `Icons.edit_outlined`
* `Icons.draw_outlined`

Choose one that fits Flutter Material icons and looks stable.

The icon should have a semantic label or tooltip-like accessibility text equivalent to:

```text
Animation layer
```

### 3. Storyboard icon

For `LayerKind.storyboard`, show a storyboard/book/panel-style Material icon.

Acceptable examples:

* `Icons.auto_stories_outlined`
* `Icons.menu_book_outlined`
* `Icons.view_comfy_alt_outlined`

Choose one that fits Flutter Material icons and looks stable.

The icon should have a semantic label or tooltip-like accessibility text equivalent to:

```text
Storyboard layer
```

### 4. Icon placement

The icon should appear inside the existing layer row label/control area.

Preferred location:

* left of `layer.name`
* inside the clickable layer name/row area
* before the text
* without breaking the existing visibility button, opacity slider, or opacity text

Do not move the layer visibility button or opacity slider to a different conceptual area.

### 5. Active layer styling must still work

The existing active layer row highlight must remain.

The icon may inherit normal row color styling, but the active row should still be visually clear.

### 6. Storyboard toggle must update the icon

When the user toggles a layer from animation to storyboard, the icon should update.

When the user toggles a layer from storyboard back to animation, the icon should update.

This should happen through the existing state rebuild path.

Do not add a separate state management system.

### 7. Keep existing keys stable

Do not remove or rename existing keys unless absolutely necessary.

Existing important keys must continue to work:

```text
timeline-layer-row-<layerId>
timeline-layer-name-<layerId>
timeline-layer-visibility-<layerId>
timeline-layer-opacity-<layerId>
timeline-selected-layer
toggle-storyboard-layer-button
active-layer-kind-label
timeline-toolbar-add-layer-button
timeline-add-layer-button
```

### 8. Add stable test keys for icons

Add stable keys for layer type icons.

Required key format:

```text
timeline-layer-kind-icon-<layerId>
```

Examples:

```text
timeline-layer-kind-icon-sample-layer-1
timeline-layer-kind-icon-sample-layer-2
```

### 9. Add accessibility/semantic coverage

Each icon should be discoverable in tests through either:

* `Semantics(label: 'Animation layer')`
* `Semantics(label: 'Storyboard layer')`

or an equivalent accessible label.

Do not rely only on visual icon data for testing.

### 10. Keep UI compact

Do not make the layer row much taller.

Do not make the layer control area much wider unless absolutely necessary.

A small spacing between icon and layer name is enough.

## Suggested implementation

Likely file to change:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
```

Possible helper:

```text
IconData _iconForLayerKind(LayerKind kind)
String _labelForLayerKind(LayerKind kind)
```

If a separate helper file is cleaner, it may be added, but keep this phase small.

Possible implementation shape:

```dart
Semantics(
  label: _semanticLabelForLayerKind(layer.kind),
  child: Icon(
    _iconForLayerKind(layer.kind),
    key: ValueKey<String>('timeline-layer-kind-icon-${layer.id}'),
    size: 18,
  ),
)
```

Then show the layer name text after the icon.

This is only an example. Implement it in the cleanest way for the current code.

## Tests required

Update or add widget tests in:

```text
test/widget_test.dart
```

Add focused tests for:

### 1. Initial animation layer icon

On initial app launch:

* Cut 1 exists.
* Layer A exists.
* Layer A has an animation icon.
* `timeline-layer-kind-icon-sample-layer-1` exists.
* The animation icon semantic label exists.

### 2. Add Layer creates animation icon

When the user presses Add Layer once:

* New Layer B is created.
* B becomes active.
* B has an animation layer icon.
* `timeline-layer-kind-icon-sample-layer-2` exists.

### 3. Storyboard toggle updates icon

On the active Layer A:

* Initially the icon is animation.
* Press `toggle-storyboard-layer-button`.
* The icon becomes storyboard.
* `active-layer-kind-label` still shows storyboard state.
* Press the toggle again.
* The icon returns to animation.

### 4. Multiple layers show different icons

Create Layer B.

Toggle one layer to storyboard.

Verify:

* one layer has animation icon
* one layer has storyboard icon
* both layer names remain visible
* layer selection still works

### 5. Existing timeline tests continue to pass

Existing tests for:

* Add Layer
* active layer selection
* blank exposure X
* Storyboard toggle max-one rule
* undo/redo
* cut switching

must continue to pass.

## Out of scope

Do not implement any of the following in this phase:

* Do not add new `LayerKind` values.
* Do not add Sound Layer.
* Do not add Camera Layer.
* Do not add Rough Layer.
* Do not add Guide Layer.
* Do not add layer sections.
* Do not add vertical timesheet UI.
* Do not add Storyboard Panel UI.
* Do not add Conte Panel UI.
* Do not add actionMemo UI.
* Do not add dialogueMemo UI.
* Do not change `CutMetadata`.
* Do not change `StoryboardFrameMetadata`.
* Do not change layer naming rules.
* Do not change new Cut/new Layer default exposure behavior.
* Do not change internal timeline indexing.
* Do not change renderer/canvas/brush systems.
* Do not add Provider/Riverpod/Bloc/ChangeNotifier.
* Do not redesign the whole timeline.

## Acceptance criteria

This phase is complete when:

* Every visible layer row shows a layer type icon to the left of the layer name.
* Animation layers show the animation icon.
* Storyboard layers show the storyboard icon.
* Toggling layer kind updates the icon.
* Existing timeline controls still work.
* Existing keys remain stable.
* New icon keys are added.
* Tests cover animation icon, storyboard icon, and toggle icon update.
* No Sound/Camera/Section/Vertical Timesheet work is included.

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

* Changed files.
* Which icon was chosen for animation layers.
* Which icon was chosen for storyboard layers.
* Where the icon is rendered.
* New keys added.
* Accessibility/semantic label behavior.
* Tests added or updated.
* Confirmation that no new LayerKind values were added.
* Confirmation that Sound/Camera/Section/Timesheet work was not added.
* Results of:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
