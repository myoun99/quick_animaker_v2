# Phase 52 Codex Task - Cut Command Export Organization

Create this file first:

docs/Phase_52_Codex_Task.md

Paste this full Phase 52 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_52_Codex_Task.md
git commit -m "Add Phase 52 Codex task"
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

Small code/test organization phase.

This is not a UI phase.

Goal:

Create a small, stable export surface for the Cut command layer before future UI integration.

Phases 46 through 51 added and hardened these Cut commands:

- CreateCutCommand
- RenameCutCommand
- DeleteCutCommand
- DuplicateCutCommand

Phase 52 should make these commands easier and safer to import from future UI/controller integration code.

The goal is command organization only.

Do not add new behavior.

Do not add UI.

Do not wire commands into existing widgets.

Do not change save/load.

Do not change JSON schema.

Do not redesign command, repository, or history architecture.

Primary implementation task:

Add a Cut command barrel export file.

Recommended file:

lib/src/services/commands/cut_commands.dart

This file should export only the current user-level Cut commands:

- create_cut_command.dart
- rename_cut_command.dart
- delete_cut_command.dart
- duplicate_cut_command.dart

Expected contents should be simple exports only.

Example direction:

export 'create_cut_command.dart';
export 'rename_cut_command.dart';
export 'delete_cut_command.dart';
export 'duplicate_cut_command.dart';

If the existing repository has a better established naming pattern for barrel files, follow that pattern, but keep the purpose the same.

Do not move existing command files.

Do not rename existing command files.

Do not change command public APIs.

Do not replace existing imports across the app unless there is already an obvious nearby command-layer test where doing so improves the export coverage.

Avoid broad import churn.

Required test task:

Add a small compile/export coverage test proving that the new barrel file exposes the expected command types.

Recommended file:

test/services/commands/cut_commands_export_test.dart

If the existing test folder organization suggests a better nearby location, follow the existing pattern.

The test should import:

package:quick_animaker_v2/src/services/commands/cut_commands.dart

The test should verify that the following types are available from the barrel import:

- CreateCutCommand
- RenameCutCommand
- DeleteCutCommand
- DuplicateCutCommand

This test is only for export surface coverage.

Do not duplicate the Phase 51 behavior tests.

Do not add command execution behavior tests in this phase unless needed to make the export test compile cleanly.

Keep the test small.

Background and architecture rules:

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

activeCutId is session state, not Project data.

HistoryManager owns undo/redo command history.

Undo/redo is volatile and must not be saved to project files.

CutId is the true identity of a Cut.

Cut name is only a display label.

Duplicate Cut names are allowed.

Frame name/material policy must not be weakened.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

Important analyzer rule:

Do not use const map literals with LayerId or FrameId keys.

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

Do not implement Phase 53 or later.

Expected changed files:

Likely changed files:

lib/src/services/commands/cut_commands.dart
test/services/commands/cut_commands_export_test.dart

Possibly changed files only if existing project structure clearly requires it:

test/services/commands/...

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
- confirmation that this is command export organization only
- confirmation that no UI was added
- confirmation that no save/load or JSON schema changes were made
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 52 is complete when:

1. A Cut command barrel export file exists.
2. The barrel exports CreateCutCommand.
3. The barrel exports RenameCutCommand.
4. The barrel exports DeleteCutCommand.
5. The barrel exports DuplicateCutCommand.
6. A small export coverage test exists.
7. Existing command behavior is not changed.
8. No UI is added.
9. No save/load or JSON schema behavior is changed.
10. No broad architecture or state-management framework is introduced.
11. dart format lib test completes.
12. flutter analyze passes.
13. flutter test passes.
14. git status is clean after commit.

Manual check guidance after merge:

No major Android Studio manual UI check is required because this phase should not add UI or runtime behavior.

After the PR is merged and local checks pass, optional manual check:

- app still launches
- existing drawing/timeline UI still appears
- existing Cut list/sample Cut behavior is not visibly broken
- no new Cut management UI appears
- no visible behavior changed