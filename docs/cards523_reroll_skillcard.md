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

### TWILIGHT 해석 (표에 없음)

- TWILIGHT 카드 보유는 "영구 보유(해금) 1장 + 중복분"이다. 다시 뽑기는 **중복분**을 바꾼다. 영구 보유 1장은 각성·컬렉션·장착·원정이
  걸려 있어 기존 합성과 같이 소모하지 않는다(저장 보존). 그래서 중복분이 없는 카드는 다시 뽑을 수 없고, 신화·유일은 중복분 2장이 필요하다.
  퀘스트로 받아 보류 중인 중복분(`outgoing_material_spare`)은 쓰지 않는다.
- "카드마다"는 카드 정체(`card_id`)마다다. 같은 카드의 중복분을 여러 번 바꾸면 그 카드의 횟수가 쌓이고, 결과로 받은 카드는 자기 횟수를 따로 갖는다.
- 6회째에 보여 준 5장은 처음 보여 줄 때 저장(`picks`)하고 실행할 때까지 고정한다. 다시 견적을 내도 같은 5장이다(창을 닫았다 열어 후보를 바꾸는 것 방지).
- 대상 덱: 표에 활성 행이 있는 변신(1)·마법인형(2)·성물(98). 스킬 카드 덱 41의 다시 뽑기는 2절의 "남은 것" 참고.

### API (world)

```gdscript
var q: Dictionary = world.card523_swap_quote(category, identity)   # category: "변신"|"마법인형"|"성물", identity: TwilightCardDrawFusion.card_id(record)
# q = {ok, reason, token, category, card{identity,card_id,name,grade,grade_id}, used, max, remaining,
#      swap_count, cost{currency:"다이아",currency_id:4,amount}, diamonds, copies_required, extra_copies,
#      copies_available, candidates[{identity,card_id,name,grade}], candidate_count,
#      pick_count, pick_candidates[...]}          # ok=false여도 아는 칸은 채워서 돌려준다(창 표시용)
var r: Dictionary = world.card523_swap_execute(q.token, pick_identity)  # pick은 pick_count>0일 때만, pick_candidates 중 하나
# r = {ok, reason, saved, category, from{...}, result{id,name,grade,new}, picked, consumed, cost, swap_count, remaining}
```

견적 → 확인 → 실행. 실행은 저장 한 번으로 확정되고, 저장이 실패하면 카드·다이아·횟수·후보를 모두 되돌린다.
견적 뒤 카드·다이아·횟수가 바뀌면 실행을 거부한다(다시 견적).

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

- 새 키 `card_swap523` = `{schema:1, counts:{덱:{카드:횟수}}, picks:{"덱|카드":{swap_count, candidates[]}}}`,
  `skill_card523` = `{schema:1, cards:{"카드ID":{level 0~3, exp}}}`. 예전 저장에는 키가 없고 빈 상태로 시작한다.
- 읽을 수 없는 값은 그대로 보존해 다시 저장하고(덮어쓰지 않음), 그 기능만 막는다.

## 4. 남은 것

- 원본 창 연결(CardChange, SkillCard_All): UI 담당 작업.
- 스킬 카드 덱 41 다시 뽑기(영웅·전설 활성 행): 스킬서 아이템을 다른 스킬서로 바꾸는 규칙(직업 제한 여부)이 정해지지 않아 넣지 않았다.
- 영구 보유 1장만 있는 카드의 다시 뽑기: 위 해석대로 막혀 있다. 해금 카드를 바꾸려면 각성·컬렉션·장착 처리 규칙이 필요하다.
- 소비자 없는 단계 효과(위 목록).
