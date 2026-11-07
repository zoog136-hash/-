extends RefCounted

# Patch523 facts are read from canonical Content tables. Server dispatch is not
# present there: these two policies are explicit, adjustable TWILIGHT rules.
# Official dragon protection/reuse rules: article 5c7ea4a0d389e900016e28fe,
# article 50211207; grace behavior: lounge feed68828 and probability category
# 6a02882bbaf6a619213b5843. No shop, timer, inventory, or save is owned here.
var protection_dispatch: Dictionary = {1: 54252, 14: 66574}
var test_protection_dispatch: Dictionary = {197781: 67731, 255643: 67731}
var stack_set_thresholds: bool = true

const RECHARGER_CATEGORY: int = 10291
const SCROLL_CURRENCY: int = 2964
const ADENA_CURRENCY: int = 1
const REUSE_WINDOW: int = 86400
const RNG_MODULUS: int = 2147483647
const STAT_KEYS: Dictionary = {
	1: "melee_damage", 2: "melee_accuracy", 4: "magic_damage",
	10: "ranged_damage", 11: "ranged_accuracy", 17: "max_hp", 21: "armor_class",
	34: "move_speed_bonus", 35: "attack_speed_bonus", 37: "magic_accuracy",
	112: "damage_reduction", 127: "hp_potion_recovery_pct", 133: "exp_bonus_pct",
	140: "cast_speed_bonus", 4544: "pve_damage_reduction",
	4581: "damage_reduction_ignore", 5681: "ignore_melee_damage_reduction_pct",
	5691: "ignore_ranged_damage_reduction_pct", 5701: "ignore_magic_damage_reduction_pct",
	7304: "undead_additional_max_damage", 7818: "pvp_damage_reduction_pct",
	11134: "pvp_damage_reduction_ignore_pct"
}

var _source: Object
var _tables: Dictionary = {}
var _indices: Dictionary = {}
var _jade: Dictionary = {}
var _grail: Dictionary = {}
var _item_bonuses: Dictionary = {}
var _buff_bonuses: Dictionary = {}
var _pools: Dictionary = {}
var _set_prefixes: Dictionary = {}
var _set_bonuses: Dictionary = {}
var _scroll_id: int = 0

func setup(source: Object) -> void:
	_source = source
	_tables.clear()
	_indices.clear()
	_jade.clear()
	_grail.clear()
	_item_bonuses.clear()
	_buff_bonuses.clear()
	_pools.clear()
	_set_prefixes.clear()
	_set_bonuses.clear()
	_scroll_id = 0
	# ItemBonus/BuffBonus links are looked up per item/buff (_links) instead of
	# indexing all 89,702 + 34,623 rows here (~0.4 GB with the original installed).
	for item: Dictionary in _rows("ItemClass"):
		var item_id: int = int(item.get("ID", 0))
		if int(item.get("CategoryID", 0)) == RECHARGER_CATEGORY:
			var duration: int = 0
			var subscription: int = 0
			var delete_time: int = 0
			for link: Dictionary in _links("ItemBonus", "ItemClassID", item_id):
				var bonus: Dictionary = _row("Bonus", int(link.get("BonusID", 0)))
				match int(bonus.get("BonusTypeID", 0)):
					109: duration = int(bonus.get("Value", 0))
					3851: subscription = int(bonus.get("Value", 0))
					492: delete_time = int(bonus.get("Value", 0))
			if duration > 0 and subscription > 0:
				_jade[item_id] = {"item_id": item_id, "duration": duration,
					"subscription": subscription, "delete_time": delete_time}
		for grace: Dictionary in _rows("ItemGrace"):
			if int(item.get("CategoryID", 0)) == int(grace.get("ItemCategoryID", -1)) and int(item.get("GradeID", 0)) == int(grace.get("GradeID", -1)):
				_grail[item_id] = int(grace.get("ID", 0))
	for link: Dictionary in _rows("CurrencyUnitClass"):
		if int(link.get("CurrencyID", 0)) == SCROLL_CURRENCY and int(link.get("UnitID", 0)) == 4 and not bool(link.get("ForGive", true)):
			_scroll_id = int(link.get("ClassID", 0))
	for link: Dictionary in _rows("ItemGraceBonus"):
		var prefix: Dictionary = _row("ItemGracePrefix", int(link.get("GracePrefixID", 0)))
		var pool_key: String = "%d:%d" % [int(link.get("GraceID", 0)), int(prefix.get("SlotNumber", 0))]
		_append(_pools, pool_key, link)
	for link: Dictionary in _rows("ItemGracePrefixForSet"):
		_append(_set_prefixes, int(link.get("GraceSetID", 0)), int(link.get("GracePrefixID", 0)))
	for link: Dictionary in _rows("ItemGraceSetBonus"):
		_append(_set_bonuses, int(link.get("GraceSetID", 0)), link)

func _links(table: String, field: String, id: int) -> Array:
	if _source == null or id == 0: return []
	if _source.has_method("find_rows"): return _source.call("find_rows", table, field, id)
	var result: Array = []
	for row: Variant in _source.call("rows", table):
		if row is Dictionary and _same_id(row.get(field), id): result.append(row)
	return result

static func _same_id(value: Variant, id: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(id)

func initial_state() -> Dictionary:
	return {"version": 1, "rng_state": 52371, "latest_at": 0, "jade": {}, "grails": {}}

func is_grail_item(item_id: int) -> bool:
	return _grail.has(item_id)

func validate_state(value: Variant) -> String:
	if not value is Dictionary:
		return "jade_grail_state_not_dictionary"
	var state: Dictionary = value
	if not _integer(state.get("version"), 1, 1) or not _integer(state.get("rng_state"), 1, RNG_MODULUS - 1) or not _integer(state.get("latest_at"), 0, 253402300799):
		return "jade_grail_state_header_invalid"
	if not state.get("jade") is Dictionary or not state.get("grails") is Dictionary:
		return "jade_grail_state_sections_invalid"
	var jade: Dictionary = state.jade
	if not jade.is_empty():
		if not _integer(jade.get("item_id"), 1) or not _jade.has(int(jade.item_id)):
			return "jade_source_item_invalid"
		var definition: Dictionary = _jade[int(jade.item_id)]
		if not _integer(jade.get("used_at"), 1, int(state.latest_at)) or not _integer(jade.get("duration"), 1) or int(jade.duration) != int(definition.duration) or not _integer(jade.get("subscription"), 1) or int(jade.subscription) != int(definition.subscription):
			return "jade_source_metadata_invalid"
	for key: Variant in state.grails:
		if not key is String or str(key).is_empty() or not state.grails[key] is Dictionary:
			return "grail_instance_invalid"
		var grace: Dictionary = state.grails[key]
		if not _integer(grace.get("item_id"), 1) or not _grail.has(int(grace.item_id)):
			return "grail_source_item_invalid"
		if not _integer(grace.get("grace_id"), 1) or int(grace.grace_id) != int(_grail[int(grace.item_id)]):
			return "grail_source_grade_invalid"
		if not _integer(grace.get("absolute_prefix_id"), 0) or not _integer(grace.get("base_prefix_id"), 1):
			return "grail_prefix_invalid"
		if int(grace.absolute_prefix_id) != 0 and _prefix_link(int(grace.grace_id), int(grace.absolute_prefix_id), 1).is_empty():
			return "grail_absolute_prefix_invalid"
		if _prefix_link(int(grace.grace_id), int(grace.base_prefix_id), 2).is_empty():
			return "grail_base_prefix_invalid"
	return ""

func view(context: Dictionary, state: Dictionary) -> Dictionary:
	var rows: Array = []
	var error: String = validate_state(state)
	if not error.is_empty():
		return {"title": "용옥 · 성배 은총", "notes": [error], "rows": rows}
	var effective_context: Dictionary = context.duplicate(true)
	effective_context.nowUnix = maxi(int(context.get("nowUnix", 0)), int(state.latest_at))
	effective_context.now = effective_context.nowUnix
	var status: Dictionary = jade_status(effective_context, state)
	rows.append({"id": "jade_status", "label": "드래곤의 보호", "detail": "남은 시간 %d초 · 보호 단계 %d · 경험치 ×%.1f · 아데나 ×%.1f" % [status.remaining, status.protection_level, status.exp_multiplier, status.adena_multiplier], "actions": []})
	for item_id: Variant in _jade:
		if _count(context.get("owned", {}), int(item_id)) <= 0:
			continue
		var item: Dictionary = _row("ItemClass", int(item_id))
		var definition: Dictionary = _jade[item_id]
		var reason: String = _jade_eligibility(int(item_id), effective_context)
		if reason.is_empty() and int(status.remaining) > REUSE_WINDOW:
			reason = "jade_reuse_requires_final_24_hours"
		var actions: Array = []
		if reason.is_empty():
			actions.append({"label": "용옥 사용", "request": {"op": "jade_use", "item_id": int(item_id)}, "costs":[{"kind":"item","id":int(item_id),"amount":1}]})
		rows.append({"id": "jade:%d" % int(item_id), "label": str(item.get("Name", item_id)), "detail": "원본 지속 %d초 · 보유 %d%s" % [int(definition.duration), _count(context.get("owned", {}), int(item_id)), " · " + reason if not reason.is_empty() else ""], "actions": actions})
	var owned_grails: Dictionary = _owned_grails(effective_context)
	for instance_id: Variant in owned_grails:
		var instance: Dictionary = owned_grails[instance_id]
		var item_id: int = int(instance.sourceID)
		var grace_id: int = int(_grail[item_id])
		var saved: Dictionary = state.grails.get(str(instance_id), {})
		var detail: String = "소지 효과 · 은총 없음" if saved.is_empty() else "소지 효과 · %s %s" % [_prefix_name(int(saved.absolute_prefix_id)), _prefix_name(int(saved.base_prefix_id))]
		var cost: Dictionary = _grace_cost(grace_id)
		detail += " · 주문서 %d / 아데나 %d" % [int(cost.get("ScrollConsumeAmount", 0)), int(cost.get("AdenaCost", 0))]
		rows.append({"id": "grail:" + str(instance_id), "label": str(_row("ItemClass", item_id).get("Name", item_id)) + " #" + str(instance_id), "detail": detail, "actions": [{"label": "은총 부여 / 교체", "request": {"op": "grail_roll", "instance_id": str(instance_id)},"costs":[{"kind":"item","id":_scroll_id,"amount":int(cost.get("ScrollConsumeAmount",0))},{"kind":"currency","id":ADENA_CURRENCY,"amount":int(cost.get("AdenaCost",0))}]}]})
	return {"title": "용옥 · 성배 은총", "notes": ["용옥 재사용은 남은 24시간 이내, 새 사용 시점부터 원본 지속시간으로 교체됩니다.", "성배 소지 효과 · 기본 은총 확정 · 절대 은총 40% · 재부여 시 교체", "서버 구독→보호 연결 및 2/4세트 누적은 조정 가능한 TWILIGHT 규칙입니다."], "rows": rows}

func propose(request: Dictionary, context: Dictionary, state: Dictionary) -> Dictionary:
	var error: String = validate_state(state)
	if not error.is_empty():
		return _fail(error)
	if not _integer(context.get("nowUnix"), 1, 253402300799):
		return _fail("clock_invalid")
	var now: int = int(context.nowUnix)
	if now < int(state.latest_at):
		return _fail("clock_rollback")
	if str(context.get("region", "KR")) != "KR":
		return _fail("unsupported_region")
	var staged: Dictionary = state.duplicate(true)
	staged.latest_at = now
	var op: String = str(request.get("op", ""))
	if op == "observe":
		return _success(staged, [])
	if op == "jade_use":
		if not _integer(request.get("item_id"), 1):
			return _fail("jade_source_item_invalid")
		var item_id: int = int(request.item_id)
		error = _jade_eligibility(item_id, context)
		if not error.is_empty():
			return _fail(error)
		if _count(context.get("owned", {}), item_id) < 1:
			return _fail("jade_not_owned")
		if not context.get("ain") is Dictionary:
			return _fail("ain_state_unavailable")
		var ain: Dictionary = context.ain.duplicate(true)
		if not _integer(ain.get("dragon_orb_expires_at", 0), 0, 253402300799):
			return _fail("jade_expiry_invalid")
		if int(ain.get("dragon_orb_expires_at", 0)) - now > REUSE_WINDOW:
			return _fail("jade_reuse_requires_final_24_hours")
		var definition: Dictionary = _jade[item_id]
		ain.dragon_orb_expires_at = now + int(definition.duration)
		staged.jade = {"item_id": item_id, "subscription": int(definition.subscription), "duration": int(definition.duration), "used_at": now}
		var proposal: Dictionary = _success(staged, [{"kind": "item", "id": item_id, "amount": 1}])
		proposal.ain = ain
		return proposal
	if op != "grail_roll":
		return _fail("unknown_jade_grail_request")
	var instance_id: String = str(request.get("instance_id", ""))
	var instances: Dictionary = _owned_grails(context)
	if not instances.has(instance_id):
		return _fail("grail_physical_instance_not_owned")
	var item_id: int = int(instances[instance_id].sourceID)
	var grace_id: int = int(_grail[item_id])
	error = _item_eligibility(_row("ItemClass", item_id), context)
	if not error.is_empty():
		return _fail(error)
	var cost: Dictionary = _grace_cost(grace_id)
	if _scroll_id <= 0 or cost.is_empty() or int(cost.get("ScrollConsumeAmount", 0)) <= 0 or int(cost.get("AdenaCost", 0)) < 0:
		return _fail("grail_source_cost_unavailable")
	var scrolls: int = int(cost.ScrollConsumeAmount)
	var adena: int = int(cost.AdenaCost)
	if _count(context.get("owned", {}), _scroll_id) < scrolls or _count(context.get("currencies", {}), ADENA_CURRENCY) < adena:
		return _fail("grail_insufficient_cost")
	for slot: int in [1, 2]:
		error = _validate_pool(grace_id, slot)
		if not error.is_empty():
			return _fail(error)
	var absolute_prefix: int = _roll_prefix(grace_id, 1, staged)
	var base_prefix: int = _roll_prefix(grace_id, 2, staged)
	staged.grails[instance_id] = {"item_id": item_id, "grace_id": grace_id, "absolute_prefix_id": absolute_prefix, "base_prefix_id": base_prefix}
	return _success(staged, [{"kind": "item", "id": _scroll_id, "amount": scrolls}, {"kind": "currency", "id": ADENA_CURRENCY, "amount": adena}])

func jade_status(context: Dictionary, state: Dictionary) -> Dictionary:
	var result: Dictionary = {"active": false, "remaining": 0, "protection_level": 0, "effective_level": 0, "buff_id": 0, "exp_multiplier": 1.0, "adena_multiplier": 1.0, "protected_drops": false, "dispatch": "TWILIGHT adjustable subscription→protection mapping"}
	if not validate_state(state).is_empty():
		result.error = "jade_grail_state_invalid"
		return result
	var now: int = maxi(int(context.get("nowUnix", 0)), int(state.latest_at))
	var ain: Dictionary = context.get("ain", {}) if context.get("ain", {}) is Dictionary else {}
	var expiry: int = int(ain.get("dragon_orb_expires_at", 0))
	result.remaining = maxi(0, expiry - now)
	var blessing: int = int(ain.get("blessing", 0))
	var ordinary_level: int = 2 if blessing >= 201 else 1 if blessing > 0 else 0
	result.effective_level = ordinary_level
	if int(result.remaining) > 0:
		var jade: Dictionary = state.jade
		var buff_id: int = int(protection_dispatch.get(1, 0))
		# Old monthly purchases retain the existing normal protection contract.
		# Metadata only identifies this timer when the host's single expiry matches.
		if not jade.is_empty() and int(jade.used_at) + int(jade.duration) == expiry:
			buff_id = _protection_buff(int(jade.item_id), int(jade.subscription))
		result.buff_id = buff_id
		var buff: Dictionary = _row("BuffClass", buff_id)
		var erase_level: int = int(buff.get("EraseOnLevel", 0))
		if erase_level <= 0 or int(context.get("level", 1)) < erase_level:
			for link: Dictionary in _links("BuffBonus", "BuffClassID", buff_id):
				var bonus: Dictionary = _row("Bonus", int(link.get("BonusID", 0)))
				if int(bonus.get("BonusTypeID", 0)) == 3632:
					result.protection_level = int(bonus.get("Value", 0))
		result.active = int(result.protection_level) > 0
		result.effective_level = maxi(ordinary_level, int(result.protection_level))
	for benefit: Dictionary in _rows("EinasadBenefit"):
		if int(benefit.get("Level", -1)) != int(result.effective_level):
			continue
		match int(benefit.get("EinasadBenefitTypeID", 0)):
			2: result.exp_multiplier = 1.0 + float(benefit.get("Value", 0)) / 100.0
			12: result.adena_multiplier = 1.0 + float(benefit.get("Value", 0)) / 100.0
	result.protected_drops = int(result.effective_level) > 0
	return result

func bonuses(context: Dictionary, state: Dictionary) -> Dictionary:
	var result: Dictionary = {"stats": {}, "conditional_stats": {"undead": {}, "pvp": {}}, "effects": [], "unsupported": [], "sets": [], "jade": jade_status(context, state)}
	var error: String = validate_state(state)
	if not error.is_empty():
		result.unsupported.append({"reason": error})
		return result
	var effective_context: Dictionary = context.duplicate(true)
	effective_context.nowUnix = maxi(int(context.get("nowUnix", 0)), int(state.latest_at))
	effective_context.now = effective_context.nowUnix
	var owned: Dictionary = _owned_grails(effective_context)
	var qualified: Dictionary = {}
	for instance_id: Variant in owned:
		var item_id: int = int(owned[instance_id].sourceID)
		if not _item_eligibility(_row("ItemClass", item_id), effective_context).is_empty():
			continue
		for link: Dictionary in _links("ItemBonus", "ItemClassID", item_id):
			if bool(link.get("IsPossession", false)):
				_add_effect(result, int(link.get("BonusID", 0)), effective_context, {"origin": "possession", "instance_id": str(instance_id)})
		var grace: Dictionary = state.grails.get(str(instance_id), {})
		if grace.is_empty() or int(grace.item_id) != item_id:
			continue
		for prefix: int in [int(grace.absolute_prefix_id), int(grace.base_prefix_id)]:
			if prefix > 0:
				var link: Dictionary = _prefix_link(int(grace.grace_id), prefix, int(_row("ItemGracePrefix", prefix).get("SlotNumber", 0)))
				_add_effect(result, int(link.get("BonusID", 0)), effective_context, {"origin": "grace", "instance_id": str(instance_id), "prefix_id": prefix})
		for grace_set: Dictionary in _rows("ItemGraceSet"):
			var set_id: int = int(grace_set.get("ID", 0))
			if int(grace_set.get("GraceID", 0)) != int(grace.grace_id):
				continue
			var requirements: Array = _set_prefixes.get(set_id, [])
			if requirements.size() != 2:
				continue
			if int(grace.absolute_prefix_id) in requirements and int(grace.base_prefix_id) in requirements:
				qualified[set_id] = int(qualified.get(set_id, 0)) + 1
	for set_id: Variant in qualified:
		var count: int = int(qualified[set_id])
		var highest: int = 0
		for link: Dictionary in _set_bonuses.get(set_id, []):
			if int(link.get("ItemCount", 0)) <= count:
				highest = maxi(highest, int(link.get("ItemCount", 0)))
		var active_thresholds: Array = []
		for link: Dictionary in _set_bonuses.get(set_id, []):
			var threshold: int = int(link.get("ItemCount", 0))
			if threshold <= 0 or threshold > count or (not stack_set_thresholds and threshold != highest):
				continue
			if not threshold in active_thresholds:
				active_thresholds.append(threshold)
			_add_effect(result, int(link.get("BonusID", 0)), effective_context, {"origin": "set", "set_id": int(set_id), "threshold": threshold})
		result.sets.append({"set_id": int(set_id), "count": count, "thresholds": active_thresholds, "policy": "TWILIGHT cumulative thresholds" if stack_set_thresholds else "TWILIGHT highest threshold"})
	return result

func _add_effect(result: Dictionary, bonus_id: int, context: Dictionary, metadata: Dictionary) -> void:
	if bonus_id == 0:
		return
	var bonus: Dictionary = _row("Bonus", bonus_id)
	var type_id: int = int(bonus.get("BonusTypeID", 0))
	var bonus_type: Dictionary = _row("BonusType", type_id)
	var effect: Dictionary = metadata.duplicate(true)
	effect.merge({"bonus_id": bonus_id, "type_id": type_id, "raw_value": bonus.get("Value", 0), "unit_id": int(bonus_type.get("UnitID", 0)), "applied": false})
	if type_id == 12338:
		effect.policy = "CanOverlapPossession"
		effect.applied = true
		result.effects.append(effect)
		return
	var reason: String = ""
	if bonus.is_empty() or bonus_type.is_empty() or not STAT_KEYS.has(type_id):
		reason = "unsupported_source_bonus"
	elif int(bonus.get("BonusApplicationTypeID", 0)) != 0 or int(bonus.get("BonusApplicationTargetID", 0)) != 0:
		reason = "unsupported_bonus_application_context"
	var stat_key: String = str(STAT_KEYS.get(type_id, ""))
	var value: float = float(bonus.get("Value", 0))
	if int(bonus_type.get("UnitID", 0)) == 3:
		value /= 10000.0
	effect.key = stat_key
	effect.value = value
	# Source names encode these scopes even when application IDs are both zero.
	# Keep a canonical target-only view; the host chooses a real combat target.
	effect.application_type_id = int(bonus.get("BonusApplicationTypeID", 0))
	effect.application_target_id = int(bonus.get("BonusApplicationTargetID", 0))
	var condition: String = "undead" if type_id == 7304 else "pvp" if type_id in [7818, 11134] else ""
	effect.condition = condition
	if reason.is_empty() and not condition.is_empty():
		_sum(result.conditional_stats[condition], stat_key, value)
		if not bool(context.get(condition, false)):
			reason = condition + "_context_required"
	if reason.is_empty():
		_sum(result.stats, stat_key, value)
		effect.applied = true
	else:
		effect.reason = reason
		result.unsupported.append(effect.duplicate(true))
	result.effects.append(effect)

func _jade_eligibility(item_id: int, context: Dictionary) -> String:
	if not _jade.has(item_id):
		return "item_is_not_subscription_recharger"
	var error: String = _item_eligibility(_row("ItemClass", item_id), context)
	if not error.is_empty():
		return error
	var definition: Dictionary = _jade[item_id]
	var deletion: int = int(definition.delete_time)
	if deletion > 0:
		var text: String = str(deletion)
		if text.length() != 10:
			return "source_delete_time_unresolved"
		# Source Unit162 Time encodes YYYYMMDDHH here. TWILIGHT resolves KR
		# calendar cutoffs with the service timezone (UTC+9), configurable by host.
		var zone: Dictionary = context.get("time_policy", {}) if context.get("time_policy", {}) is Dictionary else {}
		var offset_minutes: int = int(zone.get("utc_offset_minutes", 540))
		var timestamp: int = int(Time.get_unix_time_from_datetime_string("%s-%s-%sT%s:00:00" % [text.substr(0, 4), text.substr(4, 2), text.substr(6, 2), text.substr(8, 2)])) - offset_minutes * 60
		if timestamp <= 0:
			return "source_delete_time_unresolved"
		if int(context.get("nowUnix", 0)) >= timestamp:
			return "source_item_expired"
	var buff_id: int = _protection_buff(item_id, int(definition.subscription))
	var buff: Dictionary = _row("BuffClass", buff_id)
	if buff_id <= 0 or buff.is_empty() or _links("BuffBonus", "BuffClassID", buff_id).is_empty():
		return "subscription_protection_dispatch_unresolved"
	if int(buff.get("EraseOnLevel", 0)) > 0 and int(context.get("level", 1)) >= int(buff.EraseOnLevel):
		return "protection_level_limit"
	return ""

func _item_eligibility(item: Dictionary, context: Dictionary) -> String:
	if item.is_empty():
		return "source_item_missing"
	if is_instance_valid(_source) and _source.has_method("item_eligibility"):
		var bridge: Dictionary = context.duplicate(true)
		bridge.now = int(context.get("nowUnix", 0))
		bridge.service_region = str(context.get("region", "KR"))
		bridge.enforce_item_use_limits = true
		if not bridge.has("time_policy"):
			bridge.time_policy = {"utc_offset_minutes": int(Time.get_time_zone_from_system().get("bias", 0))}
		var eligibility: Variant = _source.call("item_eligibility", int(item.get("ID", 0)), bridge)
		if not eligibility is Dictionary or not bool(eligibility.get("ok", false)):
			var reason: String = str(eligibility.get("error", "item_eligibility_invalid")) if eligibility is Dictionary else "item_eligibility_invalid"
			return "source_item_expired" if reason == "item_expired" else "source_" + reason
	if bool(item.get("TestItem", false)) and not bool(context.get("allow_test_items", false)):
		return "source_test_item"
	var level: int = int(context.get("level", 1))
	if level < int(item.get("LevelLimitMin", 0)) or (int(item.get("LevelLimitMax", 0)) > 0 and level > int(item.LevelLimitMax)):
		return "source_level_limit"
	var region: String = str(item.get("ServiceRegionCode", ""))
	if not region.is_empty() and not str(context.get("region", "KR")) in region.split(","):
		return "source_region_limit"
	var classes: Array = []
	for link: Dictionary in _rows("ItemClassLimit"):
		if int(link.get("ItemClassID", 0)) == int(item.get("ID", 0)):
			classes.append(int(link.get("ClassID", 0)))
	if not classes.is_empty() and not int(context.get("class_id", 0)) in classes:
		return "source_class_limit"
	return ""

func _owned_grails(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var instances: Variant = context.get("instances", {})
	if not instances is Dictionary:
		return result
	var used: Dictionary = {}
	var now: int = int(context.get("nowUnix", 0))
	for key: Variant in instances:
		if not instances[key] is Dictionary:
			continue
		var record: Dictionary = instances[key]
		var item_id: int = int(record.get("sourceID", 0))
		if not _grail.has(item_id) or str(key).is_empty() or str(record.get("instance_id", key)) != str(key):
			continue
		if int(record.get("expires_at", 0)) > 0 and int(record.expires_at) <= now:
			continue
		if int(used.get(item_id, 0)) >= _count(context.get("owned", {}), item_id):
			continue
		used[item_id] = int(used.get(item_id, 0)) + 1
		result[str(key)] = record
	return result

func _validate_pool(grace_id: int, slot: int) -> String:
	var pool: Array = _pools.get("%d:%d" % [grace_id, slot], [])
	var total: int = 0
	var seen: Dictionary = {}
	for link: Dictionary in pool:
		var prefix: int = int(link.get("GracePrefixID", 0))
		var probability: int = int(link.get("Probability", -1))
		if probability < 0 or seen.has(prefix) or (int(link.get("BonusID", 0)) > 0 and _row("Bonus", int(link.BonusID)).is_empty()):
			return "grail_source_pool_invalid"
		seen[prefix] = true
		total += probability
	var denominator: int = _slot_denominator(slot, total)
	if pool.is_empty() or total <= 0 or denominator < total or (slot == 2 and denominator != total):
		return "grail_source_pool_unavailable"
	return ""

func _roll_prefix(grace_id: int, slot: int, state: Dictionary) -> int:
	var pool: Array = _pools.get("%d:%d" % [grace_id, slot], [])
	var total: int = 0
	for link: Dictionary in pool:
		total += int(link.Probability)
	var roll: int = _random_below(_slot_denominator(slot, total), state)
	for link: Dictionary in pool:
		roll -= int(link.Probability)
		if roll < 0:
			return int(link.GracePrefixID)
	return 0 # The source's unlabelled absolute-prefix remainder stays empty.

func _random_below(bound: int, state: Dictionary) -> int:
	var limit: int = (RNG_MODULUS - 1) - ((RNG_MODULUS - 1) % bound)
	while true:
		state.rng_state = (int(state.rng_state) * 48271) % RNG_MODULUS
		var draw: int = int(state.rng_state) - 1
		if draw < limit:
			return draw % bound
	return 0

func _slot_denominator(slot: int, total: int) -> int:
	for row: Dictionary in _rows("ItemGraceSlot"):
		if int(row.get("SlotNumber", 0)) == slot:
			return int(row.get("GraceProbabilityTotal", 0)) if int(row.get("GraceProbabilityTotal", 0)) > 0 else total
	return 0

func _prefix_link(grace_id: int, prefix_id: int, slot: int) -> Dictionary:
	for link: Dictionary in _pools.get("%d:%d" % [grace_id, slot], []):
		if int(link.get("GracePrefixID", 0)) == prefix_id:
			return link
	return {}

func _prefix_name(prefix_id: int) -> String:
	if prefix_id == 0:
		return "절대 은총 없음"
	var prefix: Dictionary = _row("ItemGracePrefix", prefix_id)
	return str(_row("DescData_Korean", int(prefix.get("PrefixDescID", 0))).get("Description", "은총 %d" % prefix_id))

func _grace_cost(grace_id: int) -> Dictionary:
	for row: Dictionary in _rows("ItemGraceCost"):
		if int(row.get("GraceID", 0)) == grace_id:
			return row
	return {}

func _protection_buff(item_id: int, subscription: int) -> int:
	return int(test_protection_dispatch.get(item_id, protection_dispatch.get(subscription, 0)))

func _rows(table: String) -> Array:
	if not _tables.has(table):
		var value: Variant = _source.call("rows", table) if is_instance_valid(_source) and _source.has_method("rows") else []
		var copied: Array = value.duplicate(true) if value is Array else []
		# Large original tables are read through the source each time instead of
		# a private deep copy (ItemClass/Bonus held ~0.3 GB here).
		if is_instance_valid(_source) and _source.has_method("_shared") and _source.call("_shared", table): return copied
		_tables[table] = copied
	return _tables[table]

func _row(table: String, id: int) -> Dictionary:
	if not _indices.has(table) and is_instance_valid(_source) and _source.has_method("_shared") and _source.call("_shared", table):
		var found: Dictionary = _source.call("row", table, id)
		return found.duplicate(true) if not found.is_empty() else {}
	if not _indices.has(table):
		var index: Dictionary = {}
		for row: Dictionary in _rows(table):
			index[int(row.get("ID", 0))] = row
		_indices[table] = index
	return _indices[table].get(id, {})

func _append(target: Dictionary, key: Variant, value: Variant) -> void:
	if not target.has(key):
		target[key] = []
	target[key].append(value)

func _sum(target: Dictionary, key: String, value: float) -> void:
	target[key] = float(target.get(key, 0.0)) + value

func _count(value: Variant, id: int) -> int:
	if not value is Dictionary:
		return 0
	var amount: Variant = value.get(str(id), value.get(id, 0))
	return int(amount) if _integer(amount, 0) else 0

func _integer(value: Variant, minimum: int, maximum: int = 2147483647) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == float(int(value)) and int(value) >= minimum and int(value) <= maximum

func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}

func _success(state: Dictionary, costs: Array) -> Dictionary:
	return {"ok": true, "error": "", "state": state, "costs": costs, "rewards": []}
