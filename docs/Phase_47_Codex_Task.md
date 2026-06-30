Phase 47 Codex Task
Task Title

Implement QuickAnimaker v2.1 Phase 47: Cut Rename Command MVP.

Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 46 are complete.

Recent completed work includes:

TimelinePanel-based timeline/cell editing UI
New Frame / Blank X / Mark ● / Rename / Delete / Exposure +/- actions
Timeline marks
X/null exposure
Linked Frame Copy/Paste MVP
Same-layer linked paste using shared FrameId
Linked frames share drawing material/source but do not share exposure duration
Exposure +/- operates on the selected authored timeline entry, not globally by FrameId
Rename Frame conflict policy:
Same frame name means same material
Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed
Conflict offers Link / Cancel only
Rename-only is intentionally not offered
Compact production-tool-like timeline UI
Product direction notes
Cut / Conte direction notes
Cut management policy notes
Cut management command design notes
Minimal Cut switching between existing sample cuts
Active-cut edit safety regression tests
Cut switching UX polish
Cut deletion fallback helper
Default Cut creation helper
ProjectRepository Cut insert/remove/rename primitives
Undoable Create Cut command

Read these documents before making changes:

docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Cut_Conte_Direction_Notes.md
docs/Cut_Management_Policy.md
docs/Cut_Management_Command_Design.md
docs/Phase_42_Codex_Task.md
docs/Phase_43_Codex_Task.md
docs/Phase_44_Codex_Task.md
docs/Phase_45_Codex_Task.md
docs/Phase_46_Codex_Task.md

This task implements only Phase 47.

Scope

Implement only Phase 47: Cut Rename Command MVP.

This is a small command and unit-test phase.

The goal is to add an undoable command for renaming an existing Cut.

This phase should not add Cut rename UI.

This phase should not add Cut management panel.

This phase should not add Cut delete/duplicate/reorder commands.

This phase should not change save/load schema.

This phase should not add Conte Panel or Conte Layer.

Main Goal

Add a future-UI-ready command that can rename a Cut display label and support undo/redo.

Expected behavior:

Rename an existing Cut through ProjectRepository.renameCut.
Use CutId, not current Cut name.
Allow duplicate Cut names.
Store the previous Cut name before execute.
Undo restores the previous Cut name.
Redo restores the new Cut name.
activeCutId should not change.

No UI should call this command yet.

Important Product Policy

Cut rename is different from Frame rename.

Frame rename policy:

Same frame name means same material within the same layer.
Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
Frame rename conflict should offer Link / Cancel only.

Cut rename policy:

Cut name is only a user-facing display label.
CutId is the real identity.
Duplicate Cut names are allowed.
Rename should not be blocked by duplicate Cut names.
Rename should not create links.
Rename should not show Link / Cancel conflict behavior.

Do not weaken existing Frame rename/material policy.

Do not apply Frame rename conflict logic to Cut rename.

Important Design Boundary

This phase should implement command-level behavior, not UI behavior.

The command may coordinate:

ProjectRepository
HistoryManager

The command should not need to coordinate:

EditingSessionState
activeCutId
controller rebuild / retarget

Reason:

Cut rename changes only the display name.
It does not change Cut identity.
It does not change activeCutId.
It does not change active-cut-scoped controller targets.

Do not directly depend on Flutter widgets.

Do not change HomePage.

Files To Inspect

Inspect at least:

lib/src/services/commands/
lib/src/services/commands/create_cut_command.dart
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/project_repository.dart
lib/src/controllers/editing_session_state.dart
lib/src/models/cut.dart
lib/src/models/cut_id.dart
test/services/create_cut_command_test.dart
test/services/project_repository_test.dart

Adapt file placement to the existing architecture.

Recommended File

Preferred new file if consistent with existing architecture:

lib/src/services/commands/rename_cut_command.dart

Recommended test file:

test/services/rename_cut_command_test.dart

If the project style prefers grouped command files, use that existing style instead.

Required Command Behavior

Add a command equivalent to RenameCutCommand implements Command.

Constructor direction:

ProjectRepository repository
CutId cutId
String newName

Required behavior:

Caller provides CutId.
Caller provides new Cut name.
Execute stores the previous Cut name.
Execute calls ProjectRepository.renameCut.
Undo restores the previous Cut name.
Redo through HistoryManager should reapply the new Cut name.
Duplicate Cut names are allowed.
activeCutId is not changed.
Layers, frames, timeline, duration, canvas size, and CutId are not changed.

Important:

Do not generate IDs.
Do not enforce unique Cut names.
Do not link Cuts.
Do not create linked layers.
Do not mutate timeline/canvas/layers.
Do not change save/load.
Previous Name Lookup

The command needs to know the previous name before renaming.

Preferred approach:

Add a small repository read helper if one already exists, reuse it.
If no suitable helper exists, add a minimal private command-side lookup by reading repository.requireProject().

Acceptable helper shape if added to ProjectRepository:

Cut requireCut(CutId cutId)
or Cut requireCutById(CutId cutId)

Only add this if consistent with existing repository style and useful for tests/future commands.

Do not add broad query APIs.

Do not refactor repository architecture.

HistoryManager Integration

Use the existing HistoryManager command pattern.

Expected behavior:

Renaming a Cut through the command should be undoable.
Undo should restore the previous Cut name.
Redo should restore the new Cut name.

If existing commands are executed through historyManager.execute(command), then tests should use the same pattern.

Do not redesign HistoryManager.

Do not add persistent history.

Do not save undo/redo stacks.

Error Behavior

Required behavior:

If CutId is missing, execute should throw StateError through lookup or ProjectRepository.renameCut.
If execute fails, project state should remain unchanged.
Undo before execute should either throw StateError or be safely disallowed according to existing command style.
Redo before execute should either throw StateError or be safely disallowed according to existing command style.

Follow existing command style, especially CreateCutCommand.

Part A: Add Command

Add the rename Cut command in the existing command architecture.

The command should:

find/store previous Cut name
rename through ProjectRepository.renameCut
support undo/redo

Keep it small.

Avoid UI dependencies.

Avoid Flutter widget dependencies.

Avoid save/load dependencies.

Part B: Add Unit Tests

Add command tests.

Required test coverage:

execute renames the target Cut.
execute uses CutId, not current name.
execute allows duplicate Cut names.
execute does not change activeCutId if EditingSessionState is present elsewhere in test setup.
execute changes only Cut.name.
execute does not change CutId.
execute does not change layers.
execute does not change frames/timeline.
execute does not change duration.
execute does not change canvas size.
undo restores the previous Cut name.
redo restores the new Cut name.
missing CutId causes execute to throw StateError.
failed execute does not change project state.
undo before execute throws or follows existing command lifecycle convention.

Use unit tests, not widget tests.

Do not require Android Studio manual tests for this command-only phase.

Part C: Do Not Wire UI

Do not update:

lib/src/ui/home_page.dart
lib/src/ui/cut/cut_list_bar.dart

Do not add:

Rename Cut button
New Cut button
Delete Cut button
Cut management panel
dialogs
menus
toolbar actions
shortcuts

This command should be available for future UI but not used by the app yet.

Part D: Preserve Existing Behavior

The app should continue to:

show Cut 1 and Cut 2
keep Cut 1 active by default
switch between Cut 1 and Cut 2
keep active-cut editing scoped correctly

No user-visible behavior should change.

Policy Requirements To Preserve

From docs/Cut_Management_Policy.md:

CutId is identity.
Cut names are display labels.
Duplicate Cut names are allowed.
Cut rename should not be blocked by duplicate Cut names.
Undo/Redo is volatile session history.
Undo/Redo stack must not be saved.

From docs/Cut_Management_Command_Design.md:

Cut rename changes only the Cut display name.
Cut rename is different from Frame rename policy.
ProjectRepository owns project data mutation.
HistoryManager records volatile undoable/redoable command history.

From linked-frame policy:

Linked frames share material/source only.
Timeline placement remains independent.
Cross-cut linked paste is not implemented.

Do not weaken these policies.

Very Important Restrictions

Do not implement any of the following:

Cut rename UI
Cut create UI
Cut delete UI
Cut duplicate UI
Cut reorder UI
Cut management panel
Undoable Cut delete command
Undoable Cut duplicate command
Undoable Cut reorder command
Undoable active cut switch
Save/load lastActiveCutId
Persistent project open/close flow
Linked Cut
Linked Layer
Cross-cut paste
Cross-layer paste
Project-level material pool
Conte Panel
Conte Layer
Storyboard Panel
Camera Layer
Audio Layer behavior
Layer type enum
V/A track UI
Global FrameId refactor
ID generation refactor
JSON schema changes
Save/load format changes
Undo/Redo redesign
Timeline behavior redesign
Timeline placement sharing
Canvas painting behavior redesign
Canvas layout redesign
Renderer changes
Brush engine changes
Provider
Riverpod
Bloc
ChangeNotifier

Do not implement Phase 48 or later.

Allowed Changes

Allowed:

Add an undoable RenameCutCommand or equivalent.
Add a minimal repository read helper only if needed.
Add unit tests for execute/undo/redo behavior.

Preferred result:

No existing user-visible behavior changes.
No HomePage changes.
No UI changes.
No JSON schema changes.
No save/load changes.
Expected User-Visible Behavior

After Phase 47:

The app should look and behave exactly the same as Phase 46.

The change is internal test-covered command support for future Cut rename UI.

Tests / Validation

Run:

dart format lib test
flutter analyze
flutter test
git status

Do not run dart format on Markdown files.

Manual Check In Android Studio

Manual app check is optional for this command-only phase.

If performed, verify:

App launches normally.
Cut 1 / Cut 2 switching still works.
No Cut create/delete/rename UI appeared.
No Cut management panel appeared.
No Conte Panel appeared.
Completion Criteria

This phase is complete only when:

Rename Cut command exists.
Command renames the target Cut using CutId.
Command stores previous Cut name.
Undo restores previous Cut name.
Redo restores new Cut name.
Duplicate Cut names are allowed.
CutId is unchanged.
Layers, frames, timeline, duration, and canvas size are unchanged.
activeCutId is not changed.
No ID generator is added.
No Cut rename UI is added.
No Cut management panel is added.
No JSON schema changes are made.
No save/load changes are made.
Existing user-visible behavior remains unchanged.
dart format lib test passes.
flutter analyze passes.
flutter test passes.
git status is clean after commit.
Suggested Final Response From Codex

After completing the task, summarize:

Implemented Phase 47 Cut Rename Command MVP.

Changed:

Added undoable Rename Cut command.
Command renames Cut display name through ProjectRepository.
Command allows duplicate Cut names.
Command preserves CutId and Cut contents.
Added tests for execute/undo/redo behavior.
Existing user-visible behavior is unchanged.
No Cut management UI was added.

Validation:

dart format lib test
flutter analyze
flutter test
git status

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

Short Instruction For Codex

Read docs/Phase_47_Codex_Task.md and implement Phase 47 only.

Add an undoable Rename Cut command that renames a Cut display label through ProjectRepository.renameCut, uses CutId, stores the previous name, and supports undo/redo.

Duplicate Cut names are allowed.

It must not change activeCutId, CutId, layers, frames, timeline, duration, canvas size, UI, save/load, or JSON schema.

Add unit tests.

Do not add Cut rename UI, Cut management panel, delete/duplicate/reorder commands, Conte Panel, or Phase 48+ work.

Run:

dart format lib test
flutter analyze
flutter test
git status