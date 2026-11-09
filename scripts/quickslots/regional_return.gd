extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## QuickSlotChange projects item bindings; it never rewrites the saved slot array.
const DATA = preload("res://data/quickslots/regional_return_523.json")
const SETTING = "regional_return_enabled"

static func item_id(item_name: String) -> int:
	for key: String in DATA.data.items:
		var item: Dictionary = DATA.data.items[key]
		if item_name == item.name or item_name in item.aliases: return int(key)
	return 0

static func claims_identity(item_name: String, record: Dictionary) -> bool:
	return item_id(item_name) != 0 or DATA.data.items.has(str(int(record.get("source_item_class_id", 0))))

static func stack_identity(item_name: String, record: Dictionary = {}) -> Dictionary:
	var id: int = item_id(item_name)
	var origin: String = "host"
	if record.get("source_m_native_item", false):
		id = int(record.get("source_item_class_id", 0))
		if not DATA.data.items.has(str(id)): return {}
		var canonical: String = str(DATA.data.items[str(id)].name)
		# PR238's exact Normal stack, not a name suffix parser or a merged alias.
		if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("sourceId") != "m523:item:"+str(id): return {}
		if record.get("source_display_name") != canonical or item_name != canonical+" · 원본#"+str(id) or record.get("name") != item_name: return {}
		if record.get("source_bless_raw") != 1 or record.get("slot") != "consumable" or NATIVE_FIELDS.full(record).get("source_is_consumable") != true or record.get("source_test_item") != false or record.get("grade") != DATA.data.items[str(id)].grade: return {}
		origin = "patch523_native_normal"
	else:
		if id == 0: return {}
		if record.has("source_item_class_id") and int(record.source_item_class_id) != id: return {}
		if record.has("source523_shop_item_id") and int(record.source523_shop_item_id) != id: return {}
		if int(record.get("source_bless_raw", 1)) != 1 or record.get("bless_state", "") in ["blessed", "cursed", "축복", "저주"]: return {}
	return {"item_class_id":id, "bless_raw":1, "inventory_key":item_name, "origin":origin, "infinite":bool(DATA.data.items[str(id)].infinite)}

static func supported(item_name: String, record: Dictionary = {}) -> bool:
	return not stack_identity(item_name, record).is_empty()

static func _lookup(item_name: String, resolver: Callable) -> Dictionary:
	if not resolver.is_valid(): return {}
	var value: Variant = resolver.call(item_name)
	return value if value is Dictionary else {}

static func target_key(id: int, inventory: Dictionary, resolver: Callable = Callable()) -> String:
	var canonical: String = str(DATA.data.items[str(id)].name)
	# Select one actual owned key. Counts and blessing states never coalesce.
	for key: String in [canonical] + DATA.data.items[str(id)].aliases:
		if int(inventory.get(key, 0)) > 0 and int(stack_identity(key, _lookup(key, resolver)).get("item_class_id", 0)) == id: return key
	for key: String in inventory:
		if int(inventory[key]) > 0 and int(stack_identity(key, _lookup(key, resolver)).get("item_class_id", 0)) == id: return key
	return canonical

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

static func effective(entry: Dictionary, land_id: int, enabled: bool, inventory: Dictionary, resolver: Callable = Callable()) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	if not enabled or str(entry.get("kind", "")) != "item": return result
	var key: String = str(entry.get("id", ""))
	var source_id: int = int(stack_identity(key, _lookup(key, resolver)).get("item_class_id", 0))
	if not DATA.data.lands.has(str(land_id)):return result
	for approved: Variant in DATA.data.source_item_ids:
		if int(approved)!=source_id:continue
		result["id"] = target_key(int(DATA.data.target_item_id), inventory, resolver)
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
