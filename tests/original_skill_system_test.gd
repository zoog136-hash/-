extends SceneTree

const CLOCK = preload("res://tests/combat_test_clock.gd")
var failures: Array[String] = []
var world: TwilightWorld
var dummy: TwilightMonster

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("ORIGINAL SKILL FAIL: ", message)

func learn(name: String) -> Dictionary:
	var skill: Dictionary = world.original_skills.catalog.record_for(name)
	if skill.is_empty():
		check(false, "missing " + name)
		return {}
	world.inventory[str(skill.book_name)] = 1
	check(world.original_skills.catalog.learn(str(skill.id)), "learn " + name)
	return skill

func reset_cast() -> void:
	world._clear_combat_actions()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.active_skill_buffs.clear()
	world.mp = 999
	world.hp = world._effective_max_hp()

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.save_timer = -100000
	world.level = 90
	world.job_class = "기사"
	world.original_skills.catalog.learned.clear()
	world.original_skills.catalog.seed_starters()
	world.gold = 10000000
	world._clear_monsters()
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"원작 검사 대상","hp":10000000,"lv":1,"ac":0,"mr":0,"atk":1}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(10,0)
	dummy.set_physics_process(false)
	world.selected_monster = dummy
	world.equipped_items["weapon"] = {"name":"검사 양손검","type":"양손검","slot":"weapon"}
	var catalog := world.original_skills.catalog
	check(world.legacy_skills_db.size() == 257, "legacy database preserved")
	check(world._skill_record("기사의 일격 1").is_empty(), "synthetic skill is inactive")
	var shock := catalog.record_for("쇼크 스턴")
	var before_mp: int = world.mp
	check(not world._cast_job_skill(str(shock.name)), "unlearned cast denied")
	check(world.mp == before_mp, "denied cast costs nothing")
	var price: int = shock.book_cost
	var before_gold := world.gold
	check(catalog.buy_book(str(shock.id)), "book purchased")
	check(world.gold == before_gold - price, "exact book price")
	check(catalog.learn(str(shock.id)), "book learning")
	check(int(world.inventory[shock.book_name]) == 0, "book consumed exactly once")
	check(not catalog.learn(str(shock.id)), "double learning denied")
	reset_cast()
	world.selected_monster = dummy
	check(world._cast_job_skill("쇼크 스턴"), "learned shock cast")
	check(world.mp == 999 - int(shock.mp), "exact shock cost")
	check(world.skill_cooldowns.has("쇼크 스턴"), "cast starts cooldown")
	CLOCK.settle(world)
	reset_cast()
	world.equipped_items["weapon"].type = "한손검"
	check(not world._cast_job_skill("쇼크 스턴"), "two-handed restriction")
	check(world.mp == 999, "wrong weapon does not spend")
	world.equipped_items["weapon"].type = "양손검"
	var counter := learn("카운터 배리어")
	learn("카운터 배리어(베테랑)")
	learn("카운터 배리어(마스터)")
	var resolved := catalog.resolve(counter)
	check(is_equal_approx(float(resolved.counter_chance), .2), "highest counter tier replaces chance")
	check(is_equal_approx(float(resolved.counter_multiplier), 1.3), "counter multiplier separate from chance")
	reset_cast()
	check(world._cast_job_skill("카운터 배리어"), "base counter retains quickslot cast")
	check(world.active_skill_buffs.size() == 1, "upgrade passives do not stack buff instances")
	world.original_skills.counter_depth = 1
	check(not world.original_skills.counter(dummy, "melee", 20), "counter recursion guard")
	world.original_skills.counter_depth = 0
	check(not world.original_skills.counter(dummy, "magic", 20), "melee counter does not reflect spells")
	var counter_hits := 0
	for _trial: int in range(4000):
		if world.original_skills.counter(dummy, "melee", 20): counter_hits += 1
	check(absf(float(counter_hits)/4000 - .2) < .025, "actual counter service rate with both augments")
	check(world.active_skill_buffs.size() == 1, "counter healing cannot stack or extend a second buff")
	# AI status effects and absolute immunity are checked on a live monster.
	var status_skill := shock.duplicate(true)
	status_skill.status_chance = 1
	dummy.stun_resistance = 100
	check(not world.original_skills.status.apply(status_skill,dummy,world), "100% resistance blocks stun")
	dummy.stun_resistance = 0
	dummy.status_immunities = ["stun"]
	check(not world.original_skills.status.apply(status_skill,dummy,world), "explicit immunity")
	dummy.status_immunities = []
	check(world.original_skills.status.apply(status_skill,dummy,world), "status applied to monster AI")
	check(dummy.is_stunned(), "monster actually stunned")
	dummy.stun_remaining = 0
	# Conversion, material atomicity and independent moving arrows.
	world.job_class = "요정"
	var triple := learn("트리플 애로우")
	world.equipped_items["weapon"].type = "활"
	reset_cast()
	world.inventory["화살"] = 2
	check(not world._cast_job_skill("트리플 애로우"), "insufficient arrows")
	check(world.mp == 999 and int(world.inventory["화살"]) == 2, "failed cast is atomic")
	world.inventory["화살"] = 10
	world.selected_monster = dummy
	var hits_before := dummy.damage_hit_count
	check(world._cast_job_skill("트리플 애로우"), "triple cast")
	check(int(world.inventory["화살"]) == 7, "three arrows consumed")
	world._release_player_attack(int(world.pending_attack.id))
	check(world.combat_flights.flights.size() == 3, "three independent flights")
	for _step: int in range(8): world.combat_flights._physics_process(.1)
	check(dummy.damage_hit_count - hits_before <= 3 and dummy.damage_hit_count > hits_before, "independent hit rolls, no duplicate damage")
	reset_cast()
	world.inventory["화살"] = 10
	world.selected_monster = dummy
	check(world._cast_job_skill("트리플 애로우"), "queued cast before class change")
	var generation := world.combat_generation
	var class_hits := dummy.damage_hit_count
	world._on_job_class_selected("기사")
	check(world.pending_attack.is_empty() and world.combat_generation > generation, "class change cancels previous attack generation")
	for _step: int in range(8): world.combat_flights._physics_process(.1)
	check(dummy.damage_hit_count == class_hits, "previous class cannot hit after switching")
	world.job_class = "마검사"
	var life := learn("라이프 스트림")
	reset_cast()
	world.hp -= 5
	check(world._cast_job_skill("라이프 스트림"), "life stream cast")
	check(not world.original_skills.shields.is_empty(), "overflow becomes shield")
	var amount := world.original_skills.incoming_damage(dummy, "magic", 20)
	check(amount == 0, "shield absorbs real damage")
	# Old names and synthesized quickslots are archived, item state is untouched.
	world.job_class = "기사"
	world.quickslots = [{"kind":"skill","id":"기사의 일격 1","auto":true},{"kind":"skill","id":"실드","auto":true}]
	var inventory_before := world.inventory.duplicate(true)
	catalog.import_state({"quickslots":world.quickslots,"active_skill_buffs":{"bad":{"atk":9000}}})
	check(world.quickslots[0].is_empty(), "legacy slot archived")
	check(str(world.quickslots[1].get("skill_id", "")).begins_with("lm_"), "stable slot identity")
	check(catalog.archived.has("slot_0"), "legacy reference recoverable")
	check(world.inventory == inventory_before, "migration preserves inventory")
	var state := catalog.export_state()
	state.learned["future_skill_id"] = 2
	catalog.import_state({"original_skill_state":state})
	check(catalog.export_state().learned.has("future_skill_id"), "unknown future IDs round trip")
	# Visual budget never leaks objects or determines hit callbacks.
	world.original_skills.vfx.clear()
	for _index: int in range(400): world.original_skills.vfx.emit_skill(str(triple.id), "impact", Vector2.ZERO)
	check(world.original_skills.vfx.live.size() <= 160, "bounded VFX budget")
	world.original_skills.vfx._process(2)
	check(world.original_skills.vfx.live.is_empty() and world.original_skills.vfx.available.size() <= 160, "pool returns all effects")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_SYSTEM_OK")
	quit(0 if failures.is_empty() else 1)
