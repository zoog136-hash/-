extends SceneTree

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
		check(mob.motion.state == "walk" and mob.motion.direction.x > 0.0, "movement profile " + str(record.name))
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
