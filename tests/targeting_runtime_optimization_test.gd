extends SceneTree
## Main-scene regressions for explicit targets, path search and mutable skill DB.
## This is correctness coverage, not an Android FPS benchmark.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("TARGET_PERF_REGRESSION_FAIL ",label)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	check(CLASS_QA.enter_game(world),"main scene enters game")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	world.world_interactions.clear_selection()
	for child: Node in world.monsters_root.get_children():
		world.monsters_root.remove_child(child)
		child.queue_free()
	var original_skills: Array = world.skills_db
	var known: Dictionary = world._skill_record("쇼크 스턴")
	check(not known.is_empty(),"original skill indexed by name")
	if not known.is_empty(): check(world._skill_record(str(known.id)) == known,"skill indexed by ID")
	world.skills_db = [{"name":"검증 전용", "id":"qa_lookup", "effect":"damage"}]
	check(world._skill_record("검증 전용").get("id","")=="qa_lookup","replacement DB triggers reindex")
	check(world._skill_record("쇼크 스턴").is_empty(),"old skill does not leak into replacement DB")
	world.skills_db = original_skills
	check(world._skill_record("쇼크 스턴") == known,"restored DB reindexes correctly")
	var monster_scene: PackedScene = load("res://scenes/Monster.tscn")
	var target_a: TwilightMonster = monster_scene.instantiate()
	var target_b: TwilightMonster = monster_scene.instantiate()
	world.monsters_root.add_child(target_a)
	world.monsters_root.add_child(target_b)
	for actor: TwilightMonster in [target_a,target_b]:
		actor.setup({"name":"표적 검증","lv":1,"hp":99999,"atk":1},world.player,world,null)
		actor.set_physics_process(false)
		actor.global_position = world.player.global_position
	# When a valid explicit target is out of this spell's range, the other
	# nearby actor must not become a replacement target.
	target_a.global_position = world.player.global_position + Vector2(180,0)
	world.world_interactions.select_monster(target_a)
	check(world._skill_target(80.0) == null,"out-of-range explicit selection never retargets")
	target_a.global_position = world.player.global_position
	check(world._skill_target(80.0) == target_a,"explicit selection hits original actor when back in range")
	world.world_interactions.clear_selection()
	check(world._skill_target(80.0) != null,"no manual selection allows automatic visible fallback")
	var before: int = world.auto_target_path_checks
	check(world._nearest_reachable_monster(120.0) == target_a,"nearest reachable respects original spawn order on distance tie")
	check(world.auto_target_path_checks == before + 1,"distance-first selector tests one successful route")
	world.auto_target_failed_paths[world._auto_target_failure_key(target_a)] = Time.get_ticks_msec() + 1000
	before = world.auto_target_path_checks
	check(world._nearest_reachable_monster(120.0) == target_b,"temporary failed-path cache skips earlier candidate")
	check(world.auto_target_path_checks == before + 1,"failed-path cache skips duplicate AStar query")
	check(world._nearest_reachable_monster(120.0, true) == target_a,"manual target refresh bypasses negative cache")
	check(world.field_minimap.cached_static_geometry_ready,"minimap static geometry prepared on map entry")
	world.queue_free()
	await process_frame
	print("TARGET_PERF_REGRESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"runtime_correctness_only"}))
	quit(0 if failures.is_empty() else 1)
