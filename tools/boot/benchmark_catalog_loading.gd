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
	var report: Dictionary = {"owner":_arg("--catalog-benchmark-owner=") if not _arg("--catalog-benchmark-owner=").is_empty() else "profiled","failures":failures,"measurements":measurements,"engine":Engine.get_version_info().string,"phase":_arg("--catalog-benchmark-phase=") if not _arg("--catalog-benchmark-phase=").is_empty() else "both","profile":OS.get_user_data_dir(),"source":SOURCE.identity(),"source_problem":SOURCE.problem(),"scope":"real original definitions; targeted producers, no Main/map/media/Android", "warm_condition":"second producer call in same process, fresh catalog/model object, existing verified derived bakes and reader caches", "preload_caveat":"raw-table conversion may occur during Script preloads before timed producer calls; subprocess wall and BOOT_PROGRESS stages cover that work", "timing_overhead":"forward-only outer row access clocks; owner methods timed only in profiled mode; production owner mode has empty owner counters"}
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
		var result: Dictionary = P.register(DROPS,candidate,document) if _arg("--catalog-benchmark-owner=") == "production" else P.register(TimedOwner,candidate,document)
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
		_market_after_registration()
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
	_market_after_registration()
	_write()
	quit(0 if failures.is_empty() else 1)

## Optional public query probe, after all producer measurements. Same harness in
## both arms; no source/Market caches are cleared or implementation substituted.
## The first item is included once in the all-items aggregate (no warmed repeat).
func _market_after_registration() -> void:
	if not "--catalog-market-public" in OS.get_cmdline_user_args(): return
	var phase_started: int = Time.get_ticks_usec()
	var expected: Dictionary = {}
	var market_links: int = 0
	for index: int in SOURCE.row_count("ItemBonus"):
		var link: Dictionary = SOURCE.row_at("ItemBonus",index)
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",0)))
		var kind: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",0)))
		if kind.get("Name") != "MarketPurchaseID": continue
		market_links += 1
		var value: Variant = bonus.get("Value")
		if not P.integer(value) or value <= 0: continue
		var id: int = int(link.get("ItemClassID",0))
		var item: Dictionary = SOURCE.row("ItemClass",id)
		if id <= 0 or item.get("TestItem") != false or not SOURCE.declared_exclusion("ItemClass",item).is_empty(): continue
		expected[id] = int(expected.get(id,0))+1
	var ids: Array = expected.keys(); ids.sort()
	_check(not ids.is_empty(),"public Market probe has actual admitted original items")
	var enumeration_us: int = Time.get_ticks_usec()-phase_started
	var reader: Script = load("res://scripts/resources/current523_item_data.gd") as Script
	_check(reader != null and reader.has_method("describe"),"public ItemData.describe ABI available")
	if reader == null or not reader.has_method("describe"): return
	var full_hash := HashingContext.new(); full_hash.start(HashingContext.HASH_SHA256)
	var market_hash := HashingContext.new(); market_hash.start(HashingContext.HASH_SHA256)
	var generation_us: int = 0
	var serialization_us: int = 0
	var full_bytes: int = 0
	var market_bytes: int = 0
	var references: int = 0
	var first: Dictionary = {}
	var rss_before: Dictionary = _market_rss()
	var sampled_rss_peak: int = int(rss_before.get("rss_kib",0))
	var query_started: int = Time.get_ticks_usec()
	for id: int in ids:
		var started: int = Time.get_ticks_usec()
		var detail: Dictionary = reader.call("describe",id,false)
		var elapsed: int = Time.get_ticks_usec()-started
		generation_us += elapsed
		_check(detail.get("source") == SOURCE.identity() and detail.get("item_class",{}).get("ID") == id,"public Market item/source identity: "+str(id))
		var market: Array = []
		for reference: Dictionary in detail.get("typed_references",[]):
			if reference.has("market_gotcha"): market.append(reference)
		_check(market.size() == int(expected[id]),"public Market reference count: "+str(id))
		references += market.size()
		started = Time.get_ticks_usec()
		# Frame each item as a complete Variant; hashes consume bytes immediately.
		# Neither full descriptions nor Market graph arrays survive this iteration.
		var encoded: PackedByteArray = var_to_bytes([id,detail])
		var market_encoded: PackedByteArray = var_to_bytes([id,market])
		full_hash.update(encoded); market_hash.update(market_encoded)
		full_bytes += encoded.size(); market_bytes += market_encoded.size()
		if first.is_empty(): first={"item_id":id,"generation_usec":elapsed,"references":market.size(),"full_bytes":encoded.size(),"full_sha256":_sha(encoded),"market_bytes":market_encoded.size(),"market_sha256":_sha(market_encoded)}
		serialization_us += Time.get_ticks_usec()-started
		sampled_rss_peak = maxi(sampled_rss_peak,int(_market_rss().get("rss_kib",0)))
	var result: Dictionary = {"api":"ItemData.describe(item_id,false)","condition":"after native cold/warm and requested equipment phases; existing source/Market caches retained; sorted admitted item IDs; first item included once in all","item_ids_sha256":_sha(var_to_bytes(ids)),"items":ids.size(),"source_market_links":market_links,"references":references,"enumeration_usec":enumeration_us,"first":first,"all_generation_usec":generation_us,"serialization_hash_usec":serialization_us,"query_loop_wall_usec":Time.get_ticks_usec()-query_started,"full_bytes":full_bytes,"full_sha256":full_hash.finish().hex_encode(),"market_bytes":market_bytes,"market_sha256":market_hash.finish().hex_encode(),"rss_before":rss_before,"rss_after":_market_rss(),"per_item_sampled_peak_rss_kib":sampled_rss_peak,"rss_caveat":"Linux process RSS sampled after each item; VmHWM is lifetime peak including previous producers; no per-query peak guarantee","source_problem":SOURCE.problem()}
	measurements["market_public"] = result
	print("CATALOG_MARKET_PUBLIC_PHASE "+JSON.stringify(result))

func _market_rss() -> Dictionary:
	var result: Dictionary = {}
	var status := FileAccess.open("/proc/self/status",FileAccess.READ)
	if status == null: return result
	# procfs reports a zero file length; read lines instead of length-based bytes.
	while not status.eof_reached():
		var line: String = status.get_line()
		if line.begins_with("VmRSS:") or line.begins_with("VmHWM:"):
			var fields: PackedStringArray = line.replace("\t"," ").split(" ",false)
			if fields.size() >= 2: result["rss_kib" if line.begins_with("VmRSS:") else "lifetime_peak_rss_kib"] = int(fields[1])
	status.close()
	return result
