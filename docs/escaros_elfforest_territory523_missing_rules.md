# 에스카로스 · 요정 숲 방어전 · 영지 퀘스트 523 — 연결 범위와 표에 없는 규칙

기준: 원본 523 정의 ZIP(`source.zip`, sha256 `d5192c3c…4f1832`). 오프라인 1인 플레이.
코드: `scripts/content523/escaros523.gd`, `elfforest523.gd`, `territory_quest523.gd`(표 모델),
`scripts/content523/content523.gd`(진행·저장 키 `content523`), `content523_panel.gd`(메뉴 "에스카로스·요정 숲"),
`scripts/maps/current523_aden_play_controller.gd`(콘텐츠 입장 시 Land 안 규칙 면제), `world.content523_enter_land`.
시험: `tests/content523_test.gd`(합성 행, `tools/ci_core.py` 등록).

## 1. 표 목록과 연결 상태

### 에스카로스 (`Escaros*` 6개 + 연결 표)

| 표 | 행 | 연결 |
| --- | ---: | --- |
| EscarosConstant | 11 | `EscarosDungeonID 314` → **CompetitionDungeon 314**(경쟁 던전), `VillageTerritoryID 201094`, `ArtifactUseCoolTime 5000`(ms) 사용. 나머지(효과 스프라이트·HUD 지연·Action 상태효과·안내 주기)는 표시 연출 |
| CompetitionDungeon / View / Land | 1 / 1 / 2 | 입장 이동 `LandTeleportId 14074`(아데나 100,000, `Prerequisite MinLevel 85`) → 마을 Territory 201094(Land 47954 비탄의 동굴). 필드 Land 47964 |
| EarthObjectSpawn + EarthObjectUnit(`LandTeleportID`) + EarthObjectAttribute(`Range`) | 마을 24행 중 텔레포터 | 마을 → 필드(14084, 100,000, Lv85, Range 12칸), 필드 → 마을(14104, 무료), 마을 → 오렌(14094). Range 안에서만 사용 |
| EscarosZone | 7 | Territory 상자 진입 시 지역 이름 안내 |
| EscarosLandmark / Group | 18 / 9 | 그룹별 `Prob` 추첨으로 하나씩 표시 → 조사 시 `Reward 152974`(RewardType **Einasad**, 100) |
| EscarosArtifact | 5 | 1~5라운드 아티팩트. `ActivationRange`(칸) 안 `TouchdownDelaySec` 대기 → 터치다운 횟수 기록(`ArtifactUseCoolTime` 간격) |
| EscarosArtifactRankReward | 수천 | **미지급**(순위 보상, 아래) |
| BuffClass/BuffBonus(65894~65934) | 5 | ExperienceAdditionPercent 50000 / UIUnit 10000 = **5%** 로 읽음. **미적용**(지속 단위 없음, 아래) |
| LandTimeLimitGroup 31594 | 1 | 7시간(25200초)·충전 상한 50400초·WeeklyWed. 기존 맵 시간 정책 그대로(상시 오픈 정책이면 면제, 원본 조건 정책이면 기존 맵 시간 풀) |

필드 Land 47964의 몬스터는 기존 원문 필드 개체군(`NpcSpawnPackTerritory`)이 그대로 배치·드롭한다(262 스폰 묶음).

### 요정 숲 방어전 (`ElfForestDefense*` 5개)

| 표 | 행 | 연결 |
| --- | ---: | --- |
| ElfForestDefenseGrade | 6 | GradeNo 0~5 → SpecialDungeon 342~392 → LandTeleport(아데나 10,000, MinLevel 80) → `[방어전][N승] 듀펠게넌 잔당 토벌` Land 51122~51172. **0단계(숲의 방문자)만 입장 가능** |
| ElfForestDefenseBlessing / Type | 4 / 4 | 운디네·실프·클레이·이그니스 가호 선택 저장, 우위 속성 표시. **효과 미적용**(아래) |
| ElfForestDefenseRewardGroup / Set | 12 / 12 | WinNo 1~12 → 퀘스트 100308~100418(Goal `ArenaWin` 1~12회) → 보상 표시. **지급 불가**(승리 없음) |

Land는 `IdealNumberOfPlayer 30`, `LandChannelTypeID 1`: 30인 팀 콘텐츠다. 파티던전(파티 전용)은 아니므로 제외 대상이 아니지만,
팀·승리 규칙이 없어 1인으로는 입장·사냥까지만 된다.

### 영지 퀘스트 (`TerritoriesQuest*` 4개)

| 행 | 영지 | 목표 | 상태 |
| --- | --- | --- | --- |
| 1 | [무너지는 섬] 1라운드 지역(44631) | ItemCollect 고대 주화(동) 100개, 600초 | **연결** · 보상 [무너지는 섬] 1단계 보상 상자 |
| 11 | [무너지는 섬] 2라운드 지역(44641) | ItemCollect 은빛 고대 주화 100개, 600초 | **연결** · 보상 2단계 보상 상자 |
| 21 | 3라운드 지역(44651) | CanRank "최후의 1인으로 살아남기" | 불가: 다른 플레이어 필요, 보상이 Ranking 행 |
| 42 | 없음(Territories 0) | 없음 | 빈 행 |
| 52 / 62 | [아덴 카니발] 1·2라운드 | PK "숨어있는 늑대" 처치 | 불가: 플레이어 처치 |
| 72 | [아덴 카니발] 3라운드 | CanRank | 불가 |

진행: 영지 상자 안에 들어가면 시작(`TimeoutSecond`), 진행 중 습득한 `Goal.GoalClassID` 원본 아이템 수(시련의 탑 ItemCollect와 같은 방식),
`AutoComplete false` → 창에서 완료, 시간 초과 시 실패. 주화는 그 Land 몬스터의 원본 드롭(NpcItemDropView)으로 얻는다.

## 2. 표에 없는 규칙 (지어내지 않음 · 기록만)

### 에스카로스
1. **아티팩트 버프 지속 단위**: `EscarosArtifact.BuffDuration = 15`에 단위(초/분)가 없고 BuffClass에도 지속 시간이 없다 → 경험치 5% 버프 미적용.
2. **라운드 일정**: `StartRoundNo 1`~`EndRoundNo 5`, `HotWeeklyOpenTimeGroupId 1074`가 있으나 어느 시각에 몇 라운드 아티팩트가 활성인지 표에 없다 → 5개 모두 상시 표시·기록.
3. **터치다운 순위·보상**: `EscarosArtifactRankReward`(순위 1~500)는 서버 전체 순위다. 1인 순위 판정이 없어 미지급. "터치다운 사열 몬스터"(설명 1233478)의 등장 규칙도 없다.
4. **랜드마크 재추첨 주기·조사 거리**: Prob 추첨 시점과 조사 범위가 없다. 자체: 한국시간 05시 일일 키로 추첨(같은 날 같은 결과), 기존 마을 NPC 대화 거리(190px) 안에서 조사, 하루 1회 보상.
5. **아인하사드 100의 단위**: Reward Amount를 그대로 축복 포인트에 더한다(루틴 523 미션 보상과 같은 기존 규칙).
6. **경쟁 던전 서버 조건**: 경쟁(타 서버 PvP)·`DungeonState`·ServerLimitSet은 오프라인에서 판정하지 않는다. `CompetitionDungeonLand` 입장 보류는 콘텐츠 입장에서만 면제.

### 요정 숲 방어전
7. **승리 판정**: 방어전 승리(ArenaWin) 조건(방어 대상·시간·웨이브)이 표에 없다 → 승리 0회 고정.
8. **등급 상승**: 승리 수 → GradeNo 규칙이 없다 → 0단계만 입장. 1~5단계 Land는 표시만.
9. **가호 효과**: `StatusEffectID`(4262~4292)의 효과 표(StatusEffect)가 ZIP에 없고 `StatusEffectAttr` 한 행(유형 178)만 있어 해석 불가 → 선택만 저장. 우위 속성의 상대(적 팀/몬스터)도 없다.
10. **팀 구성·30인 채널**: 팀 배정 규칙이 없다.
11. **이벤트 기간**: 시간 그룹 32562 / 퀘스트 StartTime·EndTime 274238~274248 — 기존 "종료 시즌 로컬 반복" 결정을 따른다(맵 시간 정책).

### 영지 퀘스트
12. **경기 진행**: 무너지는 섬(CompetitionDungeon 121)은 마을(44611)에서 라운드 지역으로 서버가 옮기는 대전이다. 이동 시점이 표에 없어
    **자체: 창에서 퀘스트 영지 상자로 바로 이동**(무료, Land MinLevel 등 Land 조건은 기존 판정).
13. **재도전 주기**: 없음 → 자체: 퀘스트별 하루 1회(성공·실패 모두).
14. **우편 지급**: `FromMailTextID`/`SubjectMailTextID`의 우편함이 게임에 없다 → 완료 시 가방으로 바로 지급(523 아이템 공급자).
15. **주화 소비**: ItemCollect 완료 시 주화를 회수하는지 표에 없다 → 회수하지 않는다.
16. **플레이어 드롭**: Land 속성 `PlayerItemDrop`(사망 시 주화 10~20% 떨어뜨림)은 다른 플레이어가 주울 때만 의미 → 미적용.

## 3. 실제 Main 확인 (원본 팩 `--source523-pack`, 2026-11-13)

- 에스카로스: 메뉴 입장 → 마을 Land 47954(아데나 100,000 차감), 마을 NPC 18 배치, 진실의 석판 조사 아인하사드 200→300,
  같은 날 재조사 거부, 텔레포터 "뷔오"(Range 12) → 필드 47964(100,000 차감), 필드 개체군 137구역 등록·15마리 생존,
  커스번 처치 경험치 획득, 필드 랜드마크 엔리쉬 조사 +100, 침묵의 칼날 터치다운 기록, 저장 후 다시 불러오기 → 필드 위치·진행 유지.
  필드의 112개 스폰 묶음은 기존 개체군 정책의 일정 묶음(scheduled_pack)이라 배치되지 않는다(기존 정책 그대로).
- 요정 숲 방어전: 0단계 → Land 51122(아데나 10,000), 환영 도살자 2마리 처치·경험치 획득, 가호 선택 저장.
- 영지 퀘스트: 무너지는 섬 1라운드 영지 이동 → 퀘스트 1 시작(600초), 목표 100개 달성 후 완료 → "무너지는 섬 1단계 보상 상자" 가방 지급
  (빈 NoReward 행은 건너뜀). 몬스터 8마리 처치에서는 주화가 떨어지지 않아 실제 습득 집계는 합성 시험으로만 확인했다
  (NpcItemDropView는 확률 없는 보기 표라 드롭률은 기존 드롭 정책을 따른다).

## 4. 사용자 결정이 필요한 항목

- 아티팩트 `BuffDuration 15`를 **분**으로 볼지 **초**로 볼지(또는 미적용 유지).
- 아티팩트 라운드 일정과 1인 터치다운 순위 보상(예: 항상 1위로 볼지, 미지급 유지).
- 요정 숲 방어전 승리 조건(예: 일정 시간 생존·몬스터 N 처치)을 자체 규칙으로 만들지 여부 — 정하면 등급·승리 보상 12단계가 열림.
- 랜드마크 재추첨/보상 주기(현재 일일 05시).
- 무너지는 섬 마을(44611) 경유를 넣을지, 영지 직행 유지.
