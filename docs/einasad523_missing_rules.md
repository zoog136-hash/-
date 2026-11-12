# 아인하사드의 축복 (523) — 표에 없는 세부 규칙

원본 523 정의 표(EinasadLevel, EinasadBenefit, EinasadBenefitType,
EinasadVariable, LevelEinasadBlessRecharge, ItemConsumeRate, Bonus/BonusType,
BuffClass, DescData_Korean)로 **확정되는 것만** 구현했다
(`scripts/einasad/einasad523_rules.gd`, `scripts/ainhasad_service.gd`,
`scripts/loot/source523_item_effects.gd`). 아래는 표에 없어 지어내지 않고
거부·보존하거나 기존 TWILIGHT 값을 유지한 항목이다.

## 구현된 것 (표로 확정)

| 규칙 | 근거 행 | 동작 |
|---|---|---|
| 축복 단위 | EinasadVariable #42 = 6000 | 원본 값 ÷ 6000 = 화면 포인트 |
| 단계 구간 | EinasadLevel Level0/1/2 CumulativeValue 0 / 1,200,000 / 599,994,000 | 0 → 0단계, 1~200 → 1단계, 201~99999 → 2단계 (설명문 "1~200구간", "201~9999구간"과 일치) |
| 단계별 경험치·아데나 | EinasadBenefit (Unit Percentage, 100 기준) | 0단계 ×1/×1, 1단계 ×4/×1.5, 2단계 ×7/×2. 100 기준인 근거: 특별한 축복 버프(BuffClass 59142) 설명 "경험치 획득률 1000% / 아데나 획득률 200%" = 3단계 +900/+100 |
| 단계별 획득 제한 | EinasadBenefit GetItem DescID 155361 / 155371 | 0단계 "거래 불가 장비 획득 가능"(기존 각인 장비만 드롭), 1단계 이상 "모든 장비 및 아이템 획득 가능" |
| 드래곤의 보호 | BuffClass 54252 EinasadFixedLevel 1 | 축복 0이어도 1단계 혜택 (기존 타이머 유지) |
| 충전 상한 | EinasadLevel2 / 6000 = 99999, 아이템 EinasadBlessMaxNeturalRechargeValue 599,994,000 | 충전은 99999에서 멈춤 (저장된 더 큰 값은 지우지 않고 추가 충전만 막음) |
| 아이템 고정 충전 | EinasadBlessAbsolute ÷ 6000 (설명 "(충전량 : N)" 대조) | #549 드래곤의 다이아몬드 +100 등 (PR #392) |
| 드래곤의 비약 레벨 충전 | Bonus LevelEinasadBlessRecharge(Unit ItemConsumeRateGourpID) → ItemConsumeRate 그룹 31/43 | 캐릭터 레벨의 Value 포인트 충전 (예: 60레벨 725, 84레벨 1950). 설명 "({0} 레벨 충전량 : {1})" |
| 소모 감소 | EinasadSavingPercent (카드 덱·인챈트·각성 등) | 기존 `_blessing_consumption_reduction_percent()`로 처치당 소모량에 적용 (카드 덱 #397 포함 확인) |

## 표에 없는 규칙 (거부·보존 또는 기존값 유지)

1. **ItemConsumeRate 그룹 12의 의미** (85:100, 86:100, 87:200, 88:300, 89~99:400).
   아이템 설명은 "캐릭터 일정 레벨에서 충전량 보너스 제공"뿐이다. Value가
   (a) 더해지는 % (85레벨 ×2 … 89레벨 ×5), (b) 배율 % (85레벨 ×1 … 89레벨 ×4),
   (c) 1/10000 비율(같은 표의 경험치 그룹 2 = 10500이 ×1.05인 것처럼) 중
   무엇인지 표가 말하지 않는다. → 그룹의 첫 행 레벨(85) 이상이면 충전
   아이템을 **사용하지 않고 보존**한다. 100레벨 이상은 그룹에 행이 없어
   "보너스 없음"인지 "89행 연장"인지도 알 수 없어 함께 보존한다.
   (이름 기반 옛 경로 `TwilightAinhasadService.charge_amount`의 85+ 배율은
   기존 TWILIGHT 규칙으로 남아 있다.)
2. **드래곤의 비약 + 그룹 12 조합**: 레벨 충전량에 그룹 12 보너스가 곱해지는지
   불명 → 85레벨 이상 보존. 고정 충전량(EinasadBlessAbsolute>0)과 레벨 충전량이
   함께 있는 경우(테스트 아이템 #308343)의 합산 규칙도 불명 → 보존.
3. **LevelEinasadBlessRecharge 표의 ExtraRecharge** (80~84: 300,000,
   85~89: 600,000, 90: 1,200,000 … 110: 13,200,000 = 50~2200포인트):
   언제(접속·매일·시간·레벨업) 누구에게 주는지 표·설명문에 없다. 연결되는
   BonusType(10971)의 값은 이 표가 아니라 ItemConsumeRate 그룹 번호다.
   → 충전하지 않음.
4. **자연(시간) 충전**: EinasadVariable의 #1 600000, #4 120, #22 1200000,
   #54 4272000, #72 59142, #82 1, #92 5, #102 3, #112 4, #123 200,
   #133 10000, #143 50 은 종류 이름(EinasadVariableType) 표가 없어 의미를
   확정할 수 없다. → 기존 TWILIGHT 자연 충전(120초당 1, 200까지)을 유지.
   접속 보상형 충전도 표에 없다.
5. **처치당 소모량 공식**: 몬스터 경험치 대비 소모량 표가 없다. → 기존
   TWILIGHT 상수(`EXP_PER_BLESSING_POINT` 42000 경험치당 1)를 유지.
   ConstantData `EinasadConsumLimit`=201 의 사용처(2단계 하한과 같은 값)도 불명.
6. **Experience 표의 Einasad 열**: `EinasadReduction`(60레벨 20 … 160레벨 40),
   `EinasadSpecialBlessValue`(80레벨 10000, 91레벨 200000 …),
   `EinasadAdditionValue/Percent`(전부 0)의 단위·적용 대상이 없다. → 미적용.
7. **특별한 축복(Level_SpecialBless, 3단계)**: ContentsControl
   `EinasadSpecialBless` Enable=false (523에서 꺼진 콘텐츠). 버프 59142의
   "축복 소모 없음"도 꺼진 콘텐츠라 연결하지 않음.
8. **드래곤의 수정(Level_DragonCristal, 4단계)**: 버프 59352는 "[테스트]"
   항목이고 효과 설명이 비어 있다. → 미적용.
9. **0단계 GetItem의 비장비 아이템**: "거래 불가 장비 획득 가능"이 장비가 아닌
   아이템(물약·주문서 등)을 막는지 표가 말하지 않는다. → 기존 동작(비장비는
   허용, 장비는 각인만) 유지.
10. **EinasadBlessIncreasePercent / EinasadBlessPercent / EinasadExperienceBenefit /
    NoEinasadAddtionalDamage** BonusType: 일부 버프에 값이 있으나 단위·계산식
    설명이 없어 연결하지 않음 (충전 보너스 %는 기존 `blessing_charge:percent`
    소비자만 유지).
