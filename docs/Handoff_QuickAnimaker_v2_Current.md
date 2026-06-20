# QuickAnimaker_v2 다음 챗 인수인계 메모

이 문서는 QuickAnimaker_v2 Flutter/Dart 프로젝트의 다음 ChatGPT 대화용 최신 인수인계 문서다.

현재 기준:

* Phase 98 완료
* PR 139 merged
* PR 140 merged
* 사용자가 PR 140 이후 앱 정상 작동을 확인함
* 다음 새 챗은 Phase 100부터 시작하는 것을 권장

목표:
QuickAnimaker v2는 TVPaint 스타일의 2D 비트맵 애니메이션 제작 툴이다.
사용자는 실제 2D 애니메이터이며, 일본 애니메이션 작업 흐름에 맞는 컷/레이어/프레임/타임라인/타임시트 구조를 원한다.

대화 언어:
한국어로 답한다.

사용자 선호:

* 너무 먼 미래 설명보다 “지금 다음에 할 것”을 선호한다.
* 테스트 등에서 에러가 발생할 시, 에러만을 급하게 해결하기 위한 당장 간편하게 끝나는 땜빵식 코드보단 작업이 어려워지더라도 장기적으로 안전하게 설계하는 걸 최우선으로한다.
* Phase 문서와 Codex 지시서는 복붙하기 쉽게 작성한다.
* 장기 설계는 중요하다. 임시 땜빵보다 오래 유지되는 구조를 선호한다.
* 더 어려운 작업이어도 장기적으로 맞는 구조를 원한다.
* PR 리뷰 때는 반드시 로컬 실행 명령어, add 할 파일, 수동 확인 사항을 포함한다.
* 이전에 pull 전에 로컬 format 변경 때문에 문제가 난 적이 있으므로, PR 머지 후 안내에는 필요할 때 git restore 명령도 포함한다.

GitHub repo:
myoun99/quick_animaker_v2

기본 브랜치:
master

로컬 경로:
C:\Users\gunoo\Documents\quick_animaker_v2

기본 PR 머지 후 로컬 확인 명령:
git status
git pull
dart format lib test
flutter analyze
flutter test
git status

로컬 변경이 남아 있을 가능성이 있으면 안전형:
git status
git restore <format으로 바뀌었을 가능성이 있는 파일들>
git pull
dart format lib test
flutter analyze
flutter test
git status

restore는 로컬 변경을 버리는 명령이다.
사용자가 이미 format 변경을 커밋해야 하는 상황이면 restore를 시키면 안 된다.
그때는 add/commit/push를 안내한다.

PR 리뷰 응답 형식:
항상 아래 항목을 포함한다.

1. 결론: 머지 OK / 보류 / 수정 필요
2. 변경 파일
3. Phase 범위 적합 여부
4. 장기 설계 관점 문제 여부
5. 로컬에서 실행할 명령어
6. 포맷 등으로 바뀌면 git add 할 파일
7. 수동 확인할 사항

PR 리뷰 시 주의:

* GitHub PR 정보를 확인한다.
* 변경 파일과 diff를 본다.
* Codex가 dart/flutter를 실행하지 못했다고 적는 경우가 많으므로, 최종 판단은 사용자의 로컬 `flutter analyze`, `flutter test` 결과를 기준으로 한다.
* 테스트 실패가 발생하면 에러가 코드 문제인지 테스트 문제인지 구분한다.
* 많은 테스트가 터져도 공통 원인 하나일 수 있으므로 stack trace의 최초 원인을 확인한다.

핵심 도메인 모델:
Project -> Track -> Cut -> Layer -> Frame -> Stroke

기본 ID/value 객체:
ProjectId
TrackId
CutId
LayerId
FrameId
StrokeId
CanvasSize
BrushSettings

핵심 모델 불변식:

* Project는 tracks를 가진다.
* Track은 cuts를 가진다.
* Cut은 layers를 가진다.
* Layer는 frames를 가진다.
* Frame은 strokes를 가진다.
* Storyboard는 별도 Cut.storyboardLayer가 아니라 일반 Layer(kind: storyboard)다.
* Cut.storyboardLayer.panels 같은 구조는 사용하지 않는다.
* Cut당 Storyboard Layer는 최대 1개만 허용한다.
* Layer.name은 표시용 라벨이다.
* Layer.name 중복은 허용한다.
* LayerId가 진짜 identity다.
* Frame name은 기존 unique/link 정책을 유지한다.

Storyboard 관련 불변식:

* LayerKind.animation
* LayerKind.storyboard
* StoryboardFrameMetadata는 Frame에 붙는다.
* Frame.storyboardMetadata 필드가 있다.
* StoryboardFrameMetadata 필드:

    * actionMemo
    * dialogueMemo
    * note
* CutMetadata에는 Cut-level note만 둔다.
* CutMetadata에 actionMemo/dialogueMemo를 넣지 않는다.
* Storyboard metadata UI는 아직 구현하지 않았다.
* Storyboard thumbnail/edit/export/renderer/cache 변경은 명시된 Phase 전까지 하지 않는다.

레이어 표시 순서:
내부 raw order와 UI 표시 order는 구분한다.

Cut.layers raw logical/XSheet/cel order:
[A, B, C]

Horizontal timeline display:
[C, B, A]

Vertical XSheet/timesheet display:
[A, B, C]

새 레이어 추가 규칙:

* horizontal timeline에서 active layer 위에 보이게 추가해야 한다.
* raw order 기준으로 active layer 뒤에 insert한다.
* sourceIndex + 1
* “append to bottom”으로 생각하면 안 된다.

스토리보드 레이어 위치:

* Storyboard Layer도 Main Section 안의 일반 layer다.
* Storyboard Layer 위아래에 Animation Layer가 올 수 있어야 한다.

기본 레이어 이름:
새 Cut / 새 Layer 기본 이름은 A, B, C... 스타일을 사용한다.
Cut별 기준이다.
Cut 1이 E까지 있다고 해서 Cut 2가 F부터 시작하면 안 된다.

Initial exposure:

* 새 Cut / 새 Layer는 visible frame 1에 blank exposure `x`가 있어야 한다.
* 사용자는 새 Cut이 아무 exposure도 없는 상태를 원하지 않는다.
* C2 같은 자동 frame name이 새 Cut index 1에 들어가는 것을 원하지 않는다.

Layer icon:
현재 horizontal timeline row에 LayerKind icon이 있다.
기본 의미:

* animation: Animation layer
* storyboard: Storyboard layer

StoryboardPanel 장기 방향:
StoryboardPanel은 단순 리스트가 아니라 장기적으로 Premiere Pro / DaVinci Resolve 같은 multi-track timeline 감각을 목표로 한다.

장기 구조:
Project.tracks = V1, V2...
Track 안에 Cut blocks
Cut 안에 Storyboard Layer 표시

개념:
V1  [Cut 001--------][Cut 002----][Cut 003----------]
V2        [Alt Cut-----]       [Reference---]
V3  [Memo/Temp/Revision---------------------]

StoryboardPanel 원칙:

* Cut block은 Cut duration을 가진다.
* Cut에 Storyboard Layer가 있으면 Cut block 안에 그 layer의 head/exposure strip을 보여준다.
* StoryboardPanel은 Project 기준으로 읽는다.
* StoryboardExportPlan은 Project에서 derive한다.
* Project를 mutate하지 않는다.
* 기본 storyboard export는 Primary Track only, 즉 V1만 대상으로 한다.
* selected tracks export나 composite output은 미래 기능이다.
* Composite Output은 optional이며 default가 아니다.

성능/가상화 장기 정책:
반드시 docs/LongTerm_Performance_Architecture.md를 따른다.

핵심 원칙:

* 장기적으로 100k frames, 많은 layers, 많은 cuts를 고려한다.
* Timeline은 eager build하면 안 된다.
* ListView.builder만으로 2D timeline 문제를 해결했다고 보면 안 된다.
* 명시적인 visible range / virtualization plan을 계산해야 한다.
* horizontal virtualization과 vertical virtualization은 분리해서 단계적으로 접근한다.
* 현재 vertical layer virtualization은 아직 구현하지 않았다.
* 구조적 해결을 우선한다.
* overflow를 fixed size 증가로 숨기는 식의 임시 해결을 피한다.
* 안정적인 semantic key를 사용하고 fragile text-position test를 피한다.

완료된 주요 Phase 요약:

Phase 69:

* Storyboard model correction
* Cut.storyboardLayer.panels 제거 방향 확정
* Storyboard는 Layer(kind: storyboard)로 표현

Phase 70:

* StoryboardFrameMetadata 추가
* Frame.storyboardMetadata 추가

Phase 71:

* UpdateStoryboardFrameMetadataCommand 추가

Phase 72:

* UpdateLayerKindCommand 추가

Phase 73:

* minimal Storyboard Layer toggle UI 추가
* key:

    * toggle-storyboard-layer-button
    * active-layer-kind-label

Phase 74:

* Storyboard Layer 최대 1개 규칙
* 기본 layer name A/B/C
* 새 Cut/new Layer blank exposure frame 1
* 새 layer가 horizontal timeline에서 active 위에 보이도록 추가

Phase 75:

* horizontal timeline row에 LayerKind icon 추가
* keys:

    * timeline-layer-kind-icon-<layerId>

Phase 76:

* horizontal layer display adapter foundation

Phase 77:

* undoable active layer rename

Phase 78:

* delete layer command/UI

Phase 79:

* duplicate layer command/UI

Phase 80:

* layer clipboard foundation
* copy/paste layer payload
* duplicate layer를 copy/paste 기반으로 refactor
* duplicate layer name 보존
* Layer.name 중복 허용

Phase 81:

* minimal layer copy/paste UI
* keys:

    * copy-layer-button
    * paste-layer-button
    * layer-clipboard-status

Phase 82:

* layer system stabilization/cleanup

Phase 83:

* read-only StoryboardPanel shell
* keys:

    * storyboard-panel
    * storyboard-panel-title
    * storyboard-track-row-<trackId>
    * storyboard-track-label-<trackId>
    * storyboard-cut-block-<cutId>
    * storyboard-cut-title-<cutId>
    * storyboard-cut-duration-<cutId>
    * storyboard-layer-strip-<cutId>
    * storyboard-layer-name-<cutId>
    * storyboard-layer-empty-<cutId>

Phase 84:

* StoryboardPanel active cut sync/cut block selection
* active indicator key:

    * storyboard-cut-active-indicator-<cutId>

Phase 85:

* StoryboardTimelineLayout foundation
* file:

    * lib/src/ui/storyboard_timeline_layout.dart
* key:

    * storyboard-cut-frame-range-<cutId>

Phase 86:

* shared timeline block foundation
* files:

    * lib/src/ui/timeline/timeline_block.dart
    * lib/src/ui/timeline/timeline_scale.dart

Phase 87:

* TimelinePanel cells use shared timeline block style

Phase 88:

* StoryboardPanel shared timeline positioning
* keys:

    * storyboard-track-timeline-area-<trackId>
    * storyboard-cut-positioned-<cutId>

Phase 89:

* StoryboardPanel horizontal timeline viewport foundation
* key:

    * storyboard-timeline-horizontal-viewport

Phase 90:

* StoryboardPanel fixed track label rail
* keys:

    * storyboard-track-label-rail
    * storyboard-timeline-scroll-content
    * storyboard-track-label-row-<trackId>

Phase 91:

* timeline visible range calculator foundation
* file:

    * lib/src/ui/timeline/timeline_visible_range.dart
* tests cover empty/overscan/clamping/negative offset/invalid extent/two-axis/100k count

Phase 92:

* timeline virtualization render plan foundation
* file:

    * lib/src/ui/timeline/timeline_virtualization_plan.dart

Phase 93:

* LayerTimelineGrid virtualization adapter foundation
* files:

    * lib/src/ui/timeline/layer_timeline_grid.dart
    * lib/src/ui/timeline/timeline_grid_metrics.dart
    * lib/src/ui/timeline/timeline_panel_virtualization_adapter.dart
* TimelineGridMetrics.defaults:

    * minimumVisibleFrameCells = 24
    * layerControlsWidth = 220
    * frameCellWidth = 48
    * layerRowHeight = 52

Phase 94:

* fixed layer controls rail foundation
* keys:

    * timeline-layer-controls-rail
    * timeline-frame-scroll-viewport
    * timeline-frame-scroll-content

Phase 95:

* horizontal frame virtualization first slice
* LayerTimelineGrid became StatefulWidget
* horizontal ScrollController/listener added
* visible horizontal frame range and leading/trailing spacers added
* keys:

    * timeline-frame-header-leading-spacer
    * timeline-frame-header-trailing-spacer
    * timeline-frame-row-leading-spacer-<layerId>
    * timeline-frame-row-trailing-spacer-<layerId>

Phase 96:

* visible horizontal scrollbar foundation
* keys:

    * timeline-scrollbar-area
    * timeline-horizontal-scrollbar
    * timeline-horizontal-scrollbar-viewport

Phase 97:

* bottom horizontal scrollbar rail placement
* goal:

    * layer controls rail 아래 reserved area
    * frame grid 아래 horizontal scrollbar
* key additions:

    * timeline-bottom-scrollbar-rail
    * timeline-bottom-scrollbar-left-spacer
    * timeline-frame-grid-area
* PR 135 had a vertical desync risk at one point, but final fixed structure uses shared vertical scroll.
* Later PR 136 fixed test tap/drag target issues.

PR 137:

* bottom horizontal scrollbar alignment fix
* left reserved area kept empty
* horizontal scrollbar scoped to frame grid bottom rail
* built-in Flutter Scrollbar moved into right rail but thumb was not visible because it was detached from actual scrollable.

PR 138:

* replaced detached built-in Scrollbar with custom visible bottom horizontal scrollbar rail
* reuses existing horizontal ScrollController
* no second horizontal controller
* keys:

    * timeline-horizontal-scrollbar-track
    * timeline-horizontal-scrollbar-thumb
* thumb/track became visible and user confirmed normal operation.

Phase 98 / PR 139:

* added visible TVPaint-style vertical scrollbar slot between layer controls rail and frame grid
* added shared vertical ScrollController
* added timeline vertical scroll viewport
* added vertical scrollbar rail with visible track/thumb
* vertical layer virtualization explicitly deferred
* added TimelineGridMetrics.verticalScrollbarWidth default 14
* new keys:

    * timeline-vertical-scrollbar-slot
    * timeline-vertical-scrollbar
    * timeline-vertical-scrollbar-track
    * timeline-vertical-scrollbar-thumb
    * timeline-vertical-scrollbar-bottom-spacer
    * timeline-vertical-scroll-viewport

PR 140:

* fixed PR 139 runtime failure
* problem:

    * controller.hasClients can be true before position.hasContentDimensions is true
    * reading position.maxScrollExtent too early caused null-check error
* fix:

    * only read maxScrollExtent when hasClients && hasContentDimensions
    * fallback to content size / viewport size calculation otherwise
* applied to both:

    * _VerticalScrollbarRailState._maxScrollExtent
    * _BottomHorizontalScrollbarRailState._maxScrollExtent
* user confirmed app works normally after this.

Current TimelinePanel / LayerTimelineGrid important structure:

* one shared vertical scroll viewport controls layer controls and frame rows together
* vertical scrollbar slot is between layer controls rail and frame grid
* horizontal frame scroll is inside frame grid area
* bottom horizontal scrollbar is under frame grid only
* bottom row reserves:

    * layer controls width
    * vertical scrollbar slot width
    * horizontal scrollbar rail under frame grid area

Important current keys:

* timeline-scrollbar-area
* timeline-layer-controls-rail
* timeline-vertical-scroll-viewport
* timeline-vertical-scrollbar-slot
* timeline-vertical-scrollbar
* timeline-vertical-scrollbar-track
* timeline-vertical-scrollbar-thumb
* timeline-vertical-scrollbar-bottom-spacer
* timeline-frame-grid-area
* timeline-horizontal-scrollbar
* timeline-horizontal-scrollbar-track
* timeline-horizontal-scrollbar-thumb
* timeline-horizontal-scrollbar-viewport
* timeline-frame-scroll-viewport
* timeline-frame-scroll-content
* timeline-bottom-scrollbar-rail
* timeline-bottom-scrollbar-left-spacer
* timeline-frame-header-row
* timeline-frame-header-<frameIndex>
* timeline-cell-<layerId>-<frameIndex>
* timeline-frame-header-leading-spacer
* timeline-frame-header-trailing-spacer
* timeline-frame-row-leading-spacer-<layerId>
* timeline-frame-row-trailing-spacer-<layerId>
* timeline-layer-row-<layerId>
* timeline-layer-kind-icon-<layerId>
* timeline-layer-name-<layerId>
* timeline-add-layer-button

Current out of scope:

* vertical layer virtualization
* playhead/ruler/zoom
* layer reorder
* layer folder
* layer lock
* layer merge
* sound section
* camera section
* rough/guide layer type
* storyboard metadata editing UI
* storyboard thumbnail/edit/export
* renderer/cache/persistence changes
* Provider/Riverpod/Bloc/ChangeNotifier introduction
* full custom renderer
* custom bitmap brush engine expansion

Important long-term documents to read first:

* docs/Handoff_QuickAnimaker_v2_Current.md
* docs/LongTerm_Performance_Architecture.md
* docs/LongTerm_StoryboardPanel_TimelineDesign.md
* docs/LongTerm_Timesheet_Layer_Sections.md
* docs/Design_CutMetadata_CanvasPlanning.md
* docs/Architecture.md
* docs/ImplementationPlan.md

Recent Phase documents to read if working on timeline:

* docs/Phase_91_Codex_Task.md
* docs/Phase_92_Codex_Task.md
* docs/Phase_93_Codex_Task.md
* docs/Phase_94_Codex_Task.md
* docs/Phase_95_Codex_Task.md
* docs/Phase_96_Codex_Task.md
* docs/Phase_97_Codex_Task.md
* docs/Phase_98_Codex_Task.md

Next chat instructions:
Start from Phase 100.

Recommended first reply in next chat:

* Acknowledge that Phase 98 / PR 140 is complete.
* Do not re-check PR 139/140 unless user asks.
* Ask or infer the next phase.
* Propose Phase 100 based on current code and long-term plan.

Suggested Phase 100 candidates:

1. Timeline scrollbar stabilization polish

    * verify custom vertical/horizontal scrollbar behavior
    * add minimal tests if any manual issue remains
    * no new features

2. Timeline playhead/ruler foundation

    * add top frame ruler/playhead visual structure
    * must not break horizontal virtualization
    * should use visible frame range

3. Vertical layer virtualization planning phase

    * only planning/calculator foundation, not UI replacement
    * should follow docs/LongTerm_Performance_Architecture.md

Best recommended Phase 100:
Timeline playhead/ruler foundation, if the current scrollbars remain stable.
If any scrollbar issue remains, do a small stabilization phase first.

Next chat should not:

* assume outdated Phase 74 state
* reintroduce Cut.storyboardLayer
* split vertical scrolling into independent left/right scroll views
* move vertical scrollbar to far right
* make horizontal scrollbar span under layer controls
* implement vertical virtualization before a clear foundation phase
* change models without explicit instruction

User workflow:
When the user says “정상작동해 다음가자”, treat the latest PR as locally verified and propose the next small phase.

When the user says “PR xxx 확인해줘”, check GitHub PR xxx and respond using the standard PR review format.

When a test fails after merge:

* parse the first real error
* identify if many failures share one root cause
* do not assume restore/pull problem unless logs show local changes blocking pull
* if pull is blocked by local format changes, then advise restore or commit depending on whether the changes should be kept.

## Required reference for timeline work

Before reviewing or modifying timeline code, read:

- `docs/LongTerm_Timeline_Range_Semantics.md`

This document defines the long-term separation between playback range, visible/display range, virtualized frame window, authored/data extent, selected exposure visual range, effective horizontal scroll offset, and frame coordinate conversion.

Do not use `Cut.duration` as a data/edit/selection limit.
Do not use `authoredTimelineExtentFrameCount` to bound selected exposure outline rendering.
Do not use raw horizontal scroll offset for layout/hit testing after resize; use the effective clamped offset.
Selected exposure outline is a display-range visual effect, not a data extent.

## Recent timeline stabilization phases

- PR165: clamped effective horizontal offset after viewport resize to prevent ruler/body/frame tearing.
- PR166: restored selected exposure outline as a display-range visual effect.
- PR167: extracted selected exposure display-range policy.
- PR168: extracted horizontal offset clamp policy.
- PR169: extracted frame coordinate conversion policy.
- PR170: documented long-term timeline range semantics and policy invariants.

## Phase 145 timeline stabilization checkpoint

Phase 145 closes the current timeline refactoring / stabilization line. Before starting the next major area, read:

- `docs/Timeline_Stabilization_Checkpoint.md`

Use that checkpoint as the concise handoff source for stabilized timeline architecture, stable keys, long-term range semantics, layer ordering semantics, storyboard semantics relevant to timeline, protected tests, manual verification, and recommended next phases.
