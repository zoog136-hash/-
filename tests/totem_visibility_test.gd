extends SceneTree
## Actual Monster scene and attack markers in a local arena, no native geography claim.
const Monster = preload("res://scenes/Monster.tscn")

class Arena extends Node:
	var field_map = null
	var combat_flights = null
	var combat_vfx = null
	var field_population = null
	var hp := 999
	var hidden := false
	func is_player_concealed() -> bool:return hidden
	func _has_line_of_sight_world(_a: Vector2,_b: Vector2) -> bool:return true
	func find_world_path(a: Vector2,b: Vector2) -> PackedVector2Array:return PackedVector2Array([a,b])

var checks := 0
var failures: Array[String] = []
var hits: Array = []

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:failures.append(label)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var actors: Array[TwilightMonster] = []
	var record := {"name":"타이밍 검증","hp":1000}
	for index in range(2):
		var mob: TwilightMonster = Monster.instantiate()
		root.add_child(mob)
		mob.setup(record,player,arena,null)
		mob.set_physics_process(false)
		mob.position = player.position+Vector2(40,0)
		mob.player_hit.connect(func(actor: TwilightMonster,_amount: int,_kind: String) -> void:hits.append(actor.get_instance_id()))
		actors.append(mob)
	var blind := {"type":{"Name":"CannotSee"},"unit":{"Name":"TrueFalse"},"bonus":{"Value":1,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}}
	var target := actors[0]
	var other := actors[1]
	check(target._target_attackable() and other._target_attackable(),"ordinary observers can target player")
	target._physics_process(0.01)
	check(target.motion.active and hits.is_empty(),"real windup begins before hit marker")
	check(target.apply_source_option_debuff("totem:17504",2.5,[blind]),"source effect enters actual Monster scene")
	check(not target.motion.active and not target._target_attackable(),"blindness cancels windup and target perception")
	check(not arena.hidden and other._target_attackable(),"one observer's blindness never makes player globally hidden")
	target._physics_process(0.5)
	target._resolve_attack(target.motion.sequence,"ranged")
	check(hits.is_empty(),"blind AI and queued projectile impact cannot deal player damage")
	other._physics_process(0.01)
	other._physics_process(0.5)
	check(hits.count(other.get_instance_id()) == 1,"unaffected observer still strikes exactly once")
	target.advance_source_option_debuffs(2.01)
	check(not target.source_option_cannot_see() and target._target_attackable(),"expiry restores targeting without changing player state")
	target.attack_cooldown = 0
	target._physics_process(0.01)
	target._physics_process(0.5)
	check(hits.count(target.get_instance_id()) == 1,"expired target resumes ordinary marker-based attack once")
	target.apply_source_option_debuff("totem:17504",2.5,[blind])
	target.setup(record,player,arena,null)
	check(not target.source_option_cannot_see() and target.source_option_debuffs.is_empty(),"next pooled life clears previous observer effect")
	arena.hidden = true
	check(not target._target_attackable() and not other._target_attackable(),"existing global concealment still blocks both observers")
	for mob: TwilightMonster in actors:mob.queue_free()
	player.queue_free()
	arena.queue_free()
	await process_frame
	print("TOTEM_VISIBILITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MONSTER_SCENE_LOCAL_ARENA; NO_NATIVE_MAP_CLAIM"}))
	quit(0 if failures.is_empty() else 1)
