extends RefCounted
## Source offers are local authoritative configuration, never prices submitted by UI.
const PATH: String = "res://data/l1j/reviewed_shop_bindings.json"
const VISUAL_PATH: String = "res://data/l1j/live_visual_bindings.json"
const SQL_SHA: String = "819c1741e815321cf083aaba65aa5698f2be350cca37533a1e94da8121a351b8"
static var _enabled: bool = true

static func set_enabled(value: bool) -> void:
	_enabled = value

static func profiles(catalog: Array) -> Array:
	if not _enabled or not FileAccess.file_exists(PATH) or not FileAccess.file_exists(VISUAL_PATH): return []
	return validate(JSON.parse_string(FileAccess.get_file_as_string(PATH)), catalog,
		JSON.parse_string(FileAccess.get_file_as_string(VISUAL_PATH)))

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == float(int(value))

static func validate(payload: Variant, catalog: Array, visuals: Variant) -> Array:
	if not payload is Dictionary or not visuals is Dictionary: return []
	if int(payload.get("schema", 0)) != 1 or not bool(payload.get("enabled", false)) or str(payload.get("source_sql_sha256", "")) != SQL_SHA: return []
	if not payload.get("profiles", null) is Array or not visuals.get("items", null) is Array: return []
	var results: Array = []
	var counts: Dictionary = {}
	for raw: Variant in payload.profiles:
		if raw is Dictionary:
			var key: String = str(raw.get("source_npc_id", ""))
			counts[key] = int(counts.get(key, 0)) + 1
	for raw: Variant in payload.profiles:
		if not raw is Dictionary: continue
		var id: String = str(raw.get("source_npc_id", ""))
		var name_value: String = str(raw.get("name", ""))
		var npc: Variant = raw.get("source_npc_row", null)
		if int(counts.get(id, 0)) != 1 or not npc is Dictionary or name_value.is_empty(): continue
		if not _whole(npc.get("npcid"), 1, 10000000) or id != "ext:a3:npc:%d" % int(npc.npcid) or name_value != str(npc.get("desc_kr", "")): continue
		if not raw.get("goods", null) is Array: continue
		var goods: Array = []
		var seen: Dictionary = {}
		var duplicate: bool = false
		for offer: Variant in raw.goods:
			if not offer is Dictionary: continue
			var game_id: String = str(offer.get("game_source_id", ""))
			var item_name: String = str(offer.get("game_name", ""))
			if seen.has(game_id): duplicate = true
			seen[game_id] = true
			var matches: Array = []
			var names: int = 0
			for item: Variant in catalog:
				if not item is Dictionary: continue
				if str(item.get("name", "")) == item_name: names += 1
				if str(item.get("sourceId", "")) == game_id and str(item.get("name", "")) == item_name: matches.append(item)
			if names != 1 or matches.size() != 1 or str(matches[0].get("slot", "")) != "weapon": continue
			var identity_matches: int = 0
			for image: Variant in visuals.items:
				if image is Dictionary and str(image.get("game_source_id", "")) == game_id and str(image.get("game_name", "")) == item_name and str(image.get("source_candidate_id", "")) == str(offer.get("source_item_id", "")):
					identity_matches += 1
			if identity_matches != 1: continue
			var row: Variant = offer.get("source_shop_row", null)
			if not row is Dictionary: continue
			if not _whole(row.get("npc_id"), 1, 10000000) or int(row.npc_id) != int(npc.npcid): continue
			if not _whole(row.get("item_id"), 1, 10000000) or str(offer.get("source_item_id", "")) != "ext:a3:weapon:%d" % int(row.item_id): continue
			if not _whole(row.get("selling_price"), 1, 1000000000) or not _whole(offer.get("price"), 1, 1000000000) or int(offer.price) != int(row.selling_price): continue
			if not _whole(row.get("pack_count"), 0, 1) or not _whole(offer.get("quantity"), 1, 1): continue
			if not _whole(row.get("enchant"), 0, 0) or not _whole(offer.get("enchant"), 0, 0) or str(row.get("pledge_rank", "")) != "NONE(없음)": continue
			var accepted: Dictionary = offer.duplicate(true)
			accepted["record"] = matches[0].duplicate(true)
			goods.append(accepted)
		if not duplicate and not goods.is_empty():
			results.append({"source_npc_id": id, "name": name_value, "goods": goods})
	return results

static func offer_for(vendor_id: String, item_name: String, catalog: Array) -> Dictionary:
	for profile: Dictionary in profiles(catalog):
		if str(profile.source_npc_id) != vendor_id: continue
		for offer: Dictionary in profile.goods:
			if str(offer.game_name) == item_name: return offer.duplicate(true)
	return {}
