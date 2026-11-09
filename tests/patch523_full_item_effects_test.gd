extends SceneTree
## Run against private expectations independently generated from all original
## source rows. A combat target below is a focused engine test, not NPC coverage.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const A = preload("res://scripts/loot/patch523_ammo.gd")
const P = preload("res://scripts/loot/patch523_passive_items.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		if failures.size()<40: printerr("FULL_EFFECT_FAIL: ",label)
		failures.append(label)
func reject(_path: String,_state: Dictionary) -> Error: return ERR_CANT_CREATE
func same_stats(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key: String in expected:
		if not actual.has(key) or not is_equal_approx(float(actual[key]),float(expected[key])): return false
	return true
func run() -> void:
	var expectations: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_ITEM_EFFECT_EXPECTATIONS")))
	if not expectations is Dictionary or not D.data().get("full_item_catalog",false): printerr("full private pack and source expectations required");quit(1);return
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer = -100000
	check(QA.enter_game(world),"actual Main source-map entry")
	world.field_population.set_process(false);world.player.set_physics_process(false);world._clear_monsters();world._clear_drops()
	var document: Dictionary = D.data()
	# Representative weapons are chosen among items open by source dates.
	D.rotate_ended_dates = false
	var section: String = OS.get_environment("TWILIGHT_ITEM_EFFECT_SECTION")
	var enchant_cases: int = 0
	var passive_definitions: int = 0
	var weapons: Dictionary = {}
	for key: String in document.native_item_ids:
		var record: Dictionary = D.cached_definition(key).native_record
		if record.slot != "weapon" or not D.deadline_problem(record).is_empty(): continue
		var category: int = A.weapon_category(record)
		if category > 0 and not weapons.has(category): weapons[category] = record
	print("FULL_EFFECT_STAGE source_weapons ",weapons.keys())
	for entry: Dictionary in expectations.enchantment:
		if section == "ammo": break
		enchant_cases += 1
		var record: Dictionary = D.variant_item(world.source_item_record(int(entry.id)),int(entry.bless))
		check(same_stats(D.native_enchant_stats(record,int(entry.level)),entry.expected),"exact original enchant level / bless "+str(entry.id)+"/"+str(entry.level)+"/"+str(entry.bless))
	print("FULL_EFFECT_STAGE enchant ",expectations.enchantment.size())
	for entry: Dictionary in expectations.passives:
		if section == "ammo": break
		passive_definitions += 1
		check(same_stats(P.effects(world.source_item_record(int(entry.id))),entry.effects),"all source passive fields "+str(entry.id))
	print("FULL_EFFECT_STAGE passives ",expectations.passives.size())
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.add_child(monster)
	monster.setup({"name":"장비 효과 집중 검사 대상","hp":100000,"level":1,"defense":0,"xp":0,"gold":0},world.player,world,null)
	monster.set_process(false);monster.set_physics_process(false)
	var supported: int = 0
	var activated: int = 0
	for entry: Dictionary in expectations.ammo:
		var record: Dictionary = world.source_item_record(int(entry.id))
		var profile: Dictionary = A.profile(record)
		check(not profile.is_empty() == bool(entry.supported),"ordinary ammo vs special spell projectile "+str(entry.id))
		if not entry.supported: continue
		supported += 1
		check(weapons.has(int(entry.category_id)),"exact source weapon ammo category "+str(entry.id))
		if not weapons.has(int(entry.category_id)): continue
		for slot: String in world.EQUIPMENT_SLOT_ORDER: world.equipped_items[slot] = {}
		var weapon: Dictionary = weapons[int(entry.category_id)]
		world.inventory = {};world.item_instances = {};world.equipped_ammo = "";world.ammo_unequipped = false
		world.level = 90;world.job_class = "요정" if weapon.get("source_class_names",[]).is_empty() else str(weapon.source_class_names[0])
		var staged: Dictionary = world.stage_source_item_grants([{"item_class_id":int(weapon.source_item_class_id),"amount":1,"bless_raw":1,"enchant":0},{"item_class_id":int(entry.id),"amount":3,"bless_raw":1,"enchant":0}],{"kind":"focused_source_ammo_test"})
		check(staged.get("ok",false),"source weapon and ammo actual supplier stage")
		if not staged.get("ok",false): continue
		world.inventory = staged.overrides.inventory;world.item_instances = staged.overrides.item_instances
		world._equip_or_acquire_item(weapon,false)
		check(int(world._equipped_weapon_record().get("source_item_class_id",-1)) == int(weapon.source_item_class_id),"actual owned source weapon equipped")
		check(world._save_game(true) == OK,"ammo initial state")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
		world.equipment_collections.test_save_writer = reject
		world._on_inventory_item_activated(str(record.name))
		check(world.equipped_ammo.is_empty() and FileAccess.get_file_as_bytes(world.save_path()) == bytes,"ammo equip writer failure preserves state "+str(entry.id))
		world.equipment_collections.test_save_writer = Callable()
		world._on_inventory_item_activated(str(record.name))
		if world.equipped_ammo != record.name or world._current_ammo_name() != record.name:
			print("AMMO_ROUTE_DIAGNOSTIC ",JSON.stringify({"id":int(entry.id),"message":world.hud.message_label.text,"equipped":world.equipped_ammo,"current":world._current_ammo_name(),"weapon_id":world._equipped_weapon_record().get("source_item_class_id",-1)}))
		check(world.equipped_ammo == record.name and world._current_ammo_name() == record.name,"all plain source ammo activate and bind exact category "+str(entry.id))
		if world.equipped_ammo == record.name and world._current_ammo_name() == record.name: activated += 1
		check(world._consume_weapon_ammo() and int(world.inventory[record.name]) == 2,"native shot consumes own exact stack "+str(entry.id))
		world.ui_preferences.patch523_ammo_damage_rule = "maximum"
		for size: String in ["small","large"]:
			monster.set_meta("size_class",size)
			var maximum: int = int(entry.values["WeaponSmallDamage" if size == "small" else "WeaponLargeDamage"])
			check(world._roll_source_ammo_damage(monster) == maximum,"native ammo source size damage "+str(entry.id)+"/"+size)
			world.ui_preferences.patch523_ammo_damage_rule = "uniform"
			for roll: int in range(20):
				var amount: int = world._roll_source_ammo_damage(monster)
				check(amount >= 1 and amount <= maximum,"configured estimated ammo roll bounds")
			world.ui_preferences.patch523_ammo_damage_rule = "maximum"
		world.ui_preferences.patch523_ammo_damage_rule = "disabled"
		check(world._roll_source_ammo_damage(monster) == 0,"estimated ammo damage can be disabled")
		world.hud.refresh_inventory(world.inventory);world.hud.lineage_inventory_ui._refresh_detail(str(record.name))
		check(world.hud.lineage_inventory_ui.detail_action.text == "해제" and world.hud.lineage_inventory_ui.detail_text.text.contains("추정"),"native ammo actual inventory action and rule disclosure")
		check(world._save_game(true) == OK,"native ammo saved")
		world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
		check(world.equipped_ammo == record.name and int(world.inventory.get(record.name,0)) == 2,"native ammo equip and quantity survive reentry "+str(entry.id))
	# Each source-supported passive appears once in the original expectation.
	# Exercise actual recovery/drain totals with all those individual records.
	var regen_cases: int = 0
	var drain_cases: int = 0
	for entry: Dictionary in expectations.passives:
		if section == "ammo": break
		var record: Dictionary = world.source_item_record(int(entry.id))
		if not D.deadline_problem(record).is_empty(): continue
		for slot: String in world.EQUIPMENT_SLOT_ORDER: world.equipped_items[slot] = {}
		var slot: String = str(record.slot)
		world.equipped_items[slot+"1" if slot in ["ring","earring","seal"] else slot] = record
		world.inventory = {};world._invalidate_equipment_static();world._refresh_equipment_effects()
		world.hp = maxi(1,world._effective_max_hp()-100);world.mp = maxi(0,world._effective_max_mp()-100)
		var before_hp: int = world.hp;var before_mp: int = world.mp
		world.source_item_regen_elapsed = 0.0;world.ui_preferences.patch523_item_regen_interval_seconds = 30.0
		P.tick(world,30.0)
		var hp_expected: int = int(entry.effects.get("RegenHP",0))+int(entry.effects.get("AbsoluteRegenHP",0))
		var mp_expected: int = int(entry.effects.get("RegenMP",0))+int(entry.effects.get("AbsoluteRegenMP",0))
		check(world.hp == clampi(before_hp+hp_expected,0,world._effective_max_hp()) and world.mp == clampi(before_mp+mp_expected,0,world._effective_max_mp()),"actual source recovery values "+str(entry.id))
		regen_cases += 1
		# A source-specific HP/MP amount is capped by the target's remaining pool.
		var target := TwilightMonster.new();target.hp = 1;target.mp = 1
		world.hp = maxi(1,world._effective_max_hp()-100);world.mp = maxi(0,world._effective_max_mp()-100)
		before_hp = world.hp;before_mp = world.mp
		world.ui_preferences.patch523_item_drain_chance_percent = 100.0
		var hp_drain: int = P.drain(world,target)
		check(hp_drain == mini(1,int(entry.effects.get("AttackDrainHP",0))) and world.hp == before_hp+hp_drain,"native HP drain remaining-target cap "+str(entry.id))
		var mp_drain: int = mini(1,int(entry.effects.get("AttackDrainMP",0)))
		check(world.mp == mini(world._effective_max_mp(),before_mp+mp_drain) and target.mp == 1-(world.mp-before_mp),"native MP drain conservation "+str(entry.id))
		world.ui_preferences.patch523_item_drain_chance_percent = 0.0
		before_hp = world.hp;before_mp = world.mp
		check(P.drain(world,target) == 0 and world.hp == before_hp and world.mp == before_mp,"native drain can be disabled")
		target.free();drain_cases += 1
	world.hud.open_settings_info();await process_frame
	var settings: Node = world.hud.find_child("Patch523DropSettings",true,false)
	check(settings != null,"actual source item settings UI reachable")
	if settings != null:
		var previous: Dictionary = world.ui_preferences.duplicate(true)
		world.equipment_collections.test_save_writer = reject
		settings.ammo_rule.select(1);settings._ammo_changed(1)
		settings.source_regen_interval.value = 47.0
		settings.source_drain_chance.value = 17.0
		check(world.ui_preferences == previous,"source effect settings writer failure preserves old policy")
		world.equipment_collections.test_save_writer = Callable()
		settings.source_regen_interval.value = 47.0;settings.source_drain_chance.value = 17.0
		check(world._save_game(true) == OK,"source policy saved")
		world._load_game(true)
		check(int(world.ui_preferences.patch523_item_regen_interval_seconds) == 47 and int(world.ui_preferences.patch523_item_drain_chance_percent) == 17,"source effect settings survive actual save reentry")
	world.queue_free();await process_frame
	print("FULL_EFFECT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"all_ammo_definitions":expectations.ammo.size(),"ordinary_ammo_definitions":supported,"ordinary_ammo_activated":activated,"passive_definitions_tested":passive_definitions,"actual_recovery_and_drain_cases":regen_cases,"enchant_level_bless_cases_tested":enchant_cases,"source_enchant_group_combinations_in_input":expectations.group_combinations}))
	quit(0 if failures.is_empty() else 1)
