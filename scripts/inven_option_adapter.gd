extends RefCounted
class_name TwilightInvenOptionAdapter

# Parses the sourceOptions of the complete Inven catalog once at load time.
# Source options remain immutable for auditing. We only translate unambiguous,
# non-skill numeric passives; unique procs, blessing and collection stay deferred.
const OPTION_KEYS: Array = [
	["PVP 근거리 추가대미지", "pve_melee_damage"],
	["PVP 원거리 추가대미지", "pve_ranged_damage"],
	["PVP 근거리 추가 대미지", "pve_melee_damage"],
	["PvP 근거리 추가 대미지", "pve_melee_damage"],
	["PVP 원거리 추가 대미지", "pve_ranged_damage"],
	["PVE 근거리 추가 대미지", "pve_melee_damage"],
	["PVE 원거리 추가 대미지", "pve_ranged_damage"],
	["PVE 마법 추가 대미지", "pve_magic_damage"],
	["PVP 근거리 대미지", "pve_melee_damage"],
	["PVP 원거리 대미지", "pve_ranged_damage"],
	["PVP 대미지 감소 무시", "damage_amp_pct"],
	["PVP 대미지 리덕션 무시", "damage_reduction_ignore"],
	["PVP 대미지 리덕션", "pve_damage_reduction"],
	["PvP 대미지 리덕션", "pve_damage_reduction"],
	["PVE 대미지 리덕션", "pve_damage_reduction"],
	["PVP 대미지 감소", "pve_damage_reduction_pct"],
	["PvP 대미지 감소", "pve_damage_reduction_pct"],
	["PVE 대미지 감소", "pve_damage_reduction_pct"],
	["대미지 감소 무시", "damage_amp_pct"],
	["대미지 리덕션 무시", "damage_reduction_ignore"],
	["근거리 대미지 리덕션 무시", "melee_reduction_ignore"],
	["원거리 대미지 리덕션 무시", "ranged_reduction_ignore"],
	["근거리 대미지 감소 무시", "melee_reduction_ignore"],
	["원거리 대미지 감소 무시", "ranged_reduction_ignore"],
	["마법 대미지 감소 무시", "magic_reduction_ignore"],
	["근거리 회피력 무시", "melee_evasion_ignore"],
	["원거리 회피력 무시", "ranged_evasion_ignore"],
	["마법 방어력(MR)", "mr"],
	["마법 방어력", "mr"],
	["마법 방어력 (MR)", "mr"],
	["원거리 회피력(ER)", "er"],
	["원거리 회피력", "er"],
	["근거리 회피력", "dg"],
	["물리 방어력(AC)", "ac"],
	["물리 방어력 (AC)", "ac"],
	["근거리 치명타 대미지", "melee_critical_damage"],
	["원거리 치명타 대미지", "ranged_critical_damage"],
	["근거리 치명타", "melee_crit"],
	["원거리 치명타", "ranged_crit"],
	["마법 치명타", "magic_crit"],
	["스턴 적중률", "stun_accuracy"],
	["스턴 적중", "stun_accuracy"],
	["스턴내성", "stun_resistance"],
	["스턴 내성", "stun_resistance"],
	["공포 적중", "fear_accuracy"],
	["공포 내성", "fear_resistance"],
	["홀드 적중", "hold_accuracy"],
	["홀드 내성", "hold_resistance"],
	["독 내성", "poison_resistance"],
	["출혈 내성", "bleed_resistance"],
	["암흑 내성", "dark_resistance"],
	["물약 회복량", "potionHealFlat"],
	["HP 물약 회복량 증가", "potionHealFlat"],
	["물약 회복률", "potionHealPct"],
	["HP 회복(틱)", "hpRecoveryTick"],
	["MP 회복(틱)", "mpRecoveryTick"],
	["HP 회복 (틱)", "hpRecoveryTick"],
	["MP 회복 (틱)", "mpRecoveryTick"],
	["HP 절대회복", "hpAbsoluteRecovery"],
	["MP 회복", "mpRecoveryTick"],
	["HP 회복", "hpRecoveryTick"],
	["근거리 명중", "meleeHit"],
	["원거리 명중", "rangedHit"],
	["마법 명중", "magicHit"],
	["무기 명중", "hit"],
	["추가 대미지", "additionalDamage"],
	["근거리 대미지", "meleeDamage"],
	["원거리 대미지", "rangedDamage"],
	["마법 대미지", "magicDamage"],
	["근/원거리 대미지", "dual_damage"],
	["SP", "sp"],
	["STR", "strFlat"],
	["DEX", "dexFlat"],
	["CON", "conFlat"],
	["INT", "intFlat"],
	["WIS", "wisFlat"],
	["CHA", "chaFlat"],
	["Max HP", "hpFlat"],
	["최대 HP", "hpFlat"],
	["Max MP", "mpFlat"],
	["최대 MP", "mpFlat"],
	["경험치 획득량 증가", "xp"],
	["경험치 보너스", "xp"],
	["아데나 드롭량 증가", "adena_drop_pct"],
	["무게 보너스", "weightBonus"],
	["스킬 쿨타임 감소", "skillCooldownPct"],
	["대미지 증가", "damage_amp_pct"],
	["대미지 리덕션", "damage_reduction"],
	["대미지 감소", "pve_damage_reduction_pct"],
	["불 속성 저항", "element_resist_fire"],
	["물 속성 저항", "element_resist_water"],
	["바람 속성 저항", "element_resist_wind"],
	["땅 속성 저항", "element_resist_earth"],
	["모든 속성 저항", "element_resist_all"],
	["불 속성 추가 대미지", "element_bonus_fire"],
	["물 속성 추가 대미지", "element_bonus_water"],
	["바람 속성 추가 대미지", "element_bonus_wind"],
	["땅 속성 추가 대미지", "element_bonus_earth"]
]
const DEFERRED_PREFIXES: Array[String] = ["발동:", "전용 스킬:", "액티브 스킬:", "일반 스킬 레벨", "일반 ~", "일반~", "컬렉션", "각성"]

static func _signed_value(text: String) -> Dictionary:
	var tail: String = text.strip_edges().replace(",", "")
	var sign: int = 1
	if tail.begins_with("+"):
		tail = tail.substr(1).strip_edges()
	elif tail.begins_with("-"):
		sign = -1
		tail = tail.substr(1).strip_edges()
	var token: String = ""
	for i: int in range(tail.length()):
		var part: String = tail.substr(i, 1)
		if (part >= "0" and part <= "9") or part == ".":
			token += part
		else:
			break
	if token.is_empty() or not token.is_valid_float():
		return {}
	return {"value":sign * float(token), "percent":tail.substr(token.length()).strip_edges().begins_with("%")}

static func _parse_one(raw: String) -> Dictionary:
	var text: String = raw.strip_edges().replace("　", " ").replace("\t", " ")
	for pair: Array in OPTION_KEYS:
		var label: String = str(pair[0])
		var key: String = str(pair[1])
		if not text.begins_with(label):
			continue
		var rest: String = text.substr(label.length())
		if rest.is_empty() or not (rest.begins_with(" ") or rest.begins_with("+") or rest.begins_with("-") or rest.begins_with("(")):
			continue
		var result: Dictionary = _signed_value(rest)
		if result.is_empty():
			continue
		var value: float = float(result["value"])
		var is_pct: bool = bool(result["percent"])
		if key in ["hpFlat", "mpFlat"] and is_pct:
			key = "hpPct" if key == "hpFlat" else "mpPct"
			value /= 100.0
		elif key == "xp":
			if not is_pct:
				continue
			value /= 100.0
		elif key == "ac":
			value = absf(value)
		elif key == "damage_reduction_ignore" and is_pct:
			key = "damage_amp_pct"
		elif key == "pve_damage_reduction" and is_pct:
			key = "pve_damage_reduction_pct"
		elif key == "pve_damage_reduction_pct" and not is_pct:
			key = "pve_damage_reduction"
		return {"key":key, "value":value}
	return {}

static func annotate(source_record: Dictionary) -> Dictionary:
	if str(source_record.get("source", "")) != "inven":
		return source_record
	if bool(source_record.get("inven_indexed", false)):
		return source_record
	var record: Dictionary = source_record.duplicate(true)
	var applied: Dictionary = {}
	var pending: Array[String] = []
	var original_value: Variant = record.get("sourceOptions", [])
	var options: Array = original_value as Array if original_value is Array else []
	for value: Variant in options:
		var raw: String = str(value).strip_edges()
		if raw.is_empty():
			continue
		# Raw text is never destroyed; retired properties are omitted from runtime.
		if raw.contains("손상") or raw.contains("저주"):
			continue
		if raw == "HP 흡수":
			record["hpAbsorption"] = true
			continue
		var parsed: Dictionary = _parse_one(raw)
		if parsed.is_empty():
			pending.append(raw)
			continue
		var key: String = str(parsed["key"])
		# When the source repeats the exact same stat under two spellings,
		# do not double-add it.
		applied[key] = float(parsed["value"]) if not applied.has(key) else maxf(float(applied[key]), float(parsed["value"]))
	for key: Variant in applied.keys():
		var name_value: String = str(key)
		var numeric: float = float(applied[key])
		if name_value == "ac" and float(record.get("def", 0.0)) == 0.0:
			record["def"] = int(absf(numeric))
		if name_value in ["hpFlat", "hpPct", "xp", "hit", "attackSpeed", "speed", "def"]:
			if float(record.get(name_value, 0.0)) != 0.0:
				continue
		if record.has(name_value) and float(record.get(name_value, 0.0)) != 0.0:
			continue
		record[name_value] = numeric
	record["inven_passives"] = applied
	record["inven_unimplemented_options"] = pending
	record["inven_indexed"] = true
	return record

static func option_count(record: Dictionary) -> Dictionary:
	var raw: Variant = record.get("sourceOptions", [])
	var total: int = (raw as Array).size() if raw is Array else 0
	return {"source":total, "numeric":(record.get("inven_passives", {}) as Dictionary).size(), "deferred":(record.get("inven_unimplemented_options", []) as Array).size()}
