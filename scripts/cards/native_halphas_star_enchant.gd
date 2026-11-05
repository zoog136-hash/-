extends RefCounted
## A bounded patch523 contract. Cosmetic selection is never earned progression.
const DATA = preload("res://data/cards/patch523_halphas_star_enchant.json")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const Conditions = preload("res://scripts/cards/source_collection_conditions.gd")
const CATEGORY: String = "변신"
const CARD_ID: int = 24504
const SOURCE_TABLES = ["BuffCard","BuffCardStarEnchantGroup","BuffCardStarEnchantRule","BuffCardStarEnchantBonus","BuffCardSpriteCustomizingOption","Grade","Currency","ServerLimit","ConstantData","ContentsControl","Bonus","BonusType","Unit","BonusApplicationType","SpecialResistanceType","UIUnit","ChargeBonus","ChargeEffectBonus","SpellClass"]
static var _definition: Dictionary = {}
static var _source_identity: Dictionary = {}
static var _source_problem: String = ""
static var _model_sha256: String = ""

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _one(table: String, fields: Dictionary) -> Dictionary:
	var candidates: Array = []
	for field: String in fields:
		if _integer(fields[field]):
			candidates = SOURCE.related(table,field,int(fields[field]))
			break
	if candidates.is_empty(): candidates = SOURCE.rows(table)
	var matches: Array[Dictionary] = []
	for row: Dictionary in candidates:
		var match_fields := true
		for field: String in fields:
			if row.get(field)!=fields[field]: match_fields = false; break
		if match_fields: matches.append(row)
	if matches.size()!=1:
		_source_problem = "halphas_source_reference_missing_or_ambiguous:"+table
		return {}
	if not SOURCE.declared_exclusion(table,matches[0]).is_empty():
		_source_problem = "halphas_source_declared_exclusion:"+table
		return {}
	if table=="SpellClass" and matches[0].get("TestSpell") is bool and matches[0].TestSpell:
		_source_problem = "halphas_source_test_declaration:SpellClass.TestSpell"
		return {}
	return matches[0]

static func _related(table: String, field: String, value: int) -> Array:
	var result: Array = []
	for row: Dictionary in SOURCE.related(table,field,value):
		if not SOURCE.declared_exclusion(table,row).is_empty():
			_source_problem = "halphas_source_declared_exclusion:"+table
			return []
		result.append(row)
	return result

static func _build_definition(identity: Dictionary) -> Dictionary:
	# Exact model projection from build_patch523_halphas_star_enchant.py. The
	# preserved public DATA constant is an ABI/reference, never an input fallback.
	var evidence: Dictionary = {}
	for table: String in SOURCE_TABLES:
		var metadata: Dictionary = SOURCE.table_metadata(table)
		if metadata.is_empty(): _source_problem = "halphas_source_table_unavailable:"+table; return {}
		evidence[table] = {"member":metadata.get("path","content/"+table+".json"),"bytes":metadata.get("bytes",0),"sha256":metadata.get("sha256","")}
	var card: Dictionary = _one("BuffCard",{"ID":CARD_ID})
	if card.is_empty(): return {}
	if card.get("BuffCardDeckID")!=1: _source_problem = "halphas_source_deck_changed"; return {}
	var group: Dictionary = _one("BuffCardStarEnchantGroup",{"BuffCardID":card.ID})
	var control: Dictionary = _one("ContentsControl",{"Name":"BuffCardStarEnchantPolymorph"})
	if group.is_empty() or control.is_empty(): return {}
	if control.get("ServerLimitSetID")!=group.get("ServerLimitsetID"):
		_source_problem = "halphas_source_feature_group_scope_changed"
		return {}
	if SOURCE.rows("BuffCardStarEnchantGroup").size()!=1: _source_problem = "halphas_source_group_review_required"; return {}
	if not _integer(group.get("ID")): _source_problem = "halphas_source_group_id_invalid"; return {}
	var rules: Array = _related("BuffCardStarEnchantRule","GroupID",int(group.ID))
	rules.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.get("Enchant",0)<b.get("Enchant",0))
	var stages: Array = []
	var limits: Array = []
	for value: Variant in [card.get("ServerLimitSetID"),group.get("ServerLimitsetID")]:
		if not _integer(value): _source_problem = "halphas_source_server_scope_invalid"; return {}
		if int(value)!=0 and int(value) not in limits: limits.append(int(value))
	var grade_ids: Array = []
	var currency_ids: Array = []
	for rule: Dictionary in rules:
		stages.append(rule.get("Enchant"))
		for field: String in ["Probability","SourceGradeID","SourceAmount","CurrencyID","CurrencyCost"]:
			if not _integer(rule.get(field)) or rule[field]<=0: _source_problem = "halphas_source_rule_invalid:"+field; return {}
		if not _integer(rule.get("ServerLimitsetID")): _source_problem = "halphas_source_rule_scope_invalid"; return {}
		if int(rule.ServerLimitsetID)!=0 and int(rule.ServerLimitsetID) not in limits: limits.append(int(rule.ServerLimitsetID))
		if int(rule.SourceGradeID) not in grade_ids: grade_ids.append(int(rule.SourceGradeID))
		if int(rule.CurrencyID) not in currency_ids: currency_ids.append(int(rule.CurrencyID))
	if stages!=[1,2,3]: _source_problem = "halphas_source_stages_changed"; return {}
	var limit_rows: Array = []
	var unresolved: Array = []
	# Preserve original ServerLimit order across the selected sets.
	for row: Dictionary in SOURCE.rows("ServerLimit"):
		if row.get("ServerLimitSetID") in limits:
			if not SOURCE.declared_exclusion("ServerLimit",row).is_empty(): _source_problem = "halphas_source_declared_exclusion:ServerLimit"; return {}
			limit_rows.append(row)
	for set_id: int in limits:
		var found := false
		for row: Dictionary in limit_rows:
			if row.get("ServerLimitSetID")==set_id: found = true; break
		if not found: unresolved.append(set_id)
	unresolved.sort()
	var bonuses: Array = _related("BuffCardStarEnchantBonus","GroupID",int(group.ID))
	var effects: Array = []
	for link: Dictionary in bonuses:
		if not _integer(link.get("BonusID")): _source_problem = "halphas_source_bonus_id_invalid"; return {}
		var bonus: Dictionary = _one("Bonus",{"ID":link.BonusID})
		if bonus.is_empty(): return {}
		var type: Dictionary = _one("BonusType",{"ID":bonus.get("BonusTypeID")})
		if type.is_empty(): return {}
		var unit: Dictionary = _one("Unit",{"ID":type.get("UnitID")})
		var ui: Dictionary = _one("UIUnit",{"UnitID":type.get("UnitID")})
		if unit.is_empty() or ui.is_empty(): return {}
		var application: Dictionary = {}
		var target: Dictionary = {}
		if bonus.get("BonusApplicationTypeID")==2:
			application = _one("BonusApplicationType",{"ID":2})
			target = _one("SpecialResistanceType",{"ID":bonus.get("BonusApplicationTargetID")})
			if application.is_empty() or target.is_empty(): return {}
		effects.append({"link":link,"bonus":bonus,"type":type,"unit":unit,"ui_unit":ui,"application_type":application,"application_target":target})
	var charge_steps: Array = _related("ChargeBonus","ChargeID",21)
	var charge_effects: Array = []
	for link: Dictionary in SOURCE.rows("ChargeEffectBonus"):
		if link.get("TargetSpellClassID")!=82: continue
		var step: Dictionary = {}
		for candidate: Dictionary in charge_steps:
			if candidate.get("ID")==link.get("ChargeBonusID"): step = candidate; break
		if step.is_empty(): continue
		if not SOURCE.declared_exclusion("ChargeEffectBonus",link).is_empty(): _source_problem = "halphas_source_declared_exclusion:ChargeEffectBonus"; return {}
		var bonus: Dictionary = _one("Bonus",{"ID":link.get("BonusID")})
		if bonus.is_empty(): return {}
		var type: Dictionary = _one("BonusType",{"ID":bonus.get("BonusTypeID")})
		if type.is_empty(): return {}
		charge_effects.append({"step":step.get("Step"),"link":link,"bonus":bonus,"type":type})
	var charge_spell: Dictionary = _one("SpellClass",{"ID":82})
	var charge_constants: Array = []
	for name: String in ["ChargeLongPressTriggerTime","ChargeMaxTime","ChargeMinTime"]:
		var row: Dictionary = _one("ConstantData",{"Name":name})
		if row.is_empty(): return {}
		charge_constants.append(row)
	var max_level: Dictionary = _one("ConstantData",{"Name":"StarEnchantMaxLevel"})
	var options: Array = _related("BuffCardSpriteCustomizingOption","BuffCardID",CARD_ID)
	var grades: Array = []
	grade_ids.sort()
	for id: int in grade_ids:
		var row: Dictionary = _one("Grade",{"ID":id})
		if row.is_empty(): return {}
		grades.append(row)
	var currencies: Array = []
	currency_ids.sort()
	for id: int in currency_ids:
		var row: Dictionary = _one("Currency",{"ID":id})
		if row.is_empty(): return {}
		currencies.append(row)
	if charge_spell.is_empty() or max_level.is_empty() or not _source_problem.is_empty(): return {}
	return {"schema":1,"source_snapshot":"patch523","archive_sha256":identity.get("source_sha256",""),"source_tables":evidence,
		"card":card,"group":group,"rules":rules,"content_control":control,"effects":effects,
		"charge":{"spell":charge_spell,"steps":charge_steps,"effects":charge_effects,"constants":charge_constants},
		"bonuses":bonuses,"sprite_options":options,"grades":grades,"currencies":currencies,"max_level":max_level,
		"server_limits":limit_rows,"unresolved_server_limit_sets":unresolved,
		"unresolved_semantics":["probability_scale","material_deck_and_duplicate_policy","failure_stage_and_target_policy","stage_bonus_aggregation"],
		"execution":"blocked_pending_source_semantics"}

static func definition() -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty():
		_definition = {}; _source_identity = {}; _model_sha256 = ""
		_source_problem = "halphas_current523_unavailable:"+SOURCE.problem()
		return {}
	if identity==_source_identity and not _definition.is_empty(): return _definition.duplicate(true)
	_source_problem = ""
	var candidate: Dictionary = _build_definition(identity)
	if candidate.is_empty():
		_definition = {}; _source_identity = {}; _model_sha256 = ""
		return {}
	_definition = candidate
	_source_identity = identity.duplicate(true)
	_model_sha256 = JSON.stringify(candidate,"",true,true).sha256_text()
	return _definition.duplicate(true)

static func input_status() -> Dictionary:
	var active: Dictionary = definition()
	return {"available":not active.is_empty(),"source_mode":"current523_original","source_identity":_source_identity.duplicate(true),"model_sha256":_model_sha256,"problem":_source_problem}

static func is_target(category: String, record: Dictionary) -> bool:
	var source: Dictionary = definition()
	return not source.is_empty() and category == CATEGORY and record.get("source", "") == "lineagem_base508" and record.get("source_card_id", -1) == CARD_ID and record.get("sourceId", "") == "m508:1:24504" and record.get("source_deck_id", -1) == 1 and record.get("source_original_card", {}) == source.card

static func snapshot(category: String, record: Dictionary, cards: Dictionary, gold: int, context: Dictionary = {}) -> Dictionary:
	if not is_target(category, record):
		return {"ok": false, "code": "not_halphas", "error": "이 카드에는 성급 강화 규칙이 없습니다", "can_attempt": false}
	var identity: String = Cards.card_id(record)
	if identity.is_empty():
		return {"ok": false, "code": "identity_missing", "error": "카드 정체성 확인 실패", "can_attempt": false}
	var source_definition: Dictionary = definition()
	var conditions = Conditions.new()
	conditions.configure(source_definition.server_limits)
	var evaluations: Array[Dictionary] = []
	var problems: Array[String] = []
	var control: Dictionary = source_definition.content_control
	if control.get("Enable") != true: problems.append("source_feature_disabled")
	var owned: bool = cards.get("owned", {}).get(category, {}).get(identity, false) == true
	if not owned: problems.append("not_owned")
	# Preserve card and group restrictions separately. An empty set is unknown,
	# never a server-wide permission, even if a caller supplies a context.
	for set_id: int in [int(source_definition.card.ServerLimitSetID), int(source_definition.group.ServerLimitsetID)]:
		var evaluation: Dictionary = conditions.evaluate(set_id, context)
		evaluation["set_id"] = set_id
		evaluations.append(evaluation)
		if evaluation.status not in ["eligible", "unrestricted"]:
			var code: String = "server_" + str(evaluation.status)
			if not problems.has(code): problems.append(code)
	var stages: Array[Dictionary] = []
	for raw: Dictionary in source_definition.rules:
		var row: Dictionary = raw.duplicate(true)
		row["affordable"] = gold >= int(row.CurrencyCost)
		row["bonus_reference_count"] = 0
		for bonus: Dictionary in source_definition.bonuses:
			if int(bonus.Enchant) == int(row.Enchant): row.bonus_reference_count += 1
		row["sprite_options"] = []
		for option: Dictionary in source_definition.sprite_options:
			if int(option.StarEnchant) == int(row.Enchant): row.sprite_options.append(option.duplicate(true))
		stages.append(row)
	for unresolved: String in source_definition.unresolved_semantics:
		problems.append(unresolved)
	return {"ok": true, "category": category, "identity": identity, "card_id": CARD_ID,
		"owned": owned, "stages": stages, "max_stage": int(source_definition.max_level.Value),
		"earned_stage": null, "stage_status": "no_authoritative_progression_ledger",
		"server_evaluations": evaluations, "problems": problems, "feature_control": control.duplicate(true),
		"can_attempt": false, "blocked_reason": "원본 설정에서 성급 강화가 비활성으로 기록돼 있습니다. 카드와 아데나는 소모되지 않습니다." if problems.has("source_feature_disabled") else "강화 조건을 확인 중입니다. 카드와 아데나는 소모되지 않습니다.",
		"source_snapshot": "patch523"}

static func attempt(category: String, record: Dictionary, cards: Dictionary, gold: int, context: Dictionary = {}) -> Dictionary:
	var view: Dictionary = snapshot(category, record, cards, gold, context)
	if not view.ok: return view
	# Do not roll, spend, advance, apply bonuses, or save with unresolved rules.
	# In particular, source_visual_context.active_card_options is not a ledger.
	return {"ok": false, "code": "source_feature_disabled" if view.problems.has("source_feature_disabled") else "source_contract_unresolved", "error": view.blocked_reason, "snapshot": view}

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
