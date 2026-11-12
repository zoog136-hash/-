# 523 아이템 — 남은 미연결 묶음과 표에 없는 세부 규칙

사용자 결정(2026-11-11): 원본 표 자료가 충분한 것만 구현하고, 표에 없는 세부 규칙은 지어내지 않고
거부·아이템 보존하며 이 문서에 남긴다. 진행 순서(2026-11-12): 장비 → 스킬 → 소모품, 혈맹 전용은 집계만.

## 1. 집계 방법 (2026-11-12, main `1af65770` 기준)

- 대상: 원본 ItemClass 중 `TestItem=false` 30,398종. 게임 투영(`current523_native_item_projection`)에
  실패한 67종(`missing_current_native_record_projection`)은 별도.
- "가방 사용 거부" = 소모품(slot consumable) 중 사용 소유자(`current523_native_stack.profile`)가 없고 뽑기권이
  아닌 것. 사용 시 "원본 사용 조건·효과 미지원 · 아이템 보존"으로 거부되고 아이템은 남는다.
- "지급 불가" = 장비·아데나가 아니고 공급 소유자(`supply_profile`)도 없는 것. 드롭·보상·상점 지급 시
  "새 원문 비장비 물리 수량·소비 소유자 연결 대기 · 입력과 보상 보존"으로 거부된다.
- 묶음은 원본 ItemCategory + 효과 BonusType 조합(기간·표시 행 제외)이다. 이름으로 묶지 않는다.
- 기간이 지난 이벤트 아이템도 그대로 센다(연결되어도 기존 기간 규칙이 사용을 거부한다).

## 2. 장비 (2,954종 — 지급·장착 경로는 모두 연결)

모든 장비가 장착 슬롯(`source_equipment_status=mapped`)과 물리 지급 경로를 가진다. 직업 미확인·서버 조건
보류도 0종이다. 막히는 것은 효과(BonusType) 단위다. 투영 단계에서 처리하지 않은 효과 행을 아이템 수로 세고,
게임의 다른 소유자가 그 효과를 읽는지 확인했다.

| 효과(BonusType) | 장비 수 | 상태 |
| --- | ---: | --- |
| EnchantBonusGroupID / EnchantEquipGroupID | 2,681 / 1,893 | 강화 소유자(`patch523_rules`·`patch523_enhancement`)가 읽음 — 동작 |
| RegenHP / RegenMP / AbsoluteRegenMP / AttackDrainHP / AttackDrainMP | 225 / 381 / 24 / 71 / 51 | `patch523_passive_items`가 읽음 — 동작 |
| **SpecialResistance / HitSpecialResistance** | 203 / 195 | **이번 연결(아래 4.1)**: 스턴·홀드·공포·독 360종 |
| WeaponErodeProof | 939 | 미연결 — TWILIGHT에 무기 손상(부식)이 없어 효과 대상이 없음 |
| InvokeOption / ItemInvokeReplacementID / EquipSpellClassID | 192 / 48 / 16 | 장비 발동은 `patch523_equipment_spells`의 지정 아이템만. 나머지는 발동 주문·확률 연결 표 해석 미확정 |
| BuffClassID (장비 상시 버프) | 104 | 미연결 — 착용 중 버프 유지·해제 시점 규칙이 표에 없음 |
| CarryPlus | 100 | 미연결 — 원본 무게 단위(`source_weight_unit=unverified_source_units`) 미확정 |
| ElementalResistance / ElementalDamage | 90 / 46 | 세트 효과·강화 효과에서만 읽음. 장비 기본 행은 속성 대상(Target) 해석이 TWILIGHT 설정에 의존 |
| EquipGroupID | 78 | 제련·세공(`smith_smelt`)에서 읽음 |
| KarmaDeath / KarmaLife | 48 / 58 | KarmaDeath는 사망 소유자가 읽음, KarmaLife는 소비자 없음 |
| Fishing* (Power·ExpAmplifier 등 5종) | 55 | 미연결 — 낚시 소유자가 낚싯대 장비 행을 읽지 않음 |
| IgnoreFarBarrior / StorableOnEnchant / FixedDesc | 46 / 45 / 45 | 소비자 없음(설명·창고 규칙) |
| 그 밖의 소수 효과(치명타·관통·리덕션 비율 등 40여 종) | 각 1~35 | 효과별 계산 순서가 표에 없어 미연결 |

## 3. 스킬북 (BuffCardDrawer 2,244종)

| 묶음 | 수 | 상태 |
| --- | ---: | --- |
| 스킬북(source_skill_book) 투영 동작 | 1,327 | #410 병합 후 main(`8634f931`) 실제 Main에서 다시 확인: 원본 스킬 프로필과 정확히 연결 1,256, 그중 **습득 가능 381**(일반 377 + 학습 전용 4), **875는 연결된 스킬이 참고 전용(runtime_blocked) → "현재 주문 실행 소유자 미지원 · 스킬서 보존"**(스킬 실행 엔진 범위, 아이템 표 규칙으로 풀 수 없음), 71은 SpellClass ID·행 SHA가 441개 원본 프로필과 맞지 않아 보존 |
| 고정 카드(fixed_card) | 714 | 동작 |
| 스킬북, 직업 미지원(unsupported_skill_learn_class) | 47 | 거부 — 학습 직업이 TWILIGHT 직업에 없음 |
| 스킬북, 제한 카드 요구(source_skill_limit_card_requirement_unresolved) | 22 | 거부 — 카드 보유 요구의 판정 표 없음 |
| 스킬북, 비튜토리얼 학습 제한 없음 | 6 | 거부 — SpellLearnLimit 행 없음 |
| 효과 행 없음 | 95 | 거부 — 원본에 학습 대상 행이 없음 |
| LearnSpellClassID (덱 등급 조건 포함 18) | 13 + 18 | 보류 — 대부분 혈맹 전용(아래 6) 또는 테스트 이름. 스킬 묶음 차례에 재확인 |

## 4. 연결한 묶음

### 4.1 장비 상태 내성·적중 (이 문서와 같은 PR)

- 근거: ItemBonus → Bonus(BonusApplicationTypeID 2 = BonusApplicationType "SpecialResistanceType",
  Target = SpecialResistanceType ID), BonusType Unit Percentage, UIUnit Denominator 10000 (50000 → +5).
  같은 해석을 기존 칭호·몬스터 도감이 이미 쓴다.
- 연결: 투영이 `stun_resistance`, `stun_accuracy`, `hold_resistance`, `fear_resistance`,
  `fear_accuracy`, `poison_resistance`(침묵 `silence_*` 포함)를 채우고, 기존 `_stun_resistance_stat()` 등
  상태 판정이 착용 장비에서 읽는다. 장착 기록은 불러올 때 현재 정의에서 다시 만들어지므로 기존 보유 장비도 적용된다.
- 수치(실제 Main, 원본 팩): 360종, 행 수 스턴 적중 188 · 스턴 내성 140 · 홀드 내성 28 · 독 내성 22 ·
  공포 내성 8 · 공포 적중 8. 지급→장착→저장→다시 불러오기:
  #611 스턴 내성 7→12, #447 스턴 적중 7→13(기존 성장 곡선 포함), #516 홀드 내성 7→12,
  #370 독 내성 7→100(상한 100), 다시 불러온 뒤 같은 값·장착 유지.
- 테스트: `tests/items523_equipment_status_resistance_test.gd`.

### 4.2 드래곤의 성수류 — 아인하사드 충전 + 경험치 (별도 PR `feature/items523-einasad-exp`)

- 대상 184종: ItemCategory EinasadRecharager 중 Experience 행과 ItemConsumeRate(적용 42) 그룹 2를 가진 것.
- 근거: Experience × 그룹 2 Value / 10000 (30,400,000 × 10500 = 31,920,000)이 아이템 설명
  "EXP 31,920,000을 획득"과 같음을 매번 확인. 축복 충전량은 설명 "축복 N을/를 충전"과 일치 확인.
- EXP 단위: 리니지M 값 → TWILIGHT 값은 기존 곡선 환산(`HOLY_WATER_EXP` = 31,920,000의 TWILIGHT 값
  3,864,874)과 같은 비율. 표 규칙이 아니라 기존 TWILIGHT 환산이다.
- 수치: 50레벨 축복 150→1650, EXP 0→3,864,874, 1개 소비 / 85레벨 축복 +3000(그룹 12 ×2), EXP 동일 /
  44레벨·100레벨·축복 최대치는 거부·보존 / 이름 스택(상점) 경로 동일 / 저장→불러오기 수량·축복·EXP·레벨 유지.

## 5. 남은 소모품 묶음 (가방 사용 거부 4,276종)

| 묶음(ItemCategory · 효과) | 사용 거부 | 판정 | 표에 없는 것 / 처리 |
| --- | ---: | --- | --- |
| LuckyBag · LuckyBagClassID | 857 | 불가 | 보상에 테스트·제외 아이템 포함(388+156+52) — 후보를 빼면 확률이 바뀌어 거부. 직업별 확률 합 불완전(126+11) |
| LandTimeRecharger · RechargeLandTimeLimitGroupID + RechargeTime | 327 | 불가 | MaxRechargeTime이 기간당 충전 한도인지 잔량 상한인지 표에 없음. 기존 시간 풀(`current523_map_time_pool`)은 초기화 없음 정책이고 기본 개방 정책에서는 시간 제한 자체가 꺼짐 → 보존 |
| LuckyBag · (행 없음) | 197 | 불가 | 내용물 표 연결(LuckyBagClassID) 없음 |
| EinasadRecharager · +Experience | 184 | **연결(4.2)** | 그룹 2 행(1·99레벨) 밖 레벨, 축복 최대치일 때 EXP만 받는 규칙 없음 → 보존 |
| SelectReward | 175 | 불가 | 172종이 제외된 선택 보상(source_excluded_select_reward), 3종 RewardGetTimeTypeID 규칙 없음 |
| LuckyBag · ResetAutoSlotByEmpty | 174 | 보류 | 자동 사용 슬롯 표시 플래그. 단 155종은 내용물(장비 강화 주문서 등)의 공급자가 없어 열어도 거부됨. 주문서 묶음과 함께 처리 |
| ScrollEnchant · EnchantScrollGroupID (+ByBlessCode) | 157 + 23 | 불가 | 기존 강화 규칙에 결과 단계·비용 화폐·0개 소비·부작용·축복 도약 규칙이 미확정(`enhancement_evidence.unresolved`) |
| ScrollTeleportDungeon · TeleportToLocation | 141 + 21 | 불가 | 목적 Land 착지·충돌 실행 연결 없음(던전 지역 이동 보류와 같음) |
| ScrollQuest · QuestID | 137 | 불가 | 퀘스트 두루마리가 여는 퀘스트의 시작 조건·중복 규칙 없음 |
| ScrollBuffCardRetry / AwakenRetry (카드 재뽑기) | 107+52+46+17+34 | 불가 | 재뽑기 대상 카드 선택·결과 풀·PlayerValueReturn 의미 표 없음 |
| IntangibleItemRecharger · BlessPoint 등 | 102 | 보류 | 축복 포인트(IntangibleItemClass 14)는 문양 소유자 자체 기록이 이미 있음. 원본 물리 수량 경로와 합치는 소유 규칙은 문양 쪽 결정 필요 |
| Potion/Scroll/ScrollSpecial · BuffClassID (+IgnoreUseItemDuringBuff, ConsumeTerritoryClassID, CannotUseBuffGroup, Life, ValidLand) | 약 450 | 불가 | 버프 효과 중 이동·시전 속도 등 미지원 효과, 사용 금지 지역·버프 그룹 규칙 미연결 |
| QuestFreePass | 66 | 불가 | 효과 행 없음 |
| ScrollElementalEnchant | 64+24 | 불가 | 속성 강화 확률·실패 규칙 없음 |
| ScrollTeleport · TeleportToTerritory | 56+24 | 불가 | 지정 영역 이동 실행 연결 없음 |
| SummonStick · SpellClassID | 27+11 | 불가 | 소환 주문 실행 연결 없음(혈맹 소나무 막대 등 혈맹 다수) |
| 그 밖(CharacterCreateCount, GachaCraft, Smelt, SlotIncrease 등) | 각 8~16 | 불가 | 온라인 계정 기능이거나 실행 규칙 없음 |

## 6. 지급 불가(5,433종)와 루틴 보상

- 분류(슬롯·카테고리): LuckyBag 1,370 · StackableItem(재료, 제작 입력 없음) 581 · Potion 375 ·
  LandTimeRecharger 327 · ScrollBuffCardRetry 222 · BuffCardDrawer 203 · Emblem 196 · Currency 193 ·
  EinasadRecharager 193(→ 4.2 연결 후 9) · ScrollEnchant 181 · SelectReward 180 · 기타.
- 루틴 보상 중 지급 불가 확인:
  - 변신·마법인형·성물 제작 코인(3242·3252·246058): 화폐이지만 CurrencyUnitClass ForGive false — 보상 지급 불가가 표 값.
  - 드래곤의 진주(887): 버프 효과 CastSpeedBonus·RunSpritePoint 미지원, 사용 금지 지역 행 → 소모품 버프 묶음.
  - 시간 충전석 5종(202238·202308·265763·202318·202328): LandTimeRecharger 묶음(위 5).
  - 드래곤의 사파이어·다이아몬드·고급 다이아몬드(113882·113892·113902): 원본에서 `TestItem=true` → 보상이 테스트 아이템을 가리킴. 지급하지 않음.
- 아인하사드 충전 중 남은 9종: PlayerEinasadBless 행이 없는 2019년 이벤트 8종, 테스트 1종 — 기존 규칙(PlayerEinasadBless 1 필수) 유지.

## 7. 혈맹 전용 (집계만, 연결 안 함)

이름에 "[혈맹]"이 있는 아이템 중 가방 사용 거부 101종(BuffCardDrawer 30 · 뽑기 24 · SummonStick 18 ·
LuckyBag 8 · ScrollQuest 6 등), 지급 불가 178종. 혈맹은 온라인 전용(사용자 범위 밖)이라 연결하지 않는다.

## 8. 장비 상태 내성 중 남은 것

- Ice·Lapidification(석화)·Sleep·Dark(암흑) 내성 15종: TWILIGHT에 해당 상태가 없어 미연결.
- 같은 효과의 조건부 행(IsPossession, 적용 대상이 SpecialResistanceType이 아닌 행)은 연결하지 않는다.

## 9. '실수 in 정수배열' 점검 (#411 유형)

아이템 판정 코드(loot·equipment523·shop·einasad·routine523·강화)의 `X in [정수…]` 비교를 모두 확인했다.
대부분 `int()`/`whole()`로 감싸거나 `int` 형 변수다. 예외 1건: `equipment523/native_catalog.gd`의
`identity.get("schema") not in [3,4]` — 저장 JSON에서 온 4.0을 거부(연금술 대기분 이전 경로). `whole()`로 수정.
수정 전후 전체 30,398종 사용·지급 판정 집계는 변화 없음(막힘 원인 아님).
