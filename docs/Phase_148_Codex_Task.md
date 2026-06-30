# Phase 148 Codex Task

## Title

2D brush model / brush settings architecture

## Repository

```txt id="0nv8g6"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="myb5sw"
master
```

## Project type

```txt id="7xk6jz"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 147.

Recent phases completed:

```txt id="62wjx8"
Phase 145: Timeline stabilization checkpoint
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
```

Phase 148 starts the next recommended area:

```txt id="ixh39m"
2D brush model / brush settings architecture
```

This is not a canvas phase.

This is not a brush rendering phase.

This is not an input sampling phase yet.

## Required references

Before editing, read:

```txt id="8fnyws"
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Phase_146_Codex_Task.md
docs/Phase_147_Codex_Task.md
```

Also inspect:

```txt id="n4g3tv"
lib/src/models/brush_settings.dart
lib/src/models/stroke.dart
lib/src/models/stroke_point.dart
test/models/json_serialization_test.dart
test/models/copy_with_test.dart
test/models/value_objects_test.dart
```

Do not modify timeline or storyboard behavior in this phase.

## Goal

Create a stable brush settings model foundation that future brush input sampling, brush engine, canvas, and stroke rendering can build on.

The main goals are:

```txt id="idcbfn"
- Keep BrushSettings immutable and safe to snapshot into Stroke.
- Expand BrushSettings beyond color/size/opacity in a controlled, backwards-compatible way.
- Add small value objects/enums needed to represent brush presets and brush behavior without rendering.
- Add tests for equality, copyWith, JSON, validation, and backward compatibility.
- Do not add actual drawing, canvas, CustomPainter, renderer, brush engine, or input sampling.
```

## Design intent

`BrushSettings` should represent the frozen brush configuration used by a `Stroke`.

A `Stroke` should continue to own a `BrushSettings` snapshot.

Future UI may have selected brush presets, but existing strokes must not change when a preset changes later.

Therefore:

```txt id="a1u1mb"
BrushPreset = reusable named preset
BrushSettings = immutable settings snapshot
Stroke.brushSettings = frozen settings used by that stroke
```

Do not make `Stroke` reference a mutable preset.

Do not make `Stroke` depend on brush UI state.

## Required production changes

### 1. Expand BrushSettings safely

Update:

```txt id="a7hd9e"
lib/src/models/brush_settings.dart
```

Current fields:

```txt id="6w54fk"
color
size
opacity
```

Add a small set of model-only fields.

Preferred fields:

```txt id="vf8szs"
flow
hardness
spacing
tipShape
pressureSize
pressureOpacity
```

Recommended defaults:

```dart id="duau9c"
color = 0xFF000000
size = 4.0
opacity = 1.0
flow = 1.0
hardness = 1.0
spacing = 0.1
tipShape = BrushTipShape.round
pressureSize = false
pressureOpacity = false
```

Meaning:

```txt id="unvy00"
color: ARGB int color
size: base brush diameter in canvas units
opacity: final stroke opacity, 0.0 to 1.0
flow: per-dab paint amount, 0.0 to 1.0
hardness: soft edge control, 0.0 to 1.0
spacing: normalized spacing between brush dabs, must be positive
tipShape: brush tip shape enum
pressureSize: whether future input pressure may affect size
pressureOpacity: whether future input pressure may affect opacity
```

Do not implement actual dab generation.

Do not implement pressure sampling.

Do not implement rendering.

### 2. Add BrushTipShape enum

Preferred file:

```txt id="v59323"
lib/src/models/brush_tip_shape.dart
```

Preferred enum:

```dart id="hum9m6"
enum BrushTipShape {
  round,
  square,
}
```

Add JSON helpers consistent with existing project style.

Preferred API:

```dart id="m6j0nj"
String toJson()
static BrushTipShape fromJson(Object? json)
```

or equivalent project style.

Behavior:

```txt id="j3gjc1"
- round serializes as "round"
- square serializes as "square"
- unknown values throw FormatException
```

Keep this model-only.

Do not use Flutter `Paint`.

Do not use `Canvas`.

### 3. Add BrushPresetId value object

Preferred file:

```txt id="vrw9vx"
lib/src/models/brush_preset_id.dart
```

Preferred behavior should match existing ID value object style in the project.

Required behavior:

```txt id="0115pf"
- immutable value object
- stores String value
- supports equality/hashCode
- supports toJson/fromJson
- rejects empty value if existing ID style does so
```

If existing ID value objects allow empty values, follow the existing project style.

Do not invent a different ID convention.

### 4. Add BrushPreset model

Preferred file:

```txt id="1t0v5v"
lib/src/models/brush_preset.dart
```

Preferred fields:

```dart id="w4kq0v"
final BrushPresetId id;
final String name;
final BrushSettings settings;
```

Required behavior:

```txt id="7vn9r0"
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- duplicate names should be allowed
- BrushPresetId is identity
- name is a display label
```

Do not add preset UI.

Do not add selected brush state.

Do not add persistence services.

Do not add a preset repository.

### 5. Validation policy

Add validation directly in model constructors or small private helpers.

Required validation:

```txt id="6zmpea"
BrushSettings.size must be greater than 0.
BrushSettings.opacity must be between 0.0 and 1.0 inclusive.
BrushSettings.flow must be between 0.0 and 1.0 inclusive.
BrushSettings.hardness must be between 0.0 and 1.0 inclusive.
BrushSettings.spacing must be greater than 0.
```

Preferred exception type:

```txt id="tyns04"
ArgumentError
```

Do not clamp silently.

Reason:

Silent clamping can hide invalid model data and make future brush engine behavior harder to debug.

### 6. JSON backward compatibility

`BrushSettings.fromJson` must remain backward-compatible with old JSON that only contains:

```txt id="7m9gng"
color
size
opacity
```

If the new fields are missing, use the defaults.

Required:

```txt id="atp2et"
old BrushSettings JSON should still deserialize successfully
new BrushSettings JSON should round-trip all fields
```

Do not break existing `Stroke.fromJson`.

`Stroke.fromJson` must continue to read nested `brushSettings`.

## Required tests

### 1. BrushSettings tests

Create or update:

```txt id="lpwzpb"
test/models/brush_settings_test.dart
```

Required tests:

```txt id="tmx1e6"
default values are stable
copyWith updates each field independently
equality includes new fields
toJson includes new fields
fromJson round-trips new fields
fromJson supports legacy color/size/opacity JSON
invalid size throws
invalid opacity throws
invalid flow throws
invalid hardness throws
invalid spacing throws
```

### 2. BrushTipShape tests

Preferred file:

```txt id="uj5wyp"
test/models/brush_tip_shape_test.dart
```

Required tests:

```txt id="i0ixg2"
round serializes to round
square serializes to square
fromJson parses round
fromJson parses square
fromJson throws FormatException for unknown value
```

### 3. BrushPresetId tests

Create or update:

```txt id="mux693"
test/models/value_objects_test.dart
```

or create:

```txt id="6qolty"
test/models/brush_preset_id_test.dart
```

Follow existing test organization.

Required tests:

```txt id="cihq5i"
BrushPresetId equality works
BrushPresetId toJson/fromJson round-trips
```

If existing ID objects reject empty values, add:

```txt id="lix4d2"
empty BrushPresetId throws
```

### 4. BrushPreset tests

Preferred file:

```txt id="lldoqp"
test/models/brush_preset_test.dart
```

Required tests:

```txt id="c4vk58"
copyWith preserves unspecified fields
copyWith updates name
copyWith updates settings
toJson/fromJson round-trips
equality includes id, name, and settings
duplicate preset names are allowed because BrushPresetId is identity
```

### 5. Stroke compatibility tests

Update existing model serialization tests or add a focused test file if needed.

Required tests:

```txt id="fbpksb"
Stroke serializes BrushSettings with new fields
Stroke deserializes legacy BrushSettings nested in old stroke JSON
Stroke keeps BrushSettings as a value snapshot
```

Do not change `Stroke` to reference `BrushPreset`.

## Architecture rules

Brush architecture rules:

```txt id="pmlw88"
- BrushSettings is an immutable value object.
- BrushSettings can be stored inside Stroke.
- BrushSettings should be safe as a frozen stroke snapshot.
- BrushPreset is reusable preset metadata.
- BrushPresetId is the identity of a preset.
- BrushPreset.name is a display label.
- Duplicate BrushPreset names are allowed.
- Stroke must not reference BrushPreset.
- Stroke must not depend on mutable current brush UI state.
```

Current phase boundaries:

```txt id="evzdlt"
- This phase may add model/value-object code.
- This phase may update model tests.
- This phase may update JSON tests for compatibility.
- This phase must not add actual brush engine behavior.
```

## Out of scope

Do not add:

```txt id="b2bxsx"
canvas
drawing canvas
brush engine
brush rendering
stroke rendering
dab generation
input sampling
pressure sampling
pointer event handling
smoothing/stabilization algorithm
onion skin
undo/redo
save/load service changes
Provider
Riverpod
Bloc
ChangeNotifier
CustomPainter
renderer changes
tile engine changes
cache changes
persistence service changes
brush preset UI
selected brush UI
toolbar UI
metadata side panel
storyboard drawing
storyboard thumbnail rendering
storyboard export
```

Do not change:

```txt id="35yu5m"
TimelinePanel
LayerTimelineGrid
TimelineController
StoryboardPanel
StoryboardPanel tests except if a shared model helper requires imports
timeline range semantics
Cut.duration semantics
authoredTimelineExtentFrameCount semantics
selected exposure range semantics
visible frame range semantics
```

Do not weaken existing tests.

Do not remove Phase 146 or Phase 147 tests.

## Expected changed files

Likely:

```txt id="zvqvs0"
lib/src/models/brush_settings.dart
lib/src/models/brush_tip_shape.dart
lib/src/models/brush_preset_id.dart
lib/src/models/brush_preset.dart
test/models/brush_settings_test.dart
test/models/brush_tip_shape_test.dart
test/models/brush_preset_test.dart
```

Possibly:

```txt id="wjl2wr"
test/models/value_objects_test.dart
test/models/json_serialization_test.dart
test/models/copy_with_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="34cazf"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="mkjff4"
- changed files
- new model/value-object files added
- BrushSettings fields after this phase
- confirmation that BrushSettings remains immutable
- confirmation that BrushSettings.fromJson supports legacy color/size/opacity JSON
- confirmation that Stroke still stores BrushSettings directly
- confirmation that Stroke does not reference BrushPreset
- confirmation that BrushPresetId is preset identity
- confirmation that BrushPreset.name is only a display label
- confirmation that duplicate BrushPreset names are allowed
- confirmation that no brush engine/rendering/input sampling was added
- confirmation that no canvas/drawing/CustomPainter code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 148 is complete when:

```txt id="4jtm22"
- BrushSettings has stable expanded model-only fields.
- BrushSettings validation is explicit and does not silently clamp invalid values.
- BrushSettings JSON is backward-compatible with old color/size/opacity JSON.
- BrushTipShape exists and is tested.
- BrushPresetId exists and is tested.
- BrushPreset exists and is tested.
- Stroke serialization/deserialization still works with BrushSettings.
- Stroke does not reference BrushPreset.
- Existing model tests pass.
- Existing timeline/storyboard stabilization tests pass.
- No canvas/drawing/brush rendering/input sampling/stroke rendering was added.
- No undo/redo/save/load/state-management framework work was added.
```
