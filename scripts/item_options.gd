extends RefCounted
class_name TwilightItemOptions

# Item option adapter: typed record fields take precedence over legacy Korean
# descriptions. This keeps preexisting catalog records and save data unchanged.
const ATTRIBUTES: Dictionary = {
	"STR": ["strFlat", "STR", "str"],
	"DEX": ["dexFlat", "DEX", "dex"],
	"CON": ["conFlat", "CON", "con"],
	"INT": ["intFlat", "INT", "int"],
	"WIS": ["wisFlat", "WIS", "wis"],
	"CHA": ["chaFlat", "CHA", "cha"]
}

static func _signed_integer(raw: String) -> int:
	var value: String = raw.strip_edges()
	var sign: int = 1
	if value.begins_with("-"):
		sign = -1
		value = value.substr(1).strip_edges()
	elif value.begins_with("+"):
		value = value.substr(1).strip_edges()
	var digits: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if character >= "0" and character <= "9":
			digits += character
		else:
			break
	return sign * int(digits) if not digits.is_empty() else 0

static func _description_bonus(record: Dictionary, label: String) -> int:
	for value: String in str(record.get("desc", "")).split("·"):
		var segment: String = value.strip_edges()
		if segment.begins_with(label + " ") or segment.begins_with(label + "+") or segment.begins_with(label + "-"):
			return _signed_integer(segment.substr(label.length()))
	return 0

static func _option(record: Dictionary, keys: Array, desc_label: String = "") -> int:
	for value: Variant in keys:
		var key: String = str(value)
		if record.has(key):
			return int(record.get(key, 0))
	if desc_label.is_empty():
		return 0
	return _description_bonus(record, desc_label)

static func attribute(record: Dictionary, stat: String) -> int:
	if not ATTRIBUTES.has(stat):
		return 0
	return _option(record, ATTRIBUTES[stat], stat)

static func accuracy(record: Dictionary, attack_kind: String) -> int:
	var physical: int = 0
	if attack_kind != "magic":
		physical = _option(record, ["hit", "accuracy", "accuracy_bonus"], "명중")
	match attack_kind:
		"ranged":
			return physical + _option(record, ["rangedHit", "ranged_hit", "ranged_accuracy"], "원거리 명중")
		"magic":
			return _option(record, ["magicHit", "magic_hit", "magic_accuracy"], "마법 명중")
		_:
			return physical + _option(record, ["meleeHit", "melee_hit", "melee_accuracy"], "근거리 명중")

static func additional_damage(record: Dictionary, attack_kind: String) -> int:
	if attack_kind == "magic":
		return _option(record, ["magicDamage", "magic_damage"], "마법 대미지")
	var shared: int = _option(record, ["additionalDamage", "additional_damage", "extraDamage", "extra_damage"], "추가 대미지")
	if attack_kind == "ranged":
		return shared + _option(record, ["rangedDamage", "ranged_damage"], "원거리 대미지")
	return shared + _option(record, ["meleeDamage", "melee_damage"], "근거리 대미지")

# The weapon's size damage is a separate 1..N roll, never a fixed part
# of the melee/ranged character sheet. Typed fields win over source-stat and
# legacy descriptions. "atk" is only a fallback for weapons with no size data;
# old catalog entries sometimes store small damage + flat bonus together in it.
static func weapon_size_damage(record: Dictionary, is_large: bool) -> int:
	if str(record.get("slot", "")) != "weapon":
		return 0
	if record.has("small_damage") and record.has("large_damage"):
		return maxi(0, int(record.get("large_damage" if is_large else "small_damage", 0)))
	var small_named: int = _description_bonus(record, "작은 대상 대미지")
	var large_named: int = _description_bonus(record, "큰 대상 대미지")
	if small_named > 0 and large_named > 0:
		return maxi(0, large_named if is_large else small_named)
	# Inven source "stat": "54 / 35"; earlier game DB "desc": "21/13 · ...".
	for pair: String in [str(record.get("stat", "")).strip_edges(), str(record.get("desc", "")).split("·")[0].strip_edges()]:
		var parts: PackedStringArray = pair.split("/")
		if parts.size() == 2:
			var small: String = parts[0].strip_edges()
			var large: String = parts[1].strip_edges()
			if small.is_valid_int() and large.is_valid_int():
				return maxi(0, int(large if is_large else small))
	return maxi(0, int(record.get("atk", 0)))

# Backward-compatible audit helper; live attacks use weapon_size_damage rolls.
static func weapon_size_adjustment(record: Dictionary, is_large: bool) -> int:
	if not is_large:
		return 0
	return weapon_size_damage(record, true) - weapon_size_damage(record, false)

static func item_weight(record: Dictionary, type_defaults: Dictionary = {}) -> int:
	if record.has("weight"):
		return maxi(0, int(record.get("weight", 0)))
	return maxi(0, int(type_defaults.get(str(record.get("type", "")), 0)))

static func carrying_capacity(effective_con: int) -> int:
	return 2500 + maxi(0, effective_con) * 100

static func encumbrance_multiplier(weight: int, capacity: int) -> float:
	if weight >= capacity * 2:
		return 0.50
	if weight >= int(ceil(float(capacity) * 1.5)):
		return 0.65
	if weight >= capacity:
		return 0.85
	return 1.0
