extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const Service = preload("res://scripts/skills/skill_service.gd")
const Loot = preload("res://scripts/loot_drop.gd")
var checks: int = 0
var failures: Array[String] = []
var world: TwilightWorld
var dummy: TwilightMonster
var base: Dictionary
var deaths: int = 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("TURN_REWARDS FAIL: ", message)

func seed_for(success: bool) -> bool:
	var rng := RandomNumberGenerator.new()
	var chance := world.original_skills.turn_undead_chance(world.original_skills.catalog.resolve(base), dummy)
	for candidate: int in range(10000):
		rng.seed = candidate
		if Service.roll_turn_undead(rng, chance) != success: continue
		if success:
			# Select a fixture seed with one real potion drop. Do not replace the
			# production drop table or duplicate its probability formula.
			var drops := Loot.roll(dummy.drop_items, false, world.loot_catalog, rng)
			if drops.size() != 1 or drops[0] != "HP 물약": continue
		world.rng.seed = candidate
		return true
	return false

func cast_and_land(success: bool) -> void:
	world._clear_combat_actions()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.selected_monster = dummy
	world.mp = 999
	check(world._cast_job_skill(str(base.id)), "real paid cast")
	check(world.mp == 999 - int(base.mp), "exact cast cost")
	world._release_player_attack(int(world.pending_attack.id))
	check(dummy.hp == dummy.max_hp and world.combat_flights.flights.size() == 1, "no early kill before actual flight")
	check(seed_for(success), "find a production-path deterministic reward seed")
	for _step: int in range(20): world.combat_flights._physics_process(.02)

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world._clear_drops()
	world.level = 90
	world.experience = 0
	world.exp_need = 100000
	world.quest_kills = 0
	world._on_job_class_selected("마법사")
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300, 4370)))
	world.equipped_items.clear()
	world.equipped_catalog.clear()
	world._equip_catalog("마법인형", {"name":"즉사 흡수 검사 인형", "hpAbsorption":true})
	world.hp = world._effective_max_hp() - 10
	var catalog := world.original_skills.catalog
	catalog.learned.clear()
	catalog.seed_starters()
	base = catalog.record_for("턴 언데드")
	world.inventory[str(base.book_name)] = 1
	check(catalog.learn(str(base.id)), "learn with the actual book service")
	world._on_quickslot_assignment_requested(0, "skill_auto", str(base.id))
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"턴 언데드 보상 검사 NPC", "hp":10000, "xp":25, "gold":40, "mr":150, "undead":true, "drop":["HP 물약"]}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(30, 0)
	dummy.set_physics_process(false)
	# The same connection as real field monsters: the service must reach it
	# through take_damage/death, not by calling a reward handler in this test.
	dummy.died.connect(world._on_monster_died)
	dummy.died.connect(func(_monster: TwilightMonster) -> void: deaths += 1)
	var before_gold := world.gold
	var before_hp := world.hp
	var before_items := int(world.inventory.get("HP 물약", 0))
	cast_and_land(false)
	check(not dummy.dead and deaths == 0, "failed roll emits no death")
	check(world.experience == 0 and world.gold == before_gold and world.quest_kills == 0, "failed roll grants no XP/currency/quest kill")
	check(world.ground_loot.views.is_empty(), "failed roll creates no ground loot")
	cast_and_land(true)
	check(dummy.dead and dummy.hp == 0 and deaths == 1, "successful roll emits one real death")
	check(world.experience > 0 and world.gold > before_gold and world.quest_kills == 1, "real death handler grants XP/currency/quest kill")
	check(dummy.get_parent() == world.combat_corpses and world.selected_monster == null, "normal corpse and target cleanup")
	check(world.hp == before_hp, "instant death cannot trigger weapon HP absorption")
	check(world.ground_loot.views.size() == 1 and int(world.inventory.get("HP 물약", 0)) == before_items, "real loot roll creates one ground item without instant inventory grant")
	var earned := world.experience
	var earned_gold := world.gold
	world.original_skills.impact(catalog.resolve(base), dummy)
	check(deaths == 1 and world.experience == earned and world.gold == earned_gold and world.ground_loot.views.size() == 1, "duplicate callback cannot grant rewards twice")
	if not world.ground_loot.views.is_empty():
		var drop: Button = world.ground_loot.views.values()[0]
		check(str(drop.get_meta("item_name")) == "HP 물약", "ground record retains the actual rolled item")
		drop.set("visible_since", Time.get_ticks_msec() - 900)
		world.player.global_position = drop.get_meta("world_position")
		check(world._collect_ground_drop(drop), "normal pickup collects the actual kill drop")
		check(int(world.inventory.get("HP 물약", 0)) == before_items + 1 and world.ground_loot.views.is_empty(), "pickup grants exactly one item and removes the ground record")
	world._save_game(true)
	world.experience = 0
	world.gold = 0
	world.inventory["HP 물약"] = 0
	world._load_game(true)
	check(world.experience == earned and world.gold == earned_gold and int(world.inventory.get("HP 물약", 0)) == before_items + 1, "kill rewards and picked-up loot survive save/load")
	check(int(catalog.learned.get(str(base.id), 0)) == 1 and world.quickslots[0].get("skill_id") == base.id and float(world.skill_cooldowns.get(str(base.name), 0)) > 0, "same save preserves learned ID, AUTO slot and live cooldown")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_TURN_UNDEAD_REWARDS_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
