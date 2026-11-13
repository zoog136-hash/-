extends SceneTree
## Production Loading caller. No producer, loader, or World methods replaced.
const LOADER = preload("res://scripts/boot/loading_screen.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
var samples: Array = []
var failures: Array[String] = []
var loader: Control
var started: int
var ended: bool = false
var last_percent: float = -1.0
var saw_wait: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var options_path: String = OS.get_environment("TWILIGHT_ENTRY_OPTIONS")
	if not options_path.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(options_path))
		if not value is Dictionary or OPTIONS.write(value) != OK:
			printerr("ENTRY_OPTIONS_INVALID"); quit(2); return
	var destination: String = OS.get_environment("TWILIGHT_ENTRY_DESTINATION")
	if destination.is_empty(): destination = "res://Main.tscn"
	started = Time.get_ticks_usec()
	loader = LOADER.open(self, destination)
	loader.progress_changed.connect(_progress)
	loader.finished.connect(_finished)

func _state() -> Dictionary:
	var target: Node = current_scene
	if target == null: return {"ready":false,"failed":false,"reason":"scene_absent"}
	return target.call("loading_readiness") if target.has_method("loading_readiness") else {"ready":target.is_node_ready(),"failed":false,"reason":"no_explicit_readiness_contract"}

func _progress(value: Dictionary) -> void:
	var percent: float = float(value.get("percent", 0))
	var readiness: Dictionary = _state()
	if percent < last_percent: failures.append("percent_decreased")
	if percent >= 100 and not readiness.get("ready",false): failures.append("100_before_readiness")
	if str(value.get("current", "")) == "scene_ready" and not readiness.get("ready",false): saw_wait = true
	last_percent = percent
	samples.append({"elapsed_us":Time.get_ticks_usec()-started,"progress":value.duplicate(true),"readiness":readiness})

func _properties(object: Object, names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in object.get_property_list():
		var key: String = str(property.name)
		if key in names: result[key] = object.get(key)
	return result

func _finished(ok: bool) -> void:
	if ended: return
	ended = true
	var elapsed: int = Time.get_ticks_usec()-started
	var readiness: Dictionary = _state()
	if not ok: failures.append("loading_failed")
	if not readiness.get("ready", false): failures.append("not_ready_at_finished")
	if last_percent != 100: failures.append("finished_percent_not_100")
	var world: Dictionary = {}
	var target: Node = current_scene
	if target != null:
		world = _properties(target, ["active_map_id","current523_aden_play_active","current523_aden_play_problem","source_save_blocked","map_bootstrap_blocked"])
		var objects: Dictionary = _properties(target, ["field_renderer","field_map"])
		for key: String in objects:
			var object: Object = objects[key]
			if object == null: world[key] = null; continue
			var details: Dictionary = {"class":object.get_class(),"script":object.get_script().resource_path if object.get_script() != null else "","meta":{}}
			for meta: StringName in object.get_meta_list(): details.meta[str(meta)] = object.get_meta(meta)
			for method: String in ["frame_metrics","scope_metrics","cache_metrics"]:
				if object.has_method(method): details[method] = object.call(method)
			details["properties"] = _properties(object,["_built_view","_view_rect","draw_region","_draw_region"])
			world[key] = details
	var record: Dictionary = {"ok":ok,"failures":failures,"loading_to_finished_us":elapsed,"readiness":readiness,"samples":samples,"saw_pending_readiness":saw_wait,"world":world,"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"scope":"Linux headless Loading.open to finished; no GPU rendering, Android, or complete original media validation"}
	var output := FileAccess.open(OS.get_environment("TWILIGHT_ENTRY_RESULT"),FileAccess.WRITE)
	if output == null: printerr("ENTRY_RESULT_WRITE_FAILED"); quit(2); return
	output.store_string(JSON.stringify(record,"  ")); output.close()
	print("LOADING_ENTRY_RESULT " + JSON.stringify({"ok":ok,"failures":failures,"loading_to_finished_us":elapsed}))
	# Let the production overlay close before terminating.
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
