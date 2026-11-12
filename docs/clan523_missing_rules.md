# 523 혈맹 — 로컬 1인 혈맹으로 연결한 것과 표에 없는 규칙

사용자 결정(2026-11-11): 원본 표 자료가 충분한 것만 구현하고, 표에 없는 세부 규칙은 지어내지 않고 여기에 남긴다.
TWILIGHT는 오프라인 1인 게임이라 다른 플레이어가 필요한 혈맹 기능(가입·혈맹원·전쟁·동맹·순위 등)은 범위 밖이다.
기준: 원본 정의 ZIP `tables/source.zip`(기존 로더 `current523_definition_rows`), 실제 팩 `smoke523/root_ui`로 확인.

## 1. 연결한 것 (`scripts/clan523/clan523.gd`, 저장 키 `clan523`)

| 원본 표 | 쓰는 값 | 게임 |
| --- | --- | --- |
| ClanCreateGameClass (1행) | GameClassID 8 = 군주 | **군주만 혈맹 창설** (다른 직업은 원본상 다른 군주 혈맹에 가입 = 온라인) |
| ClanPolicies CreateLevelCondition / CreateCommission | 30레벨 / 아데나 100,000 (Unit 4, ItemClassID 26) | 창설 조건·수수료 |
| ClanMemberRankType Owner | DescID → "군주" | 창설자 직위 |
| ClanExperience (20행) | 레벨 L의 CumulativeExperience = L을 마치는 누적 경험치 (20레벨 999,999,999,999,999 = 상한) | 혈맹 레벨 1~20, 새 혈맹은 1레벨 |
| ClanDonate (3행) + CurrencyUnitClass | 일반 아데나 200,000 / 고급 Gem 100 / 최고급 Gem 300 (Gem = Intangible 2 = 다이아) | 혈맹 기부 3종 |
| ClanDonateReward (17행) | ClanExperience 90/150/500 · 명예 코인 600/4,000/12,000 · 기사단의 기부 증서 3/2/6 · ClanDonatePoint 90/150/500 | 기부 보상 (지급 가능한 것만, 아래 3) |
| ClanPolicies DonateExpRatio / MaxDonateCount / WeeklyMaxDonatePoint | 1배 / 5회 / 52,500 | 경험치 배율, 하루 기부 횟수, 주간 포인트 상한 |
| ClanDonatePolicy (3행) | DailyMaxDonatePoint 7,500 / 52,500 / 52,500 | 종류별 하루 기부 포인트 한도 |
| ClanDonateWeeklyReward (6행) | 3,000~52,500 포인트 → Reward | 주간 보상 수령 버튼 (지급 소유자가 있는 품목만, 아래 3) |
| ClanReward (20행) → Reward(Buff) → BuffClass "[혈맹] 버프 N단계" → BuffBonus → Bonus | 레벨별 효과 190행 중 **181행 적용** | 혈맹이 있는 동안 상시 버프 (기존 아이템 버프 소비처 `_active_item_buff_total`, 마법 대미지는 `_catalog_damage_bonus`) |
| UIClanBenefit (20행) | ContentsDescID 문구, BuffIconAssetID | 혈맹 창의 레벨 혜택 목록·원본 아이콘(이미지 팩이 풀어 줄 때만) |
| Emblem.OpenGrade (#408) | 혈맹 레벨 | 혈맹이 있으면 그 레벨까지 Predefined 문장 선택 (혈맹 없음 = 기존처럼 1레벨, 42개) |
| MerchantGoods ClanLevelMin · LimitMinClanLevel | 두 값 중 큰 값 이상의 혈맹 레벨 | 혈맹 상인 판매행 조건 (아래 2) |

버프 적용 예: 1레벨 경험치 +1%(ExperienceAdditionPercent 10000 ÷ UIUnit 분모 10000), 13레벨 HP+48·MP+48·AC 2·리덕션 2·근/원/마법 대미지·명중 +2·경험치 +2%,
20레벨 HP+70·AC 3·리덕션 3·대미지·명중 +2·경험치 +2%.
레벨 판정: 누적 경험치 ≥ 레벨 L의 CumulativeExperience 이면 L+1 (예: 3,999 = 1레벨, 4,000 = 2레벨).
하루·주간 경계는 사용자 결정(2026-11-09)의 게임 달력: 매일 KST 05:00, 주간은 기존 `domination_stone_runtime.week_key`.

## 2. 혈맹 상인 (MerchantGoods 91 / 833 / 1164 / 1371)

- 서버 선택 규칙은 표에 있다: 판매 NPC의 EarthObjectSpawn.ServerLimitSetID → ServerLimit(ServiceRegionCode, WorldNo).
  게임의 서버 프로필(`current523_server_profile`, 오프라인 KR 1서버)에 맞는 세트는 **762 하나**이고 그 NPC가 상인 91
  "[기란][라이브] 혈맹 상인"(EarthObject 621, 스폰 811 "[기란] 혈맹상인^린", 재화 ClanCoin = 명예 코인)이다.
  → `data/shop/source523_npc_local_rules.json`에 91만 추가. NPC 서버 스폰 조건은 이제 서버 프로필로 판정한다.
- 833(세트 782, WorldNo 221~ 리부트)·1164(세트 828, 191~ 신서버)는 서버 프로필과 맞지 않아 닫힘(172+181행).
  1371(138행)은 EarthObjectUnit에 상인 연결 NPC가 없어 닫힘.
- 91의 183행 판정: 혈맹 레벨 조건 → 로컬 혈맹 레벨. LimitRepeatedBuyCardID(168행) → 그 카드가 그 원본 스킬서 자신의
  BuffCard인지 확인하고, 이미 배운 주문이면 재구매 차단(기존 마법상인 "습득 후 재구매 차단"과 같은 해석),
  원본 학습 조건(직업·레벨)이 안 맞으면 차단.
- 가격: 기존 TWILIGHT NPC 가격 정책(원본 ItemClass.Cost × Percentage, 재화는 NPC의 원본 재화 = 명예 코인)을 그대로 쓴다.
  예: 혈맹 순간이동 주문서 Cost 10,000 → 명예 코인 10,000, 카운터 매직 500,000, 섬광류(13레벨) 수천만 단위.

### 실제 팩 측정 (smoke523/root_ui, 실제 Main)

| 상태 | 상인 91 구매 가능 행 |
| --- | ---: |
| 이번 변경 전 (혈맹 조건이 있으면 전부 거부, 서버 세트 762 스폰도 거부) | 0 / 183 |
| 혈맹 없음 | 0 / 183 (모두 "혈맹 레벨 N 필요") |
| 혈맹 1레벨 | 0 / 183 (최저 조건이 2레벨) |
| 혈맹 20레벨 · 85레벨 · 명예 코인 충분, 직업별 | 군주 5 · 기사 6 · 요정 9 · 마법사 12 · 다크엘프 7 · 광전사 2 · 총사 3 · 투사 4 · 암흑기사 5 · 신성검사 5 · 사신 5 · 뇌신 8 · 마검사 7 |
| 위 합집합(어느 직업이든) | **49 / 183** |

군주로 구매 → 보관함 수령 → 사용(습득) → 같은 행 재조회 "이미 습득함" 까지 실제 Main에서 확인
(마법서 (브레이브 멘탈)(혈맹상점), 명예 코인 16,000,000).
군주 기준 남은 막힘: 다른 직업 스킬서 126, 스펠 그룹 마스터리 조건 10, 원본 물리 공급 없음(축복 순간이동 주문서 등) 10,
LimitBuffCardID 23, 기존 스킬 연결 없음 4, 스킬 실행 보류 3, 직위 조건 1, 원본 더미 1.

## 3. 표에 없는 규칙 (지어내지 않음)

1. **사냥·미션 혈맹 경험치.** ClanPolicies HuntingExpRatio 1, MissionExpRatio 1, ClanExperienceAbsoluteValue 20,000 이
   있으나 무엇에 곱하는지(캐릭터 경험치? 처치 수?) 표에 없다. 기부만 혈맹 경험치를 준다.
   그래서 1인 혈맹은 레벨이 매우 느리다: 하루 최대 5회 기부, 최고급(다이아 300) 5회 = 2,500 경험치/일,
   13레벨(10,010,000)까지 약 4,000일. **사용자 결정 필요** (예: 사냥 경험치의 일정 비율을 혈맹 경험치로).
2. **MaxDonateCount 5의 기간.** UnitId 1(Value)만 있고 기간이 없다. DailyMaxDonatePoint와 같은 하루(05:00)로 적용.
3. **Currency.ExchangeRate.** ClanCoin 100, Gem 825, Adena 1. 가격 환산에 쓰는지 표에 없다. 현재 가격 정책은 환율을 쓰지 않아
   혈맹 상점 가격이 명예 코인 단위로 매우 크다(위 2). **사용자 결정 필요** (환율 100으로 나눌지).
4. **아인하사드 기부 보상**(Unit Einasad 2,500 / 7,500). 원본 축복 단위(EinasadVariable 6,000 = 1포인트)인지 표시 포인트인지
   표에 없어 지급하지 않는다(기부 결과에 "미지급"으로 표시).
5. **지급 소유자가 없는 보상**: 기사단의 증표(215394, 화폐지만 게임 지갑 없음) 60/200/600 → 미지급.
   주간 보상 결속의 주화(353752, 화폐·지갑 없음) 5종, 특별한 뿔피리 선택 상자(353592, Life 미지원) → 수령 거부(수령 기록도 안 남김).
6. **혈맹 이름 규칙.** 길이·금지어 표가 없다(금지어는 사용자 범위 밖). TWILIGHT 기술 제한 1~16자.
7. **ClanContentLevelRestriction (12행).** ClanContentTypeID(1~111)의 이름 표가 없어 어떤 기능인지 알 수 없다. 화면에는
   UIClanBenefit 문구만 보인다.
8. **혈맹 버프 효과 중 소비처 없는 것 9행**: RangeEvasion 5행(16~20레벨), PierceMeleeEvasion·PierceRangeEvasion 각 2행(19·20레벨).
   게임에 원거리 회피·회피 무시 버프를 읽는 곳이 없어 미반영(창에 "미반영"으로 표시).
9. **MerchantGoods 91 남은 막힘**: LimitBuffCardID 23행(신화 변신 카드 보유 조건 — 카드 보유 판정 규칙 없음),
   LimitClanMemberRank 1행(어느 직위인지 값이 bool뿐), 혈맹 레벨 15·16·17·19 행은 레벨 도달 필요.
   DaysAfterClanJoin·LimitDaysAfterClanJoin(상인 123 9행) — 로컬 창설자의 "가입일" 정의 없음, 거부.
10. **혈맹 전용 아이템 (현재 집계 33종 사용 거부·지급 불가, 이름 "[혈맹]" 105종 중)**: 특수-신화 스킬서 22종
    (학습 조건에 신화 변신 카드 필요 — `source_skill_limit_card_requirement_unresolved`), 속성 강화·변환 주문서 5종,
    마법서·정령 수정 등 효과 소유자 없음 6종. 혈맹 규칙이 아니라 스킬·강화 쪽 미연결이라 이번에 연결하지 않음.
    이전 감사(사용 101 · 지급 178)는 그 뒤 PR들(#423 선택 상자 등)로 대부분 연결됨.
11. **성장의 뿔피리·전투의 뿔피리(350562·350572, ClanRewardOnItemUse)**: 사용 시 혈맹원 전원에게 버프(성장 = 경험치 +20% 1,800초,
    전투 = PVP 리덕션). 성장 뿔피리는 표로 정의되지만 얻는 경로가 주간 52,500포인트 보너스 상자(Life 미지원)뿐이고,
    1인 혈맹의 "혈맹원 전원" 적용 범위가 표에 없어 연결하지 않음. 전투 뿔피리는 PVP 전용(게임에 PVP 없음).
12. **Reward.RewardGetTimeTypeID / ClanOnly / UseImmediately**: 혈맹 보상 행에서 의미 표가 없어 읽지 않음.

## 4. 온라인 전용 (범위 밖)

혈맹 가입·신청·탈퇴(JoinLevelCondition, RejoinDuration, MaxMemberCount 50 …), 혈맹원 직위·권한(ClanMemberRank*),
적대·동맹·연합(MaxEnemyClanCount, MaxAlly*, Coalition), 혈맹 채팅·음성·푸시, 혈맹 순위·기부 순위(ClanExpLeaderBoardReward,
RankCount), 혈맹 레이드(ClanRaidClass 9 · ClanBossRaidView 9 · ClanRaidRank* — 혈맹원 분배·순위·차원의 열쇠),
혈맹 퀘스트(ClanQuest 5행 전부 IsTest=1), 경매·분배(Auction*, ClanItemDistribute*), 혈맹 아지트, 공성 상인(123),
서버 이전, 혈맹 컬렉션(ClanCollectionMaterial 5행, 컬렉션 본체 표 없음).

## 5. 원본 UI

원본 클라이언트에는 `UI/Clan/` CSB가 많지만(Clan_All, Clan_Popup_Benefit, Clan_List_Join_Donate_A/B/C …), 523 UI 추가 팩
(`main_pack5`, manifest e25584b0…)에는 문장 팝업 5개(Clan_Popup_Symbol, Clan_Tab_Mark, Clan_Tab_Mark_Request,
Clan_Mark_FlagSlot, Clan_Mark_FlagSlot_Set)만 들어 있다. 그래서 혈맹 창은 기존 일반 창(텍스트·버튼)으로 만들고, 그림은
그리지 않았다(레벨 아이콘만 원본 AssetView로 연결). 원본 창으로 바꾸려면 추가 팩에 위 CSB와 그 텍스처를 넣어야 한다.
