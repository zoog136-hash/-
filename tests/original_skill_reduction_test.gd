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
		print("REDUCTION FAIL: ", message)

func respawn() -> void:
	dummy.setup({"name":"리덕션 검사 NPC","hp":10000,"lv":1,"mr":0,"ac":0,"stun_resistance":0}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(30, 0)
	dummy.set_physics_process(false)
	world.selected_monster = dummy

func normal_hit(amount: int, critical: bool = false) -> int:
	var before := dummy.hp
	world._deal_successful_player_hit(dummy, amount, critical)
	return before - dummy.hp

func spell_hit(spell: Dictionary, seed_value: int) -> int:
	world.rng.seed = seed_value
	var before := dummy.hp
	world.original_skills.deal_damage(spell, dummy)
	return before - dummy.hp

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.level = 90
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300, 4370)))
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	var service := world.original_skills
	var catalog := service.catalog
	for pair: Array in [["암흑기사","다크 스턴"],["뇌신","썬더 스턴"]]:
		world._clear_combat_actions()
		world._on_job_class_selected(str(pair[0]))
		world.equipped_items.clear()
		respawn()
		var source := catalog.record_for(str(pair[1]))
		world.inventory[str(source.book_name)] = 1
		check(catalog.learn(str(source.id)), str(pair[1]) + " learned through the real book path")
		var stun: Dictionary = world._skill_record(str(source.id))
		# Only fix the RNG success/duration in the paid-cast fixture. The real
		# stored CUSTOM_BALANCE debuff and actual release/impact path stay intact.
		stun["status_chance"] = 1.0
		stun["duration"] = 2.0
		stun["duration_bounds"] = []
		var plain := normal_hit(100)
		var magic := catalog.record_for("에너지 볼트")
		var plain_magic := spell_hit(magic, 313)
		world.mp = 999
		world.skill_cooldowns.clear()
		world.skill_global_cooldown = 0
		check(world._cast_job_skill(str(stun.id)), str(pair[1]) + " actual paid cast")
		check(world.mp == 999 - int(stun.mp), "one actual MP cost")
		check(service.status.modifier(dummy, "reduction") == 0, "debuff is not applied before the marker")
		world._release_player_attack(int(world.pending_attack.id))
		for _step: int in range(20): world.combat_flights._physics_process(.02)
		check(dummy.is_stunned() and service.status.modifier(dummy, "reduction") == -3, "real impact applies the stored reduction modifier")
		check(normal_hit(100) == plain + 3, "normal hit consumes the flat modifier exactly once")
		check(normal_hit(200, true) == 203, "critical result consumes the flat modifier after critical scaling")
		check(spell_hit(magic, 313) == plain_magic + 3, "actual magic skill damage consumes the same modifier once")
		world.equipped_items["weapon"] = {"name":"증폭 검사 무기","type":"한손검","slot":"weapon","damage_amp_pct":100}
		check(normal_hit(100) == 203, "equipment amplification does not multiply the flat debuff")
		world.equipped_items.clear()
		service.status.tick(2.01)
		check(normal_hit(100) == plain, "expired modifier restores the real hit damage")
		check(service.status.apply(stun, dummy, world), "reapply to current life")
		var old_life := dummy.life_id
		respawn()
		check(dummy.life_id > old_life and normal_hit(100) == plain, "same pooled NPC new life cannot inherit reduction")
		check(service.status.apply(stun, dummy, world), "apply before cleanup")
		world._clear_combat_actions()
		check(normal_hit(100) == plain, "combat/map cleanup removes target modifiers")
		check(service.status.apply(stun, dummy, world), "apply before class change")
		world._on_job_class_selected("기사")
		world.equipped_items.clear()
		check(normal_hit(100) == plain, "class change removes target modifiers")
	# Instant death bypasses successful-hit modifiers and still uses one NPC
	# death call. A flat vulnerability must not change its probability or HP.
	world._on_job_class_selected("마법사")
	world.equipped_items.clear()
	respawn()
	dummy.undead = true
	var turn := catalog.record_for("턴 언데드").duplicate(true)
	turn["turn_min_chance"] = 1.0
	turn["turn_max_chance"] = 1.0
	var death_skill := catalog.record_for("다크 스턴").duplicate(true)
	death_skill["status_chance"] = 1.0
	check(service.status.apply(death_skill, dummy, world), "debuff an undead before instant death")
	var calls := dummy.damage_hit_count
	service.resolve_turn_undead(turn, dummy)
	check(dummy.dead and dummy.hp == 0 and dummy.damage_hit_count == calls + 1, "instant death stays a single exact-HP death path")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_REDUCTION_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
