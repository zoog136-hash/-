extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## 523 membership selects candidates; loot_drop.gd owns all chances and counts.
const KIND = "patch523_monster_drop_membership"
const DATA_SHA = "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const PREVIOUS_FULL_DATA_SHA = "b812b3dc4b8e79dad50fedeb3ee279113a6dcad24d8a51f9fb1868ce98fb3750"
const PHASE4_DATA_SHA = "45e21a871a09f4ccf2898896adc8cfb1b766890646911d20b5a5b3c12f33fa45"
const FULL_ITEMS = preload("res://scripts/loot/patch523_item_catalog.gd")
const CURRENT_DTO=preload("res://scripts/loot/current523_native_item_projection.gd")
const CURRENT_SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const PHASE3_DATA_SHA = "bec901d26a7766f2c77e9781ce636f17c14e7ba1b33617840eb5a5d5123bafd3"
const PREVIOUS_DATA_SHA = "1d0756f1adc4de14e003af99fa487789f27d954a98e7c7e6ed7152d147164b6f"
const LEGACY_DATA_SHA = "4455cbbd2e6dc5392ccb2f142d99124ad2b5966e2dbca6d5fd3bb1f7b0cde0a3"
const FILE_NAME = "monster_drops.bin"
const RESOURCE_PATH = "res://data/lineagem_patch523/monster_drops.bin"
const STORE = "user://lineagem_patch523_drops"
const MAX_PACKED = 8 * 1024 * 1024
const MAX_RAW = 64 * 1024 * 1024
static var _data: Dictionary = {}
static var _checked: bool = false
static var _root: String = ""
static var _active_sha: String = ""
static var _sources: Dictionary = {}
static var diagnostics: Dictionary = {}
## Most recently resolved per-NPC membership documents (newest last). Older
## ones are rebuilt from the original rows on the next death of that NPC; the
## shared item references stay in data(), so a rebuild yields the same values.
static var _current_documents: Dictionary = {}
const DOCUMENT_CACHE_LIMIT: int = 16
## NPC IDs whose membership has been merged into data() (once per source).
static var _current_resolved: Dictionary = {}
static var _current_source_identity: Dictionary = {}
static var _current_drop_positions: Dictionary = {}
static var _current_reference_data: Dictionary = {}
static var _current_input_problem: String = ""
## Item definitions (Lineage M style): every definition is a pure function of
## the verified original and this code, so it is built on demand and only a
## small LRU of built [reference, definition] pairs stays resident (the whole
## original ItemData descriptions were ~264 KB each, >1 MB for boxes, and the
## former unbounded cache held ~78 MB at boot and grew with every kill).
## _definition_ids is the stable index: exactly the IDs (in the same order)
## the former data().item_definitions/source_item_references held, so
## has_definition()/cached_definition() answer as the former cache did.
## data().item_definitions/source_item_references stay as empty dictionaries;
## read them through the accessors below.
const DEFINITION_CACHE_LIMIT: int = 64
static var _definition_ids: Dictionary = {}
static var _definition_lru: Dictionary = {}

static func _source_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func installed_path(fingerprint: String = DATA_SHA) -> String:
	return STORE.path_join(fingerprint).path_join(FILE_NAME)

static func decode(packed: PackedByteArray) -> Dictionary:
	if packed.size() > MAX_PACKED or packed.is_empty(): return {}
	if preload("res://scripts/lineagem_pack_install.gd").sha(packed) not in [DATA_SHA, PREVIOUS_FULL_DATA_SHA, PHASE4_DATA_SHA, PHASE3_DATA_SHA, PREVIOUS_DATA_SHA, LEGACY_DATA_SHA]: return {}
	var raw: PackedByteArray = packed.decompress_dynamic(MAX_RAW, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty(): return {}
	var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not value is Dictionary or int(value.get("schema", 0)) not in [1, 2, 3] or value.get("kind") != KIND or value.get("source_snapshot") != "patch523": return {}
	if int(value.schema) < 3 and raw.size() > 32*1024*1024: return {}
	return value

static func _legacy_data_for_reference() -> Dictionary:
	# Decoder/installation/reference compatibility only. Final data() and
	# candidates() never select this former packed numeric input or fall back.
	if _checked: return _data
	_checked = true
	var paths: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-drop-root="): paths.append(arg.trim_prefix("--patch523-drop-root=").path_join(FILE_NAME))
	var explicit_count: int = paths.size()
	paths.append(installed_path())
	paths.append(RESOURCE_PATH)
	paths.append(installed_path(PREVIOUS_FULL_DATA_SHA))
	paths.append(installed_path(PHASE4_DATA_SHA))
	paths.append(installed_path(PHASE3_DATA_SHA))
	paths.append(installed_path(PREVIOUS_DATA_SHA))
	if LEGACY_DATA_SHA != DATA_SHA: paths.append(installed_path(LEGACY_DATA_SHA))
	var best_rank: int = 99
	var versions: Array[String] = [DATA_SHA,PREVIOUS_FULL_DATA_SHA,PHASE4_DATA_SHA,PHASE3_DATA_SHA,PREVIOUS_DATA_SHA,LEGACY_DATA_SHA]
	for index: int in range(paths.size()):
		var path: String = paths[index]
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_PACKED: continue
		var packed: PackedByteArray = file.get_buffer(file.get_length())
		var rank: int = versions.find(preload("res://scripts/lineagem_pack_install.gd").sha(packed))
		if rank < 0 or (index >= explicit_count and rank >= best_rank): continue
		var document: Dictionary = decode(packed)
		if document.is_empty() or not FULL_ITEMS.validate_files(document,path.get_base_dir()): continue
		_root = path.get_base_dir()
		_active_sha = versions[rank]
		_data = document
		best_rank = rank
		if index < explicit_count or rank == 0: return _data
	return _data

static func data() -> Dictionary:
	var source_identity: Dictionary = CURRENT_SOURCE.identity()
	if source_identity.is_empty():
		_current_reference_data.clear(); _current_documents.clear(); _current_resolved.clear(); _current_drop_positions.clear()
		_definition_ids.clear(); _definition_lru.clear()
		_current_source_identity = {}
		diagnostics = {"status":"current523_drop_input_unavailable","reason":CURRENT_SOURCE.problem()}
		return {}
	if source_identity != _current_source_identity:
		_current_reference_data.clear(); _current_documents.clear(); _current_resolved.clear(); _current_drop_positions.clear()
		_definition_ids.clear(); _definition_lru.clear()
		_current_source_identity = source_identity.duplicate(true)
	if _current_reference_data.is_empty():
		_current_reference_data = {"schema":2,"kind":KIND,"source_snapshot":"patch523",
			"input_kind":"current523_original_reference_rows","source_input_identity":source_identity,
			"npcs":{},"drops":{},"bindings":{},"bless_codes":{},"item_definitions":{},
			"source_item_references":{},"source_tables":{},"native_item_ids":[],"native_reward_item_ids":[],
			"full_item_catalog":false,"source_exclusion_evidence":[],"unavailable_source_definitions":[],
			"original_numeric_projection_complete":false,"native_record_status":"missing_current_native_record_projection",
			"reference_only":true,"can_activate":false,
			"remaining_contract":"Existing item supplier owns current native_record/effects/ownership; historical sidecars are excluded from final input"}
		for table: String in ["NpcClass","NpcCategory","NpcItemDropView","ItemClass","ItemBlessCode"]:
			_current_reference_data.source_tables[table] = CURRENT_SOURCE.table_metadata(table)
	return _current_reference_data

static func identity(record: Dictionary, admitted_registry: RefCounted = null) -> Dictionary:
	var original: Dictionary = record.get("source_m_original", {})
	var id: int = int(record.get("source_m_npc_id", -1))
	if record.get("source_m_snapshot", "") not in ["base508", "patch523"] or id <= 0 or int(original.get("ID", -2)) != id: return {}
	# Preserve native routing when current input is unavailable, so this source
	# actor cannot silently acquire a legacy/global loot pool instead.
	var result: Dictionary = {"kind":KIND,"source_npc_id":id,"source_sprite_id":int(original.get("Sprite",-1)),
		"source_name":str(original.get("Name","")),"current_source_admitted":false,
		"input_problem":"current523_admitted_npc_registry_unavailable"}
	var source_identity: Dictionary = CURRENT_SOURCE.identity()
	if source_identity.is_empty():
		result.input_problem = "current523_original_unavailable:"+CURRENT_SOURCE.problem()
		return result
	if admitted_registry == null or not admitted_registry.has_method("row"): return result
	var admitted: Variant = admitted_registry.get("admitted_source_identities")
	if not admitted is Dictionary or not admitted.get(str(id)) is Dictionary: return result
	var proof: Dictionary = admitted[str(id)]
	if admitted_registry.get("source_available") != true or admitted_registry.get("source_identity") != source_identity or proof.get("npc_class_id") != id or proof.get("source_archive_sha256") != source_identity.get("source_sha256"):
		return result
	var selected: Variant = admitted_registry.call("row","NpcClass",id)
	var current: Dictionary = CURRENT_SOURCE.row("NpcClass",id)
	if not selected is Dictionary or current.is_empty() or selected != current:
		result.input_problem = "current523_admitted_npc_source_mismatch"
		return result
	for field: String in ["ID","Sprite","DescId"]:
		if not _source_integer(current.get(field)) or not _source_integer(original.get(field)) or current[field] != original[field]:
			result.input_problem = "current523_actor_identity_mismatch:"+field
			return result
	if current.get("Name") != original.get("Name") or record.get("source_m_definition_snapshot") != "patch523" or record.get("source_m_definition_archive_sha256") != source_identity.get("source_sha256"):
		result.input_problem = "current523_actor_definition_not_admitted"
		return result
	result.current_source_admitted = true
	result.input_problem = ""
	result["source_desc_id"] = current.DescId
	result["source_input_identity"] = source_identity
	result["source_admission"] = proof.duplicate(true)
	return result

static func _current_item_reference(item_id: int) -> Dictionary:
	var entry: Array = _current_item_entry(item_id)
	return entry[0] if not entry.is_empty() else {}

## [reference, definition] for an item, remembering it in the stable index
## (what the former cache did on first read); [] when ItemData is unavailable.
static func _current_item_entry(item_id: int) -> Array:
	var document: Dictionary = data()
	if document.is_empty(): return []
	var id: String = str(item_id)
	if _definition_ids.has(id): return _known_entry(id)
	var detail: Dictionary = _describe_item(item_id)
	if detail.is_empty(): return []
	var entry: Array = [detail,_current_raw_definition(detail)]
	_definition_ids[id] = true
	_remember_entry(id,entry)
	return entry

## A known ID's pair: from the LRU, else shared from a cached NPC document
## (same objects, no rebuild), else rebuilt from the verified original. The
## build is deterministic for one source identity (all caches reset with it),
## so a rebuild equals what the former cache kept.
static func _known_entry(id: String) -> Array:
	if _definition_lru.has(id):
		var hit: Array = _definition_lru[id]
		_definition_lru.erase(id)
		_definition_lru[id] = hit
		return hit
	for document: Dictionary in _current_documents.values():
		if document.source_item_references.has(id) and document.item_definitions.has(id) and not document.source_item_references[id].is_empty():
			var shared: Array = [document.source_item_references[id],document.item_definitions[id]]
			_remember_entry(id,shared)
			return shared
	var detail: Dictionary = _describe_item(int(id))
	if detail.is_empty(): return []
	var built: Array = [detail,_current_raw_definition(detail)]
	_remember_entry(id,built)
	return built

static func _remember_entry(id: String, entry: Array) -> void:
	_definition_lru.erase(id)
	_definition_lru[id] = entry
	while _definition_lru.size() > DEFINITION_CACHE_LIMIT: _definition_lru.erase(_definition_lru.keys()[0])

## Same value as the former data().item_definitions.get(id,{}): the built
## definition for an ID that has been read before, {} otherwise. Does not
## remember new IDs (definition_id() does).
static func cached_definition(item_id: String) -> Dictionary:
	if data().is_empty() or not _definition_ids.has(item_id): return {}
	var entry: Array = _known_entry(item_id)
	return entry[1] if not entry.is_empty() else {}

## Same value as the former data().source_item_references.get(id,{}).
static func cached_reference(item_id: String) -> Dictionary:
	if data().is_empty() or not _definition_ids.has(item_id): return {}
	var entry: Array = _known_entry(item_id)
	return entry[0] if not entry.is_empty() else {}

## Former data().item_definitions.has(id) / source_item_references.has(id).
static func has_definition(item_id: String) -> bool:
	return not data().is_empty() and _definition_ids.has(item_id)

## Former data().item_definitions.keys() (same order) and .size().
static func definition_ids() -> Array:
	return _definition_ids.keys() if not data().is_empty() else []

static func definition_count() -> int:
	return _definition_ids.size() if not data().is_empty() else 0

## Former erase of an ID from both data() caches.
static func forget_definition(item_id: String) -> void:
	_definition_ids.erase(item_id)
	_definition_lru.erase(item_id)

## definition_id() without remembering an ID that was not read before (the
## former read-then-erase in the catalog registrar). Known IDs behave as
## definition_id().
static func transient_definition(item_id: String) -> Dictionary:
	if not item_id.is_valid_int() or int(item_id) <= 0 or item_id != str(int(item_id)): return {}
	if data().is_empty(): return {}
	if _definition_ids.has(item_id): return definition_id(item_id)
	var detail: Dictionary = _describe_item(int(item_id))
	return _current_raw_definition(detail) if not detail.is_empty() else {}

## Resident-memory diagnostics for the bounded cache.
static func definition_cache_state() -> Dictionary:
	return {"known_ids":_definition_ids.size(),"resident":_definition_lru.size(),"limit":DEFINITION_CACHE_LIMIT,"documents":_current_documents.size()}

## The former cache dictionaries were read directly by some callers. A
## document is that cache when it shares data()'s (now index-only) dictionary.
static func _document_definition(document: Dictionary, item_id: String) -> Dictionary:
	var definitions: Variant = document.get("item_definitions")
	if not _current_reference_data.is_empty() and definitions is Dictionary and is_same(definitions,_current_reference_data.get("item_definitions")):
		return cached_definition(item_id)
	return document.get("item_definitions",{}).get(item_id,{})

static func _describe_item(item_id: int) -> Dictionary:
	# ItemData retains a legacy helper preload of this module. Defer loading
	# until this actual read path; a static preload here would form a cycle.
	var path: String = "res://scripts/resources/current523_item_data.gd"
	if not ResourceLoader.exists(path): return {}
	var reader: Script = load(path) as Script
	if reader == null: return {}
	# ItemData.describe is the published static reader API. Match the script's
	# own methods before calling it; Resource instance methods are not that ABI.
	var has_describe: bool = false
	for method: Dictionary in reader.get_script_method_list():
		if method.get("name") == "describe": has_describe = true; break
	if not has_describe: return {}
	var detail: Variant = reader.call("describe",item_id,false)
	if not detail is Dictionary: return {}
	return detail

static func _current_raw_definition(reference: Dictionary) -> Dictionary:
	if reference.is_empty() or reference.get("source") != CURRENT_SOURCE.identity(): return {}
	var original: Dictionary = reference.get("item_class",{})
	if original.is_empty(): return {}
	# Same public compiler relationships, without inventing its game/effect DTO.
	var bonuses: Array = []; var equips: Array = []; var classes: Array = []
	for effect: Dictionary in reference.get("bonuses",[]):
		var row: Dictionary = effect.get("link",{}).duplicate(true)
		row["bonus"] = effect.get("bonus",{})
		row["bonus_type"] = effect.get("type",{})
		row["unit"] = effect.get("unit",{})
		bonuses.append(row)
	for effect: Dictionary in reference.get("equip_slots",[]):
		var row: Dictionary = effect.get("link",{}).duplicate(true)
		row["equip_slot"] = effect.get("slot",{})
		equips.append(row)
	for effect: Dictionary in reference.get("class_limits",[]):
		var row: Dictionary = effect.get("link",{}).duplicate(true)
		row["class"] = effect.get("class",{})
		classes.append(row)
	var definition: Dictionary={"original_item":original,"category":reference.get("category",{}),"grade":reference.get("grade",{}),
		"item_bonus":bonuses,"equip_rows":equips,"class_rows":classes,"native_record":{},"existing_binding":{},
		"source_invoke_options":[],"source_reference":reference,"source_typed_references":reference.get("typed_references",[]),
		"source_input_identity":reference.source,"excluded":reference.get("excluded",false),
		"declared_exclusion":reference.get("declared_exclusion",{}),"reference_only":true,"can_activate":false,
		"native_record_status":"missing_current_native_record_projection",
		"unresolved_source_reference":"missing_current_native_record_projection"}

	var projected: Dictionary=CURRENT_DTO.record(definition)
	if not projected.is_empty():
		definition.native_record=projected
		# Base-item weapon invokes (claw / dual blade / rifle bleed) for the
		# existing weapon_invoke_roll and patch523_weapon_bleed consumers.
		definition.source_invoke_options=preload("res://scripts/loot/current523_weapon_invokes.gd").compile(bonuses,projected)
		definition.native_record_status="current_original_typed_game_dto"
		definition.unresolved_source_reference=""
	return definition

## 1-based table position of each NpcItemDropView row ID. Kept as one sorted
## packed array of (ID << 20 | row) instead of a Dictionary of ~47k strings
## (~6 MB), built from the ID column without materializing every row.
const POSITION_ROW_LIMIT: int = 1048576
const POSITION_ID_LIMIT: int = 4398046511104

static func _current_source_positions() -> bool:
	if not _current_drop_positions.is_empty(): return true
	var metadata: Dictionary = CURRENT_SOURCE.table_metadata("NpcItemDropView")
	var count: int = CURRENT_SOURCE.row_count("NpcItemDropView")
	if not _source_integer(metadata.get("row_count")) or int(metadata.row_count) != count:
		_current_input_problem = "current523_NpcItemDropView_rows_or_provenance_unavailable"
		return false
	if count == 0: return true
	var column: Variant = CURRENT_SOURCE.column("NpcItemDropView","ID")
	var values: Array = []
	if (column is Array or column is PackedFloat64Array or column is PackedInt64Array or column is PackedInt32Array) and column.size() == count:
		values = Array(column)
	else:
		# Some row has no ID column value: read rows one at a time, as before.
		for index: int in count: values.append(CURRENT_SOURCE.row_at("NpcItemDropView",index).get("ID"))
	var composite := PackedInt64Array()
	var compact: bool = count < POSITION_ROW_LIMIT
	var fallback: Dictionary = {}
	for index: int in count:
		var value: Variant = values[index]
		if not _source_integer(value):
			_current_input_problem = "invalid_or_duplicate_original_drop_row_ID"
			return false
		var id: int = int(value)
		if compact and absi(id) >= POSITION_ID_LIMIT: compact = false
		if fallback.has(id):
			_current_input_problem = "invalid_or_duplicate_original_drop_row_ID"
			return false
		fallback[id] = index+1
	if compact:
		composite.resize(count)
		var position: int = 0
		for id: int in fallback:
			composite[position] = id*POSITION_ROW_LIMIT + int(fallback[id])
			position += 1
		composite.sort()
		_current_drop_positions = {"composite":composite}
	else:
		_current_drop_positions = {"ids":fallback}
	return true

## 0 when `id` is not a row ID of the verified NpcItemDropView.
static func _current_drop_position(id: int) -> int:
	if _current_drop_positions.has("ids"): return int(_current_drop_positions.ids.get(id,0))
	var composite: PackedInt64Array = _current_drop_positions.get("composite",PackedInt64Array())
	if composite.is_empty() or absi(id) >= POSITION_ID_LIMIT: return 0
	var at: int = composite.bsearch(id*POSITION_ROW_LIMIT, true)
	if at >= composite.size(): return 0
	var position: int = posmod(composite[at], POSITION_ROW_LIMIT)
	return position if (composite[at]-position)/POSITION_ROW_LIMIT == id else 0

static func _current_source_document(value: Dictionary) -> Dictionary:
	_current_input_problem = ""
	var source_identity: Dictionary = CURRENT_SOURCE.identity()
	if source_identity.is_empty():
		_current_input_problem = "current523_original_unavailable:"+CURRENT_SOURCE.problem()
		return {}
	if value.get("source_input_identity") != source_identity or value.get("current_source_admitted") != true:
		_current_input_problem = str(value.get("input_problem","current523_admitted_npc_source_unavailable"))
		if _current_input_problem.is_empty(): _current_input_problem = "current523_admitted_npc_source_mismatch"
		return {}
	var reference_document: Dictionary = data()
	if reference_document.is_empty(): return {}
	var npc_id: int = int(value.get("source_npc_id",-1))
	var id: String = str(npc_id)
	var npc: Dictionary = CURRENT_SOURCE.row("NpcClass",npc_id)
	if npc.is_empty() or npc.get("Sprite") != value.get("source_sprite_id") or npc.get("DescId") != value.get("source_desc_id") or npc.get("Name") != value.get("source_name"):
		_current_input_problem = "current523_admitted_npc_identity_mismatch"
		return {}
	if not CURRENT_SOURCE.declared_exclusion("NpcClass",npc).is_empty() or npc.get("TestNPC") != false or not _source_integer(npc.get("Category")):
		_current_input_problem = "current523_npc_excluded_or_category_unavailable"
		return {}
	var category: Dictionary = CURRENT_SOURCE.row("NpcCategory",int(npc.Category))
	if category.get("IsAttackable") != true or not category.get("IsShowDropInfo") is bool:
		_current_input_problem = "current523_npc_drop_category_unavailable"
		return {}
	if _current_documents.has(id):
		var cached: Dictionary = _current_documents[id]
		_current_documents.erase(id)
		_current_documents[id] = cached
		return cached
	if not _current_source_positions(): return {}
	var document: Dictionary = {"schema":2,"kind":KIND,"source_snapshot":"patch523",
		"input_kind":"current523_original_membership_with_exact_host_bindings","source_input_identity":source_identity,
		"npcs":{},"drops":{},"bindings":{},"item_definitions":{},"bless_codes":{},
		"source_tables":{},"source_item_references":{},"raw_drop_rows":[],"unavailable_source_definitions":[],
		"source_exclusion_evidence":[],"unresolved_item_ids":{},"host_binding_problems":{},"binding_provenance":{},"native_item_ids":[],
		"remaining_contract":"New native_record/game item projection and typed reward activation belong to their existing supplier/effect owner; host DTOs are not full original numeric projections"}
	var description: Dictionary = CURRENT_SOURCE.row("DescData_Korean",int(npc.DescId))
	document.npcs[id] = {"sprite_id":npc.Sprite,"source_name":npc.Name,"display_name":str(description.get("Description","")),"test_npc":npc.TestNPC,
		"category_id":npc.Category,"show_drop_info":category.IsShowDropInfo,"attackable":category.IsAttackable}
	var active: Array = []
	for raw: Dictionary in CURRENT_SOURCE.related("NpcItemDropView","NpcClassID",npc_id):
		document.raw_drop_rows.append(raw)
		var valid: bool = true
		for field: String in ["ID","NpcClassID","ItemClassID","Bless","RequiredQuestID"]:
			if not _source_integer(raw.get(field)) or raw[field] < 0: valid = false
		if not valid or raw.get("NpcClassID") != npc_id or _current_drop_position(int(raw.get("ID",-1))) == 0:
			document.unavailable_source_definitions.append({"table":"NpcItemDropView","row":raw,"reason":"invalid_original_drop_reference"})
			continue
		var exclusion: Dictionary = CURRENT_SOURCE.declared_exclusion("NpcItemDropView",raw)
		if not exclusion.is_empty():
			document.source_exclusion_evidence.append({"table":"NpcItemDropView","row":raw,"evidence":exclusion})
			continue
		var item_id: String = str(int(raw.ItemClassID))
		if not document.source_item_references.has(item_id):
			# The same values as before; the definition object is now shared
			# with the bounded owner cache instead of being built twice.
			var entry: Array = _current_item_entry(int(raw.ItemClassID))
			document.source_item_references[item_id] = entry[0] if not entry.is_empty() else {}
			document.item_definitions[item_id] = entry[1] if not entry.is_empty() else {}
		var detail: Dictionary = document.source_item_references[item_id]
		var item: Dictionary = detail.get("item_class",{})
		if item.get("ID") != raw.ItemClassID or detail.get("source") != source_identity:
			document.unresolved_item_ids[item_id] = "current523_item_reference_unavailable"
			continue
		if detail.get("excluded",false) or typeof(item.get("TestItem")) != TYPE_BOOL:
			document.unresolved_item_ids[item_id] = "source_item_excluded_or_test_declaration_unavailable"
			if detail.has("declared_exclusion"): document.source_exclusion_evidence.append({"table":"ItemClass","row":item,"evidence":detail.declared_exclusion})
			continue
		var bless: Dictionary = CURRENT_SOURCE.row("ItemBlessCode",int(raw.Bless))
		if bless.is_empty() or not bless.get("Name") is String or not CURRENT_SOURCE.declared_exclusion("ItemBlessCode",bless).is_empty():
			document.unavailable_source_definitions.append({"table":"NpcItemDropView","row":raw,"reason":"original_bless_reference_unavailable"})
			continue
		document.bless_codes[str(int(raw.Bless))] = str(bless.Name).to_lower()
		var row: Dictionary = raw.duplicate(true)
		row["source_row_1based"] = _current_drop_position(int(raw.ID))
		active.append(row)
	document.drops[id] = active
	for table: String in ["NpcClass","NpcCategory","NpcItemDropView","ItemClass","ItemBlessCode","DescData_Korean"]:
		document.source_tables[table] = CURRENT_SOURCE.table_metadata(table)
	# Only actually admitted NPC memberships enter this read registry. The
	# existing executor still consumes the separately resolved exact host DTOs.
	# A rebuilt (evicted) document was merged already; merge only once.
	if not _current_resolved.has(id):
		_current_resolved[id] = true
		reference_document.npcs[id] = document.npcs[id]
		reference_document.drops[id] = active.duplicate(true)
		for bless: String in document.bless_codes: reference_document.bless_codes[bless] = document.bless_codes[bless]
		reference_document.source_exclusion_evidence.append_array(document.source_exclusion_evidence)
		reference_document.unavailable_source_definitions.append_array(document.unavailable_source_definitions)
	_current_documents[id] = document
	while _current_documents.size() > DOCUMENT_CACHE_LIMIT: _current_documents.erase(_current_documents.keys()[0])
	return document

static func _current_missing_reference_evidence(value: Variant, evidence: Array, path: String = "item_data") -> void:
	# These are diagnostics emitted by the existing raw readers, not inferred
	# item names or unsupported-effect/dummy classifications.
	if value is Dictionary:
		var blockers: Variant = value.get("blockers",[])
		if blockers is Array:
			for blocker: Variant in blockers:
				if not blocker is String: continue
				if blocker.begins_with("missing_source_reference:") or blocker.begins_with("ambiguous_source_reference:") or blocker.begins_with("invalid_source_reference:") or blocker in ["source_item_unavailable","source_bonus_unavailable","source_spell_unavailable","source_buff_unavailable","source_test_declaration_missing"]:
					evidence.append({"path":path,"blocker":blocker})
		var unresolved: Variant = value.get("unresolved",[])
		if unresolved is Array:
			for entry: Variant in unresolved:
				if entry is Dictionary and entry.get("reason") in ["source_row_missing_or_ambiguous","source_reference_is_not_an_integer"]:
					evidence.append({"path":path,"reference":entry})
		for key: Variant in value:
			if value[key] is Dictionary or value[key] is Array:
				_current_missing_reference_evidence(value[key],evidence,path+"."+str(key))
	elif value is Array:
		for index: int in range(value.size()):
			_current_missing_reference_evidence(value[index],evidence,path+"["+str(index)+"]")

static func _current_declared_child_evidence(value: Variant, evidence: Array, path: String = "item_data") -> void:
	if value is Dictionary:
		if value.get("excluded") == true:
			evidence.append({"path":path,"reason":"source_child_declared_exclusion","reference":value})
		for key: Variant in value:
			if value[key] is Dictionary or value[key] is Array:
				_current_declared_child_evidence(value[key],evidence,path+"."+str(key))
	elif value is Array:
		for index: int in range(value.size()):
			_current_declared_child_evidence(value[index],evidence,path+"["+str(index)+"]")

static func _current_host_condition_admission(detail: Dictionary) -> Dictionary:
	var evidence: Array = []
	_current_missing_reference_evidence(detail,evidence)
	var source: Dictionary = detail.get("item_class",{})
	if not source.has("ServiceRegionCode") or not source.ServiceRegionCode is String:
		evidence.append({"table":"ItemClass","field":"ServiceRegionCode","row":source,"reason":"source_field_missing_or_invalid"})
	if not evidence.is_empty(): return {"reason":"missing_source_reference","evidence":evidence,"item_data_ok":detail.get("ok",false)}
	_current_declared_child_evidence(detail,evidence)
	if not str(source.ServiceRegionCode).is_empty():
		evidence.append({"table":"ItemClass","field":"ServiceRegionCode","value":source.ServiceRegionCode,"row":source,
			"reason":"source_service_region_context_not_represented_by_exact_host_DTO"})
	for effect: Dictionary in detail.get("bonuses",[]):
		if effect.get("type",{}).get("Name") == "DeleteTime":
			# Do not interpret zero, units, target IDs, dates or current expiry.
			evidence.append({"table":"ItemBonus","reference":effect,"reason":"source_item_lifetime_not_represented_by_exact_host_DTO"})
	for reference: Dictionary in detail.get("typed_references",[]):
		var card: Dictionary = reference.get("card",{})
		if card.is_empty(): continue
		# Public fixed-card/book compiler preserves these exact conditions.
		# The bounded Inven DTO has no corresponding checked use contract.
		for field: String in ["StartDateTimeID","EndDateTimeID","ServerLimitSetID"]:
			if not _source_integer(card.get(field)):
				return {"reason":"missing_source_reference","item_data_ok":detail.get("ok",false),
					"evidence":[{"table":"BuffCard","field":field,"row":card,"reason":"source_field_missing_or_invalid"}]}
			if int(card[field]) != 0:
				evidence.append({"table":"BuffCard","field":field,"value":card[field],"row":card,
					"item_reference":reference,"reason":"source_card_date_or_server_contract_not_represented_by_exact_host_DTO"})
	if not evidence.is_empty(): return {"reason":"unsupported_source_item_condition","evidence":evidence,"item_data_ok":detail.get("ok",false)}
	return {}

## The same values as original.duplicate(true) for this resolution. The item
## references (whole original ItemData descriptions, up to MBs per box item),
## definitions, rows and NPC entries are only read here and by resolve(), so
## they are shared with the cached document instead of deep-copied on every
## death; only the containers a resolution writes get their own copy.
const WORKING_WRITES: Array[String] = ["bindings","unresolved_item_ids","host_binding_problems","binding_provenance","unavailable_source_definitions"]
static func _working_document(original: Dictionary) -> Dictionary:
	var document: Dictionary = original.duplicate(false)
	for key: String in WORKING_WRITES:
		var value: Variant = document.get(key)
		if value is Dictionary or value is Array: document[key] = value.duplicate(false)
	return document

static func _current_host_bindings(original: Dictionary, catalog: Dictionary) -> Dictionary:
	# Same bounded public compiler binding: exact Inven ID/URL, one current
	# inventory name, and one of the two declared localized descriptors.
	# A former native sidecar DTO/alias is never accepted as this host source.
	var document: Dictionary = _working_document(original)
	document["source_condition_evidence"] = {}
	var unique: Variant = catalog.get("patch523_by_name")
	if not unique is Dictionary:
		for id: String in document.source_item_references:
			if document.unresolved_item_ids.has(id): continue
			document.unresolved_item_ids[id] = "missing_current_native_record_projection"
			document.host_binding_problems[id] = "current_unique_catalog_index_missing"
		return document
	var by_id: Dictionary = {}
	for item: Variant in unique.values():
		if not item is Dictionary or item.get("source") != "inven" or item.get("source_m_native_item",false) or item.get("source_legacy_catalog_alias",false): continue
		var source_id: String = str(item.get("sourceId",""))
		if not source_id.is_valid_int() or int(source_id) <= 0 or source_id != str(int(source_id)): continue
		if not by_id.has(source_id): by_id[source_id] = []
		by_id[source_id].append(item)
	for id: String in document.source_item_references:
		var detail: Dictionary = document.source_item_references[id]
		var source: Dictionary = detail.get("item_class",{})
		# Keep explicit Test/dummy exclusion distinct from missing references
		# and unsupported conditions; no unsupported effect becomes a dummy.
		if detail.get("excluded",false): continue
		var admission: Dictionary = _current_host_condition_admission(detail)
		if not admission.is_empty():
			document.unresolved_item_ids[id] = admission.reason
			document.host_binding_problems[id] = admission.reason
			document.source_condition_evidence[id] = admission
			document.unavailable_source_definitions.append({"table":"ItemClass","row":source,
				"reason":admission.reason,"condition_evidence":admission.evidence})
			continue
		if document.unresolved_item_ids.has(id): continue
		var candidates: Array = by_id.get(id,[])
		var reason: String = "no_unique_exact_native_ID_in_existing_catalog"
		if candidates.size() == 1:
			var item: Dictionary = candidates[0]
			if item.get("sourceUrl") != "https://lineagem.inven.co.kr/db/item/"+id:
				reason = "exact_host_source_URL_ID_mismatch"
			else:
				var labels: Array[String] = []
				for field: String in ["DescID","IdentifiedDescID"]:
					if not _source_integer(source.get(field)): continue
					var text: Dictionary = CURRENT_SOURCE.row("DescData_Korean",int(source[field]))
					if text.get("Description") is String: labels.append(str(text.Description).strip_edges())
				var name_value: String = str(item.get("name",""))
				if not name_value.is_empty() and name_value.strip_edges() in labels and unique.get(name_value,{}) == item:
					var binding: Dictionary = {}
					for field: String in ["name","source","sourceId","sourceUrl","slot","type","grade"]: binding[field] = item.get(field,"")
					document.bindings[id] = binding
					document.binding_provenance[id] = {"membership":"current523_original_NpcItemDropView",
						"item_reference":"current523_original_ItemData","game_dto":"existing_public_Inven_host_catalog",
						"original_numeric_projection_complete":false,"new_native_record_supplied":false,
						"typed_reward_activation":"existing_owner_required","source_input_identity":document.source_input_identity}
					continue
				reason = "exact_host_localized_descriptor_mismatch"
		document.unresolved_item_ids[id] = "missing_current_native_record_projection"
		document.host_binding_problems[id] = reason
	return document

static func _current_native_bindings(document: Dictionary,catalog: Dictionary,context: Dictionary) -> Dictionary:
	if document.is_empty():return {}
	var index: Variant=catalog.get("patch523_by_name",{})
	if not index is Dictionary:return document
	var by_source: Dictionary={}
	for value: Variant in index.values():
		if not value is Dictionary:continue
		var key: String=str(value.get("sourceId",""))
		if not by_source.has(key):by_source[key]=[]
		by_source[key].append(value)
	var supply: Script=load("res://scripts/cards/native_awakening_supply.gd")
	for id: String in document.source_item_references:
		if document.bindings.has(id):continue
		var detail: Dictionary=document.source_item_references[id]
		var current: Dictionary=definition_id(id).get("native_record",{})
		if current.is_empty() or detail.get("excluded",false):continue
		var condition: Dictionary=_current_host_condition_admission(detail)
		if not condition.is_empty():
			var unresolved: bool=false
			for evidence: Dictionary in condition.get("evidence",[]):
				if evidence.get("reason")!="source_item_lifetime_not_represented_by_exact_host_DTO":unresolved=true
			if unresolved:document.unresolved_item_ids[id]=condition.reason;continue
		var choices: Array=by_source.get("m523:item:"+id,[])
		if choices.size()!=1:continue
		var item: Dictionary=choices[0]
		var typed: bool=supply!=null and supply.call("exact",item,int(id))
		if not typed and not matches(item,current):continue
		if not NATIVE_FIELDS.field(current,"source_condition_pending",[]).is_empty() or current.get("source_delete_time_unresolved",false):document.unresolved_item_ids[id]="current_native_lifecycle_or_context_pending";continue
		var dated: bool=current.has("source_start_time_raw") or current.has("source_end_time_raw") or NATIVE_FIELDS.has_field(current,"source_delete_time_raw")
		if dated:
			var clock: Variant=context.get("source_clock_offset_minutes")
			if not _source_integer(clock) or clock < -720 or clock > 840:document.unresolved_item_ids[id]="current_source_drop_clock_context_required";continue
			if not deadline_problem(current,int(clock)).is_empty():document.unresolved_item_ids[id]="current_source_item_outside_existing_time_policy";continue
		# Existing physical equipment, exact typed supplies and the actual Adena
		# wallet have owners. Other new stacks require their quantity/use owner.
		var stock: Script=load("res://scripts/loot/current523_native_stack.gd")
		var stack_supported: bool=stock!=null and not stock.call("supply_profile",item).is_empty()
		if not equipment(item) and currency_identity_name(item)!="아데나" and not typed and not stack_supported:
			document.unresolved_item_ids[id]="current_native_stack_consumer_pending";continue
		var link: Dictionary={}
		for field: String in ["name","source","sourceId","sourceUrl","slot","type","grade"]:link[field]=item.get(field,"")
		document.bindings[id]=link;document.unresolved_item_ids.erase(id);document.host_binding_problems.erase(id)
		document.binding_provenance[id]={"membership":"current523_original_NpcItemDropView","item_reference":"current523_original_ItemData","game_dto":"current523_original_typed_projection","source_input_identity":CURRENT_SOURCE.identity(),"effect_completion":false,"native_quantity_or_rate_inferred":false}
	return document

static func native(value: Dictionary) -> bool:
	return value.get("kind") == KIND and int(value.get("source_npc_id", -1)) > 0

static func equipment(item: Dictionary) -> bool:
	if item.get("crafting_scroll", false): return bool(item.get("drop_as_equipment", false)) and item.get("slot", "") == "consumable"
	return str(item.get("slot", "")) not in ["", "currency", "consumable", "material"]

static func item_kind(item: Dictionary) -> String:
	if equipment(item): return "equipment"
	if item.get("slot", "") == "currency": return "currency"
	if item.get("slot", "") == "consumable" and int(item.get("heal", 0)) > 0: return "potion"
	# Existing crafting scrolls already share the rarity roll without becoming
	# wearables. Source skill books/scrolls/reward consumables use that same
	# seven-grade host path; they must not all become 28%-chance materials.
	if item.get("source_m_native_item", false) and NATIVE_FIELDS.full(item).get("source_is_consumable", false) and item.get("grade", "") in ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]: return "equipment"
	return "material"

static func matches(item: Dictionary, link: Dictionary) -> bool:
	if item.is_empty() or link.is_empty(): return false
	for key: String in ["name", "source", "sourceId", "sourceUrl", "slot", "type", "grade"]:
		if str(item.get(key, "")) != str(link.get(key, "")): return false
	return true

static func catalog_index(items: Array) -> Dictionary:
	# Main's legacy loot pool is smaller than its item encyclopedia. Keep this
	# exact-source lookup separate so registering source gear never widens a
	# legacy monster's configured candidate pool.
	var index: Dictionary = {}
	var ambiguous: Dictionary = {}
	for item: Dictionary in items:
		var name_value: String = str(item.get("name", ""))
		if index.has(name_value): ambiguous[name_value] = true
		index[name_value] = item
	for name_value: String in ambiguous: index.erase(name_value)
	return index

static func variant_item(record: Dictionary, bless: int) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	if not result.get("source_m_native_item", false): return result
	result["source_bless_raw"] = bless
	if not equipment(result) and bless != 1:
		result["name"] = str(result.name) + " · " + str({2:"축복", 3:"저주"}.get(bless, "상태%d" % bless))
		result["sourceId"] = str(result.sourceId) + ":bless:" + str(bless)
	return result

static func legacy_stone_variant(record: Dictionary, bless: int) -> Dictionary:
	# Previous verified packs stored slot293 as non-wearable material, whose
	# blessed/cursed stack names must remain addressable without merging keys.
	if int(record.get("source_item_class_id",0)) != 323353 or record.get("slot") != "domination_stone" or bless not in [2,3]: return {}
	var result: Dictionary = variant_item(record,bless)
	result["name"] = str(record.name) + (" · 축복" if bless==2 else " · 저주")
	result["sourceId"] = str(record.sourceId)+":bless:"+str(bless)
	result["source_legacy_stack_variant"] = true
	result["bless_state"] = "blessed" if bless==2 else "cursed"
	return result

static func expected_variant(original: Dictionary, saved: Dictionary) -> Dictionary:
	if saved.get("source_legacy_catalog_alias",false):
		var alias: Dictionary = data().get("catalog_aliases",{}).get(str(int(original.get("source_item_class_id",-1))),{})
		if alias.is_empty() or not matches(saved,alias.get("identity",{})): return {}
		var result: Dictionary = original.duplicate(true)
		result.merge(alias.identity,true)
		result["source_legacy_catalog_alias"] = true
		result["source_bless_raw"] = int(saved.get("source_bless_raw",1))
		return result
	return legacy_stone_variant(original,int(saved.get("source_bless_raw",1))) if saved.get("source_legacy_stack_variant",false) else variant_item(original,int(saved.get("source_bless_raw",1)))

static func register_catalog(document: Dictionary, catalog: Dictionary) -> Dictionary:
	if document.get("input_kind")=="current523_original_reference_rows":return CURRENT_DTO.register(load("res://scripts/loot/patch523_monster_drops.gd"),catalog,document)
	if document.get("full_item_catalog",false): return FULL_ITEMS.register(document,catalog)
	var records: Array = catalog.get("아이템", [])
	var by_source: Dictionary = {}
	var positions: Dictionary = {}
	for index: int in range(records.size()):
		var item: Dictionary = records[index]
		by_source[str(item.get("sourceId", ""))] = item
		positions[str(item.get("sourceId", ""))] = index
	var needed_states: Dictionary = {}
	for rows: Array in document.get("drops", {}).values():
		for row: Dictionary in rows:
			var key: String = str(int(row.ItemClassID))
			if not needed_states.has(key): needed_states[key] = {}
			needed_states[key][int(row.Bless)] = true
	for definition: Dictionary in document.get("item_definitions", {}).values():
		var spec: Dictionary = NATIVE_FIELDS.full(definition.get("native_record", {})).get("source_use_spec", {})
		if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_selectable_bag"] or spec.get("activation_status") != "unrestricted": continue
		for reward: Dictionary in spec.get("rewards", []):
			var key: String = str(int(reward.item_class_id))
			if not needed_states.has(key): needed_states[key] = {}
			needed_states[key][int(reward.bless_raw)] = true
	var added: int = 0
	var updated: int = 0
	var native_ids: Array = document.get("native_item_ids", []).duplicate()
	for key: String in document.get("native_reward_item_ids", []):
		if not native_ids.has(key): native_ids.append(key)
	for key: String in native_ids:
		var definition: Dictionary = document.get("item_definitions", {}).get(key, {})
		var original: Dictionary = definition.get("native_record", {})
		if original.is_empty(): continue
		var states: Array = [1]
		if not equipment(original):
			for state: int in needed_states.get(key, {}):
				if state in [2, 3]: states.append(state)
		for state: int in states:
			var item: Dictionary = variant_item(original, state)
			var identity_key: String = str(item.sourceId)
			if by_source.has(identity_key):
				var old: Dictionary = by_source[identity_key]
				if old.get("source") == "lineagem_patch523" and old.get("source_snapshot") == "patch523" and old.get("source_m_native_item",false) and int(old.get("source_item_class_id",-1)) == int(item.get("source_item_class_id",-2)) and old.get("name") == item.get("name") and NATIVE_FIELDS.field(old,"source_display_name") == NATIVE_FIELDS.field(item,"source_display_name"):
					records[int(positions[identity_key])] = item
					by_source[identity_key] = item
					updated += 1
				continue
			positions[identity_key] = records.size()
			records.append(item)
			by_source[identity_key] = item
			added += 1
		if int(original.get("source_item_class_id",0)) == 323353 and original.get("slot") == "domination_stone":
			for state: int in [2,3]:
				var item: Dictionary = legacy_stone_variant(original,state)
				if not by_source.has(str(item.sourceId)):
					positions[str(item.sourceId)] = records.size()
					records.append(item)
					by_source[str(item.sourceId)] = item
					added += 1
				else:
					var old: Dictionary = by_source[str(item.sourceId)]
					if old.get("source") == "lineagem_patch523" and int(old.get("source_item_class_id",0)) == 323353 and old.get("name") == item.name:
						records[int(positions[str(item.sourceId)])] = item
						updated += 1
	catalog["아이템"] = records
	return {"added":added,"updated":updated, "native_definition_count":document.get("native_item_ids", []).size()}

## TWILIGHT is offline: a source item whose end/delete date has passed would
## otherwise be unusable forever. Repeating its window back to back (local
## rotation) means a passed end/delete date no longer blocks; a start date in
## the future still does. false = source dates only.
static var rotate_ended_dates: bool = true

static func deadline_problem(item: Dictionary, timezone_minutes: int = 540) -> String:
	if item.get("source_delete_time_unresolved",false): return "원본 아이템 수명 조건 미지원 · 아이템 보존"
	for key: String in ["source_start_time_raw","source_end_time_raw","source_delete_time_raw"]:
		if not NATIVE_FIELDS.has_field(item,key): continue
		var encoded: String = str(int(NATIVE_FIELDS.field(item,key)))
		if encoded.length() not in [10,12]: return "원본 기간 형식 확인 실패 · 아이템 보존"
		var minute: String = encoded.substr(10,2) if encoded.length() == 12 else "00"
		var local_time: String = "%s-%s-%sT%s:%s:00" % [encoded.substr(0,4),encoded.substr(4,2),encoded.substr(6,2),encoded.substr(8,2),minute]
		var deadline: int = Time.get_unix_time_from_datetime_string(local_time)-clampi(timezone_minutes,-720,840)*60
		var now: int = int(Time.get_unix_time_from_system())
		if key == "source_start_time_raw" and now < deadline: return "원본 사용 기간 시작 전 · 보유 아이템 보존"
		if key != "source_start_time_raw" and now >= deadline and not rotate_ended_dates: return "원본 사용 기한 만료 · 보유 아이템은 보존"
	return ""

static func equipment_error(item: Dictionary, job: String, level: int, timezone_minutes: int = 540) -> String:
	if not item.get("source_m_native_item", false): return ""
	if item.get("source_test_item",false): return "원본 테스트 장비는 착용할 수 없습니다"
	if not NATIVE_FIELDS.field(item,"source_condition_pending",[]).is_empty():return "원본 장비의 서비스·서버·기간 조건 연결 필요"
	var deadline: String = deadline_problem(item,timezone_minutes)
	if not deadline.is_empty(): return deadline
	var full: Dictionary = NATIVE_FIELDS.full(item)
	var classes: Array = full.get("source_class_names", [])
	if not full.get("source_unresolved_class_ids", []).is_empty(): return "원본 착용 직업 조건 미확인"
	if not classes.is_empty() and not classes.has(job): return "원본 직업 조건에 맞지 않는 장비입니다"
	var minimum: int = int(NATIVE_FIELDS.field(item,"source_level_limit_min",0))
	var maximum: int = int(NATIVE_FIELDS.field(item,"source_level_limit_max",0))
	if level < minimum or (maximum > 0 and level > maximum): return "원본 장비 레벨 조건에 맞지 않습니다"
	if level < int(full.get("source_max_level_limit_min",0)) or (int(full.get("source_max_level_limit_max",0)) > 0 and level > int(full.source_max_level_limit_max)): return "원본 최고 레벨 조건에 맞지 않습니다"
	return ""

static func healing_amount(item: Dictionary, rng: RandomNumberGenerator, fallback: int) -> int:
	if not item.get("source_m_native_item", false): return fallback
	var spec: Dictionary = item.get("heal_spec", {})
	if spec.get("kind") != "source_hp_dice": return fallback
	var amount: int = int(spec.get("HPRestoration", 0))
	var count: int = int(spec.get("HPRestorationDiceNumber", 0))
	var sides: int = int(spec.get("HPRestorationDiceSpotCount", 0))
	if count < 0 or count > 1000 or sides < 0 or sides > 1000000 or (count > 0 and sides < 1): return fallback
	for die: int in range(count): amount += rng.randi_range(1, sides)
	return amount

static func hp_use_metadata(item: Dictionary) -> Dictionary:
	var definition: Dictionary = item_definition(item)
	var original: Dictionary = definition.get("original_item",{})
	var category: Dictionary = definition.get("category",{})
	if original.is_empty() or category.get("Name") != "Potion" or not category.get("IsConsumable",false) or definition.get("native_record",{}).get("heal_spec",{}).is_empty(): return {"ok":false}
	if original.get("TestItem",true) or int(original.get("TargettingTypeID",0)) != 1 or not str(original.get("ServiceRegionCode","")).is_empty(): return {"ok":false}
	var allowed: Dictionary = {"HPRestoration":"Value","HPRestorationDiceNumber":"Value","HPRestorationDiceSpotCount":"Value","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID"}
	var seen: Dictionary = {}
	var metadata: Dictionary = {"ok":true,"can_use_when_invisible":bool(original.get("CanUseWhenInvisible",false)),"consume_effect_sprite_id":0}
	for row: Dictionary in definition.get("item_bonus",[]):
		var kind: String = str(row.get("bonus_type",{}).get("Name",""))
		var bonus: Dictionary = row.get("bonus",{})
		if kind == "DeleteTime":
			var joined_deadline: bool = false
			for source_date: Dictionary in definition.get("source_deadline_definitions",[]):
				if int(source_date.get("item_bonus_id",-1)) == int(row.get("ID",-2)): joined_deadline = true
			if joined_deadline: continue
		if kind == "DeleteTime" and definition.get("native_record",{}).has("source_delete_time_raw") and row.get("unit",{}).get("Name") == "Time" and not row.get("IsPossession",true) and int(bonus.get("BonusApplicationTypeID",-1)) == 0 and int(bonus.get("BonusApplicationTargetID",-1)) == 0: continue
		if row.get("IsPossession",true) or int(bonus.get("BonusApplicationTypeID",-1)) != 0 or int(bonus.get("BonusApplicationTargetID",-1)) != 0 or not allowed.has(kind) or row.get("unit",{}).get("Name") != allowed[kind] or seen.has(kind): return {"ok":false}
		seen[kind] = true
		if kind == "ItemConsumeEffectSpriteID": metadata.consume_effect_sprite_id = int(bonus.get("Value",0))
		if kind == "ItemConsumeDelay": metadata["source_consume_delay_ms"] = int(bonus.get("Value",-1))
	if not seen.has("ItemConsumeDelay") or int(metadata.get("source_consume_delay_ms",-1)) < 0: return {"ok":false}
	return metadata

static func hp_use_problem(item: Dictionary, concealed: bool = false, timezone_minutes: int = 540) -> String:
	var deadline: String = deadline_problem(item,timezone_minutes)
	if not deadline.is_empty(): return deadline
	var metadata: Dictionary = hp_use_metadata(item)
	if not metadata.get("ok",false): return "원본 회복 아이템의 지역·기간·추가 효과 미연결 · 아이템 보존"
	if concealed and not metadata.get("can_use_when_invisible",false): return "원본 조건: 은신 중 사용할 수 없습니다"
	return ""

static func definition_id(item_id: String) -> Dictionary:
	if not item_id.is_valid_int() or int(item_id) <= 0 or item_id != str(int(item_id)): return {}
	var document: Dictionary = data()
	if document.is_empty(): return {}
	var entry: Array = _current_item_entry(int(item_id))
	return entry[1] if not entry.is_empty() else {}

static func pack_identity() -> Dictionary:
	var identity: Dictionary=CURRENT_SOURCE.identity()
	if identity.is_empty():return {}
	return {"schema":4,"source_snapshot":"patch523","kind":"current523_original_definition_projection","sha256":identity.source_sha256,"source_definition_archive":identity,"projection":"current523_original_typed_game_dto_v1","registered_count":int(data().get("current_native_registered_count",0)),"full_native_effects_complete":false}

static func issued_definition_for_reference(item_id: String) -> Dictionary:
	var historical: Dictionary=_legacy_data_for_reference()
	return FULL_ITEMS.definition(historical,_root,item_id) if not historical.is_empty() else {}

static func current_owned_record(saved: Dictionary) -> Dictionary:
	if saved.get("source_m_native_item")!=true:return saved
	var id: String=str(int(saved.get("source_item_class_id",0)))
	var original: Dictionary=definition_id(id).get("native_record",{})
	if original.is_empty() or saved.get("source")!="lineagem_patch523" or saved.get("source_snapshot")!="patch523":return {}
	var current: Dictionary=expected_variant(original,saved)
	if not matches(current,saved):return {}
	for key: String in ["instance_id","enhance_level","is_engraved","bless_state","source_m_drop_proof","source_m_reward_proof","source_m_item_id"]:
		if saved.has(key):current[key]=saved[key].duplicate(true) if saved[key] is Dictionary or saved[key] is Array else saved[key]
	return current

static func native_enchant_stats(item: Dictionary, level: int) -> Dictionary:
	if not item.get("source_m_native_item",false):return {}
	var source: Dictionary=definition_id(str(int(item.get("source_item_class_id",-1)))).get("native_record",{})
	if source.is_empty() or not matches(item,expected_variant(source,item)):return {}
	var bless: int=int(item.get("source_bless_raw",1))
	if item.get("bless_state") in ["blessed","축복"]:bless=2
	elif item.get("bless_state") in ["cursed","저주"]:bless=3
	return CURRENT_DTO.enchant_stats(source,maxi(0,level),bless)

static func migrate_legacy_record(saved: Dictionary) -> Dictionary:
	if not data().get("full_item_catalog",false) or saved.get("source") != "inven": return {}
	var id: String = str(saved.get("sourceId",""))
	var alias: Dictionary = data().get("catalog_aliases",{}).get(id,{})
	if alias.is_empty(): return {}
	for key: String in ["name","sourceId","sourceUrl"]:
		if str(saved.get(key,"")) != str(alias.original_identity.get(key,"")): return {}
	var record: Dictionary = definition_id(id).get("native_record",{}).duplicate(true)
	if record.is_empty(): return {}
	record.merge(alias.identity,true)
	record["source_legacy_catalog_alias"] = true
	record["source_bless_raw"] = 1
	return record

static func item_definition(item: Dictionary) -> Dictionary:
	var item_id: String = str(int(item.get("source_item_class_id", -1))) if item.get("source_m_native_item", false) else str(item.get("sourceId", ""))
	var definition: Dictionary = definition_id(item_id)
	if definition.is_empty(): return {}
	var expected: Dictionary = expected_variant(definition.get("native_record", {}),item) if item.get("source_m_native_item", false) else definition.get("existing_binding", {})
	return definition if matches(item, expected) else {}

static func weapon_invoke_roll(item: Dictionary, rolled: int, maximum: int, extra: int, scope: String, rng: RandomNumberGenerator) -> Dictionary:
	var definition: Dictionary = item_definition(item)
	var result: Dictionary = {"damage":rolled,"fired":[]}
	if definition.get("original_item", {}).get("TestItem", true): return result
	for effect: Dictionary in definition.get("source_invoke_options", []):
		if effect.get("activation_status") != "unrestricted": continue
		var kind: String = str(effect.get("kind", ""))
		if kind not in ["normal_attack_additional_critical", "normal_attack_weapon_scale"] or (kind == "normal_attack_weapon_scale" and scope == "disabled"): continue
		if rng.randi_range(0,999999) >= int(effect.get("probability_raw", 0)): continue
		if kind == "normal_attack_additional_critical":
			# Official weapon guide: claw critical selects maximum weapon base;
			# the existing player critical damage/chance remains independent.
			result.damage = maximum
			result.fired.append("원본 크로우 무기 최대 대미지")
		else:
			# Chance and scale are source values. The component boundary is an
			# explicitly configurable local interpretation of the public experiment.
			var component: int = int(result.damage) + (extra if scope == "base_flat_enchant" else 0)
			result.damage += int(round(float(component)*(float(effect.invoke_option.Param1)/1000000.0-1.0)))
			result.fired.append("원본 이도류 배율 · 적용 범위는 TWILIGHT 보완 설정")
	return result

static func wallet_name(item: Dictionary) -> String:
	var name_value: String = currency_identity_name(item)
	if name_value.is_empty(): return ""
	var id: int = int(item.get("source_item_class_id", -1))
	var proof: Dictionary = item.get("source_m_drop_proof", {})
	if int(proof.get("source_item_class_id", -2)) != id or int(proof.get("bless_raw", 0)) != 1 or int(proof.get("required_quest_id", -1)) != 0: return ""
	return name_value

static func currency_identity_name(item: Dictionary) -> String:
	if not item.get("source_m_native_item", false) or NATIVE_FIELDS.field(item,"source_category_name") != "Currency": return ""
	if int(item.get("source_bless_raw", 1)) != 1: return ""
	var id: int = int(item.get("source_item_class_id", -1))
	var labels: Dictionary = {26:"아데나", 3242:"변신 코인", 3252:"마법인형 코인", 3631:"명예 코인", 246058:"성물 제작 코인"}
	if not labels.has(id) or NATIVE_FIELDS.field(item,"source_display_name") != labels[id]: return ""
	return preload("res://scripts/loot/currency_drops.gd").canonical_name(str(labels[id]))

static func resolve(document: Dictionary, value: Dictionary, catalog: Dictionary) -> Dictionary:
	var id: String = str(int(value.get("source_npc_id", -1)))
	var npc: Dictionary = document.get("npcs", {}).get(id, {})
	var report: Dictionary = {"npc_id":id, "missing_item_bindings":0, "quest_rows_blocked":0, "test_item_rows_blocked":0, "unsupported_bless_rows":0, "unsupported_currency_rows":0, "duplicate_rows_ignored":0}
	diagnostics = report
	if not native(value) or npc.is_empty() or int(npc.get("sprite_id", -1)) != int(value.get("source_sprite_id", -2)) or npc.get("source_name") != value.get("source_name"): return {}
	if not npc.get("attackable", false) or npc.get("test_npc", true): return {}
	var groups: Dictionary = {}
	for row: Dictionary in document.get("drops", {}).get(id, []):
		# Keep quest-conditioned rows until the separate quest owner supplies
		# exact source quest state; never make the requirement unconditional.
		if int(row.RequiredQuestID) != 0: report.quest_rows_blocked += 1; continue
		var item_id: String = str(int(row.ItemClassID))
		if _document_definition(document,item_id).get("original_item", {}).get("TestItem", false): report.test_item_rows_blocked += 1; continue
		var link: Dictionary = document.get("bindings", {}).get(item_id, {})
		var item: Dictionary = catalog.get("patch523_by_name", catalog.get("by_name", {})).get(str(link.get("name", "")), {})
		if not matches(item, link): report.missing_item_bindings += 1; continue
		var bless: int = int(row.Bless)
		# Stack ownership has no distinct bless variant. Do not flatten it.
		if bless not in [1, 2, 3] or (bless != 1 and not item.get("source_m_native_item", false) and (not equipment(item) or item.get("slot") == "consumable")):
			report.unsupported_bless_rows += 1; continue
		var kind: String = item_kind(item)
		if not groups.has(item_id): groups[item_id] = {"item_class_id":int(item_id), "item":item, "kind":kind, "variants":{}}
		var key: String = "%d:%d" % [bless, int(row.RequiredQuestID)]
		var variants: Dictionary = groups[item_id].variants
		if variants.has(key):
			variants[key].source_rows.append(row.duplicate(true))
			report.duplicate_rows_ignored += 1
			continue
		variants[key] = {"source_snapshot":"patch523", "source_npc_id":int(id), "source_item_class_id":int(item_id), "bless_raw":bless, "bless_state":str(document.bless_codes[str(bless)]), "required_quest_id":int(row.RequiredQuestID), "source_rows":[row.duplicate(true)], "selection_policy":"host_uniform_distinct_items_then_distinct_variants", "quantity_policy":"host_one", "variant_record":variant_item(item, bless)}
	return groups

static func candidates(value: Dictionary, catalog: Dictionary) -> Dictionary:
	# data() and this actual membership read both use current originals. The
	# preserved legacy decoder/installer is never a final input or fallback.
	var original: Dictionary = _current_source_document(value)
	var document: Dictionary = _current_native_bindings(_current_host_bindings(original,catalog),catalog,value) if not original.is_empty() else {}
	if document.is_empty():
		diagnostics = {"status":"current523_drop_input_unavailable","reason":_current_input_problem if not _current_input_problem.is_empty() else "current523_original_membership_unavailable","source_problem":CURRENT_SOURCE.problem()}
		return {}
	var groups: Dictionary = resolve(document,value,catalog)
	diagnostics["input_kind"] = document.input_kind
	diagnostics["source_input_identity"] = document.source_input_identity.duplicate(true)
	diagnostics["binding_provenance"] = document.binding_provenance.duplicate(true)
	diagnostics["unresolved_item_ids"] = document.unresolved_item_ids.duplicate(true)
	diagnostics["host_binding_problems"] = document.host_binding_problems.duplicate(true)
	# Same values as deep copies; the read-only original references and
	# evidence rows are shared with data() rather than copied per death.
	diagnostics["source_condition_evidence"] = document.source_condition_evidence.duplicate(false)
	diagnostics["source_item_references"] = document.source_item_references.duplicate(false)
	diagnostics["unavailable_source_definitions"] = document.unavailable_source_definitions.duplicate(false)
	diagnostics["source_exclusion_evidence"] = document.source_exclusion_evidence.duplicate(false)
	diagnostics["original_numeric_projection_complete"] = false
	return groups

static func pick(groups: Dictionary, kind: String, grade: String, rng: RandomNumberGenerator) -> Dictionary:
	var choices: Array = []
	for group: Dictionary in groups.values():
		if group.kind != kind: continue
		# This equality retains the host rarity roll. It is not a separate cap.
		if kind == "equipment" and str(group.item.get("grade", "일반")) != grade: continue
		choices.append(group)
	if choices.is_empty(): return {}
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.item_class_id) < int(b.item_class_id))
	var selected: Dictionary = choices[rng.randi_range(0, choices.size()-1)]
	var keys: Array = selected.variants.keys()
	keys.sort()
	var proof: Dictionary = selected.variants[keys[rng.randi_range(0, keys.size()-1)]].duplicate(true)
	var item: Dictionary = proof.get("variant_record", selected.item).duplicate(true)
	proof.erase("variant_record")
	item["source_m_item_id"] = selected.item_class_id
	item["bless_state"] = proof.bless_state
	item["source_m_drop_proof"] = proof
	return {"item_name":str(item.name), "quantity":1, "item_record":item, "source_m_drop_proof":proof}

static func ground_metadata(entry: Dictionary) -> Dictionary:
	if not entry.has("source_m_drop_proof") or not entry.get("item_record") is Dictionary: return {}
	var item: Dictionary = NATIVE_FIELDS.full(entry.item_record).duplicate(true)
	var result: Dictionary = {"item_record":item}
	if equipment(item) and item.get("slot") != "consumable":
		result["physical_item"] = {"id":Crypto.new().generate_random_bytes(16).hex_encode(), "data":{"name":str(entry.item_name), "level":0, "element":"", "element_level":0, "record":item, "bless_state":item.bless_state, "source_m_drop_proof":entry.source_m_drop_proof.duplicate(true)}}
	return result

static func source_rows(item: Dictionary) -> Array:
	var document: Dictionary = data()
	var item_id: String = str(int(item.source_item_class_id)) if item.get("source_m_native_item", false) else str(item.get("sourceId", ""))
	var binding: Dictionary = document.get("bindings", {}).get(item_id, {})
	var base: Dictionary = _document_definition(document,item_id).get("native_record", {})
	var validated: bool = matches(item, binding)
	if item.get("source_m_native_item", false) and not base.is_empty():
		var expected: Dictionary = expected_variant(base,item)
		validated = matches(item, expected)
	if document.is_empty() or not validated: return []
	if _sources.is_empty():
		for id: String in document.get("drops", {}):
			var npc: Dictionary = document.npcs[id]
			if not npc.show_drop_info or npc.test_npc: continue
			var seen: Dictionary = {}
			for row: Dictionary in document.drops[id]:
				var key: String = "%d:%d:%d" % [int(row.ItemClassID), int(row.Bless), int(row.RequiredQuestID)]
				if seen.has(key): continue
				seen[key] = true
				var source_item: String = str(int(row.ItemClassID))
				if not _sources.has(source_item): _sources[source_item] = []
				_sources[source_item].append({"npc_id":int(id), "name":str(npc.display_name), "source_name":str(npc.source_name), "bless":int(row.Bless), "quest":int(row.RequiredQuestID)})
	return _sources.get(item_id, [])

static func source_text(item: Dictionary) -> String:
	if data().is_empty(): return "523 드랍 자료 미설치 · 설정에서 드랍 자료 ZIP을 설치하세요."
	var rows: Array = source_rows(item)
	if rows.is_empty(): return "523 드랍원: 현재 아이템 ID와 검증된 연결 없음"
	var lines: PackedStringArray = ["523 원본 드랍원 · 실제 출현·획득 보장 아님", "확률·수량: TWILIGHT 규칙 · 일반·보스 모두 전 등급 추첨", "일반 몬스터 상위 등급: 기존 게임 전설 0.2% · 신화 0.025% · 유일 0.001% / 회"]
	for row: Dictionary in rows.slice(0, 24):
		var state: String = {1:"일반", 2:"축복", 3:"저주"}.get(int(row.bless), "미지원 상태 %d" % int(row.bless))
		var quest: String = " · 퀘스트 %d 필요(드랍 제외)" % int(row.quest) if int(row.quest) != 0 else ""
		lines.append("%s (#%d) · %s%s" % [str(row.name), int(row.npc_id), state, quest])
	if rows.size() > 24: lines.append("외 %d개 원본 조건" % (rows.size()-24))
	return "\n".join(lines)

static func item_details(item: Dictionary) -> String:
	var full_definition: Dictionary = item_definition(item)
	if item.get("source_m_native_item",false):
		var full: Dictionary = full_definition.get("native_record",{})
		if not full.is_empty(): item = full
	if not item.get("source_m_native_item", false):
		var original: Dictionary = item_definition(item).get("native_record", {})
		if NATIVE_FIELDS.full(original).get("source_use_spec", {}).get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_selectable_bag","source_skill_book"]: return invoke_details(item)
		item = original
	var lines: PackedStringArray = ["원본 아이템 #%d · %s" % [int(item.get("source_item_class_id", 0)), str(NATIVE_FIELDS.field(item,"source_display_name",""))]]
	if NATIVE_FIELDS.field(item,"source_category_name") in ["Arrow","Bullet","Sting"]:
		lines.append("원본 탄약 분류 · 특수 주문 투사체는 주문 연결 필요")
		for row: Dictionary in full_definition.get("item_bonus",[]):
			if row.bonus_type.Name in ["WeaponSmallDamage","WeaponLargeDamage"]:
				lines.append("원본 %s %d" % [str(row.bonus_type.Name),int(row.bonus.Value)])
		lines.append("지원 탄약은 발사마다 1개 소모 · 대미지는 TWILIGHT 설정(기본 1~원본 상한 균등 추정)\n원본 투사체 ID 보존 · 기존 게임 발사 연출 사용")
	for field: String in ["StoryDescID","UseDescID","ProductDescID"]:
		var description: String = str(full_definition.get("source_descriptions",{}).get(field,{}).get("text","")).strip_edges()
		if not description.is_empty(): lines.append("원본 설명 · "+description)
	if item.has("source_enchant_group_ids"): lines.append("강화 단계 옵션은 원본 표 우선 · 원본에 없는 항목은 기존 게임 규칙 유지")
	if equipment(item):
		for row: Dictionary in full_definition.get("item_bonus",[]):
			if row.get("IsPossession") != false or int(row.bonus.BonusApplicationTypeID) != 0 or int(row.bonus.BonusApplicationTargetID) != 0: continue
			if row.bonus_type.Name in ["RegenHP","RegenMP","AbsoluteRegenHP","AbsoluteRegenMP","AttackDrainHP","AttackDrainMP"]:
				lines.append("원본 %s %+d · 회복 간격·일반 명중 흡수 발동률은 TWILIGHT 설정" % [str(row.bonus_type.Name),int(row.bonus.Value)])
	if NATIVE_FIELDS.full(item).get("source_is_trash",false): lines.append("원본 IsTrash 표시 · 이 표시만으로 제외하지 않고 공급·사용 조건을 따름")
	var labels: Dictionary = {"small_damage":"작은 대상 무기 대미지", "large_damage":"큰 대상 무기 대미지", "hit":"무기 명중", "additionalDamage":"추가 대미지", "def":"방어", "strFlat":"STR", "dexFlat":"DEX", "conFlat":"CON", "intFlat":"INT", "wisFlat":"WIS", "chaFlat":"CHA", "hpFlat":"HP", "mpFlat":"MP", "mr":"MR", "damage_reduction":"리덕션", "sp":"SP", "meleeDamage":"근거리 대미지", "rangedDamage":"원거리 대미지", "magicDamage":"마법 대미지", "meleeHit":"근거리 명중", "rangedHit":"원거리 명중", "magicHit":"마법 명중"}
	for key: String in labels:
		if item.has(key): lines.append("%s %+d" % [str(labels[key]), int(item[key])])
	if item.has("xp"): lines.append("경험치 획득 +%.2f%%" % (float(item.xp)*100.0))
	if item.get("slot") == "domination_stone": lines.append("원본 지배석 전용 장착 부위 · 게임 장비창 3쪽\n원본 탑 이동·퀘스트·세트 활성 조건은 이 장착으로 해금하지 않음")
	var heal: Dictionary = item.get("heal_spec", {})
	if not heal.is_empty():
		lines.append("HP 회복 %d + %dD%d · 기존 물약 사용 규칙" % [int(heal.get("HPRestoration", 0)), int(heal.get("HPRestorationDiceNumber", 0)), int(heal.get("HPRestorationDiceSpotCount", 0))])
		var problem: String = hp_use_problem(item)
		if not problem.is_empty(): lines.append(problem)
	var spec: Dictionary = NATIVE_FIELDS.full(item).get("source_use_spec", {})
	var presentation_flags: PackedStringArray = []
	for row: Dictionary in full_definition.get("item_bonus",[]):
		if row.bonus_type.Name in ["UIShowFilter","NoAnnounce"]: presentation_flags.append(str(row.bonus_type.Name)+"="+str(int(row.bonus.Value)))
	if not presentation_flags.is_empty(): lines.append("원본 표시 플래그 %s · TWILIGHT 추정 설정을 켜면 이 무조건 표시·공지 플래그만으로 사용을 차단하지 않음" % ", ".join(presentation_flags))
	if NATIVE_FIELDS.has_field(item,"source_delete_time_raw"):
		var expiry: String = "원본 사용 기한 %s · 시각대는 TWILIGHT 설정(기본 UTC+9)" % str(int(NATIVE_FIELDS.field(item,"source_delete_time_raw")))
		expiry += " · 지난 기한은 오프라인 순환으로 사용 가능" if rotate_ended_dates else " · 만료 시 소유 보존"
		if item.get("source_cannot_extend_delete_time",false): expiry += " · 원본 기간 연장 불가"
		lines.append(expiry)
	if not spec.is_empty():
		if spec.get("activation_status") != "unrestricted": lines.append("원본 사용 조건·효과 미지원 · 사용 시 소비하지 않음")
		else:
			match str(spec.get("kind", "")):
				"fixed_card": lines.append("사용: 원본 지정 %s 카드 %s (#%d) 1장 · 확률 추첨 없음" % [str(spec.get("card_kind", "")),str(spec.get("original_card", {}).get("Name", "")),int(spec.get("card_id", 0))])
				"source_mp_dice": lines.append("사용: MP 회복 %d + %dD%d" % [int(spec.get("base",0)),int(spec.get("dice_number",0)),int(spec.get("dice_spot_count",0))])
				"source_selectable_reward":
					lines.append("사용: 원본 선택 보상 %d개 중 1개 · 확인 후 인벤토리 수령" % spec.get("rewards",[]).size())
					if spec.has("local_rule_required"): lines.append("장비 초기 강화값: 원본 없음 · TWILIGHT +0 자체 설정 · 설정에서 해제 가능")
				"source_selectable_bag":
					lines.append("사용: 원본 선택 상자 %d개 중 1종 선택(원본 설명) · 확인 후 인벤토리 수령" % spec.get("rewards",[]).size())
				"source_skill_book":
					lines.append("스킬서: 원본 카드 #%d → 주문 #%d · PR245의 동일 ID·정의 SHA 연결 필요" % [int(spec.get("card_id",0)),int(spec.get("spell_class_id",0))])
					lines.append("원본 직업·레벨·선행 조건 검증 · 연결 전 스킬서 보존")
				"source_timed_buff":
					lines.append("사용: 원본 지속 버프 %d초" % int(spec.get("duration_seconds", 0)))
					var effect_labels: Dictionary = {"def":"방어","strFlat":"STR","dexFlat":"DEX","intFlat":"INT","wisFlat":"WIS","conFlat":"CON","chaFlat":"CHA","hp_flat":"HP","mp_flat":"MP","mr":"MR","sp":"SP","melee_damage":"근거리 대미지","ranged_damage":"원거리 대미지","magic_damage":"마법 대미지","melee_accuracy":"근거리 명중","ranged_accuracy":"원거리 명중","magic_accuracy":"마법 명중","damage_reduction":"리덕션"}
					for field: String in spec.get("typed_effects", {}): lines.append("%s %+d" % [str(effect_labels.get(field,field)),int(spec.typed_effects[field])])
					lines.append("사망 시 유지" if spec.get("source_buff_class", {}).get("IsImmuneToDead", false) else "사망 시 해제")
				"guaranteed_bag":
					lines.append("사용: 원본 확정 보상 지급 · 확률 추첨 없음")
					for reward: Dictionary in spec.get("rewards", []):
						var label: String = str(cached_definition(str(int(reward.item_class_id))).get("native_record", {}).get("source_display_name", "아이템 #"+str(int(reward.item_class_id))))
						lines.append("%s ×%d%s" % [label,int(reward.amount)," · 원본 직업 조건에 해당할 때" if not reward.get("class_ids", []).is_empty() else ""])
				"source_weighted_bag", "mixed_rewards_bag":
					lines.append("사용: 원본 확률·보상 수량 적용 · 직업 조건 보존")
					lines.append("확률 보상 선택 횟수: TWILIGHT 자체 규칙 · 기본 1회 · 설정에서 변경 가능")
					for reward: Dictionary in spec.get("rewards",[]).slice(0,40):
						var label: String = str(cached_definition(str(int(reward.item_class_id))).get("native_record",{}).get("source_display_name","아이템 #"+str(int(reward.item_class_id))))
						var chance: String = "확정" if int(reward.entity_type_id) == 1 else "%.6f%%" % (float(reward.probability_raw)/100000.0)
						lines.append("%s ×%d · %s%s" % [label,int(reward.amount),chance," · 원본 직업 조건" if not reward.get("class_ids",[]).is_empty() else ""])
					if spec.get("rewards",[]).size() > 40: lines.append("외 %d개 원본 보상" % (spec.rewards.size()-40))
			if int(spec.get("consume_delay_ms", 0)) > 0: lines.append("원본 재사용 대기 %.1f초" % (float(spec.consume_delay_ms)/1000.0))
	var full_item: Dictionary = NATIVE_FIELDS.full(item)
	var classes: Array = full_item.get("source_class_names", [])
	if not classes.is_empty(): lines.append("원본 착용 직업: " + ", ".join(classes))
	if int(NATIVE_FIELDS.field(item,"source_level_limit_min",0)) > 0: lines.append("착용 최소 레벨 %d" % int(NATIVE_FIELDS.field(item,"source_level_limit_min")))
	if full_item.get("source_effect_status", "") == "partial": lines.append("일부 발동·특수 효과 미적용 · 확인된 기본 옵션만 적용")
	if full_item.get("source_equipment_status", "") == "unsupported_source_slot": lines.append("원본 전용 장착 부위 미지원 · 보관 가능")
	if item.get("source_test_item", false): lines.append("원본 테스트 아이템 · 드랍 제외")
	var invokes: String = invoke_details(item)
	if not invokes.is_empty(): lines.append(invokes)
	return "\n".join(lines)

static func invoke_details(item: Dictionary) -> String:
	var lines: PackedStringArray = []
	for effect: Dictionary in item_definition(item).get("source_invoke_options", []):
		if effect.get("kind") == "normal_attack_additional_critical" and effect.get("activation_status") == "unrestricted": lines.append("원본 크로우: 일반 공격 무기 최대 대미지 발동 %.1f%% · 캐릭터 치명타와 별도" % (float(effect.probability_raw)/10000.0))
		elif effect.get("kind") == "normal_attack_weapon_scale" and effect.get("activation_status") == "unrestricted": lines.append("원본 이도류: %.1f%% 확률 · 무기 배율 %.1f배\n배율 적용 범위: 공개 실험을 참고한 TWILIGHT 추정 규칙 · 설정에서 변경 가능" % [float(effect.probability_raw)/10000.0,float(effect.invoke_option.Param1)/1000000.0])
		elif effect.get("kind") == "normal_attack_source_bleed" and effect.get("activation_status") == "unrestricted": lines.append("원본 총 출혈: %.1f%% 확률 · %d초 · %dD%d 피해\n틱 간격·HP 상한: TWILIGHT 추정 규칙 · 기본 0.75초·누적 피해 최대 HP 50%% 상한 · 설정 가능" % [float(effect.probability_raw)/10000.0,int(effect.duration_seconds),int(effect.damage_dice_number),int(effect.damage_dice_spot_count)])
		else: lines.append("원본 무기 발동: 효과·조건 연결 미완료 · 기존 게임 발동 설정 유지")
	return "\n".join(lines)

static func install_zip(path: String) -> Dictionary:
	var validation: Dictionary = preload("res://scripts/lineagem_pack_install.gd").validate_zip(path)
	if not validation.get("ok", false) or not validation.entries.has("payload/monster_drops.bin") or int(validation.entries["payload/monster_drops.bin"]) > MAX_PACKED:
		return {"ok":false, "error":"지원되는 드랍 자료 ZIP이 아닙니다."}
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return {"ok":false, "error":"드랍 ZIP을 열 수 없습니다."}
	var header: Variant = JSON.parse_string(zip.read_file("pack.json").get_string_from_utf8())
	var packed: PackedByteArray = zip.read_file("payload/monster_drops.bin")
	zip.close()
	if not header is Dictionary or header.get("kind") != KIND or header.get("sha256") not in [DATA_SHA, PREVIOUS_FULL_DATA_SHA, PHASE4_DATA_SHA, PHASE3_DATA_SHA, PREVIOUS_DATA_SHA, LEGACY_DATA_SHA] or preload("res://scripts/lineagem_pack_install.gd").sha(packed) != header.get("sha256") or int(header.get("bytes", -1)) != packed.size() or decode(packed).is_empty():
		return {"ok":false, "error":"드랍 자료 버전 또는 무결성 검사 실패 · 기존 자료 유지"}
	var decoded: Dictionary = decode(packed)
	if int(header.get("schema",0)) == 3:
		var installed: Dictionary = FULL_ITEMS.install(path,validation.entries,header,decoded,installed_path(str(header.sha256)).get_base_dir())
		if not installed.get("ok",false): return installed
	elif validation.entries.size() != 2: return {"ok":false,"error":"지원하지 않는 추가 파일"}
	var fingerprint: String = str(header.sha256)
	var target: String = installed_path(fingerprint)
	if FileAccess.file_exists(target):
		if FileAccess.get_sha256(target) != fingerprint: return {"ok":false, "error":"기존 드랍 자료 손상 · 파일을 보존했습니다."}
	else:
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return {"ok":false, "error":"드랍 자료 폴더를 만들 수 없습니다."}
		var pending: String = target + ".pending"
		var file := FileAccess.open(pending, FileAccess.WRITE)
		if file == null: return {"ok":false, "error":"드랍 자료를 기록할 수 없습니다."}
		file.store_buffer(packed)
		file.close()
		if FileAccess.get_sha256(pending) != fingerprint or DirAccess.rename_absolute(pending, target) != OK: return {"ok":false, "error":"드랍 자료 설치 실패 · 기존 자료 유지"}
	FULL_ITEMS.reset()
	_checked = false
	_data = {}
	_sources = {}
	return {"ok":true, "path":target, "sha256":fingerprint}


# Existing exact effect owners use this current-original definition proof;
# historical BIN fingerprints remain receipt evidence, not final input gates.
static func current_original_definition(record: Dictionary) -> Dictionary:
	var marker: Dictionary=pack_identity()
	if marker.get("schema")!=4 or marker.get("source_definition_archive")!=CURRENT_SOURCE.identity():return {}
	var definition: Dictionary=item_definition(record)
	var raw: Dictionary=definition.get("original_item",{})
	return definition if not raw.is_empty() and definition.get("source_input_identity")==CURRENT_SOURCE.identity() and raw==CURRENT_SOURCE.row("ItemClass",int(raw.get("ID",0))) else {}
