# 523 루틴(미션)·할 일 목록(현황판) — 표에 없는 세부 규칙

사용자 결정(2026-11-11): 원본 표 자료가 충분한 것만 구현하고, 표에 없는 세부 규칙은 지어내지 않고 거부·보존하며 이 문서에 남긴다.

구현 위치: `scripts/routine523/routine523_source.gd`(표 해석), `scripts/routine523/routine523_runtime.gd`(진행·보상·초기화·저장),
원본 UI `scripts/ui/original_ui/source_main_routine_page.gd`(Quest_All 미션 탭), `scripts/ui/original_ui/source_main_status_board.gd`(StatusBoard_All 현황판).

## 구현한 것 (표 근거)

| 항목 | 근거 표 |
| --- | --- |
| 미션 종류·탭 이름 | RoutineType 4 MissionDaily / 5 MissionWeekly / 21 MissionMonthly / 31 MissionWorldWeekly / 6 MissionComplete, 탭 이름은 RoutineType.DescID |
| 미션 제목·설명 | RoutineView.TitleDescID / ScenarioDescID, Goal.DescID |
| 목표 종류·수량 | Goal (GoalType, GoalClassID, Amount) — 연결 방법은 아래 1번 |
| 몬스터 그룹 처치 | NpcClassForNpcGroup (ServerLimitSetID 0 행만) |
| 미션 달성 보너스 | GoalType RoutineCompleteCount, GoalClassID = 집계할 RoutineType |
| 보상 | RoutineReward → Reward (Item 2 / Einasad 5). 화폐 아이템은 CurrencyUnitClass(UnitID 4, ForGive) — 원본 퀘스트 보상과 같은 경로 |
| 현황판 항목 | ToDoList (레벨 AddLevel ≤ Lv < RemoveLevel, ToDoListResetType 일일/주간, DateTimes_Korean 기간, ServerLimit 오프라인 KR 월드 1) |
| 추천 목록 | TodoListRecommend (자체 레벨 범위) |
| 등록 상한 | ConstantData TodoStatusBoardMaxRegistedContents (30) |
| 분류·세부 분류 | ToDoListUICategory(Priority 순서), ToDoListUISubCategory.Name |

## 표에 없는 세부 규칙 (거부·보존 또는 적용 기준)

### 루틴(미션)

1. **루틴→목표 연결 표가 없음.** RoutineView에는 목표 열이 없고 Routine 목표 표도 없다. 미션의 목표는 `Goal.ID = RoutineView.ID + 84870` 행으로 연결했다. 이 차이는 가정하지 않고, 불러올 때마다 미션 달성 루틴 3행(2958·3068·3188)이 RoutineCompleteCount(GoalClassID 4·5·21) 목표와 짝이 맞는지 확인하며, 맞지 않으면 미션 전체를 연결하지 않는다. 46행 중 38행이 이 방법으로 연결된다.
2. **목표 행이 없는 8행은 보류(진행·보상 없음).** 6822·6832(악몽의 섬), 7448·7458·7468·7478·7488(성물 카드), 10553(혼돈의 개미굴). 같은 문구의 미사용 Goal 행(93302·93312, 94738~94778, 101053)이 있으나, 연결을 보여 주는 표가 없어 쓰지 않았다. 이 때문에 일간 미션 달성(7개 필요)·주간(10개)·월간(11개)은 연결된 미션만으로는 다 채울 수 없다(일간은 연결 6행 중 파티 던전 1행 제외 5행).
3. **PartyDungeonComplete(2918·2998·3108):** 파티 던전(온라인 파티 콘텐츠)이 로컬 게임에 없어 집계하지 않는다.
4. **ItemPay(3198 다크엘프 장군의 배지, 3248 약탈한 은화):** 아이템을 제출(지불)하는 시점·차감 규칙이 표에 없어 집계하지 않는다.
5. **혈맹 레이드(3058·3178, NpcGroup 14048 "[미션] 혈맹 레이드 보스 그룹"):** 표대로 그룹 처치로 집계하지만 혈맹 레이드는 로컬에 없어 사실상 달성되지 않는다.
6. **BuffCardBuy(카드 구매) 집계 시점:** 표에는 덱(1 변신, 2 마법인형, 98 성물)과 수량만 있다. TWILIGHT에서는 카드 뽑기권 사용 1회(뽑기 1회)를 구매 1회로 센다(연결 기준, 확인 필요).
7. **RoutineCompleteCount의 "달성" 기준:** 목표 도달과 보상 수령 중 무엇을 세는지 표에 없다. 목표 도달(보상 수령 전 포함) 기준으로 센다.
8. **초기화 시각:** 표에 없다. TWILIGHT 공통 달력(사용자 결정 2026-11-09)을 쓴다 — 일간 KST 05:00, 주간·월드 주간 수요일 05:00, 월간 매월 1일 05:00. 기기 시계를 되돌려도 다시 초기화하지 않는다.
9. **Einasad 보상의 단위:** 표에 단위가 없다. 기존 출석·패스 보상(unconfirmed523)과 같이 아인하사드 축복 포인트로 지급한다(상한 999999).
10. **지급할 수 없는 보상 아이템(미션 보상은 받지 않은 상태로 보존):** 아이템 소유자(공급 경로)가 아직 연결되지 않은 아이템이다. 변신 제작 코인(3242)·마법인형 제작 코인(3252)·성물 제작 코인(246058, CurrencyUnitClass ForGive false), 드래곤의 진주(887), 시간 충전석(202238·202308·265763·202318·202328), 드래곤의 사파이어·다이아몬드·고급 다이아몬드(113882·113892·113902, 원본 정의 확인 실패). 아데나·명예 코인·상급 축복의 가루·장비 강화 주문서 상자·아인하사드 축복은 지급된다.
11. **혈맹 퀘스트(RoutineType 3, 490행)와 혈맹 전용 규칙:** RoutineDifficulty, RoutineRerollCost, RoutineReward.LevelRewardID/IgnorePercent, IsLucky, ConstantData Routine*(LevelRewardCondition, ClanSlotMaxCount, ExpandSlot*, RerollLuckyProbability) — 혈맹은 온라인 전용(사용자 범위 밖)이라 제외.
12. **랜덤 미션(RoutineType 46·56·66):** ConstantData RandomMission*Count(3)만 있고 RoutineView 행·후보 목록이 없어 구현하지 않았다.
13. **바로 가기:** 미션 행의 RoutineView.TeleportTerritoriesID가 모두 0이라 목적지가 없다. 행의 "바로 가기" 버튼은 숨긴다.
14. **RoutineSymbolID(2~6):** 아이콘 의미를 정하는 표가 없어 원본 csb 기본 아이콘을 쓴다.

### 할 일 목록(현황판)

15. **ToDoListTargetType 표가 없고 Value/Count의 의미가 유형별로 정의되어 있지 않다.** 진행 표시는 표가 직접 가리키는 경우만 한다.
    - DailyMission/WeeklyMission(22·32): 원문이 같은 미션 달성 루틴(2958 "일간 미션 달성", 3068 "주간 미션 달성")의 진행.
    - Quest(TargetType 2, Value = QuestView ID, 14행): 그 퀘스트의 완료 기록.
    - 나머지 147행(던전·제작·패스·낚시·지배석 등)은 진행을 표시하지 않는다(완료 표시 없음).
16. **퀘스트 항목의 일일/주간 초기화:** 퀘스트 완료 기록을 다시 여는 규칙이 없어 퀘스트 시스템의 기록을 그대로 보여 준다.
17. **TodoStatusBoardSeasonPassCompleteCount(6):** 의미가 표에 없어 쓰지 않는다.
18. **ShortcutType/ShortcutValue:** 이동 대상 규칙이 없어 "바로 가기"(Btn_Move)를 숨긴다.
19. **WeeklyOpenTImeGroupID(602·632):** 요일 개방 표시(Nd_Lock 조건 문구) 규칙이 없어 연결하지 않았다.
20. **분류 한글 이름:** ToDoListUICategory에는 영문 Name(Dungeon/Quest/Craft/Etc)만 있어 그대로 표시한다.
21. **분류 아이콘·보드 그림:** ToDoListUICategory의 AssetView 그림(StatusBoard/*.png)은 UI 팩 범위 밖이라 원본 견본 그림을 숨긴다.
22. **계정/서버 배지(Img_Account/Img_Server), 시간 충전 막대(Nd_Timebar):** 기준 표가 없어 숨긴다.
23. **추천/커스텀 전환:** 원본 Btn_Recommend/Btn_Custom 두 버튼으로 전환한다. 추천 목록의 표시 상한은 표에 없어 레벨 범위 안의 추천 행을 모두 보인다(등록 상한 30은 커스텀 등록에만 적용).
24. **이벤트 컨텐츠 자동 등록:** 원본 체크박스 문구만 있다. 켜면 기간 안의 이벤트 항목(IsEvent)을 커스텀 목록에 함께 보인다.
25. **혈맹 분류·혈맹 유형 항목(ClanQuest·ClanDonate·ClanDonateReward, 분류 Clan):** 온라인 전용(사용자 범위 밖)이라 목록에서 제외한다.

## 저장·성능

- 저장 키 `routine523`: 기간 키, 미션 진행, 보상 수령 기록, 현황판 모드·등록 목록·이벤트 자동 등록. 읽을 수 없는 저장은 그대로 다시 쓰고 진행·수령을 막는다.
- 원본 표는 부팅·전투 중에 읽지 않는다(PC 측정 첫 읽기 약 1.1초). 창을 열거나 보상을 받을 때 처음 읽고, 그 전의 사냥 등은 `pending`에 기간별로 모아 두었다가 아직 현재인 기간에만 반영한다.
