extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const Service = preload("res://scripts/skills/skill_service.gd")
const Rules = preload("res://scripts/skill_rules.gd")
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld
var dummy: TwilightMonster
var base: Dictionary
var ancient: Dictionary
var death_events: int = 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("TURN_UNDEAD FAIL: ", message)

func fresh() -> void:
	world._clear_combat_actions()
	world.active_skill_buffs.clear()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.hp = world._effective_max_hp()
	world.mp = 999
	world.player.clear_status_effects()
	dummy.dead = false
	dummy.hp = dummy.max_hp
	dummy.undead = true
	dummy.monster_type = "언데드"
	dummy.is_boss = false
	dummy.status_immunities = []
	dummy.set_physics_process(false)
	world.selected_monster = dummy
	world.player.global_position = dummy.global_position - Vector2(30, 0)

func force_roll(chance: float, success: bool) -> void:
	for seed_value: int in range(10000):
		world.rng.seed = seed_value
		if Service.roll_turn_undead(world.rng, chance) == success:
			world.rng.seed = seed_value
			return
	check(false, "find reproducible success/failure seed")

func release_and_land(success: bool) -> void:
	var service := world.original_skills
	var hp_before := dummy.hp
	var action_id := int(world.pending_attack.get("id", -1))
	world._release_player_attack(action_id)
	check(world.combat_flights.flights.size() == 1, "one moving projectile at the release marker")
	check(dummy.hp == hp_before, "release does not apply early damage")
	force_roll(service.turn_undead_chance(service.catalog.resolve(base), dummy), success)
	for _step: int in range(12): world.combat_flights._physics_process(.02)
	check(world.combat_flights.flights.is_empty(), "projectile actually reaches the NPC")

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual gameplay")
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.job_class = "마법사"
	world.level = 90
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300, 4370)))
	world.equipped_items.clear()
	world.equipped_catalog.clear()
	var service := world.original_skills
	var catalog := service.catalog
	catalog.learned.clear()
	catalog.seed_starters()
	base = catalog.record_for("턴 언데드")
	ancient = catalog.record_for("턴 언데드(에이션트)")
	check(not base.is_empty() and not ancient.is_empty(), "both records restored with stable identities")
	if base.is_empty() or ancient.is_empty(): quit(1); return
	check(base.id == "lm_e35a5e1482fc0950" and ancient.id == "lm_09370fb0d313977d", "existing research IDs preserved")
	check(ancient.grade == "영웅" and ancient.activation == "passive", "official hero passive grade")
	check(catalog.relations[str(ancient.id)].upgrades_from == base.id, "verified enhancement relationship")
	check(base.fields.combat.mp_cost.status == "CUSTOM_BALANCE", "unconfirmed original cost not presented as verified")
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"턴 판정 검증 NPC", "hp":10000, "lv":90, "mr":150, "undead":true}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(30, 0)
	dummy.died.connect(func(_monster: TwilightMonster) -> void: death_events += 1)
	fresh()
	check(not world._cast_job_skill(str(base.name)) and world.mp == 999, "unlearned cast denied without cost")
	world.inventory[str(base.book_name)] = 1
	world.level = int(base.minimum_level) - 1
	check(not catalog.learn(str(base.id)) and int(world.inventory[str(base.book_name)]) == 1, "low level preserves book")
	world.level = 90
	check(catalog.learn(str(base.id)), "learn basic skill through actual book service")
	check(int(world.inventory[str(base.book_name)]) == 0, "learning consumes one book")
	check(not catalog.learn(str(base.id)), "cannot learn twice")
	fresh()
	dummy.undead = false
	dummy.monster_type = "동물"
	var rng_state := world.rng.state
	check(not world._cast_job_skill(str(base.name)), "ordinary monster rejected before cast")
	check(world.mp == 999 and world.skill_cooldowns.is_empty() and world.pending_attack.is_empty(), "ordinary target consumes no MP/cooldown/action")
	check(world.rng.state == rng_state, "ordinary target consumes no probability roll")
	check(not service.auto_wants(base, dummy), "AUTO skips ordinary monsters")
	fresh()
	dummy.status_immunities = ["turnUndead"]
	check(not world._cast_job_skill(str(base.name)) and world.mp == 999, "explicit instant-death immunity")
	fresh()
	dummy.is_boss = true
	check(not service.auto_wants(base, dummy) and not world._cast_job_skill(str(base.name)), "CUSTOM_BALANCE boss exclusion")
	fresh()
	world.mp = int(base.mp) - 1
	check(not world._cast_job_skill(str(base.name)), "insufficient MP rejected")
	check(world.mp == int(base.mp) - 1 and world.pending_attack.is_empty(), "failed cost validation is atomic")
	fresh()
	world.player.apply_silence(2)
	check(not world._cast_job_skill(str(base.name)) and world.mp == 999, "silence forbids casting")
	fresh()
	check(world._cast_job_skill(str(base.name)), "basic manual cast")
	check(world.mp == 999 - int(base.mp), "MP spent once")
	check(is_equal_approx(float(world.skill_cooldowns[str(base.name)]), float(base.cooldown)), "cooldown starts once")
	check(not world._cast_job_skill(str(base.name)), "pending cast cannot be duplicated")
	var hits_before := dummy.damage_hit_count
	var hp_before := dummy.hp
	release_and_land(false)
	check(dummy.hp == hp_before and dummy.damage_hit_count == hits_before and not dummy.dead, "failed roll has no fallback damage")
	check(death_events == 0, "failed roll never emits death")
	check(not world._cast_job_skill(str(base.name)), "cooldown survives failed roll")
	fresh()
	check(world._cast_job_skill(str(base.name)), "successful-roll cast starts")
	release_and_land(true)
	check(dummy.dead and dummy.hp == 0, "success changes real NPC HP to zero")
	check(dummy.damage_hit_count == hits_before + 1 and death_events == 1, "success uses exactly one NPC death/damage signal")
	service.impact(catalog.resolve(base), dummy)
	check(death_events == 1, "repeated callback cannot kill twice")
	fresh()
	var basic_chance := service.turn_undead_chance(catalog.resolve(base), dummy)
	world.inventory[str(ancient.book_name)] = 1
	check(catalog.learn(str(ancient.id)), "learn Ancient passive")
	var upgraded := catalog.resolve(base)
	var upgraded_chance := service.turn_undead_chance(upgraded, dummy)
	check(upgraded_chance > basic_chance, "Ancient improves actual production chance")
	check(is_equal_approx(float(upgraded.turn_accuracy_bonus), .12), "one replacement bonus, not stacked twice")
	check(Service.presentation_id(upgraded) == str(ancient.id), "upgraded presentation uses Ancient resources")
	check(not world._cast_job_skill(str(ancient.name)) and world.mp == 999, "passive is not separately castable")
	check(Rules.can_auto_cast(base) and not Rules.can_auto_cast(ancient), "only base can be registered for AUTO")
	world._on_quickslot_assignment_requested(0, "skill_auto", str(base.name))
	check(world.quickslots[0].get("id") == base.name and world.quickslots[0].get("auto", false), "register base AUTO quickslot")
	check(world._run_auto_combat_quickslots(), "actual AUTO combat invokes shared cast")
	check(world.mp == 999 - int(base.mp), "AUTO uses exact manual cost")
	release_and_land(false)
	fresh()
	# A race change during flight must be validated again at the hit event.
	check(world._cast_job_skill(str(base.name)), "cast before race change")
	world._release_player_attack(int(world.pending_attack.id))
	dummy.undead = false
	dummy.monster_type = "동물"
	hp_before = dummy.hp
	for _step: int in range(12): world.combat_flights._physics_process(.02)
	check(dummy.hp == hp_before, "race change cancels instant death at impact")
	fresh()
	check(world._cast_job_skill(str(base.name)), "cast before class change")
	world._release_player_attack(int(world.pending_attack.id))
	var generation := world.combat_generation
	world._on_job_class_selected("기사")
	check(world.combat_generation > generation and world.combat_flights.flights.is_empty(), "class change cancels stale flights")
	check(int(catalog.learned[str(base.id)]) == 1 and int(catalog.learned[str(ancient.id)]) == 1, "class change retains learned IDs")
	world._on_job_class_selected("마법사")
	fresh()
	world._on_quickslot_assignment_requested(0, "skill_auto", str(base.name))
	check(world.quickslots[0].get("id") == base.name and world.quickslots[0].get("auto", false), "restore wizard AUTO slot")
	world.skill_cooldowns[str(base.name)] = 2.75
	world._save_game(true)
	catalog.learned.clear()
	world.quickslots.clear()
	world.skill_cooldowns.clear()
	world._load_game(true)
	check(int(catalog.learned.get(str(base.id), 0)) == 1 and int(catalog.learned.get(str(ancient.id), 0)) == 1, "save/load preserves base and upgrade")
	check(world.quickslots[0].skill_id == base.id and world.quickslots[0].auto, "save/load preserves stable quickslot ID and AUTO flag")
	check(is_equal_approx(float(world.skill_cooldowns.get(str(base.name), 0)), 2.75), "save/load preserves cooldown")
	check(world.pending_attack.is_empty() and world.combat_flights.flights.is_empty(), "save/load never replays an in-flight kill")
	# Both simulations call the same chance calculation and RNG predicate as impact.
	fresh()
	var random := RandomNumberGenerator.new()
	for upgraded_state: bool in [false, true]:
		catalog.learned[str(ancient.id)] = 1 if upgraded_state else 0
		var chance := service.turn_undead_chance(catalog.resolve(base), dummy)
		random.seed = 20261010
		var successes := 0
		for _trial: int in range(100000):
			if Service.roll_turn_undead(random, chance): successes += 1
		var measured := float(successes) / 100000
		var margin := 6 * sqrt(chance * (1 - chance) / 100000)
		check(absf(measured - chance) < margin, "100000 production rolls " + str(upgraded_state))
		print("TURN_UNDEAD_SAMPLE ancient=", upgraded_state, " expected=", chance, " measured=", measured, " trials=100000")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_TURN_UNDEAD_OK checks=", checks, " trials=200000")
	quit(0 if failures.is_empty() else 1)
