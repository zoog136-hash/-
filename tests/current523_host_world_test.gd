extends SceneTree
## With the 523 resource pack installed, aden_world is the original 523 Aden:
## the game starts there on a fresh install (no saved 523 position), plays in
## 523 play mode on top of it, saves and restores, and never reads the old
## source84 Aden picture pack.
## Real input: -- --source523-pack=<installed pack folder>. Without it, only
## checks that nothing changes for a game without the pack.
const HOST = preload("res://scripts/maps/current523_host.gd")
const SOURCE_MAP84 = preload("res://scripts/maps/source_map_runtime.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _finish(extra: Dictionary = {}) -> void:
	var result: Dictionary = {"checks":checks,"failures":failures}
	result.merge(extra)
	print("CURRENT523_HOST_WORLD_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _pack_requested() -> bool:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): return true
	return false

func _wait_for(condition: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if condition.call(): return true
		await process_frame
	return condition.call()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _pack_requested():
		HOST.refresh()
		check(not HOST.requested(), "no 523 map selection without the pack")
		check(SOURCE_MAP84.supports("aden_world"), "the old Aden pack still owns aden_world without the pack")
		_finish({"real_input_checked":false})
		return
	# Script runs may start without autoloads: apply the installed pack the
	# same way the Source523Pack autoload does at startup.
	if root.get_node_or_null("Source523Pack") == null or not bool(root.get_node("Source523Pack").get("configured")):
		var base: String = ""
		for value: String in OS.get_cmdline_user_args():
			if value.begins_with("--source523-pack="): base = value.trim_prefix("--source523-pack=")
		var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
		check(read.ok, "installed pack descriptor: " + str(read.get("reason","")))
		if read.ok: check(PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base))).ok, "installed pack applied")
	HOST.refresh()
	check(HOST.requested(), "the installed pack selects the 523 maps")
	check(not SOURCE_MAP84.supports("aden_world"), "the old Aden picture pack is not consulted")
	var started: int = Time.get_ticks_msec()
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var opened: bool = await _wait_for(func() -> bool: return bool(world.get("current523_aden_play_active")), 900)
	var boot_ms: int = Time.get_ticks_msec() - started
	check(opened, "523 play mode is active after start: " + str(world.get("current523_aden_play_problem")) + " / host: " + HOST.problem)
	if world.field_map == null:
		failures.append("no field after start; map=%s blocked=%s" % [str(world.get("active_map_id")), str(world.get("map_bootstrap_blocked"))])
		_finish({"real_input_checked":true})
		return
	check(str(world.get("active_map_id")) == "aden_world", "the world is aden_world")
	var controller: RefCounted = world.call("_aden_play_controller")
	var host: Variant = controller.get("_prior_world").get("field")
	check(HOST.is_host(host), "play mode stands on the 523 host Aden")
	check(bool(world.field_map.get_meta("current523_generic_field", false)), "the active field is a 523 Land field")
	check(int(world.field_map.get("native_land").get("ID", -1)) == HOST.ADEN_LAND, "the first Land is Aden (4)")
	check(world.field_map.walkable(world.player.global_position), "the player stands on a walkable 523 cell")
	var options: Dictionary = OPTIONS.read()
	check(options.source_position is Array and options.source_position.size() == 2, "the entry point was recorded for later starts")
	var first: Vector2 = world.player.global_position
	check(world.call("_save_game", true) == OK, "the game saves on the host")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.call("save_path")))
	check(saved is Dictionary and saved.get("map_id") == "aden_world", "the save names aden_world")
	check(saved is Dictionary and int(saved.get("original_position", {}).get("source_map_id", -1)) == HOST.ADEN_LAND, "the save records a position on the 523 Aden grid")
	var host_renderer: Variant = controller.get("_prior")
	check(host_renderer is Node and not (host_renderer as Node).can_process() and not (host_renderer as CanvasItem).visible, "the hidden host renderer does not run under play mode")
	_finish({"real_input_checked":true,"boot_ms":boot_ms,"position":[first.x, first.y],"map_name":str(world.field_map.data.get("map_name",""))})
