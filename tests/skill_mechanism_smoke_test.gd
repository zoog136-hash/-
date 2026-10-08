extends SceneTree

const SKILL_RULES = preload("res://scripts/skill_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)
		print("SKILL MECHANISM FAIL: " + detail)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_expect(false, "Skill rules or main scene failed to load")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var db: Array = world.get("skills_db") as Array
	_expect(db.size() == 257, "skill DB count unexpectedly changed")
	_expect((world.call("_skill_record", "라이트") as Dictionary).is_empty(), "removed Light skill remains castable")
	var passive_count: int = 0
	for value: Variant in db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if str(skill.get("activation", "")) == "passive":
			passive_count += 1
		_expect(SKILL_RULES.is_supported(str(skill.get("effect", ""))), "unknown effect " + str(skill.get("name", "")))
	_expect(passive_count == 40, "expected 40 class/passive skills after reclassification")
	_expect(str((world.call("_skill_record", "쇼크 스턴") as Dictionary).get("effect", "")) == "stun", "stun not routed to status effect")
	_expect(str((world.call("_skill_record", "사일런스") as Dictionary).get("effect", "")) == "silence", "silence not routed to status effect")

	world.call("_on_job_class_selected", "기사")
	var initial_gear: Dictionary = world.get("equipped_items") as Dictionary
	initial_gear["weapon"] = {"type":"한손검","name":"테스트 검","slot":"weapon"}
	world.set("equipped_items", initial_gear)
	world.set("mp", 999)
	world.set("skill_cooldowns", {})
	world.set("skill_global_cooldown", 0.0)
	var before_mp: int = int(world.get("mp"))
	_expect(bool(world.call("_cast_job_skill", "실드")), "cast of shield failed")
	_expect(int(world.get("mp")) == before_mp - 8, "shield MP cost wrong")
	var buffs: Dictionary = world.get("active_skill_buffs") as Dictionary
	_expect(buffs.has("실드"), "shield buff missing")
	var after_cast: int = int(world.get("mp"))
	_expect(not bool(world.call("_cast_job_skill", "실드")), "shield cooldown not enforced")
	_expect(int(world.get("mp")) == after_cast, "cooldown failure consumed MP")
	world.call("_tick_skill_cooldowns", 10.0)
	_expect(bool(world.call("_cast_job_skill", "실드")), "recast after cooldown failed")

	world.call("_tick_skill_cooldowns", 10.0)
	world.set("hp", int(world.call("_effective_max_hp")))
	var full_mp: int = int(world.get("mp"))
	_expect(not bool(world.call("_cast_job_skill", "힐")), "heal should reject full HP")
	_expect(int(world.get("mp")) == full_mp, "full HP heal spent MP")
	world.set("hp", maxi(1, int(world.call("_effective_max_hp")) - 180))
	var before_hp: int = int(world.get("hp"))
	_expect(bool(world.call("_cast_job_skill", "힐")), "healing skill failed")
	_expect(int(world.get("hp")) > before_hp, "heal produced no HP")
	_expect(not bool(world.call("_cast_job_skill", "힐")), "heal ignored cooldown")

	# Remove nearby monsters and verify unsuccessful target selection consumes no MP.
	var monsters: Node = world.get("monsters_root") as Node
	for child: Node in monsters.get_children():
		monsters.remove_child(child)
		child.queue_free()
	world.set("selected_monster", null)
	world.call("_tick_skill_cooldowns", 10.0)
	before_mp = int(world.get("mp"))
	_expect(not bool(world.call("_cast_job_skill", "쇼크 스턴")), "stun cast without target")
	_expect(int(world.get("mp")) == before_mp, "targetless stun spent MP")

	# Place a robust dummy directly on the player to avoid terrain LOS ambiguity.
	var monster_scene: PackedScene = load("res://scenes/Monster.tscn") as PackedScene
	var dummy: TwilightMonster = monster_scene.instantiate() as TwilightMonster
	monsters.add_child(dummy)
	var player: TwilightPlayer = world.get("player") as TwilightPlayer
	dummy.setup({"name":"훈련용 몬스터", "lv":1, "hp":999999, "atk":1}, player, world, null)
	dummy.global_position = player.global_position
	world.set("selected_monster", dummy)
	world.call("_tick_skill_cooldowns", 10.0)
	before_mp = int(world.get("mp"))
	_expect(bool(world.call("_cast_job_skill", "쇼크 스턴")), "stun did not use dedicated status path")
	preload("res://tests/combat_test_clock.gd").settle(world)
	_expect(int(world.get("mp")) == before_mp - 10, "stun MP not consumed on attempt")
	var cds: Dictionary = world.get("skill_cooldowns") as Dictionary
	_expect(float(cds.get("쇼크 스턴", 0.0)) >= 9.0, "stun cooldown not started")

	world.call("_tick_skill_cooldowns", 15.0)
	world.call("_on_quickslot_assignment_requested", 0, "skill_auto", "에너지 볼트")
	var slots: Array = world.get("quickslots") as Array
	_expect(bool((slots[0] as Dictionary).get("auto", false)), "AUTO flag was not stored")
	before_mp = int(world.get("mp"))
	_expect(bool(world.call("_run_auto_combat_quickslots")), "AUTO attack did not cast")
	preload("res://tests/combat_test_clock.gd").settle(world)
	_expect(int(world.get("mp")) == before_mp - 3, "AUTO attack MP cost incorrect")
	_expect(not bool(world.call("_run_auto_combat_quickslots")), "AUTO attack ignored cooldown")

	world.call("_tick_skill_cooldowns", 15.0)
	world.call("_on_quickslot_assignment_requested", 1, "skill_auto", "힐")
	world.set("hp", maxi(1, int(world.call("_effective_max_hp")) / 2))
	before_hp = int(world.get("hp"))
	world.call("_run_auto_heal_quickslots")
	_expect(int(world.get("hp")) > before_hp, "AUTO heal did not activate at low HP")

	# Dynamic passive events may be added to DB without applying permanent stats.
	world.call("_on_job_class_selected", "요정")
	var new_skills: Array = world.get("skills_db") as Array
	new_skills.append({
		"name":"기계 테스트 패시브", "class":"요정", "grade":"일반", "type":"버프",
		"effect":"heal", "activation":"passive", "trigger":"on_damaged",
		"proc_effect":"heal", "heal":35, "proc_chance":1.0, "cooldown":2.0
	})
	world.set("skills_db", new_skills)
	world.set("hp", maxi(1, int(world.call("_effective_max_hp")) / 2))
	world.call("_tick_skill_cooldowns", 20.0)
	before_hp = int(world.get("hp"))
	world.call("_try_trigger_passives", "on_damaged", null)
	_expect(int(world.get("hp")) == before_hp + 35, "event passive did not heal")
	world.call("_try_trigger_passives", "on_damaged", null)
	_expect(int(world.get("hp")) == before_hp + 35, "event passive ignored internal cooldown")

	world.call("_tick_skill_cooldowns", 20.0)
	before_mp = int(world.get("mp"))
	_expect(bool(world.call("_cast_job_skill", "인비지블리티")), "invisibility skill failed")
	_expect(int(world.get("mp")) == before_mp - 15, "invisibility MP mismatch")
	_expect(bool(world.call("is_player_concealed")), "invisibility flag not active")
	world.call("_tick_skill_cooldowns", 20.0)
	world.set("selected_monster", dummy)
	dummy.global_position = player.global_position
	_expect(bool(world.call("_cast_job_skill", "사일런스")), "offensive silence could not be cast from stealth")
	preload("res://tests/combat_test_clock.gd").settle(world)
	_expect(not bool(world.call("is_player_concealed")), "offensive status skill did not break stealth")


	# Turn Undead must be restricted to the monster race and instantly defeat
	# an undead on a successful magic hit, not just deal high fixed damage.
	world.call("_on_job_class_selected", "마법사")
	world.set("mp", 999)
	world.call("_tick_skill_cooldowns", 60.0)
	world.set("selected_monster", dummy)
	before_mp = int(world.get("mp"))
	_expect(not bool(world.call("_cast_job_skill", "턴 언데드")), "Turn Undead accepted a living monster")
	_expect(int(world.get("mp")) == before_mp, "rejected Turn Undead consumed MP")
	var undead_dummy: TwilightMonster = monster_scene.instantiate() as TwilightMonster
	monsters.add_child(undead_dummy)
	undead_dummy.setup({"name":"검증용 해골", "type":"언데드", "lv":1, "hp":999999, "mr":0}, player, world, null)
	undead_dummy.global_position = player.global_position
	_expect(undead_dummy.is_undead(), "monster metadata does not identify undead")
	for _attempt: int in range(16):
		if undead_dummy.dead:
			break
		world.call("_tick_skill_cooldowns", 60.0)
		world.set("selected_monster", undead_dummy)
		_expect(bool(world.call("_cast_job_skill", "턴 언데드")), "Turn Undead failed to cast on undead")
		preload("res://tests/combat_test_clock.gd").settle(world)
	_expect(undead_dummy.dead, "a magic hit must instantly defeat undead regardless of HP")

	# Counter Barrier must reflect damage only on a successful melee hit.
	world.call("_on_job_class_selected", "기사")
	world.set("mp", 999)
	world.set("hp", int(world.call("_effective_max_hp")))
	world.call("_tick_skill_cooldowns", 60.0)
	_expect(bool(world.call("_cast_job_skill", "카운터 배리어")), "counter buff could not be cast")
	buffs = world.get("active_skill_buffs") as Dictionary
	_expect(buffs.has("카운터 배리어"), "counter buff record missing")
	var counter_buff: Dictionary = buffs.get("카운터 배리어", {}) as Dictionary
	_expect(float(counter_buff.get("counter_chance", 0.0)) > 0.0, "counter proc chance not stored")
	counter_buff["counter_chance"] = 1.0
	buffs["카운터 배리어"] = counter_buff
	world.set("active_skill_buffs", buffs)
	var target_hp_before: int = dummy.hp
	_expect(not bool(world.call("_try_active_counterattack", dummy, "ranged", 20)), "counter incorrectly procced on ranged damage")
	_expect(dummy.hp == target_hp_before, "counter reflected ranged damage")
	_expect(bool(world.call("_try_active_counterattack", dummy, "melee", 20)), "melee counter did not proc at 100%")
	_expect(dummy.hp < target_hp_before, "counter did not hurt attacker")
	var master_counter: Dictionary = world.call("_skill_record", "카운터 배리어(마스터)") as Dictionary
	_expect(float(master_counter.get("counter_chance", 0.0)) > float((world.call("_skill_record", "카운터 배리어") as Dictionary).get("counter_chance", 0.0)), "master counter proc rate is not stronger")
	_expect(float(master_counter.get("counter_multiplier", 0.0)) > 1.5, "master counter does not upgrade reflected damage")

	# Both Triple Arrow grades must make three independent damage checks.
	world.call("_on_job_class_selected", "요정")
	var bow_gear: Dictionary = world.get("equipped_items") as Dictionary
	bow_gear["weapon"] = {"type":"활","name":"테스트 활","slot":"weapon"}
	world.set("equipped_items", bow_gear)
	var arrows_before: int = int((world.get("inventory") as Dictionary).get("화살", 0))
	world.set("mp", 999)
	var triple: Dictionary = world.call("_skill_record", "트리플 애로우") as Dictionary
	var triple_spirit: Dictionary = world.call("_skill_record", "트리플 애로우(스피릿)") as Dictionary
	_expect(int(triple.get("hits", 0)) == 3, "basic Triple Arrow is not 3-hit")
	_expect(int(triple_spirit.get("hits", 0)) == 3, "Spirit Triple Arrow is not 3-hit")
	var multiple_landed: bool = false
	for _attempt: int in range(6):
		world.call("_tick_skill_cooldowns", 60.0)
		world.set("selected_monster", dummy)
		var count_before: int = dummy.damage_hit_count
		_expect(bool(world.call("_cast_job_skill", "트리플 애로우(스피릿)")), "Spirit Triple Arrow cast failed")
		preload("res://tests/combat_test_clock.gd").settle(world)
		if dummy.damage_hit_count - count_before >= 2:
			multiple_landed = true
			break
	_expect(multiple_landed, "Triple Arrow did not land multiple independently rolled hits")
	_expect(int((world.get("inventory") as Dictionary).get("화살", 0)) < arrows_before, "Triple Arrow failed to consume arrows")

	# Find a clear, walkable target position so charge is tested against real
	# world coordinates instead of teleporting through impassable map tiles.
	world.call("_on_job_class_selected", "기사")
	world.set("mp", 999)
	world.call("_tick_skill_cooldowns", 60.0)
	var start_position: Vector2 = player.global_position
	var charge_position: Vector2 = Vector2.ZERO
	for radius: int in [180, 140, 220]:
		for angle_index: int in range(24):
			var candidate: Vector2 = start_position + Vector2.from_angle(float(angle_index) * TAU / 24.0) * float(radius)
			if not bool(world.call("_is_walkable_world", candidate)):
				continue
			if not bool(world.call("_has_line_of_sight_world", start_position, candidate)):
				continue
			var path_check: PackedVector2Array = world.call("find_world_path", start_position, candidate) as PackedVector2Array
			if path_check.size() < 2:
				continue
			charge_position = candidate
			break
		if charge_position != Vector2.ZERO:
			break
	_expect(charge_position != Vector2.ZERO, "no open charge destination found for integration test")
	if charge_position != Vector2.ZERO:
		var charge_dummy: TwilightMonster = monster_scene.instantiate() as TwilightMonster
		monsters.add_child(charge_dummy)
		charge_dummy.setup({"name":"돌진 검증용", "lv":1, "hp":999999, "mr":0}, player, world, null)
		charge_dummy.global_position = charge_position
		world.set("selected_monster", charge_dummy)
		var cast_charge: bool = bool(world.call("_cast_job_skill", "기사의 돌진 12"))
		_expect(cast_charge, "charge skill could not start in open terrain")
		if cast_charge:
			for _step: int in range(120):
				world.call("_advance_skill_charge", 1.0 / 60.0)
				if (world.get("charge_skill") as Dictionary).is_empty():
					break
			_expect((world.get("charge_skill") as Dictionary).is_empty(), "charge never completed")
			preload("res://tests/combat_test_clock.gd").settle(world)
			_expect(player.global_position.distance_to(start_position) > 40.0, "charge did not move player")
			_expect(charge_dummy.damage_hit_count > 0, "charge did not strike after arriving")

		# A ranged AUTO skill must cast outside the equipped melee weapon range.
		world.call("_on_job_class_selected", "요정")
		world.set("mp", 999)
		world.call("_tick_skill_cooldowns", 60.0)
		world.call("_on_quickslot_assignment_requested", 0, "skill_auto", "에너지 볼트")
		world.set("auto_target", dummy)
		world.set("selected_monster", dummy)
		var priority_position: Vector2 = Vector2.ZERO
		for radius: int in [185, 155, 230]:
			for angle_index: int in range(24):
				var candidate: Vector2 = player.global_position + Vector2.from_angle(float(angle_index) * TAU / 24.0) * float(radius)
				if bool(world.call("_is_walkable_world", candidate)) and bool(world.call("_has_line_of_sight_world", player.global_position, candidate)):
					priority_position = candidate
					break
			if priority_position != Vector2.ZERO:
				break
		_expect(priority_position != Vector2.ZERO, "no candidate for AUTO distance priority integration test")
		if priority_position != Vector2.ZERO:
			dummy.global_position = priority_position
			_expect(not bool(world.call("_target_in_current_weapon_range", dummy)), "AUTO priority target unexpectedly in 1-cell weapon range")
			before_mp = int(world.get("mp"))
			world.call("_run_auto_hunt")
			_expect(int(world.get("mp")) == before_mp - 3, "AUTO did not prioritize available spell outside weapon range")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SKILL_MECHANISM_SMOKE_OK: active, passive, status, MP, cooldown and AUTO validated")
		quit(0)
	else:
		print("SKILL_MECHANISM_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
