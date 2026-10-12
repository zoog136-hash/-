extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var world: TwilightWorld
var dummy: TwilightMonster

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("TARGET_STATE FAIL: ", message)

func respawn() -> void:
	# Exercise the actual pool-reuse reset on the same object, not a new Node.
	dummy.setup({"name":"생명 주기 검사 NPC", "hp":10000, "lv":1, "mr":150, "ac":-100, "stun_resistance":0}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(30, 0)
	dummy.set_physics_process(false)
	world.selected_monster = dummy

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300, 4370)))
	world.level = 90
	world._on_job_class_selected("암흑기사")
	var service := world.original_skills
	var catalog := service.catalog
	var dark := catalog.record_for("다크 스턴")
	check(not dark.is_empty(), "existing dark stun record")
	if dark.is_empty(): quit(1); return
	catalog.learned[str(dark.id)] = 1
	# World keeps a presentation/cast copy; configure that actual cast fixture.
	dark = world._skill_record(str(dark.id))
	# Force a status success only in this fixture; the production apply path,
	# actual paid cast and projectile remain unchanged.
	dark["status_chance"] = 1.0
	dark["duration_bounds"] = []
	dark["duration"] = 2.0
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	respawn()
	var spell := catalog.record_for("에너지 볼트")
	var plain_chance := service.hit_chance(spell, dummy)
	world.mp = 999
	world.equipped_items["weapon"] = {"name":"상태 검사 양손검", "type":"양손검", "slot":"weapon"}
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill(str(dark.id)), "real learned status cast")
	check(world.mp == 999 - int(dark.mp), "status cast spends its actual cost")
	world._release_player_attack(int(world.pending_attack.id))
	for _step: int in range(20): world.combat_flights._physics_process(.02)
	check(dummy.is_stunned() and is_equal_approx(service.status.modifier(dummy, "mr"), -10), "actual impact applies stun and MR reduction")
	check(service.hit_chance(spell, dummy) > plain_chance, "MR debuff changes the production hit formula")
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	dummy.stun_remaining = 0
	for entry: Dictionary in world.quickslots: entry["auto"] = false
	world._on_quickslot_assignment_requested(0, "skill_auto", str(dark.id))
	dummy.status_immunities = ["stun"]
	var mp_before := world.mp
	var rng_before := world.rng.state
	check(not world._run_auto_combat_quickslots(), "actual AUTO skips an explicitly immune status target")
	check(world.mp == mp_before and world.rng.state == rng_before and world.skill_cooldowns.is_empty(), "AUTO immunity check spends no MP/cooldown/RNG")
	dummy.status_immunities = []
	dummy.stun_resistance = 100
	check(not world._run_auto_combat_quickslots() and world.mp == mp_before, "actual AUTO skips a 100-percent resistant status target")
	dummy.stun_resistance = 0
	var key := dummy.get_instance_id()
	var old_life := dummy.life_id
	respawn()
	check(dummy.life_id > old_life and not dummy.is_stunned(), "actual pool reset creates a new life and clears NPC status")
	check(service.status.modifier(dummy, "mr") == 0, "new life has no old MR reduction before any tick")
	check(is_equal_approx(service.hit_chance(spell, dummy), plain_chance), "new life restores the actual hit probability")
	world._on_job_class_selected("뇌신")
	var mark := catalog.record_for("썬더 마크")
	catalog.learned[str(mark.id)] = 1
	mark["proc_chance"] = 1.0
	mark["proc_cooldown"] = 0.0
	service.trigger("on_hit", dummy)
	service.trigger("on_hit", dummy)
	check(int(service.marks.get(key, {}).get("count", 0)) == 2, "two real on-hit marks")
	respawn()
	var hp_before := dummy.hp
	service.trigger("on_hit", dummy)
	check(int(service.marks.get(key, {}).get("count", 0)) == 1, "first hit of a new life starts at one mark")
	check(dummy.hp == hp_before and not dummy.is_stunned(), "new life cannot inherit the old third-hit burst")
	# A new status must not inherit an old life's longer modifier lifetime.
	respawn()
	var short := dark.duplicate(true)
	short["duration"] = .5
	check(service.status.apply(short, dummy, world), "apply short status on respawned NPC")
	check(is_equal_approx(float(service.status.debuffs.get(key, {}).get("remaining", 0)), .5), "old modifier lifetime cannot extend new status")
	service.status.tick(.6)
	check(service.status.modifier(dummy, "mr") == 0, "modifier expires on its current-life timer")
	service.trigger("on_hit", dummy)
	respawn()
	service.tick(0)
	check(not service.marks.has(key) and not service.status.debuffs.has(key), "tick removes stale-life marks and debuffs without a query")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_TARGET_STATE_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
