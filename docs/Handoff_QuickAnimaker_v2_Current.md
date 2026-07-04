# QuickAnimaker v2 인수인계문

## 중요 : 인수인계문 수정할 시, 0번부터 4번까지는 사용자가 수정한다. AI는 5번부터만 수정을 허용한다.

## 0. 문서 목적

이 문서는 QuickAnimaker v2 프로젝트를 다음 GPT 챗이나 다음 작업 세션에서 이어가기 위한 최신 인수인계문이다.

이 문서는 과거 handoff 문서를 대체한다.

대화는 한국어로 진행한다.

AI는 매 답변 시 사용자에 의해 최신화되는 0번부터 4번까지를 항상 직접 읽어서 확인한다.
5번부터, 또한 코덱스 주문서를 제외한 메모용 문서는 사용자와 프로그램의 구조에 대해 상담하고 결정할 때 결과를 문서의 룰에 맞춰서 수정하여 반영한다. 

8번 항목은 다음 챗을 위한 인수인계 용도로서 사용한다.

---

## 1. 프로젝트 개요

QuickAnimaker v2는 Flutter/Dart 기반 2D 애니메이션 제작 프로그램이다.

목표는 TVPaint 스타일의 2D bitmap animation tool이다.

그 외 참고 소프트 : Flash,ClipStudio,OpenToonz,Photoshop

사용자는 실제 2D 애니메이터이며, 일본 애니메이션 제작 흐름에 맞는 다음 구조를 원한다.

## 2. 저장소 정보

GitHub repository:
myoun99/quick_animaker_v2


기본 브랜치:
master


로컬 경로:
C:\Users\gunoo\Documents\quick_animaker_v2

## 3. GPT와의 대화 흐름
1. AI: 이번 Phase에서 만들 계획 간단 명료하게 안내
    - 파트 로드맵 (현재 위치 표시, ex) 1. 브러시 작업 2. 콘티 패널 )
    - 세부 로드맵 (현재 위치 표시, 현재 파트가 완료될 시점까지 계획하여 안내 ex) 1-1 브러시 기초 다지기 1-2. 브러시 실 작업 1-3 브러시 안정화 1-4 브러시 파트 완료)
    - 이번 페이즈에서 구현할 것
    - 장기적인 면에서 안전하고 효율적인지

2. 사용자: 진행하자

3. AI: 담백하게 실행용 안내만 제공
    - 만들 문서 파일명 안내 (기존 흐름인 Phase_숫자_Codex_Task의 이름 규칙을 지킨다)
    - 문서 내용 (영어)
    - git add / commit / push (명령어 간략하게 안내)
    - Codex 주문서 (영어)

4. 사용자: PR 확인해줘

5. AI: PR 리뷰
    - 코드 확인
    - 문제점 확인
    - 장기적인 면에서 안전하고 효율적인지 판단
    - 머지 판단 ok일 경우 AI가 머지
    - 안드로이드 스튜디오를 통한 수동 확인 리스트 안내
    - 판단 no일 경우 6-2 진행

6-1. 사용자: 문제 발생

6-2. AI: 문제 해결
- 간단하게 끝난다면 사용자선에서 해결, 아니라면 codex한테 새 pr로서 주문 (영어)
- 당장 편하게 해결하는게 아니라 근본적으로, 장기적인 면을 고려해서 해결

7-1. 사용자: 정상 확인

7-2. AI: 다음 Phase(1번) 진행

## 4. 코딩의 목표
1. 모듈식 : 한 파일 내에 덕지덕지 기능을 붙히지 않고 모듈화하여 효율적으로 관리한다
2. 장기적으로 안전하고 효율적인 코드를 작성한다
3. 프로그램의 가벼움을 최우선으로 하여 간단하면서 효율적인 구조를 설계한다
4. 페이즈를 작게 진행하지 않고, 어느정도 필요한 선에서 크게크게 진행한다.
5. 각 AI는 자신의 파트에 맞는 문서를 매번 직접 읽어서 확인하여 도중 구현하려는 내용이 바뀌지 않도록 한다.

사용자로부터의 아이디어
- 사용자의 아이디어는 장기 로드맵 후보로 검토한다.
- 즉시 구현할지, 뒤로 미룰지, 구조만 준비할지, 버릴지는 장기 설계 기준으로 판단한다.
- 구현 타이밍은 GPT가 필요하다고 판단하는 시점에 맞춘다.
- 임시 땜빵보다 장기적으로 안전한 구조를 우선한다.


## 5. Current source-of-truth entry point

Sections 0 through 4 above are maintained by the user and must always be read directly. Sections 5 and later are maintained only as a lightweight entry point to the current documentation set; they are not a detailed architecture specification or module policy document.

For detailed current architecture policy, read the matching `Current_*` document directly:

- Docs index: `docs/Current_Docs_Index.md`
- Project architecture: `docs/Current_Project_Architecture.md`
- Implementation roadmap: `docs/Current_Implementation_Roadmap.md`
- Brush: `docs/Current_Brush_Architecture.md`
- Timeline: `docs/Current_Timeline_Architecture.md`
- Cut management: `docs/Current_Cut_Management_Architecture.md`
- Canvas / cache / storage: `docs/Current_Canvas_Cache_Storage_Architecture.md`
- Storyboard: `docs/Current_Storyboard_Architecture.md`
- UI / product interaction policy: `docs/Current_UI_Product_Policy.md`
- Test architecture / test policy: `docs/Current_Test_Architecture.md`

Before working on a module, read the matching Current document directly rather than relying on this handoff summary.

## 6. Current-doc rule

`Current_*` documents are the source of truth for current policy. Old phase/task docs remain historical records and must not override the matching Current document.

## 7. Documentation test rule

Regular tests should not check exact documentation prose, normalized documentation phrases, headings, or long-form policy wording. Current test policy lives in `docs/Current_Test_Architecture.md`. Tests should focus on behavior, stable boundaries, shared constants, and narrow forbidden legacy paths rather than making `flutter test` fail because documentation prose was rewritten more clearly.

## 8. Latest continuation note

Current active work remains the brush/canvas editing part. Continue brush and canvas viewport work until the brush editing area is temporarily production-safe enough to move on.

Recent canvas viewport status:

- Phase 227 adds stable canvas boundary behavior and a compact local canvas editor shell around the existing brush viewport.
- Active brush/canvas display is clipped to `Cut.canvasSize`; pointer-down outside canvas can start a stroke session, outside movement collects no visible dabs, re-entering starts a new visible segment without connecting across the outside gap, and pointer-up commits only if in-canvas dabs were collected.
- The canvas editor shell is UI-only: top title/status bar, center viewport content, right strip, and bottom zoom/fit/reset controls. It does not implement Cut canvas size editing, Camera T1, playback crop, save/load, or broad state management.
- Phase 226 introduced the `CanvasViewport` pan / zoom / fit-to-view / reset-view foundation for the production brush editing route.
- Viewport state is UI-only and must not become drawing source data, brush source payload architecture, save/load data, playback behavior, cache identity, or broad app-wide state.
- Brush source dabs remain committed in canvas-space coordinates after viewport pan/zoom.
- `Cut.canvasSize` remains drawing/storage bounds.
- `Project.cameraSize` remains the project-wide camera/output frame size.
- Future Camera T1 remains a candidate only: camera layer or camera-like track, camera view rectangle, darkened outside-camera editing area, playback cropped to camera frame, and editable camera position, size, and rotation. Do not implement Camera T1 until a dedicated phase designs it.

Recent brush cleanup status:

- Phase 225 records PR #294 as the current Brush T2 baseline and PR #293 only as a failed reference. PR #294 keeps active display on visible source dabs plus a sampled `BrushDab` stamp overlay, avoids active drawPath and active `displayPreviewSurface` routes, routes brush strokes through app-level global undo/redo, and preserves timeline frame selection after undo/redo.
- Phase 213A removed `TileDelta` / `TileDeltaCommand` from brush runtime boundaries.
- Phase 213B cleaned up brush history/source-of-truth boundaries:
    - `UnifiedUndoHistory` is the production-facing user undo/redo order.
    - `BrushFrameStore` owns frame-local brush payload movement.
    - `BrushPaintCommand` is the brush command identity / payload boundary and carries a minimal `materializationRef`.
    - `BrushBitmapMaterializationHistoryState` / `BrushBitmapMaterializationHistoryEntry` and `BrushCommitResult` remain internal session-local bitmap materialization bridges only.
- Phase 213C protects UI-facing brush undo/redo routes:
    - UI/canvas/smoke routes must call `BrushFrameEditingCoordinator.undo()` / `BrushFrameEditingCoordinator.redo()`.
    - UI must not directly call internal bitmap materialization undo/redo services.
    - Architecture guard tests protect this boundary.

Before continuing brush work in a new chat:

1. Read sections 0 through 4 of this handoff directly.
2. Read `docs/Current_Brush_Architecture.md` directly.
3. Read `docs/Current_Canvas_Cache_Storage_Architecture.md` if the next brush phase touches storage/cache/display.
4. Confirm whether PR 279 was merged and local checks passed:
    - `dart format lib test`
    - `flutter analyze`
    - `flutter test`
    - `git status`

Next preferred brush direction:

- Continue brush part rather than moving to storyboard/timeline/save-load yet.
- Do not reintroduce `TileDelta` / `TileDeltaCommand`.
- Do not treat internal materialization history as user-facing undo.
- Keep `Frame` lightweight.
- Keep cache images derived, not source of truth.
- Do not implement save/load, playback cache, real deferred bake, or large UI rewrites unless a new phase explicitly targets them.

Latest canvas baseline:

1. Phase 226: Canvas viewport foundation baseline.
   - pan / zoom
   - fit to view / reset view
   - visible editor viewport separate from the inner `Cut.canvasSize` drawing canvas
   - separate viewport transform from drawing coordinates
   - keep `Cut.canvasSize` as drawing bounds
   - keep viewport state out of drawing source data
2. Phase 227: Canvas boundary behavior and editor panel shell.
   - clip active display to `Cut.canvasSize`
   - keep pointer stroke sessions alive outside the canvas until pointer-up
   - re-enter with a new visible segment rather than connecting across outside gaps
   - keep the canvas editor shell local UI only
3. Cut canvas size editing remains later work.
4. Save/load and playback/cache remain later work.


## 5. Phase 229 canvas panel layout and panbar interaction notes

- The brush canvas panel shell now has an explicit small-height layout contract. The shell clips title/bottom decoration as needed, guarantees the central canvas/right-strip row receives a non-negative height, and keeps title/content/right-strip/bottom regions structurally present instead of allowing a vertical overflow.
- Panbar geometry is centralized in `CanvasViewportPanMetrics`, which uses the actual painted track extent on the scrollbar axis. Thumb sizes and starts remain finite and inside the track, including tracks smaller than the nominal minimum thumb size.
- Panbar drag uses normal scrollbar mapping: thumb delta over thumb travel maps to scroll delta over max scroll, while viewport pan is the negative scroll value. Horizontal drag updates `panX`; vertical drag updates `panY`.
- Panbar drags update the local `BrushCanvasPanel` live viewport during movement and synchronize the parent editor-session viewport once when the drag ends or is canceled. Zoom, fit, reset, and direct canvas viewport changes still synchronize immediately.
- When there is no scroll range, panbar drag is ignored so fit-centered positive pan values are preserved and the canvas does not snap to the top-left. `CanvasViewport` remains editor-session UI state only and is not stored in source, project, playback/cache, save/load, or camera data.

## 5. Phase 303 editor panel dock and brush settings notes

Phase 303 replaces the temporary canvas-local brush options strip with a right-side `BrushSettingsPanel`. `BrushSettingsPanel` is now the primary editable brush settings UI; `BrushCanvasPanel` should remain focused on canvas viewport display, panbars, zoom/fit/reset, canvas clipping, and drawing input.

Reusable editor panel primitives now exist for the long-term panel direction: `EditorPanelFrame`, `EditorPanelHeader`, `EditorPanelBody`, and `EditorPanelDock`. The right-side `EditorPanelDock` is the first durable dock direction for future Brush, Color, Layers, Navigator, Timeline, Storyboard, Brush Preset, and tool-property panels. This is not a full docking framework and must not introduce source data, project data, save/load schema, workspace persistence, or broad app-wide state management.

`BrushToolState` remains editor-session tool state owned by `HomePage` / the editor session. It now includes spacing in addition to size, opacity, and color. Spacing affects future dab sampling only; existing committed strokes retain their materialized dab values and are not rewritten. Active strokes snapshot input settings at pointer down, so mid-stroke UI changes affect future strokes only.

The panel and brush-settings direction is Photoshop-like, but it is not Photoshop ABR compatibility and does not claim exact Photoshop brush engine parity. Source models and save/load schema remain unchanged.

## 5. Phase 304 brush tool mode and eraser notes

Phase 304 adds an editor-session tool mode foundation with Brush and Eraser selected from a compact left-side tool palette. `HomePage` owns the selected tool mode next to `BrushToolState`; neither tool mode nor brush settings are written into Project, Cut, Layer, Frame, cache, playback, camera, or save/load data.

Brush input snapshots tool mode at pointer down, just like brush settings. Changing Brush/Eraser or changing brush settings mid-stroke affects future strokes only.

Eraser is implemented as a source operation (`BrushPaintCommandKind.eraseStroke`) with source dabs. It is not white paint and it does not destructively delete or mutate earlier paint commands. Visible commands replay in source order, and eraser rendering clears previous marks through a local canvas layer.

Eraser strokes use the existing global undo/redo model. Undo hides the eraser command through `BrushFrameStore.hiddenCommandIds`, restoring earlier paint appearance without changing old source data; redo restores the eraser command.

The preferred high-level order remains brush finishing, panel system expansion, canvas/cache/storage foundation, Camera T1, playback/cache, timeline, storyboard, then layer/save-load and larger systems later.
