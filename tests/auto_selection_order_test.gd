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
	world.add_child(world.player)
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
	world.auto_target_failed_paths.clear() # The fixture has just changed terrain.
	world.selection_path_calls=0
	check(world._nearest_reachable_monster(9999)==null,"all unreachable stays empty")
	check(world.selection_path_calls==25,"all failures still evaluated; no stale negative cache")
	var reopened: TwilightMonster=world.monsters_root.get_child(0)
	world.blocked_positions.erase(reopened.position)
	check(world._nearest_reachable_monster(9999,true)==previous(world,9999),"explicit refresh immediately reconsiders newly opened fixture terrain")
	world.blocked_positions.clear()
	for actor: TwilightMonster in world.monsters_root.get_children():
		actor.source_targeting={"snapshot":"fixture", "IsAutoSelectable":false}
	world.selection_path_calls=0
	check(world._nearest_reachable_monster(9999,true,true)==null and world.selection_path_calls==0,"automatic exclusion happens before pathfinding")
	var allowed: TwilightMonster=world.monsters_root.get_child(0)
	allowed.source_targeting.IsAutoSelectable=true
	check(world._nearest_reachable_monster(9999,true,true)==allowed,"automatic acquisition chooses eligible actor")
	var excluded: TwilightMonster=world.monsters_root.get_child(1)
	world.auto_target=excluded;world.selected_monster=excluded
	world._run_auto_hunt()
	check(world.auto_target==allowed and world.last_test_attack==allowed and world.last_test_attack_automatic,"cached excluded target cannot bypass acquisition rule")
	allowed.source_targeting.IsAutoSelectable=false
	world.auto_target=excluded;world.last_test_attack=null;world.auto_target_next_search_ms=0
	world._run_auto_hunt()
	check(world.auto_target==null and world.last_test_attack==null and world.player.click_path.is_empty(),"excluded-only population creates no automatic attack or chase")
	check(world._nearest_reachable_monster(9999,true)==previous(world,9999),"manual nearest selection keeps its existing rule")
	var interactions=preload("res://scripts/input/world_interactions.gd").new()
	interactions.world=world;world.world_interactions=interactions
	interactions.selections.append(interactions.monster_entry(excluded))
	world._run_auto_hunt()
	check(world.auto_target==excluded and world.last_test_attack==excluded and not world.last_test_attack_automatic,"explicit manual priority preserved while AUTO runs")
	var summon=preload("res://scripts/skills/summon_service.gd").new()
	summon.world=world;summon.skill={"summon_leash":99999.0};world.player.auto_enabled=true
	world.selected_monster=excluded
	check(summon.choose_target()==null,"guard summon automatic fallback respects source exclusion")
	summon.designated=weakref(excluded)
	check(summon.choose_target()==excluded,"explicit summon attack is not damage immunity")
	summon.designated=null;summon.threat=weakref(excluded)
	check(summon.choose_target()==excluded,"summon retaliation preserved")
	excluded.life_id+=1
	check(summon.choose_target()==null,"stale summon retaliation cannot follow a pooled new life")
	summon.designated=weakref(excluded)
	check(summon.choose_target()==excluded,"fresh explicit designation binds the current life")
	excluded.life_id+=1
	check(summon.choose_target()==null,"stale explicit designation cannot bypass automatic exclusion after reuse")
	summon.designated=weakref(excluded)
	var detached:=Node2D.new()
	excluded.reparent(detached)
	check(summon.choose_target()==null,"detached encounter cannot remain a summon target")
	excluded.reparent(world.monsters_root);detached.free()
	excluded.source_targeting.IsAutoSelectable=1
	check(not excluded.permits_auto_selection(),"unknown numeric category flag is not boolean true")
	excluded.source_targeting.clear()
	check(excluded.permits_auto_selection(),"legacy actor without source category preserves automatic eligibility")
	interactions.free();world.world_interactions=null
	world.player.original_source_preview.free()
	world.player.current523_identity_actor.free()
	world.player.free();world.monsters_root.free();world.free()
	print("AUTO_SELECTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"before_paths":24,"after_paths":1}))
	if failures.is_empty(): print("AUTO_SELECTION_OK")
	quit(0 if failures.is_empty() else 1)
