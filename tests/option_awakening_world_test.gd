extends SceneTree
## Exercises the shipped Main scene, real card IDs, save writer and stat consumers.
## The project runner supplies an isolated user directory.
const Core = preload("res://scripts/cards/option_awakening_service.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
var world
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("OPTION_AWAKENING_WORLD_FAIL: " + message)

func _card(category: String, identity: String) -> Dictionary:
	return world.option_awakening.core.catalog.get(category, {}).get(identity, {})

func _grant(category: String, identity: String, duplicates: int = 0) -> void:
	world.card_draw_fusion.owned[category][identity] = true
	if duplicates > 0: world.card_draw_fusion.spare[category][identity] = duplicates
	# Production card transactions publish through _update_hud; this fixture
	# edits the runtime dictionaries directly.
	world._invalidate_equipment_static()

func _set_awakened(category: String, identity: String, active: bool) -> void:
	_grant(category, identity)
	world.option_awakening.progress.cards[category][identity] = {"experience":0,"awakened":active,"attempts":1 if active else 0,"failures":0}
	world.option_awakening.progress.revision += 1
	world._invalidate_equipment_static()

func _disk() -> String:
	return FileAccess.get_file_as_string(world.save_path())

func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(world.save_path(), FileAccess.WRITE)
	check(file != null, "isolated fixture file opens")
	if file != null:
		file.store_string(text)
		file.close()

func _seed_success() -> void:
	var probe := RandomNumberGenerator.new()
	for value: int in range(1, 1000):
		probe.seed = value
		if probe.randi_range(0, 9999) < 1650:
			world.option_awakening.rng.seed = value
			return
	check(false, "deterministic success seed found")

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	check(scene != null, "shipped Main loads")
	if scene == null: _finish(); return
	world = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.hud.complete_class_selection()
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	var rt = world.option_awakening
	check(rt.problem.is_empty(), "real catalog configures option awakening")
	if not rt.problem.is_empty():
		world.queue_free(); await process_frame; _finish(); return
	check(rt.core.definitions["변신"].size() == 180 and rt.core.definitions["마법인형"].size() == 83 and rt.core.definitions["성물"].size() == 58, "all 321 mapped cards resolve against the actual normalized catalog")
	world.inventory = {}
	world.item_instances = {}
	world.equipped_items = {}
	world.enhancement_levels = {}
	world.equipped_catalog = {"변신":{},"마법인형":{},"성물":{}}
	world.active_item_buffs = {}
	world.active_skill_buffs = {}
	world.gold = 10000000
	rt.progress = Core.fresh_state()
	var category: String = "변신"
	var identity: String = "source:146"
	_grant(category, identity, 2)
	var target: Dictionary = _card(category, identity)
	world._equip_catalog(category, target)
	check(world._save_game(true) == OK, "initial whole-game save succeeds")
	var before_cards: Dictionary = world.card_draw_fusion.export_state()
	var before_progress: Dictionary = rt.export_state()
	var before_disk: String = _disk()
	var before_gold: int = world.gold
	var before_speed: float = world._effective_attack_speed_bonus_percent()
	world.equipment_collections.test_save_writer = func(_path: String, _data: Dictionary) -> Error: return ERR_CANT_CREATE
	world._on_option_awakening_feed_requested(category, identity, {identity:1})
	check(world.card_draw_fusion.export_state() == before_cards and rt.export_state() == before_progress and world.gold == before_gold, "failed material save preserves live cards, XP, RNG and gold")
	check(_disk() == before_disk, "failed material save preserves durable bytes")
	check(not world.hud.is_option_awakening_busy(), "failed save cannot present a result")
	world.equipment_collections.test_save_writer = Callable()
	world._on_option_awakening_feed_requested(category, identity, {identity:1})
	check(int(rt.view(category, identity).experience) == 100, "actual HUD handler feeds target XP")
	check(bool(world.card_draw_fusion.owned[category][identity]) and int(world.card_draw_fusion.spare[category][identity]) == 1, "only selected duplicate is consumed; first copy remains owned")
	var fed: Dictionary = JSON.parse_string(_disk())
	check(int(fed.card_option_awakening.cards[category][identity].experience) == 100 and int(fed.card_draw_fusion.spare[category][identity]) == 1, "XP and consumed materials share one persisted save")
	_seed_success()
	before_progress = rt.export_state()
	before_disk = _disk()
	world.equipment_collections.test_save_writer = func(_path: String, _data: Dictionary) -> Error: return ERR_CANT_CREATE
	world._on_option_awakening_attempt_requested(category, identity)
	check(rt.export_state() == before_progress and world.gold == before_gold and _disk() == before_disk, "failed attempt save preserves outcome, RNG, money and disk")
	check(not world.hud.is_option_awakening_busy(), "rejected attempt has no success reveal")
	world.equipment_collections.test_save_writer = Callable()
	world._on_option_awakening_attempt_requested(category, identity)
	check(rt.is_awakened(category, identity), "same successful RNG outcome commits after storage recovers")
	check(world.gold == before_gold - 100000, "exact configured fee charged once")
	check(is_equal_approx(world._effective_attack_speed_bonus_percent(), before_speed + 7.0), "successful actual target adds seven attack-speed points")
	check(world.hud.is_option_awakening_busy(), "result presentation starts after successful commit")
	var committed: Dictionary = rt.export_state()
	var committed_gold: int = world.gold
	world._on_option_awakening_attempt_requested(category, identity)
	check(rt.export_state() == committed and world.gold == committed_gold, "duplicate request during reveal cannot charge again")
	var reveal: Control = world.hud.option_awakening_reveal
	if is_instance_valid(reveal):
		reveal.call("skip_to_result")
		reveal.call("close_reveal")
	await process_frame
	var aura: Node2D = world.option_awakening_auras.get(category)
	check(is_instance_valid(aura) and bool(aura.get("awakened")), "equipped awakened transformation gains its field aura")
	world._load_game(true)
	check(rt.export_state() == committed and world.gold == committed_gold, "whole-game reload preserves awakening and RNG")
	check(is_equal_approx(world._effective_attack_speed_bonus_percent(), before_speed + 7.0), "reload never double-counts stats")
	world._equip_catalog(category, {})
	check(not bool(aura.get("awakened")), "unequipping removes its field aura")
	world._equip_catalog(category, target)
	check(bool(aura.get("awakened")), "re-equipping restores saved aura")

	var valid: Dictionary = JSON.parse_string(_disk())
	valid["future_option_world_extension"] = {"kept":true}
	valid.card_option_awakening["future_metadata"] = {"kept":true}
	_write_raw(JSON.stringify(valid))
	world._load_game(true)
	check(world._save_game(true) == OK, "recognized save can be resaved")
	valid = JSON.parse_string(_disk())
	check(bool(valid.future_option_world_extension.kept) and bool(valid.card_option_awakening.future_metadata.kept), "unrelated and same-version future fields survive the whole-save adapter")
	var valid_text: String = _disk()
	var invalid: Dictionary = valid.duplicate(true)
	invalid.card_option_awakening.version = 999
	_write_raw(JSON.stringify(invalid))
	var invalid_bytes: String = _disk()
	world._load_game(true)
	check(world._save_game(true) != OK and _disk() == invalid_bytes, "unknown awakening version cannot be overwritten by autosave")
	check(rt.is_awakened(category, identity) and world.gold == committed_gold, "rejected load preserves prior live awakening and gold")
	_write_raw(valid_text)
	world._load_game(true)
	check(world._save_game(true) == OK, "valid reload releases save protection")
	var legacy: Dictionary = valid.duplicate(true)
	legacy.erase("card_option_awakening")
	_write_raw(JSON.stringify(legacy))
	var legacy_hash: String = FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	check(FileAccess.get_sha256(world.save_path() + ".pre-option-awakening") == legacy_hash, "legacy save receives an exact migration backup")
	check(not rt.is_awakened(category, identity) and world.gold == committed_gold, "legacy save starts unawakened while preserving money and cards")
	check(bool(world.card_draw_fusion.owned[category][identity]), "migration retains existing ownership")
	_write_raw(valid_text)
	world._load_game(true)
	_check_stat_consumers()
	_check_collections()
	world.queue_free()
	await process_frame
	_finish()

func _check_stat_consumers() -> void:
	world.max_hp = 10000
	var samples: Array = [["변신","source:146"],["변신","source:267"],["마법인형","source:145"],["성물","source:4014"]]
	# Include one real card with style-specific accuracy to exercise its separate consumer.
	for category: String in Core.CATEGORIES:
		for identity: String in world.option_awakening.core.definitions[category]:
			var stats: Dictionary = world.option_awakening.core.definition(category, identity).stats
			if stats.has("meleeHit") or stats.has("rangedHit") or stats.has("magicHit"):
				samples.append([category,identity])
				break
	for pair: Array in samples:
		var category: String = pair[0]
		var identity: String = pair[1]
		var rt = world.option_awakening
		rt.progress = Core.fresh_state()
		world.equipped_catalog = {"변신":{},"마법인형":{},"성물":{}}
		var card: Dictionary = _card(category, identity).duplicate(true)
		var original_text: String = JSON.stringify(card)
		var stats: Dictionary = rt.core.definition(category, identity).stats
		world.equipped_catalog[category] = card
		_set_awakened(category, identity, false)
		var before: Dictionary = _stats()
		var base: Dictionary = world._verified_catalog_record(category, card)
		_set_awakened(category, identity, true)
		var after: Dictionary = _stats()
		for key: String in ["strFlat","dexFlat","intFlat","weightBonus","attackSpeed","xp","blessing_consumption_reduction_pct","damage_reduction_ignore","meleeHit","rangedHit","magicHit"]:
			check(is_equal_approx(float(after[key]) - float(before[key]), float(stats.get(key,0))), category + "/" + identity + " actual stat: " + key)
		check(is_equal_approx(float(after.move) - float(before.move), float(stats.get("moveSpeedPct",0)) / 100.0), category + "/" + identity + " movement percentage points")
		check(int(after.ac) - int(before.ac) == -int(stats.get("def",0)) - (world._stat_step_bonus(int(after.dexFlat),10,3.0) - world._stat_step_bonus(int(before.dexFlat),10,3.0)), category + "/" + identity + " AC and DEX each counted once")
		var flat: float = world.max_hp + float(base.get("hpFlat",0)) + float(stats.get("hpFlat",0)) + world._passive_skill_total("hpFlat")
		var expected_hp: int = int(round(flat * (1.0 + float(base.get("hpPct",0)) + float(stats.get("hpPct",0)))))
		check(int(after.hp) == expected_hp, category + "/" + identity + " maximum HP flat/fraction units")
		var expected_cooldown: float = clampf(float(before.cooldown) - float(stats.get("skillCooldownPct",0)) / 100.0,0.1,1.0)
		check(is_equal_approx(float(after.cooldown), expected_cooldown), category + "/" + identity + " existing cooldown stat receives relic option")
		check(JSON.stringify(card) == original_text, "source catalog options remain immutable")

func _stats() -> Dictionary:
	return {"strFlat":world._effective_attribute("STR"),"dexFlat":world._effective_attribute("DEX"),"intFlat":world._effective_attribute("INT"),"weightBonus":world._catalog_stat_sum("weightBonus"),"attackSpeed":world._effective_attack_speed_bonus_percent(),"xp":world._experience_multiplier(),"blessing_consumption_reduction_pct":world._blessing_consumption_reduction_percent(),"damage_reduction_ignore":world._catalog_damage_bonus("melee"),"meleeHit":world._catalog_accuracy_bonus("melee"),"rangedHit":world._catalog_accuracy_bonus("ranged"),"magicHit":world._catalog_accuracy_bonus("magic"),"move":world._effective_move_speed_multiplier(),"ac":world._effective_ac(),"hp":world._effective_max_hp(),"cooldown":world._skill_cooldown_factor()}

func _check_collections() -> void:
	var rt = world.option_awakening
	rt.progress = Core.fresh_state()
	world.equipped_catalog = {"변신":{},"마법인형":{},"성물":{}}
	# No owned requirements from a previous fixture may complete a collection early.
	world.card_draw_fusion.configure(world.catalog_db)
	world._invalidate_equipment_static()
	var before_ac: int = world._effective_ac()
	var before_int: int = world._effective_attribute("INT")
	var before_sp: int = world._catalog_stat_sum("sp")
	world.inventory["체력 회복제"] = 2
	world.item_use_cooldowns = {}
	world.hp = 1
	world._use_healing_item("체력 회복제",50)
	var before_heal: int = world.hp - 1
	for row: Dictionary in rt.core.collections:
		for requirement: Dictionary in row.requirements:
			_grant(str(requirement.category),str(requirement.id))
			if bool(requirement.awakened): _set_awakened(str(requirement.category),str(requirement.id),true)
	check(world._effective_ac() == before_ac - 1, "verified collection grants AC without equipping its cards")
	check(world._effective_attribute("INT") == before_int + 1 and world._catalog_stat_sum("sp") == before_sp + 1, "verified collection INT/SP apply once")
	world.item_use_cooldowns = {}
	world.hp = 1
	world._use_healing_item("체력 회복제",50)
	check(world.hp - 1 == before_heal + 3, "collection healing increases the actual potion by three, not six")
	for row: Dictionary in rt.collections_view(): check(bool(row.completed), "verified collection membership completes: " + str(row.name))

func _finish() -> void:
	print("OPTION_AWAKENING_WORLD_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("OPTION_AWAKENING_WORLD_OK")
	quit(0 if failures.is_empty() else 1)
