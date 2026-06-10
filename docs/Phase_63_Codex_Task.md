# Phase 63 Codex Task - CutMetadata Foundation

Create this file first:

docs/Phase_63_Codex_Task.md

Paste this full Phase 63 task document into that file.

Before implementing, also read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Domain model foundation phase.

This is not a UI phase.

Goal:

Add a small CutMetadata value object and attach it to Cut.

This is the first low-risk foundation for future Conte / Storyboard workflows.

The Cut metadata should initially contain only storyboard/conte text fields:

* actionMemo
* dialogueMemo
* note

Do not add UI.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add Cut canvas settings yet.

Do not add drawable area settings yet.

Do not add camera/framing settings yet.

Design reference:

Use docs/Design_CutMetadata_CanvasPlanning.md as the long-term design reference.

Phase 63 should implement only the initial metadata part.

Required model:

Add a new model class:

CutMetadata

Suggested file:

lib/src/models/cut_metadata.dart

Required fields:

* String actionMemo
* String dialogueMemo
* String note

Required behavior:

1. Default empty metadata

Provide a simple default constructor or named factory for empty metadata.

Preferred API:

const CutMetadata.empty()

or:

static const empty = CutMetadata(...)

Choose the style that best matches existing model conventions.

Default values:

* actionMemo = ''
* dialogueMemo = ''
* note = ''

2. Immutable value object

CutMetadata should be immutable.

All fields should be final.

3. Equality

CutMetadata should support value equality consistent with existing model style.

If the project uses manual == / hashCode, implement manual == / hashCode.

If the project uses another convention, follow that convention.

4. copyWith

If existing models use copyWith, add copyWith to CutMetadata.

Required copyWith fields:

* actionMemo
* dialogueMemo
* note

5. Attach metadata to Cut

Update Cut model to include:

final CutMetadata metadata;

Default value should be empty metadata.

Existing code that creates Cut should not be forced to pass metadata unless project conventions require it.

Preferred:

metadata defaults to CutMetadata.empty()

or equivalent.

6. Cut copyWith

Update Cut.copyWith if it exists.

It should support metadata.

7. Cut equality / hashCode

Update Cut equality and hashCode if necessary.

metadata must participate in equality if existing Cut equality compares all value fields.

8. Barrel export

If models have a barrel export file, export CutMetadata there.

If there is no barrel export pattern for models, do not create one just for this phase.

Testing requirements:

Add focused tests.

Suggested test file:

test/models/cut_metadata_test.dart

Required tests:

1. empty metadata defaults

CutMetadata.empty should produce:

* actionMemo == ''
* dialogueMemo == ''
* note == ''

2. value equality

Two CutMetadata instances with the same fields should be equal.

Two CutMetadata instances with different fields should not be equal.

3. copyWith changes one field

copyWith(actionMemo: ...) changes only actionMemo.

copyWith(dialogueMemo: ...) changes only dialogueMemo.

copyWith(note: ...) changes only note.

4. Cut default metadata

Creating a Cut without explicitly passing metadata should result in empty metadata.

5. Cut metadata copyWith

If Cut has copyWith:

* Cut.copyWith(metadata: newMetadata) should update metadata
* other Cut fields should remain unchanged

6. Cut equality includes metadata

If Cut equality exists:

* two Cuts with same id/name/duration/layers but different metadata should not be equal

Adjust exact tests to match existing model style.

Existing tests:

Update existing Cut/model tests if they fail due to the new metadata field.

Do not weaken existing tests.

Out of scope:

Do not add UI.

Do not add metadata editor.

Do not add Cut inspector.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add Cut management panel.

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

Do not add camera/framing transform.

Do not add renderer changes.

Do not add tile engine changes.

Do not change save/load or JSON schema unless tests reveal existing serialization requires a minimal default-safe update.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 64 or later.

Architecture rules:

CutMetadata is a domain model value object.

CutMetadata must not know about UI.

CutMetadata must not know about HistoryManager.

CutMetadata must not know about ProjectRepository.

CutMetadata must not know about rendering.

CutMetadata must not know about canvas size.

CutMetadata must not know about drawable area.

CutMetadata must not know about camera/framing.

CutId remains the true identity of a Cut.

Cut name remains a display label.

Duplicate Cut names remain allowed.

Cut reorder behavior must not change.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/models/cut_metadata.dart
lib/src/models/cut.dart
test/models/cut_metadata_test.dart

Possibly changed files:

test/models/cut_test.dart
lib/src/models/models.dart or equivalent barrel export if it exists

Avoid touching unrelated files.

Do not change UI files unless required by constructor updates.

Do not change command behavior.

Do not change repository behavior.

Required checks for Codex:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* confirmation that this is CutMetadata foundation only
* confirmation that no UI was added
* confirmation that no Conte Panel or Storyboard Panel was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no save/load or JSON schema changes were made, unless a minimal compatibility change was required
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 63 is complete when:

1. CutMetadata model exists.
2. CutMetadata has actionMemo.
3. CutMetadata has dialogueMemo.
4. CutMetadata has note.
5. CutMetadata has empty/default metadata.
6. CutMetadata supports value equality.
7. CutMetadata supports copyWith if project model style supports copyWith.
8. Cut includes metadata.
9. Existing Cut construction remains easy through default empty metadata.
10. Cut copyWith supports metadata if Cut.copyWith exists.
11. Cut equality/hashCode handles metadata consistently.
12. Focused model tests are added.
13. Existing tests pass.
14. No UI is added.
15. No Conte Panel is added.
16. No Storyboard Panel is added.
17. No Cut canvas size is added.
18. No drawable area is added.
19. No camera/framing settings are added.
20. No save/load or JSON schema behavior is changed unless unavoidable.
21. No broad state-management framework is introduced.
22. dart format lib test completes.
23. flutter analyze passes.
24. flutter test passes.
25. git status is clean after commit.

Manual check guidance after merge:

This phase should not change visible UI.

After merge, a short manual check is enough:

* app launches
* existing Cut list appears
* Cut creation still works
* Cut rename still works
* Cut duplicate still works
* Cut delete still works
* Cut drag reorder still works
* Undo/Redo still work
* no metadata UI appears yet
* no Conte Panel appears
* no Storyboard Panel appears
