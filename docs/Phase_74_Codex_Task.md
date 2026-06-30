# Phase 74 Codex Task - Layer Defaults and Storyboard Layer Rule Correction

Create this file first:

docs/Phase_74_Codex_Task.md

Paste this full Phase 74 task document into that file.

Before implementing, read these documents first:

docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Timesheet_Layer_Sections.md
docs/Design_CutMetadata_CanvasPlanning.md
docs/Phase_69_Codex_Task.md
docs/Phase_70_Codex_Task.md
docs/Phase_71_Codex_Task.md
docs/Phase_72_Codex_Task.md
docs/Phase_73_Codex_Task.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Small domain/controller/command rule correction phase.

This is not a broad UI phase.

Goal:

Correct the current Layer default behavior before building more storyboard, layer icon, sound, camera, or timesheet UI.

Phase 74 must establish these rules:

1. A Cut may have at most one Storyboard Layer.
2. Main visual layer default names use Japanese cel-style names:
   A, B, C, ..., Z, AA, AB, AC, ...
3. Layer name generation is Cut-local.
4. New Cut default Layer name is A.
5. New Cut default Layer starts with blank exposure on visible frame 1.
6. New Layer default name is the smallest available cel name in that Cut.
7. New Layer default exposure starts with blank exposure on visible frame 1.
8. Do not create automatic C2-style drawing frame names for new Cut / new Layer defaults.
9. New Layer insertion in the current horizontal timeline should be above the active/target layer, not appended below by accident.
10. Do not add Sound or Camera sections yet.
11. Do not add Layer type icon UI yet.
12. Do not add Storyboard Panel / Conte Panel / actionMemo / dialogueMemo UI yet.

Important indexing note:

The current internal timeline frame index is zero-based.

Therefore:

* visible frame 1 == internal timeline index 0
* visible frame 2 == internal timeline index 1
* visible frame 3 == internal timeline index 2

When this phase says:

index 1 = x

it means:

* visible frame 1 displays x
* internal timeline map contains:
  0: TimelineExposure.blank()

Do not convert the whole internal timeline system to one-based indexing in this phase.

Do not rewrite TimelineController indexing.

Do not rewrite timeline widgets to use one-based internal indexes.

Required behavior:

## 1. Add or update default layer helper logic

Add a small helper for default layer creation and cel-style naming.

Preferred location:

lib/src/controllers/default_layer_helpers.dart

Alternative acceptable location:

lib/src/controllers/default_cut_helpers.dart

Keep this small.

Required functions may include, but do not have to use exactly these names:

* celLayerNameForIndex(int index)
* nextCelLayerNameForCut(Cut cut)
* createDefaultAnimationLayer(...)
* createDefaultMainLayer(...)

The exact names may follow project style, but the behavior must be clear and tested.

Cel name generation rule:

0 -> A
1 -> B
2 -> C
...
25 -> Z
26 -> AA
27 -> AB
28 -> AC
...
51 -> AZ
52 -> BA

This is similar to spreadsheet column naming, but zero-based at the function boundary.

Cut-local naming rule:

Layer names must be generated from layers inside the target Cut only.

Example:

Cut 1 has:
A
B
C
D
E

Cut 2 has no layers.

Creating a layer in Cut 2 must create:

A

Wrong:

F

Smallest available name rule:

If a Cut already has:

A
B
D

The next created default layer should be:

C

Storyboard Layer naming:

Storyboard Layer is still a normal Layer in the Main Section.

If a storyboard layer has a cel-style name, that name counts as used inside the Cut.

Example:

Cut has:
A animation
B storyboard
D animation

Next default layer name:

C

Do not introduce special storyboard names such as Storyboard 1 in this phase.

Do not introduce sound/camera naming in this phase.

## 2. New Cut default Layer rule

Update createDefaultCut behavior.

Current wrong behavior to remove:

* default layer named "Layer 1"
* default layer with no exposure

Required new behavior:

New Cut:

* has one default Layer
* default Layer name is A
* default Layer kind is LayerKind.animation
* default Layer has no drawing Frame by default
* default Layer timeline has blank exposure at internal index 0
* visible frame 1 should show x / blank exposure

Expected layer shape:

Layer(
name: 'A',
kind: LayerKind.animation,
frames: const [],
timeline: const {0: TimelineExposure.blank()},
)

Do not create a default drawing Frame.

Do not create a Frame named C2.

Do not create any automatic drawing frame name for the default blank exposure.

Cut duration should remain small and safe.

Do not change canvas size behavior in this phase.

Do not change CutMetadata.

## 3. New Layer default rule

Update LayerController.addLayerWithDefaults and all current call sites that create a default layer.

Current behavior may still pass names like:

Layer 2
Layer 3

This should be replaced.

Required new behavior:

When adding a new Layer to a Cut:

* name is generated Cut-locally
* name uses the smallest available cel-style name
* kind defaults to LayerKind.animation
* frames is empty
* timeline contains blank exposure at internal index 0
* visible frame 1 displays x / blank exposure
* new Layer becomes active after insertion

Example:

Cut has:

A
B
D

Add Layer:

C

Example:

Cut has:

A
B
C

Add Layer:

D

Example:

Cut 1 has:

A
B
C
D

Cut 2 has:

A

Adding a layer to Cut 2 creates:

B

Do not use a project-global layer counter for visible Layer names.

IDs can still use the existing project-level ID generation policy.

LayerId and Layer.name are separate concepts.

LayerId may remain globally unique.

Layer.name must be Cut-local display label.

## 4. New Layer insertion rule

The current horizontal timeline renders layers in list order.

For Phase 74, define and implement this current simple rule:

* Insert new default Layer before the active Layer in the Cut.layers list.
* If there is no active Layer, insert at index 0.
* If the active Layer is missing, fall back safely to index 0.
* Newly inserted Layer becomes active.
* Do not append new layers to the end by accident.

Reason:

In the current horizontal timeline, list order is the current visible row order.

Inserting before the active Layer makes the new row appear above the current/target row.

This is a small current-rule correction.

Do not implement a full data/display/compositing adapter in this phase.

Do not implement vertical timesheet display adapters in this phase.

Do not implement Camera/Sound/Main section adapters in this phase.

Do not redesign renderer compositing order in this phase.

Implementation guidance:

ProjectRepository may get an insertLayer helper:

insertLayer({
required CutId cutId,
required Layer layer,
int? index,
})

Existing addLayer may delegate to insertLayer with append behavior for backward compatibility, or be updated carefully if tests allow.

AddLayerCommand may accept an optional insertion index.

LayerController should compute the insertion index based on activeLayerId:

* if activeLayerId is found in layers, insert at that index
* otherwise insert at 0

Keep undo/redo behavior working.

The existing AddLayerCommand snapshot-based undo behavior may remain if consistent with current style.

## 5. Storyboard Layer maximum-one rule

A Cut may have at most one LayerKind.storyboard layer.

Required rule:

When changing a layer from animation to storyboard:

* if the target layer is already storyboard, no-op behavior remains unchanged
* if another layer in the same Cut is already LayerKind.storyboard, reject the change
* rejection should throw StateError in command/repository level
* no project mutation should occur

When changing a layer from storyboard to animation:

* allow it
* this removes the storyboard layer status from that Cut
* do not delete Frame.storyboardMetadata
* do not delete frames
* do not delete strokes
* do not delete timeline
* do not delete marks

Where to enforce:

Enforce the rule in the safest shared path.

Preferred:

* ProjectRepository.updateLayerKind rejects duplicate storyboard layer creation
* UpdateLayerKindCommand is tested for the rejection
* CutCommandCoordinator.updateLayerKind keeps no-op skip behavior

Acceptable:

* UpdateLayerKindCommand performs preflight and rejects before mutation
* repository also stays safe if small enough

Do not rely only on UI.

UI should not be the only enforcement point.

Legacy multiple storyboard layers:

Do not add automatic migration in Phase 74.

If an old or manually created project already contains multiple storyboard layers:

* loading should not fail because of this phase
* do not sanitize or delete layers automatically
* do not rewrite old data automatically
* new attempts to convert another animation layer to storyboard should still be rejected
* changing an existing storyboard layer back to animation should be allowed

Do not remove or merge existing storyboard layers automatically.

## 6. Existing Storyboard/Conte metadata rules must remain unchanged

Keep the corrected Phase 69-73 direction:

* Storyboard Layer is a normal Layer with LayerKind.storyboard.
* Storyboard Layer uses existing Layer / Frame / Stroke structure.
* Frame.storyboardMetadata remains Frame-level.
* StoryboardFrameMetadata has actionMemo, dialogueMemo, and note.
* CutMetadata remains Cut-level note-only metadata.
* actionMemo and dialogueMemo must not be added to CutMetadata.
* Storyboard Panel UI does not exist yet.
* Conte Panel UI does not exist yet.

Do not add:

* Cut.storyboardLayer
* StoryboardLayer model attached to Cut
* StoryboardPanel list attached to Cut
* Cut.storyboardLayer.panels
* actionMemo on CutMetadata
* dialogueMemo on CutMetadata

## 7. Existing UI should remain minimal

This phase may adjust existing Add Layer behavior and existing Storyboard Layer toggle safety.

Allowed small UI adjustments:

* Add Layer button can now create A/B/C-style layers.
* Add Layer button can now insert above active layer.
* Existing Storyboard Layer toggle can be disabled when target layer cannot become storyboard because another storyboard layer already exists.
* Existing label can remain the same.
* Existing button key must remain unchanged:
  ValueKey<String>('toggle-storyboard-layer-button')
* Existing active layer kind label key must remain unchanged:
  ValueKey<String>('active-layer-kind-label')
* Existing add layer button keys should remain unchanged:
  ValueKey<String>('timeline-toolbar-add-layer-button')
  ValueKey<String>('timeline-add-layer-button')

Do not add new large UI.

Do not add Layer Inspector.

Do not add Storyboard Panel.

Do not add Conte Panel.

Do not add actionMemo / dialogueMemo editor.

Do not add Layer type icons.

Do not add Sound/Camera sections.

Do not add vertical timesheet view changes.

## 8. Tests required

Add focused tests.

Likely files:

test/controllers/default_cut_helpers_test.dart
test/controllers/default_layer_helpers_test.dart
test/controllers/layer_controller_test.dart
test/services/project_repository_test.dart
test/services/commands/add_layer_command_test.dart
test/services/commands/update_layer_kind_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/widget_test.dart

Exact file names may vary.

Required tests:

### Default cut tests

1. createDefaultCut creates Layer A

Given createDefaultCut(...)

Expected:

* cut.layers.length == 1
* cut.layers.first.name == 'A'
* cut.layers.first.kind == LayerKind.animation

2. createDefaultCut starts with blank exposure at visible frame 1

Expected internal model:

* cut.layers.first.timeline[0] == const TimelineExposure.blank()
* cut.layers.first.frames is empty

3. createDefaultCut does not create C2 or any drawing frame

Expected:

* no Frame exists by default
* no default frame.name exists

### Cel layer name tests

4. celLayerNameForIndex produces A/B/C/Z/AA/AB/BA

Required examples:

* 0 -> A
* 1 -> B
* 25 -> Z
* 26 -> AA
* 27 -> AB
* 52 -> BA

5. negative cel index throws

Expected:

* celLayerNameForIndex(-1) throws ArgumentError or StateError

6. nextCelLayerNameForCut is Cut-local

Given two Cuts:

Cut 1 layers:
A
B
C

Cut 2 layers:
A

Expected:

* next name for Cut 1 is D
* next name for Cut 2 is B

7. nextCelLayerNameForCut fills smallest missing name

Given:

A
B
D

Expected:

C

8. storyboard layer names count as used

Given:

A animation
B storyboard
D animation

Expected:

C

### New layer default tests

9. LayerController.addLayerWithDefaults creates next cel name

Given active Cut with A and B.

Add layer with defaults.

Expected:

* new layer name is C
* new layer kind is LayerKind.animation

10. LayerController.addLayerWithDefaults creates blank exposure at visible frame 1

Expected:

* new layer.timeline[0] == const TimelineExposure.blank()
* new layer.frames is empty

11. New layer becomes active

Expected:

* layerController.activeLayerId == newLayerId

12. Add Layer inserts above active layer

Given Cut.layers:

A
B
C

Active layer:

B

Add layer with defaults.

Expected list order:

A
D
B
C

If D is the next available cel name.

13. Add Layer with no active layer inserts at index 0

Given active layer is null or missing.

Add layer.

Expected:

* inserted layer is cut.layers.first

14. Add Layer undo restores previous project

Given AddLayerCommand executes.

Undo.

Expected:

* layers return to previous order
* active layer behavior remains safe

### Storyboard layer max-one tests

15. UpdateLayerKindCommand allows animation -> storyboard when no storyboard exists

Given Cut with only animation layers.

Change A to storyboard.

Expected:

* A.kind == LayerKind.storyboard

16. UpdateLayerKindCommand rejects animation -> storyboard when another storyboard layer exists

Given Cut:

A storyboard
B animation

Try changing B to storyboard.

Expected:

* throws StateError
* A remains storyboard
* B remains animation
* frames/strokes/timeline/marks are unchanged

17. UpdateLayerKindCommand allows storyboard -> animation

Given:

A storyboard

Change A to animation.

Expected:

* A.kind == LayerKind.animation
* Frame.storyboardMetadata is preserved
* frames are preserved
* strokes are preserved

18. CutCommandCoordinator unchanged kind skip still works

Given target layer is already storyboard.

Call updateLayerKind with LayerKind.storyboard.

Expected:

* no new history entry

19. CutCommandCoordinator duplicate storyboard rejection does not create history entry if coordinator preflight is used

Given another storyboard layer exists.

Try changing animation layer to storyboard.

Expected:

* throws StateError
* history count does not increase

If current architecture makes this difficult, at minimum verify no mutation.

20. ProjectRepository.updateLayerKind preserves unrelated data

Given multiple Cuts / Layers / Frames.

Reject or update one layer.

Expected:

* unrelated Cuts unchanged
* unrelated Layers unchanged
* CutMetadata unchanged
* Frame.storyboardMetadata unchanged

### UI safety tests

21. Existing Storyboard toggle still toggles animation -> storyboard when allowed

Use existing button key:

ValueKey<String>('toggle-storyboard-layer-button')

Expected:

* target layer becomes storyboard

22. Existing Storyboard toggle can toggle storyboard -> animation

Expected:

* target layer becomes animation

23. Existing Storyboard toggle does not allow creating a second storyboard layer

Given active Cut has another storyboard layer and target is animation.

Expected:

* pressing button is disabled or safely does not mutate
* no crash
* only one storyboard layer remains

24. Existing Add Layer buttons use new default naming

Use existing keys if practical:

ValueKey<String>('timeline-toolbar-add-layer-button')
ValueKey<String>('timeline-add-layer-button')

Expected:

* pressing Add Layer creates next cel-style name
* no "Layer 2" / "Layer 3" default visible name appears for newly added default layers

25. Existing Add Layer buttons insert above active layer

Expected:

* new layer appears before active layer in the current horizontal timeline list order
* new layer becomes active if current behavior supports it

26. Existing timeline visible frame 1 shows X for blank default exposure

Given new Cut default layer or new Layer.

Expected:

* visible frame header 1 corresponds to internal index 0
* cell at internal index 0 is blankStart
* UI marker may display X according to existing marker behavior

Do not overbuild UI tests if current test helpers make this too expensive.

Prefer focused controller/model/command tests plus one or two widget smoke tests.

## 9. Out of scope

Do not add Sound Section.

Do not add Camera Section.

Do not add Main/Sound/Camera section model.

Do not add sound layer kinds.

Do not add cameraControl layer kind.

Do not add cameraDirection layer kind.

Do not add Layer type icon UI.

Do not add Storyboard Panel UI.

Do not add Conte Panel UI.

Do not add Layer Inspector.

Do not add Cut Inspector.

Do not add StoryboardFrameMetadata editor.

Do not add actionMemo UI.

Do not add dialogueMemo UI.

Do not add panelNote UI.

Do not add thumbnail rendering.

Do not add image import.

Do not add storyboard canvas.

Do not add Cut canvas size.

Do not add drawable area.

Do not add drawing area scale.

Do not add Project camera size.

Do not add camera/framing.

Do not add renderer changes.

Do not add tile engine changes.

Do not add vertical timesheet view.

Do not add timesheet display adapter.

Do not redesign compositing order.

Do not change internal timeline indexing from zero-based to one-based.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 75 or later.

## 10. Architecture rules

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

A Cut may have at most one Storyboard Layer for new mutations.

Legacy multiple storyboard layers should not be auto-deleted.

Layer name is a display label.

LayerId is identity.

Layer name generation is Cut-local.

LayerId generation may remain project-global.

New Cut default Layer is A.

New Layer default name is the smallest available A/B/C-style name inside the active Cut.

New Cut/New Layer blank exposure is internal timeline index 0, representing visible frame 1.

Do not create default drawing Frames for blank exposure.

Do not create C2-style automatic default frame names.

Frame name/material policy must not change.

Existing rule remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the UI-facing command entry point for Cut/layer kind command flow.

LayerController can remain the current layer-focused controller, but should not bypass undo/redo for adding layers.

## 11. Expected changed files

Likely changed files:

lib/src/controllers/default_cut_helpers.dart
lib/src/controllers/default_layer_helpers.dart
lib/src/controllers/layer_controller.dart
lib/src/services/project_repository.dart
lib/src/services/commands/add_layer_command.dart
lib/src/services/commands/update_layer_kind_command.dart
lib/src/services/commands/cut_command_coordinator.dart
lib/src/ui/home_page.dart
test/controllers/default_cut_helpers_test.dart
test/controllers/default_layer_helpers_test.dart
test/controllers/layer_controller_test.dart
test/services/project_repository_test.dart
test/services/commands/add_layer_command_test.dart
test/services/commands/update_layer_kind_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/widget_test.dart

Possibly changed files:

lib/src/ui/timeline/timeline_panel.dart
lib/src/ui/timeline/layer_timeline_grid.dart
test/ui/layer_timeline_grid_test.dart

Avoid touching unrelated files.

Do not change renderer/canvas code unless a test compile failure requires a tiny import-level adjustment.

Do not change save/load services except through existing model JSON behavior if tests require it.

## 12. Required checks for Codex

Run:

dart format lib test
flutter analyze
flutter test
git status

## 13. Required Codex report

After implementation, report:

* changed files
* new helper file/name if added
* cel layer naming function behavior
* confirmation that new Cut default Layer is A
* confirmation that new Cut default Layer has blank exposure at visible frame 1 / internal index 0
* confirmation that new Layer default names are Cut-local A/B/C style
* confirmation that smallest missing cel name is reused
* confirmation that new Layer default exposure is blank at visible frame 1 / internal index 0
* confirmation that no default C2-style drawing frame is created
* confirmation that new Layer inserts above active layer in current horizontal timeline order
* confirmation that new Layer becomes active
* confirmation that Storyboard Layer max-one rule is enforced
* confirmation that storyboard -> animation remains allowed
* confirmation that Frame.storyboardMetadata is preserved
* confirmation that frames/strokes/timeline/marks are preserved
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added to CutMetadata
* confirmation that no Sound/Camera Section was added
* confirmation that no Layer type icon UI was added
* confirmation that no Storyboard Panel UI or Conte Panel UI was added
* confirmation that no vertical timesheet view was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that internal timeline indexing remains zero-based
* analyze result
* test result
* git status summary

## 14. Acceptance criteria

Phase 74 is complete when:

1. createDefaultCut creates a default Layer named A.
2. createDefaultCut default Layer kind is LayerKind.animation.
3. createDefaultCut default Layer has timeline[0] == TimelineExposure.blank().
4. createDefaultCut default Layer has no drawing Frame by default.
5. createDefaultCut does not create C2-style frame names.
6. Cel layer naming supports A through Z and AA/AB style names.
7. Cel layer naming is Cut-local.
8. Smallest missing cel name is reused.
9. Storyboard Layer names count as used cel names.
10. New Layer with defaults uses Cut-local next cel name.
11. New Layer with defaults has timeline[0] == TimelineExposure.blank().
12. New Layer with defaults has no drawing Frame by default.
13. New Layer with defaults has LayerKind.animation.
14. New Layer inserts above active layer in the current list/visual timeline order.
15. New Layer inserts at index 0 if no active layer exists.
16. New Layer becomes active.
17. AddLayerCommand undo restores the previous project state.
18. UpdateLayerKindCommand allows animation -> storyboard when no storyboard layer exists in the Cut.
19. UpdateLayerKindCommand rejects animation -> storyboard when another storyboard layer already exists in the Cut.
20. Rejected duplicate storyboard conversion does not mutate project data.
21. storyboard -> animation remains allowed.
22. Frame.storyboardMetadata is preserved when changing layer kind.
23. Frames are preserved when changing layer kind.
24. Strokes are preserved when changing layer kind.
25. Timeline is preserved when changing layer kind.
26. Marks are preserved when changing layer kind.
27. CutMetadata remains note-only.
28. actionMemo is not added to CutMetadata.
29. dialogueMemo is not added to CutMetadata.
30. Existing Storyboard Layer toggle still works when allowed.
31. Existing Storyboard Layer toggle cannot create a second storyboard layer.
32. Existing Add Layer buttons create A/B/C-style default layers.
33. Existing Add Layer buttons no longer create visible "Layer 2" / "Layer 3" default names.
34. Existing visible frame 1 can show X for default blank exposure.
35. No Sound Section is added.
36. No Camera Section is added.
37. No Layer type icon UI is added.
38. No Storyboard Panel UI is added.
39. No Conte Panel UI is added.
40. No StoryboardFrameMetadata editor UI is added.
41. No actionMemo UI is added.
42. No dialogueMemo UI is added.
43. No vertical timesheet view is added.
44. No Cut canvas size is added.
45. No drawable area is added.
46. No renderer/tile/camera changes are added.
47. Internal timeline indexing remains zero-based.
48. Existing Cut create/rename/duplicate/delete/reorder behavior still works.
49. Existing Cut Note UI tests still pass.
50. Existing LayerKind toggle tests still pass.
51. Existing Layer/Frame/Stroke tests still pass.
52. dart format lib test completes.
53. flutter analyze passes.
54. flutter test passes.
55. git status is clean after commit.

## 15. Manual check guidance after merge

After merge, manually check:

* app launches
* Cut list still appears
* creating a new Cut creates Layer A
* new Cut visible frame 1 shows X / blank exposure
* Add Layer creates B if A exists
* Add Layer creates C if A/B exist
* Add Layer fills C when A/B/D exist
* Add Layer inserts above the active layer
* newly added layer becomes active
* toggle storyboard layer button still appears
* toggling animation -> storyboard works when no storyboard layer exists
* toggling storyboard -> animation works
* a second storyboard layer cannot be created in the same Cut
* Undo / Redo still works after Add Layer
* Undo / Redo still works after Storyboard Layer toggle
* Cut Note UI still works
* no actionMemo field appears in UI
* no dialogueMemo field appears in UI
* no Conte Panel appears
* no Storyboard Panel appears
* no Sound/Camera Section appears
