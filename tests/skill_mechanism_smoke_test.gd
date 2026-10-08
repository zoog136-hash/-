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
	_expect(db.size() == 258, "skill DB count unexpectedly changed")
	var passive_count: int = 0
	for value: Variant in db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if str(skill.get("activation", "")) == "passive":
			passive_count += 1
		_expect(SKILL_RULES.is_supported(str(skill.get("effect", ""))) or str(skill.get("effect", "")) == "utility", "unknown effect " + str(skill.get("name", "")))
	_expect(passive_count > 0, "missing passive skills")
	_expect(str((world.call("_skill_record", "쇼크 스턴") as Dictionary).get("effect", "")) == "stun", "stun not routed to status effect")
	_expect(str((world.call("_skill_record", "사일런스") as Dictionary).get("effect", "")) == "silence", "silence not routed to status effect")

	world.call("_on_job_class_selected", "기사")
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
	_expect(int(world.get("mp")) == before_mp - 10, "stun MP not consumed on attempt")
	var cds: Dictionary = world.get("skill_cooldowns") as Dictionary
	_expect(float(cds.get("쇼크 스턴", 0.0)) >= 9.0, "stun cooldown not started")

	world.call("_tick_skill_cooldowns", 15.0)
	world.call("_on_quickslot_assignment_requested", 0, "skill_auto", "에너지 볼트")
	var slots: Array = world.get("quickslots") as Array
	_expect(bool((slots[0] as Dictionary).get("auto", false)), "AUTO flag was not stored")
	before_mp = int(world.get("mp"))
	_expect(bool(world.call("_run_auto_combat_quickslots")), "AUTO attack did not cast")
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
	world.call("_break_invisibility")
	_expect(not bool(world.call("is_player_concealed")), "attack did not break stealth")

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
