extends RefCounted
class_name TwilightFullCatalogOptions

# All 2,852 Inven source records / 9,603 raw option clauses are preserved in
# sourceOptions. Only well-defined numeric passive effects are normalized.
# This is not an implementation of unknown procs, collection or awakening.
const DIRECT_LABELS: Dictionary = {
	"STR":"strFlat", "DEX":"dexFlat", "CON":"conFlat", "INT":"intFlat", "WIS":"wisFlat", "CHA":"chaFlat",
	"SP":"sp", "MaxMP":"mpFlat", "최대MP":"mpFlat",
	"마법방어력(MR)":"mr", "마법방어력":"mr", "MR":"mr",
	"근거리회피력":"dg", "원거리회피력":"er", "원거리회피력(ER)":"er",
	"스턴적중":"stun_accuracy", "스턴내성":"stun_resistance", "스턴내성률":"stun_resistance",
	"공포적중":"fear_accuracy", "공포내성":"fear_resistance",
	"홀드적중":"hold_accuracy", "홀드내성":"hold_resistance",
	"침묵적중":"silence_accuracy", "침묵내성":"silence_resistance",
	"독적중":"poison_accuracy", "독내성":"poison_resistance",
	"치명타저항":"critical_resistance", "치명타내성":"critical_resistance",
	"무게보너스":"weightBonus", "물약회복량":"potionHealFlat", "물약회복률":"potionHealPct",
	"SP증가":"sp", "스킬쿨타임감소":"skillCooldownPct",
	"무기명중":"hit", "마법명중":"magicHit",
	"근거리명중":"meleeHit", "원거리명중":"rangedHit",
	"근거리대미지":"meleeDamage", "원거리대미지":"rangedDamage",
	"마법대미지":"magicDamage", "추가대미지":"additionalDamage",
	"대미지리덕션":"damage_reduction",
	"MP회복(틱)":"mpRecoveryTick", "MP회복":"mpRecoveryTick",
	"HP회복(틱)":"hpRecoveryTick", "HP회복":"hpRecoveryTick",
	"대미지리덕션무시":"damage_reduction_ignore",
	"근거리대미지리덕션무시":"melee_damage_reduction_ignore",
	"원거리대미지리덕션무시":"ranged_damage_reduction_ignore",
	"마법대미지리덕션무시":"magic_damage_reduction_ignore",
	"PVE대미지리덕션":"pve_damage_reduction",
	"PVE근거리추가대미지":"pve_melee_damage",
	"PVE원거리추가대미지":"pve_ranged_damage",
	"PVE마법추가대미지":"pve_magic_damage",
	"PVE근거리대미지":"pve_melee_damage",
	"PVE원거리대미지":"pve_ranged_damage",
	"근거리치명타":"melee_crit", "원거리치명타":"ranged_crit", "마법치명타":"magic_crit"
}

static func original_options(record: Dictionary) -> Array:
	var raw: Variant = record.get("sourceOptions", [])
	if raw is Array and not (raw as Array).is_empty():
		return raw as Array
	var result: Array = []
	for value: String in str(record.get("desc", "")).split("·"):
		if value.strip_edges() != "":
			result.append(value.strip_edges())
	return result

static func visible_options(record: Dictionary) -> Array[String]:
	if record.has("runtimeOptions") and record["runtimeOptions"] is Array:
		var saved: Array[String] = []
		for v: Variant in record["runtimeOptions"] as Array:
			saved.append(str(v))
		return saved
	var result: Array[String] = []
	for value: Variant in original_options(record):
		var source: String = str(value).strip_edges()
		if source.contains("손상") or source.contains("저주"):
			continue
		result.append(source.replace("PVP","PVE").replace("PvP","PvE"))
	return result

static func _parsed(raw_value: String) -> Dictionary:
	var string_value: String = raw_value.replace(",", "").replace(" ", "").replace("\t", "").replace("PvP", "PVE").replace("PVP", "PVE").strip_edges()
	var number_position: int = -1
	for i: int in range(string_value.length()):
		var c: String = string_value.substr(i, 1)
		if c >= "0" and c <= "9":
			number_position = i
			break
	if number_position < 1:
		return {}
	var end_position: int = number_position
	while end_position < string_value.length():
		var c: String = string_value.substr(end_position, 1)
		if (c >= "0" and c <= "9") or c == ".":
			end_position += 1
		else:
			break
	var number_text: String = string_value.substr(number_position, end_position - number_position)
	if not number_text.is_valid_float():
		return {}
	var label: String = string_value.substr(0, number_position)
	var is_negative: bool = label.ends_with("-")
	label = label.trim_suffix("+").trim_suffix("-")
	return {"label": label, "value": float(number_text) * (-1.0 if is_negative else 1.0), "percent": string_value.substr(end_position).begins_with("%")}

static func _assign_if_missing(record: Dictionary, key: String, value: Variant) -> bool:
	if record.has(key):
		if absf(float(record.get(key, 0))) > 0.00001:
			return false
	record[key] = value
	return true

static func enrich(source: Dictionary) -> Dictionary:
	var record: Dictionary = source.duplicate(true)
	var display: Array[String] = []
	var deferred: Array[String] = []
	var normalized: Dictionary = {}
	var parsed_count: int = 0
	for raw: Variant in original_options(record):
		var option: String = str(raw).strip_edges()
		if option.is_empty():
			continue
		if option.contains("손상") or option.contains("저주"):
			continue
		option = option.replace("PVP", "PVE").replace("PvP", "PvE")
		display.append(option)
		var data: Dictionary = _parsed(option)
		if data.is_empty():
			if option.contains("발동") or option.contains("전용 스킬") or option.contains("면역") or option.contains("흡수") or option.contains("각성") or option.contains("컬렉션"):
				deferred.append(option)
			continue
		var label: String = str(data.get("label", ""))
		var number: float = float(data.get("value", 0.0))
		var percent: bool = bool(data.get("percent", false))
		var effect: String = ""
		var value: Variant = number
		if (label == "PVE대미지리덕션" or label == "PVE대미지감소") and percent:
			effect = "pve_damage_reduction_pct"
			value = int(round(number))
		elif DIRECT_LABELS.has(label):
			effect = str(DIRECT_LABELS[label])
			value = int(round(number))
			if label == "MP회복" or label == "HP회복":
				# User choice: +5 each 30 seconds, independent of source tick numbers.
				value = maxi(1, int(round(number)))
		elif label == "MaxHP" or label == "최대HP":
			effect = "hpPct" if percent else "hpFlat"
			value = number / 100.0 if percent else int(round(number))
		elif label in ["경험치획득량증가", "경험치보너스", "경험치증가"]:
			effect = "xp"
			value = number / 100.0
		elif label == "공격속도":
			effect = "attackSpeed"
			value = number
		elif label == "이동속도":
			effect = "speed"
			value = 1.0 + number / 100.0
		elif label in ["물리방어력(AC)", "물리방어력", "AC"]:
			effect = "def"
			value = maxi(0, -int(round(number)))
		elif label in ["PVE대미지감소", "PVE대미지리덕션", "대미지감소"]:
			effect = "pve_damage_reduction_pct" if percent else "pve_damage_reduction"
			value = int(round(number))
		elif label == "PVE대미지리덕션무시" and not percent:
			effect = "damage_reduction_ignore"
			value = int(round(number))
		elif label == "PVE대미지감소무시" or label == "대미지감소무시":
			# Percent mitigation bypass is not the same as flat +N damage.
			deferred.append(option)
			continue
		elif label == "추가대미지" and percent:
			deferred.append(option)
			continue
		else:
			deferred.append(option)
			continue
		normalized[effect] = value
		_assign_if_missing(record, effect, value)
		parsed_count += 1
	record["runtimeOptions"] = display
	record["deferredOptions"] = deferred
	record["catalogOptionCount"] = display.size()
	record["catalogNumericCount"] = parsed_count
	record["normalizedCatalogStats"] = normalized
	return record
