# QuickAnimaker_v2 다음 챗 인수인계 메모

이 대화는 QuickAnimaker_v2 Flutter/Dart 프로젝트의 Phase 진행용 대화다.

목표는 TVPaint 스타일의 2D 비트맵 애니메이션 제작 툴을 만드는 것이다.

사용자는 2D 애니메이터이고, 실제 일본 애니메이션 작업 흐름에 맞는 타임라인/타임시트/레이어 구조를 원한다.

답변은 한국어로 한다.

사용자는 너무 먼 미래 설명보다 “지금 다음에 할 것”을 선호한다.

Phase 문서나 Codex 지시서는 복붙하기 쉽게 작성한다.

사용자가 “정상이야 다음가자”라고 하면:

* 직전 PR이 머지/로컬 테스트까지 정상이라는 뜻으로 이해한다.
* 다음 Phase를 제안하고, Codex에게 줄 작업 지시서를 작성한다.
* 너무 큰 범위를 한 번에 넣지 말고 작은 Phase로 나눈다.

사용자가 “PR xx 확인해줘”라고 하면:

* GitHub PR을 확인한다.
* 변경 파일과 테스트를 본다.
* 머지 가능 여부를 판단한다.
* 문제 있으면 “수정 요청”을 명확히 말한다.
* 문제 없으면 “머지해도 괜찮아”라고 말한다.
* 마지막에 로컬에서 실행할 명령어를 준다.
* 포맷으로 인해 스테이터스 확인 시 git add 작업이 예상되니 그에 대한 cmd 명령어도 제공한다.

GitHub repo:
myoun99/quick_animaker_v2

기본 브랜치:
master

현재까지 진행 요약:

Phase 69:

* 잘못된 Cut.storyboardLayer.panels 방향을 수정.
* Storyboard Layer는 별도 Cut.storyboardLayer가 아니라 일반 Layer에 LayerKind.storyboard를 붙이는 방식으로 정리.
* LayerKind.animation / LayerKind.storyboard 추가.
* Cut.storyboardLayer 제거.
* old Cut JSON의 storyboardLayer는 무시.
* Layer.kind 기본값은 animation.
* old Layer JSON에 kind가 없으면 animation으로 로드.

Phase 70:

* StoryboardFrameMetadata 모델 추가.
* Frame.storyboardMetadata 추가.
* actionMemo / dialogueMemo / note는 Frame-level StoryboardFrameMetadata에 둔다.
* CutMetadata에는 넣지 않는다.
* old Frame JSON에 storyboardMetadata가 없으면 empty metadata로 로드.
* Cut duplicate 시 Frame.storyboardMetadata 보존.

Phase 71:

* UpdateStoryboardFrameMetadataCommand 추가.
* Storyboard Frame metadata를 undo/redo 가능한 command로 수정 가능.
* target Layer가 LayerKind.storyboard일 때만 허용.
* CutCommandCoordinator.updateStoryboardFrameMetadata 추가.
* unchanged metadata는 history entry 없이 skip.
* UI는 아직 없음.

Phase 72:

* UpdateLayerKindCommand 추가.
* Layer.kind를 undo/redo 가능하게 변경.
* animation ↔ storyboard 전환 가능.
* Frame.storyboardMetadata는 지우지 않는다.
* CutCommandCoordinator.updateLayerKind 추가.
* unchanged kind는 history entry 없이 skip.
* UI는 아직 없음.

Phase 73:

* HomePage timeline action toolbar에 Storyboard Layer toggle UI 추가.
* 버튼 key:
  ValueKey('toggle-storyboard-layer-button')
* tooltip:
  Toggle Storyboard Layer
* 상태 label key:
  ValueKey('active-layer-kind-label')
* UI는 ProjectRepository를 직접 건드리지 않고 CutCommandCoordinator.updateLayerKind를 호출한다.
* active layer를 target으로 사용한다.
* active layer가 없으면 disabled.
* Animation Layer ↔ Storyboard Layer 토글 가능.
* Undo/Redo 작동.
* Storyboard Panel UI, Conte Panel UI, actionMemo/dialogueMemo UI는 아직 없음.

중요한 현재 설계 결정:

1. Storyboard Layer 방향

Storyboard Layer는 별도 Cut.storyboardLayer가 아니다.

정답:

Cut
layers
Layer(kind: animation)
frames
Frame
strokes

```
Layer(kind: storyboard)
  frames
    Frame
      strokes
      storyboardMetadata
```

오답:

Cut
storyboardLayer
panels

Cut당 Storyboard Layer는 앞으로 최대 1개만 허용하는 방향이다.

2. CutMetadata 방향

CutMetadata는 Cut-level note만 가진다.

CutMetadata에는 actionMemo/dialogueMemo를 절대 넣지 않는다.

현재 올바른 구조:

CutMetadata
note

StoryboardFrameMetadata
actionMemo
dialogueMemo
note

3. 장기 타임시트 구조

사용자는 첨부한 A1/Toei식 타임시트를 참고해서, 세로 타임시트 모드에서 다음 구조에 가까운 형태를 원한다.

전통 타임시트 감각:

* ACTION / 원화 지시
* SOUND / 대사 / SE
* CELL / 셀 / 동화
* CAMERA / 카메라 지시

QuickAnimaker 장기 방향:
가로 타임라인에서 위에서 아래로:

Camera Section
Sound Section
Main Section

아래에서 위로 보면:

Main Section
Sound Section
Camera Section

이 순서가 매우 중요하다.

절대 Main / Camera / Sound 순서로 이해하지 말 것.

Main Section:

* Animation Layer
* Storyboard Layer
* Rough Layer
* Guide Layer
* 일반 그림을 그리는 레이어 영역
* Storyboard Layer도 여기 안에 둔다.
* 사용자가 Storyboard Layer 위아래에 Animation Layer를 둘 수 있어야 한다.

Sound Section:

* Dialogue Layer
* SE Layer
* Sound Note Layer
* 장기적으로 SOUND 영역에 대응.
* SE는 여러 개 가능하게 열어두되, 지금 당장 구현하지 않는다.

Camera Section:

* Camera Control Layer
* Camera Direction Layer

Camera Control Layer:

* 실제 렌더 카메라 조작용.
* pan / zoom / follow / shake / camera keyframe 등.

Camera Direction Layer:

* 시트에 적는 카메라 지시문용.
* PAN, BOOK, BG, TU, TB 같은 이름을 가질 수 있다.
* 이름이 시트의 헤더/컬럼명으로 표시될 수 있다.
* 여러 개 존재할 수 있다.
* 실제 카메라를 직접 조작하는 레이어와 구분한다.

4. 데이터 order와 표시 order는 다르다

반드시 구분해야 한다.

* data model order
* compositing order
* horizontal timeline display order
* vertical timesheet display order
* new layer insertion order

이걸 같은 것으로 취급하면 안 된다.

가로 타임라인에서 새 레이어가 아래로 append되는 현재/기존 동작은 사용자가 원하지 않는다.

사용자는 새 레이어가 현재 레이어의 위 또는 섹션 최상단에 쌓이는 것을 원한다.

세로 타임시트에서는 적절히 왼쪽→오른쪽 컬럼 배치가 되어야 한다.

따라서 향후 구현할 때:

* 내부 logical order를 명확히 정의한다.
* 가로 표시용 adapter
* 세로 타임시트 표시용 adapter
  를 분리해서 생각한다.

5. Layer naming 방향

현재 “Layer 1, Layer 2…” 식 이름은 바꾸고 싶어 한다.

앞으로 Main Section의 animation layer 기본 이름은 일본 셀 애니메이션식으로:

A
B
C
...
Z
AA
AB
AC
...

이렇게 간다.

중요:
레이어 이름 생성은 Project 전체 기준이 아니라 Cut별 기준이다.

예:

Cut 1:
A
B
C

Cut 2:
A
B
C

Cut 1에서 E까지 만들었다고 해서 Cut 2가 F부터 시작하면 안 된다.

또한 가능한 경우 가장 작은 빈 셀 이름을 사용한다.

예:

기존:
A
B
D

새 레이어:
C

6. Initial exposure 방향

새 Cut / 새 Layer는 무조건 1번 인덱스에 x로 시작해야 한다.

x 의미:
blank exposure / no drawing / empty cell

사용자가 싫어하는 것:

* 새 Cut에 아무 exposure도 없는 상태
* C2 같은 자동 Frame 이름이 생기는 상태
* Cut 2에서 1번 인덱스에 C2가 들어가는 상태

원하는 기본:

New Cut
Layer A
index 1 = x

New Layer
index 1 = x

7. Layer type icon 방향

나중에 레이어 라벨 왼쪽에 타입 아이콘을 표시하고 싶어 한다.

초기 아이콘:

* animation: 셀/붓/그림 아이콘
* storyboard: 콘티/책/패널 아이콘

장기 아이콘:

* sound: 음표/소리 아이콘
* cameraControl: 카메라 아이콘
* cameraDirection: 카메라 지시/메모 아이콘

이건 아직 다음 Phase에서 하지 말고, 기본 규칙 정리 후 별도 UI Phase에서 한다.

반드시 확인해야 할 문서:

다음 챗은 먼저 docs 폴더를 확인해야 한다.

특히 아래 문서들을 우선 확인:

* docs/LongTerm_Timesheet_Layer_Sections.md
* docs/Design_CutMetadata_CanvasPlanning.md
* docs/Phase_69_Codex_Task.md
* docs/Phase_70_Codex_Task.md
* docs/Phase_71_Codex_Task.md
* docs/Phase_72_Codex_Task.md
* docs/Phase_73_Codex_Task.md

추가로 있으면 확인할 문서:

* docs/Architecture.md
* docs/ImplementationPlan.md
* docs/Cut_Structure_Audit.md
* docs/Phase_*.md
* README.md

다음 챗에서 먼저 할 일:

1. docs/LongTerm_Timesheet_Layer_Sections.md를 읽고 장기 방향을 확인한다.
2. docs/Design_CutMetadata_CanvasPlanning.md를 읽고 CutMetadata / StoryboardFrameMetadata 방향을 확인한다.
3. 최신 머지 상태에서 Phase 74를 제안한다.
4. Phase 74는 작고 안전하게 잡는다.

다음 Phase 추천:

Phase 74 - Layer Defaults and Storyboard Layer Rule Correction

목표:

* Cut당 Storyboard Layer는 최대 1개만 허용.
* Layer 이름 생성 방식을 Cut별 A/B/C... AA/AB 방식으로 변경.
* 새 Cut의 기본 Layer 이름은 A.
* 새 Layer 생성 시 해당 Cut 안에서 다음 셀 이름 사용.
* 새 Cut / 새 Layer는 1번 인덱스에 x(blank exposure)로 시작.
* C2 같은 자동 frame name 생성 제거.
* 새 레이어가 가로 타임라인에서 아래로 append되지 않고 현재 target layer 위 또는 Main Section 최상단에 들어가는 방향을 정의.
* 아직 Sound/Camera Section은 구현하지 않는다.
* 아직 Layer type icon UI는 구현하지 않는다.
* 아직 Storyboard Panel UI / Conte Panel UI / actionMemo UI / dialogueMemo UI는 구현하지 않는다.

Phase 74에서 주의할 것:

* 너무 큰 UI 개편 금지.
* Sound/Camera LayerKind 추가 금지.
* Camera Section 구현 금지.
* Sound Section 구현 금지.
* Timesheet vertical view 구현 금지.
* Layer icon UI 구현 금지.
* StoryboardFrameMetadata editor 구현 금지.
* actionMemo/dialogueMemo UI 구현 금지.
* CutMetadata는 note-only 유지.
* Storyboard Layer는 Cut당 1개로 제한하되, 기존 프로젝트에 storyboard layer가 여러 개 있는 legacy 상태를 어떻게 처리할지는 신중히 정한다.
* UpdateLayerKindCommand가 animation → storyboard로 바꿀 때 같은 Cut 안에 이미 storyboard layer가 있으면 StateError로 거부하는 방향이 좋다.
* Coordinator에서도 unchanged skip은 유지.
* UI toggle도 이미 storyboard layer가 있는 상태에서 다른 layer를 storyboard로 바꾸려 하면 안전하게 실패하거나 disabled되는 방향을 나중에 잡는다.

## 대화 진행 방식

답변은 한국어로 한다.

사용자는 QuickAnimaker_v2 프로젝트를 Phase 단위로 진행하고 있다.

사용자는 구현 타이밍, Phase 분할, 다음 작업 판단을 기본적으로 AI에게 맡긴다.

다만 답변 방식은 항상 다음 순서를 유지한다.

1. 현재 상태를 짧게 판단한다.
2. 다음 Phase가 무엇인지 말한다.
3. 제일 먼저 사용자가 만들어야 할 파일명을 알려준다.
4. 그 파일에 붙여넣을 Phase 문서 전체 내용을 제공한다.
5. Codex에게 그대로 전달할 짧은 지시문을 별도로 제공한다.
6. 마지막에 사용자가 실행할 git 명령어를 제공한다.

사용자가 “정상이야 다음가자”라고 하면:

* 직전 PR이 머지/로컬 테스트까지 정상이라는 뜻으로 이해한다.
* 바로 다음 Phase를 판단한다.
* “다음은 Phase xx가 맞아.”라고 먼저 말한다.
* 그 이유를 짧게 설명한다.
* 그 다음 아래 형식으로 진행한다.

필수 답변 형식:

1. 먼저 만들 파일

예:

```text
먼저 이 파일을 만들어.
docs/Phase_74_Codex_Task.md
```

2. Phase md 파일에 붙여넣을 내용

* 사용자가 md 파일에 그대로 붙여넣을 수 있게 작성한다.
* Phase 문서 전체를 제공한다.
* 범위, 목표, 금지사항, 테스트 요구사항, acceptance criteria, required checks, Codex report 항목을 포함한다.
* 너무 큰 범위를 잡지 않는다.
* 현재 Phase에서 하지 않을 것을 명확히 적는다.

3. Codex에게 전달할 내용

* Phase 문서보다 짧고 실행 지향적으로 작성한다.
* Codex 채팅에 그대로 붙여넣기 좋게 작성한다.
* “Implement Phase xx only.”로 시작하는 형태가 좋다.
* 읽어야 할 문서, 목표, 금지사항, 실행할 체크 명령어, 보고할 항목을 포함한다.

4. git 명령어 안내

Phase 문서를 만든 뒤 사용자가 실행할 명령어를 제공한다.

예:

```bat
git status
git add docs/Phase_74_Codex_Task.md
git commit -m "Add Phase 74 Codex task"
git push
git status
```

PR 리뷰 후에는 로컬 확인 명령어를 제공한다.

예:

```bat
git pull
dart format lib test
flutter analyze
flutter test
git status
```

format 때문에 modified가 생길 수 있으므로, 예상 파일 기준 git add / commit / push 명령어도 제공한다.

예:

```bat
git add lib/src/... test/...
git commit -m "Format Phase xx ..."
git push
git status
```

사용자가 “PR xx 확인해줘”라고 하면:

* GitHub PR을 확인한다.
* PR body만 보고 판단하지 않는다.
* 중요한 변경 파일을 직접 fetch해서 확인한다.
* 테스트 파일을 확인한다.
* PR comments를 확인한다.
* 기존 설계 방향과 충돌하는지 확인한다.
* out of scope 위반이 있는지 확인한다.
* 문제 없으면 “머지해도 괜찮아.”라고 명확히 말한다.
* 문제 있으면 “이건 수정 요청이 맞아.”라고 명확히 말한다.
* 마지막에 로컬 실행 명령어와 예상 git add 명령어를 제공한다.

좋은 답변 스타일:

```text
좋아. 다음은 Phase 74가 맞아.

이유는 간단해.
지금은 LayerKind command/UI까지 생겼고,
이제 기본 레이어 규칙을 정리하지 않으면 다음 UI가 흔들릴 수 있어.

먼저 이 파일을 만들어.
docs/Phase_74_Codex_Task.md

아래 내용을 그대로 붙여넣어.
...
Codex에게는 이걸 보내면 돼.
...
진행 명령어는 이거야.
...
```

피해야 할 답변 스타일:

* 처음부터 설명 없이 긴 Phase 문서만 던지는 것
* 사용자가 만들어야 할 파일명을 먼저 안 알려주는 것
* Phase md 내용과 Codex 전달용 내용을 구분하지 않는 것
* git add / commit / push 안내를 빼먹는 것
* 너무 먼 미래 구현을 한 번에 넣는 것
* 장기 아이디어를 즉시 구현 범위에 넣는 것
* Phase 범위를 크게 잡는 것
* “원하면 해줄게”로 끝내는 것

Phase 문서 작성 원칙:

* 새 챗은 항상 최신 장기 메모와 설계 문서를 먼저 확인해야 한다.
* 특히 다음 문서를 우선 확인한다.

```text
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Timesheet_Layer_Sections.md
docs/Design_CutMetadata_CanvasPlanning.md
최신 Phase 문서들
```

* 장기 아이디어는 바로 구현하지 말고, 현재 Phase에 필요한 최소 범위만 반영한다.
* 모델 → command → UI 순서로 작게 쌓는다.
* UI Phase라도 큰 화면 개편은 피한다.
* command Phase에서는 undo/redo, missing target, no-op skip, unrelated data preservation을 반드시 본다.
* UI Phase에서는 widget key, command path 사용 여부, future UI 미추가 여부를 반드시 본다.

다음 챗에서 특히 지켜야 할 진행 방식:

* 먼저 장기 메모를 확인한다.
* 다음 Phase가 맞는지 짧게 판단한다.
* “먼저 만들 파일”을 알려준다.
* “Phase md에 붙여넣을 내용”을 작성한다.
* “Codex에게 전달할 내용”을 작성한다.
* “git add/commit/push 명령어”를 작성한다.


현재 중요 key / UI:

Phase 73 toggle button:
ValueKey('toggle-storyboard-layer-button')

Layer kind label:
ValueKey('active-layer-kind-label')

Undo:
ValueKey('undo-button')

Redo:
ValueKey('redo-button')

Cut Note UI:
이미 존재하며 계속 유지되어야 한다.

아직 없어야 하는 UI:

* Storyboard Panel
* Conte Panel
* Layer Inspector
* Cut Inspector
* actionMemo field
* dialogueMemo field
* StoryboardFrameMetadata editor
* panelNote field

이 인수인계 메모를 기준으로 QuickAnimaker_v2 다음 Phase를 이어가자.

먼저 다음 문서를 확인해줘.

* docs/Handoff_QuickAnimaker_v2_Current.md
* docs/LongTerm_Timesheet_Layer_Sections.md
* docs/Design_CutMetadata_CanvasPlanning.md
* 최신 Phase 문서들

그 다음 아래 순서로 진행해줘.

1. 현재 상태를 짧게 판단
2. 다음 Phase가 무엇인지 말하기
3. 먼저 만들어야 할 Phase md 파일명 안내
4. 그 md 파일에 붙여넣을 Phase 문서 전체 작성
5. Codex에게 전달할 짧은 지시문 작성
6. git add / commit / push 명령어 안내

다음 목표 후보는 Phase 74: Layer Defaults and Storyboard Layer Rule Correction이야.

단, Phase 74는 작은 기본 규칙 정리 Phase로 잡아줘.

바로 구현하지 말 것:

* Sound/Camera Section
* Layer type icon UI
* Storyboard Panel UI
* Conte Panel UI
* actionMemo/dialogueMemo UI
* vertical timesheet view

Phase 82:

* Layer system stabilization after Add/Rename/Delete/Duplicate/Copy/Paste.
* Layer identity policy is now explicit: `LayerId` is identity; `Layer.name` is only a display label.
* Duplicate layer names are allowed. Rename rejects empty/whitespace names only and must not reject a duplicate display label.
* Frame rename/link behavior was intentionally unchanged; layer duplicate-name allowance must not be applied to frame naming rules.
* Duplicate Layer is a convenience wrapper over the layer copy/paste foundation: `copyLayerToPayload(sourceLayer)` + `CutCommandCoordinator.pasteLayer(... insertionIndex: sourceIndex + 1)` + `PasteLayerCommand`.
* Obsolete duplicate-layer-only command/planner code was removed. The retained `duplicateLayerAsIndependentCopy` helper is for Cut duplication only, where the entire Cut's layer/frame ID maps are preplanned together; it is not the Layer Duplicate command path.
* Copy Layer stores an app-local `LayerCopyPayload` and does not mutate repository state or history.
* Paste Layer inserts at the requested raw layer index, remaps `FrameId`s, preserves the copied layer display name, becomes undoable/redoable through history, and selects the pasted layer in UI flows.
* Storyboard paste policy remains:
  * Storyboard payload into a Cut with no Storyboard Layer pastes as `LayerKind.storyboard`.
  * Storyboard payload into a Cut with an existing Storyboard Layer pastes as `LayerKind.animation`.
  * Animation payload always pastes as `LayerKind.animation`.
* Clipboard UI remains minimal/app-local only: Copy Layer, Paste Layer, and status label. No OS clipboard, shortcuts, context menus, or multi-layer clipboard were added.
* Widget tests were stabilized away from generated IDs like `timeline-layer-row-layer-1`; prefer row counts, selected-layer assertions, repository-backed IDs, or discovered IDs.
* Raw layer order / horizontal display order / future XSheet order separation remains important. No section UI, vertical timesheet redesign, new `LayerKind`, or Storyboard Panel UI was added. `docs/LongTerm_StoryboardPanel_TimelineDesign.md` remains long-term reference only.
