# Phase 195 Codex Task

## Title

Brush workspace stabilization bundle

## Current context

Phase 194 introduced the first app-level Brush workspace integration.

Implemented:

```txt id="y0mnv6"
- BrushWorkspaceScreen
- BrushFrameEditSessionStore
- BrushWorkspaceCoordinator
- app entry button
- Frame 1 / Frame 2 / Frame 3 switching
- independent BrushEditSessionState per BrushFrameKey
- paint commit recording into BrushFrameStore
- paint commit recording into UnifiedUndoHistory
```

Follow-up fixes corrected test commit behavior:

```txt id="rp26ya"
- commit detection now records paint only when session undoCount increases
- no-op commits must not create BrushPaintCommand or UnifiedUndoHistory entries
- coordinator tests use non-no-op dabs
```

Phase 195 should stabilize the workspace behavior before deeper timeline/layer integration.

## Goal

Make the Brush workspace safer and clearer as an app-level integration surface.

This phase should focus on:

```txt id="ijp83i"
1. reset behavior clarity
2. cross-frame undo/redo tests
3. no-op commit safety tests
4. workspace debug/status clarity
5. protected Storyboard/Timeline non-regression
```

Do not jump into full timeline/layer production integration yet.

## Important architecture rules

Keep these rules:

```txt id="jm5ufj"
- Existing InteractiveBrushEditCanvasView is the real reusable canvas component.
- BrushCanvasSmokeScreen remains a dev/manual harness, not the production app workspace.
- BrushWorkspaceScreen is the current app-level shell around the existing canvas.
- Frame remains lightweight.
- Drawing/session payload stays outside Frame.
- BrushFrameStore owns frame-local paint metadata/state.
- BrushFrameEditSessionStore owns interactive BrushEditSessionState per BrushFrameKey.
- UnifiedUndoHistory owns the only global user-facing undo/redo order.
- BrushFrameStore must not decide undo/redo order.
```

## Required work

### 1. Clarify reset behavior

The current `Reset Session` button resets only the active `BrushEditSessionState`.

That is potentially misleading because:

```txt id="mo8g6r"
- the canvas may appear cleared
- BrushFrameStore command metadata may still remain
- UnifiedUndoHistory may still contain entries
```

In this phase, choose one of the following safe solutions.

Preferred simple solution:

```txt id="m5r8my"
Rename the button to "Debug Reset Session".
Make it clearly dev/debug-only.
Add status/debug text explaining it resets only the interactive session for the active frame.
Do not pretend this is a production Clear Frame command.
```

Alternative, only if simple and safe:

```txt id="c4r9uc"
Implement coordinator.resetActiveFrameDebugSessionOnly()
and route the button through it.
Still label it as debug-only.
```

Do not implement production clear-frame undo semantics yet unless the existing architecture already supports it cleanly.

Do not create a fake clear command that corrupts BrushFrameStore / UnifiedUndoHistory consistency.

### 2. Cross-frame undo/redo behavior

Add tests that verify global undo order across frames.

Expected behavior:

```txt id="ngv6ai"
1. Select Frame 1.
2. Commit paint A.
3. Select Frame 2.
4. Commit paint B.
5. Undo once.
   - UnifiedUndoHistory chooses paint B.
   - Frame 2 command becomes hiddenByUndo.
   - Frame 1 remains live.
6. Undo again.
   - UnifiedUndoHistory chooses paint A.
   - Frame 1 command becomes hiddenByUndo.
7. Redo once.
   - Frame 1 command becomes live again.
8. Redo again.
   - Frame 2 command becomes live again.
```

Important:

```txt id="mna9rh"
The active frame does not have to automatically switch during cross-frame undo/redo.
But the target frame's session/state must update correctly.
```

If the current coordinator cannot safely apply cross-frame session undo/redo yet, document the limitation and add a test for the current intended behavior. However, prefer real cross-frame paint undo/redo because the coordinator already stores targetKey in UndoPayloadRef.

### 3. No-op commit safety

Add or strengthen tests confirming:

```txt id="xstiwf"
- no-op commit results do not create BrushPaintCommand
- no-op commit results do not create UnifiedUndoHistory entries
- no-op commit results still update sessionStore if result.sessionState differs
- repeated same-pixel same-color dabs are treated as no-op after the first commit
```

This protects the bug chain from PR 251–254.

### 4. Workspace UI status clarity

Improve `BrushWorkspaceScreen` status text enough for manual checking.

The status should show:

```txt id="mx33km"
- active frame id
- active frame command count
- active frame live command count
- active frame hiddenByUndo count
- active frame deferredBake count
- global undo count
- global redo count
```

Keep stable keys where useful.

Do not overbuild a production toolbar.

### 5. Tests for Debug Reset Session

Add a widget or service test for reset behavior.

If using the preferred simple solution:

```txt id="svdu69"
- button label is Debug Reset Session
- pressing it resets only the active session
- debug/status text makes clear it is session-only
```

Do not assert that BrushFrameStore or UnifiedUndoHistory are cleared unless you intentionally implement that behavior.

### 6. Protected app behavior

Existing protected tests must remain passing:

```txt id="u81qum"
- StoryboardPanel tests
- TimelinePanel tests
- brush smoke/dev canvas tests
- BrushWorkspaceScreen tests
```

Do not weaken protected tests.

## Suggested files

Likely changed files:

```txt id="6oxzgj"
lib/src/ui/brush/brush_workspace_screen.dart
lib/src/services/brush_workspace_coordinator.dart
test/services/brush_workspace_coordinator_test.dart
test/ui/brush_workspace_screen_test.dart
docs/Brush_App_Integration_Decisions.md
```

Only modify files that are actually needed.

## Documentation update

Update:

```txt id="rdqn6p"
docs/Brush_App_Integration_Decisions.md
```

Add:

```txt id="h9l92v"
## Phase 195 workspace stabilization

Implemented:
- Debug reset behavior clarified.
- Cross-frame undo/redo behavior covered by tests.
- No-op commit safety covered by tests.
- BrushWorkspace status/debug text improved.

Still out of scope:
- production Clear Frame command
- save/load
- renderer/playback cache
- actual deferred bitmap baking
- full timeline/layer panel integration
```

Do not claim Brush is fully complete yet.

## Not allowed

Do not implement:

```txt id="jjuj8f"
- save/load
- renderer cache
- playback cache
- actual deferred bitmap baking
- production clear-frame command unless fully consistent with undo/history
- timeline rewrite
- layer panel rewrite
- storyboard drawing
- onion skin
- pressure
- smoothing
- eraser
- selection
- Provider/Riverpod/Bloc/ChangeNotifier
- global singleton app state
```

## Required checks

Run:

```bash id="g25e8a"
dart format lib test
flutter analyze
flutter test
git status
```

If a tool is unavailable, report that clearly.

## Report back

Report:

```txt id="rqy3bc"
- changed files
- reset behavior decision
- cross-frame undo/redo behavior
- no-op commit safety tests
- workspace status/debug changes
- protected tests status
- check results
- git status summary
```
