# QuickAnimaker v2 현재 인수인계문

## 0. 문서 목적

이 문서는 QuickAnimaker v2 프로젝트를 다음 GPT 챗이나 다음 작업 세션에서 이어가기 위한 최신 인수인계문이다.

이 문서는 과거 handoff 문서를 대체한다.

중요:

```txt
현재 기준은 Phase 150 완료 후 상태다.
Phase 146~150 추천 흐름은 완료되었다.
이제 다음 방향은 bitmap-first canvas / brush / cache architecture 기반으로 간다.
```

대화는 한국어로 진행한다.

---

## 1. 프로젝트 개요

QuickAnimaker v2는 Flutter/Dart 기반 2D 애니메이션 제작 프로그램이다.

목표는 TVPaint 스타일의 2D bitmap animation tool이다.

사용자는 실제 2D 애니메이터이며, 일본 애니메이션 제작 흐름에 맞는 다음 구조를 원한다.

```txt
Project
Track
Cut
Layer
Frame
Stroke
Storyboard / Conte
Timeline / XSheet
Bitmap drawing canvas
2D brush
Undo / cache / playback / save-load
```

QuickAnimaker v2는 bitmap-first 프로그램이다.

장기적으로 최종 artwork source of truth는 vector stroke list가 아니라 bitmap tile data가 되어야 한다.

---

## 2. 저장소 정보

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

필요하면 먼저 다음을 안내한다.

```bash
git add <changed-files>
git commit -m "<message>"
git push
```

---

## 3. 현재 최신 진행 상태

현재 QuickAnimaker v2는 **Phase 150 완료 상태**다.

완료된 최신 흐름:

```txt
Phase 145: Timeline stabilization checkpoint
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
Phase 148: 2D brush model / brush settings architecture
Phase 149: Brush input sampling tests
Phase 150: Canvas viewport foundation
```

Phase 146~150 추천 흐름은 끝났다.

이제 다음은 바로 brush UI나 Photoshop brush import로 가지 말고, 장기 bitmap canvas architecture 기준에 따라 다음 순서로 진행하는 것이 좋다.

```txt
bitmap storage
-> dirty tile tracking
-> tile delta undo
-> frame/playback cache policy
-> minimal bitmap brush rasterizer
-> canvas UI integration
```

반드시 먼저 읽어야 할 최신 문서:

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

`docs/LongTerm_Roadmap_After_Phase_150.md`와 `docs/Bitmap_Canvas_Brush_Architecture.md`가 Phase 150 이후 방향의 핵심 문서다.

---

## 4. 사용자 작업 선호

사용자는 너무 먼 미래 설명보다 “지금 다음에 할 것”을 선호한다.

다만 설계 대화에서는 큰 방향, 장기 구조, 구현 타이밍을 함께 검토하는 것을 원한다.

사용자의 제안은 즉시 구현 요구가 아니다.

사용자 제안 처리 원칙:

```txt
- 사용자의 아이디어는 장기 로드맵 후보로 검토한다.
- 즉시 구현할지, 뒤로 미룰지, 구조만 준비할지, 버릴지는 장기 설계 기준으로 판단한다.
- 구현 타이밍은 GPT가 필요하다고 판단하는 시점에 맞춘다.
- 임시 땜빵보다 장기적으로 안전한 구조를 우선한다.
- 에러가 나면 급하게 숨기는 수정이 아니라 원인을 보고 안정적인 방향으로 고친다.
```

작업 지시서 선호:

```txt
- Phase 문서와 Codex 지시서는 복붙하기 쉽게 작성한다.
- 새 Phase를 제안할 때는 먼저 “이번에 어떤 구조/기능을 왜 만드는지” 설명한다.
- 그 다음 복붙용 문서와 Codex prompt를 준다.
- 문서-only 작업은 Codex보다 사용자가 직접 복붙하는 방식이 더 안전할 수 있다.
```

PR 리뷰 선호:

```txt
- “PR xxx 확인해줘”라고 하면 GitHub PR xxx를 확인한다.
- 변경 파일, diff, 범위, 테스트, 장기 설계 문제, 수동 확인 리스트를 검토한다.
- 큰 문제가 없으면 “머지 OK”를 기본으로 판단하고, 머지 후 로컬 확인을 안내한다.
- 수동 확인 리스트는 반드시 포함한다.
- 수동 확인 리스트는 이번 PR에서 바뀐 것만 체크하도록 짧게 작성한다.
```

“정상이야 다음가자”라고 하면 최신 PR이 로컬에서 정상 확인된 것으로 보고 다음 작은 phase 또는 다음 설계 단계를 제안한다.

---

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

## 6. Storyboard 관련 불변식

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

---

## 7. StoryboardPanel 장기 방향

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
StoryboardPanel은 drawing canvas가 아니다.
StoryboardPanel은 timeline range semantics를 소유하면 안 된다.
```

장기 확장 가능 기능:

```txt
Storyboard thumbnails
Storyboard metadata display
Project-level cut overview
Track-based board view
Primary-track storyboard export
Optional selected-track export
```

아직 금지:

```txt
StoryboardPanel에서 직접 그림 그리기
StoryboardPanel이 timeline range semantics를 소유하기
StoryboardPanel이 Project를 layout 과정에서 mutate하기
StoryboardPanel 전용 별도 drawing data 구조 만들기
```

---

## 8. Layer ordering semantics

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

---

## 9. Timeline stabilization 현재 상태

Timeline refactoring / stabilization line은 Phase 145에서 checkpoint까지 완료했다.

특별한 regression이 없으면 timeline refactor를 계속 늘리지 말고, bitmap canvas / brush / cache 쪽으로 넘어가는 것이 좋다.

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

---

## 10. 절대 지켜야 할 Timeline long-term range semantics

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

앞으로 timeline, storyboard, brush, canvas, cache 작업을 할 때도 이 의미를 깨면 안 된다.

---

## 11. Long-term bitmap canvas / brush direction

QuickAnimaker v2는 bitmap-first animation tool이다.

핵심 원칙:

```txt
최종 artwork source of truth는 bitmap tile data다.
Stroke는 표시용 source of truth가 아니라 input/history metadata로 취급한다.
브러시는 그리는 순간 bitmap tile에 반영하는 방향을 우선한다.
Undo는 장기적으로 stroke replay보다 tile delta 복원을 우선한다.
재생은 brush rasterize나 stroke replay가 아니라 playback preview cache image swap을 우선한다.
비활성 frame은 가능하면 baked/composited preview cache로 표시한다.
```

이 방향은 사용자의 v1 구조를 참고하되, v2에서는 더 playback-friendly하게 바꾸는 것이다.

v1 아이디어:

```txt
기본 bitmap
+ undo 가능한 stroke 정보
+ undo 제한을 넘은 stroke는 bitmap에 bake
+ 비활성 frame은 base bitmap + strokes를 baked cache image로 표시
```

v2 권장 방향:

```txt
stroke는 그리는 순간 dirty bitmap tiles에 commit
undo는 stroke replay가 아니라 dirty tile delta 복원
비활성 frame은 항상 frame/playback preview cache 우선
재생 중 brush rasterization 금지
재생 중 stroke replay 금지
재생 중 full layer recomposition 금지
```

장기적으로 참고할 문서:

```txt
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
```

다음 구현 방향은 brush UI나 Photoshop brush import가 아니라 다음 순서가 좋다.

```txt
1. BitmapSurface / BitmapTile / TileCoord
2. DirtyTileSet / DirtyRegion
3. TileDeltaCommand
4. FrameCompositeCache / PlaybackPreviewCache policy
5. Minimal bitmap brush rasterizer
6. Canvas UI integration
```

Photoshop-style / ABR brush import는 장기 목표로 인정하지만, 내부 bitmap brush engine이 안정된 뒤 별도 phase로 다룬다.

---

## 12. Bitmap canvas performance policy

장기 목표는 많은 cuts, 많은 layers, 많은 frames, 장시간 playback에서도 렉이 적은 구조다.

성능 최우선 규칙:

```txt
재생 중에는 brush rasterize 금지
재생 중에는 stroke replay 금지
재생 중에는 full layer composite 금지
재생 중에는 disk read 최소화
재생 중에는 cache image swap 중심
```

Canvas storage는 tile 기반이어야 한다.

권장 초기 tile size 후보:

```txt
256x256: 기본 후보, 관리 overhead가 적음
128x128: brush 반응성을 더 중시할 때 후보
```

초기 판단은 256x256을 우선하되, 성능 테스트 후 변경할 수 있다.

Tile rules:

```txt
모든 tile을 eager allocation하지 않는다.
sparse tile map을 사용한다.
pixel data가 생긴 tile만 allocate한다.
dirty tile을 명시적으로 추적한다.
visible dirty tile만 redraw/upload한다.
stroke마다 전체 frame image를 재생성하지 않는다.
```

캐시 계층 후보:

```txt
LayerTileCache
FrameCompositeCache
PlaybackPreviewCache
DiskPreviewCache
```

Playback cache policy:

```txt
현재 frame 주변 N프레임의 PlaybackPreviewCache를 미리 준비한다.
재생 중에는 cache image swap만 수행하는 것을 목표로 한다.
cache miss가 있어도 playback을 가능한 한 block하지 않는다.
```

---

## 13. Photoshop-style / ABR brush import policy

Photoshop-style brush import는 장기 목표다.

하지만 지금 당장 구현하지 않는다.

내부 bitmap brush engine이 먼저 안정되어야 한다.

선호 표현:

```txt
Best-effort import of user-owned brush files
```

피해야 할 표현 / 방향:

```txt
Photoshop brush engine clone
Full Photoshop compatibility
Adobe default brushes bundled
Photoshop logo/branding 사용
Adobe 제품처럼 보이는 마케팅
```

장기 구현 방향:

```txt
사용자가 보유한 brush file을 import
지원 가능한 brush tip/settings만 추출
QuickAnimaker 내부 BrushPreset / BrushSettings / BrushTip data로 변환
지원하지 않는 설정은 명확하게 무시하거나 근사 처리
```

앱에 Adobe/Photoshop 기본 브러시나 유료 브러시를 포함하면 안 된다.

---

## 14. Stable key inventory

아래 stable key는 테스트와 수동 검증 기준이므로 함부로 바꾸면 안 된다.

Timeline stable keys:

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

StoryboardPanel stable keys:

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

Stable key 변경은 반드시 명시된 phase에서만 한다.

변경 시 관련 테스트와 handoff 문서를 함께 갱신한다.

---

## 15. Protected tests

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
test/ui/storyboard_panel_interaction_test.dart
test/models/brush_settings_test.dart
test/models/brush_tip_shape_test.dart
test/models/brush_preset_test.dart
test/models/stroke_brush_settings_compatibility_test.dart
test/models/brush_input_sample_test.dart
test/services/brush_input_sampling_test.dart
test/models/canvas_point_test.dart
test/models/viewport_point_test.dart
test/models/canvas_viewport_test.dart
```

이 테스트들은 단순한 테스트가 아니라 현재 설계 계약을 보호하는 역할을 한다.

작업 중 테스트가 실패하면 production을 바꾸기 전에 먼저 아래를 확인한다.

```txt
테스트가 현재 의도와 맞는가?
stable key를 잘못 누르고 있지 않은가?
public API 밖의 가정을 하고 있지 않은가?
많은 실패가 하나의 공통 원인에서 나온 것은 아닌가?
장기 설계 문서를 깨는 변경을 했는가?
```

---

## 16. 최근 PR 흐름 요약

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

Post-timeline stabilization 흐름:

```txt
PR202: Phase 146 StoryboardPanel layer lookup stabilization
PR203: Phase 147 StoryboardPanel interaction tests
PR204: Phase 148 BrushSettings / BrushTipShape / BrushPreset model foundation
PR205: Phase 149 BrushInputSample / brush input sampling helper
PR206: Phase 150 CanvasPoint / ViewportPoint / CanvasViewport model foundation
```

주의할 analyzer/test 이슈:

```txt
TimelineExposure.drawing(...)은 const 생성자가 아니다.
Frame(...)도 const 생성자가 아니다.
BrushSettings(...)도 validation 때문에 const 생성자가 아니다.
BrushInputSample(...)도 validation 때문에 const 생성자가 아니다.
CanvasPoint(...), ViewportPoint(...), CanvasViewport(...)도 validation 때문에 const 생성자가 아니다.
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

BrushSettings 예시:

```dart
final brush = BrushSettings(size: 4.0);
```

Canvas viewport 예시:

```dart
final viewport = CanvasViewport(zoom: 1.0, panX: 0.0, panY: 0.0);
```

---

## 17. Performance / virtualization 장기 정책

장기적으로 100k frames, 많은 layers, 많은 cuts를 고려한다.

반드시 참고할 문서:

```txt
docs/LongTerm_Performance_Architecture.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
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

StoryboardPanel performance 방향:

```txt
StoryboardPanel은 Cut block 기반이라 TimelinePanel보다 현재는 가볍다.
하지만 many cuts 상황에서는 StoryboardPanel도 virtualize해야 한다.
Project를 mutate하지 않고 visible cut block만 derive/render해야 한다.
```

Canvas performance 방향:

```txt
한 장의 거대한 bitmap을 매 stroke마다 새로 만들지 않는다.
tile 기반 bitmap surface를 사용한다.
dirty tile만 갱신한다.
비활성 frame은 baked/composited cache image를 우선 표시한다.
playback은 preview cache image swap을 목표로 한다.
```

---

## 18. 현재 out of scope

Phase 150까지 brush model, brush input sample, canvas viewport coordinate model은 완료되었다.

하지만 다음은 아직 out of scope이거나 미래 기능이다.

```txt
actual drawing canvas integration
pointer event / tablet event integration
gesture-based zoom/pan UI
bitmap brush rasterizer
brush engine execution
stroke rendering changes
BitmapSurface / Tile implementation
DirtyTileSet / DirtyRegion implementation
TileDelta undo/redo
FrameCompositeCache / PlaybackPreviewCache implementation
save/load for bitmap tile data
renderer/cache/persistence implementation
onion skin
playback optimization
storyboard thumbnail/edit/export
storyboard metadata editing UI
Provider/Riverpod/Bloc/ChangeNotifier introduction
Photoshop-style / ABR brush import
```

주의:

```txt
다음 단계는 actual drawing UI가 아니라 bitmap canvas storage foundation부터 시작하는 것이 좋다.
```

---

## 19. 다음 recommended phases

Phase 146~150 추천 흐름은 완료되었다.

현재 다음 방향은 장기 bitmap canvas architecture 기준을 고정한 뒤, bitmap storage foundation으로 진입하는 것이다.

추천 순서:

```txt
Phase 151: Long-term roadmap / bitmap canvas architecture documentation
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyTileSet / DirtyRegion model foundation
Phase 154: TileDeltaCommand / undo delta architecture foundation
Phase 155: FrameCompositeCache / PlaybackPreviewCache policy foundation
Phase 156: Minimal bitmap brush rasterizer foundation
Phase 157: Canvas UI integration foundation
```

Phase 번호는 실제 진행 상황에 따라 조정할 수 있다.

중요한 것은 순서다.

```txt
bitmap storage
-> dirty tile tracking
-> tile delta undo
-> cache policy
-> brush rasterizer
-> canvas UI integration
```

Photoshop-style brush import는 이 흐름보다 뒤다.

---

## 20. Codex 작업 지시 작성 스타일

Codex 작업 지시를 작성할 때는 가능하면 아래 4단계 구조를 사용한다.

```txt
1. 만들 파일 안내
2. 그 파일에 복붙할 문서 안내
3. git add/commit/push 안내
4. Codex에게 전달할 문장 안내
```

Phase 작업 지시서에는 다음을 포함한다.

```txt
- 이번 Phase에서 어떤 구조/기능을 만들 것인지
- 왜 지금 이 Phase가 필요한지
- 읽어야 할 문서
- 명확한 goal
- strong scope rule
- required production changes
- required tests
- out of scope
- expected changed files
- required checks
- required report back
- acceptance criteria
- manual check list
```

문서-only 작업은 Codex를 쓰지 않고 사용자가 직접 복붙하는 방식이 더 안전할 수 있다.

---

## 21. PR 리뷰 스타일

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

수동 확인 체크리스트는 “이번 PR에서 바뀐 것만” 확인하도록 짧고 구체적으로 작성한다.

예:

```txt
model-only PR:
- 앱 실행 확인
- 기존 관련 화면에 눈에 띄는 변화가 없는지 확인

timeline PR:
- timeline 표시 확인
- scroll/playhead/selection 확인
- 이번 PR에서 바꾼 동작만 수동 확인

storyboard PR:
- StoryboardPanel 표시 확인
- cut selection 확인
- storyboard layer empty/present 상태 확인

canvas PR:
- canvas 화면 표시 확인
- 기존 drawing/canvas 동작 변화 확인
```

---

## 22. 다음 GPT 챗 시작 지시

새 GPT 챗에서는 이 인수인계문을 기준으로 이어간다.

먼저 아래 문서를 읽었다는 전제로 진행한다.

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Handoff_QuickAnimaker_v2_Current.md
```

그리고 다음 요청부터 시작한다.

```txt
위 인수인계문을 기준으로 이어서 진행해줘.

현재 QuickAnimaker v2는 Phase 150 Canvas viewport foundation까지 완료된 상태다.

Phase 146~150 추천 흐름은 끝났고, 이제 장기 bitmap canvas / brush / cache architecture 기준에 따라 다음 구현 방향을 잡고 싶다.

다음은 바로 brush UI나 Photoshop brush import로 가지 말고, BitmapSurface / BitmapTile / DirtyTileSet / TileDelta / PlaybackPreviewCache 쪽 기반부터 검토해줘.

내가 선호하는 방식은 다음과 같다.

- 새 Phase를 제안하기 전에 어떤 구조/기능을 만들 것인지 설명한다.
- PR 확인 시 수동 확인 리스트를 반드시 포함한다.
- 내가 제안하는 아이디어는 즉시 구현 요구가 아니라 장기 로드맵 후보로 검토한다.
- 최종 구현 타이밍은 장기 설계 관점에서 판단한다.
```

---

## 23. 최우선 기억 사항

```txt
QuickAnimaker v2는 bitmap-first animation tool이다.
최종 artwork source of truth는 bitmap tile data다.
Stroke는 표시용 source of truth가 아니라 input/history metadata다.
Undo는 장기적으로 tile delta 중심으로 간다.
Playback은 baked preview cache 중심으로 간다.
StoryboardPanel은 drawing canvas가 아니라 project/cut overview다.
Timeline range semantics는 절대 canvas/cache/storage 의미와 섞지 않는다.
다음 구현은 brush UI가 아니라 bitmap storage foundation부터 시작한다.
```
