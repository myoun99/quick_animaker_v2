# Phase 69 Codex Task - Storyboard Layer Design Correction

Create this file first:

docs/Phase_69_Codex_Task.md

Paste this full Phase 69 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Design correction / domain model correction phase.

This is not a UI phase.

Goal:

Correct the Storyboard / Conte data direction before building commands or UI.

Important design correction:

The app should not treat StoryboardLayer as a separate Cut-owned panel list.

The intended design is:

* A Storyboard Layer behaves like a normal animation Layer.
* It uses the existing Layer / Frame / Stroke structure.
* It can contain drawable Frames.
* It can later support memo data such as actionMemo / dialogueMemo / note.
* The layer header / timeline row can later act like a storyboard/conte panel interface.
* But it should not be modeled as Cut.storyboardLayer.panels.

Correct long-term direction:

Storyboard data should be based on existing animation structures:

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
      future storyboard metadata
```

Wrong direction to stop:

Cut
storyboardLayer
panels
StoryboardPanel
actionMemo
dialogueMemo
note

That panel-list model does not match the intended workflow.

Current state:

Phase 68 added:

* StoryboardPanelId
* StoryboardPanel
* StoryboardLayer
* Cut.storyboardLayer

This was based on the wrong assumption that storyboard/conte panels should live in a separate Cut-owned panel list.

Phase 69 should correct this before commands or UI are added.

Required changes:

1. Remove the separate Cut-owned storyboardLayer direction

Remove from Cut:

* StoryboardLayer storyboardLayer

Remove from Cut behavior:

* constructor storyboardLayer parameter
* default StoryboardLayer.empty
* copyWith(storyboardLayer)
* equality/hashCode participation
* toString participation
* toJson storyboardLayer serialization
* fromJson storyboardLayer deserialization

Old JSON compatibility:

If old JSON contains storyboardLayer from the short-lived Phase 68 model:

* Cut.fromJson should safely ignore it
* Do not throw
* Do not preserve it

Reason:

The Phase 68 storyboardLayer field was never intended as persisted public schema and is being corrected immediately.

2. Remove or deprecate unused panel-list models

Preferred:

Remove these files entirely if nothing else depends on them:

* lib/src/models/storyboard_panel_id.dart
* lib/src/models/storyboard_panel.dart
* lib/src/models/storyboard_layer.dart

Also remove their tests:

* test/models/storyboard_panel_id_test.dart
* test/models/storyboard_panel_test.dart
* test/models/storyboard_layer_test.dart
* test/models/cut_storyboard_layer_test.dart

If removing files creates too much churn, an acceptable fallback is to leave them unused but clearly mark them as deprecated/internal and no longer attached to Cut.

Preferred is removal.

3. Add Layer kind/type foundation

Add a small model for distinguishing layer purpose.

Preferred enum name:

LayerKind

Suggested file:

lib/src/models/layer_kind.dart

Values:

* animation
* storyboard

Default:

* animation

Rationale:

Storyboard Layer should be a normal Layer with a kind/type, not a separate Cut field.

4. Attach LayerKind to Layer

Add to Layer:

* LayerKind kind

Default:

* LayerKind.animation

Required Layer behavior:

* constructor default kind to LayerKind.animation
* copyWith supports kind
* equality/hashCode includes kind
* toString includes kind if existing style includes fields
* toJson serializes kind
* fromJson deserializes kind
* old JSON without kind defaults to LayerKind.animation

JSON representation:

Use a stable string, e.g.

* "animation"
* "storyboard"

Do not serialize enum index.

5. Cut duplication must preserve Layer.kind

Because storyboard layers are ordinary layers, duplicating a Cut should preserve whether each duplicated Layer is animation or storyboard.

Update duplicate layer helpers if needed.

Required:

* duplicateCutAsIndependentCopy preserves each source layer.kind
* add/update tests

6. CutMetadata remains note-only

Do not change CutMetadata.

Do not add actionMemo/dialogueMemo to CutMetadata.

7. Do not add storyboard memo fields yet

Do not add actionMemo / dialogueMemo / panelNote yet.

Reason:

The correct location for those fields is likely future Frame-level or StoryboardFrameMetadata-level data.

That should be a later phase.

Testing requirements:

Add focused tests.

Likely files:

test/models/layer_kind_test.dart
test/models/layer_test.dart
test/models/cut_test.dart
test/controllers/cut_duplicate_helpers_test.dart

Exact file names may vary.

Required tests:

1. LayerKind serializes stable strings

* LayerKind.animation -> "animation"
* LayerKind.storyboard -> "storyboard"

2. LayerKind deserializes stable strings

* "animation" -> LayerKind.animation
* "storyboard" -> LayerKind.storyboard

3. Invalid LayerKind JSON throws

Preferred:

* StateError or ArgumentError

Use project style.

4. Layer defaults to animation kind

Creating a Layer without kind should result in:

* LayerKind.animation

5. Layer.copyWith supports kind

Given animation layer:

* copyWith(kind: LayerKind.storyboard) changes kind
* preserves id/name/frames/visibility/opacity/etc. if those fields exist

6. Layer equality includes kind

Two Layers differing only by kind should not be equal.

7. Layer JSON round-trip preserves kind

Layer.toJson / Layer.fromJson preserves LayerKind.storyboard.

8. Old Layer JSON without kind defaults to animation

Layer.fromJson old data should load with LayerKind.animation.

9. Cut no longer has storyboardLayer

Tests should reflect that Cut does not expose storyboardLayer.

If existing tests from Phase 68 are removed, ensure no test refers to Cut.storyboardLayer.

10. Old Cut JSON with storyboardLayer is ignored

Given Cut JSON that includes a storyboardLayer key from Phase 68:

* Cut.fromJson should load successfully
* resulting Cut should not expose storyboardLayer
* toJson should not include storyboardLayer

11. Cut duplication preserves Layer.kind

Given source Cut with:

* animation layer
* storyboard layer

After duplicateCutAsIndependentCopy:

* duplicated corresponding layers preserve kind
* layer IDs are still remapped independently
* frame/stroke copying behavior remains unchanged
* CutMetadata is still preserved

12. CutMetadata remains note-only

No actionMemo/dialogueMemo on CutMetadata.

Out of scope:

Do not add UI.

Do not add Storyboard Layer UI.

Do not add Conte Panel UI.

Do not add Storyboard Panel UI.

Do not add Cut Inspector.

Do not add metadata side panel.

Do not add persistent storyboard panel.

Do not add Edit Storyboard Panel button.

Do not add actionMemo UI.

Do not add dialogueMemo UI.

Do not add panelNote UI.

Do not add actionMemo model field yet.

Do not add dialogueMemo model field yet.

Do not add StoryboardFrameMetadata yet.

Do not add Frame metadata yet.

Do not add drawing UI for storyboard layers.

Do not add thumbnail rendering.

Do not add image import.

Do not add storyboard canvas.

Do not add StoryboardPanel commands.

Do not add StoryboardLayer commands.

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

Do not implement Phase 70 or later.

Architecture rules:

Storyboard Layer is a normal Layer with LayerKind.storyboard.

Animation Layer is a normal Layer with LayerKind.animation.

Storyboard Layer is not a separate Cut-owned StoryboardLayer object.

StoryboardPanel is not currently part of the active design.

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are not CutMetadata fields.

actionMemo and dialogueMemo should later belong to Frame-level storyboard metadata or another structure that follows the Layer / Frame workflow.

Layer must not know about UI.

LayerKind must not know about UI.

LayerKind must not know about renderer.

LayerKind must not know about canvas size.

LayerKind must not know about drawable area.

LayerKind must not know about camera/framing.

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the UI-facing command entry point.

CutId remains the true identity of a Cut.

LayerId remains the true identity of a Layer.

Cut name remains a display label.

Layer name remains a display label.

Duplicate Cut names remain allowed.

Cut duplication should preserve CutMetadata and Layer.kind.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/models/layer_kind.dart
lib/src/models/layer.dart
lib/src/models/cut.dart
lib/src/controllers/cut_duplicate_helpers.dart
test/models/layer_kind_test.dart
test/models/layer_test.dart
test/models/cut_test.dart
test/controllers/cut_duplicate_helpers_test.dart

Likely deleted files:

lib/src/models/storyboard_panel_id.dart
lib/src/models/storyboard_panel.dart
lib/src/models/storyboard_layer.dart
test/models/storyboard_panel_id_test.dart
test/models/storyboard_panel_test.dart
test/models/storyboard_layer_test.dart
test/models/cut_storyboard_layer_test.dart

Possibly changed files:

docs/Design_CutMetadata_CanvasPlanning.md

Recommended doc update:

Update docs/Design_CutMetadata_CanvasPlanning.md to record:

* StoryboardLayer is not a separate Cut.storyboardLayer panel list.
* Storyboard Layer is represented by LayerKind.storyboard.
* Existing Layer / Frame / Stroke structure remains the basis for storyboard/conte workflow.
* actionMemo/dialogueMemo will be introduced later at the appropriate Frame/storyboard metadata level.

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
* deleted files
* new LayerKind model
* confirmation that Cut.storyboardLayer was removed
* confirmation that old Cut JSON with storyboardLayer is safely ignored
* confirmation that Layer.kind exists and defaults to animation
* confirmation that Layer.kind serializes as stable string
* confirmation that old Layer JSON without kind defaults to animation
* confirmation that duplicate Cut preserves Layer.kind
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added anywhere
* confirmation that no UI was added
* confirmation that no Storyboard Panel UI or Conte Panel UI was added
* confirmation that no Frame metadata was added yet
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no renderer/tile/camera changes were added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 69 is complete when:

1. Cut.storyboardLayer is removed.
2. Cut no longer serializes storyboardLayer.
3. Cut no longer deserializes storyboardLayer into a field.
4. Cut.fromJson safely ignores legacy storyboardLayer key.
5. StoryboardPanelId model is removed or clearly deprecated and unused.
6. StoryboardPanel model is removed or clearly deprecated and unused.
7. StoryboardLayer model is removed or clearly deprecated and unused.
8. LayerKind exists.
9. LayerKind has animation.
10. LayerKind has storyboard.
11. Layer defaults to LayerKind.animation.
12. Layer.copyWith supports kind.
13. Layer equality/hashCode includes kind.
14. Layer JSON round-trip preserves kind.
15. old Layer JSON without kind defaults to animation.
16. invalid LayerKind JSON is tested.
17. Cut duplication preserves each Layer.kind.
18. CutMetadata remains note-only.
19. actionMemo is not re-added to CutMetadata.
20. dialogueMemo is not re-added to CutMetadata.
21. actionMemo is not added elsewhere yet.
22. dialogueMemo is not added elsewhere yet.
23. No UI is added.
24. No Storyboard Panel UI is added.
25. No Conte Panel UI is added.
26. No Frame metadata is added yet.
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
