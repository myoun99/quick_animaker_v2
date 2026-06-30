# Phase 71 Codex Task - Storyboard Frame Metadata Command Foundation

Create this file first:

docs/Phase_71_Codex_Task.md

Paste this full Phase 71 task document into that file.

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

Add undoable command support for updating Frame-level storyboard metadata.

Current corrected design:

* Storyboard Layer is a normal Layer with LayerKind.storyboard.
* Storyboard Layer uses the existing Layer / Frame / Stroke structure.
* Frames inside a storyboard layer can behave like storyboard/conte panels.
* Frame has StoryboardFrameMetadata.
* StoryboardFrameMetadata contains actionMemo, dialogueMemo, and note.
* CutMetadata remains Cut-level note-only metadata.
* actionMemo and dialogueMemo are not CutMetadata fields.

Phase 71 should add command-layer support for updating StoryboardFrameMetadata on a Frame.

Do not add UI.

Do not add Storyboard Panel UI.

Do not add Conte Panel UI.

Do not add Cut Inspector.

Required command:

Add an undoable command.

Preferred command class:

UpdateStoryboardFrameMetadataCommand

Suggested file:

lib/src/services/commands/update_storyboard_frame_metadata_command.dart

Inputs:

* ProjectRepository repository
* CutId cutId
* LayerId layerId
* FrameId frameId
* StoryboardFrameMetadata metadata

Behavior:

* Find target Cut by CutId.
* Find target Layer by LayerId.
* Find target Frame by FrameId.
* Replace only frame.storyboardMetadata.
* Preserve Frame.id.
* Preserve Frame.duration.
* Preserve Frame.name.
* Preserve Frame.strokes.
* Preserve Layer.id.
* Preserve Layer.name.
* Preserve Layer.kind.
* Preserve Layer.timeline.
* Preserve Layer.marks.
* Preserve Layer visibility/opacity.
* Preserve CutMetadata.
* Preserve Cut canvasSize.
* Preserve all other Cuts, Layers, Frames, and Strokes.
* Do not change activeCutId.
* Command itself should not know about UI.

LayerKind rule:

Preferred behavior:

* Allow updating storyboardMetadata only when target Layer.kind == LayerKind.storyboard.

If target Layer.kind == LayerKind.animation:

* throw StateError

Reason:

StoryboardFrameMetadata is intended for storyboard/conte layers.

However, because Frame now technically has storyboardMetadata regardless of layer kind, this rule is enforced at command level.

Undo:

* Restore previous StoryboardFrameMetadata.

Redo:

* Reapply new StoryboardFrameMetadata.

Missing target behavior:

* Missing Cut should throw StateError.
* Missing Layer should throw StateError.
* Missing Frame should throw StateError.

No-op behavior:

Preferred coordinator behavior:

* If new metadata equals current metadata, skip and do not create a history entry.

The command itself may still be executable if called directly.

Repository support:

Add a small repository helper if needed.

Preferred helper:

ProjectRepository.updateFrameStoryboardMetadata({
required CutId cutId,
required LayerId layerId,
required FrameId frameId,
required StoryboardFrameMetadata metadata,
})

Expected helper behavior:

* Find target Cut.
* Find target Layer.
* Find target Frame.
* Replace only that Frame's storyboardMetadata.
* Preserve all other data.
* Throw StateError if Cut/Layer/Frame not found.

Alternative acceptable helper:

ProjectRepository.replaceFrameInLayer(...)

or a more general helper if consistent with existing repository style.

Keep repository changes small.

Do not redesign ProjectRepository.

Coordinator integration:

Add a method to CutCommandCoordinator if consistent with current architecture.

Preferred method:

updateStoryboardFrameMetadata({
required CutId cutId,
required LayerId layerId,
required FrameId frameId,
required StoryboardFrameMetadata metadata,
})

Behavior:

* Resolve current target.
* If target metadata is unchanged, skip and do not add a history entry.
* If target layer is not LayerKind.storyboard, follow the command/repository error behavior.
* Otherwise execute UpdateStoryboardFrameMetadataCommand through HistoryManager.

Do not add UI.

Do not let UI mutate repository directly.

Command barrel export:

If command barrel exists:

lib/src/services/commands/cut_commands.dart

Export:

* UpdateStoryboardFrameMetadataCommand

Update export tests if they exist.

Testing requirements:

Add focused command, repository, and coordinator tests.

Likely files:

test/services/commands/update_storyboard_frame_metadata_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart
test/services/project_repository_test.dart

Exact files may vary.

Required command tests:

1. execute updates storyboard metadata on target Frame

Given:

* Cut with LayerKind.storyboard layer
* Frame with empty storyboardMetadata

Execute command with metadata:

* actionMemo
* dialogueMemo
* note

Expected:

* target Frame.storyboardMetadata updated
* Frame.id preserved
* Frame.duration preserved
* Frame.name preserved
* Frame.strokes preserved
* Layer.kind preserved
* CutMetadata preserved

2. undo restores previous storyboard metadata

After execute:

* undo restores previous StoryboardFrameMetadata

3. redo reapplies new storyboard metadata

After undo:

* redo reapplies new metadata

4. replacing existing metadata works

Given Frame has old storyboardMetadata.

Execute command with new metadata.

Expected:

* new metadata applied
* undo restores old metadata

5. missing Cut throws

6. missing Layer throws

7. missing Frame throws

8. animation Layer is rejected

Given target Layer.kind == LayerKind.animation.

Execute command.

Expected:

* throws StateError
* no mutation

9. unrelated data is preserved

Given multiple Cuts / Layers / Frames.

Execute command on one frame.

Expected:

* other Cuts unchanged
* other Layers unchanged
* other Frames unchanged
* strokes unchanged

Required repository tests if helper is added:

1. updateFrameStoryboardMetadata replaces only metadata

2. missing Cut throws

3. missing Layer throws

4. missing Frame throws

5. preserves Layer.kind

6. preserves strokes

Required coordinator tests:

1. updateStoryboardFrameMetadata routes through HistoryManager

Expected:

* undoCount increases by 1
* undo restores old metadata
* redo reapplies new metadata

2. unchanged metadata is skipped

Expected:

* undoCount does not increase

3. activeCutId remains unchanged

If test can access EditingSessionState, verify activeCutId remains unchanged.

Otherwise verify CanvasView / active Cut indicator remains unchanged in existing style if a widget-level test is already practical.

4. animation Layer rejection propagates safely

Required export test:

If command barrel export test exists, include UpdateStoryboardFrameMetadataCommand.

Required scope tests:

1. CutMetadata remains note-only

Ensure CutMetadata.toJson contains only:

* note

2. LayerKind remains unchanged

Ensure LayerKind still has:

* animation
* storyboard

3. No UI added

This may be covered by absence of UI changes, but existing widget tests should continue to pass.

Out of scope:

Do not add UI.

Do not add Storyboard Layer UI.

Do not add Storyboard Frame UI.

Do not add Conte Panel UI.

Do not add Storyboard Panel UI.

Do not add Cut Inspector.

Do not add metadata side panel.

Do not add persistent storyboard panel.

Do not add Edit Storyboard Frame button.

Do not add actionMemo UI.

Do not add dialogueMemo UI.

Do not add panelNote UI.

Do not add Cut note UI changes.

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

Do not implement Phase 72 or later.

Architecture rules:

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

Storyboard Frame metadata belongs to Frame, not CutMetadata.

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are not CutMetadata fields.

actionMemo and dialogueMemo belong to StoryboardFrameMetadata.

UpdateStoryboardFrameMetadataCommand must not know about UI.

UpdateStoryboardFrameMetadataCommand must not know about renderer.

UpdateStoryboardFrameMetadataCommand must not know about canvas size.

UpdateStoryboardFrameMetadataCommand must not know about drawable area.

UpdateStoryboardFrameMetadataCommand must not know about camera/framing.

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

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/services/commands/update_storyboard_frame_metadata_command.dart
lib/src/services/commands/cut_command_coordinator.dart
lib/src/services/commands/cut_commands.dart
lib/src/services/project_repository.dart
test/services/commands/update_storyboard_frame_metadata_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart
test/services/project_repository_test.dart

Possibly changed files:

test/models/cut_metadata_test.dart
test/models/layer_kind_test.dart

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
* confirmation that storyboard frame metadata update is undoable
* confirmation that redo works
* confirmation that unchanged metadata is skipped without history entry if implemented
* confirmation that animation layers are rejected
* confirmation that Frame.strokes are preserved
* confirmation that Layer.kind is preserved
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added to CutMetadata
* confirmation that no UI was added
* confirmation that no Storyboard Panel UI or Conte Panel UI was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 71 is complete when:

1. UpdateStoryboardFrameMetadataCommand exists.
2. Command updates target Frame.storyboardMetadata.
3. Command preserves Frame.id.
4. Command preserves Frame.duration.
5. Command preserves Frame.name.
6. Command preserves Frame.strokes.
7. Command preserves Layer.kind.
8. Command preserves Layer timeline and marks.
9. Command preserves CutMetadata.
10. Command undo restores previous metadata.
11. Command redo reapplies new metadata.
12. Command rejects missing Cut.
13. Command rejects missing Layer.
14. Command rejects missing Frame.
15. Command rejects animation Layer targets.
16. Repository helper exists if needed and is tested.
17. Coordinator method exists if implemented.
18. Coordinator routes through HistoryManager.
19. Coordinator skips unchanged metadata if implemented.
20. Command barrel exports command if applicable.
21. CutMetadata remains note-only.
22. actionMemo is not added to CutMetadata.
23. dialogueMemo is not added to CutMetadata.
24. No UI is added.
25. No Storyboard Frame UI is added.
26. No Storyboard Panel UI is added.
27. No Conte Panel UI is added.
28. No Cut canvas size is added.
29. No drawable area is added.
30. No renderer/tile/camera changes are added.
31. No broad state-management framework is introduced.
32. Existing Cut create/rename/duplicate/delete/reorder behavior still works.
33. Existing Cut Note UI tests still pass.
34. Existing Layer/Frame/Stroke tests still pass.
35. dart format lib test completes.
36. flutter analyze passes.
37. flutter test passes.
38. git status is clean after commit.

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
