# Phase 70 Codex Task - Storyboard Frame Metadata Foundation

Create this file first:

docs/Phase_70_Codex_Task.md

Paste this full Phase 70 task document into that file.

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

Add Frame-level storyboard metadata foundation for future Storyboard / Conte workflow.

Current corrected design:

* Storyboard Layer is not a separate Cut.storyboardLayer panel list.
* Storyboard Layer is a normal Layer with LayerKind.storyboard.
* Storyboard Layer uses existing Layer / Frame / Stroke structure.
* Frames inside a storyboard layer can later behave like storyboard/conte panels.
* CutMetadata remains Cut-level note-only metadata.
* actionMemo and dialogueMemo should not be CutMetadata fields.

Phase 70 should add small, non-UI metadata support at the Frame level.

Correct long-term direction:

Cut
layers
Layer(kind: animation)
frames
Frame
strokes

```
Layer(kind: storyboard)
  frames
    Frame
      strokes
      storyboardMetadata
        actionMemo
        dialogueMemo
        note
```

Important:

This phase only adds model support.

Do not add UI.

Do not add commands.

Do not add Storyboard Panel UI.

Do not add Conte Panel UI.

Do not add renderer behavior.

Required new model:

1. StoryboardFrameMetadata

Suggested file:

lib/src/models/storyboard_frame_metadata.dart

Fields:

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
* const StoryboardFrameMetadata.empty()
* copyWith
* equality/hashCode
* toJson/fromJson
* missing JSON fields default to empty strings
* JSON round-trip test

Important:

This is metadata for a Frame when the frame is used in a storyboard layer.

Do not put drawing data here.

Do not put strokes here.

Do not put thumbnail here.

Do not put camera data here.

Do not put canvas size here.

2. Attach metadata to Frame

Add to Frame:

* StoryboardFrameMetadata storyboardMetadata

Default:

* const StoryboardFrameMetadata.empty()

Required Frame behavior:

* constructor default storyboardMetadata to StoryboardFrameMetadata.empty()
* copyWith supports storyboardMetadata
* equality/hashCode includes storyboardMetadata
* toString includes storyboardMetadata if existing style includes fields
* toJson serializes storyboardMetadata
* fromJson deserializes storyboardMetadata
* old JSON without storyboardMetadata defaults to StoryboardFrameMetadata.empty()

Reason:

A Frame in a storyboard layer can act as a storyboard/conte panel.

This allows action/dialogue/note to vary per frame/panel while still using the existing Layer / Frame / Stroke workflow.

3. Frame duplication must preserve storyboardMetadata

When duplicating Frames as part of Cut duplication:

* duplicated Frame should preserve source.frame.storyboardMetadata

This is value metadata.

Do not generate new IDs for metadata because it has no identity.

4. Existing Frame behavior must not change

Frame remains drawable.

Frame still owns strokes.

Frame ID behavior remains unchanged.

Frame name/material policy must not change.

Frame rename/link policy must not change.

5. CutMetadata remains note-only

Do not add:

* actionMemo
* dialogueMemo

to CutMetadata.

6. LayerKind remains unchanged

Do not change LayerKind.

LayerKind.storyboard remains the way to identify storyboard layers.

7. No UI yet

Do not add:

* storyboard metadata editor
* storyboard frame header UI
* actionMemo field in UI
* dialogueMemo field in UI
* Conte Panel
* Storyboard Panel

Testing requirements:

Add focused model and duplication tests.

Likely files:

test/models/storyboard_frame_metadata_test.dart
test/models/frame_storyboard_metadata_test.dart
test/controllers/cut_duplicate_helpers_test.dart
test/models/cut_metadata_test.dart

Exact files may vary.

Required tests:

1. StoryboardFrameMetadata defaults to empty text

Given:

const StoryboardFrameMetadata.empty()

Expected:

* actionMemo == ''
* dialogueMemo == ''
* note == ''

2. StoryboardFrameMetadata constructor defaults text fields to empty

Given:

const StoryboardFrameMetadata()

Expected:

* actionMemo == ''
* dialogueMemo == ''
* note == ''

3. StoryboardFrameMetadata copyWith

Can update:

* actionMemo
* dialogueMemo
* note

without affecting unspecified fields.

4. StoryboardFrameMetadata equality/hashCode

Same fields => equal.

Different actionMemo/dialogueMemo/note => not equal.

5. StoryboardFrameMetadata JSON round-trip

toJson/fromJson preserves:

* actionMemo
* dialogueMemo
* note

6. StoryboardFrameMetadata fromJson missing fields

Missing actionMemo/dialogueMemo/note should default to empty strings.

7. Frame defaults storyboardMetadata to empty

Creating Frame without storyboardMetadata should result in:

* const StoryboardFrameMetadata.empty()

8. Frame.copyWith supports storyboardMetadata

Frame.copyWith(storyboardMetadata: ...) should update metadata and preserve:

* id
* duration
* strokes
* name

9. Frame equality/hashCode includes storyboardMetadata

Two Frames differing only by storyboardMetadata should not be equal.

10. Frame JSON round-trip preserves storyboardMetadata

Frame.toJson / Frame.fromJson should preserve storyboardMetadata.

11. Old Frame JSON without storyboardMetadata loads with empty metadata

Frame.fromJson should default missing storyboardMetadata to StoryboardFrameMetadata.empty().

12. Cut duplication preserves Frame storyboardMetadata

Given a source Cut with a Layer that contains a Frame with storyboardMetadata:

* duplicateCutAsIndependentCopy preserves storyboardMetadata on the duplicated corresponding Frame
* FrameId is still remapped
* Stroke data is still duplicated as before
* Layer.kind is still preserved
* CutMetadata is still preserved

13. CutMetadata remains note-only

CutMetadata.toJson should still contain only:

* note

No actionMemo/dialogueMemo should appear.

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

Do not add commands.

Do not add StoryboardFrameMetadata commands.

Do not add Frame metadata editing commands.

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

Do not implement Phase 71 or later.

Architecture rules:

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

Storyboard Frame metadata belongs to Frame, not CutMetadata.

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are not CutMetadata fields.

actionMemo and dialogueMemo belong to StoryboardFrameMetadata.

StoryboardFrameMetadata is a domain model, not a Flutter widget.

StoryboardFrameMetadata must not know about UI.

StoryboardFrameMetadata must not know about renderer.

StoryboardFrameMetadata must not know about canvas size.

StoryboardFrameMetadata must not know about drawable area.

StoryboardFrameMetadata must not know about camera/framing.

StoryboardFrameMetadata must not know about HistoryManager.

StoryboardFrameMetadata must not know about ProjectRepository.

LayerKind must not know about UI.

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

Cut duplication should preserve CutMetadata, Layer.kind, and Frame.storyboardMetadata.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/models/storyboard_frame_metadata.dart
lib/src/models/frame.dart
lib/src/controllers/cut_duplicate_helpers.dart
test/models/storyboard_frame_metadata_test.dart
test/models/frame_storyboard_metadata_test.dart
test/controllers/cut_duplicate_helpers_test.dart
test/models/cut_metadata_test.dart

Possibly changed files:

docs/Design_CutMetadata_CanvasPlanning.md
test/models/frame_test.dart

Recommended doc update:

Update docs/Design_CutMetadata_CanvasPlanning.md to record:

* Storyboard Frame metadata exists at Frame level.
* actionMemo/dialogueMemo/note live in StoryboardFrameMetadata.
* StoryboardFrameMetadata follows LayerKind.storyboard + Frame workflow.
* CutMetadata remains note-only.

Avoid touching unrelated files.

Do not change UI files.

Do not change command behavior.

Do not change save/load services beyond model JSON compatibility.

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
* new StoryboardFrameMetadata model
* confirmation that Frame.storyboardMetadata exists and defaults to empty
* confirmation that old Frame JSON without storyboardMetadata still loads
* confirmation that Frame JSON round-trip preserves storyboardMetadata
* confirmation that Cut duplication preserves Frame.storyboardMetadata
* confirmation that LayerKind remains unchanged
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added to CutMetadata
* confirmation that no UI was added
* confirmation that no commands were added
* confirmation that no Storyboard Panel UI or Conte Panel UI was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 70 is complete when:

1. StoryboardFrameMetadata exists.
2. StoryboardFrameMetadata has actionMemo.
3. StoryboardFrameMetadata has dialogueMemo.
4. StoryboardFrameMetadata has note.
5. StoryboardFrameMetadata fields default to empty.
6. StoryboardFrameMetadata.empty exists.
7. StoryboardFrameMetadata.copyWith works.
8. StoryboardFrameMetadata equality/hashCode work.
9. StoryboardFrameMetadata JSON round-trip works.
10. StoryboardFrameMetadata.fromJson missing fields default to empty strings.
11. Frame has storyboardMetadata.
12. Frame default storyboardMetadata is empty.
13. Frame.copyWith supports storyboardMetadata.
14. Frame equality/hashCode includes storyboardMetadata.
15. Frame JSON round-trip preserves storyboardMetadata.
16. old Frame JSON without storyboardMetadata loads with empty metadata.
17. Cut duplication preserves Frame.storyboardMetadata.
18. Cut duplication still preserves Layer.kind.
19. CutMetadata remains note-only.
20. actionMemo is not added to CutMetadata.
21. dialogueMemo is not added to CutMetadata.
22. No UI is added.
23. No Storyboard Frame UI is added.
24. No Storyboard Panel UI is added.
25. No Conte Panel UI is added.
26. No commands are added.
27. No Cut canvas size is added.
28. No drawable area is added.
29. No renderer/tile/camera changes are added.
30. No broad state-management framework is introduced.
31. Existing Cut create/rename/duplicate/delete/reorder behavior still works.
32. Existing Cut Note UI tests still pass.
33. Existing Layer/Frame/Stroke tests still pass.
34. dart format lib test completes.
35. flutter analyze passes.
36. flutter test passes.
37. git status is clean after commit.

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
