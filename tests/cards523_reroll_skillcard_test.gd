extends SceneTree
## 523 카드 다시 뽑기(card_swap523)와 스킬 카드 합성·강화(skill_card523).
## 사용자 결정 2026-11-16. Synthetic checks (save validation, preserved saves,
## the spell-stage projection) always run; with the original definition ZIP the
## real tables are checked and actual Main runs: reroll 1~6회(6회째 5장 중 선택),
## 신화 추가 1장, 다이아 차감, 저장 실패 복구, 합성 성공/실패, 강화 성공/실패/재시도,
## 단계 효과(아이스 스파이크 피해), 저장·불러오기.
const SWAP = preload("res://scripts/cards/card_swap523.gd")
const SKILL = preload("res://scripts/cards/skill_card523.gd")
const EFFECTS = preload("res://scripts/cards/relic_spell_effects.gd")
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## [공통][8단] 아이스 스파이크: 일반, 마법사, SpellDamageBase 40 → 45/50/55/60 (MinSpellLevel 1~4).
const ICE_CARD := 14991
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CARDS523_REROLL_SKILLCARD_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func effect(level: int, value: float, link: int) -> Dictionary:
	return {"link_id":link, "bonus_id":link, "name_value":"SpellDamageBase", "unit":"Value", "denominator":1.0, "value":value, "application":0, "target":0, "spell_level":level, "character_level":0, "character_class":0}

func synthetic() -> void:
	check(SWAP.validate({}).is_empty() and SWAP.validate(SWAP.empty_state()).is_empty(), "empty reroll state is valid")
	check(SWAP.validate({"schema":1,"counts":{"변신":{"source:m508:1:4":3}},"picks":{"변신|source:m508:1:4":{"swap_count":6,"candidates":["a","b"]}}}).is_empty(), "reroll counts and held picks validate")
	check(not SWAP.validate({"schema":1,"counts":{"무기":{}},"picks":{}}).is_empty() and not SWAP.validate({"schema":2,"counts":{},"picks":{}}).is_empty() and not SWAP.validate([]).is_empty(), "unknown deck / schema / type is refused")
	var swap = SWAP.new()
	var odd: Dictionary = {"schema":9, "counts":"x"}
	swap.import_state(odd)
	check(not swap.problem.is_empty() and swap.export_state() == odd, "an unreadable reroll save is kept as it was")
	check(not swap.quote("변신", "x").get("ok", true), "actions stay off while the save is unreadable")
	swap.import_state({"schema":1.0, "counts":{"변신":{"id":2.0}}, "picks":{}})
	check(swap.problem.is_empty() and swap.swap_count("변신", "id") == 2 and typeof(swap.export_state().counts["변신"]["id"]) == TYPE_INT, "JSON floats load as counts")
	swap.import_state(null)
	check(swap.export_state() == SWAP.empty_state(), "older saves start with no rerolls")
	check(SWAP.validate({"schema":1,"counts":{},"picks":{},"pending":{"변신|a":{"result":"b","swap_count":2,"picked":false}}}).is_empty() and not SWAP.validate({"schema":1,"counts":{},"picks":{},"pending":{"변신|a":{"result":3}}}).is_empty(), "pending results validate")
	swap.import_state({"schema":1, "counts":{}, "picks":{}})
	check(swap.problem.is_empty() and swap.export_state().get("pending") == {}, "a save from before pending results loads with none")
	check(SKILL.validate({}).is_empty() and SKILL.validate({"schema":1,"cards":{"14991":{"level":3,"exp":200000}}}).is_empty(), "skill card stage state validates")
	check(not SKILL.validate({"schema":1,"cards":{"14991":{"level":4,"exp":0}}}).is_empty() and not SKILL.validate({"schema":1,"cards":{"x":{"level":1,"exp":0}}}).is_empty(), "stage above 3 / non-numeric card is refused")
	var skill = SKILL.new()
	var bad: Dictionary = {"schema":1, "cards":{"14991":{"level":"x"}}}
	skill.import_state(bad)
	check(not skill.problem.is_empty() and skill.export_state() == bad and skill.level(14991) == 0, "an unreadable skill card save is kept and gives no stage effect")
	skill.import_state({"schema":1, "cards":{"14991":{"level":2.0,"exp":5.0}}})
	check(skill.level(14991) == 2 and skill.experience(14991) == 5, "stage and gauge load")
	# Stage projection on the existing spell-level consumer (relic path).
	var profile: Dictionary = {"binding":{"spell_id":1,"grade_id":1}, "spell":[effect(0,40,1), effect(1,45,2), effect(2,50,3), effect(3,55,4), effect(4,60,5)], "buff":[], "child_pending":[], "invoke":{}, "child_heal":{}, "blockers":[]}
	var record: Dictionary = {"id":"x", "mode":"attack", "power":100}
	var off: Dictionary = EFFECTS.project(record.duplicate(true), profile, {"base_level":0, "bonus":0, "effective_level":0, "code":"ready"}, 90, true)
	var relic: Dictionary = EFFECTS.project(record.duplicate(true), profile, {"effective_level":1, "bonus":1, "code":"ready"}, 90, true)
	var stage2: Dictionary = EFFECTS.project(record.duplicate(true), profile, {"base_level":2, "bonus":0, "effective_level":2, "code":"ready"}, 90, true)
	var stage3_relic: Dictionary = EFFECTS.project(record.duplicate(true), profile, {"base_level":3, "bonus":1, "effective_level":4, "code":"ready"}, 90, true)
	check(int(off.power) == 100 and not off.relic_spell_effect.active, "stage 0 without relic changes nothing")
	check(int(relic.power) == 105 and int(relic.relic_spell_effect.base_level) == 0, "relic-only level 1 projection is unchanged (+5)")
	check(int(stage2.power) == 110 and int(stage2.relic_spell_effect.base_level) == 2, "skill card stage 2 uses the MinSpellLevel 2 row (+10)")
	check(int(stage3_relic.power) == 120, "stage 3 + relic 1 reaches the MinSpellLevel 4 row (+20)")
	check(EFFECTS.detail_text(stage2).begins_with("스킬 카드 강화 2단계"), "skill detail names the card stage")

func tables() -> void:
	var swap = SWAP.new()
	check(swap.rule(1, 4).get("MaxSwapCount") == 6 and swap.rule(1, 32).get("MaxSwapCount") == 5 and int(swap.rule(1, 32).get("ActivateCardAmount", 0)) == 1, "BuffCardRuleSwap: 변신 영웅 6회, 신화 5회 + 1장")
	var costs: Array = []
	for count: int in range(1, 7): costs.append(int(swap.cost_row(1, 4, count).get("Cost", -1)))
	check(costs == [900, 2900, 4900, 6900, 9900, 9900] and int(swap.cost_row(1, 4, 6).get("PickCount", 0)) == 5, "BuffCardRuleSwapCost: 900~9900, 6회째 PickCount 5 (%s)" % str(costs))
	var skill = SKILL.new()
	var rule: Dictionary = skill.merge_rule(1)
	check(int(rule.get("SourceAmount", 0)) == 8 and int(rule.get("SuccessProbability", 0)) == 10000 and int(rule.get("SuccessGradeID", 0)) == 4 and rule.get("OnFailReward") == false, "deck 41 일반 8장 → 영웅 1%, 실패 보상 없음")
	check(int(skill.merge_rule(4).get("SuccessProbability", 0)) == 120000 and int(skill.merge_rule(5).get("SourceAmount", 0)) == 2, "영웅 4장 12%, 전설 2장")
	var stages: Array = []
	for stage: int in range(4): stages.append(int(skill.levelup_row(ICE_CARD, stage).get("Cost", -1)))
	check(stages == [100000, 100000, 100000, -1] and skill.max_stage(ICE_CARD) == 3, "ice spike: 3 stages, cost 100000 each, none at stage 3 (%s)" % str(stages))
	var probabilities: Array = []
	for stage: int in range(3): probabilities.append(skill.levelup_probability(int(skill.levelup_row(ICE_CARD, stage).ID)))
	check(probabilities == [667000, 333000, 167000], "stage probabilities 66.7/33.3/16.7%")
	check(int(skill.feed_row(ICE_CARD).get("Experience", 0)) == 25000 and skill.feed_allowed(1, 1) and not skill.feed_allowed(1, 4), "일반 card feeds 25000 exp, same grade only")
	check(skill.stage_descriptions(ICE_CARD).size() == 4, "UI has 4 stage texts (stage 4 stays empty)")

func seed_roll(rng: RandomNumberGenerator, scale: int, probability: int, success: bool) -> void:
	for value: int in range(1, 200000):
		rng.seed = value
		if (rng.randi_range(0, scale - 1) < probability) == success:
			rng.seed = value
			return

func grant(world: Node, id: int, amount: int) -> String:
	var staged: Dictionary = INVENTORY.stage(world, [{"item_class_id":id, "amount":amount, "bless_raw":1, "enchant":0}], {"kind":"twilight_debug_catalog", "initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok", false), "grant #%d: %s" % [id, str(staged.get("error", ""))]): return ""
	check(world._save_game(true, staged.overrides) == OK, "grant save #%d" % id)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var uid: String = uid_of(world, id)
	return str(world.item_instances[uid].name) if not uid.is_empty() else ""

func uid_of(world: Node, id: int) -> String:
	var ids: Array = world.item_instances.keys(); ids.sort()
	for uid: String in ids:
		if int(world.item_instances[uid].get("record", {}).get("source_item_class_id", -1)) == id: return uid
	return ""

func save_data(world: Node) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	return value if value is Dictionary else {}

func reroll_once(world: Node, category: String, identity: String, pick: String = "") -> Dictionary:
	var quote: Dictionary = world.card523_swap_quote(category, identity)
	if not quote.get("ok", false): return quote
	var done: Dictionary = world.card523_swap_execute(str(quote.token), pick)
	done["quote"] = quote
	return done

func reroll(world: Node) -> void:
	var swap = world.card_swap523
	var cards = world.card_draw_fusion
	var hero: Array = swap.candidates("변신", 4)
	evidence["hero_candidates"] = hero.size()
	check(hero.size() == 40, "변신 영웅 swap-out candidates = 40 (%d)" % hero.size())
	if hero.size() < 3: return
	# Below 영웅: refused (09:23).
	var rare: Array = swap.candidates("변신", 3)
	if not rare.is_empty():
		cards.owned["변신"][str(rare[0].identity)] = true
		var low: Dictionary = world.card523_swap_quote("변신", str(rare[0].identity))
		check(not low.get("ok", true) and str(low.reason).contains("영웅"), "희귀 카드는 거부: %s" % str(low.get("reason","")))
	# A single-copy card (no duplicate), rerolled and confirmed.
	var target: String = str(hero[0].identity)
	cards.owned["변신"][target] = true
	cards.spare["변신"].erase(target)
	world.inventory["다이아"] = 100000
	var first: Dictionary = world.card523_swap_quote("변신", target)
	evidence["quote1"] = {"ok":first.get("ok"), "reason":first.get("reason"), "cost":first.get("cost"), "candidates":first.get("candidate_count"), "last":first.get("uses_last_copy")}
	if not check(first.get("ok", false) and int(first.cost.amount) == 900 and int(first.candidate_count) == 39 and bool(first.uses_last_copy) and (first.pending as Dictionary).is_empty() and not first.has("confirm_token"), "1장뿐인 카드 1회째 견적: 900 다이아, 39장, 대기 결과 없음"): return
	world.patch523_owner_state_problem = "test: save refused"
	var refused: Dictionary = world.card523_swap_execute(str(first.token))
	world.patch523_owner_state_problem = ""
	check(not refused.get("ok", true) and int(world.inventory["다이아"]) == 100000 and swap.swap_count("변신", target) == 0 and swap.state.pending.is_empty(), "save failure keeps diamonds, count and no pending")
	var diamonds: int = 100000
	var spent: Array = []
	var last_pending: String = ""
	for count: int in range(1, 6):
		var done: Dictionary = reroll_once(world, "변신", target)
		if not check(done.get("ok", false), "%d회째 다시 뽑기: %s" % [count, str(done.get("reason", ""))]): return
		spent.append(int(done.cost.amount)); diamonds -= int(done.cost.amount)
		last_pending = str(done.pending.result.identity)
		check(last_pending != target and cards.known_ids["변신"].get(last_pending) == cards.known_ids["변신"][target] and cards.owned["변신"].get(target) == true and swap.swap_count("변신", target) == count, "%d회째: 같은 등급 대기 결과, 원래 카드 그대로" % count)
	check(spent == [900, 2900, 4900, 6900, 9900] and int(world.inventory["다이아"]) == diamonds, "costs 900~9900 deducted from the diamond wallet (%s)" % str(spent))
	var on_disk: Dictionary = save_data(world)
	check(str(on_disk.get("card_swap523", {}).get("pending", {}).get("변신|" + target, {}).get("result", "")) == last_pending and on_disk.get("card_draw_fusion", {}).get("owned", {}).get("변신", {}).get(target) == true, "pending result saved, original still owned in the save")
	# Reload before confirming: the pending result survives.
	swap.state = SWAP.empty_state()
	world._load_game(true)
	swap = world.card_swap523; cards = world.card_draw_fusion
	var after_load: Dictionary = world.card523_swap_quote("변신", target)
	check(str(after_load.get("pending", {}).get("result", {}).get("identity", "")) == last_pending and after_load.get("can_confirm", false) and world.card523_swap_pending().size() >= 1, "reload keeps the pending result and it can be confirmed")
	# 6회째: 5 shown, the picked card becomes the pending result.
	var sixth: Dictionary = world.card523_swap_quote("변신", target)
	var again: Dictionary = world.card523_swap_quote("변신", target)
	evidence["sixth"] = (sixth.get("pick_candidates", []) as Array).map(func(e: Dictionary) -> String: return str(e.name))
	check(sixth.get("ok", false) and int(sixth.pick_count) == 5 and (sixth.pick_candidates as Array).size() == 5 and int(sixth.cost.amount) == 9900 and again.get("pick_candidates") == sixth.get("pick_candidates"), "6회째: 같은 5장, 9900 다이아")
	check(save_data(world).get("card_swap523", {}).get("picks", {}).has("변신|" + target), "the 5 shown candidates are saved when first shown")
	check(not world.card523_swap_execute(str(again.token)).get("ok", true), "6회째 needs a pick")
	var third: Dictionary = world.card523_swap_quote("변신", target)
	var chosen: String = str(third.pick_candidates[2].identity)
	var picked: Dictionary = world.card523_swap_execute(str(third.token), chosen)
	check(picked.get("ok", false) and str(picked.pending.result.identity) == chosen and bool(picked.picked) and cards.owned["변신"].get(target) == true and not cards.owned["변신"].get(chosen, false), "picked card is pending, not yet received")
	var seventh: Dictionary = world.card523_swap_quote("변신", target)
	check(not seventh.get("ok", true) and int(seventh.get("remaining", -1)) == 0 and seventh.get("can_confirm", false), "no 7th reroll, but the pending result can still be confirmed")
	# Confirm: the single copy is replaced by the pending card.
	var confirmed: Dictionary = world.card523_swap_confirm(str(seventh.confirm_token))
	check(confirmed.get("ok", false) and bool(confirmed.used_last_copy) and not cards.owned["변신"].has(target) and cards.owned["변신"].get(chosen) == true and swap.state.pending.is_empty(), "확정: 1장뿐인 원래 카드가 고른 카드로 교체")
	check(not world.card523_swap_confirm(str(seventh.confirm_token)).get("ok", true), "a confirm token works once")
	on_disk = save_data(world)
	check(not on_disk.card_draw_fusion.owned["변신"].has(target) and on_disk.card_draw_fusion.owned["변신"].get(chosen) == true and (on_disk.card_swap523.pending as Dictionary).is_empty() and int(on_disk.card_swap523.counts["변신"][target]) == 6, "save after confirm: replaced card, no pending, count 6")
	# Existing owner state on the last copy: TWILIGHT 근사 — moved to the result card.
	var guarded: String = str(hero[1].identity)
	cards.owned["변신"][guarded] = true; cards.spare["변신"].erase(guarded)
	world.equipped_catalog["변신"] = world.card_swap523.card_record("변신", guarded)
	var awaken: Dictionary = world.skill_awakening.progress.duplicate(true)
	world.skill_awakening.progress.cards[guarded] = {"level":1}
	world.inventory["다이아"] = int(world.inventory.get("다이아", 0)) + 20000
	var carried: Dictionary = world.card523_swap_quote("변신", guarded)
	evidence["progress_quote"] = {"ok":carried.get("ok"), "reason":carried.get("reason",""), "moves":carried.get("progress_moves",{})}
	check(carried.get("ok", false) and bool(carried.get("progress_moves",{}).get("equipped",false)) and (carried.get("progress_moves",{}).get("owners",[]) as Array).has("skill_awakening"), "equipped + skill-awakened last copy: quote ok, lists the moves %s" % str(evidence.progress_quote))
	var moved_swap: Dictionary = reroll_once(world, "변신", guarded)
	var moved_confirm: Dictionary = world.card523_swap_confirm(str(world.card523_swap_quote("변신", guarded).get("confirm_token", "")))
	var moved_to: String = str(moved_confirm.get("result",{}).get("identity",""))
	evidence["progress_moved"] = {"swap":moved_swap.get("ok"), "confirm":moved_confirm.get("ok"), "reason":moved_confirm.get("reason",""), "to":moved_to, "moved":moved_confirm.get("moved_progress",[])}
	check(moved_confirm.get("ok", false) and bool(moved_confirm.used_last_copy) and not moved_to.is_empty() and TwilightCardDrawFusion.card_id(world.equipped_catalog["변신"]) == moved_to and world.skill_awakening.progress.cards.has(moved_to) and not world.skill_awakening.progress.cards.has(guarded), "confirm moves the equipped slot and skill awakening to the result card %s" % str(evidence.progress_moved))
	world.equipped_catalog["변신"] = {}
	world.skill_awakening.progress = awaken
	cards.owned["변신"][guarded] = true
	cards.spare["변신"][guarded] = 1
	var with_spare: Dictionary = reroll_once(world, "변신", guarded)
	var spare_confirm: Dictionary = world.card523_swap_confirm(str(world.card523_swap_quote("변신", guarded).get("confirm_token", "")))
	check(with_spare.get("ok", false) and spare_confirm.get("ok", false) and not bool(spare_confirm.used_last_copy) and cards.owned["변신"].get(guarded) == true and not cards.spare["변신"].has(guarded), "with a duplicate, the duplicate is used and the permanent copy stays")
	# 신화 (ActivateCardAmount 1): one more copy of the same card.
	var myth: Array = swap.candidates("변신", 32)
	evidence["myth_candidates"] = myth.size()
	if check(myth.size() >= 2, "변신 신화 swap-out candidates (%d)" % myth.size()):
		var mythic: String = str(myth[0].identity)
		cards.owned["변신"][mythic] = true
		cards.spare["변신"].erase(mythic)
		world.inventory["다이아"] = 200000
		var short: Dictionary = world.card523_swap_quote("변신", mythic)
		check(not short.get("ok", true) and int(short.get("copies_required", 0)) == 2, "신화 with 1 copy: needs 2 (1 + extra 1)")
		cards.spare["변신"][mythic] = 1
		var myth_done: Dictionary = reroll_once(world, "변신", mythic)
		var myth_confirm: Dictionary = world.card523_swap_confirm(str(world.card523_swap_quote("변신", mythic).get("confirm_token", "")))
		check(myth_done.get("ok", false) and int(world.inventory["다이아"]) == 200000 - 99900 and myth_confirm.get("ok", false) and int(myth_confirm.consumed) == 2 and not cards.owned["변신"].has(mythic), "신화: 99900 다이아, 확정 시 2장(중복 1 + 마지막 1) 소모")
	check(world._save_game(true) == OK, "save before reload")
	var count_before: int = swap.swap_count("변신", target)
	var diamonds_before: int = int(world.inventory.get("다이아", 0))
	swap.state = SWAP.empty_state(); world.inventory["다이아"] = 0
	world._load_game(true)
	check(world.card_swap523.swap_count("변신", target) == count_before and int(world.inventory.get("다이아", 0)) == diamonds_before and not world.card_draw_fusion.owned["변신"].has(target), "reload keeps counts, diamonds and the replaced card")

func skill_cards(world: Node) -> void:
	var cards = world.skill_cards523
	var books: Dictionary = cards._book_items()
	evidence["book_cards"] = books.size()
	if not check(books.has(ICE_CARD), "ice spike has a skill book item (%d cards)" % books.size()): return
	var ice_item: int = int(books[ICE_CARD])
	var name: String = grant(world, ice_item, 40)
	if name.is_empty(): return
	var uid: String = uid_of(world, ice_item)
	world.level = 90
	world.item_use_cooldowns.clear()
	var learned: Dictionary = STACK.try_use(world, name)
	for frame: int in 3: await process_frame
	evidence["learn"] = learned.get("reason", learned.get("message", ""))
	var deck: Array = world.skill_card523_deck()
	if not check(deck.any(func(entry: Dictionary) -> bool: return int(entry.card_id) == ICE_CARD), "learning the book puts the card in the deck (%s)" % str(evidence.learn)): return
	uid = uid_of(world, ice_item)
	check(world.skill_card523_materials(1).any(func(entry: Dictionary) -> bool: return entry.physical_id == uid and int(entry.remaining) == 39), "unused books are materials (39 left)")
	var catalog = world.original_skills.catalog
	var ice: Dictionary = catalog.record_for("아이스 스파이크")
	if not RULES.ensure_loaded(): RULES.load_source(SOURCE.archive_path())
	var base_power: int = int(catalog.resolve(ice).power)
	world.gold = 10000000
	# Stage 0 → 1: 8 cards × 25000 = 200000 exp, 8 × 100000 + 100000 adena.
	var quote: Dictionary = world.skill_card523_levelup_quote(ICE_CARD, {uid:8}, true)
	evidence["levelup1"] = {"ok":quote.get("ok"), "reason":quote.get("reason"), "cost":quote.get("cost"), "exp":quote.get("exp_after_feed"), "p":quote.get("probability")}
	if not check(quote.get("ok", false) and int(quote.cost.amount) == 900000 and int(quote.exp_after_feed) == 200000 and int(quote.probability) == 667000, "1단계 견적: 경험치 200000, 아데나 900000, 66.7%"): return
	seed_roll(cards.rng, 1000000, 667000, true)
	var up: Dictionary = world.skill_card523_levelup_execute(str(quote.token))
	check(up.get("ok", false) and up.success and int(up.level) == 1 and int(world.gold) == 9100000 and int(world.inventory.get(name, 0)) == 31, "강화 성공: 1단계, 아데나·재료 차감")
	var stage1: int = int(catalog.resolve(ice).power)
	evidence["power"] = {"base":base_power, "stage1":stage1, "relic_loaded":RULES.ensure_loaded()}
	check(stage1 == base_power + 5, "1단계 효과: 아이스 스파이크 피해 +5 (SpellBonus MinSpellLevel 1)")
	# Stage 1 → 2 fails: FailureExperience refills the gauge.
	var second: Dictionary = world.skill_card523_levelup_quote(ICE_CARD, {uid:8}, true)
	seed_roll(cards.rng, 1000000, int(second.get("probability", 0)), false)
	var failed: Dictionary = world.skill_card523_levelup_execute(str(second.get("token", "")))
	check(failed.get("ok", false) and not failed.success and int(failed.level) == 1 and int(failed.exp) == 200000 and int(world.gold) == 8200000, "강화 실패: 1단계 유지, FailureExperience 200000")
	var retry: Dictionary = world.skill_card523_levelup_quote(ICE_CARD, {}, true)
	check(retry.get("ok", false) and int(retry.cost.amount) == 100000 and (retry.materials as Array).is_empty(), "retry with the kept gauge costs only the attempt (100000)")
	seed_roll(cards.rng, 1000000, int(retry.get("probability", 0)), true)
	var stage2: Dictionary = world.skill_card523_levelup_execute(str(retry.get("token", "")))
	check(stage2.get("ok", false) and stage2.success and int(stage2.level) == 2 and int(catalog.resolve(ice).power) == base_power + 10, "2단계: 피해 +10")
	var overfeed: Dictionary = world.skill_card523_levelup_quote(ICE_CARD, {uid:9}, false)
	check(overfeed.get("ok", false) and int(overfeed.wasted_exp) == 25000, "overfeeding shows the wasted exp")
	# Synthesis: 8 일반 → 영웅 1%. Failure destroys the materials.
	var before_books: int = int(world.inventory.get(name, 0))
	var merge: Dictionary = world.skill_card523_merge_quote(1, {uid:8})
	evidence["merge"] = {"ok":merge.get("ok"), "reason":merge.get("reason"), "p":merge.get("probability"), "candidates":merge.get("candidate_count")}
	if not check(merge.get("ok", false) and int(merge.source_amount) == 8 and int(merge.probability) == 10000 and int(merge.candidate_count) > 0, "합성 견적: 일반 8장 → 영웅 1%, 마법사 영웅 후보"): return
	for entry: Dictionary in merge.candidates:
		var card: Dictionary = SOURCE.row("BuffCard", int(entry.card_id))
		var mage: bool = SOURCE.related("SpellLearnLimit", "SpellClassID", int(card.SpellClassID)).any(func(limit: Dictionary) -> bool: return int(limit.ClassID) == 3 and limit.IsTutorialSpell == false)
		if not mage or int(card.GradeID) != 4: check(false, "candidate %d is a mage 영웅 card" % int(entry.card_id)); break
	seed_roll(cards.rng, 1000000, 10000, false)
	var lost: Dictionary = world.skill_card523_merge_execute(str(merge.token))
	check(lost.get("ok", false) and not lost.success and int(world.inventory.get(name, 0)) == before_books - 8 and (lost.result as Dictionary).is_empty(), "합성 실패: 재료 8장 소멸, 결과 없음")
	var merge2: Dictionary = world.skill_card523_merge_quote(1, {uid:8})
	seed_roll(cards.rng, 1000000, 10000, true)
	var won: Dictionary = world.skill_card523_merge_execute(str(merge2.get("token", "")))
	evidence["merge_won"] = won.get("result", {})
	check(won.get("ok", false) and won.success and int(world.inventory.get(str(won.result.get("item", "")), 0)) >= 1 and int(world.inventory.get(name, 0)) == before_books - 16, "합성 성공: 영웅 스킬 카드 1장 받음")
	# TWILIGHT 근사: 영웅 스킬 카드 다시 뽑기 (deck 41 RuleSwap 900 다이아, 같은 등급·현재 직업).
	var hero_book: String = str(won.get("result", {}).get("item", ""))
	var hero_uid: String = ""
	for entry: Dictionary in world.skill_cards523.materials(4):
		if str(entry.name) == hero_book: hero_uid = str(entry.physical_id)
	world.inventory["다이아"] = 5000
	var swap_q: Dictionary = world.skill_card523_swap_quote(hero_uid)
	evidence["skill_swap_quote"] = {"ok":swap_q.get("ok"), "reason":swap_q.get("reason",""), "cost":swap_q.get("cost",{}), "candidates":swap_q.get("candidate_count",0)}
	if check(swap_q.get("ok", false) and int(swap_q.cost.amount) == 900 and int(swap_q.candidate_count) > 0, "스킬 카드 다시 뽑기 견적: 영웅 1회째 900 다이아 "+str(evidence.skill_swap_quote)):
		var swapped: Dictionary = world.skill_card523_swap_execute(str(swap_q.token))
		evidence["skill_swap"] = {"ok":swapped.get("ok"), "reason":swapped.get("reason",""), "result":swapped.get("result",{})}
		var result_card: int = int(swapped.get("result",{}).get("card_id",0))
		var mage_ok: bool = SOURCE.related("SpellLearnLimit", "SpellClassID", int(SOURCE.row("BuffCard", result_card).get("SpellClassID", 0))).any(func(limit: Dictionary) -> bool: return int(limit.ClassID) == 3 and limit.IsTutorialSpell == false)
		check(swapped.get("ok", false) and int(world.inventory.get("다이아", 0)) == 4100 and int(world.inventory.get(hero_book, 0)) == 0 and int(world.inventory.get(str(swapped.result.get("item","")), 0)) >= 1 and mage_ok and int(SOURCE.row("BuffCard", result_card).get("GradeID", 0)) == 4 and world.skill_cards523.swap_count(int(swap_q.card_id)) == 1, "다시 뽑기: 다이아 900 차감, 원래 카드 1장 → 같은 등급 마법사 카드 1장, 횟수 1 "+str(evidence.skill_swap))
	var on_disk: Dictionary = save_data(world)
	check(int(on_disk.get("skill_card523", {}).get("swaps", {}).values().size()) >= 1, "save holds the skill card reroll count")
	check(int(on_disk.get("skill_card523", {}).get("cards", {}).get(str(ICE_CARD), {}).get("level", -1)) == 2 and int(on_disk.get("gold", -1)) == int(world.gold), "save holds stage 2 and adena")
	cards.state = SKILL.empty_state(); cards.revision += 1
	check(int(catalog.resolve(ice).power) == base_power, "without the stage the effect is gone")
	world._load_game(true)
	check(world.skill_cards523.level(ICE_CARD) == 2 and int(world.original_skills.catalog.resolve(world.original_skills.catalog.record_for("아이스 스파이크")).power) == base_power + 10, "reload keeps stage 2 and its effect")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer = -100000
	var entered: bool = QA.enter_game(world, "마법사") and world.job_class == "마법사"
	if not entered:
		# Test setup only: a saved character fixes its class, so the class
		# window refuses; the skill-card rules read job_class (as other tests do).
		evidence["class_setup"] = "job_class set directly (character session fixes class)"
		world.job_class = "마법사"; world._update_job_skillbar()
	check(world.job_class == "마법사", "test character is 마법사")
	world.player.set_physics_process(false); world.player.set_auto_enabled(false)
	await reroll(world)
	await skill_cards(world)
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")
	world.queue_free()
	await process_frame

func run() -> void:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="):
			var base: String = value.trim_prefix("--source523-pack=")
			var pack: Script = load("res://scripts/boot/source523_pack.gd")
			var read: Dictionary = pack.read_descriptor(base.path_join("source523_pack.json"))
			pack.apply(pack.selections(base, read.descriptor, pack.read_addons(base)))
			load("res://scripts/maps/current523_host.gd").refresh()
	synthetic()
	if not SOURCE.not_installed() and not SOURCE.identity().is_empty():
		tables()
		await runtime()
	else:
		evidence["runtime"] = "original 523 definitions not installed: table and Main parts skipped"
	print("CARDS523_REROLL_SKILLCARD_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
