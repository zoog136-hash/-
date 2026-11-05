extends RefCounted
## Adjustable host estimates; never replace a provided source value.
const PATH = "res://data/totem_combat_local_policy.json"
const ID = "twilight_totem_combat_v1"
var defaults: Dictionary = {}
var error := ""

func load_defaults() -> bool:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not value is Dictionary or value.get("schema") != 1 or value.get("policy") != ID or not valid(value.get("defaults")):
		error = "토템 자체 전투 설정 파일 오류 · 원본 효과만 사용"
		return false
	defaults = normalized(value.defaults)
	error = ""
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 6 or not (value.get("version") is int or value.get("version") is float) or value.get("version") != 1 or value.get("policy") != ID:return false
	if not value.get("venom_enabled") is bool or not value.get("shield_enabled") is bool:return false
	var interval: Variant = value.get("venom_interval")
	var capacity: Variant = value.get("shield_capacity")
	if not (interval is int or interval is float) or not is_finite(float(interval)) or float(interval) < 0.25 or float(interval) > 10:return false
	return (capacity is int or capacity is float) and is_finite(float(capacity)) and float(capacity) == floor(float(capacity)) and float(capacity) >= 1 and float(capacity) <= 100000

static func normalized(value: Dictionary) -> Dictionary:
	return {"version":1,"policy":ID,"venom_enabled":bool(value.venom_enabled),"venom_interval":float(value.venom_interval),"shield_enabled":bool(value.shield_enabled),"shield_capacity":int(value.shield_capacity)}
