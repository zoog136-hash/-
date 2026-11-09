extends SceneTree
## Actual newly received ZIP -> install -> Main -> source supplier variants,
## physical identities -> failed save -> committed save -> reentry -> UI.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const A = preload("res://scripts/loot/patch523_ammo.gd")
const U = preload("res://scripts/loot/patch523_item_use.gd")
const P = preload("res://scripts/loot/patch523_passive_items.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("FULL_DELIVERY_FAIL: ",label)
func reject(_path: String,_state: Dictionary) -> Error: return ERR_CANT_CREATE
func same_saved_value(actual: Variant,expected: Variant) -> bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in expected:
			if not actual.has(key) or not same_saved_value(actual[key],expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index: int in range(expected.size()):
			if not same_saved_value(actual[index],expected[index]): return false
		return true
	if typeof(actual) in [TYPE_INT,TYPE_FLOAT] and typeof(expected) in [TYPE_INT,TYPE_FLOAT]: return actual == expected
	return typeof(actual) == typeof(expected) and actual == expected
func equipped_ownership(world: TwilightWorld) -> Dictionary:
	var result: Dictionary = {}
	for slot: String in world.EQUIPMENT_SLOT_ORDER:
		var record: Dictionary = world.equipped_items.get(slot,{})
		if record.is_empty(): continue
		var uid: String = str(record.get("instance_id",""))
		var physical: Dictionary = world.item_instances.get(uid,{})
		result[slot] = {"uid":uid,"name":str(record.name),"sourceId":str(record.get("sourceId","")),"item_class_id":int(record.get("source_item_class_id",-1)),"level":int(physical.get("level",0)),"element":str(physical.get("element","")),"element_level":int(physical.get("element_level",0)),"bless_state":str(physical.get("bless_state",record.get("bless_state","normal")))}
	return result
func run() -> void:
	var result: Dictionary = D.install_zip(OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP"))
	check(result.get("ok",false),"explicit candidate full ZIP installed")
	if not result.get("ok",false):quit(1);return
	check(D.pack_identity().sha256 == D.DATA_SHA and D.definition_count() == 34743,"latest exact whole ItemClass root active")
	var actual_root: String = ProjectSettings.globalize_path(D._root)
	check(FileAccess.get_sha256(actual_root.path_join("monster_drops.bin")) == D.DATA_SHA,"actual consumed root bytes match approved Drive payload")
	for relative: String in D.data().item_shards:
		check(FileAccess.get_sha256(actual_root.path_join(relative)) == D.data().item_shards[relative].sha256,"every actually installed detail shard matches approved bytes "+relative)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer = -100000
	check(QA.enter_game(world),"actual Main current-source-map entry with received pack")
	world.field_population.set_process(false);world.player.set_physics_process(false);world._clear_monsters();world._clear_drops()
	var mixed_ids: Array[String] = ["10","2","1","9223372036854775808","0001","e9c829c2682c0b40776c4876dcea20b5","9f28d781ad674e421970e534035a822f"]
	mixed_ids.sort_custom(preload("res://scripts/ui/lineage_inventory_ui.gd").instance_id_less)
	check(mixed_ids == ["0001","1","2","10","9223372036854775808","9f28d781ad674e421970e534035a822f","e9c829c2682c0b40776c4876dcea20b5"],"legacy numeric and opaque UUID ordering never casts or changes ownership IDs")
	check(D.data().counts.rows == 46854 and D.data().drops.size() == 4848,"all original drop membership loaded with actual Main")
	for id: String in D.data().bindings:
		var binding: Dictionary = D.data().bindings[id]
		if D.data().source_exclusions.has(id):
			check(world.source_item_record(int(id)).is_empty(),"raw Test drop ID never becomes a normal source grant "+id)
		else: check(D.matches(world._catalog_item_from_source_id(str(binding.sourceId)),binding),"every normal drop item identity resolves in actual catalog "+id)
	var candidate_groups: int = 0
	for id: String in D.data().npcs:
		var npc: Dictionary = D.data().npcs[id]
		var groups: Dictionary = D.resolve(D.data(),{"kind":D.KIND,"source_npc_id":int(id),"source_sprite_id":int(npc.sprite_id),"source_name":str(npc.source_name)},world.loot_catalog)
		for item_id: String in groups:
			check(not D.data().source_exclusions.has(item_id),"every actual NPC candidate resolver excludes raw Test item IDs")
			candidate_groups += 1
	world.hud.open_catalog("아이템");world.hud._refresh_catalog_list("")
	var ui_ids: Dictionary = {}
	for item: Dictionary in world.hud.catalog_filtered_results:
		if item.get("source_m_native_item",false): ui_ids[str(int(item.source_item_class_id))] = true
		check(not item.get("source_test_item",false) and not item.get("source_preserved_legacy_catalog",false),"actual replacement catalog hides Test/archive rows")
	for id: String in D.data().native_item_ids: check(ui_ids.has(id),"every normal item reachable in actual fresh-pack catalog UI "+id)
	print("FULL_DELIVERY_STAGE catalog_and_drop_bindings ",ui_ids.size())
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_SUPPLIER_BLESS_EXPECTATIONS")))
	if not expected is Dictionary:printerr("private supplier source expectations required");quit(1);return
	if expected.has("supplier_bless_grants"): expected["grants"] = expected.supplier_bless_grants
	var valid: Dictionary = expected.grants[0]
	for field: String in ["item_class_id","amount","bless_raw","enchant"]:
		for invalid: Variant in [null,true,"1"]:
			var malformed: Dictionary = valid.duplicate(true);malformed[field] = invalid
			var rejected: Dictionary = world.stage_source_item_grants([malformed],{"kind":"supplier_numeric_guard"})
			check(not rejected.get("ok",false) and rejected.get("error") == "원본 지급 수치 형식 확인 실패","null/boolean/string never becomes an item ID or default enchant "+field)
	var saved_gold: int = world.gold
	world.gold = 9007199254740991
	check(not world.stage_source_item_grants([{"item_class_id":26,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"supplier_numeric_guard"}).get("ok",false) and world.gold == 9007199254740991,"currency overflow rejects without rounding owned value")
	world.gold = saved_gold
	var arrow: Dictionary = world.source_item_record(389)
	var saved_inventory: Dictionary = world.inventory.duplicate(true)
	world.inventory[str(arrow.name)] = 9007199254740991
	check(not world.stage_source_item_grants([{"item_class_id":389,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"supplier_numeric_guard"}).get("ok",false) and int(world.inventory[str(arrow.name)]) == 9007199254740991,"stack overflow preserves exact old count")
	world.inventory[str(arrow.name)] = 9007199254740990
	var boundary: Dictionary = world.stage_source_item_grants([{"item_class_id":389,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"supplier_numeric_guard"})
	check(boundary.get("ok",false) and int(boundary.overrides.inventory[str(arrow.name)]) == 9007199254740991 and int(world.inventory[str(arrow.name)]) == 9007199254740990,"largest exact JSON integer stages without changing live inventory")
	world.inventory = saved_inventory
	var staged: Dictionary = world.stage_source_item_grants(expected.grants,{"kind":"whole_original_supplier_variant_contract"})
	check(staged.get("ok",false),"all original merchant/craft nondefault bless variants stage")
	if not staged.get("ok",false):printerr(staged.get("error",""));quit(1);return
	check(world._save_game(true) == OK,"baseline durable save")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
	var ownership: Dictionary = world.inventory.duplicate(true)
	world.equipment_collections.test_save_writer = reject
	check(world._save_game(true,staged.overrides) != OK,"supplier variants actual writer failure")
	world.equipment_collections.test_save_writer = Callable()
	check(world.inventory == ownership and FileAccess.get_file_as_bytes(world.save_path()) == before,"supplier variant failure preserves both live and saved ownership")
	check(world._save_game(true,staged.overrides) == OK,"all supplier variants atomically saved")
	world.inventory = staged.overrides.inventory;world.item_instances = staged.overrides.item_instances;world.gold = int(staged.overrides.gold)
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	for grant: Dictionary in expected.grants:
		var item: Dictionary = world.source_item_record(int(grant.item_class_id),int(grant.bless_raw))
		var wallet: String = D.currency_identity_name(item)
		if wallet == "아데나":continue
		var name_value: String = wallet if not wallet.is_empty() else str(item.name)
		check(int(world.inventory.get(name_value,0)) > 0,"exact supplier variant inventory reentry "+str(int(grant.item_class_id))+"/"+str(int(grant.bless_raw)))
		if not D.equipment(item):continue
		var found: bool = false
		for physical: Dictionary in world.item_instances.values():
			if int(physical.get("source_m_reward_proof",{}).get("source_item_class_id",-1)) == int(grant.item_class_id) and int(physical.source_m_reward_proof.bless) == int(grant.bless_raw):found = true;break
		check(found,"source gear bless variant physical identity preserved")
	var jobs: Array[String] = []
	for row: Dictionary in world.BASE508.cards().get("classes",[]): jobs.append(str(row.name))
	var weapons: int = 0
	for key: String in D.data().native_item_ids:
		var item: Dictionary = world.source_item_record(int(key))
		if item.slot != "weapon": continue
		weapons += 1
		for job: String in jobs:
			var permitted: bool = item.get("source_unresolved_class_ids",[]).is_empty() and (item.get("source_class_names",[]).is_empty() or item.source_class_names.has(job))
			check(world._weapon_allowed_for_job(item,job) == permitted,"every native weapon follows original class instead of old fallback "+key+"/"+job)
	# These were the only non-expired source equipment rows previously blocked
	# solely by the old host weapon list in the whole-input execution matrix.
	for id: int in [344,6371,699]:
		var weapon: Dictionary = world.source_item_record(id)
		var acquired: Dictionary = world.stage_source_item_grants([{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"original_weapon_class_regression"})
		check(acquired.get("ok",false),"formerly host-blocked weapon acquisition")
		if not acquired.get("ok",false):continue
		world.inventory = acquired.overrides.inventory;world.item_instances = acquired.overrides.item_instances
		world.job_class = str(weapon.source_class_names[0]);world.level = 90;world.equipped_items.weapon = {}
		world._on_inventory_item_activated(str(weapon.name))
		check(int(world._equipped_weapon_record().get("source_item_class_id",-1)) == id,"formerly host-blocked source weapon now actually equips")
		var native: Dictionary = A.weapon_type(weapon)
		check(world._current_attack_range_cells() == int(native.AttackRange)+int(world.original_skills.local_runtime.attack_range_bonus()),"exact original weapon range")
	check(world._save_game(true) == OK,"current original equipment saved")
	# Actual inventory button -> Main use/equip handlers -> source effect -> save.
	var healing: Dictionary = {}
	for id: String in D.data().native_item_ids:
		var candidate: Dictionary = world.source_item_record(int(id))
		if candidate.get("heal_spec",{}).is_empty(): continue
		if U.eligibility(world,U.canonical(candidate)).is_empty() and D.hp_use_problem(U.canonical(candidate),false).is_empty(): healing = candidate;break
	check(not healing.is_empty(),"currently usable exact original HP item available")
	if not healing.is_empty():
		var staged_heal: Dictionary = world.stage_source_item_grants([{"item_class_id":int(healing.source_item_class_id),"amount":1,"bless_raw":1,"enchant":0}],{"kind":"fresh_drive_inventory_use_contract"})
		check(staged_heal.get("ok",false),"source healing item staged")
		if staged_heal.get("ok",false):
			world.inventory = staged_heal.overrides.inventory;world.item_instances = staged_heal.overrides.item_instances
			world.hp = maxi(1,world._effective_max_hp()-100);var before_hp: int = world.hp
			world.item_use_cooldowns = {};world._update_hud();world.hud.show_companion_bag()
			world.hud.lineage_inventory_ui._select_item(str(healing.name))
			var before_amount: int = int(world.inventory.get(healing.name,0))
			world.hud.lineage_inventory_ui.detail_action.pressed.emit()
			check(world.hp > before_hp and int(world.inventory.get(healing.name,0)) == before_amount-1,"actual source HP use via visible inventory button")
	var passive: Dictionary = {}
	var effects_file: String = OS.get_environment("TWILIGHT_ITEM_EFFECT_EXPECTATIONS")
	if not effects_file.is_empty():
		var effects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(effects_file))
		for entry: Dictionary in effects.passives:
			if int(entry.effects.get("RegenMP",0)) <= 0: continue
			var candidate: Dictionary = world.source_item_record(int(entry.id))
			var eligible_jobs: Array = candidate.get("source_class_names",[])
			var job: String = "기사" if eligible_jobs.is_empty() else str(eligible_jobs[0])
			if D.equipment_error(candidate,job,90).is_empty(): passive = candidate;world.job_class = job;world.level = 90;break
	check(not passive.is_empty(),"currently eligible exact source recovery gear available")
	if not passive.is_empty():
		for slot: String in world.EQUIPMENT_SLOT_ORDER: world.equipped_items[slot] = {}
		# The complete supplier inventory was saved/reentered above. Isolate the
		# effect case with one carried item; natural recovery must respect weight.
		world.inventory = {"화살":0,"총알":0};world.item_instances = {}
		var staged_passive: Dictionary = world.stage_source_item_grants([{"item_class_id":int(passive.source_item_class_id),"amount":1,"bless_raw":1,"enchant":0}],{"kind":"fresh_drive_inventory_equip_contract"})
		check(staged_passive.get("ok",false),"source recovery gear staged")
		if staged_passive.get("ok",false):
			world.inventory = staged_passive.overrides.inventory;world.item_instances = staged_passive.overrides.item_instances;world._update_hud()
			world.hud.lineage_inventory_ui._select_item(str(passive.name));world.hud.lineage_inventory_ui.detail_action.pressed.emit()
			var equipped: bool = false
			for gear: Dictionary in world.equipped_items.values():
				if int(gear.get("source_item_class_id",-1)) == int(passive.source_item_class_id): equipped = true
			check(equipped,"actual original recovery gear equipped through inventory button")
			world._refresh_equipment_effects();world.mp = maxi(0,world._effective_max_mp()-100)
			check(world._inventory_total_weight()*2 < world._carrying_capacity(),"natural recovery case satisfies actual weight condition")
			var before_mp: int = world.mp;world.source_item_regen_elapsed = 0.0
			P.tick(world,float(world.ui_preferences.get("patch523_item_regen_interval_seconds",30.0)))
			check(world.mp > before_mp,"actual original equipped MP recovery effect")
	check(world._save_game(true) == OK,"fresh source use/equipment/effect saved")
	var final_inventory: Dictionary = world.inventory.duplicate(true)
	var final_equipment: Dictionary = equipped_ownership(world)
	var final_mp: int = world.mp
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	if not same_saved_value(world.inventory,final_inventory) or not same_saved_value(equipped_ownership(world),final_equipment) or world.mp != final_mp:
		print("FULL_REENTRY_DIAGNOSTIC ",JSON.stringify({"inventory_equal":same_saved_value(world.inventory,final_inventory),"equipment_before":final_equipment,"equipment_after":equipped_ownership(world),"mp_before":final_mp,"mp_after":world.mp}))
	check(same_saved_value(world.inventory,final_inventory) and same_saved_value(equipped_ownership(world),final_equipment) and world.mp == final_mp,"actual fresh source ownership/equipment/MP survive reentry")
	world.hud.open_settings_info();await process_frame
	var settings: Node = world.hud.find_child("Patch523DropSettings",true,false)
	check(settings != null and settings.source_regen_interval != null and settings.ammo_rule != null,"actual full item settings controls present")
	world.hud.lineage_side_ui.equipment_page_index = 2
	world.hud.lineage_side_ui._layout_equipment()
	for slot: String in ["domination_stone","relic_item","fishing_rod"]:check(world.hud.lineage_side_ui.gear_icons.has(slot),"actual native equipment slot UI "+slot)
	world.queue_free();await process_frame
	print("FULL_DELIVERY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":34743,"normal_catalog_ui_ids":ui_ids.size(),"all_drop_rows_loaded":46854,"all_NPC_candidate_resolvers_checked":D.data().npcs.size(),"resolved_candidate_groups":candidate_groups,"source_supplier_bless_variants":expected.grants.size(),"all_native_weapons_class_checked":weapons,"latest_root_sha256":D.DATA_SHA,"actual_installed_root":actual_root,"input_origin":OS.get_environment("TWILIGHT_DELIVERY_ORIGIN"),"drive_auto_download":false,"other_supplier_prs_merged":false}))
	quit(0 if failures.is_empty() else 1)
