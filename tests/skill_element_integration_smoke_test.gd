extends SceneTree

const ELEMENT_RULES = preload("res://scripts/elemental_rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("ELEMENT INTEGRATION FAIL: " + label)

func _clear_cooldowns(world: Node) -> void:
	world.set("skill_cooldowns", {})
	world.set("skill_global_cooldown", 0.0)

func _dummy(scene: PackedScene, root_node: Node, player: TwilightPlayer, world: Node, name_value: String, record: Dictionary) -> TwilightMonster:
	var mob: TwilightMonster = scene.instantiate() as TwilightMonster
	root_node.add_child(mob)
	var merged: Dictionary = {"name":name_value,"lv":1,"hp":900000,"mr":0,"atk":1}
	merged.merge(record, true)
	mob.setup(merged, player, world, null)
	mob.global_position = player.global_position
	return mob

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main scene unavailable")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	preload("res://tests/legacy_skill_fixture.gd").install(world)
	var spells: Array = world.get("skills_db") as Array
	var passive_total: int = 0
	for value: Variant in spells:
		if value is Dictionary and str((value as Dictionary).get("activation", "")) == "passive":
			passive_total += 1
	_check(spells.size() == 257 and passive_total == 40, "reclassification must preserve 257 entries and 40 passives")
	_check(str((world.call("_skill_record", "콜 라이트닝") as Dictionary).get("attack_style", "")) == "magic", "magic projectile style not declared")
	var sphere_count: int = 0
	for skill_value: Variant in spells:
		if not (skill_value is Dictionary):
			continue
		var skill_data: Dictionary = skill_value as Dictionary
		if not str(skill_data.get("name", "")).contains("의 구체 "):
			continue
		sphere_count += 1
		_check(ELEMENT_RULES.channel(str(skill_data.get("element", "physical"))) != "physical", "orb has no elemental channel: " + str(skill_data.get("name", "")))
		_check(str(skill_data.get("attack_style", "")) == "magic", "orb is not using magic accuracy: " + str(skill_data.get("name", "")))
	_check(sphere_count == 60, "all 60 expansion orb skills must have distinct elements")
	var judge: Dictionary = world.call("_skill_record", "기사의 심판 4") as Dictionary
	_check(float(judge.get("execute_threshold", 0.0)) >= 0.3 and float(judge.get("execute_multiplier", 1.0)) >= 1.5, "judgment execute rule missing")
	_check(ELEMENT_RULES.damage_after_resistance(100, 40) == 60, "40% resist not applied")
	_check(ELEMENT_RULES.damage_after_resistance(100, -25) == 125, "weakness does not amplify damage")
	_check(ELEMENT_RULES.damage_with_bonus(100, 20) == 120, "20% elemental attack bonus not applied")

	var player: TwilightPlayer = world.get("player") as TwilightPlayer
	var monsters: Node = world.get("monsters_root") as Node
	for mob: Node in monsters.get_children():
		monsters.remove_child(mob)
		mob.queue_free()
	var monster_scene: PackedScene = load("res://scenes/Monster.tscn") as PackedScene
	var primary: TwilightMonster = _dummy(monster_scene, monsters, player, world, "번개 대상 1", {"element_resistance":{"fire":40,"ice":-25,"lightning":0}})
	var neighbor: TwilightMonster = _dummy(monster_scene, monsters, player, world, "번개 대상 2", {})
	var third: TwilightMonster = _dummy(monster_scene, monsters, player, world, "번개 대상 3", {})
	_check(int(world.call("_elemental_damage_to_monster", 100, "fire", primary)) == 60, "fire resist ignored by world damage")
	_check(int(world.call("_elemental_damage_to_monster", 100, "ice", primary)) == 125, "ice weakness ignored by world damage")
	world.call("_on_job_class_selected", "마법사")
	world.set("mp", 999)
	world.set("selected_monster", primary)
	_clear_cooldowns(world)
	_check(bool(world.call("_cast_job_skill", "파이어 볼")), "Fire Ball unavailable")
	preload("res://tests/combat_test_clock.gd").settle(world)
	_check(neighbor.damage_hit_count > 0 or third.damage_hit_count > 0, "AoE failed to damage nearby monsters")
	_clear_cooldowns(world)
	var hits_before: Array[int] = [primary.damage_hit_count, neighbor.damage_hit_count, third.damage_hit_count]
	for attempt: int in range(4):
		world.set("selected_monster", primary)
		_clear_cooldowns(world)
		_check(bool(world.call("_cast_job_skill", "콜 라이트닝")), "chain lightning could not cast")
		preload("res://tests/combat_test_clock.gd").settle(world)
		if primary.damage_hit_count > hits_before[0] and neighbor.damage_hit_count > hits_before[1] and third.damage_hit_count > hits_before[2]:
			break
	_check(primary.damage_hit_count > hits_before[0] and neighbor.damage_hit_count > hits_before[1] and third.damage_hit_count > hits_before[2], "chain lightning must reach all 3 nearby enemies")
	var cold: Dictionary = world.call("_skill_record", "콘 오브 콜드") as Dictionary
	cold["status_chance"] = 1.0
	for attempt: int in range(5):
		_clear_cooldowns(world)
		world.set("selected_monster", primary)
		world.call("_cast_job_skill", "콘 오브 콜드")
		preload("res://tests/combat_test_clock.gd").settle(world)
		if primary.slow_remaining > 0.0:
			break
	_check(primary.slow_remaining > 0.0 and primary.move_speed < primary.base_move_speed, "ice slow did not affect movement speed")
	primary.call("_tick_slow", 6.0)
	_check(primary.slow_remaining == 0.0 and absf(primary.move_speed - primary.base_move_speed) < 0.01, "ice slow did not expire cleanly")
	var poison_orb: Dictionary = world.call("_skill_record", "독의 구체 1단계") as Dictionary
	poison_orb["status_chance"] = 1.0
	for attempt: int in range(5):
		_clear_cooldowns(world)
		world.set("selected_monster", primary)
		world.call("_cast_job_skill", "독의 구체 1단계")
		preload("res://tests/combat_test_clock.gd").settle(world)
		if primary.poison_remaining > 0.0:
			break
	_check(primary.poison_remaining > 0.0, "poison orb failed to apply damage-over-time status")
	_clear_cooldowns(world)
	world.set("hp", maxi(1, int(world.call("_effective_max_hp")) / 3))
	_check(bool(world.call("_cast_job_skill", "풀 힐")), "Full Heal did not cast")
	_check(int(world.get("hp")) == int(world.call("_effective_max_hp")), "Full Heal did not restore full HP")

	world.call("_on_job_class_selected", "요정")
	var gear: Dictionary = world.get("equipped_items") as Dictionary
	gear["weapon"] = {}
	world.set("equipped_items", gear)
	world.set("mp", 999)
	_clear_cooldowns(world)
	var before_mp: int = int(world.get("mp"))
	_check(not bool(world.call("_cast_job_skill", "트리플 애로우")), "Triple Arrow can cast without a bow")
	_check(int(world.get("mp")) == before_mp, "invalid weapon cast consumed MP")
	gear["weapon"] = {"type":"활","slot":"weapon","name":"검증용 활"}
	world.set("equipped_items", gear)
	var inventory: Dictionary = world.get("inventory") as Dictionary
	inventory["화살"] = 2
	world.set("inventory", inventory)
	_clear_cooldowns(world)
	_check(not bool(world.call("_cast_job_skill", "트리플 애로우")), "Triple Arrow ignored low ammunition")
	inventory["화살"] = 9
	world.set("inventory", inventory)
	_clear_cooldowns(world)
	world.set("selected_monster", primary)
	_check(bool(world.call("_cast_job_skill", "트리플 애로우")), "Triple Arrow failed with bow and arrows")
	preload("res://tests/combat_test_clock.gd").settle(world)
	_check(int((world.get("inventory") as Dictionary).get("화살", -1)) == 6, "Triple Arrow must consume 3 arrows")
	_clear_cooldowns(world)
	_check(bool(world.call("_cast_job_skill", "스톰 샷")), "Storm Shot rejected equipped bow")
	_check(int(world.call("_active_skill_buff_total", "ranged_bonus")) >= 6, "Storm Shot did not modify ranged bonus")

	world.call("_on_job_class_selected", "다크엘프")
	gear = world.get("equipped_items") as Dictionary
	gear["weapon"] = {"type":"이도류","slot":"weapon","name":"검증용 이도류"}
	world.set("equipped_items", gear)
	world.set("mp", 999)
	_clear_cooldowns(world)
	_check(bool(world.call("_cast_job_skill", "더블 브레이크")), "Double Break buff could not cast")
	var buffs: Dictionary = world.get("active_skill_buffs") as Dictionary
	var double_buff: Dictionary = buffs.get("더블 브레이크", {}) as Dictionary
	double_buff["double_chance"] = 1.0
	buffs["더블 브레이크"] = double_buff
	world.set("active_skill_buffs", buffs)
	var old_hits: int = primary.damage_hit_count
	world.call("_try_extra_weapon_hit", primary, 50, "melee")
	_check(primary.damage_hit_count == old_hits + 1, "Double Break did not produce an independent extra hit")
	world.call("_on_job_class_selected", "암흑기사")
	_clear_cooldowns(world)
	_check(bool(world.call("_cast_job_skill", "다크 프로텍션")), "Dark Protection did not cast")
	_check(absf(float(world.call("_player_element_resistance", "dark")) - 25.0) < 0.01, "dark resistance buff not applied")

	world.call("_on_job_class_selected", "기사")
	_clear_cooldowns(world)
	var will: Dictionary = world.call("_skill_record", "기사의 전투의지 6") as Dictionary
	var iron: Dictionary = world.call("_skill_record", "기사의 철벽 11") as Dictionary
	var focus: Dictionary = world.call("_skill_record", "기사의 집중 10") as Dictionary
	_check(str(will.get("trigger", "")) == "on_hit" and str(iron.get("trigger", "")) == "on_damaged", "passive event classification wrong")
	_check(str(focus.get("activation", "")) == "passive" and int(world.call("_passive_skill_total", "atk")) == 10, "permanent focus passive not applied")
	will["proc_chance"] = 1.0
	_clear_cooldowns(world)
	world.call("_try_trigger_passives", "on_hit", primary)
	_check((world.get("active_skill_buffs") as Dictionary).has("기사의 전투의지 6"), "passive on-hit proc did not activate")
	iron["proc_chance"] = 1.0
	world.call("_try_trigger_passives", "on_damaged", primary)
	_check((world.get("active_skill_buffs") as Dictionary).has("기사의 철벽 11"), "passive on-damaged proc did not activate")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SKILL_ELEMENT_INTEGRATION_OK: elements, AoE, chaining, status, buffs, passives and weapon ammunition")
		quit(0)
	else:
		print("SKILL_ELEMENT_INTEGRATION_FAILED: %d failure(s)" % failures.size())
		quit(1)
