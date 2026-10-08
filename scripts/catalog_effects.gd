extends RefCounted
class_name TwilightCatalogEffects

# Readable catalog data is retained; exact numeric descriptions are supported.
# Do not synthesize numbers for phrases such as "대미지 리덕션 계열".
const ATTACK_STYLES: Array[String] = ["melee", "ranged", "magic"]

static func numeric_description_option(record: Dictionary, label: String) -> float:
	for raw_value: String in str(record.get("desc", "")).split("·"):
		var segment: String = raw_value.strip_edges()
		if not (segment.begins_with(label + " ") or segment.begins_with(label + "+")):
			continue
		var tail: String = segment.substr(label.length()).strip_edges()
		if tail.begins_with("+"):
			tail = tail.substr(1).strip_edges()
		elif tail.begins_with("-"):
			# Positive-only bonus parser; negative penalties can use typed data.
			continue
		if tail.ends_with("%"):
			tail = tail.substr(0, tail.length() - 1).strip_edges()
		if tail.is_valid_float():
			return float(tail)
	return 0.0

static func attack_speed_percent(record: Dictionary) -> float:
	if record.has("attackSpeed"):
		return maxf(0.0, float(record.get("attackSpeed", 0.0)))
	if record.has("attack_speed"):
		return maxf(0.0, float(record.get("attack_speed", 0.0)))
	return numeric_description_option(record, "공격 속도")

static func damage_by_style(record: Dictionary, kind: String) -> int:
	if not ATTACK_STYLES.has(kind):
		return 0
	var melee: int = int(numeric_description_option(record, "근거리 대미지"))
	var ranged: int = int(numeric_description_option(record, "원거리 대미지"))
	var magic: int = int(numeric_description_option(record, "마법 대미지"))
	var dual: int = int(numeric_description_option(record, "근/원거리 대미지"))
	# If an exact style-specific bonus is present, the historical atk field
	# represents that already described bonus, rather than a second bonus.
	if melee > 0 or ranged > 0 or magic > 0 or dual > 0:
		match kind:
			"melee": return melee + dual
			"ranged": return ranged + dual
			"magic": return magic
	var attack_value: int = int(record.get("atk", 0))
	match str(record.get("type", "만능")):
		"근거리": return attack_value if kind == "melee" else 0
		"원거리": return attack_value if kind == "ranged" else 0
		"마법": return attack_value if kind == "magic" else 0
		_: return attack_value

static func accuracy_by_style(record: Dictionary, kind: String) -> int:
	match kind:
		"melee":
			return int(numeric_description_option(record, "근거리 명중"))
		"ranged":
			return int(numeric_description_option(record, "원거리 명중"))
		"magic":
			return int(numeric_description_option(record, "마법 명중"))
	return 0

static func critical_by_style(record: Dictionary, kind: String) -> int:
	match kind:
		"melee": return int(numeric_description_option(record, "근거리 치명타"))
		"ranged": return int(numeric_description_option(record, "원거리 치명타"))
		"magic": return int(numeric_description_option(record, "마법 치명타"))
	return 0

static func flat_reduction(record: Dictionary) -> int:
	for key: String in ["damage_reduction", "damageReduction", "reduction", "리덕션"]:
		if record.has(key):
			return maxi(0, int(record.get(key, 0)))
	return maxi(0, int(numeric_description_option(record, "대미지 리덕션")))

static func unresolved_description(record: Dictionary) -> bool:
	var description: String = str(record.get("desc", ""))
	return description.contains("계열") or description.contains("보너스") or description.contains("회복형")
