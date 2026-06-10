# Phase 64 Codex Task - CutMetadata Scope Correction

Create this file first:

docs/Phase_64_Codex_Task.md

Paste this full Phase 64 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Domain model correction / design alignment phase.

This is not a UI phase.

Goal:

Correct the scope of CutMetadata.

Phase 63 introduced CutMetadata with:

* actionMemo
* dialogueMemo
* note

After review, the design has been corrected:

* actionMemo and dialogueMemo are not Cut-level metadata.
* They belong to future StoryboardPanel / ContePanel data because they may vary per storyboard panel.
* CutMetadata should keep only Cut-level general note for now.

Phase 64 should update the model and tests accordingly.

Required final model:

CutMetadata should contain only:

* String note

Required behavior:

1. Remove actionMemo from CutMetadata

CutMetadata should no longer have:

* actionMemo

2. Remove dialogueMemo from CutMetadata

CutMetadata should no longer have:

* dialogueMemo

3. Keep note

CutMetadata should keep:

* note

Default:

* note = ''

4. Empty metadata

CutMetadata.empty should still exist.

Expected:

* CutMetadata.empty().note == ''

5. copyWith

CutMetadata.copyWith should support:

* note

It should no longer support:

* actionMemo
* dialogueMemo

6. Equality / hashCode

CutMetadata equality and hashCode should use only note.

7. JSON serialization

Update CutMetadata.toJson.

Expected output:

* note only

Example:

{
"note": "General Cut note"
}

Do not serialize actionMemo or dialogueMemo anymore.

8. JSON deserialization

Update CutMetadata.fromJson.

It should read:

* note

Compatibility requirement:

If old JSON contains actionMemo and dialogueMemo, ignore them safely.

If note is missing, default to ''.

This is important because PR 84 briefly introduced metadata JSON with actionMemo/dialogueMemo.

Required behavior:

CutMetadata.fromJson({
"actionMemo": "old action",
"dialogueMemo": "old dialogue",
"note": "general note"
})

should produce:

CutMetadata(note: "general note")

CutMetadata.fromJson({
"actionMemo": "old action",
"dialogueMemo": "old dialogue"
})

should produce:

CutMetadata.empty()

9. Cut model

Cut should still have:

* final CutMetadata metadata

Default should remain:

* const CutMetadata.empty()

Cut.copyWith should still support metadata.

Cut equality/hashCode should still include metadata.

Cut.toJson/fromJson should still serialize/deserialize metadata.

10. Cut duplicate behavior

duplicateCutAsIndependentCopy should still preserve source.metadata.

Do not regress this.

Testing requirements:

Update existing tests and add correction tests.

Likely test files:

test/models/cut_metadata_test.dart
test/controllers/cut_duplicate_helpers_test.dart

Required tests:

1. empty metadata defaults to blank note

CutMetadata.empty().note == ''

2. value equality uses note

Same note => equal.

Different note => not equal.

3. copyWith changes note only

CutMetadata(note: 'a').copyWith(note: 'b') => note 'b'

4. toJson serializes note only

CutMetadata(note: 'General').toJson() should equal:

{
"note": "General"
}

It should not contain:

* actionMemo
* dialogueMemo

5. fromJson reads note

CutMetadata.fromJson({'note': 'General'}) should equal:

CutMetadata(note: 'General')

6. fromJson ignores legacy actionMemo/dialogueMemo

CutMetadata.fromJson({
'actionMemo': 'old action',
'dialogueMemo': 'old dialogue',
'note': 'General'
})

should equal:

CutMetadata(note: 'General')

7. fromJson defaults missing note to empty

CutMetadata.fromJson({
'actionMemo': 'old action',
'dialogueMemo': 'old dialogue'
})

should equal:

CutMetadata.empty()

8. Cut default metadata remains empty

Creating Cut without metadata should still result in CutMetadata.empty().

9. Cut metadata JSON round-trip still works

Cut with non-empty note should survive Cut.toJson / Cut.fromJson.

10. Old Cut JSON without metadata still loads

Cut.fromJson without metadata should still result in CutMetadata.empty().

11. Cut duplicate preserves metadata

duplicateCutAsIndependentCopy should preserve source.metadata.

If this test already exists from PR 84, update it to note-only metadata.

Out of scope:

Do not add UI.

Do not add metadata editor.

Do not add Cut inspector.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add Cut management panel.

Do not add StoryboardLayer.

Do not add StoryboardPanel.

Do not add actionMemo elsewhere yet.

Do not add dialogueMemo elsewhere yet.

Do not add panelNote yet.

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

Do not implement Phase 65 or later.

Architecture rules:

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are future StoryboardPanel fields, not CutMetadata fields.

CutMetadata must not know about UI.

CutMetadata must not know about StoryboardPanel yet.

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

Cut duplication should preserve CutMetadata.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

docs/Design_CutMetadata_CanvasPlanning.md
lib/src/models/cut_metadata.dart
test/models/cut_metadata_test.dart
test/controllers/cut_duplicate_helpers_test.dart

Possibly changed files:

lib/src/models/cut.dart
test/models/cut_test.dart

Avoid touching unrelated files.

Do not change UI files.

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
* root cause / design correction summary
* confirmation that CutMetadata now contains note only
* confirmation that actionMemo/dialogueMemo were removed from CutMetadata
* confirmation that legacy actionMemo/dialogueMemo JSON is ignored safely
* confirmation that Cut metadata JSON round-trip still works
* confirmation that Cut duplication still preserves metadata
* confirmation that no UI was added
* confirmation that no StoryboardLayer/StoryboardPanel was added
* confirmation that no Conte Panel or Storyboard Panel was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 64 is complete when:

1. CutMetadata contains note only.
2. actionMemo is removed from CutMetadata.
3. dialogueMemo is removed from CutMetadata.
4. CutMetadata.empty still works.
5. CutMetadata.copyWith supports note.
6. CutMetadata equality/hashCode use note.
7. CutMetadata.toJson serializes note only.
8. CutMetadata.fromJson reads note.
9. CutMetadata.fromJson ignores legacy actionMemo/dialogueMemo.
10. CutMetadata.fromJson defaults missing note to empty.
11. Cut still has metadata.
12. Cut default metadata still works.
13. Cut.copyWith(metadata: ...) still works.
14. Cut JSON round-trip still works for note metadata.
15. old Cut JSON without metadata still loads.
16. Cut duplication still preserves metadata.
17. docs/Design_CutMetadata_CanvasPlanning.md records the correction.
18. No UI is added.
19. No StoryboardLayer is added.
20. No StoryboardPanel is added.
21. No Conte Panel is added.
22. No Storyboard Panel is added.
23. No Cut canvas size is added.
24. No drawable area is added.
25. No broad state-management framework is introduced.
26. dart format lib test completes.
27. flutter analyze passes.
28. flutter test passes.
29. git status is clean after commit.

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
