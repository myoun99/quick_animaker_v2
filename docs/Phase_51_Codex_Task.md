# Phase 51 Codex Task - Cut Command Contract Test Hardening

## Create this file first

Create this file in the repository:

docs/Phase_51_Codex_Task.md

Paste this full Phase 51 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_51_Codex_Task.md
git commit -m "Add Phase 51 Codex task"
git push
git status

Do not run dart format on this Markdown document.

## Repository

myoun99/quick_animaker_v2

## Base branch

master

## Project type

Flutter / Dart

## Phase type

Code/test hardening phase.

This is not a UI phase.

## Goal

Add focused Cut command contract tests before starting Cut management UI work.

Phases 46 through 50 added the core undoable Cut commands:

- CreateCutCommand
- RenameCutCommand
- DeleteCutCommand
- DuplicateCutCommand

Phase 51 should lock down the shared behavior of those commands with tests.

The main purpose is to make sure the command layer is stable before any UI starts calling these commands.

## Primary implementation task

Create this test file:

test/commands/cut_command_contract_test.dart

If the existing repository already has a more appropriate nearby test folder or naming pattern, follow the existing pattern.

However, keep the purpose the same:

Cut command contract tests.

Do not create UI.

Do not wire these commands into the app UI.

Do not change save/load.

Do not introduce new architecture.

## Background

QuickAnimaker v2.1 is a Flutter / Dart project for a TVPaint-style bitmap 2D animation program.

The core model hierarchy is:

Project
Track
Cut
Layer
Frame
Stroke

The project is being developed in small numbered phases.

Current completed phase status:

- Phases 0 through 50 are complete.
- Phase 50 added Undoable DuplicateCutCommand.
- Local checks were clean after Phase 50.

Known current Cut command state:

- CreateCutCommand exists.
- RenameCutCommand exists.
- DeleteCutCommand exists.
- DuplicateCutCommand exists.
- ProjectRepository has Cut mutation primitives.
- EditingSessionState owns activeCutId.
- HistoryManager owns undo/redo command history.
- Undo/redo is volatile and must not be saved.

## Important architecture rules

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

ProjectRepository primitives must not manage:

- activeCutId
- undo/redo
- controller retargeting
- UI behavior

EditingSessionState owns activeCutId.

activeCutId is session state, not Project data.

After any user-level Cut command completes, activeCutId must never point to a missing Cut.

HistoryManager records undoable and redoable command history.

Undo/redo is volatile.

Undo/redo stack must not be saved to project files.

CutId is the true identity of a Cut.

Cut name is only a display label.

Duplicate Cut names are allowed.

Cut rename must not block duplicate names.

This is different from the Frame name/material policy.

Frame name/material policy must not be weakened.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

## Required test area 1 - activeCutId safety after execute

Add tests verifying that after each user-level Cut command executes, EditingSessionState.activeCutId never points to a missing Cut.

Cover at least:

- create Cut
- rename Cut
- duplicate Cut
- delete inactive Cut
- delete active Cut with previous fallback
- delete active Cut with next fallback
- delete the last remaining Cut

Expected behavior:

- activeCutId remains valid after every command.
- If deleting the active Cut, fallback order is:
    1. previous Cut
    2. next Cut
    3. newly-created default Cut
- Deleting the last Cut is allowed from the user's perspective.
- Internally, deleting the last Cut should immediately create a new default empty Cut.
- The app must not end with zero editable Cuts.

## Required test area 2 - activeCutId safety after undo

Add tests verifying that undo also leaves activeCutId valid.

Cover at least:

- undo create Cut
- undo rename Cut
- undo delete Cut
- undo duplicate Cut
- undo delete last remaining Cut replacement case, if supported by the current implementation

Expected behavior:

- undo must not leave activeCutId pointing to a missing Cut.
- if a command restores a previous active Cut, that Cut must exist.
- if a command cannot restore a previous active Cut because of the command's established semantics, it must still choose a valid Cut.

Do not redesign command behavior in this phase unless a test exposes an actual bug in the intended policy.

## Required test area 3 - activeCutId safety after redo

Add tests verifying that redo also leaves activeCutId valid.

Cover at least:

- redo create Cut
- redo rename Cut
- redo delete Cut
- redo duplicate Cut

Expected behavior:

- redo must produce the same valid state as the original execute path.
- activeCutId must not point to a removed Cut.

## Required test area 4 - Cut rename duplicate-name policy

Add or strengthen tests proving that Cut names are display labels only.

Required assertions:

- renaming a Cut to the same display name as another Cut is allowed.
- duplicate Cut names do not merge Cuts.
- duplicate Cut names do not change CutIds.
- duplicate Cut names do not affect Frame material/link policy.

Important distinction:

Cut name policy is different from Frame name/material policy.

Cut rename is only a display-label change.

Frame rename may imply material identity/linking.

Do not weaken the existing Frame rename/linking policy.

## Required test area 5 - Duplicate Cut independent-copy policy

Add or strengthen command-level tests for DuplicateCutCommand proving that the duplicate is independent.

Required assertions:

- duplicate receives a new CutId.
- duplicated layers receive new LayerIds.
- duplicated frames receive new FrameIds.
- timeline drawing exposures point to the remapped FrameIds.
- blank/X exposures are preserved.
- authored timeline placement is preserved.
- exposure durations are preserved.
- canvas size is preserved.
- strokes/material content is copied independently.
- editing duplicate content should not mutate the source Cut.
- editing source content should not mutate the duplicate Cut.

If lower-level helper tests already cover some of this, Phase 51 may add command-level tests that verify the command correctly uses that helper and applies repository/session behavior.

Avoid duplicating every helper test mechanically.

Focus on command-level contract coverage.

## Required test area 6 - repository boundary expectations

Add tests or assertions proving that command-level active Cut behavior is not pushed into ProjectRepository.

Expected policy:

- ProjectRepository owns project data mutation.
- ProjectRepository does not own activeCutId.
- repository primitives do not manage undo/redo.
- repository primitives do not retarget controllers.
- repository primitives do not manage UI.

This can be verified through command tests rather than adding new repository APIs.

## Important analyzer rule

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

This issue happened before after Phase 50, so be careful.

## Out of scope

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

Do not implement Phase 52 or later.

## Implementation notes

Prefer small, readable tests over one large all-in-one test.

Use existing test fixture helpers if available.

If new fixture helpers are needed, keep them test-only and narrowly scoped.

Do not create production helper APIs unless the tests reveal repeated setup that already belongs in production.

Do not change command public APIs unless necessary to fix a real bug.

Do not change behavior just to make tests easier.

If an intended contract is ambiguous, document the assumption in the test name and keep the behavior aligned with the existing phase policy.

## Expected changed files

Likely changed files:

test/commands/cut_command_contract_test.dart

Possibly changed files if an intended-policy bug is found:

lib/src/commands/...
test/commands/...

Avoid touching unrelated files.

## Required checks for Codex

Because this is a code/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

## Required Codex report

After implementation, report:

- changed files
- confirmation that this is test/command hardening only
- confirmation that no UI was added
- confirmation that no save/load or JSON schema changes were made
- analyze result
- test result
- git status summary

## Acceptance criteria

Phase 51 is complete when:

1. Cut command contract tests are added.
2. Tests cover execute / undo / redo activeCutId safety.
3. Tests cover duplicate Cut names as allowed display labels.
4. Tests cover command-level independent duplicate behavior.
5. No UI is added.
6. No save/load or JSON schema behavior is changed.
7. No broad architecture or state-management framework is introduced.
8. dart format lib test completes.
9. flutter analyze passes.
10. flutter test passes.
11. git status is clean after commit.

## Manual check guidance after merge

No major Android Studio manual UI check is required because this phase should not add UI.

After the PR is merged and local checks pass, optionally open the app once from Android Studio and verify:

- the app still launches.
- existing drawing/timeline UI still appears.
- existing Cut switching/sample Cut behavior is not visibly broken.
- no new Cut management UI appears yet.

If any UI behavior changes, treat it as suspicious unless directly explained by a necessary bug fix.

## Short instruction to send to Codex

Implement Phase 51 only.

Use docs/Phase_51_Codex_Task.md as the source of truth.

This is a code/test hardening phase.

Add focused Cut command contract tests, likely in:

test/commands/cut_command_contract_test.dart

Do not add UI.

Do not change save/load or JSON schema.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 52 or later.

Be careful not to use const map literals with LayerId or FrameId keys.

After implementation, run:

dart format lib test
flutter analyze
flutter test
git status

Then report changed files, scope confirmation, analyze result, test result, and git status summary.