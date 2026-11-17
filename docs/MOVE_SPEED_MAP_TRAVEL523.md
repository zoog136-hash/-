# 523 이동 속도와 맵 이동 (사용자 보고 2026-11-17)

사용자 보고: "1. 이속이 너무빠른데?" "4. 맵 이동이 안돼".
코드: `scripts/maps/source_walk_speed.gd`, `scripts/player.gd`,
`scripts/maps/current523_map_teleport.gd`, `scripts/world.gd`
(`current523_map_teleport`, 523 포탈 트리거), `scripts/maps/current523_aden_play_controller.gd`
(걸어 들어가는 포탈), `scripts/ui/original_ui/source_main_teleport_window.gd`.
검증: `tests/current523_move_speed_map_travel_test.gd` (CI는 합성 검사, 실제 팩이 있으면 실제 Main).

## 1. 이동 속도

### 원본 523 표

| 항목 | 값 | 출처 |
|---|---|---|
| 걷기 동작 | `ListSprAction` 0 "Walk"와 무기별 Walk 행 전부: PlayerFrameRate 36, PlayerDelay 16 | 원본 행 |
| 한 칸 걷는 시간 | 16 / 36 = 0.444초 → 초당 2.25칸 | 위 행에서 계산 |
| 이동 속도 보너스 | `BonusType` 34 MoveSpeedBonus 등, 값 / 1,000,000 (예: 50000 = +5%) | 원본 행 (기존 배율로 유지) |
| 기본 속도 열 | `Class`·`ConstantData`에 캐릭터 기본 이동 속도 열 없음 (`ObserverMoveSpeed` 2000000은 관전 카메라) | 원본 표 조사 |

PC 리니지의 같은 몸 동작은 16틱을 초당 24틱으로 재생(0.667초/칸)하고, M은 플레이어 걷기를
초당 36으로 재생한다(`PlayerFrameRate`). 걷기 한 번이 한 칸 이동이라는 점은 리니지 클라이언트의
칸 단위 이동 규칙이다. 대각선 한 칸도 직선 한 칸과 같은 시간(체비쇼프 거리)이다.

### 고치기 전

`player.gd`는 원본 523 지도에서도 모든 방향에 210 px/s(클릭 이동 225 px/s)를 썼다.
523 지도 칸은 48x24 마름모(`source_coordinates.gd` basis (24,-12)/(24,12))라서

| 화면 방향 | 한 칸 | 고치기 전 | 원본 |
|---|---|---|---|
| 좌우 | 48 px | 4.4칸/초 (2.0배) | 2.25칸/초 = 108 px/s |
| 위아래 | 24 px | 8.75칸/초 (3.9배) | 2.25칸/초 = 54 px/s |
| 격자 축 | 26.8 px | 7.8칸/초 (3.5배) | 2.25칸/초 = 60.4 px/s |

#630의 카메라 1.75배는 지도·캐릭터를 같은 비율로 키우므로 칸/초는 바꾸지 않지만, 화면 픽셀
속도가 1.75배로 커져 과속이 더 눈에 띄었다. 카메라 값은 그대로 두고 속도만 원본으로 맞췄다.

### 고친 뒤

- 원본 523 Land 필드에서는 조이스틱·키보드·클릭 경로·공포 이동 모두 방향마다 체비쇼프
  2.25칸/초 × 기존 이동 속도 배율(장비·버프·스킬·무게)이다. 원본 정의 ZIP이 있으면 그 행을
  읽고, 없으면 같은 숫자의 상수 사본을 쓴다.
- 실제 Main 측정(기란 시작, 배율 1.0): 오른쪽 2.21, 아래 2.25, 왼쪽 2.25칸/초.
- 걷기 애니: 원본 액터의 걷기 한 바퀴가 한 칸 이동 시간(0.444초 / 배율)에 끝나도록 원본 프레임
  시계를 늘이거나 줄인다(프레임·틱·순서는 그대로). 벽에 막혀 덜 움직이면 같은 비율로 느려진다.
  이 작업 환경의 테스트 팩에서는 플레이어 원본 액터가 시험 시간 안에 설치되지 않아(installed=false)
  실제 프레임 진행은 화면으로 확인하지 못했고, 배율 계산만 합성 검사로 확인했다.
- 돌진 스킬(`spell_move523` dash)의 속도 백분율도 이 걷기 속도에 곱한다.
- 523이 아닌 옛 지도(팩 없음)는 210 px/s 그대로다.

### 체감 속도 검색 결과

리니지M의 초당 칸 수를 수치로 적은 공개 자료는 찾지 못했다(인벤 등 검색: 프레임이 낮으면
이속·공속이 느려진다는 체감 글만 있음). 그래서 원본 표 값만 적용했고 TWILIGHT 근사는 쓰지 않았다.

## 4. 맵 이동

실제 Main(523 팩)에서 하나씩 확인했다.

| 경로 | 고치기 전 | 고친 뒤 |
|---|---|---|
| 순간이동 주문서(ItemClass 313) | 현재 Land 임의 위치 이동 | 변경 없음 (테스트로 확인) |
| 기란 텔레포터 NPC(멀린, TeleportList) → 지역 이동 창 | 목록이 옛 25개 지도(`maps.json`, 11월 이전 지도)라 523 세계에서 쓸 수 없음 | 원본 `UIMapArea` 목적지 |
| 월드맵 위치 선택 | 현재 Land 안에서 그 지점까지 보행 | 변경 없음 (테스트로 확인) |
| 맵 간 포탈 | 디버그 패널 버튼으로만 사용, 자체 비용 100000 아데나 | 원본 `Portal` 출발 칸을 밟으면 이동 |

### 텔레포트 목적지 (원본 표)

- `UIMapArea` 한 행 = 한 목적지: `TerritoryID` → `Territories`(LandID, StartX..EndY) 도착 상자,
  `LandTeleportID` → `LandTeleport`(TeleportCost, CurrencyID, AllowMapTeleport) 비용,
  `LandTeleportPrerequisite` → `Prerequisite`(MinLevel 등) 조건, 이름은 `DescData_Korean`(DescID).
- 목록: IsHide 아님, 도착 상자·비용 행 있음, AllowMapTeleport, CurrencyID 1(아데나), 테스트 태그 없음.
  예: 글루딘 마을 4,000 · 기란 마을 5,500 · 아덴 마을 6,000 아데나.
- 제외: CurrencyID 4(Gem, 하딘 텔레포트 탭 `HardinTeleportUIMapWorldID` 11093)와 LandTeleportID 0 행.
- 전제조건: MinLevel만 판정. 그 밖의 종류(예: 74 ItemInDefaultBag)가 붙은 행은 목록에 잠금으로 남고
  이동은 거절한다(면제하지 않음).
- 이동 규칙: 주문서 순간이동과 같다(`ITEM523_TELEPORT_WAIVE`: NoTeleport·비진입 속성 면제,
  MinLevel 판정, 경쟁 던전 통과), 도착하면 자동 사냥을 끈다. 아데나 차감은 도착 저장과 함께 저장된다.
- 실제 Main 확인: 글루딘 마을(LandTeleport 3) 4,000 아데나 차감, 도착 상자 안 착지, 자동 사냥 꺼짐.
- 원본 행 프레임: 목적지 종류(`UIMapAreaType` 3 마을, 4 던전, 5 필드)에 맞는 원본
  `Img_Village`/`Img_Dungeon`/`Img_Field` 프레임을 보인다.
- 523 지도에서는 옛 지도 id로 된 "오만의 탑" 탭(#623)을 숨긴다. 523 오만의 탑은 원본 이동 주문서
  (`items523_location_teleport`)로 간다.

### 걸어 들어가는 포탈 (원본 표)

- `Portal`(SourceLandID, SourceX, SourceY, TargetTerritoryID): 현재 Land의 출발 칸으로 걸어 들어가면
  `TargetTerritoryID`의 `Territories` 상자 안 첫 통행 칸으로 이동한다.
- `Portal` 표에는 비용 열이 없으므로 무료다(디버그 패널의 자체 수동 포탈 100000 아데나는 그대로).
- 대상 Land 진입 규칙: `WALK_IN_WAIVE` = 콘텐츠 입장 면제(NoTeleport, NoTeleportCome 등) +
  주문서 순간이동과 같은 비진입 속성 면제(UsableCallClan, ObjectLazyLoad, LandCondition,
  CompetitionDungeonLand 등). MinLevel은 판정한다. (실제 Main에서 기란 근처 Portal 329 →
  Land 17 CaveOfNerupa가 UsableCallClan 때문에 막히던 것을 확인하고 넣었다.)
- 도착 칸, 순간이동·부활 같은 몇 칸 이상 점프, 자동 사냥 중, 이동 직후 2초는 발동하지 않는다.
  0.2초 트리거 주기 사이에 지나친 칸도 검사한다.
