# Phase 76 Codex Task - Horizontal Layer Display Adapter Foundation

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
    * New Cut and new Layer start with blank exposure at visible frame 1.
    * Internal timeline indexing remains zero-based.
    * A Cut may have at most one Storyboard Layer.
    * New Layer insertion appears above the active/target layer in the horizontal timeline.

* Phase 75:

    * Horizontal timeline layer rows show LayerKind icons.
    * `LayerKind.animation` has an animation/drawing icon.
    * `LayerKind.storyboard` has a storyboard icon.
    * Icon keys use `timeline-layer-kind-icon-<layerId>`.
    * Existing animation/storyboard toggle updates the icon.

Current issue:
The horizontal timeline still receives the raw layer list directly from the controller.

This keeps these concepts too tightly coupled:

* model/data order
* horizontal timeline display order
* future vertical timesheet display order
* future section display order
* new layer insertion order

The long-term design requires these concepts to stay separate.

## Phase goal

Introduce a small horizontal timeline layer display adapter.

This phase should preserve the current UI behavior exactly.

The goal is to create a safe place where future phases can later map layers into:

* Main Section
* Sound Section
* Camera Section
* vertical timesheet columns

But this phase must not implement those sections yet.

## What this phase should build

Add a small adapter/helper that converts the current active Cut's layers into the list used by the horizontal timeline.

For now, the adapter should return the same visible order as today.

This is a foundation phase.

## Required behavior

### 1. Add a horizontal layer display adapter

Create a new file such as:

```text
lib/src/ui/timeline/layer_timeline_display_adapter.dart
```

or another clearly named file under `lib/src/ui/timeline/`.

The adapter should expose a small function such as:

```dart
List<Layer> horizontalLayerDisplayOrder(List<Layer> layers)
```

or a similarly clear name.

For now, it must:

* preserve the current order
* not mutate the input list
* return a defensive list/copy
* preserve the same Layer object references
* support empty layer lists

### 2. Use the adapter from HomePage / TimelinePanel wiring

Where the current horizontal timeline receives the layer list, route the list through the adapter first.

Current behavior should remain visually unchanged.

Example intent:

```dart
final horizontalLayers = horizontalLayerDisplayOrder(_layerController.layers);
```

Then pass `horizontalLayers` to the timeline panel.

The actual implementation may vary depending on the current code structure.

### 3. Do not change insertion behavior

Phase 74 behavior must remain:

* new layers insert above the active/target layer
* new layers become active
* Add Layer first creates B above A
* layer names remain Cut-local A/B/C...

The adapter must not undo or reverse this behavior.

### 4. Do not change compositing behavior

This phase is only about timeline display preparation.

Do not change renderer/compositor/canvas behavior.

Do not reinterpret the order as compositing order.

### 5. Do not introduce sections yet

Do not add:

* Main Section UI
* Sound Section UI
* Camera Section UI
* section headers
* section rows
* collapsible sections
* section models
* section persistence

This phase only introduces the adapter foundation.

### 6. Do not add new LayerKind values

Do not add:

* sound
* cameraControl
* cameraDirection
* rough
* guide

Only existing LayerKinds should remain:

* animation
* storyboard

### 7. Keep existing keys stable

Do not remove or rename existing keys.

Important keys that must remain stable include:

```text
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

### 8. Add focused unit tests for the adapter

Add tests for the adapter.

Suggested file:

```text
test/ui/layer_timeline_display_adapter_test.dart
```

Test cases:

1. Empty list returns empty list.
2. One layer returns one layer.
3. Multiple layers preserve current order.
4. Returned list is not the same list instance as the input.
5. Returned list contains the same Layer object references.
6. Mutating the returned list does not mutate the original input list.
7. Animation and storyboard layers are both preserved.
8. No sorting by name occurs.
9. No sorting by LayerKind occurs.
10. Existing order such as `[B, A]` stays `[B, A]`.

### 9. Add or update widget tests

Existing widget tests should continue to pass.

Add or update a small widget test only if needed to ensure the horizontal timeline still shows layers in the same order after the adapter is introduced.

Suggested verification:

* Initial state still shows Layer A.
* Add Layer creates B above A.
* B remains above A.
* B remains active.
* Layer kind icons still appear.

Do not over-expand widget tests unless necessary.

## Out of scope

Do not implement any of the following:

* Sound Layer
* Camera Layer
* Rough Layer
* Guide Layer
* new LayerKind values
* Main/Sound/Camera Section UI
* section headers
* section collapse/expand
* vertical timesheet UI
* timesheet columns
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
* project persistence changes
* Provider/Riverpod/Bloc/ChangeNotifier
* any broad UI redesign

## Acceptance criteria

This phase is complete when:

* A horizontal timeline layer display adapter exists.
* HomePage or the timeline wiring uses the adapter before passing layers to the horizontal timeline UI.
* Current visual layer order remains unchanged.
* Add Layer behavior remains unchanged.
* Layer kind icons from Phase 75 still work.
* Existing keys remain stable.
* No new LayerKind values are added.
* No Sound/Camera/Section/Timesheet work is added.
* Unit tests cover the adapter behavior.
* Existing tests continue to pass.

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
* Adapter file/function name.
* Where the adapter is used.
* Confirmation that the current visual order is unchanged.
* Confirmation that Add Layer still inserts B above A.
* Confirmation that LayerKind icons still work.
* Confirmation that no new LayerKind values were added.
* Confirmation that no Sound/Camera/Section/Vertical Timesheet UI was added.
* Tests added or updated.
* Results of:

    * `dart format lib test`
    * `flutter analyze`
    * `flutter test`
    * `git status`
