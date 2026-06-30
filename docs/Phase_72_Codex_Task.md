# Phase 72 Codex Task - Layer Kind Command Foundation

Create this file first:

docs/Phase_72_Codex_Task.md

Paste this full Phase 72 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Command foundation phase.

This is not a UI phase.

Goal:

Add undoable command support for changing a Layer's kind.

Current corrected design:

* Storyboard Layer is a normal Layer with LayerKind.storyboard.
* Animation Layer is a normal Layer with LayerKind.animation.
* Storyboard Layer uses the existing Layer / Frame / Stroke structure.
* Frame has StoryboardFrameMetadata.
* StoryboardFrameMetadata contains actionMemo, dialogueMemo, and note.
* CutMetadata remains Cut-level note-only metadata.
* actionMemo and dialogueMemo are not CutMetadata fields.
* UpdateStoryboardFrameMetadataCommand already exists and only works on LayerKind.storyboard layers.

Phase 72 should add command-layer support for changing Layer.kind.

This enables future UI to convert a normal animation layer into a storyboard/conte layer without directly mutating the repository.

Do not add UI.

Do not add Storyboard Layer UI.

Do not add Conte Panel UI.

Required command:

Add an undoable command.

Preferred command class:

UpdateLayerKindCommand

Suggested file:

lib/src/services/commands/update_layer_kind_command.dart

Inputs:

* ProjectRepository repository
* CutId cutId
* LayerId layerId
* LayerKind kind

Behavior:

* Find target Cut by CutId.
* Find target Layer by LayerId within that Cut.
* Replace only Layer.kind.
* Preserve Layer.id.
* Preserve Layer.name.
* Preserve Layer.frames.
* Preserve Layer.timeline.
* Preserve Layer.marks.
* Preserve Layer.isVisible.
* Preserve Layer.opacity.
* Preserve all Frame data.
* Preserve Frame.storyboardMetadata.
* Preserve CutMetadata.
* Preserve all other Cuts, Layers, Frames, and Strokes.
* Do not change activeCutId.
* Command itself should not know about UI.

Undo:

* Restore previous LayerKind.

Redo:

* Reapply new LayerKind.

Missing target behavior:

* Missing Cut should throw StateError.
* Missing Layer should throw StateError.

No-op behavior:

Preferred coordinator behavior:

* If new LayerKind equals current Layer.kind, skip and do not create a history entry.

The command itself may still be executable if called directly.

Repository support:

Add a small repository helper if needed.

Preferred helper:

ProjectRepository.updateLayerKind({
required CutId cutId,
required LayerId layerId,
required LayerKind kind,
})

Expected helper behavior:

* Find target Cut.
* Find target Layer within that Cut.
* Replace only Layer.kind.
* Preserve all other data.
* Throw StateError if Cut/Layer not found.

Keep repository changes small.

Do not redesign ProjectRepository.

Coordinator integration:

Add a method to CutCommandCoordinator if consistent with current architecture.

Preferred method:

updateLayerKind({
required CutId cutId,
required LayerId layerId,
required LayerKind kind,
})

Behavior:

* Resolve current target Layer.
* If target kind is unchanged, skip and do not add a history entry.
* Otherwise execute UpdateLayerKindCommand through HistoryManager.

Do not add UI.

Do not let UI mutate repository directly.

Command barrel export:

If command barrel exists:

lib/src/services/commands/cut_commands.dart

Export:

* UpdateLayerKindCommand

Update export tests if they exist.

Testing requirements:

Add focused command, repository, and coordinator tests.

Likely files:

test/services/commands/update_layer_kind_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart
test/services/project_repository_test.dart

Exact files may vary.

Required command tests:

1. execute changes animation layer to storyboard

Given:

* Cut with LayerKind.animation layer

Execute command with LayerKind.storyboard.

Expected:

* target Layer.kind becomes LayerKind.storyboard
* frames preserved
* timeline preserved
* marks preserved
* visibility/opacity preserved
* Frame.storyboardMetadata preserved
* CutMetadata preserved

2. execute changes storyboard layer back to animation

Given:

* Cut with LayerKind.storyboard layer

Execute command with LayerKind.animation.

Expected:

* target Layer.kind becomes LayerKind.animation
* Frame.storyboardMetadata is still preserved

Important:

Changing a layer back to animation should not erase Frame.storyboardMetadata in this phase.

Reason:

Data loss should be avoided. If the user changes back later, metadata can still be reused.

3. undo restores previous LayerKind

After execute:

* undo restores old kind.

4. redo reapplies new LayerKind

After undo:

* redo reapplies new kind.

5. missing Cut throws

6. missing Layer throws

7. unrelated data is preserved

Given multiple Cuts / Layers / Frames.

Execute command on one layer.

Expected:

* other Cuts unchanged
* other Layers unchanged
* other Frames unchanged
* strokes unchanged

Required repository tests if helper is added:

1. updateLayerKind replaces only kind

2. missing Cut throws

3. missing Layer throws

4. preserves frames

5. preserves Frame.storyboardMetadata

6. preserves Layer timeline / marks / visibility / opacity

Required coordinator tests:

1. updateLayerKind routes through HistoryManager

Expected:

* undoCount increases by 1
* undo restores previous kind
* redo reapplies new kind

2. unchanged kind is skipped

Expected:

* undoCount does not increase

3. activeCutId remains unchanged

Required export test:

If command barrel export test exists, include UpdateLayerKindCommand.

Required scope tests:

1. LayerKind remains stable

Ensure LayerKind still has:

* animation
* storyboard

2. CutMetadata remains note-only

Ensure CutMetadata.toJson contains only:

* note

3. StoryboardFrameMetadata remains Frame-level

No changes needed, but existing tests should continue to pass.

Out of scope:

Do not add UI.

Do not add Storyboard Layer UI.

Do not add Storyboard Frame UI.

Do not add Conte Panel UI.

Do not add Storyboard Panel UI.

Do not add Cut Inspector.

Do not add metadata side panel.

Do not add persistent storyboard panel.

Do not add Edit Storyboard Layer button.

Do not add Convert Layer button.

Do not add actionMemo UI.

Do not add dialogueMemo UI.

Do not add panelNote UI.

Do not change Cut Note UI.

Do not add drawing UI for storyboard layers.

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

Do not implement Phase 73 or later.

Architecture rules:

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

LayerKind belongs to Layer.

Frame storyboard metadata belongs to Frame, not CutMetadata.

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are not CutMetadata fields.

actionMemo and dialogueMemo belong to StoryboardFrameMetadata.

UpdateLayerKindCommand must not know about UI.

UpdateLayerKindCommand must not know about renderer.

UpdateLayerKindCommand must not know about canvas size.

UpdateLayerKindCommand must not know about drawable area.

UpdateLayerKindCommand must not know about camera/framing.

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the UI-facing command entry point.

CutId remains the true identity of a Cut.

LayerId remains the true identity of a Layer.

FrameId remains the true identity of a Frame.

Cut name remains a display label.

Layer name remains a display label.

Frame name remains material/link identity within a layer.

Duplicate Cut names remain allowed.

Changing Layer.kind should not delete Frames.

Changing Layer.kind should not delete Frame.storyboardMetadata.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/services/commands/update_layer_kind_command.dart
lib/src/services/commands/cut_command_coordinator.dart
lib/src/services/commands/cut_commands.dart
lib/src/services/project_repository.dart
test/services/commands/update_layer_kind_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart
test/services/project_repository_test.dart

Possibly changed files:

test/models/layer_kind_test.dart
test/models/cut_metadata_test.dart
docs/Design_CutMetadata_CanvasPlanning.md

Avoid touching unrelated files.

Do not change UI files.

Do not change save/load code.

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
* new command class name
* repository helper name, if added
* coordinator method name, if added
* confirmation that Layer.kind update is undoable
* confirmation that redo works
* confirmation that unchanged kind is skipped without history entry if implemented
* confirmation that Frame.storyboardMetadata is preserved
* confirmation that Layer timeline/marks are preserved
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added to CutMetadata
* confirmation that no UI was added
* confirmation that no Storyboard Layer UI or Conte Panel UI was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 72 is complete when:

1. UpdateLayerKindCommand exists.
2. Command updates target Layer.kind.
3. Command can change animation to storyboard.
4. Command can change storyboard to animation.
5. Command preserves Layer.id.
6. Command preserves Layer.name.
7. Command preserves Layer.frames.
8. Command preserves Layer.timeline.
9. Command preserves Layer.marks.
10. Command preserves Layer.isVisible.
11. Command preserves Layer.opacity.
12. Command preserves Frame.storyboardMetadata.
13. Command preserves CutMetadata.
14. Command undo restores previous kind.
15. Command redo reapplies new kind.
16. Command rejects missing Cut.
17. Command rejects missing Layer.
18. Repository helper exists if needed and is tested.
19. Coordinator method exists if implemented.
20. Coordinator routes through HistoryManager.
21. Coordinator skips unchanged kind if implemented.
22. Command barrel exports command if applicable.
23. CutMetadata remains note-only.
24. actionMemo is not added to CutMetadata.
25. dialogueMemo is not added to CutMetadata.
26. No UI is added.
27. No Storyboard Layer UI is added.
28. No Storyboard Frame UI is added.
29. No Storyboard Panel UI is added.
30. No Conte Panel UI is added.
31. No Cut canvas size is added.
32. No drawable area is added.
33. No renderer/tile/camera changes are added.
34. No broad state-management framework is introduced.
35. Existing Cut create/rename/duplicate/delete/reorder behavior still works.
36. Existing Cut Note UI tests still pass.
37. Existing Layer/Frame/Stroke tests still pass.
38. Existing StoryboardFrameMetadata tests still pass.
39. dart format lib test completes.
40. flutter analyze passes.
41. flutter test passes.
42. git status is clean after commit.

Manual check guidance after merge:

This phase should not change visible UI.

After merge, manually check:

* app launches
* Cut list still appears
* Cut creation still works
* Cut rename still works
* Cut duplicate still works
* Cut delete still works
* Cut drag reorder still works
* Edit Cut Note still works
* Undo / Redo still work
* no actionMemo field appears in UI
* no dialogueMemo field appears in UI
* no Conte Panel appears
* no Storyboard Panel appears
