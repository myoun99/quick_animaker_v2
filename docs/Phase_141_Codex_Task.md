# Phase 141 Codex Task

## Title

Add StoryboardPanel baseline smoke tests

## Goal

Add focused smoke tests for the existing `StoryboardPanel`.

This is the first stabilization phase before expanding storyboard / conte features.

Do not change production behavior.

## Required references

Before editing code, read:

```txt id="d8pqep"
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

Preserve all timeline and project model rules.

## Why this phase exists

The project is moving toward:

```txt id="5otizh"
1. Storyboard / conte panel stabilization
2. 2D brush architecture
3. Canvas / drawing implementation
```

Before adding new storyboard features, the current `StoryboardPanel` structure must be locked with tests.

This phase adds tests only.

## Target files to inspect

Inspect existing files first:

```txt id="memojw"
lib/src/ui/storyboard_panel.dart
test/ui/storyboard_panel_test.dart, if present
test/ui/layer_timeline_grid_test.dart, for harness style
```

Use the current production implementation as the source of truth.

Do not invent new production APIs.

## Test file

Prefer creating:

```txt id="5j3x40"
test/ui/storyboard_panel_smoke_test.dart
```

If the repository already has a strong existing `StoryboardPanel` test file, adding a new group there is acceptable.

## Widget under test

Test:

```txt id="60xial"
StoryboardPanel
```

Use the actual constructor from production code.

Use real model objects where possible:

```txt id="uomuwc"
Project
Track
Cut
Layer
Frame
CanvasSize
ProjectId
TrackId
CutId
LayerId
FrameId
```

Use existing constructor patterns from current tests.

Do not invent test-only model constructors.

## Required baseline tests

### 1. Storyboard panel renders with stable root/title keys

Render a minimal project with at least one track and one cut.

Verify the existing root/title keys used by `StoryboardPanel`.

Do not rename or add production keys.

If the current keys are not obvious, inspect production code and test the keys that already exist.

### 2. Track row renders

With at least one track, verify the track row and track label render.

Expected key patterns may include existing keys like:

```txt id="hjoxig"
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-track-timeline-area-<trackId>
```

Use actual current keys from production code.

### 3. Cut block renders at timeline position

With at least one cut, verify the cut positioned/block widgets render.

Expected key patterns may include:

```txt id="et9pb0"
storyboard-cut-positioned-<cutId>
storyboard-cut-block-<cutId>
```

Use actual current keys from production code.

Do not assert pixel-perfect coordinates unless existing tests already use stable layout constants.

### 4. Cut title / duration / frame range render

Verify visible cut metadata renders if currently shown:

```txt id="oeua6x"
cut title
duration
frame range
```

Use text or existing stable keys.

Do not change UI just to make this easier.

### 5. Layer strip renders

If the current StoryboardPanel shows a layer strip for each cut, verify it renders.

Expected key patterns may include existing keys like:

```txt id="euquv7"
storyboard-layer-strip-<cutId>
storyboard-layer-name-<layerId>
storyboard-layer-empty-<cutId>
```

Use actual current keys from production code.

### 6. Active cut indicator renders

If the current StoryboardPanel has an active cut indicator, render with an active cut ID and verify the indicator exists.

Use current production key or text.

Do not invent a new indicator key.

### 7. Cut selection callback is preserved

If the current StoryboardPanel supports selecting a cut, tap a stable cut block and verify the callback receives the expected `CutId`.

Avoid fragile pointer-offset tests.

Prefer tapping by stable key.

### 8. Empty state renders

Render a project or track with no cuts if current UI supports it.

Verify the empty state renders without throwing.

Use existing empty-state text/key if present.

Do not add a new empty-state UI in this phase.

## Do not change

Do not change production behavior.

Do not change:

```txt id="t7xn3r"
- Project / Track / Cut / Layer / Frame models
- TimelinePanel
- LayerTimelineGrid
- TimelineController
- StoryboardPanel production behavior
- cut positioning semantics
- layer ordering semantics
- Cut.duration semantics
- timeline range semantics
- selection semantics
```

Do not add:

```txt id="9f20x2"
- canvas
- drawing
- brush engine
- stroke rendering
- onion skin
- undo/redo
- save/load
- Provider
- Riverpod
- ChangeNotifier
- CustomPainter
```

Do not reintroduce `authoredTimelineExtentFrameCount` into storyboard or timeline UI.

## Storyboard semantics to preserve

For now, treat StoryboardPanel as a visual overview panel.

It should not mutate project data in this phase.

It should not become a drawing canvas.

It should not own timeline range semantics.

It may display cuts, tracks, and layers based on the existing model.

## Acceptable production changes

This phase should normally add tests only.

Only make production changes if required to fix an existing analyzer/test issue.

If production code is changed, it must be minimal and behavior-preserving.

## Required checks

Run:

```bash id="qvmzza"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Manual verification after local checks

After the PR is merged and local checks pass, manually verify:

```txt id="4njfkh"
1. StoryboardPanel still opens.
2. Tracks render normally.
3. Cuts render normally.
4. Cut title/duration/frame range display is unchanged.
5. Layer strip display is unchanged.
6. Active cut indicator is unchanged.
7. Clicking a cut still selects the cut if selection is currently supported.
8. Empty storyboard/track state does not crash.
9. TimelinePanel behavior is unchanged.
10. LayerTimelineGrid behavior is unchanged.
```

## Report back

Report:

```txt id="yobk6a"
- changed files
- new test file
- whether production code changed
- test cases added
- stable keys tested
- model constructors used
- confirmation that StoryboardPanel behavior did not change
- confirmation that TimelinePanel / LayerTimelineGrid behavior did not change
- confirmation that no canvas/drawing/brush code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no CustomPainter was added
- check results
- git status summary
```
