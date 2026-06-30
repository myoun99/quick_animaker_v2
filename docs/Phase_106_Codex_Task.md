# Phase 106 Codex Task - Timeline Frame Count Naming Cleanup

## Goal

Clean up ambiguous Timeline frame-count naming after Phase 104R and Phase 105.

This is not a new feature phase.

The goal is to make the code safer long-term by ensuring that playback duration, visible timeline range, authored timeline extent, and UI frame count names are not confused again.

## Background

After Phase 104R:

- Cut.duration means playback/export duration only.
- Cut.duration is not a selection limit.
- Cut.duration is not an edit limit.
- Cut.duration is not a data deletion boundary.
- visibleFrameCount is computed from playback duration + safety/work-area frames.
- authored timeline data can exist outside Cut.duration.
- authored timeline data can exist outside the currently visible range and must remain stored.
- outside-playback visible frames are selectable and editable.

After Phase 105:

- the cut end boundary is visible in both the frame ruler and body grid.
- ruler/body boundary positions use the same playback boundary calculation.

However, some public widget/API names may still use ambiguous names like `frameCount`.

That is dangerous long-term because `frameCount` can be misunderstood as:

- playback duration
- visible frame count
- authored data extent
- editable frame count
- total project frame count

This phase should reduce that ambiguity.

## Core Rule

Avoid vague `frameCount` naming when the value has a specific meaning.

Prefer explicit names:

- playbackFrameCount
- visibleFrameCount
- safetyFrameCount
- authoredTimelineExtentFrameCount
- playbackEndFrameIndexExclusive
- visibleEndFrameIndexExclusive

## Required Changes

### 1. Rename ambiguous TimelinePanel API where appropriate

Find Timeline UI widgets that receive a value named `frameCount` but actually mean playback duration.

Likely widgets:

- TimelinePanel
- LayerTimelineGrid
- TimelineFrameRuler
- related private widgets/classes

Rename that API to:

- playbackFrameCount

For example, prefer:

- playbackFrameCount: _activeCutPlaybackFrameCount

over:

- frameCount: _activeCutPlaybackFrameCount

If changing every public argument at once is too large, at minimum update the top-level TimelinePanel and LayerTimelineGrid API so future callers cannot confuse the meaning.

### 2. Keep visible range internal and explicit

LayerTimelineGrid should continue to compute visibleFrameCount through TimelineFrameRange.

Do not pass visibleFrameCount as playbackFrameCount.

Do not rename visibleFrameCount back to frameCount.

Keep the policy flow clear:

- playbackFrameCount comes from Cut.duration
- TimelineFrameRange computes visibleFrameCount
- virtualization/rendering uses visibleFrameCount
- ruler/body boundary uses playbackFrameCount

### 3. Remove deprecated totalFrameCount usage from production code

TimelineController now has:

- authoredTimelineExtentFrameCount
- deprecated totalFrameCount alias

Search production code for usage of:

- totalFrameCount

Replace production usage with:

- authoredTimelineExtentFrameCount

Only keep the deprecated alias for compatibility if tests or older code still need it.

Do not remove the deprecated alias unless all code and tests are safely migrated and no external compatibility issue exists.

### 4. Test names should also use clear terms

Update test descriptions and helper parameter names where they still use ambiguous `frameCount` incorrectly.

Examples:

Prefer:

- playbackFrameCount
- visibleFrameCount
- safetyFrameCount
- authored extent

Avoid:

- frameCount

Exception:
If a test is checking a legacy deprecated API named `totalFrameCount`, it may mention that name explicitly.

### 5. Preserve all Phase 104R behavior

Do not change behavior.

This phase is naming/API cleanup only.

Must preserve:

- defaultCutDurationFrames = 24
- defaultTimelineSafetyFrameCount = 24
- Cut.duration as playback/export length only
- visibleFrameCount = max(playbackFrameCount + safetyFrameCount, minimumVisibleFrameCells)
- outside-playback visible frame selection
- outside-playback visible frame editing
- authored data outside playback remains visible when inside visible range
- authored data outside visible range remains stored but hidden
- cut end boundary in body grid
- cut end boundary in ruler
- ruler/body boundary alignment
- sticky ruler behavior
- ruler scrub behavior
- no overflow behavior

### 6. Preserve stable widget keys

Do not rename existing widget keys unless absolutely necessary.

Preserve:

- timeline-frame-ruler
- timeline-frame-ruler-scrub-area
- timeline-frame-header-row
- timeline-frame-header-<frameIndex>
- timeline-frame-scroll-viewport
- timeline-frame-scroll-content
- timeline-cut-end-boundary
- timeline-cut-end-boundary-ruler
- timeline-playhead
- timeline-playhead-column
- timeline-horizontal-scrollbar
- timeline-vertical-scrollbar

This phase is about code/API naming, not test key renaming.

## Suggested Files

Likely:

- lib/src/ui/home_page.dart
- lib/src/ui/timeline/timeline_panel.dart
- lib/src/ui/timeline/layer_timeline_grid.dart
- lib/src/ui/timeline/timeline_frame_ruler.dart
- lib/src/ui/timeline/timeline_frame_range_policy.dart
- lib/src/controllers/timeline_controller.dart
- test/ui/layer_timeline_grid_test.dart
- test/ui/timeline/timeline_frame_ruler_test.dart
- test/ui/timeline/timeline_frame_range_policy_test.dart
- test/controllers/timeline_controller_test.dart
- test/widget_test.dart

Only edit files that are actually needed.

## Out of Scope

Do not implement:

- exposure block visuals
- exposure handles
- exposure drag editing
- cut duration editing UI
- playback system
- export system
- zoom
- snapping
- auto-scroll
- StoryboardPanel changes
- renderer/cache/persistence changes
- new state management
- Provider/Riverpod/Bloc/ChangeNotifier
- data trimming
- destructive deletion of timeline entries

## Required Tests

Update existing tests if necessary so they compile with the renamed APIs.

Add small tests only if needed.

Important test coverage that must still pass:

- default Cut duration is 24
- newly created Cut duration is 24
- safety/work-area frame count is 24
- visible frame count is playback + safety
- outside-playback visible frames are selectable
- outside-playback visible frames are editable
- authored data outside playback remains visible inside visible range
- authored data outside visible range remains hidden but stored
- cut end boundary exists in body grid
- cut end boundary exists in ruler
- body/ruler boundaries stay aligned
- ruler scrub still works
- sticky ruler has no overflow
- cut switching tests still pass

## Acceptance Criteria

This phase is complete when:

1. Timeline UI API names clearly distinguish playbackFrameCount from visibleFrameCount.
2. Ambiguous production usage of `frameCount` is reduced or eliminated where it means playback duration.
3. Production code no longer uses TimelineController.totalFrameCount where authoredTimelineExtentFrameCount is meant.
4. TimelineFrameRange remains the source of visibleFrameCount calculation.
5. Cut.duration remains playback/export duration only.
6. Phase 104R behavior is unchanged.
7. Phase 105 ruler/body cut boundary behavior is unchanged.
8. No stable widget keys are broken.
9. dart format lib test passes.
10. flutter analyze passes.
11. flutter test passes.
12. git status is clean or only expected files are changed.

## Report Back

Report:

- changed files
- which APIs were renamed from frameCount to playbackFrameCount
- whether TimelinePanel API was renamed
- whether LayerTimelineGrid API was renamed
- whether any production totalFrameCount usage remains
- confirmation that visibleFrameCount calculation still uses TimelineFrameRange
- confirmation that Phase 104R behavior was not changed
- confirmation that Phase 105 ruler/body boundary behavior was not changed
- analyze result
- full test result
- git status summary