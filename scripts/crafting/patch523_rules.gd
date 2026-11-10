extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Private 523 rules. Existing TWILIGHT recipes and economic tables stay separate.
const BLESS = preload("res://scripts/equipment_blessing.gd")
const OPTIONS = preload("res://scripts/inven_option_adapter.gd")
const ITEM_USE = preload("res://scripts/crafting/patch523_item_use.gd")
const CONDITIONS = preload("res://scripts/crafting/patch523_craft_conditions.gd")
const EXPEDITION_MATERIALS=preload("res://scripts/crafting/patch523_expedition_materials.gd")
const QUEST_MATERIALS=preload("res://scripts/crafting/quest_material_inputs.gd")
const ENHANCEMENT = preload("res://scripts/crafting/patch523_enhancement.gd")
const SOURCE_DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const SOURCE_ITEMS = preload("res://scripts/resources/current523_item_data.gd")
const ORIGINAL_PROJECTION = preload("res://scripts/crafting/patch523_rules_projection.gd")
const SCHEMA: String = "twilight-patch523-equipment-v1"
const MAX_BYTES: int = 128 * 1024 * 1024
const MAX_BATCH: int = 20
var data: Dictionary = {}
## sourceId -> live catalog record. Native items are compiled as slim
## identities (twilight_binding_slim); record() returns the live record.
var live_record: Callable
var recipes: Dictionary = {}
var problem: String = ""
var digest: String = ""

static func valid_material(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["item", "source_id"]:
		if not value.get(key) is String or str(value[key]).is_empty(): return false
	for key: String in ["quantity", "level", "bless_code"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or float(value[key]) != float(int(value[key])): return false
	return int(value.quantity)>0 and int(value.quantity)<=(1000000000 if str(value.source_id)=="26" and bool(value.get("wallet",false)) else 100000000) and int(value.level)>=0 and int(value.level)<=21 and int(value.bless_code) in [1,2] and typeof(value.get("physical"))==TYPE_BOOL

static func valid_outcome(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not value.get("empty_result",false): return valid_material(value)
	return value.get("empty_result")==true and value.get("source_id")=="0" and value.get("item")=="지급 없음" and value.get("label")=="실패" and value.get("quantity")==0 and value.get("level")==0 and value.get("bless_code")==1 and value.get("physical")==false and not value.has("inventory_key")

func load_file(path: String, expected_sha256: String) -> bool:
	problem = ""
	if expected_sha256.length() != 64 or not FileAccess.file_exists(path):
		problem = "원본523 제작 규칙 파일·해시가 필요합니다"
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		problem = "원본523 제작 규칙 파일 크기를 확인하세요"
		return false
	file.close()
	if FileAccess.get_sha256(path) != expected_sha256:
		problem = "원본523 제작 규칙 SHA 불일치"
		return false
	return _load_payload(FileAccess.get_file_as_string(path),expected_sha256)

func load_original(catalog_bytes: PackedByteArray, binding_catalog_bytes: PackedByteArray = PackedByteArray()) -> bool:
	if not data.is_empty(): return true # Preserve an already accepted live model.
	var projection = _new_projection()
	return _load_candidate(projection,projection.build(catalog_bytes,binding_catalog_bytes),"") == COMPILED

## load_original() with the registered catalog given as items + contract; the
## same bytes are identified without building the whole binding text.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
const NATIVE_PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const BAKE_NAME := "equipment_rules"
## Everything the compiled model depends on besides the inputs in the key.
const BAKE_CODE: Array[String] = ["res://scripts/crafting/patch523_rules.gd","res://scripts/crafting/patch523_rules_projection.gd",
	"res://scripts/crafting/patch523_enchantment_projection.gd","res://scripts/crafting/patch523_packed_records.gd",
	"res://scripts/resources/current523_definition_rows.gd",
	"res://scripts/resources/current523_bake_cache.gd","res://data/crafting/patch523_crafting_policy.json",
	"res://data/crafting/patch523_enhancement_policy.json"]
## True when the model was read from this device's bake instead of compiled.
var loaded_from_bake: bool = false
var _bake_key: String = ""
var _model_key: String = ""
## Compiled catalog identities of an original-compiled model, kept on storage
## (keyed by the model's bake key) and read by source ID.
var _records: Object = null
const RECORDS_NAME := "equipment_rules_catalog_records"
const RECORDS_MARK := "twilight_catalog_record_offloaded"

## Identifies the registered catalog for the bake key without expanding every
## record: light records are hashed as stored and their template fields are
## identified by the item template bake key (full() = light + template).
static func _registered_catalog_key(items: Array, contract: Dictionary) -> String:
	var template_key: String = NATIVE_PROJECTION._template_key()
	if template_key.is_empty(): return ""
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(("templates:" + template_key + "\n").to_utf8_buffer())
	for item: Variant in items: hash.update(var_to_bytes(item))
	hash.update(var_to_bytes(contract))
	return hash.finish().hex_encode()

func load_original_bound(catalog_bytes: PackedByteArray, items: Array, contract: Dictionary) -> bool:
	if not data.is_empty(): return true
	loaded_from_bake = false
	# The model is a pure function of these inputs; reuse this device's
	# compile of the same inputs (see current523_bake_cache.gd).
	var catalog_hash := HashingContext.new(); catalog_hash.start(HashingContext.HASH_SHA256); catalog_hash.update(catalog_bytes)
	_bake_key = BAKE.key([catalog_hash.finish().hex_encode(),_registered_catalog_key(items,contract),
		str(SOURCE_DEFINITIONS.identity().get("source_sha256","")),BAKE.code_key(BAKE_CODE)])
	_model_key = _bake_key
	var baked: Variant = BAKE.read(BAKE_NAME,_bake_key)
	var usable: bool = baked is Dictionary and baked.get("model") is Dictionary and baked.get("sha256") is String and baked.get("offloaded") == true
	if usable and OS.get_environment("TWILIGHT_RULES_RECORDS_RESIDENT") == "1": usable = false
	if usable and BAKE.open_records(RECORDS_NAME,_bake_key) == null: usable = false
	if usable and (baked.model.get("equipment_runtime",{}) as Dictionary).get(RUNTIME_MARK) == true and BAKE.open_records(RUNTIME_NAME,_bake_key) == null: usable = false
	if usable:
		if _accept(baked.model,baked.sha256):
			loaded_from_bake = true
			_release_cold()
			return true
		data = {}
	baked = null
	BOOT_LOG.mark("rules_cold_build", {"bake_usable": usable})
	return compile_original_bound(catalog_bytes,items,contract,_bake_key)

## Compile outcomes of _load_candidate().
const COMPILED: int = 1
const REJECTED: int = 0
## The record files could not be written or read back: nothing was accepted
## and the same inputs are compiled again with every part resident.
const RESIDENT_RETRY: int = -1

## Test seam: the definition reader the compile uses (null: the installed
## original through current523_definition_rows.gd).
var _projection_source: Variant = null

func _new_projection() -> Variant:
	var projection = ORIGINAL_PROJECTION.new()
	if _projection_source != null: projection.source = _projection_source
	return projection

## The cold compile behind load_original_bound(): `key` is the bake key of
## these inputs ("" = no device bake: everything stays resident). Bounded:
## the registered catalog identities are held packed, the big original tables
## are read by position, and the two per-item parts (catalog identities,
## equipment runtime) go from the compiler to their record files one item at
## a time (see _load_candidate). If a record file cannot be written, the
## documented fallback is kept: the model is compiled again fully resident and
## no bake is written, so the next start retries.
func compile_original_bound(catalog_bytes: PackedByteArray, items: Array, contract: Dictionary, key: String) -> bool:
	_bake_key = ""
	_model_key = ""
	var outcome: int = _compile_bound(catalog_bytes,items,contract,key)
	if outcome == RESIDENT_RETRY:
		BOOT_LOG.mark("rules_resident_retry")
		data = {}
		_records = null
		_runtime = null
		outcome = _compile_bound(catalog_bytes,items,contract,"")
		if outcome == COMPILED:
			# As before a failed record write: cold parts may still be offloaded.
			_cold_key = key
			_release_cold()
	return outcome == COMPILED

func _compile_bound(catalog_bytes: PackedByteArray, items: Array, contract: Dictionary, key: String) -> int:
	var projection = _new_projection()
	var started: int = BOOT_LOG.begin("rules_binding",{"items":items.size()})
	# The registered identities as a packed store instead of ~30,000 parsed
	# Dictionaries (the same records; see patch523_packed_records.gd).
	var document: Dictionary = ORIGINAL_PROJECTION.binding_document(items,contract,true,true)
	BOOT_LOG.end("rules_binding",started)
	var binding: Dictionary = document.binding
	var binding_sha: String = document.sha256
	document = {}
	started = BOOT_LOG.begin("rules_build")
	var candidate: Dictionary = projection.build_bound(catalog_bytes,binding,binding_sha)
	binding = {}
	BOOT_LOG.end("rules_build",started,{"ok":not candidate.is_empty()})
	return _load_candidate(projection,candidate,key)

## Serializes, identifies and accepts a compiled candidate. With `key` (and
## record storage usable) the per-item parts are written to their record
## files while they are serialized, so the accepted model is already in its
## offloaded form and no item's catalog identity or runtime is held twice.
func _load_candidate(projection: Variant, candidate: Dictionary, key: String) -> int:
	# UNVERIFIED: the original ZIP identifies inputs; the actual normalized
	# payload bytes identify this rules model. No private file is generated.
	problem = ""
	if candidate.is_empty():
		problem = projection.problem
		projection.call("release")
		return REJECTED
	var offload: bool = not key.is_empty() and OS.get_environment("TWILIGHT_RULES_RECORDS_RESIDENT") != "1"
	var wanted: bool = offload
	var record_writer: Object = null
	var runtime_writer: Object = null
	if offload:
		# Earlier handles on these files are dropped before they are replaced.
		_records = null
		_runtime = null
		record_writer = BAKE.record_writer(RECORDS_NAME,key)
		runtime_writer = BAKE.record_writer(RUNTIME_NAME,key) if record_writer != null else null
		if runtime_writer == null:
			# Storage unusable: documented fallback, everything stays resident.
			if record_writer != null: record_writer.abort()
			record_writer = null
			offload = false
	var items_part: Variant = candidate.get("items")
	var runtime_part: Variant = candidate.get("equipment_runtime")
	if offload and not (items_part is ORIGINAL_PROJECTION.Part and runtime_part is ORIGINAL_PROJECTION.Part):
		record_writer.abort(); runtime_writer.abort()
		record_writer = null; runtime_writer = null
		offload = false
	if offload:
		# Same records, IDs and order as writing them from the accepted model.
		items_part.take = func(id: String, entry: Variant) -> Variant:
			if entry is Dictionary and (entry as Dictionary).has("catalog_record"):
				record_writer.add(id,entry.catalog_record)
				entry.erase("catalog_record")
				entry[RECORDS_MARK] = true
			return entry
		runtime_part.take = func(id: String, value: Variant) -> Variant:
			runtime_writer.add(id,value)
			return ORIGINAL_PROJECTION.SKIP
		runtime_part.finish = func(_kept: Dictionary) -> Variant:
			return {RUNTIME_MARK: true} if runtime_part.count > 0 else {}
	# The model is identified by, and loaded as, the parse of its JSON bytes;
	# both come from one streamed pass instead of a whole-model text.
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var size: Array = [0]
	var started: int = BOOT_LOG.begin("rules_round_trip",{"offload":offload})
	var parsed: Variant = ORIGINAL_PROJECTION.stream_round_trip(candidate,hash,3,size)
	var record_count: int = int(items_part.count) if offload else 0
	var runtime_count: int = int(runtime_part.count) if offload else 0
	# The parts' callables hold the compiler and the writers: dropped here.
	for part: Variant in [items_part,runtime_part]:
		if part is ORIGINAL_PROJECTION.Part:
			part.make = Callable(); part.take = Callable(); part.finish = Callable()
	items_part = null
	runtime_part = null
	candidate.clear()
	var stream_problem: String = str(projection.problem)
	projection.call("release")
	BOOT_LOG.end("rules_round_trip",started,{"bytes":int(size[0])})
	if int(size[0]) < 0 or int(size[0]) > MAX_BYTES or (offload and not _valid_model(parsed)):
		if offload: record_writer.abort(); runtime_writer.abort()
		if int(size[0]) < 0: problem = stream_problem
		elif int(size[0]) > MAX_BYTES: problem = "원본523 제작 규칙 파일 크기를 확인하세요"
		return REJECTED
	var sha: String = hash.finish().hex_encode()
	if offload:
		started = BOOT_LOG.begin("rules_records_commit",{"records":record_count,"runtime":runtime_count})
		var committed: bool = BAKE.finish_records(record_writer)
		if runtime_count == 0: runtime_writer.abort()
		elif committed: committed = BAKE.finish_records(runtime_writer)
		else: runtime_writer.abort()
		record_writer = null
		runtime_writer = null
		# Read back before anything depends on them.
		if committed:
			var stored: Object = BAKE.open_records(RECORDS_NAME,key)
			committed = stored != null and stored.offsets.size() == record_count
			stored = BAKE.open_records(RUNTIME_NAME,key) if committed and runtime_count > 0 else null
			if committed and runtime_count > 0: committed = stored != null and stored.offsets.size() == runtime_count
		BOOT_LOG.end("rules_records_commit",started,{"ok":committed})
		if not committed: return RESIDENT_RETRY
		_model_key = key
	started = BOOT_LOG.begin("rules_accept")
	var accepted: bool = _accept(parsed,sha)
	BOOT_LOG.end("rules_accept",started,{"ok":accepted})
	if not accepted: return REJECTED
	if offload:
		# Every offloaded entry must be readable from the opened files.
		var complete: bool = _records != null and (runtime_count == 0 or (_runtime != null and _runtime_ids.size() == runtime_count))
		if complete:
			for id: Variant in data.items:
				var entry: Variant = data.items[id]
				if entry is Dictionary and (entry as Dictionary).get(RECORDS_MARK) == true and not _records.has(str(id)):
					complete = false
					break
		if not complete:
			data = {}
			recipes = {}
			digest = ""
			return RESIDENT_RETRY
		# Baked after acceptance in its offloaded form (catalog identities and
		# runtime live in their record files), so a later start decodes only the
		# light model. Without both record files the bake is never used.
		started = BOOT_LOG.begin("rules_bake_write")
		BAKE.write(BAKE_NAME,key,{"model":data,"sha256":sha,"offloaded":true})
		BOOT_LOG.end("rules_bake_write",started)
	elif wanted:
		# Record storage was unusable from the start: as before, the cold parts
		# may still be offloaded under the same key.
		_cold_key = key
	# The bake keeps the whole model; only then are cold parts released.
	started = BOOT_LOG.begin("rules_cold_release")
	_release_cold()
	BOOT_LOG.end("rules_cold_release",started)
	return COMPILED

func _load_payload(text: String, expected_sha256: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		problem = "원본523 제작 규칙 파일 크기를 확인하세요"
		return false
	var parser := JSON.new()
	if parser.parse(text) != OK:
		problem = "원본523 규칙 JSON 형식 오류"
		return false
	return _accept(parser.data,expected_sha256)

func _accept(parsed: Variant, expected_sha256: String) -> bool:
	if not _valid_model(parsed): return false
	# Rejected replacements never erase the last valid registry.
	data = parsed
	_bonus_ids.clear()
	_bonus_ready = false
	_bonus_packed = false
	_bonus_sorted = PackedInt64Array()
	_cold = null
	_cold_key = ""
	_cold_parts = PackedStringArray()
	_cold_cache.clear()
	_offload_catalog_records()
	recipes = data.recipes.duplicate(true)
	digest = expected_sha256
	return true

## The structure checks of _accept() (sets `problem`); nothing is changed.
func _valid_model(parsed: Variant) -> bool:
	if not parsed is Dictionary or parsed.get("schema", "") != SCHEMA or parsed.get("snapshot", "") != "patch523" or parsed.get("catalog_sha256", "") != FileAccess.get_sha256("res://data/catalog_v19.json"):
		problem = "원본523 제작 규칙·현재 아이템 DB 불일치"
		return false
	for key: String in ["recipes", "raw_recipes", "items", "bonuses", "bonus_types", "enchantment", "source_files"]:
		if not parsed.get(key) is Dictionary:
			problem = "원본523 제작 규칙 구조 오류"
			return false
	for id: Variant in parsed.recipes:
		var value: Variant = parsed.recipes[id]
		if not value is Dictionary or not str(id).begins_with("patch523:") or value.get("id", "") != id or value.get("source_snapshot", "") != "patch523" or not value.get("result") is Dictionary or not value.get("materials") is Array or int(value.get("adena", -1)) < 0:
			problem = "원본523 제작식 구조 오류"
			return false
		for material: Variant in value.materials:
			if not valid_material(material):
				problem = "원본523 재료 상태 구조 오류"
				return false
		if value.has("outcomes"):
			if not value.outcomes is Array or value.outcomes.size()<2:
				problem="원본 제작 결과 분기 구조 오류"; return false
			var total: int=0
			for outcome: Variant in value.outcomes:
				if not valid_outcome(outcome) or typeof(outcome.get("probability")) not in [TYPE_INT,TYPE_FLOAT] or float(outcome.probability)!=float(int(outcome.probability)) or int(outcome.probability)<1:
					problem="원본 제작 확률 구조 오류"; return false
				total+=int(outcome.probability)
			if total!=1000000:
				problem="원본 제작 확률 합계 오류"; return false
		if value.has("craft_conditions") and not CONDITIONS.valid(value.craft_conditions):
			problem="원본 제작 자격 구조 오류"; return false
		if value.has("material_slots"):
			if not value.material_slots is Array:
				problem = "원본523 후보 슬롯 구조 오류"
				return false
			for slot: Variant in value.material_slots:
				if not slot is Dictionary or typeof(slot.get("slot_index")) not in [TYPE_INT,TYPE_FLOAT] or not slot.get("candidates") is Array or slot.candidates.is_empty():
					problem = "원본523 후보 슬롯 구조 오류"
					return false
				for material: Variant in slot.candidates:
					if not valid_material(material) or typeof(material.get("row_id")) not in [TYPE_INT,TYPE_FLOAT] or int(material.row_id)<1:
						problem = "원본523 후보 재료 구조 오류"
						return false
	return true

func recipe_evidence(craft_id: int) -> Dictionary:
	var result: Dictionary = {}
	var tables: Dictionary = {"inputs":"ItemCraftInput","outputs":"ItemCraftOutputView","views":"ItemCraftView","restrictions":"ItemCraftRestriction"}
	var cached_groups: Dictionary = data.get("raw_recipes",{})
	for key: String in tables:
		var cached: Variant = cached_groups.get(key)
		if cached is Dictionary:
			var values: Variant = cached.get(str(craft_id),[])
			result[key] = values.duplicate(true) if values is Array else []
		else:
			result[key] = SOURCE_DEFINITIONS.related(tables[key],"ItemCraftID",craft_id)
	return result

func recipe_definition(craft_id: int) -> Dictionary:
	# UNVERIFIED: complete original-definition lookup for the integration owner.
	# Reading an unadmitted craft never inserts it into the executable registry.
	var result: Dictionary = {
		"kind":"current523_craft_definition","craft_id":craft_id,
		"inputs":[],"outputs":[],"views":[],"restrictions":[],"items":{},
		"available_in_compiled_recipes":recipes.has("patch523:"+str(craft_id)),
		"reference_only":true,"can_execute":false,"source_identity":{},"problem":"",
	}
	if craft_id <= 0:
		result.problem = "제작 원본 ID가 유효하지 않습니다"
		return result
	result.source_identity = SOURCE_DEFINITIONS.identity()
	if result.source_identity.is_empty():
		result.problem = SOURCE_DEFINITIONS.problem()
		return result
	var tables: Dictionary = {"inputs":"ItemCraftInput","outputs":"ItemCraftOutputView","views":"ItemCraftView","restrictions":"ItemCraftRestriction"}
	for key: String in tables:
		result[key] = SOURCE_DEFINITIONS.related(tables[key],"ItemCraftID",craft_id)
	var item_ids: Dictionary = {}
	for original: Dictionary in result.inputs + result.outputs:
		var item_id: Variant = original.get("ItemClassID")
		if not CONDITIONS.integer(item_id,0,2147483647): continue
		# Original ItemClassID=0 remains only on its original output row.
		# It is the declared failure sentinel, never a generated item record.
		if int(item_id) != 0: item_ids[str(int(item_id))] = true
	for item_id: String in item_ids:
		# The shared read contract retains explicit TestItem exclusions and raw
		# source values. It supplies no ownership, quantity, or grant operation.
		result.items[item_id] = SOURCE_ITEMS.describe(int(item_id))
	result.problem = SOURCE_DEFINITIONS.problem()
	return result

func _source_item_allowed(source_id: int) -> bool:
	var original: Dictionary = item_entry(str(source_id)).get("item_class",{})
	if original.is_empty(): original = SOURCE_ITEMS.describe(source_id).get("item_class",{})
	if not SOURCE_DEFINITIONS.declared_exclusion("ItemClass",original).is_empty():return false
	# UNVERIFIED: read the supplied item's explicit flag; retain excluded rows
	# in the source and private pack instead of turning them into active stock.
	return not original.is_empty() and original.get("ID") == source_id and original.get("TestItem") == false

static func _source_item_tuple(projected: Dictionary, original: Dictionary) -> bool:
	for pair: Array in [["source_id","ItemClassID"],["quantity","Amount"],["level","Enchant"],["bless_code","ItemBlessCodeID"]]:
		var value: Variant = original.get(pair[1])
		if not CONDITIONS.integer(value,0,2147483647): return false
		if pair[0] == "source_id":
			if projected.get(pair[0]) != str(int(value)): return false
		elif not CONDITIONS.integer(projected.get(pair[0]),0,2147483647) or int(projected[pair[0]]) != int(value): return false
	return true

func _source_recipe_contract(recipe: Dictionary) -> Dictionary:
	# UNVERIFIED: exact cached source joins are consumed by material_selection,
	# which quote/execute already call. This does not admit additional recipes.
	var craft_id: Variant = recipe.get("source_craft_id")
	if not CONDITIONS.integer(craft_id,1,2147483647) or recipe.get("id") != "patch523:"+str(int(craft_id)):
		return denied("제작 원본 ID 관계가 필요합니다 · 재료 보존")
	var source: Dictionary = recipe_evidence(int(craft_id))
	for key: String in ["inputs","outputs","views","restrictions"]:
		if not source.get(key) is Array: return denied("제작 원본 관계가 없습니다 · 재료 보존")
		if key != "restrictions" and source[key].is_empty(): return denied("제작 원본 관계가 없습니다 · 재료 보존")
		for value: Variant in source[key]:
			if not value is Dictionary or value.get("ItemCraftID") != int(craft_id): return denied("제작 원본 참조가 다릅니다 · 재료 보존")
	for original: Dictionary in source.inputs + source.outputs:
		if not CONDITIONS.integer(original.get("ItemClassID"),0,2147483647): return denied("제작 원본 품목 참조가 필요합니다")
		if int(original.ItemClassID) != 0 and not _source_item_allowed(int(original.ItemClassID)):
			return denied("제작 원본 품목이 미확정 또는 명시적 시험용입니다 · 재료 보존")
		if int(original.get("ItemHoningEpithetID",0)) != 0 or int(original.get("ClanItemClassID",0)) != 0 or int(original.get("ClanAmount",0)) != 0:
			return denied("별도 소유자 제작 조건입니다 · 재료 보존")
	var conditions: Dictionary = CONDITIONS.source_recipe(recipe,source.views,source.restrictions)
	if not conditions.get("ok",false): return conditions
	var primary_found: bool = false
	var view_found: bool = false
	for original: Dictionary in source.outputs:
		if original.get("ItemCraftOutputTypeID") == 1 and _source_item_tuple(recipe.result,original): primary_found = true
	for original: Dictionary in source.views:
		if _source_item_tuple(recipe.result,original): view_found = true
	if not primary_found or not view_found: return denied("제작 결과와 원본 표시·결과 관계가 다릅니다 · 재료 보존")
	if not recipe.has("outcomes"):
		if source.outputs.size() != 1 or source.outputs[0].get("Probability") != 1000000:
			return denied("원본 제작 결과 분기를 확인해야 합니다 · 재료 보존")
		for view: Dictionary in source.views:
			if view.get("AlwaysSuccess") != 1: return denied("원본 제작 성공 조건이 다릅니다 · 재료 보존")
	else:
		var remaining: Array = source.outputs.duplicate()
		for outcome: Dictionary in recipe.outcomes:
			if outcome.get("twilight_missing_failure",false):
				# Keep the existing explicit missing-failure policy separate from
				# source rows. It must never stand in for an omitted real branch.
				if source.outputs.size() != 1 or source.outputs[0].get("ItemCraftOutputTypeID") != 1 or source.views.size() != 1 or source.views[0].get("AlwaysSuccess") != 0 or not outcome.get("empty_result",false) or outcome.get("probability") != 1000000-int(source.outputs[0].get("Probability",0)):
					return denied("원본과 자체 누락 실패 경계가 다릅니다 · 재료 보존")
				continue
			var found: int = -1
			for index: int in range(remaining.size()):
				var original: Dictionary = remaining[index]
				if _source_item_tuple(outcome,original) and outcome.get("probability") == original.get("Probability") and outcome.get("label") == {0:"실패",1:"성공",2:"대성공"}.get(int(original.get("ItemCraftOutputTypeID",-1)),""):
					found = index
					break
			if found < 0: return denied("제작 결과의 원본 행·확률 관계가 다릅니다 · 재료 보존")
			remaining.remove_at(found)
		if not remaining.is_empty(): return denied("원본 제작 결과가 빠져 있습니다 · 재료 보존")
	return {"ok":true,"source":source}

static func _source_material_contract(recipe: Dictionary, source: Dictionary) -> Dictionary:
	var slots: Dictionary = {}
	var ids: Dictionary = {}
	for original: Dictionary in source.inputs:
		if not CONDITIONS.integer(original.get("ID"),1,2147483647) or not CONDITIONS.integer(original.get("SlotIndex"),0,2147483647) or ids.has(int(original.ID)):
			return denied("제작 재료 원본 행·슬롯이 모호합니다 · 재료 보존")
		ids[int(original.ID)] = original
		var slot: int = int(original.SlotIndex)
		if not slots.has(slot): slots[slot] = []
		slots[slot].append(original)
	var fee: int = 0
	var selected_slots: Dictionary = {}
	for slot: int in slots:
		var candidates: Array = slots[slot]
		if candidates.size() == 1 and candidates[0].get("ItemClassID") == 26:
			if candidates[0].get("Enchant") != 0 or candidates[0].get("ItemBlessCodeID") != 1 or not CONDITIONS.integer(candidates[0].get("Amount"),1,1000000000):
				return denied("원본 아데나 재료 상태가 다릅니다 · 재료 보존")
			fee += int(candidates[0].Amount)
			selected_slots[slot] = true
	if int(recipe.get("adena",-1)) != fee: return denied("원본 아데나 재료 합계가 다릅니다 · 재료 보존")
	for material: Dictionary in recipe.materials:
		var original: Dictionary = ids.get(int(material.get("row_id",0)),{})
		if original.is_empty() or material.get("slot_index") != original.SlotIndex or selected_slots.has(int(original.SlotIndex)) or not _source_item_tuple(material,original):
			return denied("선택 재료의 원본 행·슬롯·수량·강화·축복이 다릅니다 · 재료 보존")
		selected_slots[int(original.SlotIndex)] = true
	return {"ok":true} if selected_slots.size() == slots.size() else denied("원본 재료 슬롯의 선택이 필요합니다 · 재료 보존")

static func denied(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _offload_catalog_records() -> void:
	_records = null
	_runtime = null
	_runtime_ids.clear()
	_runtime_cache.clear()
	var key: String = _model_key
	_model_key = ""
	if key.is_empty() or not data.get("items") is Dictionary or OS.get_environment("TWILIGHT_RULES_RECORDS_RESIDENT") == "1": return
	_cold_key = key
	var items: Dictionary = data.items
	var records: Object = BAKE.open_records(RECORDS_NAME,key)
	if records == null:
		var ids := PackedStringArray()
		var values: Array = []
		for id: Variant in items:
			if items[id] is Dictionary and (items[id] as Dictionary).has("catalog_record"):
				ids.append(str(id)); values.append(items[id].catalog_record)
		if not BAKE.write_records(RECORDS_NAME,key,ids,values): return
		records = BAKE.open_records(RECORDS_NAME,key)
		if records == null: return
	for id: Variant in items:
		var entry: Variant = items[id]
		if entry is Dictionary and (entry as Dictionary).has("catalog_record") and records.has(str(id)):
			entry.erase("catalog_record")
			entry[RECORDS_MARK] = true
	_records = _compact_records(records)
	# Per-item equipment runtime (enchant/extra option tables) likewise.
	var runtime: Variant = data.get("equipment_runtime")
	if not runtime is Dictionary or (runtime as Dictionary).is_empty(): return
	if (runtime as Dictionary).get(RUNTIME_MARK) == true:
		var existing: Object = BAKE.open_records(RUNTIME_NAME,key)
		if existing == null: return
		_runtime_ids.clear()
		for id: Variant in existing.offsets: _runtime_ids[str(id)] = true
		_runtime = existing
		return
	var stored: Object = BAKE.open_records(RUNTIME_NAME,key)
	if stored == null:
		var ids := PackedStringArray()
		var values: Array = []
		for id: Variant in runtime: ids.append(str(id)); values.append(runtime[id])
		if not BAKE.write_records(RUNTIME_NAME,key,ids,values): return
		stored = BAKE.open_records(RUNTIME_NAME,key)
		if stored == null: return
	for id: Variant in runtime:
		if not stored.has(str(id)): return
	_runtime_ids.clear()
	for id: Variant in runtime: _runtime_ids[str(id)] = true
	_runtime = stored
	data.equipment_runtime = {RUNTIME_MARK: true}

const RUNTIME_NAME := "equipment_rules_runtime"
const RUNTIME_MARK := "twilight_runtime_offloaded"
var _runtime: Object = null
var _runtime_ids: Dictionary = {}
var _runtime_cache: Dictionary = {}

## The compiled equipment runtime of one item ({} when it has none).
func equipment_runtime_of(source_id: String) -> Dictionary:
	var runtime: Dictionary = data.get("equipment_runtime",{})
	if runtime.get(RUNTIME_MARK) != true: return runtime.get(source_id,{})
	if not _runtime_ids.has(source_id) or _runtime == null: return {}
	if not _runtime_cache.has(source_id):
		if _runtime_cache.size() >= 64: _runtime_cache.clear()
		var value: Variant = _runtime.read(source_id)
		_runtime_cache[source_id] = value if value is Dictionary else {}
	return _runtime_cache[source_id]

func has_equipment_runtime(source_id: String) -> bool:
	var runtime: Dictionary = data.get("equipment_runtime",{})
	return _runtime_ids.has(source_id) if runtime.get(RUNTIME_MARK) == true else runtime.has(source_id)

func has_any_equipment_runtime() -> bool:
	var runtime: Dictionary = data.get("equipment_runtime",{})
	return not _runtime_ids.is_empty() if runtime.get(RUNTIME_MARK) == true else not runtime.is_empty()

## The compiled catalog record of one item entry (from storage when offloaded).
func catalog_record_of(source_id: String) -> Dictionary:
	var entry: Variant = data.get("items",{}).get(source_id)
	if not entry is Dictionary: return {}
	if (entry as Dictionary).has("catalog_record"): return entry.catalog_record
	if entry.get(RECORDS_MARK) == true and _records != null:
		var value: Variant = _records.read(source_id)
		if value is Dictionary: return value
	return {}

var _bonus_ids: Dictionary = {}
## One selected original Bonus row by ID string ({} when not selected).
func bonus_row(id: String) -> Dictionary:
	var bonuses: Dictionary = data.get("bonuses",{})
	if bonuses.get("twilight_source_lazy") != true: return bonuses.get(id,{})
	if not _bonus_ready: _prepare_bonus_index()
	if not _bonus_member(id) or not id.is_valid_int(): return {}
	var rows: Array[Dictionary] = SOURCE_DEFINITIONS.related("Bonus","ID",int(id))
	return rows[-1] if not rows.is_empty() else {}

## Membership of the lazy Bonus ID list: a sorted PackedInt64Array (~0.7 MB)
## instead of a Dictionary of ~80,000 ID strings (~7 MB). The packed form is
## used only when every listed ID is a canonical integer string, so it answers
## exactly as the string-keyed set did.
var _bonus_ready: bool = false
var _bonus_packed: bool = false
var _bonus_sorted := PackedInt64Array()

func _prepare_bonus_index() -> void:
	_bonus_ids.clear()
	_bonus_sorted = PackedInt64Array()
	var values: Variant = (data.get("bonuses",{}) as Dictionary).get("ids",[])
	_bonus_packed = values is Array
	if _bonus_packed:
		for value: Variant in values:
			var text: String = str(value)
			if not text.is_valid_int() or str(text.to_int()) != text:
				_bonus_packed = false
				break
			_bonus_sorted.append(text.to_int())
	if _bonus_packed: _bonus_sorted.sort()
	else:
		_bonus_sorted = PackedInt64Array()
		for value: Variant in values: _bonus_ids[str(value)] = true
	# An empty list is read again on the next call, as before.
	_bonus_ready = not _bonus_sorted.is_empty() or not _bonus_ids.is_empty()

func _bonus_member(id: String) -> bool:
	if not _bonus_packed: return _bonus_ids.has(id)
	if not id.is_valid_int() or str(id.to_int()) != id: return false
	var value: int = id.to_int()
	var position: int = _bonus_sorted.bsearch(value)
	return position < _bonus_sorted.size() and _bonus_sorted[position] == value

## Cold model parts. After the original-compiled model is accepted (and baked
## whole), the parts no hot path reads by scanning are kept in a record file on
## this device (keyed like the bake: catalog SHA + registered catalog key +
## source SHA + code key) and replaced in `data` by empty placeholders of the
## same type at the same key. Readers: bonus_type(), offloaded_invoke_option(),
## materialized_data(). TWILIGHT_RULES_RECORDS_RESIDENT=1 keeps everything.
const COLD_NAME := "equipment_rules_cold"
const COLD_ENCHANTMENT: Array[String] = ["InvokeOption","InvokeOptionType","ItemEquipSlot","EquipSlotConfig","ItemBlessBonus",
	"Unit","UIUnit","BonusApplicationType","AttackType","ItemBlessCode","ItemEnchantScrollGroup"]
var _cold: Object = null
var _cold_key: String = ""
var _cold_parts := PackedStringArray()
var _cold_cache: Dictionary = {}

func _release_cold() -> void:
	var key: String = _cold_key
	_cold_key = ""
	if key.is_empty() or data.is_empty() or digest.is_empty() or OS.get_environment("TWILIGHT_RULES_RECORDS_RESIDENT") == "1": return
	_share_item_entries()
	var parts: Dictionary = {}
	for name: String in ["recipes","recipe_admission","bonus_types"]:
		if data.get(name) is Dictionary and not (data[name] as Dictionary).is_empty(): parts[name] = data[name]
	var bonuses: Variant = data.get("bonuses")
	if bonuses is Dictionary and bonuses.get("twilight_source_lazy") == true and bonuses.get("ids") is Array and not (bonuses.ids as Array).is_empty():
		_prepare_bonus_index()
		if _bonus_ready: parts["bonus_ids"] = bonuses.ids
	var tables: Variant = data.get("enchantment")
	if tables is Dictionary:
		for name: String in COLD_ENCHANTMENT:
			if tables.get(name) is Array and not (tables[name] as Array).is_empty(): parts["enchantment:"+name] = tables[name]
	if parts.has("enchantment:InvokeOption"):
		for row: Variant in parts["enchantment:InvokeOption"]:
			if not row is Dictionary or typeof(row.get("ID")) not in [TYPE_INT,TYPE_FLOAT]:
				parts.erase("enchantment:InvokeOption")
				break
	if parts.is_empty(): return
	var cold: Object = BAKE.open_records(COLD_NAME,key)
	if not _cold_complete(cold,parts):
		var writer = BAKE.record_writer(COLD_NAME,key)
		if writer == null: return
		writer.add("digest",digest)
		for name: String in parts:
			writer.add(name,parts[name])
			if name == "bonus_types":
				for id: Variant in parts[name]: writer.add("bonus_type:"+str(id),parts[name][id])
			elif name == "enchantment:InvokeOption":
				# Last row per ID, as the enhancement lookup indexed them.
				for row: Dictionary in parts[name]: writer.add("invoke:"+str(int(row.ID)),row)
		if not BAKE.finish_records(writer): return
		cold = BAKE.open_records(COLD_NAME,key)
		if not _cold_complete(cold,parts): return
	_cold = cold
	_cold_cache.clear()
	# Same key, same type, emptied: key order and readers' types are kept.
	for name: String in parts:
		if name.begins_with("enchantment:"): data.enchantment[name.trim_prefix("enchantment:")] = []
		elif name == "bonus_ids": data.bonuses.ids = []
		else: data[name] = {}
	_cold_parts = PackedStringArray(parts.keys())

func _cold_complete(cold: Object, parts: Dictionary) -> bool:
	if cold == null or cold.read("digest") != digest: return false
	for name: String in parts:
		if not cold.has(name): return false
		if name == "bonus_types":
			for id: Variant in parts[name]:
				if not cold.has("bonus_type:"+str(id)): return false
	return true

func _cold_read(record_id: String) -> Variant:
	if _cold_cache.has(record_id): return _cold_cache[record_id]
	if _cold_cache.size() >= 256: _cold_cache.clear()
	var value: Variant = _cold.read(record_id)
	_cold_cache[record_id] = value
	return value

## Identical offloaded item entries (most native items: lazy marker, offloaded
## marker, no use conditions) share one read-only Dictionary. item_entry()
## never returns an offloaded entry itself, so readers see the same values.
func _share_item_entries() -> void:
	var items: Variant = data.get("items")
	if not items is Dictionary: return
	var canonical: Dictionary = {}
	for id: Variant in (items as Dictionary).keys():
		var entry: Variant = items[id]
		if not entry is Dictionary or (entry as Dictionary).get(RECORDS_MARK) != true: continue
		var bytes: PackedByteArray = var_to_bytes(entry)
		var shared: Variant = canonical.get(bytes)
		if shared == null:
			canonical[bytes] = entry
			continue
		if not (shared as Dictionary).is_read_only(): _freeze(shared)
		items[id] = shared

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value: _freeze(value[key])
		(value as Dictionary).make_read_only()
	elif value is Array:
		for item: Variant in value: _freeze(item)
		(value as Array).make_read_only()

## One original BonusType row by ID string ({} when absent).
func bonus_type(id: String) -> Dictionary:
	if _cold == null or not _cold_parts.has("bonus_types"): return data.bonus_types.get(id,{})
	var value: Variant = _cold_read("bonus_type:"+id)
	return value if value is Dictionary else {}

## The InvokeOption row of one ID when that table is on storage ({} when the
## ID has none); null while the table is resident in data.enchantment.
func offloaded_invoke_option(id: String) -> Variant:
	if _cold == null or not _cold_parts.has("enchantment:InvokeOption"): return null
	var value: Variant = _cold_read("invoke:"+id)
	return value if value is Dictionary else {}

## `data` with every cold part read back: the whole compiled model exactly as
## it was accepted (diagnostics and verification only; reads ~9 MB).
func materialized_data() -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	if _cold == null: return result
	for name: String in _cold_parts:
		var value: Variant = _cold.read(name)
		if name.begins_with("enchantment:"): result.enchantment[name.trim_prefix("enchantment:")] = value
		elif name == "bonus_ids": result.bonuses.ids = value
		else: result[name] = value
	return result

## Catalog record file index as sorted packed integers (~0.4 MB) instead of a
## Dictionary of ~27,000 ID strings (~3.9 MB); used only when every ID is a
## canonical integer string, so has()/read() answer exactly as before.
class CompactRecords extends RefCounted:
	var file: FileAccess
	var keys := PackedInt64Array()
	var offsets := PackedInt64Array()
	func _position(id: String) -> int:
		if not id.is_valid_int() or str(id.to_int()) != id: return -1
		var value: int = id.to_int()
		var position: int = keys.bsearch(value)
		return position if position < keys.size() and keys[position] == value else -1
	func has(id: String) -> bool: return _position(id) >= 0
	func read(id: String) -> Variant:
		var position: int = _position(id)
		if position < 0: return null
		file.seek(offsets[position])
		return file.get_var()

static func _compact_records(records: Object) -> Object:
	if records == null or not records.get("offsets") is Dictionary: return records
	var compact := CompactRecords.new()
	for id: Variant in records.offsets:
		var text: String = str(id)
		if not id is String or not text.is_valid_int() or str(text.to_int()) != text: return records
		compact.keys.append(text.to_int())
	compact.keys.sort()
	compact.offsets.resize(compact.keys.size())
	for id: Variant in records.offsets:
		var position: int = compact.keys.bsearch(str(id).to_int())
		# Two spellings can never share a canonical value; guard anyway.
		if position >= compact.keys.size() or compact.keys[position] != str(id).to_int(): return records
		compact.offsets[position] = int(records.offsets[id])
	for position: int in range(1, compact.keys.size()):
		if compact.keys[position] == compact.keys[position - 1]: return records
	compact.file = records.file
	return compact

## One compiled item entry with its original rows. Entries compiled from the
## installed original keep only a lazy marker; their item_class/item_bonuses/
## enchant_effects are read back from the shared original reader.
func item_entry(source_id: String) -> Dictionary:
	var entry: Variant = data.get("items",{}).get(source_id)
	if not entry is Dictionary: return {}
	if (entry as Dictionary).get("twilight_source_lazy") != true and (entry as Dictionary).get(RECORDS_MARK) != true: return entry
	var full: Dictionary = {}
	if (entry as Dictionary).get(RECORDS_MARK) == true: full["catalog_record"] = catalog_record_of(source_id)
	full.merge(entry as Dictionary)
	full.erase(RECORDS_MARK)
	if full.get("twilight_source_lazy") != true: return full
	full.erase("twilight_source_lazy")
	full.merge(ORIGINAL_PROJECTION.source_fields(source_id), true)
	return full

func record(source_id: String, stack_bless: int=1) -> Dictionary:
	# Only catalog/variant/use fields are read; no original rows are needed.
	var item: Dictionary = data.get("items",{}).get(source_id,{})
	var result: Dictionary = (item.get("stack_variants",{}).get(str(stack_bless),{}) if stack_bless!=1 else catalog_record_of(source_id)).duplicate(true)
	if result.get("twilight_binding_slim") == true:
		var live: Variant = live_record.call(str(result.get("sourceId",""))) if live_record.is_valid() else {}
		if live is Dictionary and not (live as Dictionary).is_empty() and (live as Dictionary).get("name") == result.get("name"): result = (live as Dictionary).duplicate(true)
		else: result.erase("twilight_binding_slim")
	if not preload("res://scripts/quests/source_dummy523.gd").record_evidence(result).is_empty():return {}
	var use: Dictionary = item.get("use_conditions",{})
	if not use.is_empty(): result["patch523_item_use"]=use.duplicate(true)
	return result

func craftsman_weapon_rule(pinned: Dictionary) -> Dictionary:
	# Public table is grade scoped. Only exact current523/catalog identities
	# enter this override; local and unidentified host items keep their rules.
	if pinned.get("source","")!="inven" or pinned.get("slot","")!="weapon": return {}
	var id: String = str(pinned.get("sourceId",""))
	var entry: Dictionary = item_entry(id)
	var canonical: Dictionary = catalog_record_of(id)
	if canonical.get("source","")!="inven" or canonical.get("name")!=pinned.get("name") or canonical.get("grade")!=pinned.get("grade"): return {}
	var grade: int = int(entry.get("item_class",{}).get("GradeID",-1))
	var names: Dictionary = {1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}
	if not names.has(grade) or canonical.get("grade")!=names[grade]: return {}
	return {"levels":[] if grade==52 else ([9,10,11] if grade==32 else ([9,10] if grade==5 else [9])),
		"success":5.0,"no_change":95.0,"destroy":0.0,"decrease":0.0}

static func identity(physical: Dictionary) -> String:
	var pinned: Variant = physical.get("record", {})
	if not pinned is Dictionary:
		return ""
	var source_id: String = str(pinned.get("sourceId", ""))
	if physical.has("sourceId") and str(physical.sourceId) != source_id:
		return ""
	if pinned.get("source")=="inven": return source_id
	if pinned.get("source")=="lineagem_patch523" and pinned.get("source_snapshot")=="patch523" and pinned.get("source_m_native_item",false) and source_id=="m523:item:"+str(int(pinned.get("source_item_class_id",0))) and int(pinned.get("source_item_class_id",0))>0: return str(int(pinned.source_item_class_id))
	return ""

static func _source_ids_match(left: Variant, right: Variant, allow_zero: bool=false) -> bool:
	if not left is Array or not right is Array or left.size()!=right.size(): return false
	var a: Array[int]=[]
	var b: Array[int]=[]
	for pair: Array in [[left,a],[right,b]]:
		for value: Variant in pair[0]:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or float(value)!=float(int(value)) or int(value)<(0 if allow_zero else 1): return false
			pair[1].append(int(value))
	a.sort(); b.sort()
	return a==b

## The compiled catalog identity (no live-record substitution).
func compiled_record(source_id: String, stack_bless: int=1) -> Dictionary:
	var item: Dictionary = data.get("items",{}).get(source_id,{})
	var result: Dictionary = (item.get("stack_variants",{}).get(str(stack_bless),{}) if stack_bless!=1 else catalog_record_of(source_id)).duplicate(true)
	if not preload("res://scripts/quests/source_dummy523.gd").record_evidence(result).is_empty():return {}
	return result

func catalog_identity_matches(item: Dictionary, source_id: String, stack_bless: int=1) -> bool:
	# Compare against the compiled identity, never the live record itself.
	var canonical: Dictionary=compiled_record(source_id,stack_bless)
	if canonical.is_empty() or item.get("name")!=canonical.get("name") or item.get("source")!=canonical.get("source") or item.get("sourceId")!=canonical.get("sourceId"): return false
	if canonical.get("source")=="inven": return str(item.sourceId)==source_id
	if canonical.get("source")!="lineagem_patch523" or not canonical.get("source_m_native_item",false): return false
	for key: String in ["source_snapshot","source_item_class_id","source_display_name","source_is_stackable","source_test_item","source_level_limit_min","source_level_limit_max","slot"]:
		if NATIVE_FIELDS.field(item,key)!=NATIVE_FIELDS.field(canonical,key): return false
	for key: String in ["source_class_ids","source_equip_slot_ids"]:
		var entry: Dictionary=item_entry(source_id)
		var allowed: Dictionary=entry.get("craft_material_only_class_references",{})
		var allow_zero: bool=key=="source_class_ids" and canonical.get("slot")=="material" and allowed.get("scope")=="source_input_only" and allowed.get("class_ids")==NATIVE_FIELDS.field(canonical,key) and entry.get("item_bonuses",[]).is_empty()
		if not _source_ids_match(NATIVE_FIELDS.field(item,key),NATIVE_FIELDS.field(canonical,key),allow_zero): return false
	if stack_bless!=1:return NATIVE_FIELDS.field(canonical,"source_is_stackable",false) and int(item.get("source_bless_raw",0))==stack_bless and str(item.sourceId)=="m523:item:"+source_id+":bless:"+str(stack_bless)
	return identity({"record":item})==source_id

static func bless_code(physical: Dictionary) -> int:
	var pinned: Dictionary = physical.get("record", {})
	var result: int = 2 if BLESS.is_blessed(physical, pinned) else 1
	if pinned.get("source_m_native_item",false) and int(pinned.get("source_bless_raw",result))!=result: return -1
	return result if int(physical.get("source_bless_code", result)) == result else -1

static func _worn(equipped: Dictionary, id: String) -> bool:
	for value: Variant in equipped.values():
		if value is Dictionary and str(value.get("instance_id", "")) == id:
			return true
	return false

static func _drop_proof_matches(proof: Variant, source_id: String, source_bless: int) -> bool:
	if not proof is Dictionary or proof.get("source_snapshot")!="patch523" or int(proof.get("source_item_class_id",0))!=int(source_id) or int(proof.get("bless_raw",0))!=source_bless or int(proof.get("required_quest_id",-1))!=0 or int(proof.get("source_npc_id",0))<1: return false
	if proof.get("selection_policy")!="host_uniform_distinct_items_then_distinct_variants" or proof.get("quantity_policy")!="host_one" or not proof.get("source_rows") is Array or proof.source_rows.is_empty(): return false
	for row: Variant in proof.source_rows:
		if not row is Dictionary or int(row.get("ItemClassID",0))!=int(source_id) or int(row.get("NpcClassID",0))!=int(proof.source_npc_id) or int(row.get("Bless",0))!=source_bless or int(row.get("RequiredQuestID",-1))!=0: return false
	return true

static func _reward_proof_matches(proof: Variant, source_id: String) -> bool:
	# PR238 f078a465 acquisition evidence describes the initial grant. Current
	# enhancement/blessing are separately checked; legitimate reforging does
	# not rewrite or invalidate the supplier's historical receipt.
	if not proof is Dictionary or proof.get("source_snapshot")!="patch523" or not proof.get("supplier") is Dictionary or proof.supplier.is_empty():return false
	for key: String in ["item_class_id","source_item_class_id","bless","enchant"]:
		var value: Variant=proof.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=float(int(value)):return false
	return int(proof.item_class_id)==int(source_id) and int(proof.source_item_class_id)==int(source_id) and int(proof.bless) in [1,2,3] and int(proof.enchant)>=0

func _state_matches(physical: Dictionary, material: Dictionary, allow_smelt_loss: bool) -> bool:
	if identity(physical) != str(material.source_id) or int(physical.get("level", -1)) != int(material.level) or bless_code(physical) != int(material.bless_code):
		return false
	if str(physical.get("element", "")) != "" or int(physical.get("element_level", 0)) != 0:
		return false
	var canonical: Dictionary = record(str(material.source_id))
	if canonical.is_empty():
		return false
	var annotated: Dictionary = OPTIONS.annotate(canonical)
	var pinned: Dictionary = physical.get("record", {})
	if not catalog_identity_matches(pinned,str(material.source_id)): return false
	if canonical.get("source_m_native_item",false):
		for key: Variant in canonical:
			if key not in ["bless_state","blessed","source_bless_raw","patch523_item_use","source_class_ids","source_equip_slot_ids"] and pinned.get(key)!=canonical[key]: return false
	for key: Variant in pinned:
		if key == "originalSourceOptions":
			if pinned[key] != canonical.get("sourceOptions", []):
				return false
		elif key == "enhancement_options":
			if pinned[key] != canonical.get(key, {}) and pinned[key] != supported_seal_options(str(material.source_id), int(material.bless_code)) and pinned[key] != ENHANCEMENT.prepare(self,canonical,int(material.bless_code)).get(key,{}):
				return false
		elif key in ["enhancement_extra_options","patch523_blessing_bonus","patch523_invoke_options"]:
			if pinned[key]!=ENHANCEMENT.prepare(self,canonical,int(material.bless_code)).get(key,{}): return false
		elif key == "patch523_item_use":
			if pinned[key]!=canonical.get(key,{}): return false
		elif key == "source_m_drop_proof":
			if not _drop_proof_matches(pinned[key],str(material.source_id),int(material.bless_code)): return false
		elif key == "source_m_item_id":
			if int(pinned[key])!=int(material.source_id): return false
		elif key in ["bless_state", "blessed", "grade_original", "grade_evidence", "patch523_effect_basis", "weaponTypeKey", "attackKind", "attackRangeCells", "ammo", "weaponAttackSpeed"]:
			continue
		elif key == "weight" and not canonical.has(key):
			if int(pinned[key]) != 3:
				return false
		elif not canonical.has(key) and not annotated.has(key):
			return false
		elif key in ["name", "source", "sourceId", "slot", "type", "atk", "def", "hit", "hpFlat", "hpPct", "speed", "attackSpeed", "stat"]:
			if pinned[key] != canonical.get(key) and pinned[key] != annotated.get(key):
				return false
	# Unknown instance options stay protected. A known smelt state can be lost
	# only by a recipe whose original popup explicitly warns about that loss.
	for key: Variant in physical:
		if key not in ["name", "level", "element", "element_level", "record", "sourceId", "source_snapshot", "source_bless_code", "bless_state", "blessed"]:
			if key=="source_m_reward_proof":
				if not canonical.get("source_m_native_item",false) or not _reward_proof_matches(physical[key],str(material.source_id)):return false
				continue
			if key=="source_m_drop_proof":
				if physical[key]!=pinned.get(key) or not _drop_proof_matches(physical[key],str(material.source_id),int(material.bless_code)): return false
				continue
			if key != "source_smelt" or not allow_smelt_loss:
				return false
	return true

static func _stack_has_owned_entities(material: Dictionary, physical: Dictionary, owned_key: String) -> bool:
	# Pending rewards/quest materials have an owner-maintained quantity and
	# receipt. A plain name-keyed debit must never leave that entity unchanged.
	# Until that owner's deduction contract is installed, preserve the stack.
	for instance: Variant in physical.values():
		if instance is Dictionary and str(instance.get("name","")) in [owned_key,str(material.item)]:return true
	return false

func available_material(material: Dictionary, inventory: Dictionary, items: Dictionary, physical: Dictionary, equipped: Dictionary, locks: Dictionary, allow_smelt_loss: bool, gold: int = -1, context: Dictionary = {}) -> int:
	var item_name: String = str(material.item)
	if bool(material.get("wallet",false)) and str(material.source_id)=="26": return maxi(0,gold)
	if bool(locks.get(item_name, false)):
		return 0
	var owned: int = maxi(0, int(inventory.get(ownership_key(material), 0)))
	if not bool(material.physical):
		var item: Dictionary = items.get(item_name, {})
		var total: int=owned if not _stack_has_owned_entities(material,physical,ownership_key(material)) and _stack_identity_matches(item,material) else 0
		for value: Dictionary in EXPEDITION_MATERIALS.owned(self,material,inventory,physical,locks,context).values():total+=int(value.amount)
		for value: Dictionary in QUEST_MATERIALS.owned(material,context).values():total+=int(value.row_limit)
		return total
	var eligible: int = 0
	for id: Variant in physical:
		var instance: Variant = physical[id]
		if instance is Dictionary and instance.get("name", "") == item_name and not _worn(equipped, str(id)) and not bool(locks.get(item_name + "@@@" + str(id), false)) and _state_matches(instance, material, allow_smelt_loss):
			eligible += 1
	return mini(owned, eligible)

func ownership_key(material: Dictionary) -> String:
	if not material.has("inventory_key"): return str(material.item)
	var key: String=str(material.inventory_key)
	var entry: Dictionary=item_entry(str(material.source_id))
	return key if not key.is_empty() and key==str(entry.get("currency_inventory_key","")) and not bool(material.physical) and int(material.level)==0 and int(material.bless_code)==1 else ""

func _stack_identity_matches(item: Dictionary, material: Dictionary) -> bool:
	if item.get("source","") in ["inven","lineagem_patch523"]: return catalog_identity_matches(item,str(material.source_id),1 if material.physical else int(material.bless_code))
	if str(item.get("sourceId",""))!=str(material.source_id): return false
	var canonical: Dictionary=record(str(material.source_id))
	return item.get("source","")=="twilight_host_binding" and canonical.get("source","")=="twilight_host_binding" and item.get("name")==canonical.get("name") and item.get("host_kind")==canonical.get("host_kind") and item.get("host_amount")==canonical.get("host_amount")

static func recipe_cost(recipe: Dictionary, count: int) -> int:
	var cost: int=int(recipe.adena)*count
	for material: Dictionary in recipe.materials:
		if bool(material.get("wallet",false)) and str(material.source_id)=="26": cost+=int(material.quantity)*count
	return cost

func material_selection(recipe_id: String, choices: Dictionary = {}) -> Dictionary:
	if not recipes.has(recipe_id): return denied("원본 제작법이 없습니다")
	var recipe: Dictionary = recipes[recipe_id].duplicate(true)
	var contract: Dictionary = _source_recipe_contract(recipe)
	if not contract.get("ok",false): return contract
	if not recipe.has("material_slots"):
		var material_contract: Dictionary = _source_material_contract(recipe,contract.source)
		return {"ok":true,"recipe":recipe} if material_contract.get("ok",false) else material_contract
	var selected: Array = []
	var missing: bool = false
	for slot: Dictionary in recipe.material_slots:
		var candidates: Array = slot.candidates
		var chosen: Dictionary = {}
		if candidates.size() == 1:
			chosen = candidates[0]
		else:
			var wanted: int = int(choices.get(str(int(slot.slot_index)), -1))
			for candidate: Dictionary in candidates:
				if int(candidate.row_id) == wanted: chosen = candidate
		if chosen.is_empty():
			missing = true
			continue
		selected.append(chosen)
	recipe["materials"] = selected
	if not missing:
		var material_contract: Dictionary = _source_material_contract(recipe,contract.source)
		if not material_contract.get("ok",false): return material_contract
	return {"ok":not missing,"recipe":recipe,"reason":"각 재료 슬롯의 후보를 직접 선택하세요" if missing else ""}

func quote(recipe_id: String, count: int, inventory: Dictionary, gold: int, items: Dictionary, physical: Dictionary, equipped: Dictionary, current_weight: int, capacity: int, locks: Dictionary = {}, choices: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if not recipes.has(recipe_id) or count < 1 or count > MAX_BATCH or gold < 0 or current_weight < 0 or capacity < 0:
		return denied("원본 제작법·횟수·보관 상태가 유효하지 않습니다")
	if context.has("quest_material_review"):
		var quest_review: Variant=context.quest_material_review
		if not quest_review is Dictionary:return denied("선택 원본 재료 검토 형식 오류")
		if not quest_review.get("ok",false):return denied(str(quest_review.get("reason","선택 원본 재료 확인 필요")))
	var selection: Dictionary = material_selection(recipe_id, choices)
	if not bool(selection.get("ok", false)): return selection
	var recipe: Dictionary = selection.recipe
	var qualification: Dictionary=CONDITIONS.stage(recipe,count,context)
	if not bool(qualification.get("ok",false)): return qualification
	if recipe.has("outcomes") and count!=1: return denied("확률 제작은 결과를 확인하며 1회씩 진행합니다")
	var output: Dictionary = recipe.result
	var result_record: Dictionary = record(str(output.source_id),1 if output.physical else int(output.bless_code))
	if ownership_key(output).is_empty(): return denied("원본 결과 재화의 정확한 보유 키가 필요합니다")
	if result_record.is_empty() or str(result_record.get("name", "")) != str(output.item):
		return denied("원본 결과 아이템의 정확한 ID 연결이 필요합니다")
	var wallet_output: bool = bool(output.get("wallet_currency",false)) and str(output.source_id)=="26" and str(result_record.get("source",""))=="lineagem_patch523" and str(output.item)=="아데나" and not bool(output.physical)
	var current_output: Dictionary = result_record if wallet_output else items.get(str(output.item), {})
	if not wallet_output and not catalog_identity_matches(current_output,str(output.source_id),1 if output.physical else int(output.bless_code)):
		return denied("현재 게임에서 원본 결과 아이템을 사용할 수 없습니다")
	if not output.physical and not wallet_output and _stack_has_owned_entities(output,physical,ownership_key(output)):
		var native_stacks: Script=load("res://scripts/loot/current523_native_stack.gd")
		if not native_stacks.call("can_supply",current_output,inventory,physical):return denied("결과 아이템의 기존 개체/영수증 소유자 확인 필요 · 재료 보존")
	var costs: Dictionary = {}
	var selections: Array[String] = []
	var provenance: Dictionary={}
	var material_rows: Array=[]
	var net_weight: int = current_weight
	var cost: int = recipe_cost(recipe,count)
	if gold < cost:
		return denied("아데나가 부족합니다")
	for material: Dictionary in recipe.materials:
		if bool(material.get("wallet",false)) and str(material.source_id)=="26": continue
		var item_name: String = str(material.item)
		var owned_key: String=ownership_key(material)
		var required: int = int(material.quantity) * count
		var item: Dictionary = items.get(item_name, {})
		if required < 1 or owned_key.is_empty() or bool(locks.get(item_name, false)) or bool(locks.get(owned_key,false)):
			return denied("잠긴 재료 또는 중복 재료는 사용할 수 없습니다")
		if not bool(material.physical):
			var pools: Dictionary={}
			if not _stack_has_owned_entities(material,physical,owned_key) and _stack_identity_matches(item,material):pools[owned_key]={"amount":maxi(0,int(inventory.get(owned_key,0))),"record":item}
			pools.merge(EXPEDITION_MATERIALS.owned(self,material,inventory,physical,locks,context))
			pools.merge(QUEST_MATERIALS.owned(material,context))
			var need: int=required
			var keys: Array=pools.keys();keys.sort()
			# Keep exact native ownership first; the remaining typed key is
			# independently proven, never renamed or promoted into native stock.
			if owned_key in keys:keys.erase(owned_key);keys.push_front(owned_key)
			# Explicit selected quest inputs are spent before automatic canonical
			# or expedition inputs. Their row allocation remains a hard limit.
			var selected_keys: Array=[]
			for key: String in keys:
				if pools[key].get("quest_material",false):selected_keys.append(key)
			for key: String in selected_keys:keys.erase(key)
			keys=selected_keys+keys
			for key: String in keys:
				var take: int=mini(need,maxi(0,int(pools[key].amount)-int(costs.get(key,0))))
				if pools[key].get("quest_material",false):take=mini(take,int(pools[key].row_limit))
				if take<=0:continue
				costs[key]=int(costs.get(key,0))+take
				provenance[key]={"source_id":str(material.source_id),"bless_code":int(material.bless_code),"level":int(material.level),"record":pools[key].record,"expedition":pools[key].has("tuple"),"quest_material":pools[key].get("quest_material",false)}
				material_rows.append({"key":key,"quantity":take,"source_id":str(material.source_id),"material_row_id":int(material.get("row_id",0)),"quest_material":pools[key].get("quest_material",false)})
				net_weight-=maxi(0,int(pools[key].get("carried_weight",pools[key].record.get("weight",3))))*take
				need-=take
				if need==0:break
			if need>0:return denied(item_name+" 재료가 부족하거나 원본 소지/발급 증명이 일치하지 않습니다")
			continue
		if int(inventory.get(owned_key, 0)) < required + int(costs.get(owned_key, 0)):
			return denied(item_name + " 재료가 부족합니다")
		if bool(material.physical):
			var candidates: Array = physical.keys()
			candidates.sort()
			var selected: int = 0
			for raw_id: Variant in candidates:
				var id: String = str(raw_id)
				var instance: Variant = physical[raw_id]
				if not instance is Dictionary or str(instance.get("name", "")) != item_name or id in selections or _worn(equipped, id) or bool(locks.get(item_name + "@@@" + id, false)):
					continue
				if _state_matches(instance, material, int(recipe.get("popup_text_id", 0)) != 0):
					selections.append(id)
					selected += 1
					if selected == required:
						break
			if selected != required:
				return denied("재료의 원본 ID·강화·축복·잠금·장착 상태를 확인하세요: " + item_name)
		elif _stack_has_owned_entities(material,physical,owned_key):
			return denied("원본 보상 개체의 수량·제한·영수증 차감 소유자 연결이 필요합니다: "+item_name)
		elif not _stack_identity_matches(item,material):
			return denied("이름만 같은 재료는 사용할 수 없습니다: " + item_name)
		costs[owned_key] = int(costs.get(owned_key, 0)) + required
		net_weight -= maxi(0, int(item.get("weight", 3))) * required
	var produced: int = int(output.quantity) * count
	var output_weight: int=maxi(0,int(current_output.get("weight",3)))*produced
	for outcome: Dictionary in recipe.get("outcomes",[]):
		if outcome.get("empty_result",false):continue
		if ownership_key(outcome).is_empty(): return denied("확률 결과 재화의 정확한 보유 키가 필요합니다")
		if not outcome.physical and _stack_has_owned_entities(outcome,physical,ownership_key(outcome)):return denied("확률 결과의 기존 개체 소유자 확인 필요 · 재료 보존")
		var candidate: Dictionary=items.get(str(outcome.item),{})
		if not catalog_identity_matches(candidate,str(outcome.source_id),1 if outcome.physical else int(outcome.bless_code)) or record(str(outcome.source_id),1 if outcome.physical else int(outcome.bless_code)).get("name","")!=outcome.item:
			return denied("모든 확률 결과의 정확한 아이템 ID 연결이 필요합니다")
		output_weight=maxi(output_weight,maxi(0,int(candidate.get("weight",3)))*int(outcome.quantity))
	net_weight += output_weight
	if net_weight < 0 or net_weight > capacity:
		return denied("제작 결과를 보관할 무게가 부족합니다")
	qualification.merge({"ok": true, "result_name": str(output.item), "result_quantity": produced, "cost": cost,
		"materials": costs, "material_provenance":provenance, "material_rows":material_rows, "consumed_ids": selections, "new_weight": net_weight},true)
	var quest_problem: String=QUEST_MATERIALS.quote_problem(qualification,context)
	if not quest_problem.is_empty():return denied(quest_problem)
	return qualification

func execute(recipe_id: String, count: int, inventory: Dictionary, gold: int, items: Dictionary, physical: Dictionary, equipped: Dictionary, current_weight: int, capacity: int, next_id: int, locks: Dictionary = {}, choices: Dictionary = {}, roll: int = -1, context: Dictionary = {}) -> Dictionary:
	var approval: Dictionary = quote(recipe_id, count, inventory, gold, items, physical, equipped, current_weight, capacity, locks, choices,context)
	if not bool(approval.get("ok", false)):
		return approval
	var output: Dictionary = recipes[recipe_id].result
	if recipes[recipe_id].has("outcomes"):
		if roll<0 or roll>=1000000: return denied("확률 제작의 유효한 추첨이 필요합니다")
		var threshold: int=0
		for outcome: Dictionary in recipes[recipe_id].outcomes:
			threshold+=int(outcome.probability)
			if roll<threshold:
				output=outcome
				break
		approval.result_name=output.item
		approval.result_quantity=int(output.quantity)
		approval["outcome_label"]=str(output.label)
	var consume_materials: bool=true
	if output.get("twilight_missing_failure",false):
		var policy: Variant=recipes[recipe_id].get("missing_failure_policy")
		if not policy is Dictionary or not policy.get("consume_materials_on_failure") is bool or not policy.get("consume_fee_on_failure") is bool:return denied("누락 실패의 TWILIGHT 소비 정책 확인 필요")
		consume_materials=policy.consume_materials_on_failure
		# Gold used as an ItemCraftInput is material, while recipe.adena is
		# the fee. Independent failure toggles must preserve that distinction.
		var fee: int=int(recipes[recipe_id].adena)*count
		var wallet_materials: int=int(approval.cost)-fee
		approval.cost=(wallet_materials if consume_materials else 0)+(fee if policy.consume_fee_on_failure else 0)
		if not consume_materials:
			approval["quoted_materials"]=approval.materials.duplicate(true)
			approval.materials={}
			approval.consumed_ids=[]
	var staged_inventory: Dictionary = inventory.duplicate(true)
	var staged_physical: Dictionary = physical.duplicate(true)
	for item_name: String in (approval.materials if consume_materials else {}):
		staged_inventory[item_name] = int(staged_inventory.get(item_name, 0)) - int(approval.materials[item_name])
		if int(staged_inventory[item_name]) == 0:
			staged_inventory.erase(item_name)
	for id: String in (approval.consumed_ids if consume_materials else []):
		staged_physical.erase(id)
	var output_record: Dictionary = record(str(output.source_id),1 if output.physical else int(output.bless_code))
	var output_name: String = str(output.item)
	var wallet_reward: int = int(approval.result_quantity) if bool(output.get("wallet_currency",false)) and str(output.source_id)=="26" else 0
	var output_key: String=ownership_key(output)
	var produced: int=int(approval.result_quantity)
	if str(output.get("label",""))=="실패" and not bool(output.physical):
		# A source failure return of a consumed material keeps the exact issued
		# key and its restriction/provenance record; it is not a new native grant.
		for key: String in approval.materials:
			var proof: Dictionary=approval.material_provenance.get(key,{})
			if not proof.get("expedition",false) or proof.get("source_id")!=str(output.source_id) or proof.get("bless_code")!=int(output.bless_code) or proof.get("level")!=int(output.level):continue
			var returned: int=mini(produced,int(approval.materials[key]))
			staged_inventory[key]=int(staged_inventory.get(key,0))+returned
			produced-=returned
			if produced==0:break
	if wallet_reward==0 and not output.get("empty_result",false) and produced>0: staged_inventory[output_key] = int(staged_inventory.get(output_key, 0)) + produced
	var counter: int = maxi(1, next_id)
	if bool(output.physical):
		for _i: int in range(int(approval.result_quantity)):
			var refund_id: String=""
			if str(output.get("label",""))=="실패" and bool(recipes[recipe_id].get("preserve_refund_instance",false)):
				for id: String in approval.consumed_ids:
					if not staged_physical.has(id) and identity(physical[id])==str(output.source_id) and int(physical[id].level)==int(output.level) and bless_code(physical[id])==int(output.bless_code):
						refund_id=id
						break
			if not refund_id.is_empty():
				staged_physical[refund_id]=physical[refund_id].duplicate(true)
				continue
			while staged_physical.has(str(counter)):
				counter += 1
			var pinned: Dictionary = output_record.duplicate(true)
			pinned["bless_state"] = "blessed" if int(output.bless_code) == 2 else "normal"
			if pinned.get("source_m_native_item",false): pinned["source_bless_raw"]=int(output.bless_code)
			var seal_options: Dictionary = supported_seal_options(str(output.source_id), int(output.bless_code))
			if not seal_options.is_empty():
				pinned["enhancement_options"] = seal_options
				pinned["patch523_effect_basis"] = {"sha256":digest, "bless_code":2, "selection":"exact_level_only"}
			pinned=ENHANCEMENT.prepare(self,pinned,int(output.bless_code))
			staged_physical[str(counter)] = {"name": output_name, "level": int(output.level),
				"element": "", "element_level": 0, "sourceId": str(pinned.get("sourceId",output.source_id)),
				"source_snapshot": "patch523", "source_bless_code": int(output.bless_code),
				"bless_state": pinned.bless_state, "record": pinned}
			counter += 1
	# Return a staged transaction. The actual Main persists this snapshot first.
	approval.merge({"inventory": staged_inventory, "item_instances": staged_physical, "selected_output":output.duplicate(true),
		"gold_after": gold - int(approval.cost) + wallet_reward, "next_instance_id": counter})
	return approval

func supported_seal_options(source_id: String, source_bless: int) -> Dictionary:
	# Exact Blessed2 rows only. Raw0 is never remapped to Normal1 here.
	# Existing host consumers keep their stacking, rounding and caps; source
	# values are selected by exact level and blessing, never cumulatively.
	if source_id not in ["30671", "130551"] or source_bless != 2:
		return {}
	var fields: Dictionary = {
		"MeleeHit":["melee_accuracy","hit",1], "RangeHit":["ranged_accuracy","hit",1],
		"MeleeDamage":["melee_damage","meleeDamage",1], "RangeDamage":["ranged_damage","rangedDamage",1],
		"DamageReduction":["reduction","damage_reduction",1],
		"HPPotionIncreaseStatic":["potion_heal_flat","potionHealFlat",1],
		"HPPotionIncreasePercent":["potion_heal_pct","potionHealPct",10000],
		"ExperienceAdditionPercent":["xp_pct","_unused",10000],
		"EinasadSavingPercent":["ain_saving_pct","blessing_consumption_reduction_pct",10000],
		"PotionConsumeDelayDecreasePercent":["potion_cooldown_pct","potionCooldownPct",10000],
		"SpecialResistance":["stun_resistance","stun_resistance",10000]}
	var base: Dictionary = OPTIONS.annotate(record(source_id))
	var result: Dictionary = {}
	for level_value: int in range(9):
		var exact: Array = effect_evidence(int(source_id), level_value, 2)
		if exact.is_empty():
			continue
		var totals: Dictionary = {}
		for effect: Dictionary in exact:
			var bonus: Dictionary = effect.bonus
			var type_name: String = str(effect.bonus_type.get("Name", ""))
			if not fields.has(type_name): continue
			if type_name == "SpecialResistance":
				if int(bonus.get("BonusApplicationTypeID", -1)) != 2 or int(bonus.get("BonusApplicationTargetID", -1)) != 6: continue
			elif int(bonus.get("BonusApplicationTypeID", -1)) != 0 or int(bonus.get("BonusApplicationTargetID", -1)) != 0: continue
			var definition: Array = fields[type_name]
			if int(bonus.Value) % int(definition[2]) != 0:
				continue
			var key: String = str(definition[0])
			totals[key] = int(totals.get(key, 0)) + int(float(bonus.Value) / float(definition[2]))
		for definition: Array in fields.values():
			var key: String = str(definition[0])
			if totals.has(key):
				# The existing engine adds enchant increments to its catalog +0
				# base, so subtract that actual base once, never lower ranks.
				totals[key] = int(totals[key]) - int(base.get(str(definition[1]), 0))
		if totals.has("xp_pct"): totals.xp_pct = int(totals.xp_pct) - int(round(float(base.get("xp",0.0))*100.0))
		result[str(level_value)] = totals
	return result

func refresh_derived_options(physical: Dictionary) -> bool:
	var source_id: String = identity(physical)
	var current_record: Dictionary=physical.get("record",{})
	var prepared: Dictionary=ENHANCEMENT.prepare(self,current_record,bless_code(physical))
	if prepared!=current_record:
		physical["record"]=prepared
		return true
	if source_id.is_empty() or bless_code(physical) != 2: return false
	var pinned: Dictionary = physical.get("record", {})
	if pinned.get("patch523_effect_basis", {}).get("selection", "") != "exact_level_only": return false
	var current: Variant = pinned.get("enhancement_options", {})
	var complete: Dictionary = supported_seal_options(source_id, 2)
	if not current is Dictionary or current.is_empty() or complete.is_empty(): return false
	# Add newly connected consumers only when every old derived value agrees.
	# Unknown/custom options are never replaced by a catalog refresh.
	for level_key: Variant in current:
		if not current[level_key] is Dictionary or not complete.has(level_key): return false
		for key: Variant in current[level_key]:
			if current[level_key][key] != complete[level_key].get(key): return false
	pinned["enhancement_options"] = complete.duplicate(true)
	pinned["patch523_effect_basis"] = {"sha256":digest,"bless_code":2,"selection":"exact_level_only"}
	return true


func effect_evidence(item_id: int, level: int, raw_bless_code: int) -> Array:
	var result: Array = []
	for row: Dictionary in item_entry(str(item_id)).get("enchant_effects", []):
		if int(row.EnchantLevel) == level and int(row.BlessCode) == raw_bless_code:
			var bonus: Dictionary = bonus_row(str(int(row.BonusID)))
			result.append({"row": row.duplicate(true), "bonus": bonus.duplicate(true),
				"bonus_type": bonus_type(str(int(bonus.get("BonusTypeID", -1)))).duplicate(true)})
	return result

func enhancement_evidence(item_id: int, scroll_id: int, level: int, target_bless: int, scroll_bless: int) -> Dictionary:
	var equip_groups: Array = []
	var scroll_groups: Array = []
	for link: Dictionary in item_entry(str(item_id)).get("item_bonuses", []):
		var bonus: Dictionary = bonus_row(str(int(link.BonusID)))
		if int(bonus.get("BonusTypeID", -1)) == 2032:
			equip_groups.append(int(bonus.Value))
	for link: Dictionary in item_entry(str(scroll_id)).get("item_bonuses", []):
		var bonus: Dictionary = bonus_row(str(int(link.BonusID)))
		var kind: int = int(bonus.get("BonusTypeID", -1))
		if kind == 2022 or (kind == 8352 and int(bonus.get("BonusApplicationTypeID", 0)) == 202 and int(bonus.get("BonusApplicationTargetID", -1)) == scroll_bless):
			scroll_groups.append(int(bonus.Value))
	var equip_probabilities: Array = []
	var matched: Array = []
	for row: Dictionary in data.get("enchantment", {}).get("ItemEnchantEquipGroupMapping", []):
		if int(row.ItemEnchantEquipGroupID) in equip_groups:
			equip_probabilities.append(int(row.ItemEnchantProbabilityGroupID))
	for row: Dictionary in data.get("enchantment", {}).get("ItemEnchantScrollGroupMapping", []):
		var group: int = int(row.ItemEnchantProbabilityGroupID)
		if int(row.ItemEnchantScrollGroupID) in scroll_groups and group in equip_probabilities and group not in matched:
			matched.append(group)
	var result: Dictionary = {"groups": matched, "probabilities": [], "costs": [], "unresolved": ["current_or_result_level_contract", "target_bless_zero_matching", "cost_currency", "zero_consume_amount", "side_effect_amount", "blessed_leap_activation"]}
	for table: String in ["BmItemEnchantProView", "ItemEnchantCostView"]:
		for row: Dictionary in data.get("enchantment", {}).get(table, []):
			# Preserve 0 rows separately; never silently equate 0 with Normal1.
			if int(row.ItemEnchantProbabilityGroupID) in matched and int(row.EnchantLevel) == level and int(row.TargetItemBlessCode) in [0, target_bless]:
				(result["probabilities" if table == "BmItemEnchantProView" else "costs"] as Array).append(row.duplicate(true))
	return result
