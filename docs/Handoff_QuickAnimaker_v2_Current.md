# QuickAnimaker v2 다음 GPT 챗 인수인계문

나는 `QuickAnimaker v2`라는 Flutter/Dart 기반 2D 애니메이션 제작 프로그램을 만들고 있다.

목표는 TVPaint 스타일의 2D bitmap animation tool이다. 사용자는 실제 2D 애니메이터이며, 일본 애니메이션 제작 흐름에 맞는 `Project / Track / Cut / Layer / Frame / Stroke`, 콘티, 타임라인, 타임시트, 2D 드로잉 구조를 원한다.

대화는 한국어로 진행해줘.

## 1. 저장소 정보

GitHub repository:

```txt
myoun99/quick_animaker_v2
```

기본 브랜치:

```txt
master
```

로컬 경로:

```txt
C:\Users\gunoo\Documents\quick_animaker_v2
```

기본 로컬 확인 명령:

```bash
git status
git pull
dart format lib test
flutter analyze
flutter test
git status
```

로컬 변경이 남아 pull이 막힐 가능성이 있으면 먼저 `git status`를 확인해야 한다.
`git restore`는 로컬 변경을 버리는 명령이므로, 사용자가 보존해야 할 변경을 가진 경우에는 함부로 안내하면 안 된다.
필요하면 `git add / commit / push`를 먼저 안내한다.

## 2. 현재 최신 진행 상태

현재는 **Phase 145 완료 상태**다.

중요: 기존 handoff 문서 초반에는 오래된 내용으로 `Phase 98 완료`, `PR 139/140 merged`, `다음은 Phase 100부터 시작` 같은 내용이 남아 있을 수 있다.
그 내용은 과거 기록으로만 보고, 현재 기준은 **Phase 145 완료**로 봐야 한다.

Phase 145는 현재 타임라인 리팩터링 / 안정화 라인의 마무리 checkpoint다.

반드시 먼저 읽어야 할 최신 문서:

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

특히 `docs/Timeline_Stabilization_Checkpoint.md`가 최신 timeline handoff의 핵심 문서다.

이 문서에는 다음이 정리되어 있다.

```txt
- stabilized timeline architecture
- stable key inventory
- long-term range semantics
- layer ordering semantics
- storyboard semantics relevant to timeline
- protected tests
- manual verification checklist
- next recommended phases
```

## 3. 사용자 작업 선호

사용자는 너무 먼 미래 설명보다 “지금 다음에 할 것”을 선호한다.

작업 원칙:

```txt
- 임시 땜빵보다 장기적으로 안전한 구조를 우선한다.
- 에러가 나면 급하게 숨기는 수정이 아니라 원인을 보고 안정적인 방향으로 고친다.
- Phase 문서와 Codex 지시서는 복붙하기 쉽게 작성한다.
- PR 리뷰 때는 반드시 로컬 실행 명령어와 수동 확인 사항을 포함한다.
- “정상이야 다음가자”라고 하면 최신 PR이 로컬에서 정상 확인된 것으로 보고 다음 작은 phase를 제안한다.
- “PR xxx 확인해줘”라고 하면 GitHub PR xxx를 확인하고 변경 파일/diff/범위/테스트/수동 확인을 검토한다.
```

Codex 작업 지시를 작성할 때는 가능하면 아래 4단계 구조를 사용한다.

```txt
1. 만들 파일 안내
2. 그 파일에 복붙할 문서 안내
3. git add/commit/push 안내
4. Codex에게 전달할 문장 안내
```

## 4. 핵심 도메인 모델

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
BrushSettings
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

## 5. Storyboard 관련 불변식

Storyboard는 별도 `Cut.storyboardLayer`가 아니다.

올바른 구조:

```txt
Storyboard는 일반 Layer(kind: storyboard)다.
```

규칙:

```txt
LayerKind.animation
LayerKind.storyboard
Cut당 Storyboard Layer는 최대 1개만 허용한다.
Storyboard Layer도 Cut.layers 안의 일반 layer다.
Storyboard Layer 위아래에 Animation Layer가 올 수 있어야 한다.
Cut.storyboardLayer.panels 같은 구조는 사용하지 않는다.
```

Storyboard metadata:

```txt
StoryboardFrameMetadata는 Frame에 붙는다.
Frame.storyboardMetadata 필드가 있다.
StoryboardFrameMetadata 필드:
- actionMemo
- dialogueMemo
- note
CutMetadata에는 Cut-level note만 둔다.
CutMetadata에 actionMemo/dialogueMemo를 넣지 않는다.
```

현재 Storyboard metadata UI는 아직 구현하지 않았다.
Storyboard thumbnail/edit/export/renderer/cache 변경은 명시된 phase 전까지 하지 않는다.

## 6. StoryboardPanel 장기 방향

StoryboardPanel은 단순 리스트가 아니라 장기적으로 Premiere Pro / DaVinci Resolve 같은 multi-track timeline 감각을 목표로 한다.

장기 구조:

```txt
Project.tracks = V1, V2...
Track 안에 Cut blocks
Cut 안에 Storyboard Layer 표시
```

개념 예시:

```txt
V1  [Cut 001--------][Cut 002----][Cut 003----------]
V2        [Alt Cut-----]       [Reference---]
V3  [Memo/Temp/Revision---------------------]
```

StoryboardPanel 원칙:

```txt
Cut block은 Cut duration을 가진다.
Cut에 Storyboard Layer가 있으면 Cut block 안에 그 layer의 head/exposure strip을 보여준다.
StoryboardPanel은 Project 기준으로 읽는다.
StoryboardExportPlan은 Project에서 derive한다.
Project를 mutate하지 않는다.
기본 storyboard export는 Primary Track only, 즉 V1만 대상으로 한다.
selected tracks export나 composite output은 미래 기능이다.
Composite Output은 optional이며 default가 아니다.
StoryboardPanel은 아직 drawing canvas가 아니다.
StoryboardPanel은 timeline range semantics를 소유하면 안 된다.
```

## 7. Layer ordering semantics

내부 raw order와 UI 표시 order는 구분한다.

Raw logical / XSheet / cel order:

```txt
[A, B, C]
```

Horizontal timeline display:

```txt
[C, B, A]
```

Vertical XSheet / timesheet display:

```txt
[A, B, C]
```

새 layer 추가 규칙:

```txt
horizontal timeline에서 active layer 위에 보이게 추가해야 한다.
raw order 기준으로 active layer 뒤에 insert한다.
sourceIndex + 1
“append to bottom”으로 생각하면 안 된다.
```

기본 layer 이름:

```txt
새 Cut / 새 Layer 기본 이름은 A, B, C... 스타일을 사용한다.
Cut별 기준이다.
Cut 1이 E까지 있다고 해서 Cut 2가 F부터 시작하면 안 된다.
```

Initial exposure:

```txt
새 Cut / 새 Layer는 visible frame 1에 blank exposure x가 있어야 한다.
사용자는 새 Cut이 아무 exposure도 없는 상태를 원하지 않는다.
C2 같은 자동 frame name이 새 Cut index 1에 들어가는 것을 원하지 않는다.
```

## 8. Timeline stabilization 현재 상태

Timeline refactoring / stabilization line은 **Phase 145에서 checkpoint까지 완료**했다.

이제 특별한 regression이 없으면 타임라인 리팩터링을 계속 늘리지 말고, 다음 큰 영역으로 넘어가는 것이 좋다.

현재 책임 분리된 주요 구성 요소:

```txt
TimelinePanel
LayerTimelineGrid
TimelineController
TimelineFrameRuler
TimelineFrameHeaderRow
TimelineLayerControlsHeader
TimelineLayerControlsRow
TimelineVerticalScrollbarRail
TimelineHorizontalScrollbarRail
TimelineFrameScrollViewport
TimelineFrameRowsScrollBody
TimelineFrameGridStack
TimelineLayerFrameBodyLayout
TimelineRulerCutEndBoundary
TimelineBodyCutEndBoundary
TimelinePlayhead
```

대략적 책임:

```txt
TimelinePanel:
public timeline entry point.
timeline data, selected/current state, callbacks, orientation을 timeline UI에 연결한다.

LayerTimelineGrid:
horizontal timeline grid composition을 담당한다.
layer controls, frame ruler/header, scrollable frame body, scrollbar rails, playhead, cut-end boundary visuals를 조립한다.

TimelineController:
timeline cursor/read/edit orchestration against project data를 담당한다.
authored/data extent는 controller concern이지 widget display limit이 아니다.
```

## 9. 절대 지켜야 할 Timeline long-term range semantics

아래 규칙은 매우 중요하다.

```txt
Cut.duration is playback/export duration only.
```

즉:

```txt
Cut.duration은 playback/export duration이다.
Cut.duration은 authored/data extent가 아니다.
Cut.duration은 편집 가능 범위의 한계가 아니다.
Cut.duration은 selected exposure outline의 한계가 아니다.
Cut.duration은 visible UI cell 렌더링 한계가 아니다.
```

추가 규칙:

```txt
TimelineController.authoredTimelineExtentFrameCount는 authored/data extent 전용이다.
authoredTimelineExtentFrameCount를 UI visible range limit으로 다시 쓰면 안 된다.
visible frame range는 UI/display policy다.
selected exposure outline은 display-range visual highlight다.
Cut.duration 밖 authored frame은 존재할 수 있다.
Cut.duration 밖에 editing/edit data가 생겨도 Cut.duration이 자동 확장되면 안 된다.
```

관련 문서:

```txt
docs/LongTerm_Timeline_Range_Semantics.md
docs/Timeline_Stabilization_Checkpoint.md
```

앞으로 timeline, storyboard, brush, canvas 작업을 할 때도 이 의미를 깨면 안 된다.

## 10. Stable key inventory

아래 timeline stable key는 테스트와 수동 검증 기준이므로 함부로 바꾸면 안 된다.

```txt
timeline-sticky-header-row
timeline-frame-ruler
timeline-frame-ruler-scrub-area
timeline-frame-header-row
timeline-frame-header-<frameIndex>
timeline-frame-header-leading-spacer
timeline-frame-header-trailing-spacer
timeline-frame-scroll-viewport
timeline-frame-scroll-content
timeline-horizontal-scrollbar
timeline-vertical-scrollbar
timeline-vertical-scrollbar-slot
timeline-layer-controls-rail
timeline-frame-grid-area
timeline-playhead
timeline-playhead-column
timeline-cut-end-boundary
timeline-cut-end-boundary-ruler
timeline-cell-<layerId>-<frameIndex>
timeline-selected-exposure-range-outline-<layerId>
timeline-layer-row-<layerId>
timeline-layer-name-<layerId>
timeline-layer-kind-icon-<layerId>
timeline-layer-visibility-<layerId>
timeline-layer-opacity-<layerId>
timeline-add-layer-button
timeline-vertical-scrollbar-track
timeline-vertical-scrollbar-thumb
timeline-bottom-scrollbar-rail
timeline-horizontal-scrollbar-track
timeline-horizontal-scrollbar-thumb
timeline-horizontal-scrollbar-viewport
timeline-frame-rows-scroll-body
timeline-frame-row-area-<layerId>
timeline-scrollable-body
timeline-layer-rows-scroll-body
```

StoryboardPanel 쪽 stable key도 존재한다.

```txt
storyboard-panel
storyboard-panel-title
storyboard-track-row-<trackId>
storyboard-track-label-<trackId>
storyboard-track-label-row-<trackId>
storyboard-track-timeline-area-<trackId>
storyboard-cut-positioned-<cutId>
storyboard-cut-block-<cutId>
storyboard-cut-title-<cutId>
storyboard-cut-duration-<cutId>
storyboard-cut-frame-range-<cutId>
storyboard-layer-strip-<cutId>
storyboard-layer-name-<cutId>
storyboard-layer-empty-<cutId>
storyboard-cut-active-indicator-<cutId>
storyboard-timeline-horizontal-viewport
storyboard-track-label-rail
storyboard-timeline-scroll-content
```

## 11. Protected tests

최근 안정화 phase에서 추가/보호된 중요 테스트 파일:

```txt
test/ui/timeline_layer_controls_widgets_test.dart
test/ui/timeline_vertical_scrollbar_rail_test.dart
test/ui/timeline_horizontal_scrollbar_rail_test.dart
test/ui/timeline_frame_scroll_viewport_test.dart
test/ui/timeline_frame_rows_scroll_body_test.dart
test/ui/timeline_frame_grid_stack_test.dart
test/ui/timeline_layer_frame_body_layout_test.dart
test/ui/layer_timeline_grid_extracted_composition_test.dart
test/ui/timeline_panel_smoke_test.dart
test/controllers/timeline_controller_responsibility_test.dart
test/ui/timeline_long_term_range_semantics_test.dart
test/ui/storyboard_panel_smoke_test.dart
```

이 테스트들은 단순한 테스트가 아니라 현재 설계 계약을 보호하는 역할을 한다.

작업 중 테스트가 실패하면 production을 바꾸기 전에 먼저 아래를 확인한다.

```txt
- 테스트가 현재 의도와 맞는가?
- stable key를 잘못 누르고 있지 않은가?
- public API 밖의 가정을 하고 있지 않은가?
- 많은 실패가 하나의 공통 원인에서 나온 것은 아닌가?
```

## 12. 최근 PR 흐름 요약

Timeline refactoring / stabilization 흐름:

```txt
PR177: TimelineFrameHeaderRow 추출
PR178: TimelineFrameHeaderRow 테스트 추가
PR179: TimelineRulerCutEndBoundary 추출
PR180: TimelineBodyCutEndBoundary 추출
PR181: cut-end boundary widget 테스트 추가
PR182: layer controls widget 테스트 추가
PR183: TimelineVerticalScrollbarRail 추출
PR184: vertical scrollbar rail 테스트 추가
PR185: TimelineHorizontalScrollbarRail 추출
PR186: horizontal scrollbar rail 테스트 추가
PR187: TimelineFrameScrollViewport 추출
PR188: TimelineFrameScrollViewport 테스트 추가
PR189: TimelineFrameRowsScrollBody 추출
PR190: TimelineFrameRowsScrollBody 테스트 추가
PR191: TimelineFrameGridStack 추출
PR192: TimelineFrameGridStack 테스트 추가
PR193: LayerTimelineGrid extracted composition smoke test 추가
PR194: TimelineLayerFrameBodyLayout 추출
PR195: TimelineLayerFrameBodyLayout 테스트 추가
PR196: StoryboardPanel baseline smoke test 추가
PR197: TimelinePanel baseline smoke test 추가
PR198: TimelinePanel smoke test tap target 수정
PR199: TimelineController responsibility baseline test 추가
PR200: Timeline long-term range semantics regression test 추가
PR201: Timeline stabilization checkpoint 문서화
```

주의할 analyzer/test 이슈:

```txt
TimelineExposure.drawing(...)은 const 생성자가 아니다.
Frame(...)도 const 생성자가 아니다.
따라서 TimelineExposure.drawing(...)이나 Frame(...)을 const list/map 안에 넣으면 analyzer가 실패한다.
FrameId(...) 같은 ID value object만 const로 둘 수 있다.
```

올바른 예시:

```dart
frames: [
  Frame(id: const FrameId('head'), duration: 1, strokes: const []),
],
timeline: {
  0: TimelineExposure.drawing(const FrameId('head')),
},
```

## 13. Performance / virtualization 장기 정책

장기적으로 100k frames, 많은 layers, 많은 cuts를 고려한다.

반드시 참고할 문서:

```txt
docs/LongTerm_Performance_Architecture.md
```

핵심 원칙:

```txt
Timeline은 eager build하면 안 된다.
ListView.builder만으로 2D timeline 문제를 해결했다고 보면 안 된다.
명시적인 visible range / virtualization plan을 계산해야 한다.
horizontal virtualization과 vertical virtualization은 분리해서 단계적으로 접근한다.
현재 vertical layer virtualization은 아직 구현하지 않았다.
구조적 해결을 우선한다.
overflow를 fixed size 증가로 숨기는 식의 임시 해결을 피한다.
stable semantic key를 사용하고 fragile text-position test를 피한다.
```

## 14. 현재 out of scope

다음이 아직 out of scope이거나 미래 기능이다.

```txt
vertical layer virtualization
layer reorder
layer folder
layer lock
layer merge
sound section
camera section
rough/guide layer type
storyboard metadata editing UI
storyboard thumbnail/edit/export
renderer/cache/persistence changes
Provider/Riverpod/Bloc/ChangeNotifier introduction
full custom renderer
custom bitmap brush engine expansion
canvas
drawing canvas
brush engine
stroke rendering
onion skin
undo/redo
save/load
CustomPainter
```

특히 당장 다음 phase에서 canvas/drawing/brush engine으로 점프하지 말 것.

## 15. 다음 recommended phases

현재 Phase 145까지 완료되었으므로 다음은 새 GPT 챗에서 Phase 146부터 시작하는 것이 좋다.

추천 순서:

```txt
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
Phase 148: 2D brush model / brush settings architecture
Phase 149: Brush input sampling tests
Phase 150: Canvas viewport foundation
```

Phase 146에서는 아직 drawing canvas를 만들지 않는다.

좋은 Phase 146 범위:

```txt
- StoryboardPanel 구조 안정화
- storyboard layer presence / empty state / selection 흐름 확인
- storyboard layer가 ordinary Layer(kind: storyboard)라는 정책 유지
- Cut당 storyboard layer 최대 1개 규칙 유지
- StoryboardPanel이 timeline range semantics를 소유하지 않도록 유지
- 필요하면 StoryboardPanel 관련 작은 policy/helper/test 추가
```

아직 하지 말아야 할 것:

```txt
- canvas
- drawing canvas
- brush engine
- stroke rendering
- onion skin
- undo/redo
- save/load
- Provider
- Riverpod
- ChangeNotifier
- CustomPainter
```

2D brush architecture는 StoryboardPanel 안정화 후에 진행한다.
Canvas / drawing implementation은 brush model / input sampling 설계가 끝난 다음에 진행한다.

## 16. PR 리뷰 스타일

PR 확인 시에는 다음을 확인한다.

```txt
- PR 번호와 제목
- open / mergeable 상태
- changed files
- diff 내용
- production code 변경 여부
- test-only / docs-only 여부
- phase 범위와 맞는지
- 장기 설계 관점 문제 여부
- 금지된 기능이 들어오지 않았는지
- dart/flutter 실행 여부
- Codex 환경에서 실행 못 했다면 로컬 명령 안내
- 머지 OK / 머지 보류 / 수정 필요 판정
- 수동 확인 체크리스트
```

PR 리뷰 최종 응답에는 반드시 포함한다.

```txt
1. 결론: 머지 OK / 보류 / 수정 필요
2. 변경 파일
3. Phase 범위 적합 여부
4. 장기 설계 관점 문제 여부
5. 로컬에서 실행할 명령어
6. 필요 시 git add/commit/push 안내
7. 수동 확인할 사항
```

수동 확인 체크리스트를 빼먹지 말 것.

## 17. 다음 GPT 챗 시작 지시

새 GPT 챗에서는 이 인수인계문을 기준으로 이어간다.

먼저 아래 문서를 읽었다는 전제로 진행한다.

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

그리고 다음 요청부터 시작한다.

```txt
위 인수인계문을 기준으로 이어서 진행해줘.

현재 QuickAnimaker v2는 Phase 145 timeline stabilization checkpoint까지 완료된 상태다.

다음은 Phase 146부터 시작하고 싶다.

Phase 146은 StoryboardPanel stabilization / feature foundation으로 진행하되, 아직 canvas, drawing, brush engine, stroke rendering, undo/redo, save/load, Provider/Riverpod/ChangeNotifier, CustomPainter는 추가하지 마라.

먼저 Phase 146 Codex 작업 지시서를 작성해줘.

내가 선호하는 형식은 다음 4단계다.

1. 만들 파일 안내
2. 그 파일에 복붙할 문서 안내
3. git add/commit/push 안내
4. Codex에게 전달할 문장 안내
```
