extends SceneTree
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const METER=preload("res://tests/qa_native_entry_field.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);printerr("ENTRY_SAFE_FAIL "+label)
func write(path: String,content: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(content);file.close()
func run() -> void:
	var original_path: String=OS.get_environment("TWILIGHT_PLAYABLE_BASELINE")
	check(FileAccess.file_exists(original_path),"baseline source available")
	if not failures.is_empty():quit(1);return
	var original: String=FileAccess.get_file_as_string(original_path)
	write("user://entry-baseline-playable.gd",original.replace("class_name PlayableField",""))
	var native_source: String=FileAccess.get_file_as_string("res://scripts/maps/native_png_field.gd")
	write("user://entry-baseline-native.gd",native_source.replace("extends PlayableField",'extends "user://entry-baseline-playable.gd"').replace("class_name NativePngField",""))
	var meter_source: String=FileAccess.get_file_as_string("res://tests/qa_native_entry_field.gd")
	write("user://entry-baseline-meter.gd",meter_source.replace('extends "res://scripts/maps/native_png_field.gd"','extends "user://entry-baseline-native.gd"'))
	var old_script: Script=load("user://entry-baseline-meter.gd")
	var plan: Dictionary=REGISTRY.plan()
	var results: Array=[]
	for mid: String in ["aden_world","escaros_world"]:
		var verified=REGISTRY.load_field(mid)
		check(verified!=null,"validated original pack "+mid)
		if verified==null:continue
		var before=old_script.new();var after=METER.new()
		var started: int=Time.get_ticks_usec()
		before.configure_png(mid,plan,verified.png_manifest,verified.png_root)
		var before_us: int=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec()
		after.configure_png(mid,plan,verified.png_manifest,verified.png_root)
		var after_us: int=Time.get_ticks_usec()-started
		var before_snapshot: Dictionary=before.navigation_snapshot()
		var after_snapshot: Dictionary=after.navigation_snapshot()
		var same: Dictionary={"data":before.data==after.data,"prepared_spawns":before.spawn_geometries==after.spawn_geometries,"ordered_spawn_cells":before.spawn_cells==after.spawn_cells,"solid_runs":before_snapshot.solid_runs==after_snapshot.solid_runs,"reachable":before.reachable==after.reachable,"signature":before.geometry_signature()==after.geometry_signature()}
		for key: String in same:check(bool(same[key]),mid+" "+key)
		results.append({"map":mid,"equivalence":same,"before_configure_png_us":before_us,"after_configure_png_us":after_us,"before_timings":before.timings,"after_timings":after.timings,"before_calls":before.calls,"after_calls":after.calls,"cells":after.width*after.height})
	var out: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	write(out,JSON.stringify({"engine":Engine.get_version_info().string,"baseline_playable_sha256":original.sha256_text(),"current_playable_sha256":FileAccess.get_file_as_string("res://scripts/maps/playable_field.gd").sha256_text(),"results":results,"failures":failures,"scope":"same plan/manifest in same process; only base PlayableField baseline source differs; detailed counters add overhead and nested times must not be summed"},"  "))
	print("ENTRY_SAFE_RESULT ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
