extends SceneTree
## Production _run_auto_hunt with controlled route/sight and static 523 field.
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
var checks: int = 0
var failures: Array[String] = []

class TestField extends FIELD:
	var next_clear: bool = true
	var checks_of_leg: int = 0
	func line_clear(_from: Vector2, _to: Vector2) -> bool:
		checks_of_leg+=1
		return next_clear
	func walkable(_point: Vector2) -> bool: return true
	func admit_fixture() -> void:
		loaded=true
		catalog_sha256="fixture-pin"
		set_meta("current523_generic_field",true)

class TestWorld extends TwilightWorld:
	var route_calls: int = 0
	var target_visible: bool = false
	func _run_auto_ground_pickup() -> bool: return false
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return target_visible
	func _run_auto_combat_quickslots() -> bool: return false
	func _target_in_current_weapon_range(_target: TwilightMonster) -> bool: return false
	func _equipment523_locked_target() -> TwilightMonster: return null
	func find_world_path(_from: Vector2,to: Vector2) -> PackedVector2Array:
		route_calls+=1
		return PackedVector2Array([Vector2(20,30),to])

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("AUTO_PURSUIT_REUSE_FAIL ",label)

func _initialize() -> void: _run.call_deferred()

func tick(world: TestWorld) -> void:
	world.auto_repath_timer=0.0
	world._run_auto_hunt()

func _run() -> void:
	var world := TestWorld.new()
	var field := TestField.new()
	field.admit_fixture()
	world.field_map=field
	var player: TwilightPlayer=load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	world.player=player
	world.monsters_root=Node2D.new()
	root.add_child(world.monsters_root)
	var monster: TwilightMonster=world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.set_physics_process(false)
	monster.global_position=Vector2(160,10)
	world.auto_target=monster
	tick(world)
	check(world.route_calls==1 and not player.click_path.is_empty(),"first obstructed pursuit searches normally")
	var route: PackedVector2Array=player.click_path
	for i: int in range(10):tick(world)
	check(world.route_calls==1 and field.checks_of_leg==10 and player.click_path==route,
		"ten expired timers each check next leg without a second full search")
	player.path_index=1
	tick(world)
	check(world.route_calls==1 and player.path_index==1,"retaining a route never rewinds progress")
	monster.global_position.x+=0.25
	tick(world)
	check(world.route_calls==2 and player.click_path[-1]==monster.global_position,
		"even a fractional target movement falls back to the original route")
	field.next_clear=false
	tick(world)
	check(world.route_calls==3,"a blocked immediate leg triggers ordinary repath")
	field.next_clear=true
	monster.life_id+=1
	tick(world)
	check(world.route_calls==4,"recycled actor cannot use a different life's route")
	field.close()
	field.admit_fixture()
	tick(world)
	check(world.route_calls==5,"same field object reopened with a new source reader invalidates route")
	world.combat_generation+=1
	tick(world)
	check(world.route_calls==6,"teleport or combat context change invalidates route")
	world.auto_stuck_time=0.05
	tick(world)
	check(world.route_calls==7,"stalled movement uses original search")
	world.auto_stuck_time=0.0
	player.click_path[0]=Vector2(28,30)
	tick(world)
	check(world.route_calls==8,"a replaced route cannot inherit old proof")
	player.manual_navigation=true
	tick(world)
	check(world.route_calls==8 and world._stable_auto_route.is_empty(),"manual ownership wins and clears reuse")
	player.manual_navigation=false
	world.target_visible=true
	tick(world)
	check(world.route_calls==8 and player.click_path==PackedVector2Array([monster.global_position]),
		"direct visibility prefers the existing immediate route")
	print("CURRENT523_AUTO_PURSUIT_REUSE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.monsters_root.free()
	player.free()
	world.field_map=null
	field=null
	world.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
