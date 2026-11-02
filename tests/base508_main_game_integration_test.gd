extends SceneTree
## Actual Main/player/Monster entry and exit in isolated source test mode.
const MODE = preload("res://scripts/maps/base508_game_mode.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sentinel_path: String = "user://twilight_v20_save.json"
	var sentinel := FileAccess.open(sentinel_path, FileAccess.WRITE)
	sentinel.store_string("normal-save-sentinel-not-json");sentinel.close()
	var sentinel_sha: String = FileAccess.get_sha256(sentinel_path)
	var scene: PackedScene = load("res://Main.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	for i: int in range(3): await process_frame
	check(world.BASE508_TEST.enabled(), "explicit test mode")
	check(world.active_map_id == "base508_land_48962_review_albino_01", "normal Main enters validated source map")
	check(world.field_map != null and bool(world.field_map.get_meta("base508_source_test", false)), "actual field bound")
	check(world.field_renderer.get_script().resource_path == "res://scripts/maps/base508_game_renderer.gd", "actual source renderer bound")
	check(world.field_renderer.source_overview != null, "source overview decoded by game renderer")
	check(world.monsters_root.get_child_count() == 0, "unconfirmed original spawn points not invented")
	var spawn: Vector2 = world.player.global_position
	check(world.field_map.point_clear(spawn, 4.0), "real player starts on supplied collision-checked source area")
	var moved: bool = false
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var point: Vector2 = spawn + direction * 8.0
		if world.field_map.line_clear(spawn, point):
			world.player.global_position = point
			moved = true;break
	check(moved, "real player can enter neighboring validated point")
	# Explicit runtime test fixture, never an original spawn record.
	var monster = preload("res://scenes/Monster.tscn").instantiate()
	monster.position = spawn
	world.monsters_root.add_child(monster)
	monster.setup({"name":"base508_integration_fixture", "hp":17, "lv":1, "atk":2}, world.player, world, null)
	monster.set_physics_process(false)
	check(monster.world_controller == world and monster.target_player == world.player, "real Monster bound to actual source-map World/player")
	check(world.field_map.actor_contract(monster).position_evidence == "PROJECTED_RUNTIME_REVIEW; NOT_AN_ORIGINAL_SPAWN_RECORD", "runtime fixture not misreported as source spawn")
	monster.free()
	check(world._save_game(true) == ERR_UNAVAILABLE, "test mode refuses save")
	world._load_game(true)
	check(FileAccess.get_sha256(sentinel_path) == sentinel_sha, "normal save not read or overwritten")
	check(not FileAccess.file_exists("user://base508_source_test_never_written.json"), "no separate test save silently written")
	# Leave source map through the real field teardown, then exit test session.
	world._set_map("aden_world", false)
	check(world.active_map_id == "aden_world" or (world.active_map_id == "base508_land_48962_review_albino_01" and bool(world.field_map.get_meta("base508_source_test",false))), "field switch succeeds or preserves source field when destination pack unavailable")
	check(world._save_game(true) == ERR_UNAVAILABLE, "source-test flag continues protecting saves after field switch")
	world.queue_free()
	await process_frame
	await process_frame
	MODE.prepared = null
	check(FileAccess.get_sha256(sentinel_path) == sentinel_sha, "exit notification preserves normal save")
	print("BASE508_MAIN_GAME_INTEGRATION failures=", failures, " original_spawns=0 android=false visual_equivalence=not_tested")
	quit(0 if failures == 0 else 1)
