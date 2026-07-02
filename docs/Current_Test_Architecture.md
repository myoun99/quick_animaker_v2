# Current Test Architecture

## Status

This is the current source of truth for QuickAnimaker v2 test policy. Older phase docs are historical records and must not override this file.

## Test philosophy

Tests should verify:

- user-visible behavior
- domain invariants
- public boundaries
- stable ownership rules
- absence of dangerous legacy runtime paths
- serialization and backward compatibility where applicable
- undo/redo semantics
- cache/source-of-truth boundaries
- UI smoke behavior through widgets where possible

Tests should not verify:

- exact documentation wording
- exact normalized documentation phrases
- exact prose headings in `docs/*.md`
- temporary implementation method names
- private helper names
- exact sampled dab counts unless the count is a deliberate public contract
- duplicated default sizes or policy numbers
- UI text labels when a stable key or semantic behavior is more appropriate

## Documentation tests

Do not add regular `flutter test` tests that read `docs/*.md` and check exact wording, normalized phrases, headings, or long-form policy prose.

Documentation is reviewed directly during planning and PR review. Code tests should not fail simply because architecture notes were rewritten more clearly.

Acceptable documentation-related checks are none by default. If absolutely needed, keep them to lightweight existence or index checks outside normal runtime test pressure.

## Hardcoding policy

Avoid hardcoded product-policy values in tests.

Do not duplicate values such as:

- project camera size
- default cut canvas size
- default cut duration
- brush undo limits
- tile sizes
- canvas sizes
- default frame/range constants

When a value is a product or domain policy, use a shared production constant or a test fixture constant that delegates to the production constant.

If a shared constant does not exist, introduce one in the correct production module.

Small local test geometry values are allowed only when they are clearly input examples, not duplicated product policy. Prefer named local constants when the value has semantic meaning.

## Source string checks

Avoid positive source-string checks such as checking for private method names, private fields, or specific implementation widgets. These make refactoring unsafe.

Allowed source-string checks are narrow forbidden legacy API checks and dependency guards that prevent banned architecture from being reintroduced.

Examples of allowed forbidden checks include:

- `TileDelta`
- `TileDeltaCommand`
- `commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation`
- `brushSurfaceEditForBrushDabSequenceOnBitmapSurface`
- `applyBrushSurfaceEditToCanvasSurfaceState`
- `undoLatestBrushBitmapMaterialization`
- `redoLatestBrushBitmapMaterialization`
- `Provider`
- `Riverpod`
- `Bloc`
- `ChangeNotifier`

Even forbidden checks should be scoped to relevant files or boundaries.

## Brush test policy

Brush tests should focus on:

- source stroke commit reaches `BrushFrameStore`
- source dabs are preserved as source data
- live editing does not generate cache invalidation
- live editing does not bake bitmap data
- active stroke overlay is temporary
- global undo hides commands using `hiddenCommandIds`
- global redo restores commands
- sequence values are non-negative and strictly increasing where appropriate
- fast drag creates enough sampled dabs to avoid broken strokes
- tiny movement does not create excessive duplicate dabs

Brush tests should not lock exact sampled dab counts unless the count is explicitly part of a public algorithm contract.

## Architecture guard policy

Architecture guard tests should protect stable boundaries:

- `Frame` remains lightweight and does not own brush payloads or caches
- brush source payloads live in `BrushFrameStore` or equivalent storage boundary
- cache images are derived, not source of truth
- production UI does not call internal bitmap materialization undo/redo
- global undo/redo remains the user-facing undo path
- app-wide Provider/Riverpod/Bloc/ChangeNotifier style state management is not introduced without an explicit architecture phase

Architecture guard tests should not freeze temporary implementation names.
