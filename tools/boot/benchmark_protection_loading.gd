extends SceneTree
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const NATIVE=preload("res://scripts/loot/current523_native_item_projection.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const PROTECTION=preload("res://scripts/protection/protection523_source.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
var failures: Array[String]=[]
var measurements: Dictionary={}
func _initialize()->void:run.call_deferred()
func digest(value: Variant)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func run()->void:
	if SOURCE.identity().is_empty():failures.append("source_pin");finish();return
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"));var document: Dictionary={}
	var begin: int=Time.get_ticks_usec();var native: Dictionary=NATIVE.register(DROPS,catalog,document)
	measurements.native_usec=Time.get_ticks_usec()-begin
	if not native.get("ok",false):failures.append("native_warmup");finish();return
	measurements.native_catalog_sha256=digest([catalog,document])
	var expected: String=""
	for label: String in ["cold","warm"]:
		begin=Time.get_ticks_usec();var result: Dictionary=PROTECTION.restore();var elapsed: int=Time.get_ticks_usec()-begin
		var sha: String=digest(result)
		if label=="cold":expected=sha
		if not result.get("ok",false) or sha!=expected:failures.append(label+"_result")
		var path: String=BAKE.data_path(PROTECTION.BAKE_NAME)
		measurements[label]={"usec":elapsed,"result_sha256":sha,"bytes":FileAccess.get_size(path),"file_sha256":FileAccess.get_sha256(path),"static_memory":OS.get_static_memory_usage()}
	if OS.get_environment("TWILIGHT_PROTECTION_REPEAT_EXTRACT")=="1":
		var repeats: Array=[]
		for shared: bool in [false,true,true,false]:
			begin=Time.get_ticks_usec()
			var result: Dictionary=PROTECTION._extract(SOURCE.archive_path(),shared)
			var elapsed: int=Time.get_ticks_usec()-begin
			result.erase("capsule")
			var sha: String=digest(result)
			if sha!=expected:failures.append("repeat_result")
			repeats.append({"shared":shared,"usec":elapsed,"sha256":sha})
		measurements.extract_abba=repeats
	finish()
func finish()->void:
	var result: Dictionary={"failures":failures,"measurements":measurements,"engine":Engine.get_version_info().string,"scope":"real original, native registration before protection, isolated profile; no game or save"}
	var file:=FileAccess.open(OS.get_environment("TWILIGHT_PROTECTION_RESULT"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close();print("PROTECTION_BENCHMARK_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
