extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Read-only bridge to the existing verified native catalog. It grants nothing,
## registers nothing and never converts an unavailable original into an alias.
const C = preload("res://scripts/equipment523/common.gd")
const OWNER_PATH: String = "res://scripts/loot/patch523_monster_drops.gd"
const IDENTITY_FIELDS: Array[String] = ["name","sourceId","source","sourceUrl","source_snapshot","source_item_class_id","source_m_native_item","source_bless_raw","source_display_name","slot","type","grade","source_legacy_catalog_alias","source_legacy_stack_variant"]

static func whole(value: Variant) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 1 or float(value) > 9007199254740991.0: return 0
	return int(value)

static func same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return is_finite(float(a)) and is_finite(float(b)) and a == b
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not same(a[index],b[index]): return false
		return true
	return a == b

static func resolve(pack: Dictionary, record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item") != true or not record.get("source_m_native_item") is bool: return {}
	var id: int = whole(record.get("source_item_class_id"))
	if not preload("res://scripts/quests/source_dummy523.gd").item_id_evidence(id).is_empty():return {}
	if id <= 0 or C.item(pack,id).is_empty() or not ResourceLoader.exists(OWNER_PATH): return {}
	var owner: Variant = load(OWNER_PATH)
	if owner == null: return {}
	for method: String in ["pack_identity","item_definition","expected_variant","equipment"]:
		if not owner.has_method(method): return {}
	var identity: Dictionary = owner.pack_identity()
	if identity.is_empty(): return {}
	# item_definition rechecks the actual active sidecar and exact saved variant.
	var definition: Dictionary = owner.item_definition(record)
	if definition.is_empty(): return {}
	var expected: Dictionary = owner.expected_variant(definition.get("native_record",{}),record)
	return validate_identity(pack,record,definition,expected,identity,bool(owner.equipment(expected)))

static func validate_identity(pack: Dictionary, record: Dictionary, definition: Dictionary, expected: Dictionary, identity: Dictionary, equipment: bool) -> Dictionary:
	# Pure contract reducer, also used by explicitly synthetic kernel tests.
	if pack.get("source_sha256") != C.SOURCE_SHA or identity.get("schema") not in [3,4] or identity.get("source_snapshot") != "patch523": return {}
	if identity.get("schema")==4:
		if identity.get("kind")!="current523_original_definition_projection" or identity.get("source_definition_archive",{}).get("source_sha256")!=C.SOURCE_SHA or expected.get("source_projection")!="current523_original_typed_game_dto_v1" or NATIVE_FIELDS.full(expected).get("source_original_item")!=definition.get("original_item"):return {}
	var digest: Variant = identity.get("sha256")
	if not digest is String or digest.length() != 64 or not digest.is_valid_hex_number(false) or digest != digest.to_lower(): return {}
	if not record.get("source_m_native_item") is bool or record.source_m_native_item != true or expected.get("source_m_native_item") != true: return {}
	var id: int = whole(record.get("source_item_class_id"))
	var bless: int = whole(record.get("source_bless_raw"))
	var original: Dictionary = definition.get("original_item",{})
	var raw: Dictionary = C.item(pack,id).get("raw",{})
	if id <= 0 or bless not in [1,2,3] or whole(original.get("ID")) != id or whole(expected.get("source_item_class_id")) != id or raw.is_empty(): return {}
	if original.get("TestItem") != false or not original.get("TestItem") is bool: return {}
	for key: Variant in raw:
		if not original.has(key) or not same(original[key],raw[key]): return {}
	for field: String in IDENTITY_FIELDS:
		if record.has(field) != expected.has(field) or not same(record.get(field),expected.get(field)): return {}
	if record.get("source_snapshot") != "patch523" or not record.get("name") is String or str(record.name).is_empty(): return {}
	if not bool(record.get("source_legacy_catalog_alias",false)):
		var host_id: String = "m523:item:"+str(id)
		if not equipment and bless != 1: host_id += ":bless:"+str(bless)
		if record.get("sourceId") != host_id: return {}
	return {"source_id":id,"bless_code":bless,"equipment":equipment,"owner_sha256":digest}

static func _host_bless(value: Dictionary) -> int:
	var code: int = 0
	if value.has("blessed"):
		if not value.blessed is bool: return -1
		code = 2 if value.blessed else 1
	if value.has("bless_state"):
		if not value.bless_state is String: return -1
		var state: String = str(value.bless_state).to_lower()
		var parsed: int = int({"normal":1,"blessed":2,"축복":2,"cursed":3,"저주":3}.get(state,0))
		if parsed == 0 or code != 0 and code != parsed: return -1
		code = parsed
	return code

static func processing_bless(record: Dictionary, physical: Dictionary, identity: Dictionary) -> int:
	var raw: int = whole(identity.get("bless_code"))
	if raw not in [1,2]: return 0 # Cursed native ownership is not a new processing domain.
	var current: int = _host_bless(physical)
	var stored: int = _host_bless(record)
	var explicit: int = whole(physical.get("source_bless_code")) if physical.has("source_bless_code") else 0
	if current < 0 or stored < 0 or physical.has("source_bless_code") and explicit not in [1,2]: return 0
	if not bool(identity.get("equipment",false)):
		if current != 0 and current != raw or stored != 0 and stored != raw or explicit != 0 and explicit != raw: return 0
		return raw
	# Existing ordinary gear blessing/removal changes live host flags. It may
	# supersede a historical gear raw code; stack identities cannot do this.
	if current != 0: return current if current in [1,2] else 0
	if stored != 0: return stored if stored in [1,2] else 0
	return explicit if explicit != 0 else raw
