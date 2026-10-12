extends RefCounted
class_name TwilightTransformSkillOptions

# These are PvE skill-specific modifiers from equipped transformation cards.
# No generic proc or new spell is created; an entry only affects an actual skill.
const RULES: Array[Dictionary] = [
	{"label":"트리플 애로우 대미지", "skill":"트리플 애로우", "kind":"damage_flat"},
	{"label":"트리플 애로우 추가 대미지", "skill":"트리플 애로우", "kind":"damage_flat"},
	{"label":"트리플 애로우", "skill":"트리플 애로우", "kind":"damage_flat"},
	{"label":"래피드 샷 대미지", "skill":"래피드 샷", "kind":"damage_flat"},
	{"label":"디스인티그레이트(에이션트)", "skill":"디스인티그레이트(에이션트)", "kind":"damage_flat"},
	{"label":"디스인티그레이트", "skill":"디스인티그레이트", "kind":"damage_flat"},
	{"label":"아머 브레이크 피해", "skill":"아머 브레이크", "kind":"damage_pct"},
	{"label":"쇼크 스턴 적중", "skill":"쇼크 스턴", "kind":"accuracy_pct"},
	{"label":"엑스칼리버 적중", "skill":"엑스칼리버", "kind":"accuracy_pct"},
	{"label":"드래곤 스턴 적중", "skill":"드래곤 스턴", "kind":"accuracy_pct"},
	{"label":"마법탄: 스턴 적중", "skill":"마법탄: 스턴", "kind":"accuracy_pct"},
	{"label":"썬더 그랩 적중", "skill":"썬더 그랩", "kind":"accuracy_pct"}
]

static func _matches_skill(actual: String, expected: String) -> bool:
	if actual == expected:
		return true
	# Spirit Arrow is a named upgrade of Triple Arrow, not a separate bonus.
	return expected == "트리플 애로우" and actual == "트리플 애로우(스피릿)"

static func _parsed_rule(raw: String) -> Dictionary:
	var option: String = raw.strip_edges()
	var required_job: String = ""
	if option.begins_with("<"):
		var end: int = option.find(">")
		if end <= 1:
			return {}
		required_job = option.substr(1, end - 1)
		option = option.substr(end + 1).strip_edges()
	for rule: Dictionary in RULES:
		var label: String = str(rule["label"])
		if not option.begins_with(label):
			continue
		var suffix: String = option.substr(label.length()).strip_edges()
		if not suffix.begins_with("+"):
			continue
		var numeric: String = suffix.substr(1).strip_edges().replace("%", "").strip_edges()
		if not numeric.is_valid_float():
			continue
		var kind: String = str(rule["kind"])
		if kind.ends_with("_pct") and not suffix.ends_with("%"):
			continue
		return {"job":required_job, "skill":str(rule["skill"]), "kind":kind, "amount":float(numeric)}
	return {}

static func is_named_skill_option(option: String) -> bool:
	return not _parsed_rule(option).is_empty()

static func amount(card: Dictionary, job: String, skill_name: String, kind: String) -> float:
	var raw: Variant = card.get("sourceOptions", [])
	if not (raw is Array):
		return 0.0
	var total: float = 0.0
	for value: Variant in raw as Array:
		var rule: Dictionary = _parsed_rule(str(value))
		if rule.is_empty() or str(rule["kind"]) != kind:
			continue
		if str(rule["job"]) != "" and str(rule["job"]) != job:
			continue
		if not _matches_skill(skill_name, str(rule["skill"])):
			continue
		total += float(rule["amount"])
	return total
