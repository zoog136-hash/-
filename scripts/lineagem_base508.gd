extends RefCounted
## Verified client snapshot definitions. Source IDs are namespaced; never match old IDs by integer/name.
const CARD_PATH = "res://data/lineagem_base508/cards.json"
const NPC_PATH = "res://data/lineagem_base508/npc_classes.json"
static var _cards: Dictionary = {}
static var _by_id: Dictionary = {}
static var _npcs: Dictionary = {}
static func cards() -> Dictionary:
	if _cards.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_PATH))
		if value is Dictionary and value.get("source_snapshot", "") == "base508":
			_cards = value
			for category: String in value.get("catalog", {}):
				for record: Dictionary in value.catalog[category]: _by_id[str(record.sourceId)] = record
	return _cards
static func native(record: Dictionary) -> bool:
	return record.get("source", "") == "lineagem_base508"
static func canonical(record: Dictionary) -> Dictionary:
	if not native(record): return record
	cards()
	return _by_id.get(str(record.get("sourceId", "")), record)
static func apply_catalog(existing: Dictionary) -> Dictionary:
	var data: Dictionary = cards()
	if data.is_empty(): return existing
	var result: Dictionary = existing.duplicate(true)
	# Keep the former complete registry as data; do not delete or silently migrate owned identities.
	result["_legacy_collectibles_before_base508"] = {}
	for category: String in data.catalog:
		result._legacy_collectibles_before_base508[category] = existing.get(category, []).duplicate(true)
		result[category] = data.catalog[category].duplicate(true)
	return result
static func flat_bonus(record: Dictionary, type_name: String) -> int:
	var total: int = 0
	for detail: Dictionary in record.get("source_bonuses", []):
		if detail.get("application", "") == "unconditional_native_value" and detail.bonus_type.Name == type_name:
			total += int(detail.bonus.Value)
	return total
static func npc(source_id: int) -> Dictionary:
	if _npcs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPC_PATH))
		if data is Dictionary and data.get("source_snapshot", "") == "base508":
			for row: Dictionary in data.get("rows", []): _npcs[int(row.ID)] = row
	return _npcs.get(source_id, {})
static func npc_record(source_id: int, local_context: Dictionary) -> Dictionary:
	var row: Dictionary = npc(source_id)
	if row.is_empty(): return local_context
	var result: Dictionary = local_context.duplicate(true)
	result["source_m_npc_id"] = source_id
	result["source_m_snapshot"] = "base508"
	result["source_m_original"] = row.duplicate(true)
	result["source_m_previous_application"] = local_context.duplicate(true)
	result["name"] = str(row.get("DisplayName_from_DescId", ""))
	result["hp"] = int(row.HP)
	result["mp"] = int(row.MP)
	result["ac"] = int(row.AC)
	result["mr"] = int(row.MR)
	result["xp"] = int(row.Exp)
	# Combat level remains local unless an exact, nonzero spawn-context NpcLevel is supplied.
	if local_context.has("source_m_spawn_npc_level") and int(local_context.source_m_spawn_npc_level) > 0:
		result["lv"] = int(local_context.source_m_spawn_npc_level)
		result["source_m_level_origin"] = "NpcSpawnPackNpcClassView.NpcLevel_explicit_context"
	else:
		result["source_m_level_origin"] = "local_compatibility_only_native_level_unknown"
	return result
static var _icons: Dictionary = {}
static func icon(record: Dictionary) -> Texture2D:
	if not native(record):
		var legacy: String = str(record.get("image_path", ""))
		return load(legacy) as Texture2D if not legacy.is_empty() and ResourceLoader.exists(legacy) else null
	var asset: Variant = record.get("source_ui_assets", {}).get("DisplayBaseAssetID")
	if not asset is Dictionary: return null
	var path: String = "user://lineagem_base508/ui/" + str(asset.get("path", ""))
	if not FileAccess.file_exists(path): return null
	if _icons.has(path): return _icons[path]
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty(): return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if _icons.size() >= 96: _icons.erase(_icons.keys()[0])
	_icons[path] = texture
	return texture
