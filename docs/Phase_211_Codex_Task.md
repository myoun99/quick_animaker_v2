# Phase 211 Codex Task

## Title

Consolidate project documentation into Current-prefixed source-of-truth docs

## 1. Goal

Clean up the entire `docs/` directory.

The current documentation problem is:

```txt
- too much architecture information is packed into handoff
- many old phase/task/memo docs still exist
- current policy and old policy are mixed
- AI can accidentally follow stale docs
- module-specific information is scattered across many files
```

The target structure is:

```txt
handoff = minimal entry / conversation rule document
Current_* docs = actual source-of-truth documents for each module/area
old phase/memo/obsolete docs = delete after useful content is integrated
```

Use the prefix:

```txt
Current_
```

Do not use `LongTerm_`.

Reason:

```txt
Current_ means "this is the current source of truth".
It is clearer than LongTerm_ because these docs contain both current decisions and future direction.
```

## 2. Required final documentation structure

Prefer this final current-doc set:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md

docs/Current_Docs_Index.md
docs/Current_Project_Architecture.md
docs/Current_Implementation_Roadmap.md

docs/Current_Brush_Architecture.md
docs/Current_Timeline_Architecture.md
docs/Current_Canvas_Cache_Storage_Architecture.md
docs/Current_Storyboard_Architecture.md
```

Optional only if truly needed:

```txt
docs/Current_Testing_Checklist.md
docs/Current_Codex_Workflow.md
```

Avoid creating too many new current docs.

The goal is fewer, clearer documents.

## 3. Handoff policy

`docs/Handoff_QuickAnimaker_v2_Current.md` must remain.

Do not edit sections 0 through 4.

Sections 0 through 4 are user-managed.

Sections 5 and later may be stale. They may be deleted, shortened, or replaced from section 6 onward if helpful.

The handoff should not contain detailed brush/timeline/canvas architecture.

The handoff should become a lightweight entry document that points AIs to the relevant current docs.

Allowed change:

```txt
Update section 6 or later only.
```

Recommended handoff section 6+ content:

```txt
## Current source-of-truth docs

Before working on a module, read the matching current document directly.

- General project architecture:
  docs/Current_Project_Architecture.md

- Implementation roadmap:
  docs/Current_Implementation_Roadmap.md

- Brush:
  docs/Current_Brush_Architecture.md

- Timeline:
  docs/Current_Timeline_Architecture.md

- Canvas / cache / storage:
  docs/Current_Canvas_Cache_Storage_Architecture.md

- Storyboard:
  docs/Current_Storyboard_Architecture.md

- Docs index:
  docs/Current_Docs_Index.md
```

Do not modify sections 0 through 4.

## 4. Rename / consolidate current docs

### Brush

Rename or recreate:

```txt
docs/Brush_Architecture_Current.md
-> docs/Current_Brush_Architecture.md
```

Keep the latest Deferred Bake Hybrid Brush History policy.

This is the current brush policy:

```txt
- user-facing brush undo is based on recent live paint commands / stroke-like paint commands
- UnifiedUndoHistory owns global user-facing undo order
- BrushFrameStore owns frame-local brush payloads
- userUndoLimit is custom/user-configurable
- deferredBakeRatio is conceptually about 10%
- deferredBakeLimit = max(minimumBuffer, round(userUndoLimit * deferredBakeRatio))
- deferred bake buffer is not user-facing undo
- older commands may be baked into bakedBaseSurface
- active frame display = bakedBaseSurface + deferredBakePaintCommands + livePaintCommands + activeStrokeOverlay
- inactivePreviewCache / playbackPreviewCache are derived images
- cache images are not source of truth
- playback must not replay live paint commands
- playback must not run brush rasterization
```

Remove or delete obsolete brush docs after integration.

Prefer delete over legacy notice.

Delete if no longer needed:

```txt
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Brush_App_Integration_Decisions.md
docs/Brush_V1_Complete.md
docs/Brush_V1_Integration_Review.md
```

Only keep them if tests or important current content require it. If kept, explain why in `Current_Docs_Index.md`.

### Timeline

Create or consolidate into:

```txt
docs/Current_Timeline_Architecture.md
```

Integrate the latest valid timeline decisions from existing timeline docs.

Important timeline rules to preserve if present:

```txt
- Timeline stabilized around Phase 145.
- Avoid timeline refactors unless fixing a regression.
- Cut.duration is playback/export duration only.
- Cut.duration must not limit data extent, editability, outline, or visible range.
- Timeline range semantics must not drive canvas/cache/storage semantics.
- Layer ordering:
  raw order [A, B, C]
  horizontal display [C, B, A]
  vertical XSheet [A, B, C]
  new layer inserted after active raw layer
```

Delete old timeline docs after integration when safe.

Possible old docs to inspect/delete after integration:

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/LongTerm_Roadmap_After_Phase_150.md
```

### Canvas / cache / storage

Create or consolidate into:

```txt
docs/Current_Canvas_Cache_Storage_Architecture.md
```

Preserve the latest valid canvas/cache/storage direction, but do not contradict the latest brush policy.

Important rules:

```txt
- playback must not replay live paint commands
- playback must not run brush rasterization
- playback should use prepared preview/composite bitmap cache images
- cache images are derived, not source of truth
- canvas/cache/storage semantics must stay separate from timeline range semantics
```

Do not reintroduce tile-delta-as-current-user-facing-undo policy.

Tile delta may appear only as:

```txt
- legacy implementation detail
- possible low-level optimization
- internal bitmap mutation/storage detail
```

### Storyboard

Create or consolidate into:

```txt
docs/Current_Storyboard_Architecture.md
```

Preserve:

```txt
- storyboard is an ordinary Layer with kind storyboard
- max one storyboard layer per Cut
- storyboard layer is included in Cut.layers
- do not add Cut.storyboardLayer.panels
- StoryboardPanel is project/cut overview, not drawing canvas
```

### Project architecture

Create or consolidate into:

```txt
docs/Current_Project_Architecture.md
```

It should contain:

```txt
- QuickAnimaker v2 overview
- target: TVPaint-style 2D bitmap animation tool
- core domain hierarchy:
  Project -> Track -> Cut -> Layer -> Frame -> Stroke
- model ownership boundaries
- module boundaries
- no god object principle
- no Provider/Riverpod/Bloc/ChangeNotifier unless explicitly planned
```

If `docs/Architecture.md` is integrated fully, delete it or replace it by `Current_Project_Architecture.md`.

Prefer delete if references can be updated.

### Roadmap

Create or consolidate into:

```txt
docs/Current_Implementation_Roadmap.md
```

This should contain only current future direction, not old phase-by-phase noise.

It should show:

```txt
1. Docs consolidation
2. Brush production integration cleanup
3. Brush current architecture implementation
4. Canvas/cache/storage foundation aligned with brush architecture
5. Storyboard panel work
6. Save/load
7. Playback/cache implementation
```

Adjust details based on actual existing docs.

## 5. Delete obsolete docs aggressively

The user explicitly prefers deletion over leaving many legacy docs.

Delete old docs when their useful content is integrated into Current_* docs.

Candidates to delete include:

```txt
docs/Phase_*.md
docs/LongTerm_*.md
docs/*_Review.md
docs/*_Complete.md
docs/*_Checkpoint.md
docs/*_Decisions.md
docs/*_Task.md
```

Do not delete blindly.

Before deleting:

```txt
1. inspect content
2. extract current useful rules into the appropriate Current_* doc
3. update tests/references
4. delete obsolete source document
```

Git history is enough for deleted historical docs.

The docs directory should become small and easy to scan.

## 6. Current docs index

Create:

```txt
docs/Current_Docs_Index.md
```

It must list:

```txt
- which documents are current source of truth
- which module should read which document
- which documents were deleted/consolidated
- rule: old phase/task docs are not current policy
- rule: if a module has a Current_* document, AI must read that document before planning or implementing in that module
```

Example:

```txt
# Current Docs Index

## Current source-of-truth docs

- Handoff / conversation flow:
  docs/Handoff_QuickAnimaker_v2_Current.md

- Project architecture:
  docs/Current_Project_Architecture.md

- Roadmap:
  docs/Current_Implementation_Roadmap.md

- Brush:
  docs/Current_Brush_Architecture.md

- Timeline:
  docs/Current_Timeline_Architecture.md

- Canvas / cache / storage:
  docs/Current_Canvas_Cache_Storage_Architecture.md

- Storyboard:
  docs/Current_Storyboard_Architecture.md

## AI reading rule

Before working on a module, read the matching Current_* document directly.
Do not rely on old phase/task docs as current policy.
```

## 7. Update references

Update all references in docs and tests from old paths to new paths.

Examples:

```txt
Brush_Architecture_Current.md
-> Current_Brush_Architecture.md

Architecture.md
-> Current_Project_Architecture.md

LongTerm_Roadmap_After_Phase_150.md
-> Current_Implementation_Roadmap.md

Timeline_Stabilization_Checkpoint.md
LongTerm_Timeline_Range_Semantics.md
-> Current_Timeline_Architecture.md
```

Do not leave active docs pointing users to deleted files.

## 8. Tests

Add or update architecture tests.

Suggested file:

```txt
test/architecture/current_docs_structure_test.dart
```

The test should verify:

```txt
1. docs/Current_Docs_Index.md exists.
2. docs/Current_Project_Architecture.md exists.
3. docs/Current_Implementation_Roadmap.md exists.
4. docs/Current_Brush_Architecture.md exists.
5. docs/Current_Timeline_Architecture.md exists.
6. docs/Current_Canvas_Cache_Storage_Architecture.md exists.
7. docs/Current_Storyboard_Architecture.md exists.
8. docs/Handoff_QuickAnimaker_v2_Current.md exists.
9. Current_Docs_Index.md references all Current_* docs.
10. Handoff section 0 through 4 still exists and is not removed.
11. Handoff contains the module-doc reading rule in section 6 or later if updated.
12. No Current_* document says tile delta is the current user-facing brush undo policy.
13. Current_Brush_Architecture.md says user-facing brush undo is based on recent live paint commands / stroke-like paint commands.
14. Current_Brush_Architecture.md says deferred bake buffer is not user-facing undo.
15. Current_Timeline_Architecture.md says timeline range semantics must not drive canvas/cache/storage semantics.
16. Current_Storyboard_Architecture.md says storyboard is an ordinary Layer with kind storyboard.
```

Update or delete old tests that expect old docs to exist.

## 9. Out of scope

This is a docs-only consolidation phase.

Do not change runtime code.

Do not change UI behavior.

Do not modify:

```txt
lib/
test/ except architecture/documentation tests
```

Do not implement:

```txt
brush runtime behavior
timeline runtime behavior
canvas runtime behavior
storyboard runtime behavior
save/load
renderer/cache implementation
playback cache implementation
Provider/Riverpod/Bloc/ChangeNotifier/global singleton state
```

Do not reintroduce:

```txt
BrushWorkspaceScreen
BrushWorkspaceView
Brush Workspace button
MainCanvasBrushHost.fixture()
BrushCanvasFixture under lib
debug controls
Frame 1 / Frame 2 / Frame 3 buttons
Debug Reset Session
Black / Red temporary buttons
```

## 10. Required search commands

Run:

```bash
find docs -maxdepth 1 -type f | sort
```

Run:

```bash
rg "LongTerm_|Brush_Architecture_Current|Bitmap_Canvas_Brush_Architecture|Brush_App_Integration_Decisions|Timeline_Stabilization_Checkpoint|LongTerm_Timeline_Range_Semantics|LongTerm_Roadmap_After_Phase_150|Architecture.md" docs test
```

Run:

```bash
rg "tile delta|TileDelta|Undo source = tile delta data|Undo should prefer tile deltas" docs test
```

Run:

```bash
rg "Current_Docs_Index|Current_Project_Architecture|Current_Implementation_Roadmap|Current_Brush_Architecture|Current_Timeline_Architecture|Current_Canvas_Cache_Storage_Architecture|Current_Storyboard_Architecture" docs test
```

Expected:

```txt
- active docs reference Current_* docs
- obsolete docs are deleted or fully replaced by Current_* docs
- tile delta is not described as current user-facing brush undo policy
- old phase/task/memo docs are not treated as current source of truth
```

## 11. Checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report clearly.

## 12. Acceptance criteria

```txt
1. docs are significantly reduced and easier to scan.
2. Current_* prefix is used for current source-of-truth docs.
3. docs/Current_Docs_Index.md exists.
4. docs/Current_Project_Architecture.md exists.
5. docs/Current_Implementation_Roadmap.md exists.
6. docs/Current_Brush_Architecture.md exists.
7. docs/Current_Timeline_Architecture.md exists.
8. docs/Current_Canvas_Cache_Storage_Architecture.md exists.
9. docs/Current_Storyboard_Architecture.md exists.
10. unnecessary old docs are deleted, not merely marked legacy.
11. Handoff remains and sections 0 through 4 are not edited.
12. Handoff no longer needs to carry detailed module architecture after section 6 cleanup.
13. module-specific details live in Current_* docs.
14. tests protect the current docs structure.
15. runtime code is unchanged.
16. flutter analyze passes.
17. flutter test passes.
```

## 13. Report back

Report:

```txt
- docs inspected
- docs kept
- docs created
- docs renamed
- docs deleted
- why any old docs were not deleted
- final docs directory list
- current source-of-truth docs list
- tests added/updated/deleted
- runtime code changed or not
- required rg search summary
- dart/flutter check results
- git status summary
```
