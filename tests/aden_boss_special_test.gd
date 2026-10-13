extends SceneTree

## Exercise the generated Aden encounters in the production Main scene. Only
## QA positions, actor clocks and player HP are controlled; the map, catalog,
## warning geometry, strike signals and damage handler remain production code.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const VECTORS = [Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(-1,1),
	Vector2(-1,0),Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1)]
const COMPASS = ["E","SE","S","SW","W","NW","N","NE"]
const ENCOUNTERS = {"dark_elder_encounter":"흑장로", "death_knight_encounter":"데스나이트"}
var world: TwilightWorld
var failures: Array[String] = []
var report: Array[Dictionary] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("ADEN_BOSS_SPECIAL_FAIL " + label)

func clearing(region: Dictionary) -> Vector2:
	for cell: Vector2i in world.field_map.spawn_cells.get(str(region.id), []):
		var point: Vector2 = world.field_map.cell_to_world(cell)
		var clear: bool = true
		for vector: Vector2 in VECTORS:
			var target: Vector2 = point + vector.normalized() * 80.0
			if not world.field_map.walkable(target) or not world.field_map.point_clear(target) or world.field_map.is_safe(target) or not world.field_map.line_clear(point,target):
				clear = false
				break
		if clear: return point
	return Vector2.INF

func encounter(slot: Dictionary) -> void:
	var region: Dictionary = slot.region
	var name_value: String = str(ENCOUNTERS[str(region.id)])
	check(region.get("map_id", "") == "aden_world", name_value + " current-map metadata")
	var verification: Dictionary = region.get("verification_status", {})
	check(verification.get("exact_spawn_area", "") == "unverified" and verification.get("coordinates", "") == "local_only", name_value + " honest coordinate provenance")
	check(region.get("respawn_policy", "") == "wall_clock" and int(region.respawn_time) == 28800 and verification.get("respawn", "") == "wall_clock_local_only", name_value + " eight-hour wall-clock policy")
	var boss: TwilightMonster = slot.monster as TwilightMonster
	check(is_instance_valid(boss) and boss.monster_name == name_value and boss.is_boss, name_value + " actual generated encounter actor")
	if not is_instance_valid(boss): return
	var skill: Dictionary = boss.ai.get("special", {})
	check(not skill.is_empty(), name_value + " catalog special is connected")
	if skill.is_empty(): return
	check(str(skill.get("evidence", "")) == "local_adaptation_not_verified_original_skill", name_value + " special provenance")
	var center: Vector2 = clearing(region)
	check(center.is_finite(), name_value + " eight-way clearing in actual spawn habitat")
	if not center.is_finite(): return
	var hits: Array[int] = []
	boss.player_hit.connect(func(_actor: TwilightMonster, amount: int, _kind: String) -> void: hits.append(amount))
	for direction: int in range(8):
		var aim: Vector2 = (VECTORS[direction] as Vector2).normalized()
		var label: String = name_value + " " + str(COMPASS[direction])
		boss.position = center
		boss.home_position = center
		world.player.position = center + aim * 80.0
		# The production renderer culls offscreen actor poses. Move the actual
		# gameplay camera with the QA player before sampling the attack track.
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.hp = 1000000
		boss.motion.cancel_attack()
		boss.species_visual.reset_presentation()
		boss.special_cooldown = 0.0
		boss.attack_cooldown = 9999.0
		boss.aggro_remaining = 10.0
		boss.sight_clock = 0.0
		var before: int = hits.size()
		boss._physics_process(.04)
		var rig: TwilightMonsterVisual = boss.species_visual
		check(boss.special_sequence == boss.motion.sequence and boss.motion.active and rig.warning_active, label + " actual AI starts special windup")
		check(boss.motion.facing8 == direction and rig.warning_aim.dot(aim) > .999, label + " warning and facing match screen direction")
		var attack_track: String = boss.motion._resolved_key
		check(boss.motion.frame_source != null and attack_track.ends_with("_" + str(direction)) and boss.motion._resolved_role in ["special", "cast", "attack"], label + " native special attack track matches facing")
		check(boss.sprite.scale.x > 0.0 and boss.sprite.scale.y > 0.0, label + " actor remains upright")
		var warning_center: Vector2 = rig.warning_center
		var warning_aim: Vector2 = rig.warning_aim
		var marker: float = boss.motion.attack_duration * boss.motion.attack_hit_ratio
		boss.motion.advance(maxf(0.0,marker - boss.motion.attack_elapsed - .001),Vector2.ZERO)
		boss.motion.apply(boss.sprite,boss.animation_base_scale)
		check(boss.motion.active and rig.warning_active and hits.size() == before, label + " no idle or damage before marker")
		boss.motion.advance(.002,Vector2.ZERO)
		boss.motion.apply(boss.sprite,boss.animation_base_scale)
		check(hits.size() == before + 1 and not rig.warning_active and rig.effect_age == 0.0, label + " one impact at strike marker")
		check(boss.motion._resolved_key == attack_track, label + " impact retains directional attack track")
		check(rig.effect_center == warning_center and rig.effect_aim == warning_aim and rig.effect_outline == rig.warning_outline, label + " warning and impact retain direction and geometry")
		boss.motion.advance(1.0,Vector2.ZERO)
		boss.motion.apply(boss.sprite,boss.animation_base_scale)
		rig.tick(.7)
		check(hits.size() == before + 1 and not boss.motion.presenting_attack and boss.motion.state == "idle" and rig.effect_age < 0.0, label + " single hit, idle recovery and effect expiry")
		report.append({"encounter":region.id,"name":name_value,"compass":COMPASS[direction],"kind":skill.kind,
			"facing":boss.motion.facing8,"warning_aim":[warning_aim.x,warning_aim.y],"contacts":hits.size()-before,
			"attack_track":attack_track,"idle_track":boss.motion._resolved_key})
	# The same actors cancel their warning when interrupted and when killed.
	boss._begin_special()
	boss.motion.cancel_attack()
	check(not boss.species_visual.warning_active, name_value + " interruption clears warning")
	boss._begin_special()
	boss.take_damage(boss.hp,true)
	check(boss.dead and not boss.species_visual.warning_active and not boss.motion.active, name_value + " death clears special")

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world), "production class selection enters game")
	world.save_timer = -10000.0
	world._set_map("aden_world",false)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: TwilightMonster in world.monsters_root.get_children(): actor.set_physics_process(false)
	var found: int = 0
	for slot: Dictionary in world.field_population.slots:
		if ENCOUNTERS.has(str(slot.region.id)):
			encounter(slot)
			found += 1
	check(found == 2 and report.size() == 16, "both generated Aden bosses cover all eight directions")
	FileAccess.open("user://aden-boss-special-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"directions":report},"\t"))
	world.queue_free()
	await process_frame
	print("ADEN_BOSS_SPECIAL_%s checks=%d directions=%d" % ["OK" if failures.is_empty() else "FAILED",checks,report.size()])
	quit(0 if failures.is_empty() else 1)
