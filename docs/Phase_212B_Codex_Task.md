# Phase 212B Codex Task

## Title

Current docs quality reinforcement after Phase 212A audit

## 1. Goal

Phase 211 consolidated project documentation into `Current_*` source-of-truth documents.

Phase 212A was a manual architecture audit by GPT. The audit found that the current documents are directionally correct, but several documents are too compressed or contain wording artifacts from post-merge hotfixes.

This phase must reinforce the current documentation quality without changing runtime behavior.

The goal is:

```txt
Improve Current_* documentation clarity.
Preserve the latest architecture decisions.
Reduce future AI confusion.
Make architecture documentation tests less brittle.
Do not change runtime code.
```

## 2. Important operating rules

Read these files directly before making changes:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Current_Docs_Index.md
docs/Current_Project_Architecture.md
docs/Current_Implementation_Roadmap.md
docs/Current_Brush_Architecture.md
docs/Current_Timeline_Architecture.md
docs/Current_Cut_Management_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Storyboard_Architecture.md
```

Follow these rules:

```txt
- Do not modify handoff sections 0 through 4.
- AI may edit handoff section 5 and later.
- Keep handoff lightweight.
- Do not move module-specific architecture details back into handoff.
- Current_* docs are the source of truth for current architecture policy.
- Phase_*_Codex_Task.md files are historical task/order records only.
- Do not restore deleted obsolete non-phase docs.
- Do not modify runtime code under lib/.
- Do not add Provider, Riverpod, Bloc, ChangeNotifier, or other app-wide state management.
```

## 3. Scope

This is a docs/test-only reinforcement phase.

Allowed files:

```txt
docs/Current_Docs_Index.md
docs/Current_Project_Architecture.md
docs/Current_Implementation_Roadmap.md
docs/Current_Brush_Architecture.md
docs/Current_Timeline_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Storyboard_Architecture.md
docs/Handoff_QuickAnimaker_v2_Current.md
test/architecture/*.dart
```

Only edit `docs/Handoff_QuickAnimaker_v2_Current.md` section 5 or later, and only to add a concise next-chat / current-doc pointer. Do not re-expand handoff into a large module policy document.

Do not edit runtime files.

## 4. Required documentation improvements

### 4.1 Current_Implementation_Roadmap.md

The current roadmap is too short.

Expand it enough to guide the next few implementation phases without becoming a giant historical document.

It should include:

```txt
- Current status after docs consolidation.
- Next recommended work order.
- Brush production integration / implementation direction.
- Canvas/cache/storage foundation before heavy playback/save-load work.
- Storyboard panel work after preserving storyboard-as-layer semantics.
- Save/load and playback/cache dependency order.
- Clear "not yet" items.
```

Preserve the current roadmap intent:

```txt
- Current_* docs are source of truth.
- Old phase-by-phase documents are historical records only.
- Runtime implementation may lag behind current architecture policy.
```

Suggested structure:

```txt
# Current Implementation Roadmap

## Status

## Near-term order

## Not yet

## Dependency notes
```

### 4.2 Current_Canvas_Cache_Storage_Architecture.md

This document is directionally correct but too thin.

Reinforce current policy with these concepts:

```txt
- Cache images are derived, not source of truth.
- Heavy bitmap payloads and paint command buffers belong outside lightweight Frame metadata.
- BrushFrameStore or equivalent brush/canvas storage owns frame-local drawing payloads.
- Timeline range semantics must not decide storage validity.
- Cut.duration is playback/export duration only.
- Authored drawing data can exist beyond Cut.duration.
- Playback should use prepared preview/composite cache images.
- Playback must not replay live paint commands.
- Playback must not run brush rasterization.
- Playback should not composite all layers from scratch when a valid cache exists.
- Dirty flags / dirty regions / dirty tiles are future cache invalidation concepts.
- Sparse tile allocation is the preferred future storage direction.
- Do not eagerly allocate every tile.
- Tile delta is not the current user-facing undo policy.
- Tile delta may remain only as a legacy implementation detail, possible low-level optimization, or internal bitmap mutation/storage detail.
- Save/load must distinguish source payload from derived caches.
- Derived caches may be rebuilt; source drawing payload must be persisted.
```

Do not claim all of these are already implemented. Use wording such as:

```txt
Current policy
Future implementation direction
Runtime may not yet implement every item
```

### 4.3 Current_Storyboard_Architecture.md

This document preserves the core model policy but lost too much long-term direction.

Reinforce it with:

```txt
- Storyboard is an ordinary Layer with kind: storyboard.
- A Cut may have at most one storyboard layer.
- The storyboard layer is included in Cut.layers.
- Do not add Cut.storyboardLayer.panels.
- StoryboardPanel is a project/cut overview and planning surface.
- StoryboardPanel is not a drawing canvas.
- Do not wire brush drawing into StoryboardPanel unless a future current document explicitly changes this.
- StoryboardPanel should not own timeline range semantics.
- StoryboardPanel should not mutate Project during layout/read operations.
- Basic storyboard export should default to Primary Track only.
- Selected-track export and composite output are future optional features, not defaults.
- Track-based board view is a future direction.
- Preserve stable UI keys used by tests.
```

Do not implement storyboard runtime features in this phase.

### 4.4 Current_Brush_Architecture.md

The brush policy is mostly correct, but hotfix wording left awkward expressions.

Clean up wording without weakening policy.

Fix the awkward section:

```txt
The current policy is not:
- Tile-delta data is not the user-facing undo source.
```

Replace it with clearer wording, for example:

```txt
The current policy is not:
- Tile delta as the user-facing undo source.
- User-facing undo as TileDeltaCommand.
- Tile delta as the primary brush undo model.
```

Preserve all current brush policy:

```txt
- Deferred Bake Hybrid Brush History.
- Brush input creates stroke-like / paint-command information.
- User-facing undo is based on recent live paint commands / stroke-like paint commands through UnifiedUndoHistory.
- userUndoLimit controls user-facing undo.
- deferredBakePaintCommands is a separate delayed bake buffer.
- deferred bake buffer is conceptually about 10% of the user undo limit.
- deferred bake buffer is not user-facing undo.
- bakedBaseSurface may compact old commands.
- Cache images are derived, not source of truth.
- Playback must not replay live paint commands.
- Playback must not run brush rasterization.
- Tile delta is not current user-facing undo.
```

Also clean up the duplicated Frame sentence while preserving the exact architecture meaning.

The document should still contain the phrase:

```txt
Frame remains lightweight
```

but it should not be awkwardly duplicated.

### 4.5 Current_Timeline_Architecture.md

The timeline policy is correct, but there is a hotfix duplicate:

```txt
- `Cut.duration` is playback/export duration only.
- Cut.duration is playback/export duration only.
```

Clean this up while preserving test compatibility.

Preferred final wording:

```txt
- Cut.duration is playback/export duration only.
- `Cut.duration` must not limit data extent, editability, selected exposure outline, or visible range.
```

Preserve these policies:

```txt
- Timeline range semantics must not drive canvas/cache/storage semantics.
- Playback/export duration, visible display range, virtualized rendering windows, authored data extent, selected exposure visuals, scrolling, and frame coordinate conversion are separate concepts.
- Authored frames beyond Cut.duration can exist.
- Editing beyond Cut.duration must not auto-extend Cut.duration.
- Linked frames share drawing material/source identity.
- Linked frames do not share placement, exposure duration, timeline marks, blank/X positions, selected cell state, or authored timeline entry state.
- + Exposure / - Exposure operate on the selected authored timeline entry.
- Future timeline or rename work must not accidentally mutate every linked use of a FrameId.
- Layer raw order and display order remain separate.
```

### 4.6 Current_Project_Architecture.md

The project document is mostly correct.

Add a small clarification if needed:

```txt
- Stroke remains part of the high-level domain hierarchy.
- Brush implementation may use stroke-like paint commands / PaintCommand-like payloads.
- Durable Frame metadata must stay lightweight.
- Heavy bitmap payloads, live paint command lists, baked surfaces, and caches belong in brush/canvas storage.
```

Do not redesign models in this phase.

### 4.7 Current_Docs_Index.md

Keep it simple.

Ensure it still says:

```txt
- Current_* docs are the source of truth for current architecture policy.
- Phase task docs are historical task/order records.
- Old phase/task docs must not override Current_* docs.
```

Do not add large module policy text here.

### 4.8 Handoff section 5+

Add only a concise continuation note in section 5 or later.

It should say, in Korean or English, that after Phase 212B the next chat should start by reading:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md sections 0-4
docs/Current_Docs_Index.md
the relevant Current_* document for the target module
```

Do not copy detailed module policies into handoff.

## 5. Architecture test improvements

Current architecture tests are too brittle because they often depend on exact sentence formatting, punctuation, or backticks.

Update tests to preserve important policies while avoiding unnecessary failures caused by minor markdown wording.

Allowed test improvements:

```txt
- Prefer checking multiple smaller required terms instead of one long exact sentence.
- For Cut.duration, accept the policy without depending on markdown backticks.
- For source-of-truth wording, avoid requiring only one exact hyphenation.
- For brush tile-delta policy, check that tile delta is not user-facing undo, not that one exact old phrase is absent unless that phrase is truly stale.
- Keep tests strong enough to catch policy regressions.
```

Required protected policies must still be tested:

```txt
- Current docs exist and are indexed.
- Handoff keeps user-managed sections 0-4.
- Phase task docs are historical records.
- Obsolete non-phase docs remain deleted.
- Deferred Bake Hybrid Brush History exists.
- User-facing brush undo uses live paint commands / stroke-like commands through UnifiedUndoHistory.
- Deferred bake buffer is not user-facing undo.
- Cache images are derived, not source of truth.
- Tile delta is not current user-facing undo.
- Playback must not replay live paint commands or run brush rasterization.
- Cut.duration is playback/export duration only.
- Timeline range semantics must not drive canvas/cache/storage semantics.
- Linked frames share material/source identity but not placement/exposure/marks.
- activeCutId is session/controller state, not persisted project structure.
- active Cut delete fallback is previous -> next -> new default empty Cut.
- Storyboard remains an ordinary Layer with kind: storyboard.
- StoryboardPanel is not a drawing canvas.
```

## 6. Out of scope

Do not do these:

```txt
- Do not modify runtime code under lib/.
- Do not implement brush features.
- Do not implement canvas/cache/storage.
- Do not implement storyboard features.
- Do not restore deleted obsolete docs.
- Do not delete Phase_*_Codex_Task.md or *_Task.md files.
- Do not re-expand handoff into a huge architecture document.
- Do not introduce new state management.
- Do not rename runtime classes.
```

## 7. Required checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter is unavailable in the environment, report that clearly.

Also run or otherwise verify:

```bash
git diff --check
```

## 8. Report format

In the PR body or final Codex report, include:

```txt
- Current docs reinforced
- Roadmap expanded
- Canvas/cache/storage policy reinforced
- Storyboard long-term direction restored
- Brush hotfix wording cleaned
- Timeline duplicate Cut.duration wording cleaned
- Architecture tests made less brittle but still policy-protective
- Handoff section 5+ updated lightly, sections 0-4 untouched
- Phase task docs preserved
- Obsolete non-phase docs not restored
- Runtime code unchanged
- Check results
```
