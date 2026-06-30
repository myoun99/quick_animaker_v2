# Phase 116 Codex Task

## Title

Update project handoff with timeline range semantics reference

## Goal

Update the project handoff documentation so future ChatGPT/Codex sessions know that timeline-related work must first reference:

```txt id="dfr092"
docs/LongTerm_Timeline_Range_Semantics.md
```

This is a documentation-only handoff phase after PR170.

No runtime behavior should change.

## Why this phase exists

Phase 115 created the long-term timeline range semantics document.

That document is important enough that future assistant sessions should treat it as required context before reviewing or changing timeline code.

The handoff should make this explicit so future sessions do not accidentally confuse:

* `Cut.duration`
* playback range
* visible/display range
* virtualized frame window
* authored/data extent
* selected exposure visual range
* effective horizontal scroll offset
* frame coordinate conversion

## Files to update

Update:

```txt id="y70wog"
docs/Handoff_QuickAnimaker_v2_Current.md
```

If the repository has a project workflow or GPT usage guide, also update it if appropriate:

```txt id="r3mzyp"
docs/Use_Gpt_flow.md
```

Only update these files if they exist.

Do not create a new long-term semantics document. It already exists:

```txt id="qix3dx"
docs/LongTerm_Timeline_Range_Semantics.md
```

## Required update content

In `docs/Handoff_QuickAnimaker_v2_Current.md`, add a clear section such as:

```md id="qg1ako"
## Required reference for timeline work

Before reviewing or modifying timeline code, read:

- `docs/LongTerm_Timeline_Range_Semantics.md`

This document defines the long-term separation between playback range, visible/display range, virtualized frame window, authored/data extent, selected exposure visual range, effective horizontal scroll offset, and frame coordinate conversion.

Do not use `Cut.duration` as a data/edit/selection limit.
Do not use `authoredTimelineExtentFrameCount` to bound selected exposure outline rendering.
Do not use raw horizontal scroll offset for layout/hit testing after resize; use the effective clamped offset.
Selected exposure outline is a display-range visual effect, not a data extent.
```

Also add a short recent-phase note:

```md id="dgyhci"
## Recent timeline stabilization phases

- PR165: clamped effective horizontal offset after viewport resize to prevent ruler/body/frame tearing.
- PR166: restored selected exposure outline as a display-range visual effect.
- PR167: extracted selected exposure display-range policy.
- PR168: extracted horizontal offset clamp policy.
- PR169: extracted frame coordinate conversion policy.
- PR170: documented long-term timeline range semantics and policy invariants.
```

If `docs/Use_Gpt_flow.md` exists, add a short note for future assistant sessions:

```md id="z3z94y"
For timeline-related tasks, first read `docs/LongTerm_Timeline_Range_Semantics.md` before proposing architecture changes, Codex tasks, or PR reviews.
```

## Do not change

Do not change runtime behavior.

Do not change:

* Dart source logic
* Flutter widgets
* tests
* `Project`
* `Track`
* `Cut`
* `Layer`
* `Frame`
* `Stroke`
* `Cut.duration`
* `playbackFrameCount`
* `TimelineController.authoredTimelineExtentFrameCount`
* timeline policies
* timeline virtualization
* selected exposure outline behavior
* renderer
* brush engine
* undo/redo
* editing commands
* drag handles

Do not reintroduce `authoredTimelineExtentFrameCount` into `TimelinePanel` or `LayerTimelineGrid`.

Do not use `CustomPainter`.

## Tests

No new tests are required.

Because this is documentation-only, run lightweight checks plus full project checks if available.

## Required checks

Run:

```bash id="pbpvd0"
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

Also run:

```bash id="xfw4gz"
git diff --check
```

## Report back

Report:

* changed files
* confirmation that `docs/LongTerm_Timeline_Range_Semantics.md` is referenced from the handoff
* confirmation that future timeline work is instructed to read the range semantics document first
* confirmation that no runtime source logic changed
* confirmation that no tests were changed
* confirmation that no `CustomPainter` was introduced
* check results
* git status summary
