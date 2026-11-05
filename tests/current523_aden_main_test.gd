extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var pack_root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aden523-pack="): pack_root = arg.trim_prefix("--aden523-pack=")
	check(not pack_root.is_empty(), "explicit current523 raw pack required")
	if pack_root.is_empty(): quit(1); return
	var scene: PackedScene = load("res://Main.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main class confirmation")
	world.player.set_physics_process(false)
	check(world._save_game(true) == OK, "isolated Main save created through production writer")
	var save_path: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(save_path)
	var map_id: String = world.active_map_id
	var field = world.field_map
	var renderer = world.field_renderer
	var position: Vector2 = world.player.global_position
	var gold: int = world.gold
	check(not world.open_current523_aden_sources("/nonexistent/aden523-pack"), "missing raw pack rejects through Main")
	check(world.current523_aden_source_members().is_empty(), "rejected initial pack registers nothing")
	check(world.open_current523_aden_sources(pack_root), "current523 original registry opens through Main: " + str(world.current523_aden_problem))
	check(world.current523_aden_source_members().size() == 677, "Main retains all677 literal original members")
	var changed: Dictionary = world.read_current523_aden_source("Map/Aden/800a8000.s32")
	check(changed.get("source_sha256") == "ab3b89eb4a9be8b2b5448c60bcf4c7ac6d4164ada21d85f88ffc7f566e9b2b96", "Main consumes changed523 original rather than508")
	check(not world.read_current523_aden_source("Map/Aden/800f7ff3e.s32").is_empty(), "Main consumes nonstandard source without deriving an origin")
	check(world.read_current523_aden_source("Map/13225/800a8000.s32").is_empty(), "Main rejects world-siege member identity")
	check(not world.open_current523_aden_sources("/nonexistent/replacement"), "failed replacement rejects")
	check(world.current523_aden_source_members().size() == 677 and not world.read_current523_aden_source("Map/Aden/800a8000.s32").is_empty(), "failed replacement preserves accepted registry")
	world.close_current523_aden_sources()
	check(world.current523_aden_source_members().is_empty(), "explicit close releases raw source registry")
	check(world.active_map_id == map_id and world.field_map == field and world.field_renderer == renderer, "source registration preserves live map and renderer")
	check(world.player.global_position == position and world.gold == gold, "raw source inspection preserves player position and progression")
	check(FileAccess.get_sha256(save_path) == save_sha, "raw source API preserves actual save bytes")
	print("CURRENT523_ADEN_MAIN_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "scope":"ACTUAL_MAIN_RAW_SOURCE_API; ADEN523_RENDERING_AND_MOVEMENT_NOT_IMPLEMENTED"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
