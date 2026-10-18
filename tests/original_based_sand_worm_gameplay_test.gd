extends "res://tests/original_based_ogre_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
## Original project atlas identity, production boss AI/nova and real weapon kill.

func subject_name() -> String: return "샌드 웜"
func subject_folder() -> String: return "sand_worm"

func prepare_monster_direction(_direction: int) -> bool:
	# Isolate the normal attack first; the same unmodified special is exercised
	# below with its clock ready. No boss HP, attack, range or cadence override.
	normal.special_cooldown = 9999.
	return true

func monster_case() -> void:
	check(normal.is_boss and normal.ai.has("special"), "original sand worm boss and special metadata")
	report.setup.normal_attack_probe = "special cooldown paused only for the eight normal attacks"
	report.setup.special_probe = "QA positions and full player healing before each real AI nova; boss stats unchanged"
	await super.monster_case()
	var special_before: Dictionary = normal.ai.special.duplicate(true)
	check(str(special_before.kind) == "nova" and str(special_before.evidence) == "local_adaptation_not_verified_original_skill", "existing local nova skill and provenance retained")
	for direction: int in range(8):
		var aim := screen_direction(direction)
		var label: String = "sand worm nova " + COMPASS[direction]
		normal.motion.cancel_attack()
		normal.species_visual.reset_presentation()
		normal.position = center
		normal.home_position = center
		world.player.position = center + aim * 80.
		world.player.clear_click_path()
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.hp = world._effective_max_hp()
		normal.special_cooldown = 0.
		normal.attack_cooldown = 9999.
		normal.aggro_remaining = 10.
		normal.sight_clock = 0.
		normal.returning_home = false
		var contacts_before := monster_strikes.size()
		var hp_before: int = world.hp
		var warning := false
		var effect := false
		var warned := Vector2.ZERO
		var sequence := -1
		var rig: TwilightMonsterVisual = normal.species_visual
		# A genuine nova releases a player_hit signal, but the production
		# MR/AC resolution can legitimately MISS. Pick a deterministic
		# hit-capable random seed (as in the common boss skill QA), then
		# retain the exact real RNG, damage, geometry and contact checks.
		var chance: float = world._monster_hit_chance(normal, "magic")
		check(chance > 0.0, label + " native magic hit chance is nonzero")
		var probe := RandomNumberGenerator.new()
		var seed_value: int = -1
		for candidate_seed: int in range(1, 4097):
			probe.seed = candidate_seed
			if probe.randf() < chance:
				seed_value = candidate_seed
				break
		check(seed_value > 0, label + " reproducible native magic hit seed")
		if seed_value > 0: world.rng.seed = seed_value
		normal.set_physics_process(true)
		for _wait: int in range(180):
			await tick()
			if rig.warning_active:
				warning = true
				warned = rig.warning_aim
				sequence = normal.special_sequence
				check(normal.motion.facing8 == direction and warned.dot(aim) > .999, label + " warning follows player direction")
				check(normal.motion.active and attack_track(normal.motion._resolved_key, direction), label + " attack track persists during windup")
				check(rig.warning_center.is_equal_approx(center) and monster_strikes.size() == contacts_before, label + " warning anchor and no early hit")
			if rig.effect_age >= 0.:
				effect = true
				check(rig.effect_center.is_equal_approx(center) and rig.effect_aim == warned, label + " actual effect keeps warning geometry")
				check(rig.effect_outline == rig.warning_outline and normal.released_sequence == sequence, label + " actual strike marker releases same area")
				break
		check(warning and effect, label + " production AI casts actual nova")
		check(monster_strikes.size() == contacts_before + 1 and world.hp < hp_before, label + " one actual contact damages player")
		check(upright(normal.sprite), label + " boss remains upright")
		report.boss.append({"name":normal.monster_name, "kind":str(special_before.kind), "compass":COMPASS[direction],
			"warning":warning, "effect":effect, "warning_aim":str(warned), "effect_aim":str(rig.effect_aim),
			"facing":normal.motion.facing8, "contacts":monster_strikes.size()-contacts_before,
			"player_hp_before":hp_before, "player_hp_after":world.hp})
		await capture("boss-nova-" + COMPASS[direction])
		await tick(100)
		normal.set_physics_process(false)
		check(not normal.motion.presenting_attack and normal.motion._resolved_key == "idle_" + str(direction), label + " normal AI returns to same facing idle")
		check(rig.effect_age < 0. and not rig.warning_active and monster_strikes.size() == contacts_before + 1, label + " effect expires without another contact")
	check(normal.ai.special == special_before, "boss skill configuration unchanged")
	normal._begin_special()
	check(normal.species_visual.warning_active, "interruption probe begins existing warning")
	normal.motion.cancel_attack()
	check(not normal.species_visual.warning_active, "cancel clears actual special warning")

func lifecycle_case() -> void:
	await super.lifecycle_case()
	if is_instance_valid(normal):
		check(not normal.species_visual.warning_active and not normal.motion.active, "actual weapon death clears boss motion and warning")
