extends SceneTree
const METER=preload("res://tests/qa_auto_selection_world.gd")
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("AUTO_SELECTION_FAIL "+label)

func previous(world: TwilightWorld,limit: float) -> TwilightMonster:
	var best: TwilightMonster=null
	var distance: float=limit
	for node: Node in world.monsters_root.get_children():
		if not node is TwilightMonster or node.dead: continue
		var candidate_distance: float=world.player.global_position.distance_to(node.global_position)
		if candidate_distance>=distance: continue
		if world.find_world_path(world.player.global_position,node.global_position).is_empty(): continue
		distance=candidate_distance
		best=node
	return best

func run() -> void:
	var world=METER.new()
	world.player=preload("res://scripts/player.gd").new()
	world.monsters_root=Node2D.new()
	# Descending order exercises the original worst-case successful search.
	for i: int in range(24,0,-1):
		var actor=preload("res://scripts/monster.gd").new()
		actor.position=Vector2(i*10,0)
		world.monsters_root.add_child(actor)
	var expected: TwilightMonster=previous(world,9999)
	var before: int=world.selection_path_calls
	world.selection_path_calls=0
	check(world._nearest_reachable_monster(9999)==expected,"same descending-order nearest target")
	check(before==24 and world.selection_path_calls==1,"24 successful paths reduce to1")
	var duplicate=preload("res://scripts/monster.gd").new()
	duplicate.position=Vector2(-10,0)
	world.monsters_root.add_child(duplicate)
	check(world._nearest_reachable_monster(9999)==expected,"equal distance keeps first scene child")
	var random:=RandomNumberGenerator.new();random.seed=20261025
	for trial: int in range(100):
		world.blocked_positions.clear()
		world.player.position=Vector2(random.randi_range(-50,50),random.randi_range(-50,50))
		for actor: TwilightMonster in world.monsters_root.get_children():
			actor.position=Vector2(random.randi_range(-30,30)*10,random.randi_range(-30,30)*10)
			actor.dead=random.randf()<.15
			if random.randf()<.4: world.blocked_positions[actor.position]=true
		var limit: float=random.randi_range(0,500)
		check(world._nearest_reachable_monster(limit)==previous(world,limit),"oracle changing position/dead/blocked/limit "+str(trial))
	for actor: TwilightMonster in world.monsters_root.get_children():
		actor.dead=false;world.blocked_positions[actor.position]=true
	world.selection_path_calls=0
	check(world._nearest_reachable_monster(9999)==null,"all unreachable stays empty")
	check(world.selection_path_calls==25,"all failures still evaluated; no stale negative cache")
	var reopened: TwilightMonster=world.monsters_root.get_child(0)
	world.blocked_positions.erase(reopened.position)
	check(world._nearest_reachable_monster(9999)==previous(world,9999),"newly opened path immediately reconsidered")
	world.player.free();world.monsters_root.free();world.free()
	print("AUTO_SELECTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"before_paths":24,"after_paths":1}))
	if failures.is_empty(): print("AUTO_SELECTION_OK")
	quit(0 if failures.is_empty() else 1)
