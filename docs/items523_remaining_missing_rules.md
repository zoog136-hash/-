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
| **InvokeOption (아이템 기본 행)** | 192 | **이번 연결(아래 4.3) 187종**: 크로우 치명 42 · 이도류 배율 80 · 총 출혈 65. 남은 5종은 주문 실행·없는 상태라 미연결(아래 10.2) |
| ItemInvokeReplacementID / EquipSpellClassID | 48 / 16 | 미연결 — 아래 10.2 |
| BuffClassID (장비 상시 버프) | 104 | 재검토 결과 미연결 — 18개 버프 모두 기존 소비자가 없는 효과를 포함(아래 10.1) |
| **CarryPlus** | 100 | **이번 연결(아래 4.3)** — Weight 단위 UIUnit 분모 100, 원본 설명문으로 확인 |
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

### 4.3 장비 무게 보너스(CarryPlus)와 무기 기본 발동(InvokeOption) (PR `feature/items523-equip-effects`)

**무게 보너스 CarryPlus 100종**

- 근거: BonusType CarryPlus(ID 68)의 UnitID 44 = Unit "Weight", UIUnit(UnitID 44) Denominator **100**.
  표 안의 설명문으로 확인: 판도라의 유물(#8661) CarryPlus 50000 ↔ 같은 표 설명(DescID 211891)
  "무게 보너스+500", 같은 아이템 HPPotionIncreasePercent 50000 ↔ "물약 회복률+5%"(Percentage 분모 10000).
  카드 덱 보너스(#397)·컬렉션·강화 투영이 이미 쓰는 규칙(`CarryPlus / 100 → weightBonus`)과 같다.
- 연결: 투영이 장비 기록에 `weightBonus`(정수, 나머지 0일 때만)를 채우고, 기존 소지 한도
  `_carrying_capacity()`의 `_equipment_inven_sum("weightBonus")`가 착용 장비에서 읽는다.
- 값 분포(종 수): +1000 32 · +1500 9 · +2000 9 · +500 7 · +3000 7 · +200 7 · +250 5 · +300 4 · +100 4 · 그 밖 16.
- 표에 없는 것: 원본 아이템 자체 무게(ItemClass.Weight)는 여전히 TWILIGHT 추정(ceil(raw×3/351),
  `data/item_weight_rules.json`)이고 소지 한도 기본값(2500+CON×100)도 TWILIGHT 값이다. 즉 보너스는 원본
  표시 단위(÷100) 그대로 더하지만, 아이템 무게와 한도 기본값은 원본 단위가 아니다(기존 카드·컬렉션 보너스와 같은 상태).

**무기 기본 발동 187종** — 아이템 ItemBonus의 InvokeOption 행(적용 BonusApplicationType 10 "InvokeOption",
대상 = InvokeOption ID, 확률 = Value: Percentage 분모 10000 → 180000 = 18%)

| InvokeOptionType | 종 수 | 원본 값 | 연결한 기존 소비자 |
| --- | ---: | --- | --- |
| 9 Attack_AddCriticalProbability (크로우) | 42 | 확률 22~32% | `world._roll_weapon_damage` → 무기 기본 대미지를 최대값으로(기존 규칙: 공식 무기 안내) |
| 6 Attack_WeaponDamageScale (이도류, 설명 "더블 확률") | 80 | 확률 16~30%, Param1 2000000 = ×2.0 | 같은 경로. 배율 적용 범위(기본+추가·강화 / 기본만)는 기존 TWILIGHT 설정 `patch523_weapon_double_scope` |
| 1 Attack_Spell, 옵션 611 → SpellClass 17564 "[총사] 출혈" (라이플·캐넌) | 65 | 확률 0.5%, 3초, BuffClass 51984 10D1, MaxHPPercent 50 | `patch523_weapon_bleed` (틱 0.75초·누적 HP 50% 상한은 기존 TWILIGHT 설정) |

- 이 세 종류의 해석·소비자는 예전 공개 컴파일러(`tools/monsters/patch523_item_definitions.py`)가 만들던
  `source_invoke_options`와 같다. 현재 원본(523) 정의 경로는 이 목록을 항상 비워 두어 소비자가 동작하지 않았다.
  새 `scripts/loot/current523_weapon_invokes.gd`가 같은 조건(무기 슬롯·IsPossession false·조건 열 0·
  공격 측·BySpellAttack false, 출혈은 17564/51984 사슬 값 전부 일치)으로 현재 표에서 다시 만든다.
- 강화 단계 발동(ItemEnchantBonus의 InvokeOption, `patch523_invoke_options`)과는 다른 행이라 중복 적용되지 않는다.

**실제 Main·원본 팩 확인**(`tests/items523_equipment_carry_invoke_test.gd`): 검사 34개 통과.

- 투영 집계: CarryPlus 100종·100행, 발동 크로우 42 · 이도류 80 · 출혈 65. 막힌 발동 행은 무기 아님 12 · 미구현 종류 12 등으로 보존.
- #323 오우거의 벨트(CarryPlus 100000 → +1000): 지급→장착 소지 한도 4100→5100, 저장→다시 불러오기 5100·장착 유지, 해제 시 4100.
- #500 강철 크로우(22%): 20,000회 굴림 중 21.8% 발동, 발동 시 무기 기본 대미지 = 최대값(17).
- #489 강철 이도류(16%, ×2.0): 15.7% 발동, 발동 시 (기본 4 + 추가 5)×(2.0−1) 더해 13.
- #96364 사냥꾼의 라이플(0.5%): 실제 일반 공격 판정으로 506번째에 출혈 걸림, 지속 3초·10D1·HP 50% 상한.
- 세 무기 모두 저장→다시 불러오기 후 장착·발동 유지.

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

## 10. 장비 묶음 재검토 (2026-11-12)

### 10.1 장비 상시 버프 BuffClassID 104종 — 미연결 (버프 18개 전부 확인)

착용 중 상시 적용 자체는 기존 장비 보너스와 같은 규칙(장비 ItemBonus 행 = 착용 중 적용)으로 볼 수 있다.
막히는 것은 버프 안의 효과(BuffBonus)이며, 순수 능력치만 가진 버프는 하나도 없다.

| BuffClass | 종 수 | BuffBonus 내용 | 판정 |
| --- | ---: | --- | --- |
| 82511·82371·82521·82531 "[낚싯대] … 폴 변신" | 55 | PolymorphSetID + 이동 속도 + 생성 이펙트 | 제외 — 낚싯대(끊은 낚시 콘텐츠) |
| 95478 "타겟팅 고정 #무기 데스 락" (기르타스 무기 등) | 24 | CannotReleaseTarget · IgnoreRestrainInvokeUniversalGroup(발동 억제 무시, 8행) · ImmuneBuffType 71 · AmmoClassID | 불가 — 대상 고정·발동 억제 무시·면역 버프 종류·탄환 교체 소비자 없음 |
| 53952·51683·55014·55024·78962·84644 (변신 무기·영웅 변신 반지·기자 모자·만우절) | 14 | PolymorphSetID + 공격/이동/시전 속도·대미지 등, 모자는 CannotAttack·CannotCastSpell | 불가 — 변신 외형 소유자는 변신 카드 등록부뿐. 장비발 변신과 카드 변신의 BuffGroup 경합·변신 무기 제한(#407) 연결 규칙이 없고, 속도만 넣으면 변신 효과 일부만 적용됨 |
| 23 "투명 망토" | 3 | Invisible · CannotAttack · CannotLoot · StopActionByTargetting · StatusEffectID | 불가 — 착용만으로 상시 투명+공격 불가가 되는지, 해제 조건(IsEraseOn* 전부 false)이 표에 없음. 기존 은신(`is_player_concealed`)은 스킬 버프 전용 |
| 11351 "수중 부츠" | 2 | 행 없음 | 효과 없음 |
| 67231~67261 "[쟁탈전껍데기용] 영예의 전투" | 4 | 행 없음 | 효과 없음(쟁탈전 = 온라인) |
| 79021 "안티 블라인드" (발록의 핏빛 투구) | 2 | SpecialResistance 대상 5 Dark | 불가 — TWILIGHT에 암흑 상태 없음 |

### 10.2 장비 발동 중 남은 것

- 발록의 핏빛 망토 2종: Attack_Spell "핏빛 계약: 수혈"(근접·원거리·암흑기사·근접마법, AttackTypeID 1/2/42/72) —
  주문 실행이 필요(스킬 실행 엔진 범위). AttackTypeID 42·72는 기존 공격 종류(0~3)에 없음.
- 만우절 휘장 1종: Defence_Spell "피격 시 생명력 300 회복" — 방어 측 주문 실행 필요.
- 발록의 핏빛 투구 2종: Defence_DebuffTimeDecreasePercent "암흑" — 암흑 상태 없음.
- ItemInvokeReplacementID 48종(신화 무기 18 등): ItemInvokeReplacementEntityView가 슬롯별 교체 후보와
  확률(Prob)만 준다. 교체를 언제·무엇을 소비해 굴리는지(획득 시/아이템 사용 시)가 표에 없음.
- EquipSpellClassID 16종(발센의 문장·에오딘/질리언의 스톤 등): 값이 SpellClass 1 "에너지 볼트" — 착용 시
  주문 습득/실행 규칙은 스킬 실행 엔진 범위. 이번 PR에서 다루지 않음.
- 크로우·이도류·출혈의 확률은 표 값이지만, 크로우 = "무기 최대 대미지", 이도류 배율 적용 범위, 출혈 틱 간격·
  HP 상한 의미는 표에 없고 기존 TWILIGHT 규칙/설정을 그대로 쓴다.


## 11. 소모품 1단계 — 상자 (2026-11-12, PR `feature/consumables523`)

집계: main `b488fb36` 기준, 실제 원본 팩으로 LuckyBag·SelectReward·ComplexReward 등 대상 카테고리 비테스트 14,887종의
사용 소유자(`current523_native_stack.profile`)를 다시 셌다. "사용 가능" = 사용 소유자가 있는 것. 그중 상자 안 보상이
하나라도 지급 소유자(공급 프로필) 없이 남아 있으면 실제 개봉 때 "후보 제거 없이 상자 보존"으로 거부되므로 따로 표시했다.

### 11.1 연결한 것

요약: LuckyBag 사용 거부 1,370 → 1,099 (+271), SelectReward 180 → 180, 대상 카테고리 전체 사용 가능 12,465 → 12,736.

| 묶음 | 수 | 근거 |
| --- | ---: | --- |
| **LuckyBag 선택 상자** (LuckyBagEntityView 행이 전부 LuckyBagEntityType 3 "Selectable") | 이전 0 → **99** (그중 모든 선택지 지급 가능 96) | 선택 개수는 LuckyBagClass에 열이 없고, 아이템 자신의 원본 설명(StoryDescID)이 "다음 아이템 중 1종 선택 획득"으로 적는다. 설명에 적힌 개수가 하나(1)일 때만 연결. 받는 것은 고른 행의 ItemClassID·ItemAmount·ItemBlessCodeID·ItemEnchant 그대로(+6 등, 자체 초기 강화 규칙 없음) |
| **ResetAutoSlotByEmpty 상자** (TrueFalse 1) | 이전 0 → **172** (그중 열 수 있는 것 29) | "다 쓰면 자동 사용 슬롯 해제" 표시. 상자는 AutoUseRegistrable 행이 있어야 자동 슬롯에 들어가는데 그런 상자는 여전히 거부되므로, 해제할 슬롯이 없어 값 그대로 만족. 단 이 중 143종은 내용물(강화 주문서 140행 등)에 지급 소유자가 없어 열면 보존됨 |
| 선택 보상 창 연결 (SelectReward + 위 선택 상자) | 3,149 + 99 | 가방에서 사용하면 기존에는 "원본 UI에서 보상을 선택하세요"만 뜨고 고를 창이 없었다(`requires_original_selection`을 받는 곳이 없음). 이제 기존 선택 창(`patch523_reward_choice`)이 열리고, 확인 시 `consumable_service.claim_owned_original_selection`이 물리 개체·영수증·선택 행을 다시 증명한 뒤 1개 차감·지급·저장한다. 열기·취소는 차감하지 않음. 퀘스트 보상으로 받은 선택 상자도 같은 창 |

실제 Main·원본 팩 확인(`tests/items523_selection_boxes_test.gd`, 검사 41개 통과):
- #187362 "+6 스냅퍼의 반지 선택 상자": 창에 원본 3행(+6) → 2번째 선택 → 상자 2→1, 고른 반지 +6 지급 → 저장→다시 불러오기 후 상자 1·반지 유지, 다시 창 열림.
- #193581 "+4 지휘관의 휘장 상자"(ResetAutoSlotByEmpty): 열면 상자 소비, +4 휘장 지급.
- 기존 SelectReward 상자(#147012)도 같은 창으로 수령.

### 11.2 남은 상자 (표에 규칙이 없어 보존) — 1,285종

| 묶음 | 수 | 표에 없는 것 |
| --- | ---: | --- |
| 보상에 테스트(TestItem=true)·더미 아이템 포함 — LuckyBag | 630 | 대부분 예전 "[변신 카드]/[마법인형 카드]" 아이템(TestItem=true)이 확률·확정 행에 있다. 빼면 확률이 바뀌고(확률 상자), 확정 상자는 내용이 달라진다 → 상자 보존 |
| 같은 이유 — SelectReward | 172 | 42종은 선택지 전부가 테스트 아이템, 130종은 일부. 선택지를 빼는 규칙 없음 |
| LuckyBagClassID 행 없음 | 200 (+ SelectReward 2, ComplexReward 6) | 내용물 표 연결 자체가 없음 |
| 확률 합이 직업별 10,000,000이 아님 | 129 | 합 2,000,000 등(나머지가 "꽝"인지, 재정규화인지, 행별 독립 추첨인지 표에 없음). 5종은 일부 직업만 0 |
| ClassUsageInterval (초) | 77 (45 + 조건부 32) | 직업별 재사용 간격의 시계(실시간/접속 시간)·저장 범위가 표에 없음. 32종은 적용 대상 314 행 |
| UsageInterval (초) + InfiniteAmount | 17 (12 + 5) | 무한 수량 상자의 재사용 간격(86400초 등) 시계 기준 없음 |
| LuckyBagLimitedItemPossession | 33 (27 + 6) | 대상 ItemClass(적용 5) 보유 수 제한의 판정 범위(가방·창고·장착) 없음 |
| IsGiven + FinalReward(2) 상자 / Probability + FinalReward | 6 / 1 | FinalReward의 누적 횟수·주기 규칙 없음 |
| Life / ItemPossessionAppellationID / ConsumeTerritoryClassID 등 | 3 / 1 / 1 | 획득 후 수명 기준·호칭 보유 조건·영역 소비 규칙 없음 |
| SelectReward RewardGetTimeTypeID 3 | 3 | 수령 시점 종류 3의 의미 없음 |
| 선택 상자 중 테스트 선택지 포함 | 4 | #373971·#373981·#374468·#374678 |

- 참고: 이미 "사용 가능"이던 LuckyBag 9,316종 중 2,327종, SelectReward 3,149종 중 471종은(이번 연결 전에는 2,350·801종) 보상(또는 선택지) 일부가
  지급 소유자 없는 소모품(다른 상자 1,609행·특수 주문서 762·물약 714·강화 주문서 695·재료 604·축복 포인트 515·시간 충전석 407 등)이다.
  확률 상자는 열면 보존, 선택 상자는 그 선택지만 거부된다. 이 소모품들이 연결될수록 함께 풀린다.
