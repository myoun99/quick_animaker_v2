# Phase 53 Codex Task - Cut Command Input Planning Helpers

Create this file first:

docs/Phase_53_Codex_Task.md

Paste this full Phase 53 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_53_Codex_Task.md
git commit -m "Add Phase 53 Codex task"
git push
git status

Do not run dart format on this Markdown document.

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Small code/test preparation phase.

This is not a UI phase.

Goal:

Add pure helper logic for planning Cut command input IDs before future Cut management UI integration.

Current Cut commands intentionally require caller-provided IDs and maps:

- CreateCutCommand needs a new CutId and LayerId.
- DeleteCutCommand may need replacement CutId and replacement LayerId when deleting the last Cut.
- DuplicateCutCommand needs a new CutId, a LayerId remap, and a FrameId remap.

That design is good because commands stay deterministic and undoable.

However, future UI should not directly contain ID planning and remap planning logic.

Phase 53 should add small, pure, well-tested helper functions that prepare command input IDs and maps.

Do not execute commands in these helpers.

Do not add UI.

Do not wire commands into widgets.

Do not change command behavior.

Do not change save/load.

Do not change JSON schema.

Primary implementation task:

Add a helper file for Cut command input planning.

Recommended file:

lib/src/services/commands/cut_command_input_planner.dart

If the existing project structure suggests a better nearby location or naming pattern, follow it, but keep the purpose the same.

The helper should be pure and deterministic.

It should not mutate ProjectRepository.

It should not mutate Project.

It should not mutate EditingSessionState.

It should not use HistoryManager.

It should not access UI.

It should not use random IDs.

It should not use DateTime-based IDs.

It should not use package imports for UUID generation.

Recommended helper responsibilities:

1. Plan IDs for CreateCutCommand.

Given a Project, return a new CutId and a new LayerId suitable for creating a default Cut.

Suggested return type:

CreateCutCommandInputPlan

Suggested fields:

- cutId
- layerId

Suggested function name:

planCreateCutCommandInput

2. Plan IDs for DeleteCutCommand last-Cut replacement.

Given a Project, return a replacement CutId and replacement LayerId suitable for DeleteCutCommand when deleting the final remaining Cut.

Suggested return type:

DeleteLastCutReplacementInputPlan

Suggested fields:

- replacementCutId
- replacementLayerId

Suggested function name:

planDeleteLastCutReplacementInput

3. Plan IDs and maps for DuplicateCutCommand.

Given a Project and source Cut, return:

- new CutId
- layerIdMap
- frameIdMap

Suggested return type:

DuplicateCutCommandInputPlan

Suggested fields:

- newCutId
- layerIdMap
- frameIdMap

Suggested function name:

planDuplicateCutCommandInput

The duplicate planning helper must inspect the source Cut and include every source LayerId and every source FrameId in the returned maps.

The returned maps must not use const map literals with LayerId or FrameId keys.

ID allocation policy:

Use deterministic first-available IDs.

Recommended default ID prefixes:

- cut
- layer
- frame

Recommended generated ID format:

- cut-1
- cut-2
- cut-3
- layer-1
- layer-2
- layer-3
- frame-1
- frame-2
- frame-3

The helper should scan existing IDs in the whole Project and return the first available ID for each prefix.

The helper should not generate IDs based on Cut names or Frame names.

The helper should avoid collisions across the whole Project, not just inside one Cut.

This is safer for future Linked Layer, cross-cut linked paste, and project-level material/source direction.

If the existing project already has an ID planning or allocation pattern, follow the existing pattern instead, but keep the same acceptance criteria.

Important:

This phase only prepares command input values.

It must not create, insert, remove, rename, duplicate, or reorder Cuts by itself.

Commands remain responsible for mutation.

ProjectRepository remains responsible for project data mutation.

EditingSessionState remains responsible for activeCutId.

HistoryManager remains responsible for undo/redo.

Required tests:

Add tests for the new helper.

Recommended file:

test/services/commands/cut_command_input_planner_test.dart

If the existing test structure suggests a better nearby path, follow it.

Required test coverage:

1. Create Cut input planning

Verify that planCreateCutCommandInput:

- returns a CutId that does not already exist in the Project
- returns a LayerId that does not already exist in the Project
- uses deterministic first-available IDs
- does not mutate the Project

Example scenario:

Existing IDs:

- cut-1
- cut-2
- layer-1
- layer-3

Expected result:

- next CutId should be cut-3
- next LayerId should be layer-2

If the final implemented ID algorithm differs because of an existing project convention, update the exact expected values accordingly while preserving deterministic first-available behavior.

2. Delete last Cut replacement input planning

Verify that planDeleteLastCutReplacementInput:

- returns a replacement CutId that does not already exist
- returns a replacement LayerId that does not already exist
- uses deterministic first-available IDs
- does not mutate the Project

3. Duplicate Cut input planning

Verify that planDuplicateCutCommandInput:

- returns a new CutId that does not already exist
- returns a layerIdMap containing every LayerId from the source Cut
- returns a frameIdMap containing every FrameId from every source Layer in the source Cut
- maps every source LayerId to a different new LayerId
- maps every source FrameId to a different new FrameId
- does not map two different source LayerIds to the same new LayerId
- does not map two different source FrameIds to the same new FrameId
- avoids IDs that already exist elsewhere in the Project
- does not mutate the Project

4. Empty source Cut duplicate planning

Verify that a source Cut with no layers:

- still gets a new CutId
- returns an empty layerIdMap
- returns an empty frameIdMap
- does not throw

5. Source Cut with layers but no frames

Verify that a source Cut with layers but no frames:

- gets a new CutId
- maps every LayerId
- returns an empty frameIdMap
- does not throw

6. Analyzer safety

Ensure tests do not use const map literals with LayerId or FrameId keys.

Bad:

layerIdMap: const {LayerId('a'): LayerId('b')}
frameIdMap: const {FrameId('a'): FrameId('b')}

Good:

layerIdMap: {
const LayerId('a'): const LayerId('b'),
}

frameIdMap: {
const FrameId('a'): const FrameId('b'),
}

Reason:

LayerId and FrameId override == / hashCode, so Dart analyzer reports:

const_map_key_not_primitive_equality

Export surface:

Update the Phase 52 Cut command barrel only if appropriate.

If the new helper belongs as part of the command preparation surface, update:

lib/src/services/commands/cut_commands.dart

to export:

cut_command_input_planner.dart

Do this only if it fits the existing organization.

If you export it, add or update export coverage tests accordingly.

Do not create broad barrel files outside the command area.

Architecture rules:

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

ProjectRepository primitives must not manage:

- activeCutId
- undo/redo
- controller retargeting
- UI behavior

EditingSessionState owns activeCutId.

activeCutId is session state, not Project data.

HistoryManager owns undo/redo command history.

Undo/redo is volatile and must not be saved to project files.

CutId is the true identity of a Cut.

Cut name is only a display label.

Duplicate Cut names are allowed.

Cut rename must not block duplicate names.

Frame name/material policy must not be weakened.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

Out of scope:

Do not implement any UI.

Specifically do not add:

- Cut management panel
- Cut switching UI
- Cut create/delete/rename/duplicate buttons
- menu commands
- keyboard shortcuts
- timeline integration
- controller retargeting UI behavior

Do not execute commands from UI.

Do not change existing command behavior.

Do not change existing command public APIs unless absolutely necessary.

Do not implement save/load changes.

Specifically do not add:

- JSON schema changes
- persisted undo/redo
- persisted command history
- persisted lastActiveCutId

Do not add:

- Provider
- Riverpod
- Bloc
- ChangeNotifier
- broad state-management framework changes

Do not implement:

- Cut reorder
- Linked Cut
- Linked Layer
- cross-cut linked frames
- project-level material pool
- Conte Panel
- Conte Layer
- Camera Layer
- Audio Layer

Do not replace hardcoded sample cuts in this phase.

Do not implement Phase 54 or later.

Expected changed files:

Likely changed files:

lib/src/services/commands/cut_command_input_planner.dart
test/services/commands/cut_command_input_planner_test.dart

Possibly changed files:

lib/src/services/commands/cut_commands.dart
test/services/commands/cut_commands_export_test.dart

Avoid touching unrelated files.

Required checks for Codex:

Because this is a code/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is command input planning only
- confirmation that no UI was added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no command behavior was changed
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 53 is complete when:

1. Pure Cut command input planning helpers are added.
2. CreateCutCommand input planning is covered by tests.
3. DeleteCutCommand last-Cut replacement input planning is covered by tests.
4. DuplicateCutCommand input planning is covered by tests.
5. Duplicate planning maps every source LayerId and FrameId.
6. Planned IDs are deterministic and avoid existing Project IDs.
7. Helpers do not mutate ProjectRepository, Project, EditingSessionState, or HistoryManager.
8. No UI is added.
9. Existing command behavior is not changed.
10. No save/load or JSON schema behavior is changed.
11. No broad architecture or state-management framework is introduced.
12. dart format lib test completes.
13. flutter analyze passes.
14. flutter test passes.
15. git status is clean after commit.

Manual check guidance after merge:

No major Android Studio manual UI check is required because this phase should not add UI or runtime behavior.

After the PR is merged and local checks pass, optional manual check:

- app still launches
- existing drawing/timeline UI still appears
- existing Cut list/sample Cut behavior is not visibly broken
- no new Cut management UI appears
- no visible behavior changed