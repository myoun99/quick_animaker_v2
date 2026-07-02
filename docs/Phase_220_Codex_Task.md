# Phase 220 — Test Architecture Cleanup and CI

## Repository

`myoun99/quick_animaker_v2`

Base branch:

`master`

Suggested working branch:

`codex/phase-220-test-architecture-cleanup-and-ci`

## Background

Phase 219 completed the Brush T2 foundation:

* live brush drawing is fast and usable
* source-stroke commits are routed through the production brush path
* `BrushDab.sequence` no longer uses invalid negative values
* brittle documentation-content tests were removed
* some tests were changed from exact implementation counts to stable behavior checks

However, the test suite still needs a dedicated cleanup phase before more brush features are added.

The current project goal is long-term safe, modular, lightweight code. Tests must support that goal. Tests should not make the codebase harder to refactor by locking exact prose, implementation names, duplicated constants, or temporary structure.

This phase also introduces GitHub Actions CI so PRs automatically run formatting, analysis, and tests.

## Required reading before implementation

Read these files directly before changing code:

* `docs/Handoff_QuickAnimaker_v2_Current.md`

    * Read sections 0 through 4 directly.
    * Do not modify sections 0 through 4.
    * Do not modify section 8 in this phase.
* `docs/Current_Docs_Index.md`
* `docs/Current_Project_Architecture.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_UI_Product_Policy.md`, if UI tests are touched

## Main goals

1. Add a current test policy document.
2. Clean up remaining brittle tests.
3. Remove hardcoded policy values from tests.
4. Keep useful forbidden legacy-boundary guards.
5. Add GitHub Actions CI for Flutter checks.
6. Keep runtime behavior unchanged unless a test reveals a real bug.

## Required change 1: Add `docs/Current_Test_Architecture.md`

Create:

`docs/Current_Test_Architecture.md`

This document is now the current source of truth for test policy.

It should include the following policies.

### Test philosophy

Tests should verify:

* user-visible behavior
* domain invariants
* public boundaries
* stable ownership rules
* absence of dangerous legacy runtime paths
* serialization/backward compatibility where applicable
* undo/redo semantics
* cache/source-of-truth boundaries
* UI smoke behavior through widgets where possible

Tests should not verify:

* exact documentation wording
* exact normalized documentation phrases
* exact prose headings in `docs/*.md`
* temporary implementation method names
* private helper names
* exact sampled dab counts unless the count is a deliberate public contract
* duplicated default sizes or policy numbers
* UI text labels when a stable key/semantic behavior is more appropriate

### Documentation tests

Do not add regular `flutter test` tests that read `docs/*.md` and check exact wording, normalized phrases, headings, or long-form policy prose.

Documentation is reviewed directly by AI during planning and PR review. Code tests should not fail simply because architecture notes were rewritten more clearly.

Acceptable documentation-related checks:

* none by default
* if absolutely needed, only lightweight existence/index checks outside normal runtime test pressure

### Hardcoding policy

Avoid hardcoded product-policy values in tests.

Do not duplicate values such as:

* project camera size
* default cut canvas size
* default cut duration
* brush undo limits
* tile sizes
* canvas sizes
* default frame/range constants

When a value is a product/domain policy, use a shared production constant or a test fixture constant that delegates to the production constant.

If a shared constant does not exist, introduce one in the correct production module.

Small local test geometry values are allowed only when they are clearly input examples, not duplicated product policy. Prefer named local constants in tests when the value has semantic meaning.

### Source string checks

Avoid positive source-string checks such as:

```dart
expect(source, contains('SomePrivateMethodName'));
expect(source, contains('_somePrivateField'));
expect(source, contains('SomeImplementationWidget'));
```

These make refactoring unsafe.

Allowed source-string checks:

* narrow forbidden legacy API checks
* dependency guards that prevent banned architecture from being reintroduced

Examples of allowed forbidden checks:

* `TileDelta`
* `TileDeltaCommand`
* `commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation`
* `brushSurfaceEditForBrushDabSequenceOnBitmapSurface`
* `applyBrushSurfaceEditToCanvasSurfaceState`
* `undoLatestBrushBitmapMaterialization`
* `redoLatestBrushBitmapMaterialization`
* `Provider`
* `Riverpod`
* `Bloc`
* `ChangeNotifier`

Even forbidden checks should be scoped to relevant files or boundaries.

### Brush test policy

Brush tests should focus on:

* source stroke commit reaches `BrushFrameStore`
* source dabs are preserved as source data
* live editing does not generate cache invalidation
* live editing does not bake bitmap data
* active stroke overlay is temporary
* global undo hides commands using `hiddenCommandIds`
* global redo restores commands
* sequence values are non-negative and strictly increasing where appropriate
* fast drag creates enough sampled dabs to avoid broken strokes
* tiny movement does not create excessive duplicate dabs

Brush tests should not lock exact sampled dab counts unless the count is explicitly part of a public algorithm contract.

### Architecture guard policy

Architecture guard tests should protect stable boundaries:

* `Frame` remains lightweight and does not own brush payloads or caches
* brush source payloads live in `BrushFrameStore` or equivalent storage boundary
* cache images are derived, not source of truth
* production UI does not call internal bitmap materialization undo/redo
* global undo/redo remains the user-facing undo path
* app-wide Provider/Riverpod/Bloc/ChangeNotifier style state management is not introduced without an explicit architecture phase

Architecture guard tests should not freeze temporary implementation names.

## Required change 2: Update current docs index and handoff entry point

Update `docs/Current_Docs_Index.md`:

Add:

`- Test architecture / test policy: docs/Current_Test_Architecture.md`

Do not make old phase docs override this file.

Update `docs/Handoff_QuickAnimaker_v2_Current.md` only where allowed:

* Do not modify sections 0 through 4.
* Do not modify section 8 in this phase.
* In section 5, add `docs/Current_Test_Architecture.md` to the current document list.
* In section 7, replace the old documentation test rule with the new direction:

    * regular tests should not check exact docs prose
    * test policy lives in `docs/Current_Test_Architecture.md`
    * tests should focus on behavior, stable boundaries, shared constants, and forbidden legacy paths

## Required change 3: Audit `test/` for brittle tests

Search all tests for these patterns:

* `readAsStringSync`
* `contains('`
* `contains("`
* `RegExp`
* `docs/`
* exact arrays of sampled sequence values
* hardcoded `CanvasSize(width:`
* hardcoded `1920`
* hardcoded `1080`
* hardcoded `2340`
* hardcoded `1654`
* hardcoded `320`
* hardcoded `240`
* hardcoded `24` where it means default cut duration or FPS
* hardcoded widget implementation names
* exact private method or private field names

For each occurrence, classify it:

1. Good behavior test — keep.
2. Stable forbidden-boundary guard — keep or narrow.
3. Brittle positive implementation check — remove or replace with behavior test.
4. Duplicated product policy value — replace with shared constant.
5. Documentation prose test — remove from normal `flutter test`.

Do not do a superficial search-and-replace. Make each test more stable.

## Required change 4: Refactor test helpers / fixtures

Create or improve shared test helpers where helpful.

Possible helper areas:

* brush dab fixture
* brush frame key fixture
* brush coordinator fixture
* brush canvas gesture helper
* sequence assertion helper
* no-cache-invalidation assertion helper
* default project/cut factory helper

Prefer helper files under clear test locations, for example:

* `test/helpers/`
* `test/fixtures/`
* or existing nearby UI/service test helper files if already established

Do not create a giant test helper god object. Keep helpers small and module-specific.

## Required change 5: Keep existing good behavior coverage

After cleanup, keep or add stable tests for:

* `BrushDab.sequence` is never negative
* brush dab interpolation preserves endpoint
* fast drag produces more than raw endpoints
* tiny movement avoids duplicate dabs
* pointer down does not throw
* pointer move does not throw
* tap stroke commits source dabs
* drag stroke commits source dabs
* pointer cancel does not commit
* second pointer is ignored while first pointer is active
* source stroke commit stores dabs in `BrushFrameStore`
* global undo hides a command through `hiddenCommandIds`
* global redo restores the command
* live editing does not mutate bitmap materialization session state
* live editing does not generate cache invalidation
* `Frame` remains lightweight
* default project camera uses `defaultProjectCameraSize`
* default cut canvas uses `defaultCutCanvasSize`

## Required change 6: Add GitHub Actions CI

Add:

`.github/workflows/ci.yml`

The workflow should run on:

* pull requests targeting `master`
* pushes to `master`

Use a simple Flutter CI job.

Required checks:

```bash
flutter --version
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Use a maintained Flutter setup action. Keep the workflow simple and readable.

Suggested shape:

```yaml
name: CI

on:
  pull_request:
    branches: [master]
  push:
    branches: [master]

jobs:
  flutter:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Show Flutter version
        run: flutter --version

      - name: Install dependencies
        run: flutter pub get

      - name: Check formatting
        run: dart format --set-exit-if-changed lib test

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test
```

If the repository needs a specific Flutter version, infer it from project files if present. If no version is specified, use stable.

Do not add deployment, release, secrets, or publishing logic.

Do not add AI/agent workflows.

## Required change 7: Run validation

Run locally if available:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

Also run or verify:

```bash
git diff --check
```

If Flutter/Dart is unavailable in the Codex environment, state that clearly, but still run:

```bash
git diff --check
git status --short
```

## Do not do in this phase

Do not add new brush features.

Do not change brush runtime behavior unless a test exposes a real bug.

Do not implement save/load.

Do not implement playback cache.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or another app-wide state management package.

Do not reintroduce document prose tests.

Do not reintroduce exact sampled dab count tests.

Do not reintroduce hardcoded product policy values in tests.

Do not modify handoff sections 0 through 4.

Do not modify handoff section 8.

## Expected PR result

The PR should include:

* `docs/Current_Test_Architecture.md`
* updated `docs/Current_Docs_Index.md`
* updated allowed handoff section 5/7 only, if needed
* `.github/workflows/ci.yml`
* cleaned tests with fewer brittle implementation-name/string checks
* shared constants or fixtures replacing duplicated product-policy hardcoding
* no runtime behavior regression
* passing local checks if Flutter is available
