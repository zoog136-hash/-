extends RefCounted
## Native invoke probability differences, with explicit attack scope.
## Existing host damage/proc payloads remain the TWILIGHT compatibility policy.
const SPECS = {
	48471:{"option_id":5811,"type":"Attack_ConditionDamageScaleAfterReduction","consumer":"lm_a0a768c51a6b7838","mode":"proc"},
	70271:{"option_id":10861,"type":"Attack_Spell","consumer":"lm_eb050c341381a33f","mode":"proc","required_spell":70261},
	95152:{"option_id":17002,"type":"Attack_DamageScaleAfterReduction","consumer":"lm_3728e0e8b8a822aa","mode":"amplify"}}

static func _rows(archive: ZIPReader, table: String) -> Array:
	var value: Variant = JSON.parse_string(archive.read_file("content/" + table + ".json").get_string_from_utf8().trim_prefix("\ufeff"))
	return value.get("rows", []) if value is Dictionary else []

static func decode(archive: ZIPReader) -> Dictionary:
	var result: Dictionary = {"options":{},"types":{},"attack_types":{},"weapon_groups":{},"weapons":{}}
	for pair: Array in [["InvokeOption","options"],["InvokeOptionType","types"],["AttackType","attack_types"],["WeaponType","weapons"]]:
		for row: Dictionary in _rows(archive, str(pair[0])): result[pair[1]][int(row.ID)] = row
	for row: Dictionary in _rows(archive, "WeaponTypeForWeaponGroup"):
		var id: int = int(row.WeaponGroupID)
		if not result.weapon_groups.has(id): result.weapon_groups[id] = []
		result.weapon_groups[id].append(int(row.WeaponTypeID))
	return result

static func attach(profile: Dictionary, definitions: Dictionary) -> Dictionary:
	var expected: Dictionary = SPECS.get(int(profile.binding.spell_id), {})
	if expected.is_empty(): return {}
	var option: Dictionary = definitions.options.get(int(expected.option_id), {})
	var type_row: Dictionary = definitions.types.get(int(option.get("InvokeOptionTypeID", -1)), {})
	var attack: Dictionary = definitions.attack_types.get(int(option.get("AttackTypeID", -1)), {})
	if option.is_empty() or type_row.get("Name") != expected.type or attack.get("Name") not in ["All","Melee"]: return {}
	# No authority to invent alternate costs, shield/target gates, additional
	# conditional bonuses or chained invoke payloads.
	for key: String in ["MaterialTypeID","MaterialAmount","ShieldTypeID","TargetKind","SiegeTargetKind","SuccessedInvokeOptionID","Param2","Param3","Param6"]:
		if int(option.get(key, -1)) != 0: return {}
	if bool(option.get("BySpellAttack", true)) or bool(option.get("IsAmmoAttack", true)): return {}
	if int(expected.get("required_spell", 0)) != 0:
		if not profile.spell.any(func(row: Dictionary) -> bool: return row.name_value == "RequiredSpellClassID" and int(row.value) == int(expected.required_spell) and row.application == 0 and row.target == 0 and row.spell_level == 0): return {}
	var group: int = int(option.WeaponGroupID)
	var weapons: Array = definitions.weapon_groups.get(group, []) if group != 0 else []
	if group != 0 and weapons.is_empty(): return {}
	var weapon_names: Array[String] = []
	for id: int in weapons:
		if not definitions.weapons.has(id): return {}
		weapon_names.append(str(definitions.weapons[id].Name))
	var links: Array = []
	for row: Dictionary in profile.buff:
		if row.name_value != "InvokeOption" or row.spell_level > 1: continue
		if row.application != 10 or row.target != int(expected.option_id) or row.unit != "Percentage" or row.character_class != 0: return {}
		links.append(row)
	if links.is_empty(): return {}
	return {"option_id":int(expected.option_id),"option_type":str(expected.type),"consumer":str(expected.consumer),"mode":str(expected.mode),"attack_type":str(attack.Name),"by_spell":false,"main_only":bool(option.Param4),"allow_miss":bool(option.Param5),"weapon_group":group,"weapons":weapons,"weapon_names":weapon_names,"links":links,"source_option":option}

static func _pick(rows: Array, level: int, character_level: int) -> Dictionary:
	var result: Dictionary = {}
	var rank: int = -1
	for row: Dictionary in rows:
		if row.spell_level > level or row.character_level > character_level: continue
		var candidate: int = int(row.spell_level) * 10000 + int(row.character_level)
		if candidate > rank: result = row; rank = candidate
		elif candidate == rank and int(result.bonus_id) != int(row.bonus_id): return {}
	return result

static func project(record: Dictionary, profile: Dictionary, meta: Dictionary, character_level: int, enabled: bool) -> bool:
	var spec: Dictionary = profile.get("invoke", {})
	if spec.is_empty(): return false
	var before: Dictionary = _pick(spec.links, 0, character_level)
	var after: Dictionary = _pick(spec.links, 1, character_level)
	if before.is_empty() or after.is_empty() or int(after.spell_level) != 1: return false
	var delta: float = (float(after.value) - float(before.value)) / float(after.denominator) / 100.0
	if delta <= 0: return false
	# Upgrade cards describe the base action but never become a new proc action.
	if str(record.get("mode", "")) not in [str(spec.mode), "upgrade"]: return false
	if not enabled:
		if not meta.pending.has("성물 발동률 적용 설정 꺼짐"): meta.pending.append("성물 발동률 적용 설정 꺼짐")
		return true
	if not meta.active: return true
	var value: Dictionary = spec.duplicate(true)
	value.erase("links"); value.erase("source_option")
	value["delta"] = delta
	value["base_link_id"] = int(before.link_id)
	value["source_link_id"] = int(after.link_id)
	value["source_bonus_id"] = int(after.bonus_id)
	record["relic_invoke_probability"] = value
	meta.applied.append({"field":"invoke_probability","delta":delta,"source_type":"InvokeOption","source_link_id":after.link_id,"source_bonus_id":after.bonus_id,"base_link_id":before.link_id,"projection":"CUSTOM_BALANCE","option_id":spec.option_id})
	return true

static func delta_for(skill: Dictionary, context: Dictionary) -> float:
	var rule: Dictionary = skill.get("relic_invoke_probability", {})
	if rule.is_empty() or str(skill.get("id", "")) != str(rule.consumer) or str(skill.get("mode", "")) != str(rule.mode): return 0.0
	if not bool(context.get("confirmed", false)) or not context.has("hit") or not context.has("by_spell"): return 0.0
	if bool(context.by_spell) != bool(rule.by_spell): return 0.0
	if not bool(context.hit) and not bool(rule.allow_miss): return 0.0
	if bool(rule.main_only) and not bool(context.get("main_target", false)): return 0.0
	if str(context.get("attack_type", "")) not in ["melee","ranged"]: return 0.0
	if rule.attack_type == "Melee" and context.attack_type != "melee": return 0.0
	if not rule.weapons.is_empty() and not rule.weapons.has(int(context.get("source_weapon_type", -1))): return 0.0
	return float(rule.delta)

static func scope_text(rule: Dictionary) -> String:
	var weapons: String = "도끼·창" if int(rule.get("weapon_group", 0)) == 241 else "무기 제한 없음"
	return "일반 공격 · %s · %s" % [weapons, "명중·빗나감" if bool(rule.get("allow_miss", false)) else "명중 시"]
