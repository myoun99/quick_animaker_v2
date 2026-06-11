# Phase 68 Codex Task - Storyboard Panel Model Foundation

Create this file first:

docs/Phase_68_Codex_Task.md

Paste this full Phase 68 task document into that file.

Before implementing, read:

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

Add the first domain model foundation for future Storyboard / Conte panel data.

Background:

Earlier, actionMemo and dialogueMemo were removed from CutMetadata because they are not Cut-level metadata.

Correct design:

* CutMetadata is Cut-level metadata only.
* CutMetadata contains only note.
* actionMemo and dialogueMemo belong to future StoryboardPanel / ContePanel data because they can vary per storyboard panel.

Phase 68 should introduce a small, non-UI storyboard data model where actionMemo and dialogueMemo can live correctly.

Do not add UI.

Do not add Storyboard Panel UI.

Do not add Conte Panel UI.

Do not add drawing/thumbnail rendering.

Do not add canvas/camera changes.

Required new model classes:

1. StoryboardPanelId

Suggested file:

lib/src/models/storyboard_panel_id.dart

Expected behavior:

* immutable value object
* wraps String value
* const constructor
* equality/hashCode
* toJson/fromJson if this project convention uses it for ID models
* toString if existing ID models do that

Follow the style of existing ID classes such as CutId, LayerId, FrameId, StrokeId.

2. StoryboardPanel

Suggested file:

lib/src/models/storyboard_panel.dart

Fields:

* StoryboardPanelId id
* String actionMemo
* String dialogueMemo
* String note

Defaults:

* actionMemo = ''
* dialogueMemo = ''
* note = ''

Expected behavior:

* immutable
* const constructor
* copyWith
* equality/hashCode
* toJson/fromJson
* default empty text fields
* JSON round-trip test

Important:

Do not add drawing data yet.

Do not add image reference yet.

Do not add thumbnail yet.

Do not add frame range yet.

Do not add camera data yet.

Do not add canvas size yet.

Do not add timing yet.

3. StoryboardLayer

Suggested file:

lib/src/models/storyboard_layer.dart

Fields:

* List<StoryboardPanel> panels

Expected behavior:

* immutable
* const constructor
* default empty layer
* copyWith
* equality/hashCode
* toJson/fromJson
* unmodifiable panels list if existing model style uses unmodifiable lists
* JSON round-trip test

Suggested default:

const StoryboardLayer.empty()

where panels is empty.

4. Attach storyboard data to Cut

Add a Cut-level field:

* StoryboardLayer storyboardLayer

Default:

* const StoryboardLayer.empty()

Reason:

Storyboard/conte data belongs to the Cut, but action/dialogue belong inside panels within the Cut.

Cut should continue to have:

* CutMetadata metadata

CutMetadata remains note-only.

Cut should now also have:

* StoryboardLayer storyboardLayer

Required Cut behavior:

* constructor default storyboardLayer to StoryboardLayer.empty()
* copyWith supports storyboardLayer
* equality/hashCode includes storyboardLayer
* toString includes storyboardLayer if existing style includes fields
* toJson serializes storyboardLayer
* fromJson deserializes storyboardLayer
* old JSON without storyboardLayer defaults to StoryboardLayer.empty()

5. Cut duplication must preserve storyboardLayer

Update duplicateCutAsIndependentCopy if needed.

When duplicating a Cut:

* metadata should be preserved
* storyboardLayer should be preserved

Important:

This phase does not require deep-copying StoryboardPanel IDs yet unless existing duplicate semantics strongly require new IDs.

Preferred for Phase 68:

* Preserve storyboardLayer as value data.
* Because no commands modify individual StoryboardPanels yet, shallow value preservation is acceptable if models are immutable.
* Add a test that duplicated Cut preserves storyboardLayer.

Testing requirements:

Add focused model and duplication tests.

Likely files:

test/models/storyboard_panel_id_test.dart
test/models/storyboard_panel_test.dart
test/models/storyboard_layer_test.dart
test/models/cut_storyboard_layer_test.dart
test/controllers/cut_duplicate_helpers_test.dart

Exact file names may vary.

Required tests:

1. StoryboardPanelId value equality

Same value => equal.

Different value => not equal.

2. StoryboardPanel defaults text fields to empty

Given a StoryboardPanel with only id:

* actionMemo == ''
* dialogueMemo == ''
* note == ''

3. StoryboardPanel copyWith

Can change:

* actionMemo
* dialogueMemo
* note

without changing id.

4. StoryboardPanel equality

Same id and text fields => equal.

Different actionMemo/dialogueMemo/note => not equal.

5. StoryboardPanel JSON round-trip

StoryboardPanel.toJson / fromJson preserves:

* id
* actionMemo
* dialogueMemo
* note

6. StoryboardLayer empty default

StoryboardLayer.empty().panels is empty.

7. StoryboardLayer copyWith

Can replace panels.

8. StoryboardLayer equality

Same panel list => equal.

Different panel list => not equal.

9. StoryboardLayer JSON round-trip

Panels survive toJson / fromJson.

10. Cut default storyboardLayer

Creating Cut without storyboardLayer should result in:

* const StoryboardLayer.empty()

11. Cut copyWith storyboardLayer

Cut.copyWith(storyboardLayer: ...) should update storyboardLayer and preserve other fields.

12. Cut equality includes storyboardLayer

Cuts differing only by storyboardLayer should not be equal.

13. Cut JSON round-trip with storyboardLayer

Cut.toJson / Cut.fromJson preserves storyboardLayer.

14. Old Cut JSON without storyboardLayer

Cut.fromJson without storyboardLayer should default to StoryboardLayer.empty().

15. Cut duplication preserves storyboardLayer

duplicateCutAsIndependentCopy should preserve source.storyboardLayer.

16. CutMetadata remains note-only

Ensure no actionMemo/dialogueMemo is re-added to CutMetadata.

Out of scope:

Do not add UI.

Do not add Edit Storyboard Panel button.

Do not add Conte Panel.

Do not add Storyboard Panel UI.

Do not add Cut Inspector.

Do not add metadata side panel.

Do not add persistent note panel.

Do not add drawing UI for storyboard panels.

Do not add thumbnail rendering.

Do not add image import.

Do not add storyboard canvas.

Do not add StoryboardPanel commands.

Do not add StoryboardLayer commands.

Do not add actionMemo UI.

Do not add dialogueMemo UI.

Do not add panelNote UI.

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

Do not implement Phase 69 or later.

Architecture rules:

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are StoryboardPanel fields, not CutMetadata fields.

StoryboardPanel is a domain model, not a Flutter widget.

StoryboardLayer is a domain model, not a visual rendering layer yet.

StoryboardLayer must not know about UI.

StoryboardPanel must not know about UI.

StoryboardPanel must not know about renderer.

StoryboardPanel must not know about canvas size.

StoryboardPanel must not know about drawable area.

StoryboardPanel must not know about camera/framing.

StoryboardPanel must not know about HistoryManager.

StoryboardPanel must not know about ProjectRepository.

Cut may own StoryboardLayer as domain data.

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the UI-facing command entry point.

CutId remains the true identity of a Cut.

Cut name remains a display label.

Duplicate Cut names remain allowed.

Cut reorder behavior must not change.

Cut duplication should preserve CutMetadata and StoryboardLayer.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/models/storyboard_panel_id.dart
lib/src/models/storyboard_panel.dart
lib/src/models/storyboard_layer.dart
lib/src/models/cut.dart
lib/src/controllers/cut_duplicate_helpers.dart
test/models/storyboard_panel_id_test.dart
test/models/storyboard_panel_test.dart
test/models/storyboard_layer_test.dart
test/models/cut_storyboard_layer_test.dart
test/controllers/cut_duplicate_helpers_test.dart

Possibly changed files:

lib/src/models/models.dart
lib/src/models/cut_metadata.dart
test/models/cut_metadata_test.dart

Avoid touching unrelated files.

Do not change UI files.

Do not change command behavior.

Do not change save/load services beyond Cut model JSON support.

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
* new model classes
* confirmation that StoryboardPanel contains actionMemo/dialogueMemo/note
* confirmation that CutMetadata remains note-only
* confirmation that Cut now owns StoryboardLayer
* confirmation that old Cut JSON without storyboardLayer still loads
* confirmation that Cut JSON round-trip preserves storyboardLayer
* confirmation that Cut duplication preserves storyboardLayer
* confirmation that no UI was added
* confirmation that no Storyboard Panel UI or Conte Panel UI was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 68 is complete when:

1. StoryboardPanelId exists.
2. StoryboardPanel exists.
3. StoryboardLayer exists.
4. StoryboardPanel has actionMemo.
5. StoryboardPanel has dialogueMemo.
6. StoryboardPanel has note.
7. StoryboardPanel text fields default to empty.
8. StoryboardPanel copyWith works.
9. StoryboardPanel equality/hashCode work.
10. StoryboardPanel JSON round-trip works.
11. StoryboardLayer.empty exists.
12. StoryboardLayer panels default to empty.
13. StoryboardLayer copyWith works.
14. StoryboardLayer equality/hashCode work.
15. StoryboardLayer JSON round-trip works.
16. Cut has storyboardLayer.
17. Cut default storyboardLayer is empty.
18. Cut.copyWith supports storyboardLayer.
19. Cut equality/hashCode includes storyboardLayer.
20. Cut JSON round-trip preserves storyboardLayer.
21. old Cut JSON without storyboardLayer loads with StoryboardLayer.empty.
22. Cut duplication preserves storyboardLayer.
23. CutMetadata remains note-only.
24. actionMemo is not re-added to CutMetadata.
25. dialogueMemo is not re-added to CutMetadata.
26. No UI is added.
27. No Storyboard Panel UI is added.
28. No Conte Panel UI is added.
29. No Cut canvas size is added.
30. No drawable area is added.
31. No renderer/tile/camera changes are added.
32. No broad state-management framework is introduced.
33. Existing Cut create/rename/duplicate/delete/reorder behavior still works.
34. Existing Cut Note UI tests still pass.
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
