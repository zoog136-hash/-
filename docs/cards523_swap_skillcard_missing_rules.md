# 523 카드 다시 뽑기(CardChange_All)·스킬 카드 덱·합성·강화(SkillCard_All) — 표 조사와 보류 (2026-11-16)

원본 UI 창은 있으나 게임 기능이 없다고 보고된 두 가지를 523 원본 표(정의 ZIP `d5192c3c…4832`)로 조사했다.
원칙(사용자 결정 2026-11-11): 표 자료가 충분한 것만 구현하고, 표에 없는 세부 규칙은 지어내지 않고 여기에 남긴다.
**결론: 두 기능 모두 결과·자격·소유 단위 규칙이 표에 없어 이번에는 게임 기능을 만들지 않았다.** 아래 "결정 필요"가 정해지면 바로 구현할 수 있도록
표 근거를 정리했다.

## 1. 카드 다시 뽑기 (변신·마법인형·성물, 스킬 카드)

### 표에 있는 것

| 표 | 행 | 내용 |
| --- | ---: | --- |
| BuffCardRuleSwap | 30 | 덱·등급별 `MaxSwapCount`(5~6, 유일 1), `Activate`, `ActivateCardAmount`(신화·유일 1), `ServerLimitSetID`(0·772·1304·1632), 상품 제목·후보 목록 DescID |
| BuffCardRuleSwapCost | 64 | 덱·등급·`SwapCount`(1~6)별 비용 `CurrencyID 4` = Currency "Gem"(다이아), 변신 영웅 900·2900·4900·6900·9900, 6회째 9900 + `PickCount 5`; 전설 9900~49900; 신화·유일 99900 |
| BuffCardSourceView | 1,271 | 카드별 `IsSwapOut`(다시 뽑기 결과로 나올 수 있음), `IsGotchaOut`·`IsMergeOut`·`IsCraftOut` |
| BuffCard | 1,271 | `IsNoSwapOut` |

- 결과 후보: 같은 덱·같은 등급의 `IsSwapOut` 카드. 변신 영웅 = 40종이고, 상품 설명(DescID 321001 "[획득 가능한 카드 목록]")의 이름 40개와 일치한다(39종 확인).
- 활성 묶음(Activate=true, 서버 세트 0 또는 KR 1서버 포함 772): 변신·마법인형·성물 영웅·전설·신화·유일, 스킬 카드 영웅·전설.

### 표에 없는 것 (결정 필요)

1. **어떤 카드를 다시 뽑을 수 있는지**: 표에는 결과 쪽 표시(`IsSwapOut`)만 있다. 뽑기·합성으로 막 얻은 카드만인지, 보유 중인 아무 카드(중복분)인지, 기간 제한이 있는지 표에 없다.
2. **횟수(`SwapCount`)의 단위**: 카드 한 장(획득 건)마다 1~6회인지, 계정·덱·등급 전체 누적인지, 언제 초기화되는지 없다.
3. **결과 확률**: 후보 카드별 가중치가 없다(BuffCard에 확률 열 없음). 기존 TWILIGHT 합성은 "동일 등급 균등"(2026-10-19 사용자 결정)이다. 같은 규칙을 쓸지, 현재 카드를 후보에서 뺄지 정해야 한다.
4. **`PickCount 5`(6회째)**: 후보 5장을 보여 주고 고르게 하는지, 5장 중 무작위인지 없다.
5. **`ActivateCardAmount 1`(신화·유일)**: 카드 1장이 더 필요한지(재료), 보유 1장 이상이 조건인지 없다.
6. **비용 화폐**: Gem = 다이아. 사용자 결정(2000다이아=55,000원 현금상점)과 같은 게임 다이아 지갑에서 빼는지 확인이 필요하다.

## 2. 스킬 카드 덱 (BuffCardDeck 41 "Spell", CharacterBased) — 합성·강화

### 현재 게임

스킬 카드(ItemCategory BuffCardDrawer, BuffCard 덱 41)는 아이템이다. 가방에서 쓰면 그 주문을 배우고 아이템이 소비된다(`source_skill_book`). 스킬 카드를 "카드로 보유"하는 덱 상태(보유·중복·레벨)는 게임에 없다.
`tj/runtime.gd`의 "스킬 카드 합성 실패 엔진 없음"도 같은 이유다.

### 표에 있는 것

| 표 | 행 | 내용 |
| --- | ---: | --- |
| BuffCard (덱 41) | 551 | 일반 247 · 영웅 140 · 전설 116 · 신화 48, `SpellClassID`, 클래스 이름 접두 |
| BuffCardRuleMergeView (덱 41) | 3 | 일반 8장 → 영웅 1%(10000/1,000,000), 영웅 4장 → 전설 12%, 전설 2장 → 신화 11%; `OnFailReward false`, `RewardFailPoint 0` |
| BuffCardRuleFixedMergeView (덱 41) | 3 | 확정 합성 일반 414 · 영웅 7 · 전설 8장(`IsUse false` — 사용 안 함) |
| BuffCardLevelUp / Probability / Mapping | 12 / 12 / 468 | 레벨 0·1·2 → 다음 단계: `Cost` 10만~500만, `RequiredExperience`, `FailureExperience`, 확률 66.7% / 33.3% / 16.7%; 카드 156종(일반 52 · 영웅 52 · 전설 39 · 신화 13) × 3단계 |
| BuffCardExperience / Grade / Mapping | 4 / 4 / 484 | 같은 등급 카드를 먹이면 경험치(일반 25,000 · 영웅 100만 · 전설 800만 · 신화 7,200만), 비용 `Cost` |
| UIBuffCardLevelUpDesc | 624 | 레벨별 설명("스킬 대미지 +5% / +10% / +15% / +20%")이 **1~4단계** |
| SpellBonus `MinSpellLevel` 1~4 | 150행(카드 주문 32개) | 단계별 실제 효과 후보(SpellHitProbabilityBase 48, SpellClassID 23, SpellDamageBase 16 …) |

### 표에 없는 것 (결정 필요)

1. **스킬 카드의 보유 단위**: 스킬서 아이템을 쓰면 주문을 배우는 지금 구조에서, 합성 재료가 "배우지 않은 스킬 카드 아이템"인지, 배운 카드의 중복분을 덱에 쌓는지 없다(덱 상태와 저장 형식 신설 필요).
2. **합성 실패 결과**: `OnFailReward false`·`RewardFailPoint 0`. 재료가 모두 사라지는지, 1장이 남는지 없다. 변신 카드에 쓰는 TWILIGHT 규칙("실패 시 같은 등급 1장")은 원본 값이 아니다.
3. **합성 결과 후보**: CharacterBased 덱 — 자기 직업 카드만인지, `IsMergeOut`·`IsNoMergeOut` 외에 직업 제한이 있는지 없다. 결과 카드별 확률도 없다.
4. **강화 단계 수 불일치**: LevelUp 표는 0→1, 1→2, 2→3의 3단계인데, UI 설명과 SpellBonus `MinSpellLevel`은 1~4단계다.
5. **강화 비용 화폐**(`Cost` 열에 화폐 ID 없음)와 `FailureExperience`의 의미(실패 시 쌓인 경험치를 잃는지/유지하는지).
6. **강화 효과 적용**: 기존 스킬 실행 정책은 `MinSpellLevel>0` 행을 쓰지 않는다(`skill523_source_hold_report.md`). 단계 효과를 켜려면 그 정책 변경이 필요하고, 덱 41 주문 551개 중 실행 가능한 것은 일부다(참고 스킬 실행 보류 294).
7. 스킬 카드 다시 뽑기(덱 41 영웅·전설)는 1절과 같은 이유로 보류.

## 3. 만들 수 있게 되면 쓸 API (안)

결정이 나면 아래 형태(견적 → 확인 → 실행, 저장 원자성)로 만든다. 지금은 코드가 없다.

- `world.card523_swap_quote(category, card_id) -> {ok, reason, cost:{currency:"다이아", amount}, swap_count, max, candidates, pick_count}`
- `world.card523_swap_execute(quote_token, pick:="") -> {ok, reason, result_card_id, saved}`
- `world.skill_card523_merge_quote(grade, selection) / _execute(token)`
- `world.skill_card523_levelup_quote(card_id, feed_selection) / _execute(token)`
