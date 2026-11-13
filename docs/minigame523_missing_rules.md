# 원본 523 미니게임 · 룰렛 확률 표시 — 판정표와 표에 없는 세부 규칙

조사 범위: 원본 523 정의 표의 `MiniGame*` 12개 표 전체(`MiniGameTreasure` 118행,
`MiniGameWaveTime` 26행 포함), 그와 연결된 `LuckyDefence*`·`NpcProduction*` 표,
룰렛 확률 표시 표(`RouletteDisplayOfGachaProbability` 56행 + `RouletteDisplayOfMergeProbability`
95행 = 151행, `RouletteDisplayConstant`, `RouletteDisplayStep`), `GotCha*`/`Gotcha*` 표.
낚시(`FishMiniGame*`)는 사용자 결정으로 끊은 표(`scripts/resources/current523_cut_tables.gd`)라
제외했습니다. 이 문서에는 원본 표의 행을 옮기지 않고, 판정에 필요한 열·규칙의 유무만 적습니다.

결론: **표 자료만으로 로컬에서 원본대로 플레이 가능한 미니게임이 없어 이번에는 코드를 추가하지
않습니다.** 원본 523의 `MiniGame` 표에는 미니게임이 하나(`LuckyDefence`, 화면 이름
"붉은 기사단의 방어전")뿐이고, `MiniGameTreasure`·`MiniGameWaveTime`을 포함한 `MiniGame*`
표의 모든 행이 이 하나에 속합니다. 이 미니게임은 지난번 결정과 같이 자료 부족으로 구현하지
않습니다. 룰렛 확률 표시 표는 미니게임이 아니라 카드 뽑기·합성 결과 연출 표이고, 연출 종류의
뜻이 표에 없어 구현하지 않습니다(기존 `scripts/unconfirmed523/events_domain.gd`의 원문 행 열람은
그대로 둡니다).

## 1. 판정표

| 대상 | 행 수 | ContentsControl Enable | 진입 방법 | 재화 획득 경로 | 진행 규칙(웨이브·보물·보상) | 판정 |
|------|------|------------------------|-----------|----------------|-----------------------------|------|
| `LuckyDefence` (MiniGame 1행, 4인 디펜스) | MiniGame* 전체 + LuckyDefence* 41행 | `LuckyDefence` **false** | 표에 최소 레벨·입장 재화(아인하사드 계열 화폐)·입장 횟수별 비용·제한 시간·전용 Land(4인 정원) 있음. 진입 NPC·메뉴 버튼·입장 날짜 창(`BookmarkResetDateTimeID` 이외)은 없음 | 판 안의 재화 `[디펜스] 마물의 결정`은 몬스터 처치 드롭(`NpcItemDropView`, **수량 없음**)과 "Wave N 시작 재화 지급" NPC(지급량 **없음**)로만 얻음. 판 밖 보상 화폐 `아덴 용사의 증표`는 제작 재료로 쓰임 | 웨이브 시간표(26행)·보물(버프) 목록·보물 등급 확률·리롤 비용·유닛 소환 비용/확률·합성 재료는 있음. **웨이브별 출현 몬스터·마릿수·출현 간격·경로가 없음**, 구성요소(`MiniGameComponentTypeID`)·종료 조건(`ConditionType`)·보상 종류(`MiniGameRewardType`) 열거형 이름 없음, 순위 보상은 4인 경쟁 순위 기준 | **구현 안 함** (Enable=false + 진행 규칙·재화 지급량 부족 + 4인 순위 전제) |
| `MiniGameSupporter`/`MiniGameSupporterGroup` (후원자 6행/2그룹) | 8 | 별도 항목 없음(그룹 `IsOn`: 한 그룹 false, 한 그룹 true) | `LuckyDefence` 안의 보물(획득 방식 42) 선택 화면 | 위와 같음 | `LuckyDefence` 판 안에서만 의미가 있음 | **구현 안 함** (상위 미니게임 미구현) |
| 룰렛 확률 표시 (`RouletteDisplayOf*Probability` 151행 + 상수 10행 + 단계 4행) | 165 | 별도 항목 없음 | 미니게임이 아님: 카드 뽑기(Gacha)·합성(Merge) 결과를 보여 줄 때의 단계별 연출 경로 | 해당 없음(결과 자체는 뽑기·합성 확률 표가 정함) | 단계(Step1~4) × 최종 등급 × 경로(Route) 묶음별 확률은 있음. **연출 종류(`RouletteDisplayTypeID` 15/25/35/45)의 뜻이 없음**, 경로 선택 규칙 불명확 | **구현 안 함** (연출 의미 부족, 기존 원문 열람 유지) |
| `GotChaEntityView` (14,447행) | 14,447 | `GotChaStatistics` false(통계 화면) | 상점 상품·카드팩의 보상 풀 | 기존 경로 | 이미 카드팩·상점 리더(`current523_market_gotcha_data.gd`, 몬스터 도감 카드팩)에서 사용 중 | **기존 구현 유지** (미니게임 아님) |
| `MarketGotchaPurchase` (4행) | 4 | — | 상점 구매 | 기존 경로 | 기존 상점 리더가 사용 | **기존 구현 유지** |
| `GotChaItem` (4행) | 4 | — | 연결 표 없음 | — | 이름 일부가 깨진 시험용 행 | **제외** (더미/시험 자료) |
| `GotchaArea` (5행) | 5 | — | 연결 표 없음 | — | 설명 문구가 시험용 문장 | **제외** (더미/시험 자료) |
| `GotchaBuffCardList` | 0 | — | — | — | 빈 표 | **해당 없음** |
| `FishMiniGame*` (4표) | — | — | — | — | 사용자 결정으로 끊은 표 | **범위 제외** |

## 2. LuckyDefence — 표에 있는 것

- `MiniGame`: 최소 레벨, 입장 화폐·비용, `ContentsControlID`(→ `LuckyDefence`, Enable false),
  제한 시간(초), 제목·이야기 문구, 배경 에셋, 초기화 날짜 ID.
- `MiniGameTicketCost`: 입장 회차별 화폐·비용(1회차 무료, 2회차 다이아).
- `MiniGameWaveTime`: 0~25 웨이브의 시작/끝 남은 시간(초). 웨이브 0은 준비 시간.
- `MiniGameTreasure`(118행): 이름·그룹·레벨(0~Max)·등급·비용 화폐·비용·`SpellClassID`·획득 방식
  (입장 전 구매 버프 / 판 안 보물 / 후원자 보물 세 종류).
- `MiniGameTreasureProbability`: 보물 등급별 확률(합 1,000,000).
- `MiniGameTreasureRerollCost`: 리롤 회차별 비용(판 안 재화 / 다이아 두 줄).
- `LuckyDefenceUnitSummon`(35행): 소환 종류·레벨별 `NpcProductionGenerationID`와 판 안 재화 비용.
- `NpcProductionGenerationOutput`: 소환 결과 NPC와 확률. `NpcProductionMerge`: 같은 등급 3개 합성.
  `NpcProductionCombination*`: 특정 유닛 조합 → 결과 유닛.
- `LuckyDefenceUnitGrade`: 유닛 등급 → 등급 단계 값.
- `MiniGameCellGroup` / `CellSubGroup` / `Cells`: 플레이어 1~4별 유닛 배치 칸(위치 ID).
- `MiniGameFinishCondition`: 3행(실패 1, 성공 2). 성공 조건 하나는 25웨이브 보스 NPC.
- `MiniGameReward`(9행): 참여 보상 5종, 순위(1~3위) 보상 상자 3종, 기타 1종.
- `TimeLimitLandMessage`: 웨이브별 안내 문구 25행.
- 원본 UI csb: 방어전 안내/후원자/팀 정보/확률 창(`Mission_Dungeon_Defense*`,
  `DefenseSupporter_*`, `DefenseTeamInfo_List_Popup`, `Common_Probability_Defense` 등)이 클라이언트에 있음.

## 3. LuckyDefence — 표에 없는 세부 규칙

| # | 항목 | 표에 없는 것 |
|---|------|-------------|
| 1 | 활성 여부 | `ContentsControl` `LuckyDefence` Enable이 false. 원본 523에서 꺼져 있던 콘텐츠를 로컬에서 켤지 사용자 결정 없음 |
| 2 | 웨이브 구성 | 웨이브별로 어떤 몬스터가 몇 마리, 어떤 간격·순서로 나오는지 연결하는 표 없음(몬스터 NPC는 이름에 "WaveN"이 붙어 있을 뿐, 출현 팩 `NpcSpawnPack*`에는 웨이브 0 재화 지급 NPC 4개만 있음) |
| 3 | 몬스터 이동 경로 | 플레이어별 몬스터 출현 영역(Territories)은 있으나 경로·도착 판정 없음 |
| 4 | 판 안 재화 지급량 | 몬스터 처치 시 `마물의 결정` 드롭 수량, "Wave N 시작 재화 지급" NPC의 지급량 없음 (`NpcItemDropView`는 품목만 있고 수량 열이 없음) |
| 5 | 구성요소 의미 | `MiniGameComponent` 45행의 `MiniGameComponentTypeID` 열거형 이름 없음 (값이 Territory·화폐·아이템 ID 등으로 섞여 있어 뜻을 단정할 수 없음) |
| 6 | 종료 조건 의미 | `MiniGameFinishCondition.ConditionType` 열거형 이름 없음 (실패 조건 값 50이 "필드 몬스터 수 한도"인지 등 불명) |
| 7 | 보상 종류 의미 | `MiniGameRewardType` 3종(참여/순위/기타 추정)의 이름·지급 조건(성공 시만? 실패해도?) 없음 |
| 8 | 순위 계산 | 4인(`IdealNumberOfPlayer` 4, PlayerIndex 1~4) 경쟁 순위 기준·동점 처리 없음. 혼자 플레이할 때의 순위·보상 규칙 없음 |
| 9 | 소환 실패 | 일부 소환 Generation의 확률 합이 1,000,000 미만인데 나머지 확률에서 무엇이 일어나는지(실패·환불·재시도) 없음 |
| 10 | 소환 레벨 상승 | 소환 레벨 0→Max를 올리는 비용·조건 없음 (`LuckyDefenceUnitSummon`에는 레벨별 결과·비용만 있음) |
| 11 | 보물 레벨업 | 같은 보물을 다시 얻었을 때 레벨 상승 여부, 최대 레벨 이후 처리, 보물 선택지 개수 없음 |
| 12 | 유닛 전투 | 아군 유닛의 공격 대상 선택·사거리·공격 주기 규칙(NpcClass 기본 능력치 외) 없음, 판매·이동 규칙 없음 |
| 13 | 등급 단계 값 | `LuckyDefenceUnitGrade.Value`가 무엇(합성 단계? 표시 순서?)인지 없음 |
| 14 | 입장 화폐 | 입장 화폐(ID 174)와 현재 구현된 아인하사드 축복 포인트의 관계·차감 단위 없음 |
| 15 | 회차 초기화 | 입장 회차(`MiniGameTicketCost.TryCount`) 초기화 주기는 `BookmarkResetDateTimeID`로만 가리키며, 2회차 이후 횟수 상한 없음 |
| 16 | 순위 보상 상자 내용 | 1~3위 상자 아이템의 내용물은 아이템 보너스 표에만 연결되어 있고, 순위 없는 로컬 판에서 지급 근거 없음 |

## 4. 룰렛 확률 표시 — 표에 있는 것과 없는 것

표에 있는 것:
- 단계 `Step1`~`Step4`(`RouletteDisplayStep`), 최종 등급(`GradeID`), 경로(`RouletteDisplayRouteID`
  15/25/35), 연출 종류(`RouletteDisplayTypeID` 15/25/35/45), 확률.
- 상수: 뽑기·합성 각각 기본/부활/확정 경로 확률(이름에 `Basic`/`Resurrection`/`Determine`),
  `MaxProbability`, `GradeOfBasicRoute`, `CanSkip`, `ShouldEditForGachaIntro`.
- 뽑기 표는 (단계, 등급, 경로) 27묶음 모두 확률 합 1,000,000. 합성 표는 48묶음 중 1묶음이 500,000.

표에 없는 것:

| # | 항목 | 표에 없는 것 |
|---|------|-------------|
| 1 | 연출 종류 | `RouletteDisplayTypeID` 15/25/35/45의 이름·화면 동작(어떤 등급 칸에서 멈추는지, 어떤 효과인지) 없음, 열거형 표 없음 |
| 2 | 경로 선택 | 상수의 경로 확률(기본 1,000,000, 부활·확정 33~34만)을 어떻게 결합해 한 경로를 고르는지(독립 판정? 순차? `GradeOfBasicRoute` 이하 등급은 기본 고정?) 없음 |
| 3 | 단계 수 | 등급마다 마지막 단계가 다른데(뽑기 Step4는 상위 2등급만) 단계 생략·종료 규칙 없음 |
| 4 | 합 부족 묶음 | 합성 표 1묶음의 나머지 500,000 확률의 처리 없음 |
| 5 | 연출 창 | 카드 뽑기·합성 연출 전용 csb와 노드 연결이 표에 없음(`Compose_Roulette`는 아이템 합성용) |
| 6 | `CanSkip`·`ShouldEditForGachaIntro` | 건너뛰기 시점, 인트로 수정의 뜻 없음 |

연출은 결과(등급)를 바꾸지 않으므로, 의미가 확정되기 전에는 기존 카드 뽑기·합성 결과 흐름을
그대로 두고 원문 행 열람(`events_domain.gd` "룰렛 연출" 항목)만 유지합니다.

## 5. 판정 검증 (`tests/minigame523_scope_test.gd`, `tools/ci_core.py` 등록)

- 원본 ZIP이 없으면 이 문서의 판정표·제외 기록만 확인합니다.
- 원본 ZIP이 있으면 판정 근거를 표에서 다시 읽습니다: `MiniGame` 1행(`LuckyDefence`),
  `ContentsControl` Enable false, `MiniGame*` 9개 표의 모든 행이 그 미니게임 소속,
  `MiniGameTreasure` 118행·`MiniGameWaveTime` 26행, `NpcItemDropView`에 수량 열 없음,
  디펜스 출현 팩에는 웨이브 0 재화 지급 NPC만 있음, 룰렛 표시 56+95행, 순간이동·던전 표
  (`LandTeleportTerritories`, `LandTimeLimit`, `SpecialDungeonType`, `SeasonDungeon`)에서 디펜스
  Land로 가는 행 없음.
- 실제 Main에 들어가 던전 projection에 디펜스 Land·미니게임 항목이 없는 것, 세이브에 미니게임
  상태가 없는 것, 저장 → 불러오기 후 아데나·레벨이 그대로인 것을 확인합니다.

## 6. 다시 볼 조건

- LuckyDefence: 웨이브별 출현 표(몬스터·수·간격)와 판 안 재화 지급량, 구성요소·종료 조건·보상
  종류 열거형 이름이 확보되고, 원본에서 꺼진 콘텐츠를 1인 로컬 판으로 켜는 사용자 결정이 있을 때.
- 룰렛 표시: `RouletteDisplayType`/`Route` 열거형 이름과 클라이언트 연출 csb 연결이 확보될 때.
