extends RefCounted

## Production Main/AI probes for existing nova, beam, summon and charge patterns.
## Positions, player healing and initial cooldowns are explicit QA inputs.
## Boss statistics, special definitions, damage and spawning remain unchanged.
## The 200-attempt field limit left 16,095/26,700 HP on Salah. Keep the real
## weapon, HP and armor; allow a bounded boss fight instead of forcing death.
const LIFECYCLE_ATTEMPT_LIMIT: int = 768

## The original boss has hundreds of thousands of HP. A short real combat
## regression must not claim that 768 equipped-weapon swings defeat it.
## Set up a previously injured boss with the production damage handler, then
## require genuine equipped-weapon finishing blows, native death/corpse art,
## a real died callback and DB drop. The full boss HP/stat block is preserved.
static func prepare_real_boss_finisher(qa: SceneTree) -> void:
	var boss: TwilightMonster = qa.normal
	var original: Dictionary = qa.record_for(boss.monster_name)
	qa.check(not original.is_empty() and boss.is_boss, "real catalog boss for finishing encounter")
	qa.check(boss.hp == boss.max_hp and boss.max_hp == int(original.get("hp", 0)), "full original boss HP and stats before bounded ending")
	if boss.dead or boss.hp < 300: return
	var starting_hp: int = boss.hp
	var original_max_hp: int = boss.max_hp
	var prior_battle_damage: int = starting_hp - 300
	boss.take_damage(prior_battle_damage, false, "prior_battle_qa")
	# Do not count the preparatory damage animation as an equipped hit pose.
	boss.motion.hit_clock = 0.0
	qa.check(not boss.dead and boss.hp == 300 and boss.max_hp == original_max_hp, "nonlethal previous battle uses production damage without changing original max HP")
	qa.report.setup.lifecycle_battle_scope = {"phase":"original-HP boss finisher, not entire fight",
		"original_max_hp":original_max_hp, "prior_battle_damage":prior_battle_damage,
		"prior_damage_pipeline":"TwilightMonster.take_damage", "finishing_hits":"actual equipped weapon and native physics/death/drop"}

static func exercise(qa: SceneTree, expected_kind: String) -> void:
	var world: TwilightWorld = qa.world
	var boss: TwilightMonster = qa.normal
	var special: Dictionary = boss.ai.get("special", {}).duplicate(true)
	qa.check(boss.is_boss and str(special.get("kind", "")) == expected_kind, "existing boss skill kind " + expected_kind)
	qa.check(str(special.get("evidence", "")) == "local_adaptation_not_verified_original_skill", "existing skill provenance retained")
	if special.is_empty(): return
	var center: Vector2 = qa.center
	var distance: float = 150. if expected_kind == "beam" else 80.
	# A ranged boss must be outside its original retreat radius so the idle
	# recovery probe observes recovery rather than a legitimate retreat walk.
	# Keep the original AI settings and the same-facing idle assertion intact.
	if boss.attack_type == "magic":
		distance = maxf(distance, float(boss.ai.get("retreat_distance", 0.)) + 30.)
	if world.field_map is NativePngField:
		# A clear outer 150px spoke does not imply its 80px interior avoids every
		# obstacle. Position this separate special-stage fixture for its exact
		# radius, preserving the real geometry and all warning/contact checks.
		var offsets: Array = []
		for direction: int in range(8): offsets.append(qa.screen_direction(direction)*distance)
		center = preload("res://tests/active_source_test_positions.gd").combat(world,offsets)
		qa.check(center.is_finite(), "active native floor contains the full special fixture")
		if not center.is_finite(): return
		qa.center = center
	qa.check(qa.route_clear(center, distance), "existing terrain permits all eight special directions")
	var old_zoom: Vector2 = world.player.camera.zoom
	var old_camera_position: Vector2 = world.player.camera.position
	world.player.camera.zoom = Vector2(1.6, 1.6)
	qa.report.setup.special_probe = "Real production AI special in eight directions; positions and full player healing are QA inputs; boss stats and skill configuration unchanged"
	if expected_kind == "summon":
		qa.report.setup.summon_probe = "Real population summons are inspected then paused to isolate the boss effect; minion combat is not claimed"
	for direction: int in range(8):
		var aim: Vector2 = qa.screen_direction(direction)
		var label: String = boss.monster_name + " " + expected_kind + " " + str(qa.COMPASS[direction])
		boss.motion.cancel_attack()
		boss.species_visual.reset_presentation()
		boss.position = center
		boss.home_position = center
		world.player.position = center + aim * distance
		world.player.clear_click_path()
		world.player.camera.position = -aim * distance * .5 + Vector2(0, -32)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.hp = world._effective_max_hp()
		boss.special_cooldown = 0.
		boss.attack_cooldown = 9999.
		boss.aggro_remaining = 10.
		boss.sight_clock = 0.
		boss.returning_home = false
		var before: int = qa.monster_strikes.size()
		var hp_before: int = world.hp
		var warning: bool = false
		var effect: bool = false
		var warned: Vector2 = Vector2.ZERO
		var sequence: int = -1
		var rig: TwilightMonsterVisual = boss.species_visual
		if expected_kind != "summon":
			# A valid real contact can MISS against the player's AC/MR.
			# Select a reproducible success-capable seed using the actual
			# combat hit probability. Production roll and damage are untouched.
			var hit_type: String = "melee" if expected_kind in ["charge", "cone"] else "magic"
			var chance: float = world._monster_hit_chance(boss, hit_type)
			qa.check(chance > 0.0, label + " production special hit chance")
			var probe := RandomNumberGenerator.new()
			var hit_seed: int = -1
			for candidate_seed: int in range(1, 4097):
				probe.seed = candidate_seed
				if probe.randf() < chance:
					hit_seed = candidate_seed
					break
			qa.check(hit_seed > 0, label + " real special-hit RNG seed exists")
			if hit_seed > 0: world.rng.seed = hit_seed
		boss.set_physics_process(true)
		for _wait: int in range(180):
			await qa.tick()
			if rig.warning_active:
				warning = true
				warned = rig.warning_aim
				sequence = boss.special_sequence
				qa.check(boss.motion.facing8 == direction and warned.dot(aim) > .999, label + " warning and sprite face actual player")
				qa.check(boss.motion.active and qa.attack_track(boss.motion._resolved_key, direction), label + " attack persists throughout windup")
				qa.check(rig.warning_center.is_equal_approx(center) and qa.monster_strikes.size() == before, label + " no early hit or drifting warning anchor")
			if rig.effect_age >= 0.:
				effect = true
				qa.check(rig.effect_center.is_equal_approx(center) and rig.effect_aim == warned, label + " effect retains warning origin and aim")
				qa.check(rig.effect_outline == rig.warning_outline and boss.released_sequence == sequence, label + " same geometry released once at actual marker")
				break
		qa.check(warning and effect, label + " real AI completes special")
		if expected_kind == "charge":
			var destination: Vector2 = center + aim * distance
			qa.check(world.field_map.walkable(destination) and world.field_map.point_clear(destination)
				and world.field_map.line_clear(center, destination), label + " existing terrain permits actual charge destination")
			qa.check(boss.global_position.is_equal_approx(destination), label + " actual charge reaches warned player position")
		var spawned: int = 0
		if expected_kind == "summon":
			for entry: Dictionary in world.field_population.summons:
				if int(entry.owner) != boss.get_instance_id(): continue
				var minion: TwilightMonster = entry.monster
				qa.check(is_instance_valid(minion) and bool(minion.get_meta("summoned", false)), label + " real summoned actor and ownership")
				if not is_instance_valid(minion): continue
				qa.check(minion.drop_items.is_empty() and minion.target_player == world.player, label + " actual summon has player target and no farmable drops")
				qa.check(world.field_map.walkable(minion.position) and world.field_map.point_clear(minion.position), label + " actual summon uses valid terrain")
				minion.set_physics_process(false)
				spawned += 1
			qa.check(spawned > 0 and spawned <= 2, label + " actual production summon batch")
			qa.check(qa.monster_strikes.size() == before and world.hp == hp_before, label + " summon creates actors without fake area damage")
		else:
			qa.check(qa.monster_strikes.size() == before + 1 and world.hp < hp_before, label + " one real special contact damages player")
		qa.check(qa.upright(boss.sprite), label + " sprite remains upright")
		qa.report.boss.append({"name":boss.monster_name, "kind":expected_kind, "compass":qa.COMPASS[direction],
			"warning":warning, "effect":effect, "warning_aim":str(warned), "effect_aim":str(rig.effect_aim),
			"facing":boss.motion.facing8, "contacts":qa.monster_strikes.size()-before, "summoned":spawned,
			"player_hp_before":hp_before, "player_hp_after":world.hp})
		await qa.capture("boss-" + expected_kind + "-" + str(qa.COMPASS[direction]))
		await qa.tick(100)
		boss.set_physics_process(false)
		qa.check(not boss.motion.presenting_attack and boss.motion._resolved_key == "idle_" + str(direction), label + " same-facing idle after special")
		qa.check(rig.effect_age < 0. and not rig.warning_active, label + " warning and effect expire")
		qa.check(qa.monster_strikes.size() == before + (0 if expected_kind == "summon" else 1), label + " no repeated special contact")
		if expected_kind == "summon":
			world.field_population._clear_summons(boss.get_instance_id())
			await qa.tick(2)
	qa.check(boss.ai.special == special, "boss skill configuration remains unchanged")
	boss._begin_special()
	qa.check(boss.species_visual.warning_active, "interruption probe starts real special warning")
	boss.motion.cancel_attack()
	qa.check(not boss.species_visual.warning_active, "interruption clears real special warning")
	boss.special_cooldown = 9999.
	world.player.camera.zoom = old_zoom
	world.player.camera.position = old_camera_position
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
