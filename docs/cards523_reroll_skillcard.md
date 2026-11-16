# 523 카드 다시 뽑기 · 스킬 카드 합성/강화 — 구현 (2026-11-16)

조사 문서 `docs/cards523_swap_skillcard_missing_rules.md`(PR #553)의 "결정 필요" 항목을 사용자가 정했다.
수치는 523 원본 표(정의 ZIP `d5192c3c…4832`)만 쓰고, 표에 없는 규칙은 아래 "사용자 결정 2026-11-16"과
"TWILIGHT 해석"으로 나눠 적는다. 원본 창(CardChange, SkillCard_All) 연결은 별도 작업이고, 이 문서의 API만 부르면 된다.

## 1. 카드 다시 뽑기 (`scripts/cards/card_swap523.gd`, 저장 키 `card_swap523`)

### 표에서 오는 것

| 표 | 쓰는 값 |
| --- | --- |
| BuffCardRuleSwap | 덱·등급별 `MaxSwapCount`, `Activate`, `ActivateCardAmount`, `ServerLimitSetID`(현재 서버 프로필 KR 1서버로 거르면 덱·등급마다 1행) |
| BuffCardRuleSwapCost | `SwapCount`별 `Cost`, `CurrencyID 4`(Currency "Gem" = 다이아), `PickCount` |
| BuffCardSourceView / BuffCard | 결과 후보 `IsSwapOut = true`, `IsNoSwapOut = false`, 카드 `ServerLimitSetID`, 날짜 칸 0 |

변신 영웅: 900 · 2900 · 4900 · 6900 · 9900 · 9900(6회째, PickCount 5), 후보 40장. 전설 9900~49900, 신화·유일 99900.

### 사용자 결정 2026-11-16

- 대상은 보유한 아무 카드(중복분 포함). 횟수는 카드마다 누적되고 초기화하지 않는다.
- 결과는 표의 같은 덱·같은 등급 후보 중 균등 무작위이며 현재 카드는 뺀다.
- 6회째(PickCount 5)는 후보 5장을 보여 주고 플레이어가 하나를 고른다.
- 신화·유일(`ActivateCardAmount 1`)은 같은 카드 1장을 더 소모한다.
- 비용은 게임 다이아 지갑(인벤토리 `다이아`)에서 뺀다.
- (09:19) 1장뿐인 카드도 다시 뽑을 수 있다. 처음의 "중복분만" 해석은 없앴다.
- (09:23) 영웅 등급 이상만 대상이다(Grade `GradeValue` 4~7: 영웅·전설·신화·유일). 그 아래는 거부한다.
- (09:23) 다시 뽑은 결과는 바로 받지 않는다. 카드마다 **대기 결과**로 저장되고, 원래 카드는 확정 전까지 그대로 보유한다.
  대기 중에도 다시 뽑을 수 있고(다음 횟수·비용), 새 결과가 대기 결과를 바꾼다. 확정하면 원래 카드가 대기 결과로 바뀐다.
  6회째에 고른 카드도 대기 결과가 된다. 대기 결과는 저장되므로 불러오기·앱 종료 뒤에도 남는다.
- (09:23) 포기(취소) 버튼: 원본 창(CardChange_All, CardChange_Popup_Retry/RetrySpecial/Confirm/Result)에 별도 포기 버튼이 없다
  (노드: Btn_Ok · Btn_No · Btn_Close · Btn_Back · Btn_Caution · Btn_ListView · Btn_Probability · Btn_Confirm, 선택 팝업 Btn_Yes · Btn_Cancel).
  그래서 취소 API는 만들지 않았고, 대기 결과는 확정할 때까지 그대로 남는다.

### TWILIGHT 해석 (표에 없음)

- TWILIGHT 카드 보유는 "영구 보유(해금) 1장 + 중복분"이다. 확정할 때 바꾸는 장수(1장, 신화·유일은 2장)는 중복분부터 쓰고, 모자라면 영구 보유 1장을 쓴다.
  퀘스트로 받아 보류 중인 중복분(`outgoing_material_spare`)은 쓰지 않는다. 보류 중복분이 남아 있으면 영구 보유 1장은 바꿀 수 없다(보류 사본이 주인 없이 남기 때문).
- 영구 보유 1장을 바꿀 때의 기존 소유자 규칙(확인 결과):
  - 카드 컬렉션(`collection_runtime`)은 저장된 등록 없이 `card_draw_fusion.owned`에서 매번 계산된다. 카드를 잃으면 그 카드가 든 완성 컬렉션이 풀린다.
  - 옵션 각성(`option_awakening_service.validate_state`)은 미보유 카드에 각성 진행이 있으면 저장을 막는다. 추가 인형·성물 슬롯도 이 상태에 있다.
  - 스킬 각성·탐험 파견·할파스 별 강화는 카드 정체에 진행을 붙여 둔다.
  - 장착(`equipped_catalog`)은 보유 카드를 가리킨다.
  그래서 상태를 옮기거나 지우지 않고, 다음 중 하나면 **거부하고 이유를 보여 준다**(`_last_copy_guard`): 장착 중 · 옵션 각성/추가 슬롯 기록 · 스킬 각성 기록 ·
  탐험 파견 기록 · 할파스 별 강화 진행 · 그 카드를 빼면 지금 완성된 카드 컬렉션이 풀림. 이 검사는 견적(다시 뽑기 가능 여부)과 확정 때 모두 한다.
- "카드마다"는 카드 정체(`card_id`)마다다. 결과로 받은 카드는 자기 횟수를 따로 갖는다.
- 6회째에 보여 준 5장은 처음 보여 줄 때 저장(`picks`)하고 그 회차를 실행할 때까지 고정한다. 다시 견적을 내도 같은 5장이다(창을 닫았다 열어 후보를 바꾸는 것 방지).
- 대상 덱: 표에 활성 행이 있는 변신(1)·마법인형(2)·성물(98). 스킬 카드 덱 41의 다시 뽑기는 2절의 "남은 것" 참고.

### API (world)

```gdscript
var q: Dictionary = world.card523_swap_quote(category, identity)   # category: "변신"|"마법인형"|"성물", identity: TwilightCardDrawFusion.card_id(record)
# q = {ok, reason, token, category, card{identity,card_id,name,grade,grade_id}, used, max, remaining,
#      swap_count, cost{currency:"다이아",currency_id:4,amount}, diamonds, copies_required, extra_copies,
#      copies_available, uses_last_copy, candidates[{identity,card_id,name,grade}], candidate_count,
#      pick_count, pick_candidates[...],
#      pending{result{identity,card_id,name,grade}, swap_count, picked} | {},
#      can_confirm, confirm_reason, confirm_token}   # ok=다시 뽑기 가능(token), can_confirm=확정 가능(confirm_token)
var r: Dictionary = world.card523_swap_execute(q.token, pick_identity)  # 다시 뽑기. pick은 pick_count>0일 때만, pick_candidates 중 하나
# r = {ok, reason, saved, category, from{...}, pending{result{...},swap_count,picked}, picked, cost, swap_count, remaining}
var c: Dictionary = world.card523_swap_confirm(q.confirm_token)         # 확정: 원래 카드 → 대기 결과
# c = {ok, reason, saved, category, from{...}, result{id,identity,name,grade,new}, consumed, used_last_copy}
var all: Array = world.card523_swap_pending()   # 저장된 대기 결과 전부 [{category,identity,name,result{identity,name,grade},swap_count,picked}]
```

창 흐름: 견적 → 다시 뽑기(다이아 차감, 대기 결과 저장) → 다시 견적해 결과 표시 → 다시 뽑기 또는 확정.
최대 횟수를 다 써도 대기 결과가 있으면 `ok=false`, `can_confirm=true`이고 `confirm_token`이 있다.
각 단계는 저장 한 번으로 끝나고, 저장이 실패하면 카드·다이아·횟수·대기 결과를 되돌린다.
견적 뒤 카드·다이아·횟수·대기 결과가 바뀌면 실행·확정을 거부한다(다시 견적). 토큰은 한 번만 쓸 수 있다.

## 2. 스킬 카드 덱 41 (`scripts/cards/skill_card523.gd`, 저장 키 `skill_card523`)

### 표에서 오는 것

| 표 | 쓰는 값 |
| --- | --- |
| BuffCardRuleMergeView (덱 41) | 일반 8장 → 영웅 1%, 영웅 4장 → 전설 12%, 전설 2장 → 신화 11% (`SuccessProbability`/1,000,000), `OnFailReward false` |
| BuffCardLevelUp · Mapping · Probability | 카드·단계(0,1,2)별 `Cost`, `RequiredExperience`, `FailureExperience`, 확률 66.7% / 33.3% / 16.7% (156종) |
| BuffCardExperience · Mapping · Grade | 재료 카드가 주는 `Experience`와 `Cost`(일반 25,000 · 영웅 100만 · 전설 800만 · 신화 7,200만), 같은 등급끼리만 |
| UIBuffCardLevelUpDesc | 단계 설명 1~4 (창 표시용) |
| SpellBonus `MinSpellLevel` | 단계 효과 |
| SpellLearnLimit | 합성 결과 직업 판정 |

### 사용자 결정 2026-11-16

- 배우지 않은(쓰지 않은) 스킬서 아이템이 카드(재료)다.
- 합성 실패 시 재료는 모두 사라진다(`OnFailReward=false`).
- 합성 결과는 목표 등급 중 내 직업 카드에서 균등.
- 강화는 표의 3단계(0→1→2→3)만. 원본 창의 4단계 칸은 비워 둔다.
- 강화 비용 화폐는 아데나. 실패하면 `FailureExperience`를 받는다.
- 단계 효과(`MinSpellLevel>0` SpellBonus)는 기존 주문 단계 소비자가 있으면 그것으로 켠다.

### TWILIGHT 해석 (표에 없음)

- 강화 대상("덱 카드")은 스킬서를 써서 배운 카드(스킬서 학습 영수증 `source_skill_book_receipts`의 `card_id`)다.
- 재료는 원본 영수증이 있는 일반 소지 스킬서만 쓴다. 퀘스트 보상 스킬서와 잠근 아이템은 재료에서 뺀다.
- 재료 비용 `BuffCardExperience.Cost`는 재료 1장마다, 시도 비용 `BuffCardLevelUp.Cost`는 시도 1회마다 아데나로 낸다.
  (일반 아이스 스파이크 0→1: 8장 × 100,000 + 100,000 = 900,000)
- 경험치 게이지는 현재 단계 `RequiredExperience`에서 멈춘다. 넘친 양은 사라지고 견적에 `wasted_exp`로 보인다.
  시도하면 게이지를 비우고, 성공은 다음 단계 0부터, 실패는 `FailureExperience`(표에서 필요량과 같음)로 다시 채운다.
  그래서 실패 뒤에는 재료 없이 시도 비용만 내고 다시 시도할 수 있다.
- 합성 후보: 덱 41, 목표 등급, `IsMergeOut`(SourceView)·`IsNoMergeOut false`, 서버 조건, 날짜 칸 0, 현재 직업이 배울 수 있는
  (SpellLearnLimit, 튜토리얼 제외) 카드 중 받을 스킬서가 있는 것.
- 받는 스킬서: 그 카드의 정상(TestItem false, 바로 배울 수 있는) 스킬서 아이템 중 원본 ItemClassID가 가장 작은 것, 일반 축복 1장.
- 단계 효과: 기존 소비자 `scripts/cards/relic_spell_effects.gd`(성물 스킬 레벨과 같은 경로)에서 스킬 카드 단계를 기본 주문 레벨로 쓴다.
  `MinSpellLevel ≤ 단계`인 행 중 가장 높은 행이 기본 행을 대신한다(예: 아이스 스파이크 SpellDamageBase 40 → 45/50/55).
  성물이 레벨 1을 더하면 그 위로 더한다(3단계 + 성물 = 4단계 행).
  이 소비자는 `data/skills/relic_spell_bindings523.json`에 묶인 기존 스킬 119개만 다룬다. 강화 가능한 156장 중 43장이 여기에 있다.

### 단계 효과 기록 (소비자 없는 것 — 지어내지 않음)

- 강화 가능 156장 중 `MinSpellLevel>0` 행이 있는 주문은 23개다.
- 소비자로 켜지는 것: 바인딩에 있고, 행 이름이 소비자가 아는 칸(`SpellDamageBase`→피해, `MPRestoration`→MP 회복,
  `HPRestoration`, `SpellBuffDuration`, 버프 스탯)이며 스킬 모드가 맞는 것. 예: 아이스 스파이크, 헬 사이드(피해), 마나 체인지·블러드 투 소울(MP),
  앱솔루트 배리어(지속시간).
- 소비자 없음(창의 설명 문구만 보이고 수치는 그대로): `SpellHitProbabilityBase`(적중 확률, 일부 성물 설정 스킬만 예외), `SpellHitProbabilityMin`,
  `IgnoreSpecialResistance`, `SpellDebuffMin/MaxDuration`(단계별 행), 자식 주문 교체 `SpellClassID`, 그리고 바인딩에 없는 카드
  (힐 올, 셰이프 체인지, 블레이드 스턴, 할루시네이션, 드래곤 스턴, 쉐도우 스턴·슬립·슬로우, 이머전시 케어, 데스 브레이커).
  소비자는 `relic_spell_effect.pending`에 이름을 남긴다.

### API (world)

```gdscript
world.skill_card523_materials(grade_id := -1) -> Array      # [{physical_id,name,card_id,card_name,grade_id,grade,remaining,locked,receipt}]
world.skill_card523_deck() -> Array                         # 배운 카드: [{card_id,name,grade_id,grade,spell_class_id,level,max_level,exp,required_exp,enhanceable,stage_descriptions{1..4}}]

var m: Dictionary = world.skill_card523_merge_quote(grade_id, selection := {})   # grade_id: 1|4|5, selection {physical_id: 수량}, 비우면 앞에서부터 자동
# m = {ok, reason, token, grade_id, grade, target_grade_id, target_grade, source_amount, probability(/1,000,000),
#      probability_percent, fail_reward, candidates[{card_id,name,item_class_id}], candidate_count, owned_count, materials[...]}
var mr: Dictionary = world.skill_card523_merge_execute(m.token)
# mr = {ok, reason, saved, success, result{card_id,name,item_class_id,item}|{}, consumed, message}

var l: Dictionary = world.skill_card523_levelup_quote(card_id, feed := {}, attempt := true)  # feed {physical_id: 수량}; attempt=false면 먹이기만
# l = {ok, reason, token, card_id, name, grade, level, max_level, exp, required_exp, failure_exp, probability, probability_percent,
#      feed_exp, exp_after_feed, wasted_exp, materials, feed_cost, attempt, attempt_cost, cost{currency:"아데나",amount}, gold, stage_descriptions}
var lr: Dictionary = world.skill_card523_levelup_execute(l.token)
# lr = {ok, reason, saved, card_id, attempted, success, level, exp, cost, consumed, message}
```

재료 차감은 기존 원본 물리 차감(`current523_native_stack.stage_debit`, 사용 장부 포함), 결과 스킬서는 기존 원본 지급(`patch523_stage_view.stage_one`)으로
하고, 아데나·재료·결과·단계를 저장 한 번에 묶는다. 저장 실패 시 그대로 둔다.

## 3. 저장

- 새 키 `card_swap523` = `{schema:1, counts:{덱:{카드:횟수}}, picks:{"덱|카드":{swap_count, candidates[]}}, pending:{"덱|카드":{result, swap_count, picked}}}`(pending이 없는 저장도 읽음),
  `skill_card523` = `{schema:1, cards:{"카드ID":{level 0~3, exp}}}`. 예전 저장에는 키가 없고 빈 상태로 시작한다.
- 읽을 수 없는 값은 그대로 보존해 다시 저장하고(덮어쓰지 않음), 그 기능만 막는다.

## 4. 남은 것

- 원본 창 연결(CardChange, SkillCard_All): UI 담당 작업.
- 스킬 카드 덱 41 다시 뽑기(영웅·전설 활성 행): 스킬서 아이템을 다른 스킬서로 바꾸는 규칙(직업 제한 여부)이 정해지지 않아 넣지 않았다.
- 각성·장착·파견·완성 컬렉션이 걸린 마지막 1장의 다시 뽑기: 거부한다. 진행을 옮기는 규칙이 정해지면 바꿀 수 있다.
- 소비자 없는 단계 효과(위 목록).

## 5. TWILIGHT 근사 적용 — 사용자 지시 2026-11-16 11:40 "근사치로 다 넣어" (PR `feat/approx523-cards`)

4절의 남은 것 세 가지를 근사로 넣었다. 근거가 약한 것은 "TWILIGHT 근사(근거 약함)"으로 표시한다. 원본 창 연결은 여전히 UI 작업이다.

### 5.1 스킬 카드 덱 41 다시 뽑기 (`skill_card523.swap_quote/swap_execute`, world `skill_card523_swap_quote/execute`)
- 표에서 오는 것: BuffCardRuleSwap 덱 41(영웅 5회·전설 5회, 신화 `Activate=false`라 제외), BuffCardRuleSwapCost(영웅 900·2900·4900·6900·9900, 전설 9900~49900 다이아, PickCount 0), SourceView `IsSwapOut`·`IsNoSwapOut`.
- 없던 것: 결과 후보의 직업 제한. **근사(근거 약함)**: 사용자가 합성에서 정한 규칙과 같게 "같은 등급 중 **현재 직업이 배울 수 있는** 카드(SpellLearnLimit, 튜토리얼 제외), 받을 스킬서가 있는 것" 중 균등, 현재 카드 제외.
- 대상·결과: 배우지 않은 스킬서 1장(원본 영수증, 잠금 제외)을 차감하고 결과 스킬서 1장을 지급한다. 스킬서에는 영구 보유 1장이 없어 다른 덱처럼 "대기 결과"를 둘 곳이 없으므로 **바로 바뀐다**.
  다이아 차감·스킬서 차감·결과 지급·횟수(`skill_card523.swaps{카드ID:횟수}`, 초기화 없음)를 저장 한 번에 기록. 예전 저장(`swaps` 없음)도 그대로 읽는다.

### 5.2 마지막 1장의 진행 이전 (`card_swap523._move_progress`, 상수 `APPROX_MOVE_PROGRESS`)
- 예전: 장착·옵션 각성/추가 슬롯·스킬 각성·탐험 파견·완성 컬렉션이 걸린 마지막 1장은 거부.
- **근사(근거 약함)**: 확정할 때 진행을 결과 카드로 옮긴다 — 장착 칸은 결과 카드로, 옵션 각성·스킬 각성·탐험 파견 기록은 카드 정체(키·값)를 결과 카드 정체로 바꿔 다시 넣는다.
  완성 카드 컬렉션은 보유 카드에서 매번 계산되므로 풀릴 수 있다(견적 `progress_moves.collections_undone`에 수를 보여 준다).
  저장이 실패하면 카드·대기 결과와 함께 옮긴 진행도 되돌린다.
- 할파스 별 강화 — **TWILIGHT 근사(근거 약함, 지시 2026-11-16)**: 별 강화는 해방된 할파스 한 장의 체계라 옮길 대상 카드가 없다.
  공식·인벤에서 "할파스를 다시 뽑기로 바꿀 때 별 강화가 어떻게 되는지"의 설명을 찾지 못해(검색 2026-11-16, 결과 없음) 가장 보수적인 값으로 정했다:
  마지막 1장 다시 뽑기를 **허용**하고, 별 강화 단계는 **지우지 않고 할파스 정체에 그대로 둔다**. 할파스를 보유·장착하지 않은 동안 효과는 꺼지고
  (`halphas_star_enchant_runtime.active()`의 보유·장착 조건), 다시 얻으면 그 단계부터 이어진다. 견적에 `progress_moves.halphas_star_kept`(단계)로 보여 준다.
  스위치 `card_swap523.APPROX_KEEP_HALPHAS_STAR`.
  측정(실제 Main): 별 강화 때문에 거부하지는 않게 됐지만, 원본 표에서 할파스와 같은 덱·등급의 다른 카드가 없어(후보 0)
  할파스 다시 뽑기는 "바꿀 수 있는 같은 등급 카드가 없습니다"(원본 표 규칙)로 성립하지 않는다. 표가 바뀌어 후보가 생기면 위 근사대로 동작한다.

### 5.3 소비자 없던 스킬 카드 단계 효과 (`relic_spell_effects._approx_stage`, 상수 `APPROX_STAGE_FIELDS`)
| 행 | 근사 소비자 |
|---|---|
| `SpellHitProbabilityBase`, `IgnoreSpecialResistance` (Percentage) | 스킬의 상태이상 성공 확률 `status_chance`에 단계 차이만큼 더함(0~100%) |
| `SpellHitProbabilityMin` (Percentage) | `status_chance`의 하한 |
| `SpellDebuffMinDuration` / `SpellDebuffMaxDuration` (Seconds) | 상태이상 지속 `duration_bounds`의 최소/최대 |
- 계속 남는 것: 자식 주문 교체(`SpellClassID`)와 바인딩에 없는 카드(힐 올, 셰이프 체인지, 블레이드 스턴 등 10종) — 바꿀 기존 스킬 기록 자체가 없다.

### 확인 (`tests/cards523_reroll_skillcard_test.gd`, 실제 Main·원본 팩)
- 장착 + 스킬 각성 기록이 있는 마지막 1장: 견적 가능(옮길 진행 표시) → 다시 뽑기 → 확정하면 장착 칸·스킬 각성이 결과 카드로 옮겨짐.
- 마법사 영웅 스킬 카드 다시 뽑기: 900 다이아, 원래 스킬서 1장 → 같은 등급 마법사 카드 스킬서 1장, 횟수 1, 저장에 횟수 기록.
