extends RefCounted
## A bounded patch523 contract. Cosmetic selection is never earned progression.
const DATA = preload("res://data/cards/patch523_halphas_star_enchant.json")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const Conditions = preload("res://scripts/cards/source_collection_conditions.gd")
const CATEGORY: String = "변신"
const CARD_ID: int = 24504

static func is_target(category: String, record: Dictionary) -> bool:
	return category == CATEGORY and record.get("source", "") == "lineagem_base508" and record.get("source_card_id", -1) == CARD_ID and record.get("sourceId", "") == "m508:1:24504" and record.get("source_deck_id", -1) == 1 and record.get("source_original_card", {}) == DATA.data.card

static func snapshot(category: String, record: Dictionary, cards: Dictionary, gold: int, context: Dictionary = {}) -> Dictionary:
	if not is_target(category, record):
		return {"ok": false, "code": "not_halphas", "error": "이 카드에는 성급 강화 규칙이 없습니다", "can_attempt": false}
	var identity: String = Cards.card_id(record)
	if identity.is_empty():
		return {"ok": false, "code": "identity_missing", "error": "카드 정체성 확인 실패", "can_attempt": false}
	var definition: Dictionary = DATA.data
	var conditions = Conditions.new()
	conditions.configure(definition.server_limits)
	var evaluations: Array[Dictionary] = []
	var problems: Array[String] = []
	var owned: bool = cards.get("owned", {}).get(category, {}).get(identity, false) == true
	if not owned: problems.append("not_owned")
	# Preserve card and group restrictions separately. An empty set is unknown,
	# never a server-wide permission, even if a caller supplies a context.
	for set_id: int in [int(definition.card.ServerLimitSetID), int(definition.group.ServerLimitsetID)]:
		var evaluation: Dictionary = conditions.evaluate(set_id, context)
		evaluation["set_id"] = set_id
		evaluations.append(evaluation)
		if evaluation.status not in ["eligible", "unrestricted"]:
			var code: String = "server_" + str(evaluation.status)
			if not problems.has(code): problems.append(code)
	var stages: Array[Dictionary] = []
	for raw: Dictionary in definition.rules:
		var row: Dictionary = raw.duplicate(true)
		row["affordable"] = gold >= int(row.CurrencyCost)
		row["bonus_reference_count"] = 0
		for bonus: Dictionary in definition.bonuses:
			if int(bonus.Enchant) == int(row.Enchant): row.bonus_reference_count += 1
		row["sprite_options"] = []
		for option: Dictionary in definition.sprite_options:
			if int(option.StarEnchant) == int(row.Enchant): row.sprite_options.append(option.duplicate(true))
		stages.append(row)
	for unresolved: String in definition.unresolved_semantics:
		problems.append(unresolved)
	return {"ok": true, "category": category, "identity": identity, "card_id": CARD_ID,
		"owned": owned, "stages": stages, "max_stage": int(definition.max_level.Value),
		"earned_stage": null, "stage_status": "no_authoritative_progression_ledger",
		"server_evaluations": evaluations, "problems": problems,
		"can_attempt": false, "blocked_reason": "강화 조건을 확인 중입니다. 카드와 아데나는 소모되지 않습니다.",
		"source_snapshot": "patch523"}

static func attempt(category: String, record: Dictionary, cards: Dictionary, gold: int, context: Dictionary = {}) -> Dictionary:
	var view: Dictionary = snapshot(category, record, cards, gold, context)
	if not view.ok: return view
	# Do not roll, spend, advance, apply bonuses, or save with unresolved rules.
	# In particular, source_visual_context.active_card_options is not a ledger.
	return {"ok": false, "code": "source_contract_unresolved", "error": view.blocked_reason, "snapshot": view}

static func from_world(world: Node, category: String, identity: String, is_attempt: bool = false) -> Dictionary:
	if world == null or category != CATEGORY:
		return {"ok": false, "code": "not_halphas", "error": "성급 강화 대상이 아닙니다", "can_attempt": false}
	var matches: Array[Dictionary] = []
	for record: Dictionary in world.catalog_db.get(category, []):
		if Cards.card_id(record) == identity: matches.append(record)
	if matches.size() != 1:
		return {"ok": false, "code": "identity_missing", "error": "카드 정체성 확인 실패", "can_attempt": false}
	var context: Dictionary = world.card_collections.source_server_context()
	var state: Dictionary = world.card_draw_fusion.export_state()
	if is_attempt: return attempt(category, matches[0], state, int(world.gold), context)
	return snapshot(category, matches[0], state, int(world.gold), context)
