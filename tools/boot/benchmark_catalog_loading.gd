extends SceneTree
## Targeted real-source producers. Always use a fresh isolated XDG profile.
## No player nodes, gameplay, saves, media generation or external writes.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const RULES = preload("res://scripts/crafting/patch523_rules.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const DERIVED: Array[String] = ["native_item_templates","equipment_rules","equipment_rules_catalog_records","equipment_rules_runtime","equipment_rules_cold"]
var failures: Array[String] = []
var measurements: Dictionary = {}

class TimedInputs extends P.RegisterInputs:
	var usec: Dictionary = {}
	var calls: Dictionary = {}
	func _note(name: String, start: int) -> void:
		usec[name] = int(usec.get(name,0)) + Time.get_ticks_usec()-start
		calls[name] = int(calls.get(name,0)) + 1
	func identity() -> Dictionary: return SOURCE.identity()
	func verified_key() -> String: return SOURCE.verified_key()
	func row_count(table: String) -> int:
		var start: int = Time.get_ticks_usec(); var result: int = SOURCE.row_count(table)
		_note("row_count",start); return result
	func row_at(table: String,index: int) -> Dictionary:
		var start: int = Time.get_ticks_usec(); var result: Dictionary = SOURCE.row_at(table,index)
		_note("row_at",start); return result
	func declared_exclusion(table: String,row: Dictionary) -> Dictionary:
		var start: int = Time.get_ticks_usec(); var result: Dictionary = SOURCE.declared_exclusion(table,row)
		_note("declared_exclusion",start); return result

class TimedOwner extends RefCounted:
	static var usec: Dictionary = {}
	static var calls: Dictionary = {}
	static func reset() -> void: usec.clear(); calls.clear()
	static func _note(name: String,start: int) -> void:
		usec[name] = int(usec.get(name,0)) + Time.get_ticks_usec()-start
		calls[name] = int(calls.get(name,0)) + 1
	static func data() -> Dictionary: return DROPS.data()
	static func has_definition(id: String) -> bool:
		var start: int = Time.get_ticks_usec();var result: bool = DROPS.has_definition(id)
		_note("has_definition",start); return result
	static func transient_definition(id: String) -> Dictionary:
		var start: int = Time.get_ticks_usec();var result: Dictionary = DROPS.transient_definition(id)
		_note("transient_definition",start); return result
	static func definition_id(id: String) -> Dictionary:
		var start: int = Time.get_ticks_usec();var result: Dictionary = DROPS.definition_id(id)
		_note("definition_id",start); return result

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func _files() -> Dictionary:
	var result: Dictionary = {}
	for name: String in DERIVED:
		var path: String = BAKE.data_path(name)
		if FileAccess.file_exists(path): result[name] = {"bytes":FileAccess.get_size(path),"sha256":FileAccess.get_sha256(path)}
	return result
func _catalog_signature(catalog: Dictionary,document: Dictionary) -> String:
	return _sha(var_to_bytes([catalog.get("아이템",[]),catalog.get("patch523_crafting_catalog_contract",{}),document]))
func _arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""
func _write() -> void:
	var out: String = _arg("--catalog-benchmark-json=")
	var report: Dictionary = {"failures":failures,"measurements":measurements,"engine":Engine.get_version_info().string,"phase":_arg("--catalog-benchmark-phase=") if not _arg("--catalog-benchmark-phase=").is_empty() else "both","profile":OS.get_user_data_dir(),"source":SOURCE.identity(),"source_problem":SOURCE.problem(),"scope":"real original definitions; targeted producers, no Main/map/media/Android", "warm_condition":"second producer call in same process, fresh catalog/model object, existing verified derived bakes and reader caches", "preload_caveat":"raw-table conversion may occur during Script preloads before timed producer calls; subprocess wall and BOOT_PROGRESS stages cover that work", "timing_overhead":"forward-only clock/counter wrappers around outer row access and owner methods; same harness in both arms"}
	if not out.is_empty():
		var file := FileAccess.open(out,FileAccess.WRITE)
		if file != null:file.store_string(JSON.stringify(report,"\t",true));file.close()
	print("CATALOG_LOADING_BENCHMARK_RESULT " + JSON.stringify(report))
func _run() -> void:
	var preserve_raw: bool = "--catalog-derived-cold" in OS.get_cmdline_user_args()
	if not preserve_raw:
		for name: String in DERIVED:
			_check(not FileAccess.file_exists(BAKE.data_path(name)),"fresh isolated profile required: " + name)
	else:
		# The caller selects its own benchmark-only profile; never clear an
		# ordinary app profile or original definitions. Keep raw definition bakes.
		var profile_root: String = OS.get_environment("TWILIGHT_CATALOG_BENCHMARK_PROFILE_ROOT")
		var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_root.path_join(".twilight-catalog-benchmark-profile.json"))) if not profile_root.is_empty() else null
		_check(OS.get_environment("TWILIGHT_CATALOG_BENCHMARK_PROFILE") == "1" and not profile_root.is_empty() and OS.get_user_data_dir().begins_with(profile_root.path_join("data")+"/"),"explicit benchmark-only profile required before derived clear")
		_check(marker is Dictionary and marker.get("source_sha256") == SOURCE.SOURCE_SHA,"tool-created matching profile marker required before derived clear")
		if failures.is_empty():
			FIELDS.bind(null)
			for name: String in DERIVED: BAKE.clear(name)
	if not failures.is_empty():_write();quit(1);return
	measurements["cache_condition"] = "raw definition bakes retained; selected derived producer bakes removed" if preserve_raw else "fresh profile: raw definition and derived bakes absent"
	var started: int = Time.get_ticks_usec();var identity: Dictionary = SOURCE.identity()
	measurements["source_identity_usec"] = Time.get_ticks_usec()-started
	_check(not identity.is_empty(),"real original source pin accepted")
	if identity.is_empty():_write();quit(1);return
	var catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://data/catalog_v19.json")
	var base: Variant = JSON.parse_string(catalog_bytes.get_string_from_utf8())
	_check(base is Dictionary,"actual committed catalog decoded")
	if not base is Dictionary:_write();quit(1);return
	measurements["base_catalog"]={"bytes":catalog_bytes.size(),"sha256":_sha(catalog_bytes),"initial_items":base.get("아이템",[]).size()}
	var catalog: Dictionary = {}
	var reference: String = ""
	for pass_name: String in ["cold","warm"]:
		var inputs := TimedInputs.new();P.register_inputs = inputs;TimedOwner.reset()
		var candidate: Dictionary = base.duplicate(true);var document: Dictionary = {}
		started = Time.get_ticks_usec()
		var result: Dictionary = P.register(TimedOwner,candidate,document)
		var elapsed: int = Time.get_ticks_usec()-started
		_check(result.get("ok",false),pass_name+" registration succeeds")
		var signature: String = _catalog_signature(candidate,document)
		if pass_name == "cold":reference=signature;catalog=candidate
		else:_check(signature==reference,"warm output is byte-identical to cold registration")
		measurements["native_"+pass_name]={"usec":elapsed,"result":result,"items":candidate.get("아이템",[]).size(),"catalog_document_sha256":signature,"outer_source_usec":inputs.usec,"outer_source_calls":inputs.calls,"owner_usec":TimedOwner.usec.duplicate(),"owner_calls":TimedOwner.calls.duplicate(),"artifacts":_files(),"static_memory":OS.get_static_memory_usage(),"source_problem":SOURCE.problem()}
		print("CATALOG_NATIVE_PHASE " + JSON.stringify({"phase":pass_name,"usec":elapsed,"items":candidate.get("아이템",[]).size(),"signature":signature}))
		if not result.get("ok",false):_write();quit(1);return
	P.register_inputs=null
	if _arg("--catalog-benchmark-phase=") == "native":
		_write();quit(0 if failures.is_empty() else 1);return
	var digest: String = ""
	for pass_name: String in ["cold","warm"]:
		var rules = RULES.new()
		started = Time.get_ticks_usec()
		var ok: bool = rules.load_original_bound(catalog_bytes,catalog.get("아이템",[]),catalog.get("patch523_crafting_catalog_contract",{}))
		var elapsed: int = Time.get_ticks_usec()-started
		_check(ok,pass_name+" equipment rules accepted")
		if pass_name == "cold":digest=rules.digest
		else:_check(rules.digest==digest,"warm model digest equals cold")
		measurements["equipment_"+pass_name]={"usec":elapsed,"ok":ok,"problem":rules.problem,"digest":rules.digest,"loaded_from_bake":rules.loaded_from_bake,"data_counts":{"items":rules.data.get("items",{}).size(),"recipes":rules.data.get("recipes",{}).size()},"artifacts":_files(),"static_memory":OS.get_static_memory_usage(),"source_problem":SOURCE.problem()}
		print("CATALOG_EQUIPMENT_PHASE " + JSON.stringify({"phase":pass_name,"usec":elapsed,"digest":rules.digest,"ok":ok}))
		if not ok:_write();quit(1);return
	_write()
	quit(0 if failures.is_empty() else 1)
