extends RefCounted
## QuickSlotChange projects item bindings; it never rewrites the saved slot array.
const DATA = preload("res://data/quickslots/regional_return_523.json")
const SETTING = "regional_return_enabled"

static func item_id(item_name: String) -> int:
	for key: String in DATA.data.items:
		var item: Dictionary = DATA.data.items[key]
		if item_name == item.name or item_name in item.aliases: return int(key)
	return 0

static func supported(item_name: String) -> bool:
	return item_id(item_name) != 0

static func validate_save(data: Dictionary) -> String:
	var prefs: Variant = data.get("ui_preferences", {})
	if prefs is Dictionary and prefs.has(SETTING) and not prefs[SETTING] is bool:
		return "지역별 귀환 설정이 손상되었습니다 · 원본 저장 보존"
	return ""

static func land_for(map_id: String, map_data: Dictionary, field_data: Dictionary) -> int:
	# Explicit M Land identity wins over any host adaptation, including unknown IDs.
	for context: Dictionary in [field_data, map_data]:
		if context.has("source_land_id"): return int(context.source_land_id)
	var binding: Dictionary = DATA.data.host_bindings.get(map_id, {})
	return int(binding.get("land_id", 0))

static func effective(entry: Dictionary, land_id: int, enabled: bool, inventory: Dictionary) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	if not enabled or str(entry.get("kind", "")) != "item": return result
	var source_id: int = item_id(str(entry.get("id", "")))
	for group: Dictionary in DATA.data.groups:
		if int(group.ItemClassID) != source_id: continue
		for change: Dictionary in DATA.data.changes:
			if int(change.QuickSlotChangeID) != int(group.ID) or int(change.LandID) != land_id: continue
			var target: Dictionary = DATA.data.items[str(int(change.ItemClassID))]
			var target_name: String = str(target.name)
			# Exact aliases only. Never replace a missing regional scroll with a base scroll.
			for alias: String in target.aliases:
				if int(inventory.get(target_name, 0)) <= 0 and int(inventory.get(alias, 0)) > 0: target_name = alias
			result["id"] = target_name
			result["regional_original_id"] = str(entry.id)
			result["regional_land_id"] = land_id
			return result
	return result

static func catalog_items() -> Array:
	var result: Array = []
	for key: String in DATA.data.items:
		var item: Dictionary = DATA.data.items[key]
		result.append({"name":str(item.name), "sourceId":key, "grade":str(item.grade), "type":"이동주문서", "slot":"consumable",
			"desc":"잊혀진 섬 시작 지점으로 귀환 · 기존 지도는 TWILIGHT 대응" if key == "126424" else ("귀환 시 소모되지 않음" if item.infinite else "근처 마을로 귀환")})
	return result
