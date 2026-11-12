extends SceneTree
## Real TemplateStore format fixtures: optional binding expansion must match
## the old full() bytes/order/copies and retain every generic/cache fallback.
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const NATIVE = preload("res://scripts/loot/current523_native_item_projection.gd")
const CURRENT = preload("res://scripts/crafting/patch523_rules_projection.gd")
const OLD = preload("res://tests/fixtures/rules_cold_legacy/legacy_projection.gd")
var checks: int = 0
var failures: Array[String] = []
class OverrideStore extends NATIVE.TemplateStore:
	var record_calls: int = 0
	func record(_id: String) -> Variant:
		record_calls += 1
		return {"name":"override provider","source_item_class_id":7,"source_class_ids":[99]}
class Generic extends RefCounted:
	var records: Dictionary = {}
	var calls: int = 0
	func record(id: String) -> Variant:
		calls += 1
		return records.get(id)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and var_to_bytes(a) == var_to_bytes(b)
func put(file: FileAccess, offsets: Dictionary, id: String, light: Variant, heavy: Variant) -> void:
	offsets[id] = file.get_position()
	file.store_var(light); file.store_var(heavy)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var path: String = "user://equipment-binding-fusion-fixture.bin"
	var output := FileAccess.open(path,FileAccess.WRITE)
	var offsets: Dictionary = {}
	var light: Dictionary = {"name":"light name","source_item_class_id":7,"source_use_spec":{"from":"light","nested":[1,2]}}
	var heavy: Dictionary = {"keys":["name","source_use_spec","source_class_ids","not_heavy","source_item_class_id"],
		"fields":{"source_use_spec":{"from":"heavy"},"source_class_ids":[1,2],"not_heavy":"must not leak"}}
	put(output,offsets,"7",light,heavy)
	put(output,offsets,"8",{}, {"keys":[],"fields":{}})
	put(output,offsets,"9",{"unused_nonheavy":1}, {"keys":["unused_nonheavy"],"fields":{}})
	put(output,offsets,"10",{FIELDS.MARK:false,"source_item_class_id":10}, {"keys":[FIELDS.MARK,"source_use_spec","source_item_class_id"],"fields":{"source_use_spec":{"v":[1]}}})
	put(output,offsets,"11",{"name":"duplicate"}, {"keys":["name","source_class_ids","name","source_class_ids"],"fields":{"source_class_ids":[6]}})
	put(output,offsets,"12","malformed light", {"keys":[],"fields":{}})
	put(output,offsets,"13",{}, {"keys":"malformed keys","fields":{}})
	put(output,offsets,"14",{}, {"keys":[],"fields":"malformed fields"})
	for id: int in range(100,240):
		put(output,offsets,str(id),{"name":"item"+str(id),"source_item_class_id":id}, {"keys":["name","source_class_ids","source_item_class_id"],"fields":{"source_class_ids":[id]}})
	output.close()
	var store := NATIVE.TemplateStore.new()
	store.file = FileAccess.open(path,FileAccess.READ)
	store.offsets = offsets
	store.interning = false
	check(store.get_script().get_base_script() == null, "actual nested builtin-based TemplateStore is eligible")
	var own: Dictionary = {FIELDS.MARK:true,"source_item_class_id":7,"name":"own name","own_extra":{"v":[3]}}
	var edited: Dictionary = own.duplicate(true)
	edited.source_class_ids = [99]
	var cases: Array[Dictionary] = [own,edited]
	for id: int in [8,9,10,11,12,13,14,404]: cases.append({FIELDS.MARK:true,"source_item_class_id":id,"name":"own"+str(id),"extra":id})
	for record: Dictionary in cases:
		FIELDS.bind(store)
		var before: Dictionary = FIELDS.full(record)
		FIELDS.bind(store)
		var after: Dictionary = FIELDS._full_for_binding(record)
		check(same(before,after), "exact full bytes for "+str(record.source_item_class_id))
		if int(record.source_item_class_id) in [7,10,11]:
			check(not FIELDS._cache.has(str(record.source_item_class_id)), "real uncached template fused without a duplicate template dictionary "+str(record.source_item_class_id))
		else:
			check(FIELDS._cache.has(str(record.source_item_class_id)), "unusable template retains generic record read/cache "+str(record.source_item_class_id))
		check(not after.has("not_heavy"), "absent nonheavy fields remain absent")
	FIELDS.bind(store)
	var full: Dictionary = FIELDS._full_for_binding(own)
	check(full.keys() == ["name","source_use_spec","source_class_ids","source_item_class_id","own_extra"], "template key order then own extras")
	check(full.source_use_spec.from == "light", "light value wins over duplicate heavy value")
	(full.source_class_ids as Array).append(77)
	check(store.record("7").source_class_ids == [1,2], "heavy returned values remain isolated")
	(full.own_extra.v as Array).append(8)
	check(own.own_extra.v == [3,8], "own override references remain shared as historical full")
	own.own_extra.v.pop_back()
	# Existing cache entries, including an empty miss, are authoritative.
	FIELDS.bind(store)
	var cached: Dictionary = FIELDS.full(own)
	var saved_file: FileAccess = store.file
	store.file = null
	check(same(FIELDS._full_for_binding(own),cached), "existing cached template is never bypassed")
	store.file = saved_file
	var missing: Dictionary = {FIELDS.MARK:true,"source_item_class_id":404,"name":"missing"}
	var cached_missing: Dictionary = FIELDS.full(missing)
	store.offsets["404"] = offsets["7"]
	store.file = null
	check(same(FIELDS._full_for_binding(missing),cached_missing), "cached empty miss retains snapshot semantics")
	store.file = saved_file
	store.offsets.erase("404")
	# Public full, normal records and generic/mock stores remain unchanged.
	FIELDS.bind(store)
	store.file = null
	var ordinary: Dictionary = {FIELDS.MARK:false,"source_item_class_id":7,"name":"plain"}
	check(FIELDS._full_for_binding(ordinary) == ordinary, "marker false remains ordinary")
	check(FIELDS._full_for_binding(null) == null and FIELDS._full_for_binding([1,2]) == [1,2], "non-record values remain unchanged")
	store.file = saved_file
	var generic := Generic.new(); generic.records["7"] = store.record("7")
	FIELDS.bind(generic)
	check(same(FIELDS._full_for_binding(own),FIELDS.full(own)) and generic.calls == 1, "generic store stays on original full cache path")
	FIELDS.bind(null)
	check(not FIELDS._full_for_binding(own).has(FIELDS.MARK), "unbound store retains orphan behavior")
	var subclass := OverrideStore.new()
	subclass.interning = false; subclass.file = store.file; subclass.offsets = offsets
	check(subclass.get_script().get_base_script() != null, "record override subclass is ineligible")
	FIELDS.bind(subclass)
	check(FIELDS._full_for_binding(own).source_class_ids == [99] and subclass.record_calls == 1, "inherited optimization never bypasses subclass record override")
	# Interning has observable pool side effects and uses the old reader.
	store.interning = true; store.strings.clear()
	FIELDS.bind(store)
	var interned: Dictionary = FIELDS._full_for_binding(own)
	check(FIELDS._cache.has("7") and not store.strings.is_empty(), "interning keeps original record/string pooling")
	FIELDS.bind(store)
	check(same(interned,FIELDS.full(own)), "interning values/order unchanged")
	store.interning = false
	# The public 128-entry cache remains bounded and existing hot IDs win.
	FIELDS.bind(store)
	for id: int in range(100,240): FIELDS.full({FIELDS.MARK:true,"source_item_class_id":id,"name":"item"+str(id)})
	check(FIELDS._cache.size() == FIELDS.CACHE_LIMIT and not FIELDS._cache.has("100") and FIELDS._cache.has("239"), "public full cache eviction contract retained")
	store.file = null
	check(FIELDS._full_for_binding({FIELDS.MARK:true,"source_item_class_id":239,"name":"item239"}).source_class_ids == [239], "cached ID after boundary stays on cache")
	store.file = saved_file
	check(FIELDS._full_for_binding({FIELDS.MARK:true,"source_item_class_id":100,"name":"item100"}).source_class_ids == [100] and not FIELDS._cache.has("100"), "evicted valid ID can use bounded fusion")
	check(FIELDS._cache.size() <= FIELDS.CACHE_LIMIT, "fusion introduces no unbounded field cache")
	# Exact whole binding JSON identity and parsed/packed results.
	var items: Array = [own,edited,{FIELDS.MARK:true,"source_item_class_id":10,"name":"mark"},ordinary,{},null,[1,2]]
	var contract: Dictionary = {"fixture_only":true,"values":[1,2]}
	for parse: bool in [false,true]:
		FIELDS.bind(store)
		var before: Dictionary = OLD.binding_document(items,contract,parse)
		FIELDS.bind(store)
		var after: Dictionary = CURRENT.binding_document(items,contract,parse,false)
		check(before.sha256 == after.sha256 and before.bytes == after.bytes and same(before.binding,after.binding), "full JSON SHA/bytes and parsed binding parse="+str(parse))
		FIELDS.bind(store)
		var packed: Dictionary = CURRENT.binding_document(items,contract,parse,true)
		check(before.sha256 == packed.sha256 and before.bytes == packed.bytes, "packed full identity parse="+str(parse))
		if parse:
			for i: int in items.size(): check(same(before.binding["아이템"][i],packed.binding["아이템"].fetch(i)), "packed values isolate and match "+str(i))
			(packed.binding["아이템"].fetch(0).source_class_ids as Array).append(88)
			check(FIELDS.field(own,"source_class_ids") == [1,2], "parsed binding cannot mutate template")
	FIELDS.bind(null)
	store.file.close()
	DirAccess.remove_absolute(path)
	print("EQUIPMENT_BINDING_FUSION_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"scope":"synthetic_actual_template_format_json_cache_alias_fallback"}))
	quit(0 if failures.is_empty() else 1)
