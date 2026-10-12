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
		print("COEXISTENCE FAIL: ", message)

func respawn() -> void:
	dummy.setup({"name":"복합 상태 검사 NPC","hp":10000,"lv":1,"mr":100,"ac":-100,"stun_resistance":0,"fear_resistance":0}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(30, 0)
	dummy.set_physics_process(false)
	world.selected_monster = dummy

func fixture(name_value: String, duration: float) -> Dictionary:
	var skill := world.original_skills.catalog.record_for(name_value).duplicate(true)
	# Only RNG and time are fixed; retain the real stored modifier fields.
	skill["status_chance"] = 1.0
	skill["duration"] = duration
	skill["duration_bounds"] = []
	return skill

func cast(name_value: String, duration: float) -> void:
	var catalog := world.original_skills.catalog
	var source := catalog.record_for(name_value)
	world.inventory[str(source.book_name)] = 1
	check(catalog.learn(str(source.id)), name_value + " real book learning")
	var skill: Dictionary = world._skill_record(str(source.id))
	skill["status_chance"] = 1.0
	skill["duration"] = duration
	skill["duration_bounds"] = []
	world.mp = 999
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill(str(source.id)), name_value + " paid cast")
	check(world.mp == 999 - int(skill.mp), name_value + " one MP payment")
	world._release_player_attack(int(world.pending_attack.id))
	for _step: int in range(20): world.combat_flights._physics_process(.02)

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.level = 90
	world._on_job_class_selected("암흑기사")
	world.equipped_items.clear()
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	respawn()
	var service := world.original_skills
	var status := service.status
	cast("다크 스턴", 2.0)
	cast("다크 핸드", 5.0)
	check(dummy.is_stunned() and dummy.fear_remaining > 0, "both actual NPC controls remain active")
	check(status.modifier(dummy, "mr") == -10 and status.modifier(dummy, "reduction") == -3, "fear impact preserves stun modifiers")
	check(is_equal_approx(status.modifier(dummy, "taken"), .1), "fear adds its own modifier")
	check(service.target_damage(100, dummy) == 103, "coexisting stun still changes the production damage path")
	status.tick(2.1)
	check(status.modifier(dummy, "mr") == 0 and status.modifier(dummy, "reduction") == 0, "stun modifier expires on its own timer")
	check(is_equal_approx(status.modifier(dummy, "taken"), .1), "longer fear modifier survives stun expiry")
	status.tick(3.0)
	check(status.modifier(dummy, "taken") == 0 and status.debuffs.is_empty(), "last source expiry removes the target entry")
	var dark := fixture("다크 스턴", 2.0)
	var fear := fixture("다크 핸드", 1.0)
	check(status.apply(dark, dummy, world) and status.apply(fear, dummy, world), "apply short fear after longer stun")
	status.tick(1.1)
	check(status.modifier(dummy, "taken") == 0 and status.modifier(dummy, "mr") == -10, "short fear cannot inherit the longer stun timer")
	check(status.apply(fixture("슬로우", 6.0), dummy, world), "apply a status with no stat modifiers")
	check(status.modifier(dummy, "reduction") == -3, "modifier-free status does not erase existing weakness")
	status.tick(1.0)
	check(status.modifier(dummy, "mr") == 0, "modifier-free status cannot extend existing weakness")
	check(status.apply(dark, dummy, world), "reapply the original source")
	status.tick(1.0)
	check(status.apply(dark, dummy, world), "refresh the same source")
	status.tick(1.5)
	check(status.modifier(dummy, "reduction") == -3, "same source uses max remaining without additive stacking")
	status.tick(.6)
	check(status.modifier(dummy, "reduction") == 0, "same source does not accumulate durations")
	check(status.apply(dark, dummy, world), "apply before a resisted status")
	dummy.status_immunities = ["fear"]
	check(not status.apply(fear, dummy, world) and status.modifier(dummy, "mr") == -10, "rejected effect preserves live sources")
	dummy.status_immunities = []
	respawn()
	check(status.modifier(dummy, "mr") == 0 and status.debuffs.is_empty(), "pooled new life discards every old source")
	# Two controlled sources exercise the local, non-additive latest-live-value
	# collision rule. This fixture does not assert original game stacking rules.
	var earlier := fixture("다크 스턴", 3.0)
	var later := fixture("썬더 스턴", 1.0)
	later["debuff"] = {"reduction":-7}
	check(status.apply(earlier, dummy, world) and status.apply(later, dummy, world), "apply controlled overlapping fields")
	check(status.modifier(dummy, "reduction") == -7 and status.modifier(dummy, "mr") == -10, "latest field wins without discarding unrelated fields")
	status.tick(1.1)
	check(status.modifier(dummy, "reduction") == -3, "expiry reveals the still-live earlier value")
	world._on_job_class_selected("뇌신")
	check(status.debuffs.is_empty(), "class switch clears all sources")
	world.equipped_items.clear()
	respawn()
	var mark := service.catalog.record_for("썬더 마크")
	service.catalog.learned[str(mark.id)] = 1
	mark["proc_chance"] = 1.0
	mark["proc_cooldown"] = 0.0
	check(status.apply(fixture("썬더 스턴", 2.0), dummy, world), "apply thunder stun before on-hit marks")
	service.trigger("on_hit", dummy)
	check(status.modifier(dummy, "dg") == -3 and status.modifier(dummy, "reduction") == -3, "real first mark preserves stun weakness")
	service.trigger("on_hit", dummy)
	check(status.modifier(dummy, "dg") == -6 and status.modifier(dummy, "reduction") == -3, "second mark updates only its own values")
	service.trigger("on_hit", dummy)
	check(not service.marks.has(dummy.get_instance_id()) and status.modifier(dummy, "dg") == 0, "burst consumes its mark modifiers")
	check(status.modifier(dummy, "reduction") == -3, "modifier-free burst stun preserves original thunder weakness")
	status.tick(2.1)
	check(status.modifier(dummy, "reduction") == 0, "mark timer cannot extend thunder weakness")
	check(status.apply(dark, dummy, world) and status.apply(fear, dummy, world), "apply before combat cleanup")
	world._clear_combat_actions()
	check(status.debuffs.is_empty(), "map/combat cleanup removes every source")
	check(status.apply(dark, dummy, world), "apply before target death")
	dummy.dead = true
	status.tick(0)
	check(status.debuffs.is_empty(), "death removes all source state")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_STATUS_COEXISTENCE_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
