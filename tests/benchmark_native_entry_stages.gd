extends SceneTree
## Copies registry text at runtime only to substitute the profiling FIELD subclass.
## Hash/header validation and every loading branch remain the exact production code.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var source: String=FileAccess.get_file_as_string("res://scripts/maps/native_png_registry.gd")
	var original: String='const FIELD = preload("res://scripts/maps/native_png_field.gd")'
	assert(source.count(original)==1)
	var registry:=GDScript.new()
	registry.source_code=source.replace(original,'const FIELD = preload("res://tests/qa_native_entry_field.gd")')
	assert(registry.reload()==OK)
	var samples: Array=[]
	for mid: String in ["aden_world","escaros_world"]:
		var start: int=Time.get_ticks_usec()
		var field=registry.load_field(mid)
		assert(field!=null)
		var load_us: int=Time.get_ticks_usec()-start
		var parent:=Node2D.new();root.add_child(parent)
		var body: StaticBody2D=field.build_physics(parent)
		samples.append({"map":mid,"load_field_us":load_us,"timings":field.timings.duplicate(true),"detailed_calls":field.calls.duplicate(true),"registry_before_after_configure_us":load_us-int(field.timings.configure_png_us),"cache_hit":field.navigation_cache_hit,"cells":field.width*field.height,"physics_shapes":body.get_child_count()})
		parent.queue_free();await process_frame
	var out: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	if out.is_empty():out="user://native-entry-stages.json"
	var file:=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"registry_source_sha256":source.sha256_text(),"samples":samples,"scope":"standalone native registry+field stages; no actor/sprite loading, no normal Main wall-frame claim; nested timings are inclusive"},"  "));file.close()
	print("NATIVE_ENTRY_STAGES_OK");quit(0)
