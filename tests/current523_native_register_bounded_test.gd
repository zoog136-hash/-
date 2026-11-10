extends SceneTree
## Bounded cold registration of native item records (handoff P0 "아이템은
## 완성된 full 레코드를 누적하지 않는다"). Synthetic ItemClass rows and a
## synthetic owner; needs no private original. Run with a disposable profile:
##   XDG_DATA_HOME=<tmp> godot --headless --path <repo> --script res://tests/current523_native_register_bounded_test.gd
## (1) register() output (result, catalog records, their FIELDS.full() view,
##     contract, document and the template bake bytes) is identical to the
##     former implementation (frozen below from bfe966b5f) on cold, warm and
##     eager runs; (2) a cold run keeps at most one full record alive (its
##     transient peak does not grow with the item count as the former one
##     did); (3) writer create/write/finish/commit/reopen failures are a safe
##     stop: explicit result, catalog/document unchanged, no part/bake file,
##     no further describing after the failure, no repeated pass in the same
##     process, and a later retry succeeds with the identical output.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const ROWS := 60
var checks: int = 0
var failures: Array[String] = []
var stats: Dictionary = {}
var owner: GDScript

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void: call_deferred("run")

class Inputs extends P.RegisterInputs:
	var rows: Array = []
	func identity() -> Dictionary: return {"kind":"zz.synthetic.definitions","source_sha256":"00","source_bytes":1}
	func verified_key() -> String: return "zz-synthetic:1"
	func row_count(table: String) -> int: return rows.size() if table == "ItemClass" else 0
	func row_at(table: String, index: int) -> Dictionary: return (rows[index] as Dictionary).duplicate(true) if table == "ItemClass" else {}
	func declared_exclusion(_table: String, row: Dictionary) -> Dictionary: return {"excluded":true} if row.get("ID") == 13.0 else {}

const OWNER_SOURCE := """extends RefCounted
static var cached_ids: Dictionary = {}
static var cached_defs: Dictionary = {}
static var identity: Dictionary = {}
static var calls: int = 0
static var heavy_chars: int = 0
static var peak: int = 0
static func has_definition(id: String) -> bool: return cached_ids.has(id)
static func transient_definition(id: String) -> Dictionary:
	calls += 1
	peak = maxi(peak, OS.get_static_memory_usage())
	return {"native_record": make(id), "detail": {"blob": make_blob(id)}}
static func definition_id(id: String) -> Dictionary:
	calls += 1
	peak = maxi(peak, OS.get_static_memory_usage())
	if not cached_defs.has(id): cached_defs[id] = {"native_record": make(id)}
	return cached_defs[id]
static func data() -> Dictionary: return {}
static func make_blob(id: String) -> String:
	return id.rpad(heavy_chars, "#") if heavy_chars > 0 else ""
static func make(id: String) -> Dictionary:
	var n: int = int(id)
	if n % 7 == 0: return {}
	var out: Dictionary = {"name":"아이템"+id+" · 원본#"+id,"source_display_name":"아이템"+id,"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":n,"sourceId":"m523:item:"+id,"sourceUrl":"","source_m_native_item":true,"source_bless_raw":1,"grade":"일반","source_grade_id":1,"slot":"material" if n % 2 else "weapon"}
	out["source_original_item"] = {"ID":float(n),"Name":"원본 \\"이름\\" "+id,"blob":make_blob(id),"Nested":[1.0,{"k":[true,null]}]}
	out["source_class_ids"] = [1, 2, n]
	out["source_weight"] = 1.5 * n
	out["source_use_spec"] = {"kind":"current_source_effect_pending","activation_status":"blocked","blocked_reasons":["r"+id]}
	out["source_sprite_id"] = n * 10
	out["source_effect_status"] = "partial"
	out["source_definition_archive"] = identity
	out["def"] = n % 5
	return out
"""

func clean() -> void:
	BAKE.clear(P.TEMPLATE_BAKE)
	DirAccess.remove_absolute(BAKE.data_path(P.TEMPLATE_BAKE) + ".part")
	FIELDS.bind(null)
	P.clear_template_failure()
	P.template_fault = ""
	owner.cached_defs.clear()
	owner.calls = 0

func input_catalog(inputs: Inputs) -> Dictionary:
	var identity: Dictionary = inputs.identity()
	var lazy_prior: Dictionary = FIELDS.slim(owner.make("8"))
	return {"아이템":[
		{"name":"로컬","sourceId":"local:1"},
		owner.make("2"),
		{"name":"다른 이름","sourceId":"m523:item:3","source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":3,"source_m_native_item":true},
		{"name":"a","sourceId":"m523:item:4"}, {"name":"b","sourceId":"m523:item:4"},
		{"sourceId":"m523:item:6","source_current523_awakening_supply":true,"source_item":inputs.rows[6],"source_definition_archive":identity},
		lazy_prior,
		"not a record",
	]}

## Every value register() produces or leaves behind, as bytes.
func snapshot(result: Dictionary, catalog: Dictionary, document: Dictionary) -> PackedByteArray:
	var full: Array = []
	for record: Variant in catalog.get("아이템", []): full.append(FIELDS.full(record))
	var template_sha: String = FileAccess.get_sha256(BAKE.data_path(P.TEMPLATE_BAKE)) if FileAccess.file_exists(BAKE.data_path(P.TEMPLATE_BAKE)) else ""
	return var_to_bytes([result, catalog, full, document, template_sha])

func run_path(inputs: Inputs, old: bool) -> PackedByteArray:
	var catalog: Dictionary = input_catalog(inputs)
	var document: Dictionary = {}
	var result: Dictionary = old_register(inputs, owner, catalog, document) if old else P.register(owner, catalog, document)
	return snapshot(result, catalog, document)

func run() -> void:
	if FileAccess.file_exists("user://current523_bake/" + P.TEMPLATE_BAKE + ".json") or FileAccess.file_exists("user://current523_bake/" + P.TEMPLATE_BAKE + ".bin"):
		check(false, "refusing to replace an existing template bake: run with a disposable XDG_DATA_HOME")
		finish()
		return
	owner = GDScript.new()
	owner.source_code = OWNER_SOURCE
	check(owner.reload() == OK, "synthetic owner compiles")
	var inputs := Inputs.new()
	for index: int in ROWS:
		var row: Dictionary = {"ID": float(index), "TestItem": index == 11, "Name": "행" + str(index)}
		if index == 17: row.erase("TestItem")
		inputs.rows.append(row)
	owner.identity = inputs.identity()
	for id: String in ["5", "10", "2", "20"]: owner.cached_ids[id] = true
	P.register_inputs = inputs
	# (1) identical output, cold then warm, former vs current implementation.
	clean()
	var old_cold: PackedByteArray = run_path(inputs, true)
	var old_warm: PackedByteArray = run_path(inputs, true)
	clean()
	var new_cold: PackedByteArray = run_path(inputs, false)
	var calls_cold: int = owner.calls
	var new_warm: PackedByteArray = run_path(inputs, false)
	check(new_cold == old_cold, "cold registration output identical to the former path")
	check(new_warm == old_warm, "warm registration output identical to the former path")
	check(owner.calls == calls_cold, "warm run reads templates, describes nothing")
	var catalog: Dictionary = input_catalog(inputs)
	clean()
	var document: Dictionary = {}
	var result: Dictionary = P.register(owner, catalog, document)
	var by_source: Dictionary = {}
	for record: Variant in catalog["아이템"]:
		if record is Dictionary: by_source[str(record.get("sourceId", ""))] = record
	var light_ok: bool = result.ok and int(result.registered_count) > 0
	for id: String in document.get("native_item_ids", []):
		if id == "6": continue # typed supply record is kept as supplied
		var record: Variant = by_source.get("m523:item:" + id)
		if not FIELDS.lazy(record): light_ok = false; continue
		for key: String in FIELDS.HEAVY:
			if (record as Dictionary).has(key): light_ok = false
	check(light_ok, "every registered cold record is published light")
	# Eager comparison mode (full records resident by request) is unchanged.
	OS.set_environment("TWILIGHT_NATIVE_FIELDS_EAGER", "1")
	clean()
	var old_eager: PackedByteArray = run_path(inputs, true)
	clean()
	var new_eager: PackedByteArray = run_path(inputs, false)
	check(new_eager == old_eager, "eager registration output identical to the former path")
	OS.unset_environment("TWILIGHT_NATIVE_FIELDS_EAGER")
	# (3) failure injection.
	var expected_stage: Dictionary = {"create":"create","write:3":"write","finish":"finish","commit":"commit","reopen":"reopen"}
	for fault: String in expected_stage:
		clean()
		var before: Dictionary = input_catalog(inputs)
		var catalog_bytes: PackedByteArray = var_to_bytes(before)
		var kept: Dictionary = {"native_item_ids":["kept"]}
		P.template_fault = fault
		var failed: Dictionary = P.register(owner, before, kept)
		check(failed.get("ok") == false and failed.get("reason") == "native_item_template_store_failed" and failed.get("stage") == expected_stage[fault], "explicit failure result: " + fault)
		check(failed.get("ownership_changed") == false and str(failed.get("message", "")).contains("다시 시작"), "failure keeps ownership and names the retry: " + fault)
		check(var_to_bytes(before) == catalog_bytes and kept == {"native_item_ids":["kept"]}, "catalog and document unchanged: " + fault)
		check(not FileAccess.file_exists(BAKE.data_path(P.TEMPLATE_BAKE) + ".part") and BAKE.verified_file(P.TEMPLATE_BAKE, P._template_key()).is_empty(), "no part or committed template left: " + fault)
		if fault == "create": check(owner.calls == 0, "nothing is described when the writer cannot be created")
		if fault == "write:3": check(owner.calls == 3, "describing stops at the failed write (no full record retained past it)")
		var calls: int = owner.calls
		var again: Dictionary = P.register(owner, before, kept)
		check(again.get("ok") == false and again.get("stage") == expected_stage[fault] and owner.calls == calls, "same failure is not re-run in this process: " + fault)
		check(P.template_problem().contains("다시 시작"), "problem stays readable: " + fault)
		# Retry (next start): the identical output.
		P.template_fault = ""
		P.clear_template_failure()
		FIELDS.bind(null)
		owner.cached_defs.clear()
		check(run_path(inputs, false) == old_cold, "retry after the failure gives the identical output: " + fault)
	# (2) bounded transient memory: unique heavy payloads (~160 KB each).
	owner.heavy_chars = 40000
	var heavy: Inputs = Inputs.new()
	for index: int in 300: heavy.rows.append({"ID": float(index + 1000), "TestItem": false})
	P.register_inputs = heavy
	var peaks: Dictionary = {}
	for old: bool in [false, true]:
		clean()
		var heavy_catalog: Dictionary = {"아이템":[]}
		var base: int = OS.get_static_memory_usage()
		owner.peak = base
		var heavy_result: Dictionary = old_register(heavy, owner, heavy_catalog, {}) if old else P.register(owner, heavy_catalog, {})
		check(heavy_result.get("ok") == true, "heavy registration ok (old=%s)" % old)
		peaks["old" if old else "new"] = owner.peak - base
		heavy_catalog = {}
		FIELDS.bind(null)
	stats = {"payload_bytes": 300 * 40000 * 4, "new_transient_peak": peaks.get("new"), "old_transient_peak": peaks.get("old")}
	check(int(peaks.new) * 4 < int(peaks.old), "cold transient peak no longer grows with the item count")
	owner.heavy_chars = 0
	P.register_inputs = null
	clean()
	finish()

func finish() -> void:
	print("CURRENT523_NATIVE_REGISTER_BOUNDED_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"stats":stats}))
	quit(0 if failures.is_empty() else 1)

# ---------------------------------------------------------------------------
# Former implementation (bfe966b5f register() and TemplateWriter), frozen as
# the reference. Only the original reads go through `inputs` (SOURCE there).
class OldWriter extends RefCounted:
	var file: FileAccess
	var ids: PackedStringArray=[]
	var positions: PackedInt64Array=[]
	static func start() -> OldWriter:
		var path: String=BAKE.data_path(P.TEMPLATE_BAKE)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var writer:=OldWriter.new()
		writer.file=FileAccess.open(path+".part",FileAccess.WRITE)
		return writer if writer.file!=null else null
	func add(id: String,record: Dictionary) -> void:
		var light: Dictionary={};var fields: Dictionary={}
		for key: Variant in record:
			if key in FIELDS.HEAVY:fields[key]=record[key]
			else:light[key]=record[key]
		ids.append(id);positions.append(file.get_position())
		file.store_var(light);file.store_var({"keys":record.keys(),"fields":fields})
	func finish(value_key: String) -> void:
		var index_position: int=file.get_position()
		file.store_var({"schema":P.TEMPLATE_SCHEMA,"ids":ids,"offsets":positions})
		file.store_64(index_position)
		var stored: bool=file.get_error()==OK
		file.close()
		var part: String=BAKE.data_path(P.TEMPLATE_BAKE)+".part"
		if not stored or not BAKE.commit_file(P.TEMPLATE_BAKE,value_key,part):DirAccess.remove_absolute(part)

static func old_register(inputs: Inputs,own: Script,catalog: Dictionary,document: Dictionary) -> Dictionary:
	if inputs.identity().is_empty() or not catalog.get("아이템",[]) is Array:return {"ok":false,"reason":"current_original_catalog_input_unavailable"}
	var contract: Variant=catalog.get("patch523_crafting_catalog_contract",{})
	if contract is Dictionary and contract.get("mode")=="current_original_native_projection" and contract.get("source_definition_archive")==inputs.identity() and document.get("native_item_ids")==contract.get("registered_definition_ids") and document.get("current_registration_pending")==contract.get("pending"):
		var registered: int=0
		for record: Variant in catalog.get("아이템",[]):
			if record is Dictionary and record.get("source_m_native_item")==true and record.get("source_definition_archive")==inputs.identity():registered+=1
		if registered>=int(document.get("current_native_registered_count",-1)):
			return {"ok":true,"registered_count":int(document.current_native_registered_count),"pending":contract.pending.duplicate(),"source_definition_archive":inputs.identity(),"ownership_changed":false,"executed_gameplay":false,"reused_registration":true}
	var records: Array=catalog.get("아이템",[]).duplicate(false);var positions: Dictionary={};var pending: Dictionary={};var admitted: Array=[]
	for index: int in range(records.size()):
		if not records[index] is Dictionary:continue
		var key: String=str(records[index].get("sourceId",""))
		if not positions.has(key):positions[key]=[]
		positions[key].append(index)
	var indexed: bool=own.has_method("has_definition") and own.has_method("transient_definition")
	var cache: Dictionary=own.call("data") if not indexed else {}
	var references: Dictionary=cache.get("source_item_references",{})
	var definitions: Dictionary=cache.get("item_definitions",{})
	var templates=P._open_templates()
	var lazy: bool=OS.get_environment("TWILIGHT_NATIVE_FIELDS_EAGER")!="1"
	var placed: Array[int]=[]
	var writer: OldWriter=null if templates!=null else OldWriter.start()
	if templates!=null and lazy:FIELDS.bind(templates)
	for row_index: int in inputs.row_count("ItemClass"):
		var raw: Dictionary=inputs.row_at("ItemClass",row_index)
		if not P.integer(raw.get("ID")) or int(raw.ID)<=0 or raw.get("TestItem")!=false or not inputs.declared_exclusion("ItemClass",raw).is_empty():continue
		var id: String=str(int(raw.ID));var cached: bool=bool(own.call("has_definition",id)) if indexed else (references.has(id) or definitions.has(id))
		var current: Dictionary={}
		var baked: Variant=(templates.light(id) if lazy else templates.record(id)) if templates!=null else null
		if baked is Dictionary:
			current=baked
			if current.get("source_definition_archive")==P._archive_identity():current["source_definition_archive"]=P._archive_identity()
		else:
			var definition: Dictionary=own.call("definition_id",id) if cached or not indexed else own.call("transient_definition",id)
			current=definition.get("native_record",{})
			if not cached and not indexed:
				references.erase(id);definitions.erase(id)
			if writer!=null:writer.add(id,current)
		if current.is_empty():pending[id]="current_native_dto_unavailable";continue
		var key: String=str(current.sourceId);var previous: Array=positions.get(key,[])
		if previous.size()>1:pending[id]="ambiguous_registered_source_identity";continue
		if previous.size()==1:
			var saved: Dictionary=records[int(previous[0])]
			var typed_supply: bool=saved.get("source_current523_awakening_supply")==true and saved.get("source_item")==raw and saved.get("source_definition_archive")==inputs.identity()
			if typed_supply:admitted.append(id);continue
			if saved.get("source")!="lineagem_patch523" or saved.get("source_snapshot")!="patch523" or saved.get("source_item_class_id")!=raw.ID or saved.get("source_m_native_item")!=true or saved.get("name")!=current.name or FIELDS.field(saved,"source_display_name")!=FIELDS.field(current,"source_display_name"):
				pending[id]="unverified_registered_source_identity_preserved";continue
			records[int(previous[0])]=current.duplicate(true) if cached else current
			placed.append(int(previous[0]))
		else:
			records.append(current.duplicate(true) if cached else current);positions[key]=[records.size()-1]
			placed.append(records.size()-1)
		admitted.append(id)
	if writer!=null:writer.finish(P._template_key())
	var store=templates if templates!=null else P._open_templates()
	if store!=null:
		store.interning=false
		store.strings.clear()
	if store!=null and lazy:
		FIELDS.bind(store)
		for index: int in placed:
			if not FIELDS.lazy(records[index]):records[index]=FIELDS.slim(records[index])
	catalog["아이템"]=records
	catalog["patch523_crafting_catalog_contract"]={"mode":"current_original_native_projection","source_definition_archive":inputs.identity(),"registered_definition_ids":admitted.duplicate(),"normal_ids":admitted.size(),"pending":pending.duplicate(),"full_native_coverage_observed":false}
	document["native_item_ids"]=admitted.duplicate();document["current_registration_pending"]=pending.duplicate();document["current_native_registered_count"]=admitted.size()
	return {"ok":true,"registered_count":admitted.size(),"pending":pending,"source_definition_archive":inputs.identity(),"ownership_changed":false,"executed_gameplay":false}
