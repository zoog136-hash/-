extends RefCounted
## Small read-only projections used during item activation and reward supply.
## Neither projection supplies an effect, a recipe, or ownership proof.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const CONSUMABLE_TERRITORY_LAYOUT: Dictionary = preload("res://scripts/resources/current523_boot_row_spans.gd").CONSUME_TERRITORIES
static var _generation: int = -1
static var _consumable_territories: Variant = null
static var _craft_input_ids: PackedInt32Array

static func _source_current() -> bool:
	if SOURCE.archive_path().is_empty(): return false
	var generation: int = SOURCE.cache_generation()
	if generation != _generation:
		_generation = generation
		_consumable_territories = null
		_craft_input_ids.clear()
	return true

static func _read_member(member: String) -> PackedByteArray:
	var archive := ZIPReader.new()
	if archive.open(SOURCE.archive_path()) != OK: return PackedByteArray()
	var bytes: PackedByteArray = archive.read_file(member)
	archive.close()
	return bytes

const CONSUMABLE_TERRITORY_BAKE := "source523_consumable_territories"

static func territories(ids: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if ids.is_empty() or not _source_current(): return result
	if _consumable_territories == null:
		_consumable_territories = _load_consumable_territories()
	for id: int in _consumable_territories:
		if ids.has(id): result.append(_consumable_territories[id].duplicate(true))
	return result if result.size() == ids.size() else SOURCE.consumable_territories(ids)

## Warm the small verified projections before the player can use an item.
## Publishing the bake can do disk I/O, so only the loading screen does it.
static func prepare() -> void:
	if not _source_current(): return
	if _consumable_territories == null: _consumable_territories = _load_consumable_territories(true)
	if _craft_input_ids.is_empty() and not SOURCE.EXCLUDED_TABLES.has("ItemCraftInput"):
		_craft_input_ids = _load_craft_input_ids(true)

static func consumable_territory_bake_key() -> String:
	var code: String = BAKE.code_key(["res://scripts/resources/current523_consumable_queries.gd",
		"res://scripts/resources/current523_definition_rows.gd",
		"res://scripts/resources/current523_boot_row_spans.gd"])
	return BAKE.key(["consumable-territory-rows.v1", SOURCE.verified_key(), CONSUMABLE_TERRITORY_LAYOUT.sha, BAKE.engine_key(), code])

static func _load_consumable_territories(persist: bool = false) -> Dictionary:
	var key: String = consumable_territory_bake_key()
	var baked: Variant = BAKE.read(CONSUMABLE_TERRITORY_BAKE, key)
	if baked is Dictionary and baked.size() * 2 == CONSUMABLE_TERRITORY_LAYOUT.spans.size():
		var valid: bool = true
		for id: Variant in baked:
			var row: Variant = baked[id]
			if not id is int or not row is Dictionary or not SOURCE._integer(row.get("ID")) or int(row.ID) != id:
				valid = false
				break
		if valid: return baked
	var rows: Dictionary = SOURCE._read_consumable_territories(_read_member("content/Territories.json"))
	if persist and not rows.is_empty() and not key.is_empty(): BAKE.write(CONSUMABLE_TERRITORY_BAKE, key, rows)
	return rows

const CRAFT_INPUT_LAYOUT: Dictionary = preload("res://scripts/resources/current523_craft_input_spans.gd").LAYOUT
const CRAFT_INPUT_IDS_BAKE := "source523_craft_input_ids"
const CRAFT_INPUT_UNIQUE_IDS := 3133

## The item supplier only needs membership. Crafting itself still reads the
## complete rules and quantities through related()/rows_matching().
static func item_craft_input_declared(item_id: int) -> bool:
	if item_id <= 0 or SOURCE.EXCLUDED_TABLES.has("ItemCraftInput") or not _source_current(): return false
	if _craft_input_ids.is_empty(): _craft_input_ids = _load_craft_input_ids(false)
	if _craft_input_ids.is_empty(): return not SOURCE.related("ItemCraftInput", "ItemClassID", item_id).is_empty()
	var index: int = _craft_input_ids.bsearch(item_id)
	return index < _craft_input_ids.size() and _craft_input_ids[index] == item_id

static func craft_input_bake_key() -> String:
	var code: String = BAKE.code_key(["res://scripts/resources/current523_consumable_queries.gd",
		"res://scripts/resources/current523_definition_rows.gd",
		"res://scripts/resources/current523_craft_input_spans.gd"])
	return BAKE.key(["craft-input-ids.v1", SOURCE.verified_key(), CRAFT_INPUT_LAYOUT.sha, BAKE.engine_key(), code])

static func _load_craft_input_ids(persist: bool) -> PackedInt32Array:
	var key: String = craft_input_bake_key()
	var baked: Variant = BAKE.read(CRAFT_INPUT_IDS_BAKE, key)
	if baked is PackedInt32Array and baked.size() == CRAFT_INPUT_UNIQUE_IDS:
		var valid: bool = true
		var previous: int = 0
		for id: int in baked:
			if id <= previous:
				valid = false
				break
			previous = id
		if valid: return baked
	var ids: PackedInt32Array = _read_craft_input_ids(_read_member("content/ItemCraftInput.json"))
	if persist and not ids.is_empty() and not key.is_empty(): BAKE.write(CRAFT_INPUT_IDS_BAKE, key, ids)
	return ids

static func _read_craft_input_ids(bytes: PackedByteArray) -> PackedInt32Array:
	if bytes.size() != int(CRAFT_INPUT_LAYOUT.bytes): return PackedInt32Array()
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(bytes) != OK or hash.finish().hex_encode() != CRAFT_INPUT_LAYOUT.sha:
		return PackedInt32Array()
	var unique: Dictionary = {}
	var spans: Array = CRAFT_INPUT_LAYOUT.spans
	var rows: int = 0
	for index: int in range(0, spans.size(), 3):
		var parser := JSON.new()
		if parser.parse("[" + bytes.slice(spans[index], spans[index + 1]).get_string_from_utf8() + "]") != OK:
			return PackedInt32Array()
		var batch: Array = parser.data
		if batch.size() != spans[index + 2]: return PackedInt32Array()
		for value: Dictionary in batch:
			var item_id: Variant = value.get("ItemClassID")
			if not SOURCE._integer(item_id) or item_id <= 0 or item_id > 2147483647: return PackedInt32Array()
			unique[int(item_id)] = true
		rows += batch.size()
	if rows != CRAFT_INPUT_LAYOUT.rows or unique.size() != CRAFT_INPUT_UNIQUE_IDS: return PackedInt32Array()
	var result := PackedInt32Array(unique.keys())
	result.sort()
	return result
