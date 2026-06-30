# QuickAnimaker v2 인수인계문

## 중요 : 인수인계문 수정할 시, 0번부터 4번까지는 사용자가 수정한다. AI는 5번부터만 수정을 허용한다.

## 0. 문서 목적

이 문서는 QuickAnimaker v2 프로젝트를 다음 GPT 챗이나 다음 작업 세션에서 이어가기 위한 최신 인수인계문이다.

이 문서는 과거 handoff 문서를 대체한다.

대화는 한국어로 진행한다.

AI는 매 답변 시 사용자에 의해 최신화되는 0번부터 4번까지를 항상 직접 읽어서 확인한다. 5번부터는 최신화가 안돼있으니 그 점 유념한다.

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
    - 만들 문서 파일명
    - 문서 내용 (영어)
    - git add / commit / push
    - Codex 주문서 (영어)

4. 사용자: PR 확인해줘

5. AI: PR 리뷰
    - 코드 확인
    - 문제점 확인
    - 장기적인 면에서 안전하고 효율적인지 판단
    - 머지 판단
    - 판단 ok일 경우 머지 후 로컬 체크
    - 포맷 변경 시 commit/push
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


## 5. 핵심 도메인 모델

기본 도메인 계층:

```txt
Project
  -> Track
    -> Cut
      -> Layer
        -> Frame
          -> Stroke
```

주요 모델 / value object:

```txt
Project
Track
Cut
Layer
Frame
Stroke

CanvasSize
CanvasPoint
ViewportPoint
CanvasViewport

BrushSettings
BrushTipShape
BrushPreset
BrushPresetId
BrushInputSample

ProjectId
TrackId
CutId
LayerId
FrameId
StrokeId
```

핵심 불변식:

```txt
Project는 tracks를 가진다.
Track은 cuts를 가진다.
Cut은 layers를 가진다.
Layer는 frames를 가진다.
Frame은 strokes를 가진다.
Layer.name은 표시용 라벨이다.
Layer.name 중복은 허용한다.
LayerId가 진짜 identity다.
Frame name은 기존 unique/link 정책을 유지한다.
```

Brush / canvas 관련 불변식:

```txt
BrushSettings는 Stroke에 저장되는 frozen settings snapshot이다.
BrushPreset은 재사용 가능한 preset metadata다.
BrushPreset.name은 표시용 라벨이다.
BrushPresetId가 preset identity다.
Stroke는 BrushPreset을 직접 참조하지 않는다.
BrushInputSample은 pre-stroke input data다.
StrokePoint는 Stroke 안에 저장되는 좌표 데이터다.
CanvasPoint는 canvas-space 좌표다.
ViewportPoint는 viewport/widget-local 좌표다.
CanvasViewport는 순수 좌표 변환만 담당한다.
CanvasViewport는 Flutter Offset, PointerEvent, Canvas, Paint, CustomPainter에 의존하지 않는다.
```

---

## 6. Current source-of-truth docs

Before working on a module, read the matching current document directly. Phase task docs are historical task/order records, not current architecture policy.

- Docs index: `docs/Current_Docs_Index.md`
- General project architecture: `docs/Current_Project_Architecture.md`
- Implementation roadmap: `docs/Current_Implementation_Roadmap.md`
- Brush: `docs/Current_Brush_Architecture.md`
- Timeline: `docs/Current_Timeline_Architecture.md`
- Cut management: `docs/Current_Cut_Management_Architecture.md`
- Canvas / cache / storage: `docs/Current_Canvas_Cache_Storage_Architecture.md`
- Storyboard: `docs/Current_Storyboard_Architecture.md`

## 7. Current-doc rule

`Current_*` documents are the source of truth for current policy. Old phase/task docs remain historical records and should not override the matching current document.

## 8. Latest continuation note

Phase 212B reinforced current documentation and architecture tests only. Continue from the relevant `Current_*` docs before implementation; especially check the roadmap, brush, canvas/cache/storage, and storyboard documents before planning runtime work.
