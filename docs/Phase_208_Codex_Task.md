# Phase 208 Codex Task

## Title

Document BrushWorkspaceCacheInvalidationSink naming and responsibility decision

## 1. Overall roadmap

Current brush integration roadmap:

```txt id="j1nbws"
1. Brush preview / UI cleanup
   - Done enough for now.
   - BrushWorkspaceScreen was removed.
   - BrushWorkspaceView was renamed to BrushCanvasPanel.
   - Temporary debug controls were removed.
   - Production fixture fallback was removed.
   - BrushCanvasFixture was moved out of production code into test helpers.

2. Production brush host separation
   - Done enough for now.
   - MainCanvasBrushHost is selection-driven.
   - Missing selection renders an empty-selection placeholder.
   - MainCanvasBrushHost.fixture() was removed.
   - Production lib code no longer imports BrushCanvasFixture.

3. Brush coordinator naming cleanup
   - Phase 206 documented the decision.
   - Phase 207 renamed BrushWorkspaceCoordinator to BrushFrameEditingCoordinator.
   - Runtime coordinator naming is now aligned with production brush frame editing.

4. Brush cache invalidation sink naming decision
   - This phase.
   - Document what BrushWorkspaceCacheInvalidationSink currently does.
   - Decide future rename target.
   - Do not rename runtime code yet.
   - Keep behavior unchanged.

5. Brush cache invalidation sink runtime rename
   - Later.
   - Rename only after the Phase 208 decision is documented and protected.

6. Brush Host Preview production-mode promotion
   - Later.

7. Bitmap canvas storage foundation
   - Later.
```

Required long-term direction:

```txt id="1hki2s"
temporary workspace UI names
-> production brush host/panel naming
-> production brush editing coordinator naming
-> cache invalidation sink naming decision
-> cache invalidation sink runtime rename
-> bitmap storage foundation
-> dirty tile tracking
-> tile delta undo
-> cache policy
-> brush rasterizer
-> canvas UI integration
```

## 2. This phase detailed roadmap

Phase 208 is a documentation and architecture-prep phase.

Implement:

```txt id="agdxzf"
1. Document the current responsibility of BrushWorkspaceCacheInvalidationSink.
2. Clarify that it is no longer tied to deleted BrushWorkspaceScreen / BrushWorkspaceView UI.
3. Decide the future rename target.
4. Preferred future name: BrushEditCacheInvalidationSink.
5. Add or update architecture tests that protect this decision.
6. Do not rename BrushWorkspaceCacheInvalidationSink yet.
7. Do not rename brush_workspace_cache_invalidation_sink.dart yet.
8. Do not change runtime behavior.
9. Do not modify BrushFrameEditingCoordinator behavior.
10. Do not touch canvas UI behavior.
```

Preferred future rename:

```txt id="tqheda"
BrushWorkspaceCacheInvalidationSink
-> BrushEditCacheInvalidationSink
```

Reason:

```txt id="xvpdyg"
- It is not a workspace screen concept.
- It is not a canvas renderer.
- It is not a playback cache implementation.
- It is the sink/boundary used by brush editing flows to request cache invalidation.
- BrushEditCacheInvalidationSink is shorter and clearer than BrushFrameEditingCacheInvalidationSink.
- BrushCanvasCacheInvalidationSink sounds too close to widget/rendering concerns.
```

Alternative names considered:

```txt id="64dl0z"
BrushFrameEditingCacheInvalidationSink
BrushCanvasCacheInvalidationSink
BrushCacheInvalidationSink
```

Decision:

```txt id="kwz8er"
Use BrushEditCacheInvalidationSink as the future rename target.
```

## 3. This phase scope

### In scope

Expected files to modify or add:

```txt id="c9vad9"
docs/Brush_App_Integration_Decisions.md
test/architecture/brush_cache_invalidation_sink_naming_decisions_test.dart
```

Optional, only if it is simpler to keep related naming decisions together:

```txt id="7ddvn7"
test/architecture/brush_coordinator_naming_decisions_test.dart
```

In scope work:

```txt id="fuu6k7"
- Add Phase 208 section to docs/Brush_App_Integration_Decisions.md.
- Document BrushWorkspaceCacheInvalidationSink current responsibility.
- Document that BrushWorkspaceCacheInvalidationSink is not deleted workspace UI.
- Document future rename target: BrushEditCacheInvalidationSink.
- Add architecture test to verify the decision is documented.
- Add guard that runtime rename is not performed in this phase.
```

### Out of scope

Do not rename:

```txt id="ll9uov"
BrushWorkspaceCacheInvalidationSink
brush_workspace_cache_invalidation_sink.dart
```

Do not modify behavior in:

```txt id="o3dlmn"
BrushFrameEditingCoordinator
MainCanvasBrushHost
BrushCanvasPanel
InteractiveBrushEditCanvasView
CanvasView
HomePage
BrushFrameStore
BrushFrameEditSessionStore
UnifiedUndoHistory
```

Do not reintroduce:

```txt id="vscs71"
BrushWorkspaceScreen
BrushWorkspaceView
Brush Workspace button
MainCanvasBrushHost.fixture()
BrushCanvasFixture under lib
Frame 1 / Frame 2 / Frame 3 debug buttons
Debug Reset Session
temporary Black / Red buttons
showDebugControls
```

Do not implement:

```txt id="1f2igg"
actual drawing
pointer input
tablet input
bitmap brush rasterizer
BitmapSurface / BitmapTile / TileCoord
DirtyTileSet / DirtyRegion
TileDeltaCommand
renderer cache
playback cache
save/load
onion skin
Photoshop / ABR brush import
Provider / Riverpod / Bloc / ChangeNotifier / global singleton state
```

## 4. Implementation instructions

### 4-1. Update Brush_App_Integration_Decisions.md

Update:

```txt id="exw6sb"
docs/Brush_App_Integration_Decisions.md
```

Add this section:

```txt id="mbccu8"
## Phase 208 BrushWorkspaceCacheInvalidationSink naming decision

Decision:
- BrushWorkspaceCacheInvalidationSink is no longer tied to deleted BrushWorkspaceScreen / BrushWorkspaceView UI.
- BrushWorkspaceCacheInvalidationSink currently acts as the cache invalidation sink boundary used by brush editing flows.
- It should be treated as a brush edit cache invalidation boundary, not as a workspace UI helper.
- The current name still contains retired "Workspace" wording, but runtime behavior should not be changed in this phase.

Preferred future rename:
- BrushWorkspaceCacheInvalidationSink -> BrushEditCacheInvalidationSink

Why BrushEditCacheInvalidationSink:
- It describes the brush editing flow that emits invalidation requests.
- It avoids tying the type to deleted workspace UI.
- It avoids making the name too long.
- It is less renderer/widget-like than BrushCanvasCacheInvalidationSink.
- It keeps the concept separate from actual renderer/cache implementations.

Alternatives considered:
- BrushFrameEditingCacheInvalidationSink: accurate but too long.
- BrushCanvasCacheInvalidationSink: sounds too much like canvas rendering/widget cache.
- BrushCacheInvalidationSink: acceptable, but too broad if future brush cache concepts expand.

Implemented in Phase 208:
- Documented BrushWorkspaceCacheInvalidationSink responsibility and future rename target.
- Added architecture coverage for the naming decision.
- Left runtime behavior unchanged.
- Did not rename BrushWorkspaceCacheInvalidationSink yet.
- Did not rename brush_workspace_cache_invalidation_sink.dart yet.
- Did not reintroduce deleted workspace UI or debug controls.

Still out of scope:
- renaming BrushWorkspaceCacheInvalidationSink
- renaming brush_workspace_cache_invalidation_sink.dart
- changing BrushFrameEditingCoordinator behavior
- changing brush host behavior
- changing canvas UI behavior
- actual drawing
- bitmap storage foundation
- dirty tile tracking
- tile delta undo
- renderer/cache/save/load

Future cleanup:
- Phase 209 should rename BrushWorkspaceCacheInvalidationSink to BrushEditCacheInvalidationSink if no new responsibility conflict is found.
- Actual cache implementation should remain separate from this naming cleanup.
```

### 4-2. Add architecture test

Create:

```txt id="w11kwa"
test/architecture/brush_cache_invalidation_sink_naming_decisions_test.dart
```

Suggested behavior:

```txt id="uxm66x"
- Read docs/Brush_App_Integration_Decisions.md.
- Verify that the Phase 208 section exists.
- Verify that BrushWorkspaceCacheInvalidationSink is documented as no longer tied to deleted workspace UI.
- Verify that BrushEditCacheInvalidationSink is documented as the future rename target.
- Verify that runtime behavior is documented as unchanged.
- Verify that the runtime rename is explicitly not performed in this phase.
```

Suggested test style:

```dart id="1vl2vj"
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brush cache invalidation sink naming decisions', () {
    test('documents BrushWorkspaceCacheInvalidationSink naming decision', () {
      final doc = File(
        'docs/Brush_App_Integration_Decisions.md',
      ).readAsStringSync();

      expect(
        doc,
        contains(
          '## Phase 208 BrushWorkspaceCacheInvalidationSink naming decision',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink is no longer tied to deleted '
          'BrushWorkspaceScreen / BrushWorkspaceView UI.',
        ),
      );
      expect(
        doc,
        contains(
          'BrushWorkspaceCacheInvalidationSink -> '
          'BrushEditCacheInvalidationSink',
        ),
      );
      expect(doc, contains('Left runtime behavior unchanged.'));
      expect(
        doc,
        contains('Did not rename BrushWorkspaceCacheInvalidationSink yet.'),
      );
    });

    test('keeps runtime sink rename out of Phase 208 scope', () {
      final oldSink = File(
        'lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart',
      );
      final futureSink = File(
        'lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart',
      );

      expect(oldSink.existsSync(), isTrue);
      expect(futureSink.existsSync(), isFalse);
    });
  });
}
```

You may adjust exact strings if necessary, but keep the test meaningful and not overly fragile.

### 4-3. Do not rename runtime code yet

Do not rename:

```txt id="uenzul"
lib/src/ui/brush/brush_workspace_cache_invalidation_sink.dart
class BrushWorkspaceCacheInvalidationSink
```

Do not create:

```txt id="mpcdae"
lib/src/ui/brush/brush_edit_cache_invalidation_sink.dart
class BrushEditCacheInvalidationSink
```

Those are for the next phase.

### 4-4. Do not alter BrushFrameEditingCoordinator

Do not modify behavior in:

```txt id="64sd6s"
lib/src/services/brush_frame_editing_coordinator.dart
```

This phase is not a coordinator behavior phase.

### 4-5. Do not update Handoff sections 0 through 4

If updating:

```txt id="xnlzch"
docs/Handoff_QuickAnimaker_v2_Current.md
```

only update section 6 or later.

Do not edit:

```txt id="6vhgwu"
section 0
section 1
section 2
section 3
section 4
```

This phase does not require handoff edits unless absolutely necessary.

## 5. Checks / format / commit guidance

Run:

```bash id="2g4qmr"
dart format lib test
flutter analyze
flutter test
git status
```

Also run:

```bash id="583clo"
rg "BrushWorkspaceCacheInvalidationSink|BrushEditCacheInvalidationSink|brush_workspace_cache_invalidation_sink|brush_edit_cache_invalidation_sink|BrushFrameEditingCoordinator" docs test lib
```

Expected:

```txt id="tkix7x"
- BrushWorkspaceCacheInvalidationSink still exists in runtime code.
- brush_workspace_cache_invalidation_sink.dart still exists.
- BrushEditCacheInvalidationSink appears only in docs/tests as future rename target.
- brush_edit_cache_invalidation_sink.dart does not exist yet.
- BrushFrameEditingCoordinator remains unchanged.
- No deleted workspace UI/debug controls are reintroduced.
```

If Dart/Flutter are unavailable, report that clearly.

## Acceptance criteria

```txt id="hz8yqi"
1. docs/Brush_App_Integration_Decisions.md has Phase 208 section.
2. The current responsibility of BrushWorkspaceCacheInvalidationSink is documented.
3. Future rename target BrushEditCacheInvalidationSink is documented.
4. Architecture test exists and passes.
5. BrushWorkspaceCacheInvalidationSink is not renamed yet.
6. brush_workspace_cache_invalidation_sink.dart is not renamed yet.
7. BrushFrameEditingCoordinator behavior is unchanged.
8. MainCanvasBrushHost behavior is unchanged.
9. BrushCanvasPanel behavior is unchanged.
10. MainCanvasBrushHost.fixture() is not reintroduced.
11. BrushCanvasFixture is not reintroduced under lib.
12. Debug controls are not reintroduced.
13. BrushWorkspaceScreen / BrushWorkspaceView are not reintroduced.
14. flutter analyze passes.
15. flutter test passes.
```

## Android Studio manual confirmation

This phase should not require meaningful manual UI validation because it is docs/test only.

Still, after merge and local checks, confirm briefly:

```txt id="5dekd9"
1. App launches normally.
2. Default CanvasView still appears.
3. Brush Host Preview toggle still exists.
4. Brush Host Preview behavior is unchanged.
5. Empty selection still shows placeholder.
6. No Frame 1 / Frame 2 / Frame 3 debug buttons.
7. No Debug Reset Session.
8. No Brush Workspace button.
```

## Report back

Report:

```txt id="kx9vq3"
- changed files
- whether Phase 208 docs were added
- whether architecture test was added
- whether BrushEditCacheInvalidationSink is documented as future rename target
- whether BrushWorkspaceCacheInvalidationSink runtime code was intentionally not renamed
- whether brush_workspace_cache_invalidation_sink.dart was intentionally not renamed
- whether BrushFrameEditingCoordinator behavior stayed unchanged
- whether runtime behavior stayed unchanged
- whether deleted UI/debug controls were not reintroduced
- checks run and results
- rg search summary
- git status summary
```
