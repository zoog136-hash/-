# 카드 덱 보너스·스킬 각성 스탯 (원본 523) — 표에 없는 규칙

대상 표: `BuffCardDeckBonus` (68행), `BuffCardSkillAwakenStat` (16행),
`BuffCardSkillAwakenStatPerLevel` (300행). 원칙: 표에 있는 값만 적용하고,
표에 없는 규칙은 지어내지 않고 보류/거부하며 여기 남긴다.

## 구현된 것

- `scripts/cards/card_deck_bonus523.gd`: `BuffCardDeckBonus` 행
  (BuffCardDeckID, GradeID, BonusID)을 `Bonus` → `BonusType` → `Unit` →
  `UIUnit.Denominator`로 해석한다. Percentage는 Value/10000 = %p,
  Weight는 Value/100, Value는 그대로(기존 `option_slot_definitions.gd`와 같은 규칙).
  덱 1(변신)·2(마법인형)·98(성물)의 **장착 중이고 보유한** 원본 카드의
  덱·등급에 해당하는 행이 적용된다.
- 연결된 소비자: 이동 속도(`speedBonusPct`), 공격 속도(`attackSpeed`),
  획득 경험치(`xp`), 아인하사드 절약(`blessing_consumption_reduction_pct`),
  최대 HP/MP(`hpFlat`/`mpFlat`), 무게(`weightBonus`), 스킬 쿨타임 감소
  (`skillCooldownPct`), 시전 속도(`castSpeed` → 기존 정책
  `cast_speed_consumer = existing_skill_cooldown_factor`로 쿨타임 계수).
- 스킬 각성 스탯: 이미 있던 `skill_awakening_runtime.bonus_records()`가
  `BuffCardSkillAwakenStatPerLevel.HP`를 최대 HP에 더하고 있었다. 이번에
  `BuffCard.MagicDollAwakenStatID`가 `BuffCardSkillAwakenStat` 행을 가리켜야만
  프로필이 성립하도록 연결했다(행 이름은 프로필 `stat_set`으로 노출).
- 덱 보너스는 저장 상태가 없다. 장착 카드(`equipped_catalog`)와 보유
  (`card_draw_fusion.owned`)에서 매번 계산되므로 저장/로드 후 그대로 유지된다.

## 표에 없는 규칙과 처리

| # | 없는 규칙 | 처리 |
|---|---|---|
| 1 | 보너스가 **언제** 켜지는가(장착 카드 기준 / 보유 최고 등급 / 보유 수). 표에는 덱·등급·BonusID 세 열뿐이다. | 카드 자신의 BuffClass 보너스가 적용되는 것과 같은 경로, 즉 **장착 중 + 보유한 카드 1장의 덱·등급**으로만 적용. 보유 수·최고 등급 기준은 만들지 않음. |
| 2 | "보유 수/컬렉션 조합"에 따른 덱 보너스. `BuffCardDeckBonus`에 보유 수·카드 ID·컬렉션 열이 없다. | 구현하지 않음. 컬렉션 보너스는 기존 `BuffCardCollection*` 경로가 따로 담당(변경 없음). |
| 3 | 추가 슬롯(마법인형/성물 서브 슬롯 11)의 카드에도 덱 보너스가 붙는지. | 적용하지 않음(주 슬롯 카드만). |
| 4 | 유일(Grade 52) 변신·마법인형의 덱 보너스. 표에 해당 행이 없다(성물 98만 52행 있음). | 보너스 없음(행이 없으므로 0). 이벤트 등급(71)은 마법인형만 행이 있어 그대로 적용. |
| 5 | `HitRecoverySpeedBonus`(피격 회복 속도) 소비 규칙. 게임에 소비자가 없고, 표의 해당 행 Value가 모두 0이다. | 보류(`no_game_consumer`). 값이 0이라 수치 차이 없음. |
| 6 | `HPPlus`/`MPPlus` 덱 보너스 행(마법인형 등급 1~5)은 Value가 모두 0. 다른 표에서 값을 채우는 규칙이 없다. | 0으로 적용(효과 없음). 다른 값을 만들지 않음. |
| 7 | 1등급 변신의 이동 속도·시전 속도, 2등급 이하 일부 행 Value 0. | 0으로 적용. |
| 8 | 덱 보너스와 카드 자체 보너스(BuffClass)의 중첩/최대치 규칙. | 기존 합산 방식(더하기) 그대로. 공격 속도 배율은 기존 상한 4.0, 이동 속도 2.5 상한 유지. 새 상한을 만들지 않음. |
| 9 | 시전 속도(`CastSpeedBonus`)가 정확히 무엇을 줄이는가(시전 모션/딜레이). | 기존 저장소 정책(`cast_speed_consumer`)대로 스킬 쿨타임 계수에 % 더함. 정책이 바뀌면 함께 꺼짐. |
| 10 | 덱 31(`Test_MysteryCardDeck`) 행 3개. | 테스트 덱이라 연결하지 않음(`deck_not_connected:31`). |
| 11 | 서버/기간 조건. `BuffCardDeckBonus`에는 ServerLimit·기간 열이 없다. | 카드 자체의 기존 서버·기간 검사(`_patch523_card_available`)만 따름. |
| 12 | `BuffCardSkillAwakenStatPerLevel`에는 **HP 열만** 있다. 다른 스탯(MP, 공격 등)의 각성 스탯은 표에 없다. | HP만 적용. 다른 스탯은 만들지 않음. |
| 13 | `BuffCardSkillAwakenStat` ID 42 `None`(일반·고급 등급 카드)에는 레벨 행이 없다. | 해당 카드는 각성 스탯 없음(기존과 동일, 각성 대상 아님). |
| 14 | 각성 HP가 오를 때 현재 HP를 함께 채우는지. 표에 없다. | 기존 코드 동작 유지(최대치만 오르고 현재 HP는 기존 vitals 규칙). |
| 15 | 각성 레벨 0(각성 전)의 스탯. 표는 레벨 1~20만 있다. | 레벨 0은 보너스 없음. |

## 원본 ZIP이 없을 때

`card_deck_bonus523`은 `problem`을 세우고 아무 보너스도 적용하지 않는다
(로그 `CARD_DECK_BONUS523_HELD`). 저장은 막지 않는다(저장 상태가 없음).
