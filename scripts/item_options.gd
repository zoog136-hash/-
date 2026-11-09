extends RefCounted
class_name TwilightItemOptions
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const CURRENT_DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")

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

static func _weight_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0.0 and float(value) <= 9007199254740991.0

static func current_source_weight_input(record: Dictionary, estimate: Dictionary) -> Dictionary:
	# UNVERIFIED: only the current original-backed native DTO may use this
	# explicit TWILIGHT estimate. This does not establish a native weight unit.
	var ignored: Dictionary = {"applicable":false}
	if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or typeof(record.get("source_m_native_item")) != TYPE_BOOL or not bool(record.source_m_native_item) or typeof(record.get("source_test_item")) != TYPE_BOOL or bool(record.source_test_item):
		return ignored
	if record.get("source_projection") != "current523_original_typed_game_dto_v1": return ignored
	var item_id: Variant = record.get("source_item_class_id")
	# One full() per record (this runs for every catalog record at start).
	var full: Dictionary = NATIVE_FIELDS.full(record)
	if not _weight_integer(item_id) or int(item_id) <= 0 or full.get("source_weight_unit") != "unverified_source_units":
		return ignored
	if record.get("source_legacy_stack_variant",false) or record.get("source_legacy_catalog_alias",false): return ignored
	var blessing: Variant = record.get("source_bless_raw")
	if not _weight_integer(blessing) or int(blessing) not in [1,2,3]: return ignored
	# Exact published patch523_monster_drops.variant_item/equipment contract:
	# equipment keeps the base ID; only non-equipment states 2/3 add a suffix.
	var is_equipment: bool
	if record.get("crafting_scroll",false):
		is_equipment = bool(record.get("drop_as_equipment",false)) and record.get("slot","") == "consumable"
	else:
		is_equipment = str(record.get("slot","")) not in ["","currency","consumable","material"]
	var expected_id: String = "m523:item:"+str(int(item_id))
	if not is_equipment and int(blessing) in [2,3]: expected_id += ":bless:"+str(int(blessing))
	if record.get("sourceId") != expected_id:
		return ignored
	var identity: Dictionary = CURRENT_DEFINITIONS.identity()
	if identity.is_empty() or record.get("source_definition_archive") != identity or not full.get("source_original_item") is Dictionary:
		return ignored
	var raw: Dictionary = full.source_original_item
	if raw.is_empty() or raw.get("ID") != int(item_id) or typeof(raw.get("TestItem")) != TYPE_BOOL or bool(raw.TestItem) or raw != CURRENT_DEFINITIONS.row("ItemClass",int(item_id)) or not _weight_integer(full.get("source_weight")) or full.get("source_weight") != raw.get("Weight"):
		return ignored
	if not CURRENT_DEFINITIONS.declared_exclusion("ItemClass",raw).is_empty():
		return {"applicable":true,"ok":false,"problem":"명시적으로 제외된 원문 아이템의 무게 입력입니다."}
	if not _weight_integer(raw.get("Weight")):
		return {"applicable":true,"ok":false,"problem":"현재 원문 무게가 비음수 정수가 아닙니다."}
	if estimate.get("mode") != "twilight_estimate" or estimate.get("rounding") != "ceil" or estimate.get("source_archive_sha256") != identity.get("source_sha256") or not _weight_integer(estimate.get("points_numerator")) or not _weight_integer(estimate.get("source_units_denominator")):
		return {"applicable":true,"ok":false,"problem":"명시적 TWILIGHT 원문 무게 추정 설정이 없거나 잘못됐습니다."}
	var numerator: int = int(estimate.points_numerator)
	var denominator: int = int(estimate.source_units_denominator)
	if numerator <= 0 or denominator <= 0:
		return {"applicable":true,"ok":false,"problem":"TWILIGHT 무게 추정 분자·분모는 양의 정수여야 합니다."}
	var original_weight: int = int(raw.Weight)
	# Check multiplication before performing integer ceil; never round the raw
	# source field or use a floating-point conversion factor.
	@warning_ignore("integer_division")
	var maximum_original: int = 9223372036854775807 / numerator
	if original_weight > maximum_original:
		return {"applicable":true,"ok":false,"problem":"TWILIGHT 무게 추정 정수 곱셈 범위를 초과합니다."}
	var product: int = original_weight * numerator
	@warning_ignore("integer_division")
	var points: int = product / denominator
	if product % denominator != 0:
		if points == 9223372036854775807:
			return {"applicable":true,"ok":false,"problem":"TWILIGHT 무게 추정 올림 범위를 초과합니다."}
		points += 1
	return {"applicable":true,"ok":true,"weight":points}

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
