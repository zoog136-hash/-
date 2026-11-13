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
| **ElementalResistance / ElementalDamage** | 90 / 46 | **연결(아래 14)** — 적용 3 ElementalResistanceType 대상 = ElementalType 행(Fire/Water/Air/Earth/All) |
| **EquipGroupID** | 78 | **연결(아래 14)** — 세트 효과가 아니라 EquipSlotConfig의 같은 그룹 중복 착용 제한(MaxDuplicationPerEquipGroup) |
| KarmaDeath / KarmaLife | 48 / 58 | KarmaDeath는 사망 소유자가 읽음, KarmaLife는 소비자 없음 |
| Fishing* (Power·ExpAmplifier 등 5종) | 55 | 미연결 — 낚시 소유자가 낚싯대 장비 행을 읽지 않음 |
| IgnoreFarBarrior / StorableOnEnchant / FixedDesc | 46 / 45 / 45 | 소비자 없음(설명·창고 규칙) |
| 그 밖의 소수 효과(치명타·관통·리덕션 비율 등 40여 종) | 각 1~35 | 강화 투영과 같은 필드가 있는 21종 **연결(아래 14)**, 나머지는 14.4 |

## 2-1. 아이템 등급 연출 — 아이콘·바닥 빛기둥·이름 색 (2026-11-12, PR `feature/equipment523-grade-presentation`)

사용자 우선순위(2026-11-12): 신화 이상 장비 아이콘 연출 → 바닥 아이템(빛기둥 포함, 전 등급) → 이름·등급 색 → 착용 외형.
모두 원본 표·원본 리소스에서만 가져오고, 없으면 비워 둔다(이미지 생성·대체 없음).

### 근거 (원본 523 표·리소스)

| 등급(Grade) | 이름(DescID) | 이름 색 Grade.ColorID → ColorTable | 바닥 이펙트 Grade.DropItemEffectSpriteID | SPR 선언 |
| --- | --- | --- | --- | --- |
| Grade1 | 일반 | 4 GradeCommon `ffffff` | 0 (없음) | — |
| Grade2 | 고급 | 5 GradeRare `00dc15` | 0 (없음) | — |
| Grade3 | 희귀 | 6 GradeUnique `00a2ff` | 23195 | `Effect_Drop_Item_Rare_upper_sc` + under 23196 |
| Grade4 | 영웅 | 7 GradeLegend `ff0000` | 23197 | `Effect_Drop_Item_Hero_upper_sc` + 23198·23199 |
| Grade5 | 전설 | 8 GradeEpic `d44fff` | 23200 | `Effect_Drop_Item_Legend_upper_sc` + 23201·23202 |
| Grade6 (ID 32) | 신화 | 412 Grade6 `ffde00` | 23203 | `Effect_Drop_Item_Myth_upper_sc` + 23204·23205 |
| Grade7 (ID 52) | 유일 | 21212 Grade7 `18f4b0` | 23206 | `Effect_Drop_Item_Sole_upper_sc` + 23207·23208 |
| BM (ID 42) | 특수 | 422 Bm `ff7522` | 0 (없음) | — |
| Event (ID 71) | 이벤트 | 422 Bm `ff7522` | 0 (없음) | — |

- ColorID는 Color 표가 아니라 ColorTable 표의 ID다(ColorTable 이름이 GradeCommon…Grade7로 등급과 일치, Color 표의 같은 번호는
  귓속말 색). 기존 칭호 색(`title_source523.gd`)도 ColorTable을 쓴다. "일반"은 None(ID 0)과 Grade1 두 행이 같은 이름이라
  아이템 정보에 보이는 행(IsItemInfoVisible=true, Grade1)을 쓴다.
- 아이템별 예외: UIItemDropEffect 6행(#162121 → 23206, #255878·255888·255898·255908·315962 → 23203)이 등급 이펙트보다 우선.
  ItemDropEffectInvisible은 ItemClassID 0 한 행뿐(해당 아이템 없음).
- 바닥 이펙트는 각 스프라이트의 SPR 선언 action 3 `breath`(12프레임, body + clothes 레이어). 은행(bank) 계약은 반복을 호출자
  정책으로 남기므로, 바닥에 놓여 있는 동안 idle 동작 `breath`를 반복 재생한다(TWILIGHT 해석으로 표기).
- 신화 이상 아이콘 연출 = IconID가 가리키는 AssetType 101 CSB(`UI/CsbFile/icon/Fx_Item_*_Myth_*.csb` 등). 클라이언트 공통 아이콘
  설정 루틴(0x00C381A0)이 슬롯 Sprite에 CSB를 붙이고 `timeline.play("normal", true)`(0x00C386B1) — 아이콘 선택 문서의
  policy_source에 이미 기록된 근거.

### 등급별 아이템 수 (TestItem=false)

| 등급 | 장비 | 전체 | CSB 애니메이션 아이콘(장비 / 전체) | 바닥 이펙트 |
| --- | ---: | ---: | ---: | --- |
| 일반 | 406 | 6,291 | 0 / 1 | 원본 없음 |
| 고급 | 338 | 1,060 | 0 / 0 | 원본 없음 |
| 희귀 | 714 | 2,344 | 0 / 0 | 23195 |
| 영웅 | 407 | 2,241 | 0 / 0 | 23197 |
| 전설 | 411 | 1,781 | 0 / 0 | 23200 |
| 신화 | 107 | 325 | 104 / 206 | 23203 |
| 유일 | 24 | 60 | 24 / 50 | 23206 |
| 특수(BM) | 547 | 16,295 | 0 / 205 | 원본 없음 |
| 이벤트 | 0 | 1 | 0 / 0 | 원본 없음 |

CSB 아이콘은 선택 문서에 모두 묶여 있다(누락 0, 신화 장비 3종은 원본이 정지 PNG 아이콘).

### 연결 (실제 Main 확인, 로컬 스크린샷 — 커밋 안 함)

- **신화·유일 CSB 아이콘이 원본 인벤토리에서 안 돌던 원인**: 원본 인벤토리 슬롯(`Common_Slot.csb` Sp_IconSample)이 CSB를 받으려면
  선택 문서에 슬롯별 `native_registrations`가 있어야 했는데, 문서는 공통 아이콘 설정 근거만 담고 있어 "registration pending"으로
  거부됐다. 그 결과 신화 아이템 하나만 있어도 **원본 인벤토리 전체가 TWILIGHT 가방으로 되돌아갔다**(수정 전 스크린샷).
  수정: 슬롯 Sprite가 원본 UI 장면에 선언되어 있고(기존 PNG 아이콘이 들어가는 그 노드) 선택 문서의 policy_source가 공통 아이콘
  설정 근거를 담은 경우, 그 근거로 등록을 만든다(맞춤·크기·오프셋 추가 없음, clip `normal` 반복은 문서 값 그대로).
- **바닥 빛기둥**: 원본 523 아이템의 TWILIGHT 자체 그림(원기둥·입자·바닥 원) 대신 위 표의 원본 스프라이트를 재생. 일반·고급·특수·
  이벤트는 원본에 이펙트가 없어 아무것도 그리지 않는다.
- **바닥 이름 라벨**: 원본 아이템 이름(IdentifiedDescID/DescID, 내부 식별 접미사 "· 원본#ID" 없이)을 원본 등급 색으로 표시.
- **이름 색**: 가방 상세·이름 힌트·줍기 안내·RenewalTheme.grade(상점·보상 등 32곳)가 위 ColorTable 색을 쓴다. 원본 표가
  설치되지 않은 경우에만 기존 TWILIGHT 팔레트.
- **바닥 몸체(ItemClass.SpriteID)**: 장비 2,907종 중 정적 그림 2,839종(기존 연결). 이번에 정적 그림이 없고 SPR이 action 3을
  선언한 몸체(가이아의 격노 14440, 블레이드 78xx 등 24종)를 그 action 3으로 재생.

### 표·리소스에 없어 남긴 것

- 바닥 몸체 44종: action 0 `fly`만 있는 화살·스팅(66·2989, 14종)은 비행 동작이라 바닥 역할이 아님; 원본 클라이언트에 파일이 없는
  멤버 22종(2910 dark claw·17 gem 등); 원본 선언이 dummy인 8종. 비워 두고 "원본 지면 표시 대기".
- 등급 슬롯 테두리: `Common_Slot_Grade.csb`(Item_Common·Rare·Unique·Legend·Epic·Myth·BM 노드, 같은 Com_Img_SlotGrade 그림에 노드
  색만 다름)가 있지만 인벤토리 슬롯 `Common_Slot.csb`는 이 장면을 포함하지 않고, 어떤 화면이 어떤 노드를 켜는지 표에 없다.
  또 유일(Grade7)용 노드가 없다. 연결하지 않음.
- 바닥 이름 라벨의 글꼴 크기·외곽선·위치, 강화 수치 "+N " 접두 규칙은 원본 표에 없어 TWILIGHT 값.
- 빛기둥 반복: 은행 계약상 loop는 호출자 정책 — 위의 해석(바닥에 있는 동안 breath 반복).

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

## 12. 소모품 2~5단계 — 시간 충전석·강화 주문서·카드 재뽑기·축복 포인트 (2026-11-12, 같은 PR)

### 12.1 축복 포인트 충전 — **가방 사용 연결 91종** (IntangibleItemRecharger 102종 중)

- 근거: ItemBonus IntangibleItemClassID(Unit IntangibleItemClassID) → IntangibleItemClass 14 "BlessPoint",
  IntangibleItemAmount(Unit Value) N. 아이템 자신의 원본 설명 "사용 시 축복 포인트 N 획득"과 같은 값일 때만 연결
  (101종 모두 일치). 그 밖의 행은 DeleteTime(기존 기간 규칙)·CannotExtendDeleteTime만 허용.
- 연결: 물리 개체 1개 차감 + 기존 문양(growth) 축복 포인트 `points` +N(장부 `economy.recharged`)을 한 번에 저장
  (`current523_native_stack.use_bless_points`). 포인트 상한은 원본 표에 없고 기존 문양 상태에도 없다.
- 문양 소유자와의 경계: 기간(DeleteTime) 행이 없는 10종(#117304 등)은 기존 문양 소유자(`symbol_source523`)가 자기 재료 기록으로
  카탈로그에 올리고 문양 화면에서 충전한다(이미 사용 가능, 퀘스트 보상 연결도 이 기록). 그 기록을 그대로 두므로 이 10종은 계속 문양 화면 경로다.
  기간 행이 있는 91종은 문양 소유자가 "기간 조건을 버릴 수 없음"으로 받지 않던 것이라, 이번에 원본 물리 수량 경로(기존 기간 규칙 적용)로 연결했다.
- 남은 1종: IntangibleItemClass 2 "Gem"(다이아) 충전 — 사용자 결정(패키지 내 다이아 미지급)과 같은 이유로 연결하지 않음.
- 실제 Main·원본 팩(`tests/items523_bless_points_test.gd`): #168024 [이벤트] 축복의 성수(대) 3개 → 1개 사용 시 포인트 +1000,
  2개째 +2000 → 저장→다시 불러오기 후 포인트·남은 1개 유지 → 다시 사용 가능. #117304는 문양 재료 기록 그대로.

### 12.2 시간 충전석 (LandTimeRecharger 327종) — 미연결

- 행: RechargeLandTimeLimitGroupID → LandTimeLimitGroup(TimeLimit·MaxRechargeTime·ContentsResetScheduleTypeID), RechargeTime(초, 대부분 3600).
- 표에 없는 것: MaxRechargeTime이 "초기화 주기당 충전 가능한 총량"인지 "남은 시간의 상한"인지(설명 문구·다른 표 모두 없음).
  충전 시점이 초기화(Daily/WeeklyWed 등) 전후로 걸칠 때의 처리도 없다.
- 게임 쪽: 기존 시간 풀(`current523_map_time_pool`, 정책 `OWN_BOUNDED_SOURCE_LIMIT_NO_AUTO_RESET_V1`)은 초기화가 없고,
  기본 개방 정책에서는 시간 제한 자체가 꺼져 있다. 충전 대상 시간이 소비되지 않으므로 사용해도 결과가 없다 → 아이템 보존.

### 12.3 강화 주문서 (ScrollEnchant 181종: EnchantScrollGroupID 157 + ByBlessCode 23 + 행 없음 1) — 미연결

- 있는 표: ItemEnchantScrollGroup(→ 확률 종류), ItemEnchantScrollGroupMapping(→ ItemEnchantProbabilityGroup),
  ItemEnchantProbabilityView(단계별 `IsUnbrokenEnchant`·ServerLimitSetID만), ItemEnchantCostView(Cost·ConsumeAmount),
  ItemBlessEnchantProbability(축복 주문서 도약 1/2/3단계 확률).
- 표에 없는 것: **단계별 성공 확률**(ProbabilityView에 확률 열이 없음 — 서버 값), 실패 시 결과(증발/유지/하락)의 단계별 규칙
  (`IsUnbrokenEnchant` 0인 단계의 실패 처리), Cost의 화폐 종류. 성공률 없이 강화를 실행할 수 없어 전부 보존.
  (기존 TWILIGHT 강화 규칙의 자체 확률을 원본 주문서에 붙이면 표 규칙이 아니므로 하지 않음.)

### 12.4 카드 재뽑기 (ScrollBuffCardRetry 222 + ScrollBuffCardAwakenRetry 34 = 256종) — 미연결

| 묶음 | 수 | 표에 있는 것 / 없는 것 |
| --- | ---: | --- |
| 미스터리 카드 (ScrollBuffCardRetry, BuffDeckID + GradeID, "희귀 합성을 통해 영웅 … 실패 시 희귀 1종") | 107 | BuffCardRuleMergeView에 덱·등급별 `MysterySuccessProbability`(희귀 10000 등)와 SuccessGradeID는 있다. **결과 등급 안에서 어떤 카드가 나오는지의 카드별 가중치가 없다**(BuffCard에 확률 열 없음, GotChaEntityView는 상점 뽑기 상품용). 기존 몬스터 도감 미스터리 경로는 TWILIGHT 자체 확률 설정을 쓰므로 원본 규칙이 아님 |
| 옵션 각성 티켓 (ScrollBuffCardAwakenRetry, BuffDeckID + GradeID) | 12 | "보유 중인 영웅 변신 1종을 선택해 옵션 각성 확정" — 확정 각성 결과(어떤 옵션 값)가 표에 없음 |
| TJ 쿠폰 (PlayerValueReturn: 합성 115 + 각성 22) | 137 | 별도 소유자 `scripts/tj`(TJ 쿠폰 화면)가 합성 실패 이력·시즌·서버 조건으로 처리한다. 가방 사용 경로가 아니라 그 화면에서 쓰는 아이템이며, 원본(523) 물리 수량 개체와 TJ 화면의 연결은 이번 범위 밖 |

### 12.5 집계 (실제 원본 팩, 대상 카테고리 비테스트 14,887종 `profile` 기준)

| 묶음 | 이전 사용 가능 | 이후 사용 가능 | 남은 거부 |
| --- | ---: | ---: | ---: |
| 상자(LuckyBag·SelectReward·ComplexReward) | 12,465 | 12,736 | 1,285 |
| 시간 충전석 | 0 | 0 | 327 |
| 강화 주문서 | 0 | 0 | 181 |
| 카드 재뽑기 | 0 | 0 | 256 |
| 축복 포인트 | 10 (문양 화면) | 101 (가방 91 + 문양 화면 10) | 1 (Gem) |

- 연쇄 효과: 축복 포인트 91종이 지급 가능해지면서, 보상 일부가 지급 불가라 열면 보존되던 기존 상자 2,327 → 약 2,148종,
  선택지 일부가 막힌 SelectReward 471 → 약 397종으로 줄었다(문양 재료 기록을 쓰는 10종 #117304 등을 담은 상자는
  카탈로그 기록이 문양 쪽이라 여전히 보존될 수 있어 "약"으로 적음).

## 13. 장비 강화 원본 연결 — 강화 표가 원본 장비를 하나도 못 잡던 문제 (2026-11-12, PR `feature/equipment523-enchant-bonus`)

### 13.1 원인 (실제 Main 측정)

- 개별 ID 측정(장비 2,954종, 원본 팩)에서 강화 규칙 모델(`world.patch523_equipment`)에 **원본 장비가 0종** 들어 있었다
  (모델 아이템 25,716종은 전부 비장비, `equipment_runtime` 비어 있음). 그래서
  - 강화 단계 효과(ItemEnchantBonus, 2,681종·79,794행)는 투영의 좁은 목록(`current523_native_item_projection.enchant_stats`,
    Value 단위 20여 종)만 적용되고, 강화 발동·추가 옵션(관통·치명·리덕션 비율·내성 등)은 0;
  - 강화 주문서 규칙(EnchantEquipGroupID 1,893종)은 원본 확률·비용 대신 기존 TWILIGHT 기본 규칙.
- 원인: `patch523_rules_projection._bind_catalog`가 기록의 `source_class_ids`/`source_equip_slot_ids`(표 JSON에서 온 실수 `8.0`)를
  표에서 만든 정수 배열(`8`)과 `!=`로 비교 — Godot 배열 비교는 형이 엄격해 장비(슬롯·직업 ID가 있는 아이템)만 전부 탈락
  (#411과 같은 '실수 vs 정수' 유형). 비장비는 둘 다 빈 배열이라 통과했다.
- 수정: `_sorted_ids()`가 정수인 실수를 int로 바꿔 비교. 같은 원인으로 막혀 있던 장비 제작법도 함께 들어온다(모델 제작법
  288 → 1,006).

### 13.2 강화 발동 주문(Attack_Spell)·고정 반격(61)

- 강화 단계 InvokeOption 중 type 1 Attack_Spell(703종·10,651행)은 현재 523 경로가 항상 버렸다(예전 공개 컴파일러
  `tools/equipment/patch523_native_spells.py`는 만들던 `equipment_spell_profiles`를 현재 경로가 만들지 않음). 기존 실행기
  (`skill_service.execute_equipment_source_spell`, `patch523_equipment_spells`)는 그대로 있다.
- 새 `scripts/crafting/current523_equipment_spell_profiles.gd`가 같은 조건으로 SpellClass/SpellBonus/BuffClass/BuffBonus에서
  프로필을 만든다: 순수 피해 주사위(26 주문) 또는 순수 능력치·홀드 디버프(75 주문)만. 101/166 주문, **615종** 연결.
  type 61 Defence_FixedDamageCounterBarrier(2종)도 예전 조건 그대로.
- 남은 주문 65개(88종): 중첩 디버프(악마왕·나이트발드 등 시리즈, BuffClass가 중첩/버프 그룹), 버프 제거(이레이즈 이뮨·이지스
  브레이크: SpellBuffGroup), HP 비례 피해(루인 크래시: SpellDamagePercentByHP), 무기 기반 피해(확률 추타: SpellWeaponBasedDamage),
  후속 주문(어비스 웨이브: NextSpellClassID), 턴 언데드 부작용(SideEffect*), 흡혈(SpellDrainHP), 침묵(SpecialResistanceTypeID) —
  기존 실행기에 그 효과의 계산 단계가 없고 표에도 순서가 없어 미연결.
- 남은 강화 발동 종류: Defence_Spell(2, 32종), Aura_Spell(38, 26종), Defence_DebuffTimeDecrease(26, 1종), Gain_Experience(68, 1종) —
  방어 측·오라 주문 실행 규칙 없음.

### 13.3 측정 (실제 Main, 원본 팩, 장비 2,954종 개별 ID)

| 열 | 수정 전 (main) | 수정 후 |
| --- | ---: | ---: |
| 강화 규칙 모델에 들어간 장비 | 0 | 2,954 |
| 강화 단계 효과 행 연결 (ItemEnchantBonus) | 0 / 79,794 | 72,701 / 79,794 |
| 원본 강화 주문서 규칙(EnchantEquipGroupID, +0 성공 확률 > 0) | 0 / 1,893 | 1,848 / 1,893 |
| 강화 발동 주문 / 고정 반격 | 0 / 0 | 615 / 2 |
| 모든 효과 행이 소비되는 장비 | 135 | 2,104 |

- 강화 규칙이 남은 45종: 주문서 그룹이 없는 장비 24종(장비 강화 그룹 ↔ 주문서 그룹 매핑 없음), 원본 단계·확률·비용 행이 없는
  19종, 인장 전용 보호 주문서 2종.
- 남은 강화 행 7,093행: 위 13.2 발동 주문, 원소 피해(ElementalDamage, 속성 대상 해석이 TWILIGHT 설정 의존), 치명 저항·유형별
  피해 감소 비율(소비자 없음), 상태 효과(StatusEffectID), 원소 치명 저항, 무시 비율(Ignore*DamageReductionPercent), 마법 방어 관통
  (PierceMagicShieldPercent) — 계산 위치가 표에 없음.

## 지급 불가 재측정과 보관용(storage) 물리 수량 연결 (2026-11-13, PR `feature/items523-grantable`)

### 측정 방법 (실제 Main, 원본 팩, main `735b771f`)

- 원본 ItemClass **34,743행 전부**를 실제 Main에 들어간 상태에서 공용 지급 경로
  `patch523_item_inventory.stage()`(드롭·보상·상점 지급이 쓰는 것)에 1개·일반 축복·강화 0으로 넣고, 결과와
  거부 문구를 행마다 기록했다(로컬 측정, 커밋 안 함). 이전 집계(5,433종)는 `supply_profile` 유무로 센 것이고,
  이번은 실제 지급 결과다.
- 제외(지급 대상 아님, 그대로 둠): `TestItem=true` **4,345행**, 원본 더미 선언(`[더미]`·테스트용 더미1~3) **3행**.
  GM 표시 행은 원본 이름·표에 없다(0행).
- 대상: 나머지 **30,395종**.

### 결과

| | 이전(main) | 이후(이 PR) |
| --- | ---: | ---: |
| 지급 가능 | 25,445 | **30,249** |
| 지급 불가 | 4,950 | **146** |

- 새로 지급 가능해진 4,804종은 모두 새 공급 종류 `storage`(보관용)다. 이전에 지급되던 아이템 중 지급 불가가 된 것은 0종.
- 아이콘: 새로 지급되는 4,804종 중 **4,553종은 자기 원본 IconID 그림**(`original_linked`)으로 가방에 보인다.
  **251종은 IconID는 있으나 그 그림이 설치된 원본 팩에 없음**(`original_icon_not_installed`, 서로 다른 IconID 46개:
  카드 재뽑기 115 · 아이템 복구 주문서 55 · 스킬북 25 · 각성 재뽑기 22 등) — 빈칸으로 두었고 그림을 만들거나 대체하지 않았다.

### 연결 규칙 (`current523_native_stack.storage_profile`)

표가 아이템을 완전히 정의하면(정확한 원본 투영 DTO, `TestItem=false`, 더미·테스트 표시 없음, 보류 조건 없음,
삭제 시간 해석됨) 장비가 아닌 아이템(consumable·material·currency 슬롯)을 영수증 있는 물리 수량으로 받는다.
- 사용(효과)은 지어내지 않는다. 사용 소유자가 없는 보관용 아이템을 쓰면 "원본 표에 이 아이템의 사용 규칙이 없거나
  아직 연결되지 않았습니다 · 보관용 · 아이템 보존"으로 거부되고 수량은 그대로다.
- 창고·바닥 버리기·저장/불러오기·소지 수량 검증은 기존 물리 수량 경로를 그대로 쓴다.
- 기존 지갑(아데나, 변신·마법인형·성물 제작 코인, 명예 코인)은 보관용으로 바꾸지 않는다(기존 소유자 유지).
- 현금 상점 상자 구성품(`source523_cash_packages`)은 보관용 아이템을 지금처럼 기존 일반 구성품 기록으로 준다(저장된
  상자 구성품 기록 호환). 뽑기권(`source523_inventory_tickets`)의 스킬북 후보도 보관용이면 지금처럼 "없음"으로 센다
  (배울 수 없는 스킬북을 뽑기 결과로 주지 않음).

### 묶음별 (ItemCategory, 지급 가능 이전 → 이후 / 전체)

| 묶음 | 이전 | 이후 | 전체 | 비고 |
| --- | ---: | ---: | ---: | --- |
| LuckyBag | 9,586 | 10,685 | 10,686 | 열기 규칙 없는 상자도 보관 가능(열면 기존 사유로 거부·보존) |
| StackableItem(제작 입력 없는 재료) | 1,276 | 1,854 | 1,857 | |
| Potion | 151 | 524 | 526 | |
| LandTimeRecharger(시간 충전석) | 0 | 327 | 327 | 충전 규칙(12.2)은 여전히 미연결 — 보관만 |
| ScrollBuffCardRetry(카드 재뽑기) | 0 | 222 | 222 | 12.4 규칙 미연결 — 보관만 |
| BuffCardDrawer | 2,040 | 2,225 | 2,245 | |
| Emblem | 14 | 206 | 211 | |
| Currency | 1 | 187 | 194 | 지갑 3종 제외 |
| ScrollEnchant | 0 | 181 | 181 | 12.3 규칙 미연결 — 보관만 |
| SelectReward | 3,149 | 3,329 | 3,329 | |
| ScrollTeleportDungeon / ScrollTeleport | 0 / 5 | 168 / 108 | 168 / 108 | 이동 실행 미연결 — 보관만 |
| ScrollSpecial / Scroll / ScrollQuest | 70 / 40 / 0 | 232 / 139 / 138 | 232 / 143 / 138 | |
| NonstackBuffCoin / ScrollElementalEnchant / QuestFreePass / ScrollItemReturn | 12 / 0 / 0 / 0 | 119 / 88 / 66 / 55 | 123 / 88 / 66 / 55 | |
| 그 밖 30여 묶음(SummonStick·ScrollSpell·InfinityGear·TeleportAmulet·ScrollSmelt 등) | | | | 남은 것은 아래 표 |

- 참고: 이름에 `[혈맹` 이 있는 행 140종, `미사용`·`사용안함` 표시가 있는 행 51종도 표가 정의하므로 보관용으로 받는다
  (테스트 표시가 아니어서 제외하지 않음).
- TJ 쿠폰(PlayerValueReturn) 일부가 보관용으로 가방에 들어올 수 있다. TJ 화면은 자체 쿠폰 기록을 쓰므로 가방의 원본
  쿠폰과 합치지 않는다(이중 소유 없음, 연결은 범위 밖 — 10절 표 유지).

### 남은 지급 불가 146종 (사유 · 수 · 예)

| 사유 | 수 | 예 | 처리 |
| --- | ---: | --- | --- |
| 원본 투영 DTO 없음(`missing_current_native_record_projection`) | 64 | Arrow 29(#2712 무형화살, #123392 다크 블레이드 등 스킬 발사체), 이름이 숫자인 None 행 32(#161762 "161732") | 가방 아이템이 아닌 발사체·내부 행으로 보이며 표에 아이템 정의가 부족 — 연결 안 함 |
| 이름에 테스트 표시(`[테스트]`·`테스트용`·`test용` 등, `TestItem=false`) | 49 | #122554 [테스트] 버프 아이템 지급, #140954~ [테스트-임시] 마법서 18종, #255643 용옥 - test용 | 테스트 행으로 보고 제외 |
| 삭제 시간 해석 불가(`source_delete_time_unresolved`) | 14 | #180761 [이벤트] 아인하사드의 마법 주문서(원거리) -03/31삭제 등 | 기간 규칙이 표에 없어 보존(기존 규칙) |
| 원본 공급 카탈로그 미등록(다른 소유자 기록) | 11 | #117284~ 축복의 성수 10종(문양 소유자 재료), #231772 문양 초기화 두루마리 | 문양 쪽 자체 기록 — 12.1과 같음 |
| 각성 공급 정의 미등록 | 5 | #3252 마법인형 제작 코인, #346921 아우라키아의 상자, #365748 에바의 계시 | 각성 공급자(`native_awakening_supply`) 쪽 카탈로그 미등록 — 보관용으로 바꾸지 않음 |
| 기존 지갑 | 3 | #3242 변신 제작 코인, #3631 명예 코인, #246058 성물 제작 코인 | 지갑 소유자 결정 필요(아래) |

### 표 해석 정정 — CurrencyUnitClass `ForGive`

6절에서 "ForGive false = 보상 지급 불가가 표 값"으로 적었으나, 같은 값이 #3581 축복 부여 주문서, #147672 수호석,
#150303 금빛 훈장, 럭키백 상자 등 원본에서 보상으로 받는 아이템 141행에도 있다. 그래서 `ForGive`를 지급 차단 근거로
쓰지 않았다(의미는 표에 없음). 변신·마법인형·성물 제작 코인 지급 여부는 지갑 소유자 결정으로 남긴다.

### 사용자 결정 2026-11-13 적용 (PR `feature/items523-grantable-decisions`)

1. **제작 코인·명예 코인 보상 지급**: 원본 보상 행의 #3242 변신 제작 코인 · #3252 마법인형 제작 코인 · #3631 명예 코인 ·
   #246058 성물 제작 코인을 기존 코인 지갑(가방 수량 키 = 지갑 이름, 탐험 보상이 이미 쓰는 지갑)에 더한다
   (`patch523_item_inventory.coin_wallet`). 원본 행이 TestItem false · Currency(122) · 등급 1 · 이름이 그 지갑일 때만,
   일반 축복·강화 0만 받는다. 물리 영수증 개체는 만들지 않는다. 불멸·파멸의 가호 화면 안내문도 "원본 #3631 보상은 이
   지갑에 더함"으로 바꿨다. 몬스터 드롭 연결은 바꾸지 않았다(보상 행만).
2. **"미사용"·"사용안함"(·"사용 안함") 이름 51종 제외**: 테스트 표시와 같이 보관용 지급에서 뺀다
   (`storage_exclusion` → `source_unused_name_marker`). 이 표시가 있어도 이미 사용 소유자가 있어 지급되던 아이템(상자·장비 등)은
   그대로다. 이름에 `[혈맹` 이 있는 140종은 보관용 그대로 둔다.
3. **TJ 쿠폰**: 가방에 들어온 원본 TJ 쿠폰(보관용 물리 수량)을 TJ 화면에서 쓴다. TJ 화면의 보유 수 = TJ 자체 쿠폰 기록 +
   같은 ItemClass의 가방 물리 수량(잠긴 것 제외)이며 목록에 "(가방 N)"으로 보인다. 한 번 쓸 때 정확히 한 장만 쓴다 —
   TJ 자체 기록이 있으면 그것을, 없으면 가방 한 장을 물리 차감(`stage_debit`)해 결과·이력 사용과 **같은 저장**으로 기록한다.
   가방 쿠폰을 TJ 기록으로 복사하지 않으므로 중복 지급이 없고, TJ 저장 형식(`tj_coupons523`)은 바뀌지 않는다(저장 호환).
   가방에서 그 쿠폰을 직접 쓰면 지금처럼 보관용 거부·보존이다.

측정(실제 Main·원본 팩, 같은 방법): 대상 30,395종 중 지급 가능 **30,249 → 30,202**(코인 +4, 미사용·사용안함 −51),
지급 불가 **146 → 193**(이름 미사용 표시 51 추가, 지갑 3·각성 공급 1 해소). 남은 사유는 위 표에서 지갑 3행이 빠지고
"각성 공급 정의 미등록"이 4종(#346921·#365748·#365758·#370562)이 된 것 외에 같다.
확인: `items523_storage_items_test` 39/0(코인 4종 지급·저장·불러오기, 미사용 거부), `items523_tj_bag_coupon_test` 15/0(가방 쿠폰
2장 → TJ 보유 2 · 실제 실패 합성 이력으로 재도전 성공 · 가방 1장만 차감 · TJ 기록 0 유지 · 같은 이력 재사용 거부 · 불러오기 후
가방 1·영수증 1).

## 14. 장비 남은 효과 — 기본 행 유형 효과·속성·장착 그룹 (2026-11-13, PR `feature/equipment523-rest`)

### 14.1 다시 잰 출발점 (origin/main `735b771f`, 원본 팩, 장비 2,954종 개별 ID)

- 수치는 #429 측정과 같다: 기본 효과 행 17,536 / 18,710, 모든 효과가 소비되는 장비 2,104 / 2,954, 강화 행 72,701 / 79,794.
- **집계 방식 보정 2건**(코드 변경 없이 판정만): (1) 강화 추가 옵션 중 "읽는 곳 없음"으로 센 키(치명 저항 `melee/ranged_critical_resistance`,
  유형별 감소 `*_damage_reduction_pct`, `source_elemental_flat_*`, 유형별·PVP·공포 리덕션 무시, PVP 스킬 성공 레벨)는 모두 이미 읽는 곳이
  있다(`_critical_resistance_stat`, `_pve_reduction_percent`, `_source_elemental_flat_damage`, `patch523_equipment_combat.source_integer`);
  (2) 기본 행 FinalBlowProbability/FinalBlowAdditionalScale은 `patch523_final_blow.base`가 표에서 직접 읽는다. 보정하면 출발점은
  기본 행 17,538 · 모든 효과 2,137종.
- **RegenHP 225 / RegenMP 381 / AttackDrainHP 71 / AttackDrainMP 51은 이미 동작 중**(`patch523_passive_items`, 측정의 passives 열 537종).
  이번 테스트에서 실제 Main으로 다시 확인: #513 RegenHP 4 → 30초 틱 HP 842→846, #425 AttackDrainHP 1 → 일반 명중 1 흡수.

### 14.2 연결한 것

| 원본 효과(BonusType) | 종 / 행 | 근거 | 기록 필드 → 읽는 곳 |
| --- | ---: | --- | --- |
| ElementalResistance | 90 / 90 | 적용 3 `ElementalResistanceType`, 대상 = ElementalType ID(Fire·Water·Air·Earth, 5 All = 네 속성), Percentage ÷ UIUnit 10000 (500000 → 50) | `element_resist_fire/water/wind/earth` → `_player_element_resistance` (NPC 주문 경로가 쓰는 같은 이름 대응 Air→wind) |
| ElementalDamage | 46 / 46 | 같은 적용·대상, Value | 강화와 같은 `source_elemental_flat_<속성>` → `_source_elemental_flat_damage` (일반 명중, 대상 속성 저항 적용) |
| 치명·치명 저항·치명 대미지 | 13+17+2 / 2+4 / 4+2+2 | MeleeCritical 등 ValuePercent(분모 1), *CriticalResist Percentage ÷10000, Critical*Damage Value | `melee/ranged/magic_crit`, `*_critical_resistance`, `*_critical_damage` |
| 리덕션 %·관통 | PVE/DamageReductionPercent 12, MagicDamageReductionPercent 6, PierceDamageReductionPercent 10, PierceDamageReduction 23 | Percentage ÷10000 / Value | 강화 투영(EXTRA)과 같은 `pve_damage_reduction_pct`, `magic_damage_reduction_pct`, `damage_amp_pct`, `damage_reduction_ignore` |
| 그 밖 | RangeEvasion 8, ElementalDamageReduction 6, CastSpeedBonus 6, PoisonDamageReductionPercent 2, Strength/Dexterity/IntelligenceScale 2씩, UndeadAdditionalMaxDamage 3 | 같은 단위 규칙 | `er`, `equipment523_element_reduction`, `castSpeed`, `dot_damage_reduction_pct`, `str/dex/intPercent`, `source_undead_damage_max` |
| **EquipGroupID** | 78 / 94 | EquipSlotConfig(EquipSlotID, ServerLimitSetID 0)의 MaxDuplicationPerItemClassID / MaxDuplicationPerEquipGroup — Ear 1/1, Finger 2/2, Badge 1/2 | `source_equip_group_ids` → 착용 시 `current523_equip_group_limit` (귀걸이·반지·인장 두 칸). 그룹 ID가 하나라도 같으면 같은 계열(수령의 귀걸이 [128,148] ↔ 에바의 귀걸이 [128,138]) |

- 같은 의미의 행만 옮겼다: 강화 투영(`patch523_enchantment_projection` EXTRA)이 같은 BonusType에 이미 쓰는 필드와 단위를 그대로 쓴다.
  행의 해석(적용 순서·상한·반올림)은 각 소비자의 기존 규칙이다(속성 저항 = 피해 % 감소 −80~85 범위, 치명 저항 상한 50, 리덕션 % 상한 90).
- 장착 그룹: 새로 착용할 때만 검사한다. 같은 칸을 갈아 끼우는 것은 허용, 다른 칸에 같은 그룹/같은 아이템이 있으면 "같은 계열 장비는
  N개까지만 착용" 안내 후 가방에 보관. 이미 저장된 조합을 풀지는 않는다. 팔찌(원본 2칸)·룬(원본 1칸)은 TWILIGHT가 1칸이라 제한이 생기지 않는다.
- 실제 Main 테스트 `tests/items523_equipment_typed_effects_test.gd` 80검사 통과: #531 안타라스의 완력 땅 저항 0→50 / 저장·불러오기 50 / 해제 0,
  #179094 앨리스(양손검) 불 추가 피해 0→10, #96574 원거리 치명 2→3, #188054 근거리 치명 저항 0→5, #517 PVE 리덕션 0→1%, 귀걸이 #621
  착용 후 같은 그룹 78의 #622 거부·#621 두 번째 개체 거부·#622로 같은 칸 교체 허용·그룹 밖 #226892 허용·불러오기 후 둘 다 장착 유지.

### 14.3 측정 (실제 Main, 원본 팩, 장비 2,954종 개별 ID)

| 열 | 수정 전 (main, #429 집계 방식) | 수정 전 (보정 집계) | 수정 후 (보정 집계) |
| --- | ---: | ---: | ---: |
| 기본 효과 행 소비 (ItemBonus, 제외: 무기 부식·낚시) | 17,536 / 18,710 | 17,538 / 18,710 | **17,896 / 18,710** (+358) |
| 모든 효과 행이 소비되는 장비 | 2,104 / 2,954 | 2,137 / 2,954 | **2,273 / 2,954** (+136) |
| 강화 단계 효과 행 (ItemEnchantBonus) | 72,701 / 79,794 | 72,701 / 79,794 | 72,701 / 79,794 (변화 없음) |
| 강화 발동 주문 | 615 | 615 | 615 (14.5) |

- 같은 #429 집계 방식으로 수정 후를 세면 17,894 행 · 2,232종이다.
- 투영된 종 수(테스트 집계와 같음): 속성 저항 90 · 속성 피해 46 · 장착 그룹 78(94행) · 원거리 치명 17 · 근거리 치명 13 · 리덕션 무시 23 ·
  PVE/일반 리덕션 % 12 · 관통 % 10 · 원거리 회피 8 · 시전 속도 6 · 속성 리덕션 6 · 마법 리덕션 % 6 · 치명 대미지 8 · 치명 저항 6 ·
  언데드 추가 피해 3 · STR/DEX/INT % 2씩 · DOT 감소 2.

### 14.4 표에 없어 남긴 것 (기본 행)

| 효과 | 종 | 남긴 이유 |
| --- | ---: | --- |
| BuffClassID (장비 상시 버프) | 104 | 10.1 그대로 — 버프 안 효과의 소비자 없음 |
| KarmaLife / KarmaDeath | 58 / 48 | 카르마 수치를 생명력·사망 손실로 바꾸는 공식 없음(`death/runtime.gd`도 원본 공식 없음으로 보존) |
| ItemInvokeReplacementID | 48 | 10.2 그대로 — 교체 굴림 시점·소비 규칙 없음 |
| IgnoreFarBarrior | 46 | "원거리 장벽 무시" 대상이 될 장벽(몬스터/스킬 상태)이 TWILIGHT에 없음 |
| EnchantEquipGroupID(주문서 그룹 없음) / StorableOnEnchant / FixedDesc | 45 / 45 / 45 | 13.3 강화 규칙 미대응 45종, 창고 보관 강화 조건(온라인 창고 규칙), 설명 전용 |
| Life | 35 | Seconds 10800·36000 등 — 시계가 획득·착용·사용 중 언제 흐르는지 표에 없음(BM 유물·배지) |
| PierceMagicShieldPercent | 31 | 대상 마법 방패(`magic_shield_reduction_percent`)를 가진 몬스터가 없음; 반엘릭서만 같은 값을 씀 |
| ElementalCriticalProbability | 16 | 대상이 속성별(1~4)인데 기존 속성 치명 소비자(`equipment523_element_crit_pct`)는 속성 구분 없는 합 — 네 행을 합칠지 표에 없음 |
| Ignore*DamageReductionPercent / IgnorePVP* / PVPDamageReductionPercent / PiercePVPDamageReduction / PVPSpellByLevelAdditionLevel | 15+8+4+4+16+10+4+2 | 몬스터 쪽 % 리덕션 모델 없음, PVP 값은 강화 경로에서만 싱글 해석 정책으로 읽음(기본 행에 같은 정책을 넓히는 것은 사용자 결정 필요) |
| ReinforceSpellHitProbabilityBaseIncludingTransformSpell / DecreaseCasterSpellProb / IgnorePercentOfMoveSpeedDecrease | 20 / 8 / 16 | 주문 성공 확률·이동 감속 공식 단계가 표에 없음 |
| SpecialResistance (Ice·석화·Sleep·Dark) | 15 | 8절 그대로 — 해당 상태 없음 |
| EquipSpellClassID | 16 | 10.2 그대로 — 착용 시 주문 실행 |
| AlignmentWeaponDamageBonus / TargetDamageBonus | 11 / 2 | 성향 조건(값 −6000)·NpcGroup 11063 대상 추가 피해의 적용 소유자 없음 |
| Constitution/Wisdom/CharismaScale, HitSpecialResistanceScale | 2씩 | 기존 % 능력치 소비자는 STR/DEX/INT만 |
| 그 밖 1~7종(IncreaseNpcItemDropAmount, Einasad*, PolymorphSetID, InfiniteBuff, Vanish*, Teleport*, MaxEquipCount, ValidLand 등) | — | 소비자 없음 또는 온라인 기능 |

### 14.5 강화 발동 주문 65개 — 실행기 확장 안 함 (재확인)

실제 Main에서 `current523_equipment_spell_profiles.profile()`로 강화 Attack_Spell 166개를 다시 굴려 101 연결 / 65 미연결을 확인했다.
65개 모두 표만으로는 실행 단계가 정해지지 않는다:

- 중첩 디버프 9개(악마왕·나이트발드·오시리스·에보 시리즈 58942·58962·58972·58982, 사신 63074·63094·63114 등): BuffClass에 BuffBonus가
  없고 BuffStack/BuffStackBonus가 1~5중첩 값(PVP 리덕션 −1~−5, 스턴 내성 −1~−5%)을 준다. 발동 1회 = 1중첩인지, 중첩 시 지속 갱신인지 표에 없음.
- 버프 제거 16개(이레이즈 이뮨 투 함 SpellBuffGroup 192, 이지스 브레이크 SpellBuffGroup 5731 + CannotHaveBuffs 221): 몬스터 버프 그룹 모델이 없음.
- 무기 기반 피해 22개(확률 추타 200, 미티어 스트라이크(에이션트) 범위 4, 포세이돈의 분노 등: SpellWeaponBasedDamage + SpellAttackType):
  무기 피해를 어떻게 더하는지(무기 주사위·강화·추가 피해 포함 여부) 표에 없음. 미티어는 TargetAreaRadius 3~4 범위 주문.
- HP 비례 피해 3개(루인 크래시·루인 스피어: SpellDamagePercentByHP 2000, Min/MaxByHP, Type 14): 현재/최대 HP 기준·Type 14 의미 없음.
- 후속 주문 4개(어비스 웨이브 NextSpellClassID, 청사의 맹독): 후속 주문 연쇄 실행 규칙.
- 흡혈 2개(아이스 이럽션·데모닉 터치 SpellDrainHP 100000·80000): 피해 대비 흡수 단위·범위(데모닉 터치 반경 2) 처리 없음.
- 턴 언데드(2142): SideEffect* 부작용 버프 확률 규칙. 침묵 2개(1202·34483): CannotCastSpell 외 CannotChat·StatusEffectID 혼재 버프.
- 그 밖: 이자벨의 질투/시기(SuccessedBuffClassID 자기 버프 + 대상 DamageReduction 8행 중복), 복종의 맹세·붉은 오크 변신(PolymorphSetID 강제 변신),
  할파스 램페이지(자기 버프 그룹 확률 감소), 바포메트 커스(행동 불가 11종 + StatusEffectID).
- 남은 강화 발동 종류 Defence_Spell(2)·Aura_Spell(38)·Defence_DebuffTimeDecrease(26)·Gain_Experience(68)와 InvokeOption 3/5 중
  Param 조건이 0이 아닌 행(8+18종)은 13.2와 같다.
