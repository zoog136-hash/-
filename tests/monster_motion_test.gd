extends SceneTree

const MOVEMENT_SCOPE = preload("res://scripts/animation/transformation_movement_scope.gd")

class Arena extends Node:
	var field_map = null
	var combat_flights = null
	var hp: int = 999
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func find_world_path(a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([a, b])

var failures: int = 0
var hits: int = 0
var deaths: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("MONSTER MOTION FAIL: " + label)

func _has_run_track(frames: SpriteFrames, profile: TwilightAnimationProfile, facing8: int, facing4: int) -> bool:
	for name_value: String in [str(profile.animation_names.get("run:" + str(facing8), "")),
		str(profile.animation_names.get("run", "")), "run_" + str(facing8),
		"run" + ["_down", "_up", "_left", "_right"][facing4], "run"]:
		if not name_value.is_empty() and frames.has_animation(name_value) and frames.get_frame_count(name_value) > 0:
			return true
	return false

func _run() -> void:
	var arena: Arena = Arena.new()
	root.add_child(arena)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"]
	var monster_scene: PackedScene = load("res://scenes/Monster.tscn")
	for record: Dictionary in records:
		var mob: TwilightMonster = monster_scene.instantiate()
		root.add_child(mob)
		mob.setup(record, player, arena, null)
		mob.set_physics_process(false)
		check(not mob.motion.profile.profile_id.is_empty(), "missing profile " + str(record.name))
		mob.motion.advance(0.05, Vector2.RIGHT * mob.move_speed)
		var expected_role: String = "walk" if MOVEMENT_SCOPE.requires_walk(mob.motion.profile.profile_id) else "run"
		check(mob.motion.state == expected_role and mob.motion.direction.x > 0.0, "movement profile " + str(record.name))
		mob.motion.apply(mob.sprite, mob.animation_base_scale)
		var frames: SpriteFrames = mob.motion.frame_source
		if frames != null:
			var expected_track: String = "run" if expected_role == "run" and _has_run_track(frames, mob.motion.profile, mob.motion.facing8, mob.motion.facing4) else "walk"
			check(mob.motion._resolved_role == expected_track and frames.has_animation(mob.motion._resolved_key), "real movement track with RUN precedence " + str(record.name))
			if frames.has_animation(mob.motion._resolved_key):
				check(frames.get_frame_count(mob.motion._resolved_key) >= 2 and mob.sprite.texture != null, "movement phases and texture " + str(record.name))
			if bool(frames.get_meta("twilight_native_locomotion_staging", false)):
				# Published native monster clips have six real RUN poses/view;
				# their intentionally absent WALK must not be silently invented.
				for direction: int in range(8):
					var run_name := "run_" + str(direction)
					check(not frames.has_animation("walk_" + str(direction)), "native monster keeps run-only scope " + str(record.name))
					check(frames.has_animation(run_name) and frames.get_frame_count(run_name) == 6, "native monster run phases " + str(record.name))
				check(mob.motion._resolved_role == "run", "native monster presents RUN " + str(record.name))
		mob.free()
	var enemy: TwilightMonster = monster_scene.instantiate()
	root.add_child(enemy)
	enemy.setup({"name":"타이밍 검증", "hp":1000}, player, arena, null)
	enemy.set_physics_process(false)
	enemy.position = player.position + Vector2(40, 0)
	enemy.player_hit.connect(func(_mob: TwilightMonster, _damage: int, _kind: String) -> void: hits += 1)
	enemy.died.connect(func(_mob: TwilightMonster) -> void: deaths += 1)
	enemy._physics_process(0.01)
	check(enemy.motion.active and hits == 0, "monster dealt command-time damage")
	enemy._physics_process(0.10)
	check(hits == 0, "monster struck during windup")
	enemy._physics_process(0.28)
	check(hits == 1, "monster hit marker missing")
	enemy._physics_process(0.35)
	check(hits == 1, "monster duplicated damage")
	enemy.attack_cooldown = 0.0
	enemy._physics_process(0.01)
	player.position += Vector2(200, 0)
	enemy._physics_process(0.5)
	check(hits == 1, "out-of-range target was hit")
	enemy.take_damage(10000)
	enemy.take_damage(10000)
	check(enemy.dead and deaths == 1 and enemy.motion.dead, "death/reward emitted more than once")
	check(is_instance_valid(enemy), "corpse removed before death pose")
	await create_timer(1.2).timeout
	check(not is_instance_valid(enemy), "corpse leaked after fade")
	player.queue_free()
	arena.queue_free()
	await process_frame
	if failures == 0: print("MONSTER_MOTION_OK records=163 attack_once=true corpse_lifetime=true")
	quit(0 if failures == 0 else 1)
