extends SceneTree

const QA := preload("res://tests/qa_class_selection.gd")
const MONSTER := preload("res://scenes/Monster.tscn")
const PROFILES := preload("res://scripts/skills/reference_profiles523.gd")
const RULES := preload("res://scripts/skill_rules.gd")
var checks: int = 0
var failures: Array[String] = []
var world: TwilightWorld
var service: TwilightOriginalSkillService
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, note: String) -> bool:
	checks += 1
	if not ok:
		failures.append(note)
		printerr("REFERENCE_SKILLS523_FAIL ", note)
	return ok

func audit_catalog() -> void:
	var profiles: Dictionary = PROFILES.profiles()
	var catalog := service.catalog
	check(profiles.size() == 332, "all 332 reference skills authored")
	var mode_counts: Dictionary = {}
	var classes: Dictionary = {}
	var fallbacks := 0
	for id: String in profiles:
		var row: Dictionary = catalog.record_for(id)
		var profile: Dictionary = profiles[id]
		if not check(not row.is_empty() and row.name == profile.name, "stable ID and canonical name " + id): continue
		check(not bool(row.get("runtime_blocked", false)) and int(row.minimum_level) > 0 and not str(row.book_name).is_empty(), "learnable role and book " + str(row.name))
		check(row.reference_visual523.has("shape") and row.reference_visual523.has("color"), "bounded visual registered " + str(row.name))
		mode_counts[row.mode] = int(mode_counts.get(row.mode, 0)) + 1
		classes[row["class"]] = true
		if not row.get("reference_approx523", false): continue
		fallbacks += 1
		if row.activation == "active":
			check(service.CAST_MODES.has(str(row.mode)) and float(row.cooldown) > 0, "reachable cast mode " + str(row.name))
		else:
			check(not RULES.can_auto_cast(row), "passive excluded from quickslot auto " + str(row.name))
		if row.mode == "upgrade":
			var seen: Dictionary = {id:true}
			var base: String = str(catalog.relations[id].get("upgrades_from", ""))
			check(not catalog.record_for(base).is_empty() and not catalog.relations[id].patch.is_empty(), "real ancestor and patch " + str(row.name))
			while not base.is_empty() and not seen.has(base):
				seen[base] = true
				base = str(catalog.relations.get(base, {}).get("upgrades_from", ""))
			check(base.is_empty(), "acyclic ancestry " + str(row.name))
	metrics["classes"] = classes.size()
	metrics["modes"] = mode_counts
	metrics["fallbacks"] = fallbacks
	check(classes.size() == 13 and fallbacks == 332, "all classes have executable public fallback without a source pack")

func setup_grid() -> Vector2:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-17, -17, 38, 38)
	grid.cell_size = Vector2.ONE * world.tile_size
	grid.update()
	world.astar = grid
	var origin: Vector2 = Vector2.ONE * world.tile_size * 0.5
	world.player.global_position = origin
	return origin

func spawn(point: Vector2, label: String) -> TwilightMonster:
	var actor: TwilightMonster = MONSTER.instantiate()
	world.monsters_root.add_child(actor)
	actor.setup({"name":label,"hp":12000,"lv":1,"mr":0,"ac":0},world.player,world,null)
	actor.set_physics_process(false)
	actor.global_position = point
	return actor

func learn(skill_name: String) -> Dictionary:
	var catalog := service.catalog
	var record: Dictionary = catalog.record_for(skill_name)
	check(catalog.buy_book(str(record.id)), "buy " + skill_name)
	check(catalog.learn(str(record.id)) and catalog.owned(record), "learn " + skill_name)
	return record

func clear_cooldowns() -> void:
	world.player.cancel_attack()
	world.pending_attack.clear()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0

func release() -> void:
	var id: int = int(world.pending_attack.get("id", -1))
	world._release_player_attack(id)
	world._release_player_attack(id)
	for frame: int in 12: world.combat_flights._physics_process(1.0 / 30.0)

func reaper(origin: Vector2) -> void:
	var catalog := service.catalog
	var target := spawn(origin + Vector2(world.tile_size * 2, 0), "reference_stun_target")
	var nearby := spawn(target.global_position + Vector2(0, world.tile_size * 2), "reference_aoe_target")
	var distant := spawn(origin + Vector2(0, -world.tile_size * 8), "reference_far_target")
	var counter_book: Dictionary = catalog.record_for("고스트 카운터")
	var armor_class_before: int = world._effective_ac()
	check(not catalog.buy_book(str(counter_book.id)), "Ghost Counter respects the Ghost Armor learning prerequisite")
	var gold_before: int = world.gold
	world.source_save_blocked = true
	var armor_book: Dictionary = catalog.record_for("고스트 아머")
	check(not catalog.buy_book(str(armor_book.id)) and world.gold == gold_before and not world.inventory.has(str(armor_book.book_name)),
		"unwritable save does not debit a new book or grant an item")
	world.source_save_blocked = false
	learn("고스트 아머")
	check(world._effective_ac() == armor_class_before - 5 and service.stat("stunResistance") >= 9, "Ghost Armor is a real passive")
	learn("고스트 아머(레퀴엠)")
	check(world._effective_ac() == armor_class_before - 8 and service.stat("stunResistance") >= 15, "Ghost Armor upgrade replaces its base strength")
	learn("데스 크리티컬")
	var critical: float = service.stat("meleeCrit")
	learn("데스 크리티컬(레퀴엠)")
	check(service.stat("meleeCrit") > critical, "Death Critical Requiem boosts the existing stable base")
	var stun := learn("데스 스턴")
	var key := PROFILES.local_item_name(stun,"영혼석")
	var hp0: int = world.hp
	var mp0: int = world.mp
	world.selected_monster = target
	check(not world._cast_job_skill(str(stun.id)) and world.mp == mp0 and world.hp == hp0, "missing local soul stones refuse the cast before payment")
	check(PROFILES.buy_reagents(catalog,stun) and int(world.inventory.get(key,0)) == 150, "local shop buys ten casts worth of separately identified soul stones")
	check(not world.inventory.has("영혼석"), "local reagent does not grant native material")
	world.selected_monster = distant
	check(not world._cast_job_skill(str(stun.id)) and world.mp == mp0 and int(world.inventory[key]) == 150, "out of range preserves prepaid reagents and MP")
	world.selected_monster = target
	clear_cooldowns()
	check(world._cast_job_skill(str(stun.id)) and world.mp == mp0 - 13 and int(world.inventory[key]) == 135, "actual Main cast reserves Death Stun and consumes exactly one use")
	release()
	for attempt: int in 8:
		if target.stun_remaining > 0: break
		clear_cooldowns()
		if world._cast_job_skill(str(stun.id)): release()
	check(target.stun_remaining >= 2.0 and target.stun_remaining <= 5.0, "Death Stun applies its documented duration through the combat marker")
	check(service.status.modifier(target,"healing_taken") == -1, "Death Stun attaches healing reversal to the target life")
	var hp_before: int = target.hp
	check(service.reference_npc_healing(target, 20) == 0 and target.hp == hp_before - 20, "Death Stun reverses an actual NPC recovery amount")
	var counter := learn("고스트 카운터")
	clear_cooldowns()
	mp0 = world.mp
	hp0 = world.hp
	check(world._cast_job_skill(str(counter.id)) and world.mp == mp0 - 15 and world.hp == hp0 - 50, "actual Counter cast spends documented MP and HP")
	var evaded := false
	for attempt: int in 40:
		if service.incoming_damage(target,"melee",25) == 0 and service.last_evaded:
			evaded = true
			break
	check(evaded and target.bleed_remaining > 0 and target.bleed_tick_damage > 0, "Ghost Counter evades and applies the wraith's damage over time")
	var cyclic := learn("데스 블로우")
	var attacks: Dictionary = service.attack_context("melee",false,true)
	var counted: int = int(service.event_counts.get(cyclic.id,0))
	for i: int in 9: service.trigger("on_hit",target,{},attacks)
	check(int(service.event_counts.get(cyclic.id,0)) == counted, "Death Blow waits for ten landed normal attacks")
	service.trigger("on_hit",target,{"id":stun.id},service.attack_context("magic",true,true))
	check(int(service.event_counts.get(cyclic.id,0)) == counted, "Spell hits do not advance Death Blow")
	service.trigger("on_hit",target,{},attacks)
	check(int(service.event_counts.get(cyclic.id,0)) == counted + 1, "Tenth landed normal attack resolves Death Blow")
	var genocide := learn("제노사이드")
	clear_cooldowns()
	world.selected_monster = target
	var resolved: Dictionary = catalog.resolve(genocide)
	check(service.targets(resolved,target).has(nearby) and not service.targets(resolved,target).has(distant), "targeted explosion centers on chosen enemy and filters range")
	var had_fx: int = 0
	if is_instance_valid(service.vfx.reference_effects): had_fx = service.vfx.reference_effects.live.size()
	check(had_fx > 0, "combat publishes procedural art when no verified effect pack is installed")
	check(world._save_game(true) == OK, "save actual learned references")
	var before: Dictionary = catalog.export_state()
	catalog.learned.erase(str(stun.id))
	world._load_game(true)
	check(catalog.learned.size() == before.learned.size() and before.learned.keys().all(
		func(id: String) -> bool: return int(catalog.learned.get(id, 0)) == int(before.learned[id])),
		"save/load preserves learned and existing skill IDs")

func skill_ui() -> void:
	world._update_hud()
	world.hud.open_skills()
	var view: Node = world.hud.skills_view
	view.type_filter.select(3)
	view.search.text = "데스 스턴"
	view.refresh()
	var index: int = view.filtered.find_custom(func(row: Dictionary) -> bool: return row.name == "데스 스턴")
	if not check(index >= 0, "skill window finds the newly playable Death Stun"): return
	view.focus_skill(str(view.filtered[index].id))
	check(view.use_button.is_visible_in_tree() and not view.use_button.disabled, "actual skill detail opens manual cast")
	check(view.quick_button.is_visible_in_tree() and not view.quick_button.disabled, "actual skill detail opens quickslot")
	check(view.reagent_button.is_visible_in_tree() and not view.reagent_button.disabled, "skill window offers local material purchase")
	metrics["skill_window"] = {"use_disabled":view.use_button.disabled,"quick_disabled":view.quick_button.disabled,
		"reagent_visible":view.reagent_button.visible,"reagent_in_tree":view.reagent_button.is_visible_in_tree(),
		"owned":service.catalog.owned(view.selected),"class":world.job_class,"level":world.level}
	check(view.selection_sheet.category.text.contains("TWILIGHT 추정") and not view.selection_sheet.category.text.contains("실행 보류"),
		"playable approximation is labeled in the skill details")
	var player_state: Array = [world.hp, world.mp, world.gold, world.inventory.duplicate(true)]
	view.preview_button.pressed.emit()
	check(is_instance_valid(view.preview_vfx.reference_effects) and view.preview_vfx.reference_effects.live.size() == 2,
		"skill preview uses the authored local cast and impact")
	check(player_state == [world.hp,world.mp,world.gold,world.inventory], "preview has no cost or gameplay side effect")
	world.hud.workspace.visible = false

func mobile_cap() -> void:
	service.vfx.clear()
	service.vfx.set_detail("low", true)
	for effect: int in 24:
		service.vfx.emit_reference_effect(str(effect), {"shape":"wraith","color":"#ac9cf8"}, "impact", Vector2(effect*12,0))
	var canvas: Node2D = service.vfx.reference_effects
	check(canvas.live.size() == 14, "low-effect mode caps the new animation pool")
	canvas._process(0.8)
	check(canvas.live.is_empty() and not canvas.is_processing(), "quiescent renderer stops processing")

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world, "사신"), "actual Main player selection")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.field_population.set_process(false)
	world.save_timer = -100000.0
	world._clear_monsters()
	world.level = 90
	world.gold = 10000000
	world.hp = 1000
	world.max_hp = 1600
	world.mp = 1000
	world.max_mp = 1800
	world.equipped_items = {"weapon":{"name":"검증 사이드","type":"사이드","slot":"weapon"}}
	world.rng.seed = 11523
	service = world.original_skills
	audit_catalog()
	reaper(setup_grid())
	skill_ui()
	mobile_cap()
	world.queue_free()
	await process_frame
	print("REFERENCE_SKILLS523_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
