extends RefCounted
## Currency definitions are separate from equipment rarity and potion rolls.
## Source box names establish the coin categories; they do not establish a
## monster-to-coin relationship or a verified source chance.
const CURRENCY_NAMES = ["명예 코인", "변신 제작 코인", "마법인형 제작 코인", "성물 제작 코인", "다이아"]
const COIN_NAMES = ["명예 코인", "변신 제작 코인", "마법인형 제작 코인", "성물 제작 코인"]
const DIAMOND: String = "다이아"
const ADEN_WORLD: String = "aden_world"
const DIAMOND_MIN: int = 1
const DIAMOND_MAX: int = 10
const NAME_ALIASES = {
	"명예코인":"명예 코인", "변신 코인":"변신 제작 코인",
	"변신코인":"변신 제작 코인", "인형 코인":"마법인형 제작 코인",
	"인형코인":"마법인형 제작 코인", "마법인형 코인":"마법인형 제작 코인",
	"성물 코인":"성물 제작 코인", "성물코인":"성물 제작 코인"
}

static func canonical_name(raw: String) -> String:
	var clean: String = raw.strip_edges()
	return str(NAME_ALIASES.get(clean, clean))

static func ensure_items(items: Array) -> void:
	# Add absent categories only; never overwrite a newer source-linked record,
	# source ID, icon or grade. Use the existing stackable inventory/save path.
	var existing: Dictionary = {}
	for raw: Variant in items:
		if raw is Dictionary:
			existing[str((raw as Dictionary).get("name", ""))] = true
	for currency_name: String in CURRENCY_NAMES:
		if existing.has(currency_name):
			continue
		items.append({
			"name":currency_name, "grade":"일반", "type":"화폐", "slot":"currency",
			"weight":0, "stackable":true, "droppable":false, "sellable":false,
			"desc":"보유 재화 · 기존 인벤토리와 저장 데이터에 누적"
		})

static func _candidate(name_value: String, by_name: Dictionary) -> bool:
	if not COIN_NAMES.has(name_value) or not by_name.has(name_value):
		return false
	var raw: Variant = by_name[name_value]
	return raw is Dictionary and str((raw as Dictionary).get("slot", "")) == "currency"

static func _configured_coins(monster_drops: Array[String], monster_name: String, catalog: Dictionary) -> Array[Dictionary]:
	var by_name: Dictionary = catalog.get("by_name", {})
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	# Only explicit current per-monster associations can issue coins.
	# Audited source rows take precedence over plain name-only monster drops.
	var mapped: Dictionary = catalog.get("l1j_monster_drops", {})
	var source_rows: Variant = mapped.get(monster_name, [])
	if source_rows is Array:
		for raw_row: Variant in source_rows:
			if not (raw_row is Dictionary):
				continue
			var row: Dictionary = raw_row as Dictionary
			var item_name: String = canonical_name(str(row.get("item_name", "")))
			if not _candidate(item_name, by_name) or seen.has(item_name):
				continue
			var lower: int = clampi(int(row.get("min", 1)), 1, 10000)
			var upper: int = clampi(int(row.get("max", 1)), lower, 10000)
			candidates.append({"item_name":item_name, "weight":clampi(int(row.get("weight", 1)), 1, 1000000), "min":lower, "max":upper})
			seen[item_name] = true
	for raw_name: String in monster_drops:
		var item_name: String = canonical_name(raw_name)
		if not _candidate(item_name, by_name) or seen.has(item_name):
			continue
		candidates.append({"item_name":item_name, "weight":1, "min":1, "max":1})
		seen[item_name] = true
	return candidates

static func roll(monster_drops: Array[String], monster_name: String, map_id: String, catalog: Dictionary, rng: RandomNumberGenerator, resource_rate: float) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	var chance: float = clampf(resource_rate, 0.0, 1.0)
	# The existing material/resource chance is used rather than inventing a
	# purported official coin probability. At most one configured coin per kill.
	var configured: Array[Dictionary] = _configured_coins(monster_drops, monster_name, catalog)
	if not configured.is_empty() and rng.randf() < chance:
		var total_weight: int = 0
		for row: Dictionary in configured:
			total_weight += int(row["weight"])
		var pick: int = rng.randi_range(1, total_weight)
		for row: Dictionary in configured:
			pick -= int(row["weight"])
			if pick <= 0:
				earned.append({
					"item_name":str(row["item_name"]),
					"quantity":rng.randi_range(int(row["min"]), int(row["max"]))
				})
				break
	# Unknown/unloaded map identity is not an authorization to grant diamonds.
	# Only the distinct "아덴월드" map is excluded; other valid maps qualify.
	var by_name: Dictionary = catalog.get("by_name", {})
	var diamond_row: Variant = by_name.get(DIAMOND, {})
	if not map_id.is_empty() and map_id != ADEN_WORLD and diamond_row is Dictionary and str((diamond_row as Dictionary).get("slot", "")) == "currency":
		if rng.randf() < chance:
			earned.append({"item_name":DIAMOND, "quantity":rng.randi_range(DIAMOND_MIN, DIAMOND_MAX)})
	return earned
