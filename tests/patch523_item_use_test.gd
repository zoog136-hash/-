extends SceneTree
## Local opt-in integration with the validated private pack, never player data.
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var failed_writes: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_USE_FAIL: ",label)

func reject_write(_path: String, _state: Dictionary) -> Error:
	failed_writes += 1
	return ERR_CANT_CREATE

func grant(world: TwilightWorld, id: String, amount: int = 1) -> Dictionary:
	var definition: Dictionary = DROPS.cached_definition(id)
	var native: Dictionary = definition.native_record
	var record: Dictionary = world._find_catalog_item_record(str(native.name))
	if record.is_empty(): record = world._find_catalog_item_record(str(definition.get("existing_binding", {}).get("name", "")))
	check(not record.is_empty(),"actual catalog record "+id)
	if not record.is_empty(): world.inventory[str(record.name)] = int(world.inventory.get(str(record.name),0))+amount
	return record

func dismiss(world: TwilightWorld) -> void:
	if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()

func failure_snapshot(world: TwilightWorld) -> Dictionary:
	return {"inventory":world.inventory.duplicate(true),"cards":world.card_draw_fusion.export_state(),"buffs":world.active_item_buffs.duplicate(true),"cooldowns":world.item_use_cooldowns.duplicate(true),"hp":world.hp,"mp":world.mp,"gold":world.gold,"instances":world.item_instances.duplicate(true),"rng":world.rng.state,"disk":FileAccess.get_sha256(world.save_path())}

func same_inventory(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key: String in a:
		if not b.has(key) or int(a[key]) != int(b[key]): return false
	return true

func same_instances(a: Dictionary,b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for id: String in a:
		if not b.has(id): return false
		for field: String in ["name","bless_state","element"]:
			if str(a[id].get(field,"")) != str(b[id].get(field,"")): return false
		for field: String in ["level","element_level"]:
			if int(a[id].get(field,0)) != int(b[id].get(field,0)): return false
		if int(a[id].get("record",{}).get("source_item_class_id",0)) != int(b[id].get("record",{}).get("source_item_class_id",0)): return false
	return true

func fail_use(world: TwilightWorld, record: Dictionary) -> void:
	check(world._save_game(true) == OK,"baseline before failing item use")
	var before: Dictionary = failure_snapshot(world)
	world.equipment_collections.test_save_writer = reject_write
	world._on_inventory_item_activated(str(record.name))
	world.equipment_collections.test_save_writer = Callable()
	check(failure_snapshot(world) == before,"save failure preserves complete ownership/resources/RNG/save: "+str(record.name))
	check(not world.hud.is_card_reveal_busy(),"failed transaction never reveals a card")

func capture(label: String) -> void:
	var directory: String = OS.get_environment("TWILIGHT_DROP_CAPTURE_DIR")
	if directory.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png")) == OK,"rendered capture "+label)

func run() -> void:
	var zip: String = OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP")
	if zip.is_empty():
		printerr("Private pack required; use an isolated test XDG profile.")
		quit(2); return
	check(DROPS.install_zip(zip).get("ok",false),"private pack production installation")
	var document: Dictionary = DROPS.data()
	print("PATCH523_USE_STAGE pack_loaded")
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main and source map entry")
	print("PATCH523_USE_STAGE actual_main_entered")
	world.field_population.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.level = 90
	var card_specs: Array[Dictionary] = []
	var bags: Array[Dictionary] = []
	for key: String in DROPS.definition_ids():
		var definition: Dictionary = DROPS.cached_definition(key)
		var record: Dictionary = definition.native_record
		var spec: Dictionary = record.get("source_use_spec",{})
		if spec.get("kind") == "fixed_card" and spec.get("activation_status") == "unrestricted" and not record.source_test_item: card_specs.append({"id":key,"spec":spec})
		if spec.get("kind") == "guaranteed_bag" and spec.get("activation_status") == "unrestricted": bags.append({"id":key,"spec":spec})
	check(card_specs.size() >= 101 and bags.size() == 9,"source eligible fixed cards and guaranteed bags")
	# Write failure must reach the real save boundary without publishing awards.
	var first_card: Dictionary = grant(world,str(card_specs[0].id),2)
	await fail_use(world,first_card)
	var rng_before: int = world.card_draw_fusion.rng.state
	var categories: Dictionary = {}
	for value: Dictionary in card_specs:
		var record: Dictionary = grant(world,str(value.id))
		var spec: Dictionary = value.spec
		var before: int = world.card_draw_fusion.total_count(str(spec.card_kind),str(spec.host_card_identity))
		var item_before: int = int(world.inventory[str(record.name)])
		world._on_inventory_item_activated(str(record.name))
		check(world.card_draw_fusion.total_count(str(spec.card_kind),str(spec.host_card_identity)) == before+1,"exact fixed card actual receive "+str(value.id))
		check(int(world.inventory.get(str(record.name),0)) == item_before-1,"fixed card exactly one debit "+str(value.id))
		check(world.hud.is_card_reveal_busy(),"actual reveal UI after durable grant "+str(value.id))
		categories[str(spec.card_kind)] = true
		if categories.size() == 1 and world.card_draw_fusion.source_card_receipts.size() == 1: await capture("patch523-fixed-card")
		dismiss(world)
		await process_frame
	check(categories.size() == 3 and world.card_draw_fusion.rng.state == rng_before,"all collectible kinds supported without random draws")
	print("PATCH523_USE_STAGE fixed_cards_done ",card_specs.size())
	# Source item no-swap metadata survives alongside the fixed source identity.
	check(not world.card_draw_fusion.source_card_receipts.is_empty(),"fixed grants retain provenance ledger")
	for receipt: Dictionary in world.card_draw_fusion.source_card_receipts:
		var spec: Dictionary = DROPS.cached_definition(str(int(receipt.item_class_id))).native_record.source_use_spec
		check(receipt.buff_card_cannot_swap == spec.buff_card_cannot_swap,"source no-swap flag preserved per receipt")
	var buffs_before: Dictionary = world.active_item_buffs.duplicate(true)
	for id: String in ["859","2982","3022","230592","248198"]:
		var record: Dictionary = grant(world,id,2)
		world.item_use_cooldowns.clear()
		await fail_use(world,record)
		world._use_quick_item(str(record.name))
		check(world.active_item_buffs.has(str(record.name)),"quickslot actual source buff active "+id)
		var spec: Dictionary = record.source_use_spec
		for field: String in spec.typed_effects:
			check(int(world.active_item_buffs[str(record.name)].get(field,0)) == int(spec.typed_effects[field]),"exact typed buff field "+id+":"+field)
		var count: int = int(world.inventory.get(str(record.name),0))
		world._on_inventory_item_activated(str(record.name))
		check(int(world.inventory.get(str(record.name),0)) == count,"native cooldown prevents repeat debit "+id)
	check(world._active_item_buff_total("melee_damage") == 3,"same source buff 223 refreshes across item IDs without stacking")
	check(world._active_item_buff_total("def") == 6,"distinct source groups retain independent AC")
	var str_before: int = world._effective_attribute("STR")
	USE.clear_on_death(world)
	check(world._effective_attribute("STR") == str_before-1,"source death-sensitive attribute buff removed")
	check(world._active_item_buff_total("melee_damage") == 3 and world._active_item_buff_total("def") == 3,"source death-immune buffs retained")
	world._tick_item_buffs(3601.0)
	check(world.active_item_buffs == buffs_before,"source buff expiration clears actual effects")
	print("PATCH523_USE_STAGE buffs_done")
	var mp_record: Dictionary = grant(world,"248238",3)
	world.mp = maxi(0,world._effective_max_mp()-100)
	await fail_use(world,mp_record)
	var mp_before: int = world.mp
	world._use_quick_item(str(mp_record.name))
	check(world.mp >= mp_before+1 and world.mp <= mp_before+10,"actual MP dice 1d10 without guessed mean")
	var mp_count: int = int(world.inventory.get(str(mp_record.name),0))
	world._use_quick_item(str(mp_record.name))
	check(int(world.inventory.get(str(mp_record.name),0)) == mp_count,"source MP cooldown enforced")
	var hp_record: Dictionary = grant(world,"236",2)
	world.hp = maxi(1,world._effective_max_hp()-100)
	world.item_use_cooldowns.clear()
	await fail_use(world,hp_record)
	world._use_quick_item(str(hp_record.name))
	check(int(world.inventory.get(str(hp_record.name),0)) == 1,"source HP potion durably consumes only one")
	for id: String in ["126702","150973","164453","173003"]:
		var gated: Dictionary = grant(world,id)
		var before: Dictionary = failure_snapshot(world)
		world._on_inventory_item_activated(str(gated.name))
		check(failure_snapshot(world) == before,"partial HP recovery cannot bypass original region/lifetime/extra effects "+id)
	for value: Dictionary in bags:
		var record: Dictionary = grant(world,str(value.id),2)
		world.item_use_cooldowns.clear()
		await fail_use(world,record)
		var before: int = int(world.inventory[str(record.name)])
		var coins_before: int = int(world.inventory.get("명예 코인",0))
		world._on_inventory_item_activated(str(record.name))
		check(int(world.inventory.get(str(record.name),0)) == before-1,"actual guaranteed box consumes one "+str(value.id))
		if str(value.id) == "9281": check(int(world.inventory.get("명예 코인",0)) == coins_before+1500,"source exact 1500 honor coins go into actual wallet")
	var physical: int = 0
	for instance: Dictionary in world.item_instances.values():
		if instance.has("source_m_reward_proof"):
			physical += 1
			check(instance.record.source_item_class_id > 0 and instance.level == 0,"source guaranteed gear pinned to physical identity")
	print("PATCH523_USE_STAGE guaranteed_bags_done ",bags.size())
	var random_bags: int = 0
	for key: String in DROPS.definition_ids():
		var spec: Dictionary = DROPS.cached_definition(key).native_record.get("source_use_spec",{})
		if spec.get("kind") not in ["source_weighted_bag","mixed_rewards_bag"] or spec.get("activation_status") != "unrestricted": continue
		var record: Dictionary = grant(world,key,2)
		if key == "6851": await fail_use(world,record)
		var before: int = int(world.inventory[str(record.name)])
		world._on_inventory_item_activated(str(record.name))
		check(int(world.inventory.get(str(record.name),0)) == before-1,"actual source weighted/mixed box consumes exactly one "+key)
		random_bags += 1
	check(random_bags >= 66,"all currently source-ready weighted/mixed boxes exercised")
	physical = 0
	for instance: Dictionary in world.item_instances.values():
		if instance.has("source_m_reward_proof"):
			physical += 1
			check(instance.record.source_item_class_id > 0 and int(instance.level) == int(instance.source_m_reward_proof.enchant),"weighted source gear has pinned actual physical identity")
	check(physical > 0,"actual source equipment delivered from nested starter/random boxes")
	await stone_checks(world)
	# Source unresolved scrolls cannot enter legacy name-only enhancement UI.
	var scroll: Dictionary = grant(world,"137")
	var count_before: int = int(world.inventory[str(scroll.name)])
	var enhancement_before: String = str(world.hud.enhancement_scroll_name)
	world._on_inventory_item_activated(str(scroll.name))
	check(int(world.inventory[str(scroll.name)]) == count_before,"unmapped source scroll preserved without generic name activation")
	check(str(world.hud.enhancement_scroll_name) == enhancement_before,"unmapped source scroll cannot open generic enhancement UI")
	var blocked: int = 0
	for key: String in document.native_item_ids:
		var record: Dictionary = DROPS.cached_definition(key).native_record
		var spec: Dictionary = record.get("source_use_spec",{})
		if (spec.get("kind") == "fixed_card" and spec.get("activation_status") != "unrestricted") or (record.source_test_item and spec.get("kind") == "fixed_card"):
			grant(world,key)
			var before: Dictionary = failure_snapshot(world)
			world._on_inventory_item_activated(str(record.name))
			check(failure_snapshot(world) == before,"source server/test conditions retain item "+key)
			blocked += 1
	check(blocked >= 19,"server-context item cases exercised")
	await weapon_checks(world)
	world.hud.open_catalog("아이템")
	var display: Dictionary = world._find_catalog_item_record(str(mp_record.name))
	world.hud.catalog_search.text = str(mp_record.name)
	world.hud._refresh_catalog_list(str(mp_record.name))
	if not world.hud.catalog_results.is_empty(): world.hud._select_catalog_index(0)
	check(DROPS.item_details(display).contains("1D10"),"native MP formula visible in item detail")
	world.hud.open_settings_info()
	var settings: Node = world.hud.find_child("Patch523DropSettings",true,false)
	check(settings != null,"actual settings widget connected")
	if settings != null:
		var saved_sha: String = FileAccess.get_sha256(world.save_path())
		world.equipment_collections.test_save_writer = reject_write
		settings._scope_selected(1)
		world.equipment_collections.test_save_writer = Callable()
		check(FileAccess.get_sha256(world.save_path()) == saved_sha and str(world.ui_preferences.get("patch523_weapon_double_scope","base_flat_enchant")) == "base_flat_enchant","failed settings save preserves old rule")
		settings._scope_selected(1)
		check(world.ui_preferences.get("patch523_weapon_double_scope") == "base_only","local inferred rule configurable through actual UI")
		settings.bleed_interval.set_value_no_signal(1.0)
		settings.bleed_rule.select(1)
		settings._bleed_changed(1.0)
		settings.reward_draw_count.set_value_no_signal(2)
		settings._reward_rule_changed(2)
		check(float(world.ui_preferences.get("patch523_bleed_tick_interval_seconds",0)) == 1.0 and int(world.ui_preferences.get("patch523_reward_bag_draw_count",0)) == 2,"bleed interpretation and local reward count use actual persisted UI")
		await capture("patch523-item-use-settings")
	check(world._save_game(true) == OK,"final actual transaction save")
	var snapshot: Dictionary = failure_snapshot(world)
	world._load_game(true)
	world.field_population.set_process(false)
	world._clear_monsters()
	check(same_inventory(world.inventory,snapshot.inventory) and same_instances(world.item_instances,snapshot.instances),"inventory and physical reward variants survive reentry")
	check(world.card_draw_fusion.export_state() == snapshot.cards,"fixed cards duplicates and source restrictions survive reentry")
	check(world.ui_preferences.get("patch523_weapon_double_scope") == "base_only","local rule survives reentry")
	check(float(world.ui_preferences.get("patch523_bleed_tick_interval_seconds",0)) == 1.0 and int(world.ui_preferences.get("patch523_reward_bag_draw_count",0)) == 2,"all local inferred settings survive reentry")
	check(failed_writes >= 17,"actual atomic writer failure boundary exercised")
	world.queue_free()
	await process_frame
	print("PATCH523_ITEM_USE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"failed_writes":failed_writes,"fixed_cards":card_specs.size(),"bags":bags.size()}))
	quit(0 if failures.is_empty() else 1)

func weapon_checks(world: TwilightWorld) -> void:
	var rng := RandomNumberGenerator.new()
	for source: String in ["503","492"]:
		var record: Dictionary = world._catalog_item_from_source_id(source)
		check(not record.is_empty(),"actual source-bound weapon record "+source)
		var fired: int = 0
		for index: int in range(300):
			var seed: int = 523+index
			rng.seed = seed
			var result: Dictionary = DROPS.weapon_invoke_roll(record,4,17,5,"base_flat_enchant",rng)
			if result.fired.is_empty(): check(result.damage == 4,"failed source proc preserves damage")
			else:
				fired += 1
				check(result.damage == (17 if source == "503" else 13),"claw maximizes weapon base; dual doubles only selected component")
				rng.seed = seed
				var alternate: Dictionary = DROPS.weapon_invoke_roll(record,4,17,5,"base_only",rng)
				check(alternate.damage == (17 if source == "503" else 8),"configurable component boundary uses same source roll")
		check(fired > 0 and fired < 150,"actual source probability drives procs "+source)
	var source_weapon: Dictionary = world._catalog_item_from_source_id("96414")
	check(not source_weapon.is_empty(),"source rifle identity in actual host catalog")
	world.job_class = "총사"
	world._equip_or_acquire_item(source_weapon,true)
	check(str(world._equipped_weapon_record().get("sourceId","")) == "96414","source rifle equipped through real equipment API")
	var proc: Dictionary = {}
	for effect: Dictionary in DROPS.item_definition(source_weapon).get("source_invoke_options",[]):
		if effect.get("kind") == "normal_attack_source_bleed": proc = effect
	check(not proc.is_empty(),"source bleed chain available")
	if proc.is_empty(): return
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.setup({"name":"출혈 회귀 대상","hp":100,"atk":1,"speed":0,"drop":[]},world.player,world,null)
	monster.set_physics_process(false)
	monster.global_position = world.player.global_position
	var successful: bool = false
	monster.max_hp = 10000
	for seed_value: int in range(2000):
		monster.hp = 10000
		monster.patch523_weapon_bleed.clear()
		world.rng.seed = seed_value
		world._resolve_normal_attack(monster,"ranged")
		if not monster.patch523_weapon_bleed.is_empty(): successful = true; break
	check(successful and monster.is_bleeding(),"real source proc arms actual monster status")
	if successful:
		monster.hp = 100; monster.max_hp = 100
		check(monster.patch523_weapon_bleed.remaining == 3.0 and monster.patch523_weapon_bleed.interval == 0.75,"original duration with labeled host tick default")
		preload("res://scripts/loot/patch523_weapon_bleed.gd").tick(monster,3.0)
		check(monster.hp == 60 and monster.patch523_weapon_bleed.is_empty(),"source 10D1 ticks cause actual HP damage and expire")
		monster.max_hp = 20; monster.hp = 20
		monster.apply_patch523_weapon_bleed(proc,0.75,"total_damage_cap")
		preload("res://scripts/loot/patch523_weapon_bleed.gd").tick(monster,3.0)
		check(monster.hp == 10 and monster.patch523_weapon_bleed.is_empty(),"explicit inferred maximum-HP cap limits actual damage")
		monster.max_hp = 100; monster.hp = 100
		monster.apply_patch523_weapon_bleed(proc,1.0,"no_cap")
		preload("res://scripts/loot/patch523_weapon_bleed.gd").tick(monster,3.0)
		check(monster.hp == 70,"configurable 1-second interval produces three actual ticks")
		monster.apply_patch523_weapon_bleed(proc,0.75,"total_damage_cap")
		monster.retire_for_pool()
		check(monster.patch523_weapon_bleed.is_empty(),"pooled monster cannot leak source bleed into next life")
	monster.free()

func stone_checks(world: TwilightWorld) -> void:
	var record: Dictionary = grant(world,"323353")
	check(record.get("slot") == "domination_stone","source slot 293 has its own host slot")
	var mr_before: int = world._effective_mr()
	var xp_before: float = world._experience_multiplier()
	world._on_inventory_item_activated(str(record.name))
	check(not world.equipped_items.get("domination_stone",{}).is_empty(),"source stone equipped through actual inventory action")
	check(world._effective_mr() == mr_before+2 and is_equal_approx(world._experience_multiplier(),xp_before+0.01),"source stone actual MR and XP modifiers")
	check(world._enhancement_kind_for_record(record).is_empty(),"new slot does not inherit an invented enhancement rule")
	var alias: Dictionary = world._find_catalog_item_record(str(record.name)+" · 축복")
	check(not alias.is_empty() and alias.get("source_legacy_stack_variant",false),"old blessed source-stone stack remains addressable")
	world.inventory[str(alias.name)] = int(world.inventory.get(str(alias.name),0))+1
	world._sync_item_instances()
	var id: String = world._chosen_instance(str(alias.name),true)
	check(not id.is_empty() and world.item_instances[id].get("bless_state") == "blessed","old blessed stack gains its own physical state without merging quantities")
	world._on_inventory_item_activated(str(alias.name)+"@@@"+id)
	check(world.equipped_items.domination_stone.get("bless_state") == "blessed","legacy blessed source stone uses new dedicated slot")
	world.hud.open_character()
	world.hud.lineage_side_ui.equipment_page_index = 2
	world.hud.lineage_side_ui._layout_equipment()
	var button: Button = world.hud.lineage_side_ui.equipment_buttons.get("domination_stone")
	check(button != null and button.visible and button.is_visible_in_tree(),"dedicated stone button visible in real character UI")
	await capture("patch523-domination-stone")
	check(world._save_game(true) == OK,"source stone state durable")
