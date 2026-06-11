# Phase 73 Codex Task - Storyboard Layer Kind Basic UI MVP

Create this file first:

docs/Phase_73_Codex_Task.md

Paste this full Phase 73 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Small UI integration phase.

Goal:

Add a minimal UI action for changing a Layer between:

* LayerKind.animation
* LayerKind.storyboard

This should use the existing Phase 72 command path:

* CutCommandCoordinator.updateLayerKind(...)
* UpdateLayerKindCommand
* HistoryManager undo/redo

This phase should not add storyboard memo editing UI.

Current state:

* Layer has LayerKind.
* LayerKind has animation and storyboard.
* Frame has StoryboardFrameMetadata.
* StoryboardFrameMetadata has actionMemo, dialogueMemo, and note.
* UpdateLayerKindCommand exists.
* CutCommandCoordinator.updateLayerKind exists.
* CutMetadata remains note-only.
* Existing UI has Cut-level actions and Cut Note UI.
* Storyboard / Conte panel UI does not exist yet.

Phase 73 should add the smallest practical UI bridge to mark a layer as storyboard or animation.

Important product intent:

Storyboard Layer is not a separate Cut.storyboardLayer panel list.

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

A Storyboard Layer should still use normal Layer / Frame / Stroke drawing behavior.

Target layer selection rule:

Use existing active/selected Layer if the project already has an active layer concept.

If the app does not yet have a proper active layer selection system:

* Do not build a full layer selection system in this phase.
* Use the first Layer of the active Cut as the temporary MVP target.
* Keep that targeting logic small and local.
* Add tests documenting this behavior.

Required UI behavior:

Add a small visible action that lets the user toggle the target layer kind.

Preferred button behavior:

If target layer is LayerKind.animation:

* show an action to mark it as Storyboard Layer

If target layer is LayerKind.storyboard:

* show an action to mark it as Animation Layer

Button text / tooltip:

Preferred tooltip:

* "Toggle Storyboard Layer"

Preferred key:

* ValueKey<String>('toggle-storyboard-layer-button')

If using separate labels:

* "Make Storyboard Layer"
* "Make Animation Layer"

But keep the key stable:

* toggle-storyboard-layer-button

Placement:

Use the safest existing UI location.

Preferred:

* near existing top action row / toolbar
* or near existing layer/canvas controls if present

Do not create a large new panel.

Do not create a Layer Inspector.

Do not create a Storyboard Panel.

Do not create a Conte Panel.

Command usage:

The UI must call:

CutCommandCoordinator.updateLayerKind(...)

Do not mutate ProjectRepository directly from UI.

Expected behavior:

When the button is pressed:

* determine active Cut
* determine target Layer
* call CutCommandCoordinator.updateLayerKind with the opposite kind
* refresh UI using existing local setState / refresh pattern
* Undo should restore previous LayerKind
* Redo should reapply new LayerKind

No-op behavior:

If no active Cut exists:

* button should be disabled or do nothing safely

If active Cut has no Layers:

* button should be disabled or do nothing safely

If target Layer kind is animation:

* button should be enabled
* pressing changes it to storyboard

If target Layer kind is storyboard:

* button should be enabled
* pressing changes it to animation

Visual feedback:

Minimum required:

* button tooltip exists
* after toggle, UI text/tooltip/label should reflect the new state if practical

Preferred minimal visible label:

* show "Animation Layer" or "Storyboard Layer" somewhere near the button

Suggested key for label:

* ValueKey<String>('active-layer-kind-label')

If adding a label is too much, tests may inspect model state instead.

Undo/Redo:

Existing Undo/Redo buttons should work after toggling layer kind.

Required:

* Toggle to storyboard
* Undo returns to animation
* Redo returns to storyboard

Also test reverse:

* Toggle storyboard to animation
* Undo returns to storyboard
* Redo returns to animation

Data preservation:

Toggling LayerKind must not delete or change:

* frames
* strokes
* frame names
* frame duration
* Frame.storyboardMetadata
* timeline
* marks
* visibility
* opacity
* CutMetadata

Testing requirements:

Add focused widget tests.

Likely files:

test/widget_test.dart

Possibly files:

test/ui/layer_kind_toggle_test.dart
test/ui/home_page_test.dart

Exact file names may vary.

Required widget tests:

1. toggle button is visible

Expected:

* find.byKey(ValueKey('toggle-storyboard-layer-button')) finds one widget

2. toggles animation layer to storyboard

Given active Cut has a LayerKind.animation target layer.

Tap button.

Expected:

* target Layer.kind becomes LayerKind.storyboard
* UI refreshes

3. toggles storyboard layer back to animation

Given target layer is LayerKind.storyboard.

Tap button.

Expected:

* target Layer.kind becomes LayerKind.animation

4. Undo/Redo works after toggling to storyboard

Tap toggle.

Undo.

Redo.

Expected:

* LayerKind changes accordingly
* activeCutId remains unchanged

5. Undo/Redo works after toggling to animation

If target starts as storyboard:

Tap toggle.

Undo.

Redo.

Expected:

* LayerKind changes accordingly
* activeCutId remains unchanged

6. no active Cut safety

If possible with current test helpers:

* no crash
* button disabled or no mutation

7. no layer safety

Given active Cut has no layers:

* no crash
* button disabled or no mutation

8. preserves Frame.storyboardMetadata

Given target layer has Frame.storyboardMetadata.

Tap toggle.

Expected:

* metadata still exists unchanged

9. preserves strokes

Given target layer has a frame with strokes.

Tap toggle.

Expected:

* strokes unchanged

10. no future UI

Ensure these are not present:

* Storyboard Panel
* Conte Panel
* Cut Inspector
* actionMemo text field
* dialogueMemo text field
* panelNote field
* StoryboardFrameMetadata editor

Required command path test:

In widget test, prefer verifying result via model state and undo/redo.

Do not rely on repository direct mutation.

If mocks/spies are not currently used, do not introduce a large mocking framework just for this phase.

Out of scope:

Do not add Storyboard Panel UI.

Do not add Conte Panel UI.

Do not add Layer Inspector.

Do not add Cut Inspector.

Do not add metadata side panel.

Do not add persistent storyboard panel.

Do not add actionMemo UI.

Do not add dialogueMemo UI.

Do not add note UI for StoryboardFrameMetadata.

Do not add frame-header memo UI.

Do not add storyboard frame editor.

Do not add drawing UI changes.

Do not add thumbnail rendering.

Do not add image import.

Do not add storyboard canvas.

Do not add Cut status.

Do not add priority.

Do not add assignee.

Do not add dueDate.

Do not add retakeCount.

Do not add checkedBy.

Do not add Cut canvas size.

Do not add drawable area.

Do not add drawing area scale.

Do not add Project camera size.

Do not add camera/framing.

Do not add renderer changes.

Do not add tile engine changes.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 74 or later.

Architecture rules:

UI must call CutCommandCoordinator.updateLayerKind.

UI must not call ProjectRepository.updateLayerKind directly.

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

Changing LayerKind should not delete Frames.

Changing LayerKind should not delete Frame.storyboardMetadata.

Frame storyboard metadata belongs to Frame, not CutMetadata.

CutMetadata remains note-only.

actionMemo and dialogueMemo are not CutMetadata fields.

actionMemo and dialogueMemo belong to StoryboardFrameMetadata.

No StoryboardFrameMetadata editing UI yet.

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the UI-facing command entry point.

Expected changed files:

Likely changed files:

lib/src/ui/home_page.dart
test/widget_test.dart

Possibly changed files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/layer/layer_kind_toggle_button.dart
test/ui/layer_kind_toggle_button_test.dart

Avoid touching unrelated files.

Do not change command files unless a tiny missing helper is needed.

Do not change model files unless required by tests.

Do not change renderer/canvas code.

Required checks for Codex:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* UI location of the toggle button
* button key
* target layer selection rule used
* confirmation that UI calls CutCommandCoordinator.updateLayerKind
* confirmation that toggling animation to storyboard works
* confirmation that toggling storyboard to animation works
* confirmation that undo/redo works
* confirmation that Frame.storyboardMetadata is preserved
* confirmation that strokes are preserved
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo UI was not added
* confirmation that no Storyboard Panel UI or Conte Panel UI was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 73 is complete when:

1. A visible toggle action exists.
2. Toggle button has key ValueKey<String>('toggle-storyboard-layer-button').
3. Toggle action targets existing active/selected layer if available.
4. If no active layer system exists, toggle targets first layer of active Cut as temporary MVP.
5. Toggle animation -> storyboard works.
6. Toggle storyboard -> animation works.
7. UI calls CutCommandCoordinator.updateLayerKind.
8. UI does not mutate ProjectRepository directly.
9. Undo after toggle works.
10. Redo after undo works.
11. activeCutId remains unchanged.
12. no active Cut case is safe.
13. no Layer case is safe.
14. Frame.storyboardMetadata is preserved.
15. Frame.strokes are preserved.
16. Layer.timeline is preserved.
17. Layer.marks are preserved.
18. Layer visibility/opacity are preserved.
19. CutMetadata remains note-only.
20. actionMemo is not added to CutMetadata.
21. dialogueMemo is not added to CutMetadata.
22. No StoryboardFrameMetadata editing UI is added.
23. No Storyboard Panel UI is added.
24. No Conte Panel UI is added.
25. No Cut Inspector is added.
26. No Cut canvas size is added.
27. No drawable area is added.
28. No renderer/tile/camera changes are added.
29. No broad state-management framework is introduced.
30. Existing Cut create/rename/duplicate/delete/reorder behavior still works.
31. Existing Cut Note UI tests still pass.
32. Existing Layer/Frame/Stroke tests still pass.
33. Existing command tests still pass.
34. dart format lib test completes.
35. flutter analyze passes.
36. flutter test passes.
37. git status is clean after commit.

Manual check guidance after merge:

After merge, manually check:

* app launches
* Cut list still appears
* Cut creation still works
* Cut rename still works
* Cut duplicate still works
* Cut delete still works
* Cut drag reorder still works
* Edit Cut Note still works
* toggle storyboard layer button appears
* pressing toggle switches target layer to storyboard
* pressing again switches target layer to animation
* Undo / Redo works after toggle
* no actionMemo field appears in UI
* no dialogueMemo field appears in UI
* no Conte Panel appears
* no Storyboard Panel appears
