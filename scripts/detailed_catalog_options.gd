extends RefCounted
class_name TwilightDetailedCatalogOptions

# Data-driven, non-skill interpretation of the complete Inven catalog.
# The original sourceOptions and descriptions stay untouched for auditing.
# TWILIGHT-specific rules: PvP stats apply to PvE, HP absorb 1-3 per hit,
# HP/MP regen +5 each 30s. Do not simulate named/skill procs.
const LABELS: Dictionary = {
	"STR":"str", "DEX":"dex", "CON":"con", "INT":"int", "WIS":"wis", "CHA":"cha",
	"MaxHP":"hp_flat", "MAXHP":"hp_flat", "최대HP":"hp_flat",
	"MaxMP":"mp_flat", "MAXMP":"mp_flat", "최대MP":"mp_flat",
	"MaxHP%":"hp_pct", "최대HP%":"hp_pct",
	"무게보너스":"weight", "SP":"sp", "마법공격력":"sp",
	"마법방어력(MR)":"mr", "마법방어력":"mr", "MR":"mr",
	"물리방어력(AC)":"ac", "AC":"ac",
	"무기명중":"weapon_hit", "명중":"weapon_hit",
	"추가대미지":"extra_damage", "대미지증가":"damage_increase",
	"대미지리덕션":"reduction", "대미지감소":"reduction",
	"대미지리덕션무시":"ignore_reduction", "대미지감소무시":"ignore_reduction",
	"근거리대미지리덕션무시":"ignore_reduction_melee",
	"원거리대미지리덕션무시":"ignore_reduction_ranged",
	"마법대미지리덕션무시":"ignore_reduction_magic",
	"근거리대미지":"melee_damage", "원거리대미지":"ranged_damage", "마법대미지":"magic_damage",
	"근/원거리대미지":"dual_damage", "근거리추가대미지":"melee_damage",
	"원거리추가대미지":"ranged_damage", "마법추가대미지":"magic_damage",
	"근거리명중":"melee_hit", "원거리명중":"ranged_hit", "마법명중":"magic_hit",
	"근거리치명타":"melee_crit", "원거리치명타":"ranged_crit", "마법치명타":"magic_crit",
	"근거리회피력":"dg", "원거리회피력":"er", "원거리회피력(ER)":"er",
	"스턴적중":"stun_hit", "스턴내성":"stun_resist",
	"공포적중":"fear_hit", "공포내성":"fear_resist",
	"홀드내성":"hold_resist", "독내성":"poison_resist", "출혈적중":"bleed_hit",
	"근거리회피력무시":"ignore_dg", "원거리회피력무시":"ignore_er",
	"물약회복률":"potion_pct", "물약회복율":"potion_pct", "물약회복량":"potion_flat",
	"HP물약회복량증가":"potion_flat", "물약회복량증가":"potion_flat",
	"공격속도":"attack_speed", "이동속도":"move_speed", "시전속도":"cast_speed",
	"경험치획득량증가":"xp_pct", "경험치보너스":"xp_pct", "경험치획득량":"xp_pct",
	"스킬쿨타임감소":"skill_cooldown_pct",
	"MP회복(틱)":"mp_recovery", "HP회복(틱)":"hp_recovery",
	"MP회복":"mp_recovery", "HP회복":"hp_recovery",
	"MP절대회복":"mp_recovery", "HP절대회복":"hp_recovery",
	"작은대상대미지":"small_damage", "큰대상대미지":"large_damage",
	"PVE대미지리덕션":"pve_reduction", "PVE대미지감소":"pve_reduction",
	"PVE대미지증가":"pve_damage_pct", "PVE근거리대미지":"pve_melee_damage",
	"PVE원거리대미지":"pve_ranged_damage", "PVE마법대미지":"pve_magic_damage",
	"PVE근거리추가대미지":"pve_melee_damage",
	"PVE원거리추가대미지":"pve_ranged_damage",
	"PVE마법추가대미지":"pve_magic_damage",
	"PVE근거리명중":"pve_melee_hit", "PVE원거리명중":"pve_ranged_hit",
	"PVE마법명중":"pve_magic_hit",
	"PVE대미지감소무시":"pve_ignore_reduction",
	"PVE대미지리덕션무시":"pve_ignore_reduction"
}
const IGNORED_TOKENS: Array[String] = ["무기손상방지", "손상", "비손상", "저주", "축복소모량감소", "축복소모감소"]
const DEFERRED_TOKENS: Array[String] = ["발동:", "발동 :", "전용스킬:", "액티브스킬:", "일반스킬레벨",
	"일반~", "패시브", "각성", "컬렉션", "차징시간감소", "스킬레벨", "공허의계약:"]

static func _clean_label(raw: String) -> String:
	return raw.to_upper().replace(" ", "").replace("\t", "").replace("（", "(").replace("）", ")").replace("PVP", "PVE").replace("PVP", "PVE")

static func _signed_number(raw: String) -> Dictionary:
	var v: String = raw.strip_edges().replace(",", "").replace("％", "%")
	var sign: float = 1.0
	if v.begins_with("+"):
		v = v.substr(1).strip_edges()
	elif v.begins_with("-"):
		sign = -1.0
		v = v.substr(1).strip_edges()
	var digits: String = ""
	var decimal: bool = false
	for index: int in range(v.length()):
		var ch: String = v.substr(index, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif ch == "." and not decimal:
			decimal = true
			digits += "."
		elif ch == " " and digits.is_empty():
			continue
		else:
			break
	if digits.is_empty() or digits == ".":
		return {}
	return {"value":sign * float(digits), "percent":v.contains("%")}

static func parse_option(raw: String) -> Dictionary:
	var cleaned: String = raw.strip_edges()
	if cleaned.is_empty():
		return {}
	var compact: String = _clean_label(cleaned)
	for forbidden: String in IGNORED_TOKENS:
		if compact.contains(forbidden):
			return {"kind":"removed"}
	for pending: String in DEFERRED_TOKENS:
		if compact.contains(pending):
			return {"kind":"deferred"}
	if compact.contains("HP흡수"):
		return {"kind":"effect", "key":"hp_absorption", "value":1.0}
	if compact.contains("MP흡수"):
		return {"kind":"deferred"}
	# Determine the label at the first signed number, not by a fixed prefix:
	# "Max HP +5,000", "최대HP+15%", "스턴 적중 + 20%".
	var number_start: int = -1
	for i: int in range(cleaned.length()):
		var ch: String = cleaned.substr(i, 1)
		if ch >= "0" and ch <= "9":
			number_start = i
			break
	if number_start < 0:
		return {"kind":"deferred"}
	var raw_label: String = cleaned.substr(0, number_start).strip_edges()
	while raw_label.ends_with("+") or raw_label.ends_with("-"):
		raw_label = raw_label.substr(0, raw_label.length() - 1).strip_edges()
	var key: String = _clean_label(raw_label)
	var value: Dictionary = _signed_number(cleaned.substr(number_start))
	if value.is_empty():
		return {"kind":"deferred"}
	# Negative AC values mean a positive improvement in TWILIGHT's defense stat.
	if not LABELS.has(key):
		return {"kind":"deferred"}
	var target: String = str(LABELS[key])
	var amount: float = float(value.get("value", 0.0))
	if target == "ac":
		amount = absf(amount)
	if target == "hp_flat" and bool(value.get("percent", false)):
		target = "hp_pct"
		amount /= 100.0
	if target == "damage_increase" and bool(value.get("percent", false)):
		target = "damage_increase_pct"
	if target == "pve_ignore_reduction" and bool(value.get("percent", false)):
		return {"kind":"deferred"}
	if target == "pve_reduction" and bool(value.get("percent", false)):
		target = "pve_reduction_pct"
	if target == "reduction" and bool(value.get("percent", false)):
		target = "reduction_pct"
	return {"kind":"numeric", "key":target, "value":amount}

static func classify(record: Dictionary) -> Dictionary:
	var stats: Dictionary = {}
	var deferred: Array[String] = []
	var removed: int = 0
	var options: Array = record.get("sourceOptions", []) as Array
	var raw_parts: Array = options if not options.is_empty() else str(record.get("desc", "")).split("·")
	for original: Variant in raw_parts:
		var raw: String = str(original).strip_edges()
		if raw.is_empty():
			continue
		var info: Dictionary = parse_option(raw)
		match str(info.get("kind", "deferred")):
			"numeric", "effect":
				var key: String = str(info.get("key", ""))
				# The detailed item source does not repeat a unique canonical key
				# except for mutually exclusive wording variants.
				if key != "":
					stats[key] = float(stats.get(key, 0.0)) + float(info.get("value", 0.0))
			"removed":
				removed += 1
			_:
				deferred.append(raw)
	return {"stats":stats, "deferred":deferred, "removed":removed,
		"total":raw_parts.size()}

static func value(record: Dictionary, key: String) -> float:
	var stored: Variant = record.get("_detail_stats", {})
	if stored is Dictionary:
		return float((stored as Dictionary).get(key, 0.0))
	return float((classify(record).get("stats", {}) as Dictionary).get(key, 0.0))

static func source_display(record: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var options: Array = record.get("sourceOptions", []) as Array
	if options.is_empty():
		options = str(record.get("desc", "")).split("·")
	for raw: Variant in options:
		var v: String = str(raw).strip_edges()
		if v.is_empty() or parse_option(v).get("kind", "") == "removed":
			continue
		lines.append(v.replace("PVP", "PVE").replace("PvP", "PvE"))
	return lines
